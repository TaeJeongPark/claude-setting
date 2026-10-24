# claude-setting

Claude Code의 개인 전역 설정과 프로젝트용 `CLAUDE.md` 템플릿을 모아 둔 저장소.

## 구성

```
global/
  CLAUDE.md            # ~/.claude/CLAUDE.md — 모든 프로젝트에 적용되는 작업 원칙
  rules/               # ~/.claude/rules/ — 언어·프레임워크별 규칙 (paths로 범위 지정)
    typescript.md  react.md  python.md
    java-spring.md  jpa.md  mybatis.md  postgresql.md
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

새 프로젝트에서는:

```bash
cp ~/claude-setting/templates/project/CLAUDE.md ./CLAUDE.md
cp -r ~/claude-setting/templates/project/.claude ./   # 필요할 때만
```

복사한 뒤 `<...>` 자리를 채우고, 해당 없는 섹션은 지운다. 이미 코드가 있는 프로젝트라면 Claude Code에서 `/init`을 실행해 초안을 만든 다음 템플릿 구조에 맞춰 다듬는 방법도 있다.

## 설계 원칙

- **CLAUDE.md는 짧게.** 매 세션 컨텍스트에 통째로 들어가므로 한 줄 한 줄이 비용이다. 코드만 봐서는 알 수 없는 것, Claude가 실제로 틀렸던 것만 적는다.
- **스택별 규칙은 `rules/`로 분리.** `paths` 프런트매터가 있는 규칙은 해당 파일을 다룰 때만 로드되므로, Java 작업 중에 React 규칙이 컨텍스트를 차지하지 않는다.
- **지시문 → 스킬 → 훅 순으로 강해진다.** 가끔 필요한 절차는 `.claude/skills/`로, 반드시 지켜야 하는 규칙(저장 후 포매터, 위험 명령 차단)은 `settings.json`의 hooks/permissions로 옮긴다. 지시문은 모델이 무시할 수 있지만 훅은 하네스가 실행한다.
- **우선순위.** 프로젝트 `CLAUDE.md` / `.claude/rules/`가 전역 설정보다 우선한다고 전역 파일에 명시해 두었다.
- **자율성: 높음 + 안전장치.** 탐색 → 계획 → 구현 → 검증을 스스로 끝까지 하되, push·삭제·마이그레이션 적용·배포처럼 되돌리기 어려운 작업만 확인받는다.

## 유지보수

- Claude가 같은 실수를 반복하면 해당 범위(전역/규칙/프로젝트)에 한 줄 추가한다. Claude에게 "이걸 CLAUDE.md에 추가해 줘"라고 말해도 된다.
- 지켜지지 않는 규칙은 더 강하게 쓰기보다 훅으로 옮기는 것을 먼저 검토한다.
- 분기마다 한 번 읽어 보고 더 이상 필요 없는 줄은 지운다.
