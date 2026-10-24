# claude-setting

Claude Code의 개인 전역 설정, 하네스(훅·권한·서브에이전트), 루프 도구, 프로젝트용 `CLAUDE.md` 템플릿을 모아 둔 저장소.

## 구성

```
global/
  CLAUDE.md              # ~/.claude/CLAUDE.md — 모든 프로젝트에 적용되는 작업 원칙
  settings.json          # ~/.claude/settings.json — hooks 등록, 비밀 파일 접근 차단
  hooks/                 # ~/.claude/hooks/
    session-context.sh   #   SessionStart: 브랜치·변경·최근 커밋·루프 계획을 컨텍스트에 주입
    guard-bash.sh        #   PreToolUse: 위험한 셸 명령 차단(deny) / 확인 강제(ask)
    track-edits.sh       #   PostToolUse: 세션에서 수정한 파일 기록
    format.sh            #   PostToolUse: 수정한 파일을 프로젝트 포매터로 정리
    verify-on-stop.sh    #   Stop: 코드를 수정했으면 끝내기 전에 타입 체크·린트·테스트
    lib.sh               #   공용 함수
  agents/                # ~/.claude/agents/
    reviewer.md          #   읽기 전용 독립 코드 리뷰 서브에이전트
  rules/                 # ~/.claude/rules/ — 언어·프레임워크별 규칙 (paths로 범위 지정)
    typescript.md  react.md  python.md
    java-spring.md  jpa.md  mybatis.md  postgresql.md
  skills/                # ~/.claude/skills/ — /이름 으로 호출하거나 자동 선택
    verify/              #   프로젝트 검사 감지·실행·요약
    db-migration/        #   PostgreSQL 마이그레이션 작성 (무중단 점검, 적용은 안 함)
    pr-ready/            #   셀프 리뷰 → 검증 → PR 초안
    goal-loop/           #   세션 내 목표 루프: 검증 명령이 통과할 때까지 반복
    deps-audit/          #   정기 루프용: 의존성 취약점·업데이트 점검
    test-health/         #   정기 루프용: 실패·flaky·느린 테스트 점검
  loop/                  # ~/.claude/loop/
    claude-loop          #   장기 자율 루프 실행기 (~/.local/bin/claude-loop 로 링크)
    prompt.md            #   반복 1회 프롬프트 템플릿
    PLAN.template.md     #   계획 파일 템플릿
templates/project/
  CLAUDE.md              # 새 프로젝트 루트에 복사해서 채우는 템플릿
  .claude/rules/         # 경로 범위 규칙 예시
install.sh               # 위 파일들을 심볼릭 링크로 설치
```

## 설치

```bash
git clone <이 저장소> ~/claude-setting
~/claude-setting/install.sh
```

- 심볼릭 링크로 설치하므로 이 저장소에서 수정하거나 `git pull`하면 바로 반영된다.
- 기존 파일은 `*.bak.<타임스탬프>`로 백업된다. 기존 `~/.claude/settings.json`에 개인 설정(테마, 모델, 권한 등)이 있었다면 `global/settings.json`으로 옮긴다.
- 필요 도구: `jq`(hooks), `timeout`(claude-loop, macOS는 `brew install coreutils`).
- 설치 후 Claude Code에서 `/hooks`로 등록 상태를 확인한다.

새 프로젝트에서는:

```bash
cp ~/claude-setting/templates/project/CLAUDE.md ./CLAUDE.md
cp -r ~/claude-setting/templates/project/.claude ./   # 필요할 때만
```

## 하네스

모델에게 "검증해라"라고 지시하는 대신, 하네스가 검증·컨텍스트·안전장치를 결정적으로 실행한다.

```
SessionStart ─ session-context.sh   브랜치·미커밋 변경·최근 커밋·PLAN/PROGRESS 요약 주입
     │                              (startup / resume / clear / compact 직후 모두)
PreToolUse(Bash) ─ guard-bash.sh    위험 명령 deny / ask
PostToolUse(Write|Edit) ─ track-edits.sh → format.sh
Stop ─ verify-on-stop.sh            수정 파일이 있으면 검사 → 실패 시 종료를 막고 로그를 돌려줌
```

### verify-on-stop.sh (Stop)

이번 세션에서 수정한 파일이 있을 때만 실행한다. 프로젝트에 `.claude/harness/verify.sh`(실행 권한 필요)가 있으면 그것만 실행하고(인자: 수정 파일 목록), 없으면 수정 파일 종류로 자동 감지한다.

| 수정 파일 | 실행 |
|---|---|
| TS/JS/Vue | 가장 가까운 `package.json`의 `typecheck`·`lint`·`test` 스크립트 (없으면 `tsc --noEmit`), `CI=true` |
| Python | `ruff check`, `[tool.mypy]`/`[tool.pyright]` 설정 시 해당 체커, `tests/`나 pytest 설정 시 `pytest -x` (uv 프로젝트는 `uv run`) |
| Java/Kotlin/Gradle/XML/SQL/YAML | Gradle: 수정 파일이 속한 모듈만 `:모듈:check` / Maven: `./mvnw test` |

