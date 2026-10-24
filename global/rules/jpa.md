---
paths:
  - "**/*Entity.java"
  - "**/*Repository.java"
  - "**/entity/**/*.java"
  - "**/domain/**/*.java"
  - "**/repository/**/*.java"
---

# Spring Data JPA

- 연관관계는 기본으로 `fetch = FetchType.LAZY`를 쓴다(`@ManyToOne`, `@OneToOne`은 기본값이 EAGER이므로 명시한다).
- N+1을 경계한다. 컬렉션을 순회하며 지연 로딩하는 코드를 쓸 때는 fetch join, `@EntityGraph`, `default_batch_fetch_size` 중 하나로 해결한다. 컬렉션 fetch join과 페이징을 함께 쓰지 않는다.
- 조회 결과를 API로 내보낼 때는 필요한 컬럼만 DTO projection으로 받는 것을 검토한다.
- Entity의 setter를 열지 않는다. 상태 변경은 의도가 드러나는 도메인 메서드로 한다. 기본 생성자는 `protected`로 둔다.
- 변경 감지(dirty checking)에 맡기고, 이미 영속 상태인 Entity에 불필요한 `save()`를 호출하지 않는다.
- `ddl-auto`는 로컬 개발 외에는 `validate` 또는 `none`이다. 스키마 변경은 마이그레이션 도구(Flyway/Liquibase)로 한다.
- 복잡한 동적 쿼리는 프로젝트가 쓰는 도구(QueryDSL, Criteria, MyBatis)를 따른다. 메서드 이름 쿼리가 길어지면 `@Query`로 바꾼다.
- 대량 수정·삭제는 `@Modifying` 벌크 쿼리를 쓰고, 실행 후 영속성 컨텍스트가 DB와 어긋난다는 점(`clearAutomatically`)을 처리한다.
