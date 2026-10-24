# <프로젝트 이름>

<!--
작성 가이드 (다 쓰면 이 주석은 지운다)
- 코드만 봐서는 알 수 없는 것만 적는다. 디렉터리 목록, 일반적인 코딩 원칙은 넣지 않는다.
- 200줄 이하로 유지한다. 특정 경로에만 해당하는 규칙은 .claude/rules/*.md에 `paths`를 지정해 나눈다.
- 반복되는 다단계 작업(배포, 릴리스, 마이그레이션 생성)은 .claude/skills/로 만든다.
- 반드시 지켜야 하는 규칙(포맷, 금지 경로)은 .claude/settings.json의 hooks/permissions로 강제한다.
- 개인 설정(로컬 DB 주소 등)은 CLAUDE.local.md에 적고 .gitignore에 추가한다.
- 해당 없는 섹션은 지운다.
-->

<한두 문장: 이 서비스가 무엇을 하는지, 누가 쓰는지>

## 기술 스택

- 백엔드: Java <버전> / Spring Boot <버전>, Spring Data JPA + MyBatis(<각각 어디에 쓰는지>)
- 프론트엔드: React <버전> + TypeScript, <빌드 도구>, <상태·데이터 패칭 라이브러리>
- DB: PostgreSQL <버전>, 마이그레이션: <Flyway/Liquibase>
- 기타: <Python 배치/스크립트 등>

## 명령어

| 목적 | 명령 |
|---|---|
| 로컬 인프라 | `docker compose up -d` |
| 백엔드 실행 | `./gradlew :api:bootRun` |
| 백엔드 테스트 (단일) | `./gradlew :api:test --tests 'com.example.FooServiceTest'` |
| 백엔드 전체 검증 | `./gradlew check` |
| 프론트 개발 서버 | `pnpm --filter web dev` |
| 프론트 검증 | `pnpm --filter web typecheck && pnpm --filter web lint && pnpm --filter web test` |
| 마이그레이션 생성 | <예: `src/main/resources/db/migration/V<다음번호>__<설명>.sql` 파일 추가> |

변경을 마치기 전에 최소한 "전체 검증" 명령을 통과시킨다.

## 구조와 경계

<!-- 이름만 봐서는 알 수 없는 것만 적는다 -->
- `api/` — <역할>. `web/` — <역할>.
- JPA와 MyBatis 사용 구분: <예: 쓰기와 단건 조회는 JPA, 통계·복잡한 목록 조회는 MyBatis>
- <모듈 간 의존 방향, 다른 모듈에서 직접 import하면 안 되는 패키지>

## 프로젝트 관례

- <예: API 응답은 `ApiResponse<T>`로 감싼다>
- <예: 예외는 `BusinessException(ErrorCode)`로 던진다>
- <예: 브랜치 `feature/<이슈번호>-<설명>`, 커밋 메시지는 한국어 Conventional Commits>

## 주의사항

<!-- 실제로 겪은 함정. Claude가 실수할 때마다 한 줄씩 추가한다 -->
- <예: `legacy/` 패키지는 수정하지 않는다 — 별도 팀 소유>
- <예: 테스트는 Testcontainers를 써서 Docker가 실행 중이어야 한다>
- <예: `generated/` 아래 코드는 `./gradlew generate`로 다시 만든다. 직접 고치지 않는다>

## 참고 문서

<!-- 필요할 때만 읽도록 경로만 남긴다. 항상 읽혀야 하는 문서만 @경로 로 불러온다 -->
- 아키텍처: `docs/architecture.md`
- API 명세: `docs/api.md`