- 실패하면 `decision: block`으로 종료를 막고 로그 마지막 80줄을 Claude에게 돌려준다. Claude는 고치고 다시 끝내려 한다.
- 같은 세션에서 **3번 연속 실패**하면 무한 루프를 막기 위해 경고만 띄우고 종료를 허용한다(`CLAUDE_HARNESS_MAX_BLOCKS`).
- 통과하면 수정 목록을 비워서, 다음 종료 때 같은 검사를 반복하지 않는다.
- 끄기: `CLAUDE_HARNESS_VERIFY=off claude` 또는 `/hooks`.
- 한계: Bash로 수정한 파일(`sed -i` 등)은 추적하지 않는다. 테스트 스위트가 느리면 `.claude/harness/verify.sh`로 범위를 좁힌다.

프로젝트별 검증 예시 (`.claude/harness/verify.sh`):

```bash
#!/usr/bin/env bash
set -e
./gradlew -q :api:compileJava :api:test --tests '*Service*'
pnpm --filter web typecheck
```

### guard-bash.sh (PreToolUse · Bash)

| 판정 | 대상 |
|---|---|
| 차단 | `/`, `~`, `$HOME`, `.`, `..`, `*` 대상 `rm -rf`, `mkfs`/디스크 `dd`, fork bomb, `curl … \| sh` |
| 확인 | `git push --force`/`-f`/`--force-with-lease`/`+ref`/`--delete`, `git reset --hard`, `git clean -f`, `git checkout .`, `git branch -D`, `git stash drop/clear` |
| 확인 | SQL `DROP TABLE/SCHEMA/…`, `TRUNCATE`, `ALTER TABLE … DROP COLUMN`, 조건 없는 `DELETE FROM` |
| 확인 | Flyway/Liquibase/Alembic/Prisma 마이그레이션 적용 |
| 확인 | `.env`를 `cat`/`grep`/`source` 등으로 읽기 (`.env.example` 등 제외) |

정규식 기반 안전망이라 의도적인 우회까지 막지는 못한다. headless 실행(`claude -p`)에서는 "확인"이 사람 없이 거부되므로 루프에서는 사실상 차단이다.

### format.sh (PostToolUse · Write|Edit)

프로젝트에 **설치된** 도구만 쓴다(npx 다운로드 없음). 없거나 실패하면 아무것도 하지 않는다.

| 파일 | 포매터 |
|---|---|
| TS/JS/JSON/CSS/MD/YAML | `biome.json`이 있으면 Biome, 아니면 `node_modules/.bin/prettier` |
| Python | `.venv/bin/ruff` 또는 PATH의 `ruff format` |
| Java | Spotless가 설정된 Gradle 프로젝트면 `spotlessApply -PspotlessIdeHook=<파일>`, 아니면 `google-java-format` |

### permissions.deny

`.env`, `.env.local`, `.env.production`, `*.pem`, `*.key`, SSH 키, `~/.aws/credentials`, `~/.gnupg` 읽기와 `.env` 수정을 차단한다.

### reviewer 서브에이전트

읽기 전용 도구만 가진 독립 리뷰어. 작성자의 설명 없이 범위만 받아 결함을 "실제로 일어나는 경로"와 함께 보고한다. 전역 CLAUDE.md가 여러 파일 변경을 완료로 보고하기 전에 이 에이전트를 쓰도록 지시한다. 직접 부를 때는 "reviewer 에이전트로 이 브랜치 리뷰해 줘".

## 루프

| 루프 | 단위 | 기억 | 언제 |
|---|---|---|---|
| **장기 자율 루프** `claude-loop` | 반복마다 새 headless 세션 | `PLAN.md` · `PROGRESS.md` · git | 몇 시간짜리 작업을 작은 작업 목록으로 나눠 무인 실행 |
| **세션 내 목표 루프** `/goal-loop` | 한 세션 안의 반복 | 할 일 목록 | "테스트 다 통과할 때까지" 같은 단일 목표 |
| **정기 루프** `/loop`, 스케줄 | 주기 실행 | 보고서 | 의존성·테스트 건강 점검 |

### 장기 자율 루프: claude-loop

```bash
cp ~/.claude/loop/PLAN.template.md PLAN.md   # 목표·완료 조건·작업 체크박스 작성
git add PLAN.md && git commit -m "chore: add loop plan"
claude-loop --branch loop/orders-paging        # 작업 브랜치를 만들어 시작
```

각 반복은 새 `claude -p` 세션으로 `prompt.md`를 실행한다: 상태 파악 → 첫 미완료 작업 하나 → 구현 → 검증 → `PLAN.md` 체크 · `PROGRESS.md` 기록 → 커밋 → `<loop-status>` 출력. 이전 반복의 기억은 파일과 git에만 있으므로 컨텍스트가 쌓여 흐려지지 않는다. Stop 훅이 각 반복의 검증을 강제한다.

