---
paths:
  - "**/*.sql"
  - "**/db/**"
  - "**/migration/**"
  - "**/migrations/**"
  - "**/*Mapper.xml"
---

# PostgreSQL

## 스키마와 마이그레이션

- 스키마 변경은 마이그레이션 파일(Flyway, Liquibase, Alembic, Prisma 등 프로젝트 도구)로만 한다. 이미 적용된 마이그레이션 파일은 수정하지 않고 새 파일을 추가한다.
- 마이그레이션을 실제 DB에 적용하는 일은 확인을 받은 뒤에 한다.
- 운영 테이블 변경은 락을 고려한다: 인덱스는 `CREATE INDEX CONCURRENTLY`, NOT NULL 컬럼 추가는 nullable 추가 → 백필 → 제약 추가 순서로 나눈다. 컬럼 삭제·이름 변경은 애플리케이션 배포와 순서를 맞춘다.
- 타입: 기본키는 `bigint generated always as identity` 또는 UUID(프로젝트 관례), 시각은 `timestamptz`, 문자열은 `text`(길이 제한이 비즈니스 규칙일 때만 `varchar(n)`), 금액은 `numeric`.
- 외래키 컬럼에는 인덱스를 만든다.

## 쿼리

- 값은 항상 파라미터로 바인딩한다.
- 새로 쓰거나 바꾼 무거운 쿼리는 `EXPLAIN (ANALYZE, BUFFERS)`로 실행 계획을 확인한다. 운영 DB에서는 `ANALYZE`가 실제로 쿼리를 실행한다는 점에 주의한다.
- 대량 `UPDATE`/`DELETE`는 배치로 나누고, 실행 전에 `SELECT count(*)`로 대상 행 수를 확인한다.
- 큰 테이블 페이징은 `OFFSET`보다 키셋(커서) 페이징을 우선한다.
- 운영·스테이징 DB에 쓰기 쿼리를 실행하지 않는다(확인받은 경우 제외). 조회는 가능하면 읽기 전용 계정이나 레플리카로 한다.
