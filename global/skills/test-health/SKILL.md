---
name: test-health
description: 테스트 스위트의 건강 상태(실패, 불안정한 flaky 테스트, 느린 테스트, 건너뛴 테스트)를 점검하고 보고한다. 정기 점검 루프(/loop 1d /test-health, 스케줄 실행)나 "테스트 상태 봐 줘", "flaky 테스트 찾아 줘"라는 요청에 사용한다. 기본은 보고만 한다.
argument-hint: [--runs N]
---

# 테스트 건강 점검

## 1. 실행 (기본 3회, `--runs`로 조정)

같은 커밋에서 전체 테스트를 N번 실행하고 결과를 기계가 읽을 수 있는 형태로 남긴다.

| 스택 | 명령 | 결과 위치 |
|---|---|---|
| Gradle | `./gradlew test --rerun-tasks --continue` | `**/build/test-results/test/*.xml` (JUnit XML) |
| Maven | `./mvnw test` | `**/target/surefire-reports/*.xml` |
| Vitest | `vitest run --reporter=junit --outputFile=…` | 지정한 XML |
| Jest | `jest --ci --json --outputFile=…` | 지정한 JSON |
| pytest | `pytest -q --junitxml=…  --durations=20` | 지정한 XML |

매 실행의 결과 파일을 실행 번호별로 복사해 둔다(다음 실행이 덮어쓰므로). 작업 파일은 저장소 밖 임시 디렉터리에 둔다.

## 2. 분석

결과 파일을 파싱해서(짧은 스크립트를 써도 된다) 다음을 뽑는다:

- **항상 실패**: N번 모두 실패 → 실패 메시지 요약, 최근 관련 커밋(`git log -3 -- <파일>`)
- **flaky**: 일부만 실패 → 실패 비율, 실패 메시지 패턴(타임아웃, 순서 의존, 시간·랜덤·공유 상태, Testcontainers 기동)
- **느린 테스트**: 실행 시간 상위 10개, 전체 시간 대비 비율
- **건너뛴 테스트**: `@Disabled`, `skip`, `xfail`, `.only` 잔존 — 이유 주석이 없는 것 위주

## 3. 보고

```
테스트 건강 점검 (커밋 abc123, 3회 실행)
항상 실패 1 · flaky 2 · 건너뜀 5 · 전체 4m12s
flaky:
  - OrderServiceTest.concurrentCreate — 1/3 실패, 타임아웃 (추정: 고정 sleep에 의존)
느린 테스트: …
권장 조치: …
```

## 4. 수정 (요청받은 경우에만)

flaky 테스트를 고칠 때는 원인을 재현(반복 실행, 순서 무작위화)한 뒤 고치고, 같은 반복 횟수로 다시 실행해 안정됐는지 보인다. 테스트를 비활성화하거나 재시도 어노테이션으로 덮는 것은 수정이 아니다.
