---
paths:
  - "**/*Mapper.xml"
  - "**/*Mapper.java"
  - "**/mapper/**"
  - "**/mybatis/**"
---

# MyBatis

- 값 바인딩은 항상 `#{}`를 쓴다. `${}`는 SQL 인젝션 위험이 있으므로 정렬 컬럼명처럼 바인딩이 불가능한 경우에만 쓰고, 그때는 Java 쪽에서 허용 목록(whitelist)으로 검증한 값만 넘긴다.
- 동적 SQL은 `<where>`, `<set>`, `<if>`, `<choose>`, `<foreach>`로 만든다. `WHERE 1=1` 같은 꼼수를 새로 쓰지 않는다.
- `<foreach>`로 `IN` 절을 만들 때 빈 컬렉션이 들어오는 경우를 처리한다(빈 `IN ()`은 문법 오류).
- 결과 매핑은 `resultMap`을 명시하거나 `mapUnderscoreToCamelCase` 설정을 따른다. `SELECT *`를 쓰지 않고 컬럼을 나열한다.
- Mapper 인터페이스의 메서드명과 XML의 `id`, `namespace`가 일치하는지 확인한다. 파라미터가 두 개 이상이면 `@Param`을 단다.
- 같은 프로젝트에서 JPA와 MyBatis를 함께 쓰면, 한 트랜잭션 안에서 JPA로 변경한 내용이 flush되기 전에 MyBatis로 조회하면 반영되지 않는다는 점에 주의한다.
- 쿼리를 바꾸면 Mapper 테스트(`@MybatisTest` 또는 통합 테스트)로 실제 실행을 확인한다.
