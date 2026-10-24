# Claude Code 설정 사용 매뉴얼

이 저장소의 설치, 프로젝트 설정, 일상 사용, 하네스, 루프, 커스터마이징, 문제 해결 방법을 정리한 문서다. 각 규칙의 정확한 정의는 [RULES.md](RULES.md)를 본다.

## 목차

1. [구성 한눈에 보기](#1-구성-한눈에-보기)
2. [요구 사항](#2-요구-사항)
3. [설치 · 업데이트 · 제거](#3-설치--업데이트--제거)
4. [프로젝트 설정](#4-프로젝트-설정)
5. [일상 사용 시나리오](#5-일상-사용-시나리오)
6. [하네스](#6-하네스)
7. [스킬과 서브에이전트](#7-스킬과-서브에이전트)
8. [루프](#8-루프)
9. [커스터마이징과 훅 테스트](#9-커스터마이징과-훅-테스트)
10. [레퍼런스](#10-레퍼런스)
11. [문제 해결](#11-문제-해결)

---

## 1. 구성 한눈에 보기

| 계층 | 무엇 | 언제 작동 | 위치 |
|---|---|---|---|
| 지시 | 전역 작업 원칙 | 모든 세션 | `~/.claude/CLAUDE.md` |
| 지시 | 스택별 규칙 7종 | 해당 파일을 다룰 때 | `~/.claude/rules/` |
| 절차 | 스킬 6종 | `/이름`으로 호출하거나 요청과 맞을 때 | `~/.claude/skills/` |
| 절차 | reviewer 서브에이전트 | 리뷰가 필요할 때 | `~/.claude/agents/` |
| 하네스 | 훅 5종 | 이벤트마다 자동 | `~/.claude/hooks/`, `settings.json` |
| 하네스 | 비밀 파일 접근 차단 | 항상 | `settings.json` permissions |
| 루프 | `claude-loop` | 직접 실행 | `~/.local/bin/claude-loop` |

세션 한 번의 흐름:

```
claude 시작
  └ SessionStart ─ 브랜치·변경·최근 커밋·PLAN 요약이 컨텍스트에 들어감
사용자 요청 → Claude가 탐색·계획·구현
  ├ Bash 실행 전 ─ 위험 명령이면 차단 또는 확인 창
  └ 파일 수정 후 ─ 수정 파일 기록 + 포매터 실행
Claude가 끝내려 함
  └ Stop ─ 코드 수정이 있으면 타입 체크·린트·테스트
           ├ 통과 → 종료
           └ 실패 → 종료를 막고 로그 전달 → Claude가 수정 → 다시 Stop (최대 3회)
```

---

## 2. 요구 사항

| 도구 | 용도 | 없으면 |
|---|---|---|
| Claude Code CLI | 전부 | — |
| `git` | 훅, 루프 | 대부분의 훅이 동작하지 않음 |
| `jq` | 모든 훅, 루프 | 훅이 동작하지 않음 (설치 시 경고 표시) |
| `timeout` (coreutils) | `claude-loop` | 루프가 실행되지 않음. macOS는 `brew install coreutils` |
| bash 4+ | `verify-on-stop.sh`의 연관 배열 | macOS 기본 bash 3.2에서는 검증 훅이 실패하므로 `brew install bash` |
| 프로젝트 도구 | 포매팅·검증 | 해당 단계만 건너뜀 (Prettier/Biome, ruff, Spotless 등) |

---

## 3. 설치 · 업데이트 · 제거

### 3.1 설치

```bash
git clone <이 저장소> ~/claude-setting
~/claude-setting/install.sh
```

설치 스크립트는 아래 경로를 이 저장소로 향하는 **심볼릭 링크**로 만든다.

| 링크 | 원본 |
|---|---|
| `~/.claude/CLAUDE.md` | `global/CLAUDE.md` |
| `~/.claude/settings.json` | `global/settings.json` |
| `~/.claude/hooks` | `global/hooks/` |
| `~/.claude/loop` | `global/loop/` |
| `~/.claude/rules/<각 파일>` | `global/rules/*.md` |
| `~/.claude/skills/<각 스킬>` | `global/skills/*/` |
| `~/.claude/agents/<각 파일>` | `global/agents/*.md` |
| `~/.local/bin/claude-loop` | `global/loop/claude-loop` |

- 같은 이름의 파일이 링크가 아니면 `<이름>.bak.<타임스탬프>`로 백업한 뒤 링크한다.
- `CLAUDE_CONFIG_DIR`을 설정했으면 `~/.claude` 대신 그 경로에 설치한다. `CLAUDE_LOOP_BIN_DIR`로 실행 파일 위치를 바꿀 수 있다.
- `~/.local/bin`이 PATH에 없으면 설치 스크립트가 알려준다. 셸 설정에 `export PATH="$HOME/.local/bin:$PATH"`를 추가한다.

**기존 settings.json이 있었다면**: `~/.claude/settings.json.bak.*`에서 개인 설정(테마, 모델, `permissions.allow`, `env` 등)을 `global/settings.json`으로 옮긴다. 배열(`permissions.deny`, `hooks.*`)은 덮어쓰지 말고 항목을 합친다.

### 3.2 설치 확인

Claude Code를 새로 시작한 뒤 확인한다.

| 확인 | 방법 | 기대 결과 |
|---|---|---|
| 훅 등록 | `/hooks` | PreToolUse(Bash), PostToolUse(×2), SessionStart, Stop |
| 스킬 | `/` 입력 후 목록 | verify, db-migration, pr-ready, goal-loop, deps-audit, test-health |
| 에이전트 | `/agents` | reviewer |
| 규칙 로드 | `/memory` | `~/.claude/CLAUDE.md` 표시 |
| 컨텍스트 훅 | 아무 git 저장소에서 "지금 작업 상태 알려줘" | 브랜치·최근 커밋을 바로 답함 |
| 가드 훅 | "`git push --force` 실행해 줘" | 확인 창이 뜸 |
| 루프 | `claude-loop --help` | 사용법 출력 |

### 3.3 업데이트

```bash
cd ~/claude-setting && git pull
./install.sh      # 새 스킬·규칙·에이전트 파일이 추가됐을 때만 필요(개별 파일 링크)
```

기존 파일의 수정은 링크를 통해 바로 반영된다. 실행 중인 세션은 `/hooks`를 한 번 열거나 재시작하면 설정을 다시 읽는다.

### 3.4 제거

```bash
# 이 저장소를 가리키는 링크만 삭제
find ~/.claude ~/.local/bin -maxdepth 2 -type l -lname "$HOME/claude-setting/*" -print -delete
# 필요하면 백업을 복원
ls ~/.claude/*.bak.*    # 예: mv ~/.claude/settings.json.bak.2026… ~/.claude/settings.json
# 훅 상태 파일(선택)
rm -rf ~/.local/state/claude-harness
```

---

## 4. 프로젝트 설정

### 4.1 프로젝트 CLAUDE.md

```bash
cp ~/claude-setting/templates/project/CLAUDE.md ./CLAUDE.md
```

`<...>` 자리를 채우고 해당 없는 섹션은 지운다. 코드가 이미 있는 저장소라면 Claude Code에서 `/init`으로 초안을 만든 뒤 템플릿 구조로 다듬어도 된다.

| 섹션 | 쓸 내용 | 쓰지 말 것 |
|---|---|---|
| 기술 스택 | 버전, JPA/MyBatis를 어디에 쓰는지 | 일반적인 설명 |
| 명령어 | 실행·단일 테스트·전체 검증 명령 | 쓰지 않는 명령 |
| 구조와 경계 | 이름만 봐서는 알 수 없는 모듈 역할, 의존 방향 | 디렉터리 전체 목록 |
| 프로젝트 관례 | 응답 래퍼, 예외 규약, 브랜치·커밋 규칙 | 전역 규칙과 같은 내용 |
| 주의사항 | 실제로 겪은 함정 | 가상의 경고 |

200줄 이하로 유지한다. Claude가 같은 실수를 반복하면 "주의사항"에 한 줄씩 추가한다.

### 4.2 경로 범위 규칙

특정 디렉터리에만 해당하는 규칙은 `.claude/rules/<이름>.md`로 만든다. 예시는 `templates/project/.claude/rules/example-api.md`에 있다.

```markdown
---
paths:
  - "api/src/main/java/**/controller/**"
---
# API 컨트롤러 규칙
- 새 엔드포인트는 docs/api.md에도 추가한다.
```

### 4.3 프로젝트 검증 스크립트 (권장)

자동 감지가 너무 느리거나 부족하면 `.claude/harness/verify.sh`를 둔다. 이 파일이 있으면 Stop 훅은 자동 감지 대신 이 스크립트만 실행한다. 인자로는 이번 세션에서 수정한 파일 경로가 들어온다.

```bash
mkdir -p .claude/harness && cat > .claude/harness/verify.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
changed=("$@")
if printf '%s\n' "${changed[@]}" | grep -q '^.*/api/'; then
  ./gradlew -q :api:compileJava :api:test
fi
if printf '%s\n' "${changed[@]}" | grep -q '/web/'; then
  pnpm --filter web typecheck && pnpm --filter web test
fi
EOF
chmod +x .claude/harness/verify.sh
```

종료 코드가 0이 아니면 실패로 처리되고, 출력은 Claude에게 전달된다.

### 4.4 프로젝트 settings

팀과 공유할 권한·훅은 `.claude/settings.json`에, 개인용은 `.claude/settings.local.json`(gitignore 대상)에 둔다. 전역 설정과 합쳐지며 프로젝트 쪽이 우선한다.

```json
{
  "permissions": {
    "allow": ["Bash(./gradlew *)", "Bash(pnpm *)", "Bash(uv run *)"],
    "deny": ["Edit(legacy/**)"]
  }
}
```

`allow`는 `claude-loop`를 `--mode acceptEdits`로 돌릴 때 특히 필요하다(§8.1).

---

## 5. 일상 사용 시나리오

| 하고 싶은 일 | 이렇게 요청 | 일어나는 일 |
|---|---|---|
| 기능 구현 | "주문 목록에 상태 필터 추가해 줘" | 탐색 → 짧은 계획 → 구현 → 포매팅(자동) → 종료 전 검증(자동) |
| 버그 수정 | "이 스택트레이스 원인 찾아서 고쳐 줘" | 재현 → 원인 → 수정 → 같은 검사로 확인 |
| 통과할 때까지 수정 | `/goal-loop OrderServiceTest 전부 통과` | §8.2 |
| 스키마 변경 | "orders에 canceled_at 컬럼 추가해 줘" 또는 `/db-migration` | 마이그레이션 작성 + Entity/Mapper 동기화, 적용은 안 함 |
| 검증만 | `/verify` | 감지한 검사를 실행하고 요약 |
| 리뷰 | "reviewer 에이전트로 이 브랜치 리뷰해 줘" | 독립 컨텍스트에서 읽기 전용 리뷰 |
| PR 준비 | `/pr-ready` | 셀프 리뷰 → 검증 → PR 초안 (push는 요청 시) |
| 큰 작업 무인 실행 | `PLAN.md` 작성 후 `claude-loop --branch loop/x` | §8.1 |
| 정기 점검 | `/loop 1d /deps-audit` | §8.3 |

Claude가 확인을 요청하는 경우([RULES.md](RULES.md) SAFE-01~05): push, 삭제, 마이그레이션 적용, DB 쓰기, 배포, 외부 게시, 전역 설정 변경. 한 번 승인해도 다음 비슷한 작업에서는 다시 묻는다.

---

## 6. 하네스

### 6.1 SessionStart — 작업 상태 주입

세션 시작, `--resume`, `/clear`, 컨텍스트 압축 직후마다 실행된다. Claude는 아래 정보를 알고 시작한다.

- 현재 브랜치와 기본 브랜치. 기본 브랜치에 있으면 작업 브랜치를 만들라는 경고
- 미커밋 변경(최대 15개). 사용자의 작업일 수 있으니 덮어쓰지 말라는 표시가 함께 붙는다
- 최근 커밋 5개
- `PLAN.md`가 있으면 완료/남은 작업 수와 다음 작업 3개, `PROGRESS.md`가 있으면 마지막 12줄

이 훅은 7일이 지난 훅 상태 파일도 정리한다.

### 6.2 위험 명령 가드

Claude가 Bash를 실행하기 전에 검사한다. 판정 목록은 [RULES.md](RULES.md) §10.3에 있다.

- **차단(deny)**: 명령이 실행되지 않고, Claude는 이유를 받아 다른 방법을 찾거나 사용자에게 알린다.
- **확인(ask)**: 권한 모드와 무관하게 확인 창이 뜬다. 승인하면 그대로 실행된다.

자주 하는 작업이 확인 창에 걸려 불편하면 `guard-bash.sh`에서 해당 패턴을 수정한다(§9.2).

### 6.3 포매팅

Write/Edit 직후 해당 파일만 포매팅한다. 프로젝트에 설치된 도구만 쓰므로, 포매터가 없는 프로젝트에서는 아무 일도 일어나지 않는다. Spotless는 Gradle을 띄우므로 데몬이 꺼져 있으면 첫 실행에 몇 초 걸린다.

### 6.4 종료 전 검증

이번 세션에서 파일을 수정했을 때만 Claude가 끝내려는 시점에 실행된다. 감지 규칙은 [RULES.md](RULES.md) §10.2에 있다.

| 상황 | 화면에 보이는 것 | 다음 동작 |
|---|---|---|
| 수정 없음 | 없음 | 즉시 종료 |
| 통과 | "종료 전 검증 중..." 후 종료 | 수정 목록 초기화 |
| 실패 (1~3회째) | Claude가 실패 로그를 받아 이어서 작업 | Claude가 고치고 다시 종료를 시도 |
| 4회째 실패 | "검증이 3번 연속 실패해 종료를 허용합니다" 경고 | 종료. 수정 목록은 남아 다음 종료 때 다시 검증 |

**제어 방법**

```bash
CLAUDE_HARNESS_VERIFY=off claude          # 이번 실행 동안 검증 끄기
CLAUDE_HARNESS_MAX_BLOCKS=5 claude        # 허용 실패 횟수 변경
```

- 로그: `~/.local/state/claude-harness/<session_id>/verify.log`
- 무관한 기존 실패 때문에 계속 막히면, Claude가 근거를 보고한 뒤 4회째에 종료된다. 반복된다면 `.claude/harness/verify.sh`로 범위를 좁힌다.
- 추적 한계: Bash(`sed -i` 등)로 바꾼 파일은 추적하지 않는다.

### 6.5 비밀 파일 보호

`.env`, `.env.local`, `.env.production`, `*.pem`, `*.key`, SSH 키, `~/.aws/credentials`, `~/.gnupg`는 Claude의 Read 도구로 읽을 수 없고, `.env` 계열은 수정도 거부된다. 셸로 `.env`를 읽으려 하면 확인 창이 뜬다. 예시 파일(`.env.example`)은 읽을 수 있다.

---

## 7. 스킬과 서브에이전트

스킬은 `/이름 [인자]`로 직접 호출하거나, 요청이 스킬 설명과 맞으면 Claude가 스스로 사용한다.

| 스킬 | 호출 예 | 하는 일 | 하지 않는 일 |
|---|---|---|---|
| `verify` | `/verify` | 검사 감지 → 병렬 실행 → 실패 수정 → 요약 | 테스트 스킵, `git stash` |
| `db-migration` | `/db-migration orders에 canceled_at timestamptz 추가` | 기존 관례 확인 → 파일 작성 → Entity/Mapper 동기화 → 무중단 점검 → 테스트 | 실제 DB 적용 |
| `pr-ready` | `/pr-ready` | 범위 파악 → 셀프 리뷰 → verify → 커밋 정리 → PR 초안 | 요청 없는 push·PR 생성, push한 히스토리 rewrite |
| `goal-loop` | `/goal-loop 타입 에러 0개 --check "pnpm typecheck" --max 6` | §8.2 | 검증 명령 변경 |
| `deps-audit` | `/deps-audit` | 취약점·업데이트 점검 → 우선순위 보고 | 요청 없는 업그레이드, 플러그인 추가 |
| `test-health` | `/test-health --runs 5` | N회 실행 → 실패·flaky·느린·건너뛴 테스트 보고 | 요청 없는 수정, 테스트 비활성화 |

**reviewer 서브에이전트**

- 직접 부를 때: "reviewer 에이전트로 `origin/main...HEAD` 리뷰해 줘"
- 여러 파일에 걸친 변경을 마치면 Claude가 완료 보고 전에 스스로 호출한다(HAR-02).
- 범위만 넘기고 작성자의 의도 설명은 넘기지 않아야 독립적인 리뷰가 된다.
- 결과는 `[높음/중간/낮음] 파일:줄 — 요약 / 경로 / 제안` 형식이다.

---

## 8. 루프

| 루프 | 언제 | 사람의 개입 |
|---|---|---|
| `claude-loop` | 여러 시간짜리 작업을 작은 작업 목록으로 나눠 무인 실행 | 계획 작성, 결과 브랜치 리뷰 |
| `/goal-loop` | 한 세션에서 끝나는 단일 목표 | 시작할 때 목표 확인 |
| `/loop` · 스케줄 | 주기적인 점검 | 보고서 확인 |

### 8.1 장기 자율 루프 — `claude-loop`

**1단계: 계획 작성**

```bash
cp ~/.claude/loop/PLAN.template.md PLAN.md
```

```markdown
# 계획: 주문 목록 키셋 페이징 전환

## 완료 조건
- `./gradlew :api:check` 통과
- GET /api/orders?cursor= 가 키셋 페이징으로 동작

## 제약
- 기존 offset 파라미터는 한 버전 동안 유지(하위 호환)
- 마이그레이션은 작성만 한다

## 작업
- [ ] 1. orders(created_at, id) 복합 인덱스 마이그레이션 작성 (CONCURRENTLY)
- [ ] 2. OrderMapper.xml에 커서 조회 쿼리 추가 + Mapper 테스트
- [ ] 3. OrderService에 커서 페이징 메서드 + 단위 테스트
- [ ] 4. Controller에 cursor 파라미터 추가, 응답에 nextCursor + WebMvcTest
- [ ] 5. docs/api.md 갱신
```

좋은 작업의 조건: 한 세션에 끝나는 크기, 검증 방법이 분명함, 앞 작업의 결과에만 의존함. 체크박스는 "작업" 섹션에만 쓴다.

**2단계: 실행**

```bash
git add PLAN.md && git commit -m "chore: add loop plan"
claude-loop --branch loop/orders-keyset
```

```
claude-loop: 브랜치 loop/orders-keyset, 계획 PLAN.md (남은 작업 5), 로그 .claude/loop/logs/20261024-171003
── 반복 1/20 시작 (17:10:03)
   상태 CONTINUE · 커밋 1 · 비용 $0.42 (누적 $0.42) · 남은 작업 4
…
claude-loop 종료: 모든 작업 완료 · 반복 5회 · 누적 $2.10 · 브랜치 loop/orders-keyset
```

**옵션**

| 옵션 | 기본값 | 설명 |
|---|---|---|
| `--plan FILE` | `PLAN.md` → `.claude/loop/PLAN.md` | 계획 파일 |
| `--progress FILE` | 계획 옆 `PROGRESS.md` | 진행 기록(없으면 생성) |
| `-n, --max-iter N` | 20 | 최대 반복 |
| `--budget USD` | 5 | 반복 1회 비용 상한 |
| `--total-budget USD` | 50 | 누적 비용 상한 |
| `--timeout MIN` | 45 | 반복 1회 시간 상한 |
| `--stall N` | 3 | 진전 없는 반복이 N회 연속이면 정지 |
| `--branch NAME` | — | 새 브랜치를 만들어 시작 |
| `--mode MODE` | `auto` | 권한 모드 (`auto`, `acceptEdits`, `bypassPermissions`) |
| `--model MODEL` | 계정 기본값 | 모델 지정 |
| `--prompt FILE` | `.claude/loop/prompt.md` → `~/.claude/loop/prompt.md` | 반복 프롬프트 |
| `--notify CMD` | — | 종료 시 `CMD "<요약>"` 실행 |
| `--dry-run` | — | 첫 반복 프롬프트만 출력 |

**종료 코드와 대응**

| 코드 | 의미 | 다음 행동 |
|---|---|---|
| 0 | 완료 | 브랜치 리뷰(`reviewer` 에이전트나 `/pr-ready`) 후 머지 |
| 1 | 실행기 오류(시작 조건 불충족 등) | 메시지대로 조치 |
| 2 | BLOCKED | `PROGRESS.md`의 `BLOCKED:` 항목에 답하거나 계획을 고친 뒤 재실행 |
| 3 | 진전 없음 | 마지막 `iter-N.json`의 `result`를 읽고, 작업을 더 쪼개거나 권한·검증 문제를 해결 |
| 4 | 비용 상한 | 진행 상황을 확인한 뒤 상한을 올려 재실행 |
| 5 | 최대 반복 | 그대로 재실행하면 이어서 진행 |

**재개**: 상태는 모두 파일과 git에 있으므로, 같은 브랜치에서 `claude-loop`를 다시 실행하면 남은 작업부터 이어간다(`--branch`는 빼고 실행).

**권한 모드 선택**

| 모드 | 언제 | 설정 |
|---|---|---|
| `auto` (기본) | 계정에서 auto 모드를 쓸 수 있을 때 | 없음 |
| `acceptEdits` | auto를 쓸 수 없을 때 | 프로젝트 `.claude/settings.json`의 `permissions.allow`에 빌드·테스트·git 명령 추가(§4.4) |
| `bypassPermissions` | 격리된 컨테이너·VM에서만 | 가드 훅은 그대로 동작한다 |

**병행 작업**: 루프가 작업 트리를 쓰므로 같은 디렉터리에서 다른 작업을 하지 않는다. 대신 worktree를 쓴다.

```bash
git worktree add ../app-loop -b loop/orders-keyset
cd ../app-loop && claude-loop
```

**모니터링**

```bash
column -t -s $'\t' .claude/loop/logs/*/summary.tsv     # 반복별 상태·비용·커밋
jq -r .result .claude/loop/logs/<시각>/iter-3.json     # 특정 반복의 최종 응답
tail -f PROGRESS.md                                    # 진행 기록
git log --oneline                                      # 반복별 커밋
```

**알림 예시**

```bash
claude-loop --notify 'notify-send claude-loop'                       # Linux 데스크톱
claude-loop --notify 'terminal-notifier -title claude-loop -message' # macOS
```

**프롬프트 커스터마이징**: `cp ~/.claude/loop/prompt.md .claude/loop/prompt.md`로 복사한 뒤 수정한다. 사용할 수 있는 변수는 `{{ITER}} {{MAX}} {{PLAN}} {{PROGRESS}} {{REMAINING}} {{DATE}}`다. 마지막 줄의 `<loop-status>` 규칙은 유지해야 한다.

### 8.2 세션 내 목표 루프 — `/goal-loop`

```
/goal-loop OrderServiceTest 전부 통과 --check "./gradlew :api:test --tests '*OrderService*'" --max 6
```

1. Claude가 목표, 검증 명령, 최대 반복, 수정 범위를 한 줄씩 보여주고 시작한다.
2. 기준선을 측정한다(예: 실패 12개).
3. 반복: 실패 하나 진단 → 가설 → 최소 수정 → 재검증 → 기록
4. 정지: 성공, 최대 반복, 2회 연속 개선 없음, 범위 밖 변경이 필요한 경우
5. 보고: 기준선 → 최종 지표, 반복별 가설과 결과, 남은 문제

`--check`를 생략하면 Claude가 적절한 검증 명령을 정해서 보여준다. 명령으로 판정할 수 없는 목표("코드를 더 깔끔하게")는 판정 기준부터 함께 정한다.

### 8.3 정기 루프

**세션 안에서 (세션이 열려 있는 동안만)**

```
/loop 1d /deps-audit
/loop 12h /test-health --runs 3
/loop 30m PR #123의 CI 상태 확인하고 실패하면 원인 요약
```

간격을 생략하면(`/loop /test-health`) Claude가 주기를 스스로 정한다.

**세션과 무관하게**

- claude.ai의 Routines(클라우드 스케줄)에 `/deps-audit` 같은 프롬프트를 등록한다.
- 또는 cron + headless:

```cron
# 평일 08:47 의존성 점검 보고서
47 8 * * 1-5 cd ~/work/app && claude -p "/deps-audit" --permission-mode auto < /dev/null > ~/reports/deps-$(date +\%F).md 2>&1
# 매주 월요일 07:13 테스트 건강 점검
13 7 * * 1 cd ~/work/app && claude -p "/test-health --runs 3" --permission-mode auto < /dev/null > ~/reports/tests-$(date +\%F).md 2>&1
```

cron 환경에는 PATH가 최소한만 잡혀 있으므로 `claude`, `jq`, 빌드 도구의 경로를 crontab의 `PATH=`로 지정한다.

---

## 9. 커스터마이징과 훅 테스트

### 9.1 규칙 추가·수정

| 규칙의 성격 | 둘 곳 |
|---|---|
| 모든 프로젝트, 항상 | `global/CLAUDE.md` |
| 특정 언어·프레임워크 | `global/rules/<이름>.md` (`paths` 필수) → `install.sh` 재실행 |
| 특정 프로젝트 | 프로젝트 `CLAUDE.md` 또는 `.claude/rules/` |
| 반드시 지켜져야 함 | 훅이나 `permissions` |
| 가끔 쓰는 긴 절차 | 스킬 |

수정한 뒤에는 [RULES.md](RULES.md)의 해당 행도 고친다(부록 B).

### 9.2 훅 수정

- 위험 명령 패턴: `global/hooks/guard-bash.sh`의 `deny`/`ask` 블록. `has '<정규식>' && decide ask "<이유>"` 한 줄을 추가하거나 지운다.
- 포매터: `global/hooks/format.sh`의 확장자별 `case`
- 검증 감지: `global/hooks/verify-on-stop.sh`의 자동 감지 블록. 프로젝트 한정이면 `.claude/harness/verify.sh`가 낫다.
- 훅 비활성화: `/hooks`에서 끄거나 `global/settings.json`에서 해당 항목을 지운다.

### 9.3 훅 테스트

훅은 stdin으로 JSON을 받는다. 수정한 뒤에는 실제 입력 형태로 직접 실행해 본다.

```bash
H=~/claude-setting/global/hooks

# 가드: 판정 확인 (출력이 없으면 허용)
jq -n --arg c 'git push --force' '{tool_name:"Bash",tool_input:{command:$c}}' \
  | $H/guard-bash.sh | jq -r '.hookSpecificOutput.permissionDecision // "allow"'

# 포매터
echo "{\"tool_input\":{\"file_path\":\"$PWD/src/a.ts\"}}" | $H/format.sh

# 검증: 수정 기록 → Stop
export XDG_STATE_HOME=$(mktemp -d)        # 실제 상태와 분리
echo "{\"session_id\":\"t\",\"tool_input\":{\"file_path\":\"$PWD/src/a.ts\"}}" | $H/track-edits.sh
echo "{\"session_id\":\"t\",\"cwd\":\"$PWD\"}" | $H/verify-on-stop.sh | jq .
cat $XDG_STATE_HOME/claude-harness/t/verify.log

# 컨텍스트
echo "{\"cwd\":\"$PWD\"}" | $H/session-context.sh | jq -r .hookSpecificOutput.additionalContext

# 문법·설정 검사
bash -n $H/*.sh && jq empty ~/claude-setting/global/settings.json
```

`settings.json`이 깨지면 그 파일의 모든 설정이 조용히 무시되므로, 수정할 때마다 `jq empty`로 검사한다.

### 9.4 스킬·에이전트 추가

```
global/skills/<이름>/SKILL.md      # frontmatter: name, description(언제 쓰는지 구체적으로)
global/agents/<이름>.md            # frontmatter: name, description, tools, model
```

추가한 뒤 `install.sh`를 다시 실행한다. Claude가 스킬을 언제 쓸지는 `description`으로 판단하므로, 트리거가 되는 요청 문구를 넣는다.

---

## 10. 레퍼런스

### 10.1 환경 변수

| 변수 | 기본값 | 효과 |
|---|---|---|
| `CLAUDE_HARNESS_VERIFY` | `on` | `off`이면 종료 전 검증을 끈다 |
| `CLAUDE_HARNESS_MAX_BLOCKS` | `3` | 검증 실패로 종료를 막는 최대 연속 횟수 |
| `CLAUDE_CONFIG_DIR` | `~/.claude` | 설치 위치와 훅 경로 |
| `CLAUDE_LOOP_BIN_DIR` | `~/.local/bin` | `claude-loop` 링크 위치(설치 시) |
| `XDG_STATE_HOME` | `~/.local/state` | 훅 상태 디렉터리의 상위 경로 |

### 10.2 파일 위치

| 경로 | 내용 | git |
|---|---|---|
| `~/.local/state/claude-harness/<session>/edited` | 세션에서 수정한 파일 목록 | — |
| `~/.local/state/claude-harness/<session>/verify.log` | 마지막 검증 로그 | — |
| `~/.local/state/claude-harness/<session>/blocks` | 연속 실패 횟수 | — |
| `<project>/.claude/harness/verify.sh` | 프로젝트 검증 스크립트 | 커밋 |
| `<project>/PLAN.md` · `PROGRESS.md` | 루프 계획·기록 | 커밋 |
| `<project>/.claude/loop/prompt.md` | 프로젝트 루프 프롬프트 | 커밋 |
| `<project>/.claude/loop/logs/` | 루프 로그 | 제외(`.git/info/exclude`) |

### 10.3 훅 이벤트 매핑

| 이벤트 | 매처 | 스크립트 | 제한 시간 |
|---|---|---|---|
| SessionStart | `startup\|resume\|clear\|compact` | `session-context.sh` | 10s |
| PreToolUse | `Bash` | `guard-bash.sh` | 10s |
| PostToolUse | `Write\|Edit\|NotebookEdit` | `track-edits.sh` | 5s |
| PostToolUse | `Write\|Edit` | `format.sh` | 60s |
| Stop | (전체) | `verify-on-stop.sh` | 900s |

---

## 11. 문제 해결

| 증상 | 원인 | 해결 |
|---|---|---|
| 훅이 전혀 동작하지 않음 | `jq` 없음 / settings.json 문법 오류 / 링크 깨짐 | `command -v jq`, `jq empty ~/.claude/settings.json`, `ls -l ~/.claude/hooks` |
| 설정을 바꿨는데 반영 안 됨 | 실행 중인 세션이 이전 설정을 사용 | `/hooks`를 한 번 열거나 재시작 |
| 끝날 때마다 오래 기다림 | 전체 테스트 실행 | `.claude/harness/verify.sh`로 범위 축소, 급하면 `CLAUDE_HARNESS_VERIFY=off` |
| 내 변경과 무관한 실패로 계속 막힘 | 기본 브랜치에 이미 있는 실패 | Claude가 근거를 보고하고 4회째에 종료됨. 프로젝트 verify.sh에서 해당 검사를 제외하고, 실패는 따로 고친다 |
| macOS에서 Stop 훅 오류 `declare: -A` | bash 3.2 | `brew install bash` (훅은 `/usr/bin/env bash`를 쓰므로 PATH 앞쪽에 있으면 된다) |
| 포매팅이 안 됨 | 프로젝트에 포매터가 설치되지 않음 | `node_modules/.bin/prettier`, `ruff`, Spotless 설정 확인. 의도된 동작이다 |
| 필요한 명령이 확인 창에 자주 걸림 | 가드 패턴이 넓음 | `guard-bash.sh` 패턴 조정(§9.2) |
| `claude-loop`: 기본 브랜치 오류 | 안전장치 | `--branch loop/<이름>` |
| `claude-loop`: 미커밋 변경 오류 | 안전장치 | 커밋하거나 stash한 뒤 실행 |
| `claude-loop`: 매 반복 UNKNOWN | 응답에 `<loop-status>`가 없음, 권한 거부로 중단 | `iter-N.json`의 `result`와 `iter-N.err` 확인. 권한 문제면 `--mode`나 `permissions.allow` 조정 |
| `claude-loop`: 진전 없음(코드 3) | 작업이 너무 큼, 검증 실패 반복, 권한 부족 | `PROGRESS.md` 확인 → 작업을 쪼개거나 원인 해결 |
| `claude-loop: command not found` | PATH에 `~/.local/bin` 없음 | 셸 설정에 PATH 추가 |
| 루프 커밋에 `.claude/loop/logs`가 들어감 | `.git/info/exclude`가 없는 특수 환경 | `.gitignore`에 `.claude/loop/logs/` 추가 |
| SessionStart 정보가 안 보임 | git 저장소가 아님 | 정상 동작이다. git 저장소에서만 주입한다 |