| 정지 조건 | 기본값 | 종료 코드 |
|---|---|---|
| 남은 작업 0 / 에이전트 DONE | — | 0 |
| 에이전트 BLOCKED (사람 결정 필요) | — | 2 |
| 진전 없는 반복(커밋·계획 변화 없음) 연속 | `--stall 3` | 3 |
| 누적 비용 | `--total-budget 50` (USD) | 4 |
| 최대 반복 | `-n 20` | 5 |
| 반복 1회 비용 / 시간 | `--budget 5` / `--timeout 45`(분) | 다음 반복으로 |

안전장치: 기본·공유 브랜치(`main`, `master`, `develop`, origin 기본 브랜치)에서 실행을 거부하고, 추적 중인 파일에 미커밋 변경이 있으면 시작하지 않는다. 프롬프트가 push·배포·마이그레이션 적용·테스트 무력화를 금지하고, guard 훅이 이를 강제한다. 결과는 사람이 브랜치를 리뷰한 뒤 머지한다.

- 권한 모드 기본값은 `--mode auto`. 계정에서 auto 모드를 쓸 수 없으면 `--mode acceptEdits`에 프로젝트 `.claude/settings.json`의 `permissions.allow`로 테스트·빌드 명령을 허용한다. 격리된 컨테이너가 아니면 `bypassPermissions`는 쓰지 않는다.
- 다른 작업과 병행하려면 `git worktree add ../app-loop -b loop/x` 후 그 디렉터리에서 실행한다.
- 로그: `.claude/loop/logs/<시각>/` (`summary.tsv`, 반복별 JSON). git에는 들어가지 않는다(`.git/info/exclude`).
- 알림: `--notify 'notify-send claude-loop'`처럼 종료 시 실행할 명령을 지정한다.
- 프로젝트별 프롬프트: `.claude/loop/prompt.md`가 있으면 전역 템플릿 대신 쓴다.

좋은 계획의 조건: 작업 하나가 한 세션에 끝나는 크기, 작업마다 검증 방법이 분명, 완료 조건이 명령으로 확인 가능.

### 세션 내 목표 루프: /goal-loop

```
/goal-loop OrderServiceTest 전부 통과 --check "./gradlew :api:test --tests '*OrderService*'" --max 6
```

목표·검증 명령·최대 반복·범위를 먼저 정하고, 진단 → 가설 → 최소 수정 → 검증을 반복한다. 같은 접근을 반복하지 않고, 지표가 나빠지면 되돌리며, 2회 연속 개선이 없으면 멈추고 보고한다.

### 정기 루프

세션이 열려 있는 동안 주기 실행:

```
/loop 1d /deps-audit
/loop 12h /test-health --runs 3
```

세션과 무관하게 돌리려면 claude.ai의 Routines(클라우드 스케줄)나 cron + headless를 쓴다:

```cron
# 평일 08:47 의존성 점검 보고서를 파일로 남김
47 8 * * 1-5 cd ~/work/app && claude -p "/deps-audit" --permission-mode auto < /dev/null > ~/reports/deps-$(date +\%F).md 2>&1
```

## 설계 원칙

- **CLAUDE.md는 짧게.** 매 세션 컨텍스트에 통째로 들어가므로 한 줄 한 줄이 비용이다. 코드만 봐서는 알 수 없는 것, Claude가 실제로 틀렸던 것만 적는다.
- **스택별 규칙은 `rules/`로 분리.** `paths` 프런트매터가 있는 규칙은 해당 파일을 다룰 때만 로드된다.
- **스킬은 필요할 때만 로드된다.** 평소에는 이름과 설명만 컨텍스트에 있으므로 긴 절차를 CLAUDE.md 대신 스킬에 둔다.
- **지시문 → 스킬 → 훅 순으로 강해진다.** 반드시 지켜야 하는 규칙(검증, 포매팅, 위험 명령)은 훅으로 옮긴다. 지시문은 모델이 무시할 수 있지만 훅은 하네스가 실행한다.
- **피드백은 기계가 읽을 수 있게.** Stop 훅은 "실패했다"가 아니라 실패 로그를 돌려주고, 루프는 `<loop-status>`와 체크박스로 상태를 판정한다.
- **장기 작업의 기억은 파일에.** 컨텍스트는 압축되고 세션은 끝난다. 계획·진행·결정은 `PLAN.md`/`PROGRESS.md`/커밋에 남기고, SessionStart 훅이 다시 읽어 준다.
- **모든 루프에는 정지 조건이 있다.** 최대 반복, 비용 상한, 진전 없음 감지, BLOCKED 신호.
- **자율성: 높음 + 안전장치.** 되돌리기 어려운 작업(push, 삭제, 마이그레이션 적용, 배포)만 사람이 확인한다.

## 유지보수

- Claude가 같은 실수를 반복하면 해당 범위(전역/규칙/프로젝트)에 한 줄 추가한다.
- 지켜지지 않는 규칙은 더 강하게 쓰기보다 훅으로 옮기는 것을 먼저 검토한다.
- 루프가 BLOCKED나 진전 없음으로 멈추면 `PROGRESS.md`를 읽고, 원인이 계획(작업이 너무 큼, 완료 조건 모호)인지 하네스(검증 누락, 권한 부족)인지 구분해 고친다.
- 분기마다 한 번 읽어 보고 더 이상 필요 없는 줄은 지운다.
