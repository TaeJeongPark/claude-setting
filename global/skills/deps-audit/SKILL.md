---
name: deps-audit
description: 프로젝트 의존성의 보안 취약점과 오래된 버전을 점검하고 우선순위를 매겨 보고한다. 정기 점검 루프(/loop 1d /deps-audit, 스케줄 실행)나 "의존성 점검해 줘", "취약점 있는지 봐 줘"라는 요청에 사용한다. 기본은 보고만 하며 업그레이드는 요청이 있을 때만 한다.
---

# 의존성 점검

## 1. 생태계별 점검 (있는 것만, 서로 독립이므로 병렬로)

| 단서 | 취약점 | 오래된 버전 |
|---|---|---|
| `pnpm-lock.yaml` | `pnpm audit --json` | `pnpm outdated --format json` |
| `package-lock.json` | `npm audit --json` | `npm outdated --json` |
| `yarn.lock` | `yarn npm audit --json` (berry) / `yarn audit --json` | `yarn outdated` |
| `uv.lock` / `pyproject.toml` | `uvx pip-audit` (없으면 건너뛰고 보고) | `uv pip list --outdated` |
| `gradlew` | `./gradlew dependencyCheckAnalyze` (플러그인 있을 때) | `./gradlew dependencyUpdates` (ben-manes 플러그인 있을 때) |
| `mvnw` | `./mvnw org.owasp:dependency-check-maven:check` (설정돼 있을 때) | `./mvnw versions:display-dependency-updates` |

플러그인이 설정돼 있지 않은 도구를 새로 추가하지 않는다. 쓸 수 있는 도구가 없으면 그렇다고 보고한다.

## 2. 분류

- **즉시**: 심각도 high/critical 이면서 실제로 쓰는 경로(직접 의존성, 런타임)에 있는 취약점
- **이번 주**: 나머지 취약점, 보안 패치가 포함된 patch/minor 업데이트
- **계획**: major 업데이트 (Spring Boot, React, Java 등 프레임워크급은 별도 작업으로)
- 개발 의존성만의 취약점은 낮게 본다.

## 3. 보고

```
의존성 점검 (YYYY-MM-DD, <프로젝트>)
즉시: 2건
  - jackson-databind 2.15.0 → 2.15.4 (CVE-…, 런타임 직접 의존성)
이번 주: …
계획: Spring Boot 3.3 → 3.5 (major 아님, 마이그레이션 노트 확인 필요)
도구 없음/실패: …
```

이전 점검과 비교할 수 있으면(이전 보고가 대화나 파일에 있으면) 새로 생긴 것과 해결된 것을 표시한다.

## 4. 업그레이드 (요청받은 경우에만)

작업 브랜치를 만들고, patch/minor 업데이트만 묶어서 적용한 뒤 `verify` 스킬로 검증하고 커밋한다. major 업데이트와 push는 하지 않는다.
