# claude-setting

Claude Code의 개인 전역 설정과 프로젝트용 `CLAUDE.md` 템플릿을 모아 둔 저장소.

## 구성

```
global/
  CLAUDE.md            # ~/.claude/CLAUDE.md — 모든 프로젝트에 적용되는 작업 원칙
  settings.json        # ~/.claude/settings.json — hooks, 비밀 파일 읽기 차단
  hooks/
    guard-bash.sh      # 위험한 셸 명령 차단(deny) 또는 확인 강제(ask)
    format.sh          # 파일 수정 후 프로젝트 포매터 자동 실행
  rules/               # ~/.claude/rules/ — 언어·프레임워크별 규칙 (paths로 범위 지정)
    typescript.md  react.md  python.md
    java-spring.md  jpa.md  mybatis.md  postgresql.md
  skills/              # ~/.claude/skills/ — 반복 작업 절차 (/이름 으로 호출하거나 자동 선택)
    verify/            # 프로젝트 검사 감지·실행·요약
    db-migration/      # PostgreSQL 마이그레이션 작성 (무중단 점검 포함, 적용은 안 함)
    pr-ready/          # 셀프 리뷰 → 검증 → PR 초안
templates/project/
  CLAUDE.md            # 새 프로젝트 루트에 복사해서 채우는 템플릿
  .claude/rules/       # 경로 범위 규칙 예시
install.sh             # global/ 을 ~/.claude 에 심볼릭 링크로 설치
```

## 설치

```bash
git clone <이 저장소> ~/claude-setting
~/claude-setting/install.sh
```

심볼릭 링크로 설치하므로 이 저장소에서 수정하고 `git pull`하면 바로 반영된다. 기존 파일은 `*.bak.<타임스탬프>`로 백업된다.
기존 `~/.claude/settings.json`에 개인 설정(테마, 모델, 권한 등)이 있었다면 백업 파일에서 `global/settings.json`으로 옮겨야 한다.
hooks는 `jq`가 필요하다.

## Hooks

**guard-bash.sh** (PreToolUse · Bash)

| 판정 | 대상 |
|---|---|
| 차단 | `/`, `~`, `$HOME`, `.`, `..`, `*` 를 대상으로 한 `rm -rf`, `mkfs`/디스크 `dd`, fork bomb, `curl … \| sh` |
| 확인 | `git push --force`/`-f`/`--force-with-lease`/`+ref`/`--delete`, `git reset --hard`, `git clean -f`, `git checkout .`, `git branch -D`, `git stash drop/clear` |
| 확인 | SQL의 `DROP TABLE/SCHEMA/…`, `TRUNCATE`, `ALTER TABLE … DROP COLUMN`, 조건 없는 `DELETE FROM` |
| 확인 | Flyway/Liquibase/Alembic/Prisma 마이그레이션 적용 명령 |
| 확인 | `.env` 파일을 `cat`/`grep`/`source` 등으로 읽기 (`.env.example` 등은 제외) |

정규식 기반 안전망이라 의도적인 우회까지 막지는 못한다. 기본 권한 확인과 함께 쓰는 보조 장치다.

**format.sh** (PostToolUse · Write|Edit) — 프로젝트에 **설치된** 도구만 쓴다.

| 파일 | 포매터 |
|---|---|
| TS/JS/JSON/CSS/MD/YAML | `biome.json`이 있으면 Biome, 아니면 `node_modules/.bin/prettier` |
| Python | `.venv/bin/ruff` 또는 PATH의 `ruff format` |
| Java | Spotless가 설정된 Gradle 프로젝트면 `spotlessApply -PspotlessIdeHook=<파일>`, 아니면 PATH의 `google-java-format` |

포매터가 없으면 아무것도 하지 않고, 실패해도 작업을 막지 않는다. 훅을 끄려면 `/hooks`에서 끄거나 `settings.json`에서 해당 항목을 지운다.

**permissions.deny** — `.env`, `.env.local`, `.env.production`, `*.pem`, `*.key`, SSH 키, `~/.aws/credentials`, `~/.gnupg` 읽기를 차단한다. 프로젝트별로 더 필요하면 프로젝트 `.claude/settings.json`에 추가한다.

새 프로젝트에서는:

```bash
cp ~/claude-setting/templates/project/CLAUDE.md ./CLAUDE.md
cp -r ~/claude-setting/templates/project/.claude ./   # 필요할 때만
```

복사한 뒤 `<...>` 자리를 채우고, 해당 없는 섹션은 지운다. 이미 코드가 있는 프로젝트라면 Claude Code에서 `/init`을 실행해 초안을 만든 다음 템플릿 구조에 맞춰 다듬는 방법도 있다.

## 설계 원칙

- **CLAUDE.md는 짧게.** 매 세션 컨텍스트에 통째로 들어가므로 한 줄 한 줄이 비용이다. 코드만 봐서는 알 수 없는 것, Claude가 실제로 틀렸던 것만 적는다.
- **스택별 규칙은 `rules/`로 분리.** `paths` 프런트매터가 있는 규칙은 해당 파일을 다룰 때만 로드되므로, Java 작업 중에 React 규칙이 컨텍스트를 차지하지 않는다.
- **스킬은 필요할 때만 로드된다.** 평소에는 이름과 설명만 컨텍스트에 있고, 호출되거나 요청과 맞을 때 본문을 읽는다. 그래서 긴 절차를 CLAUDE.md 대신 스킬에 둔다.
- **지시문 → 스킬 → 훅 순으로 강해진다.** 가끔 필요한 절차는 `.claude/skills/`로, 반드시 지켜야 하는 규칙(저장 후 포매터, 위험 명령 차단)은 `settings.json`의 hooks/permissions로 옮긴다. 지시문은 모델이 무시할 수 있지만 훅은 하네스가 실행한다.
- **우선순위.** 프로젝트 `CLAUDE.md` / `.claude/rules/`가 전역 설정보다 우선한다고 전역 파일에 명시해 두었다.
- **자율성: 높음 + 안전장치.** 탐색 → 계획 → 구현 → 검증을 스스로 끝까지 하되, push·삭제·마이그레이션 적용·배포처럼 되돌리기 어려운 작업만 확인받는다.

## 유지보수

- Claude가 같은 실수를 반복하면 해당 범위(전역/규칙/프로젝트)에 한 줄 추가한다. Claude에게 "이걸 CLAUDE.md에 추가해 줘"라고 말해도 된다.
- 지켜지지 않는 규칙은 더 강하게 쓰기보다 훅으로 옮기는 것을 먼저 검토한다.
- 분기마다 한 번 읽어 보고 더 이상 필요 없는 줄은 지운다.
