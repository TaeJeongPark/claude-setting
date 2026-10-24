---
paths:
  - "**/*.java"
  - "**/*.kt"
  - "**/build.gradle*"
  - "**/settings.gradle*"
  - "**/pom.xml"
  - "**/application*.yml"
  - "**/application*.yaml"
  - "**/application*.properties"
---

# Java / Spring Boot

## 빌드와 검증

- 빌드는 저장소의 wrapper(`./gradlew`, `./mvnw`)로 실행한다. 시스템에 설치된 gradle/mvn을 쓰지 않는다.
- 변경 후 관련 모듈의 컴파일과 테스트를 돌린다(`./gradlew :module:test --tests '...'`처럼 범위를 좁힌다). 프로젝트에 정적 분석(Checkstyle, Spotless, SpotBugs 등)이 있으면 함께 돌린다.
- Java 버전과 언어 기능(record, sealed, switch 패턴 매칭, virtual thread)은 빌드 설정의 toolchain 버전 안에서 쓴다.

## 설계

- 생성자 주입만 쓴다(`final` 필드 + 생성자, 또는 Lombok `@RequiredArgsConstructor`). 필드 `@Autowired`를 쓰지 않는다.
- 레이어를 지킨다: Controller(HTTP 변환, 검증) → Service(비즈니스 로직, 트랜잭션) → Repository/Mapper(데이터 접근). Controller에서 Repository를 직접 호출하지 않는다.
- Entity를 API 응답으로 직접 노출하지 않는다. 요청·응답 DTO를 분리하고, DTO는 가능하면 `record`로 만든다.
- 요청 검증은 Bean Validation(`@Valid`, `@NotNull` 등)으로 하고, 예외는 `@RestControllerAdvice`에서 일관된 형식으로 변환한다.
- 설정값은 `@ConfigurationProperties`로 묶는다. 비밀값을 `application.yml`에 하드코딩하지 않는다.
- Lombok은 프로젝트가 이미 쓸 때만 쓴다. Entity에 `@Data`를 쓰지 않는다(equals/hashCode, toString 순환 참조 문제).

## 트랜잭션

- `@Transactional`은 Service 계층의 public 메서드에 단다. 조회 전용은 `@Transactional(readOnly = true)`.
- 같은 클래스 안에서 자기 메서드를 호출하면 프록시를 거치지 않아 `@Transactional`이 적용되지 않는다는 점에 주의한다.
- 트랜잭션 안에서 외부 API 호출이나 오래 걸리는 작업을 하지 않는다.

## 테스트

- 단위 테스트는 JUnit 5 + AssertJ(+ Mockito)로 쓴다. 슬라이스 테스트(`@WebMvcTest`, `@DataJpaTest`, `@MybatisTest`)를 `@SpringBootTest`보다 우선한다.
- DB가 필요한 통합 테스트는 프로젝트가 Testcontainers를 쓰면 실제 PostgreSQL로 돌린다. H2로 PostgreSQL 전용 문법을 테스트하지 않는다.
