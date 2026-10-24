---
name: verify
description: 현재 프로젝트의 빌드·타입 체크·린트·테스트를 감지해서 실행하고 결과를 요약한다. 작업을 "완료"라고 보고하기 전, 커밋이나 PR 전, 또는 사용자가 "검증해 줘", "테스트 돌려 줘", "다 통과하는지 봐 줘"라고 할 때 사용한다.
---

# 프로젝트 검증

변경된 범위에 맞는 검사를 찾아 실행하고, 통과·실패를 그대로 보고한다.

## 1. 검사 명령 찾기

먼저 프로젝트 `CLAUDE.md`의 명령어 표를 확인한다. 없으면 아래 순서로 감지한다(모노레포는 변경된 모듈만).

| 단서 | 실행할 검사 |
|---|---|
| `gradlew` | `./gradlew check` (모듈이 여럿이면 `./gradlew :<module>:check`) |
| `mvnw` | `./mvnw -q verify` |
| `package.json` | lockfile로 매니저를 정하고 `typecheck`, `lint`, `test` 스크립트 중 있는 것. `typecheck`가 없고 `tsconfig.json`이 있으면 `tsc --noEmit` |
| `pyproject.toml` | `ruff check`, `ruff format --check`, 설정된 타입 체커(pyright/mypy), `pytest` — uv 프로젝트면 `uv run` 접두 |

변경 파일은 `git diff --name-only HEAD`와 `git status --porcelain`으로 확인한다.

## 2. 실행

- 서로 독립적인 검사는 병렬로 실행한다.
- 오래 걸리는 전체 테스트보다 변경과 관련된 테스트를 먼저 돌리고, 통과하면 전체를 돌린다.
- 출력은 실패 부분만 추린다(`tail`, `grep -A`).
- Testcontainers 등 Docker가 필요한 테스트가 환경 문제로 실패하면 코드 실패와 구분해서 보고한다.

## 3. 실패 처리

- 이번 변경으로 생긴 실패는 원인을 찾아 고친 뒤 같은 검사를 다시 돌린다.
- 변경 전부터 있던 실패인지 의심되면 `git stash`로 확인하지 말고(사용자 변경을 건드리지 않는다) 실패한 테스트가 변경 파일과 관련 있는지로 판단해 보고한다.
- 테스트를 스킵하거나 기대값을 결과에 맞춰 바꾸지 않는다.

## 4. 보고 형식

```
검증 결과
- ✅ typecheck (12s)
- ✅ lint
- ❌ test: FooServiceTest.createsOrder — 기대 201, 실제 400 (원인: …)
남은 일: …
```
