# Java Framework Decision Tree

Complete framework selection decision tree for Java/JVM repositories. The detection engine uses this tree to populate the `testFrameworks` and `e2eFramework` recommendations in the StackProfile when the primary language is Java.

## Decision Flow

### Step 1: Check for Existing JUnit 5

```
Has useJUnitPlatform() in build.gradle or junit-jupiter in pom.xml?
├─ YES → Check customization depth
│         ├─ Has JUnit 5 extensions (@ExtendWith, custom ParameterResolver)? → Keep JUnit 5
│         ├─ Has @ParameterizedTest, @RepeatedTest, @Nested usage? → Keep JUnit 5 (full feature set)
│         ├─ Has >50 test classes already? → Keep JUnit 5 (migration cost high)
│         └─ Simple setup with <20 test classes? → Keep JUnit 5 (already optimal)
│
│         Rationale: JUnit 5 is the modern standard for Java testing. If it's already
│         configured, the decision is about which extensions and patterns to add, not
│         whether to switch frameworks.
│
│         Coverage: JaCoCo (via Gradle jacoco plugin or Maven jacoco-maven-plugin)
│         Config file: build.gradle (test block) or pom.xml (maven-surefire-plugin)
│
└─ NO → Proceed to Step 2
```

### Step 2: Check for JUnit 4

```
Has junit:junit (non-jupiter) in pom.xml or junit dependency in build.gradle?
├─ YES → Evaluate migration feasibility
│         ├─ Heavy use of @RunWith, @Rule, @ClassRule? → Add JUnit Vintage Engine for
│         │   backward compatibility, start new tests in JUnit 5
│         ├─ Simple test classes with @Test only? → Recommend full JUnit 5 migration
│         │   (annotations are nearly identical, migration is mechanical)
│         └─ Has custom Runners or Rules with complex logic? → Keep JUnit 4 + add
│             JUnit Vintage Engine, plan gradual migration
│
│         Rationale: JUnit 5's JUnit Vintage Engine runs JUnit 4 tests alongside JUnit 5
│         tests. This enables incremental migration without rewriting existing tests. New
│         tests should always use JUnit 5 annotations and extensions.
│
│         Migration path:
│         1. Add junit-vintage-engine dependency (runs existing JUnit 4 tests)
│         2. Add junit-jupiter dependency (for new JUnit 5 tests)
│         3. Configure useJUnitPlatform() in Gradle or surefire-provider in Maven
│         4. New tests use @Test from org.junit.jupiter.api, not org.junit
│
│         Coverage: JaCoCo (works with both JUnit 4 and JUnit 5)
│
└─ NO → Proceed to Step 3
```

### Step 3: Default Recommendation

```
No existing test framework detected.
├─ Any Java project → JUnit 5 (modern standard, superset of JUnit 4)
└─ Reasoning: JUnit 5 is the universal choice for Java testing. Its extension model,
    parameterized tests, nested test classes, and dependency injection support make it
    strictly superior to JUnit 4 for new projects. Even projects using JUnit 4 for
    legacy reasons should run via the JUnit Platform.

    Gradle configuration:
    dependencies {
        testImplementation 'org.junit.jupiter:junit-jupiter:5.10.2'
    }
    test {
        useJUnitPlatform()
    }

    Maven configuration:
    <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>3.2.5</version>
    </plugin>
    <dependency>
        <groupId>org.junit.jupiter</groupId>
        <artifactId>junit-jupiter</artifactId>
        <version>5.10.2</version>
        <scope>test</scope>
    </dependency>
```

### Step 4: Spring Boot Detection

```
Is Spring Boot detected? (spring-boot in build.gradle/pom.xml, @SpringBootApplication in source)
├─ YES → Add testing layers based on application type
│         ├─ Full @SpringBootTest → Integration tests with full application context
│         │   Use for: end-to-end API tests, multi-layer integration
│         │   Requires: @SpringBootTest + @AutoConfigureMockMvc or TestRestTemplate
│         │
│         ├─ @WebMvcTest → Controller slice tests
│         │   Use for: testing individual @Controller or @RestController classes
│         │   Requires: @WebMvcTest(ControllerClass.class) + @MockBean for services
│         │
│         ├─ @DataJpaTest → Repository/DAO slice tests
│         │   Use for: testing JPA repositories, entity mappings, queries
│         │   Requires: @DataJpaTest + Testcontainers for real DB or H2 for unit-speed
│         │
│         ├─ @WebFluxTest → Reactive controller slice tests
│         │   Use for: testing WebFlux @RestController endpoints
│         │   Requires: @WebFluxTest + WebTestClient
│         │
│         └─ Mockito via @MockBean / @SpyBean
│             Use for: isolating units within Spring context
│             @MockBean replaces a bean with a mock in the Spring context
│             @SpyBean wraps a bean with a spy for partial mocking
│
│         Spring Boot test dependencies (automatically included via spring-boot-starter-test):
│         - JUnit 5 (junit-jupiter)
│         - Mockito (mockito-core + mockito-junit-jupiter)
│         - AssertJ (assertj-core)
│         - Spring Test (spring-test)
│         - JSON Path (json-path)
│         - Hamcrest (hamcrest)
│
│         Testcontainers for integration tests:
│         - PostgreSQL: @Testcontainers + @Container with PostgreSQLContainer
│         - Redis: GenericContainer with redis image
│         - Wire via @DynamicPropertySource to inject container properties
│
│         Rationale: Spring Boot's testing infrastructure provides slice annotations
│         that load only the relevant parts of the application context, keeping tests
│         fast and focused. @SpringBootTest loads everything; slice tests load only
│         what's needed.
│
└─ NO → Standard Java testing (no Spring-specific test annotations)
    Pattern: plain JUnit 5 + Mockito + AssertJ
    No Spring context needed — standard unit and integration tests
```

### Step 5: Build Tool Selection

```
Which build tool is detected?
├─ Gradle (build.gradle or build.gradle.kts exists) → Use Gradle test tasks
│         Run: ./gradlew test
│         Coverage: ./gradlew jacocoTestReport
│         Configure:
│           plugins { id 'jacoco' }
│           test { useJUnitPlatform() }
│           jacocoTestReport { dependsOn test }
│         Report path: build/reports/jacoco/test/jacocoTestReport.xml
│         Build cache: ./gradlew test --build-cache for incremental builds
│
├─ Maven (pom.xml exists) → Use Maven surefire/failsafe
│         Run: mvn test
│         Coverage: mvn verify (triggers jacoco:report via plugin)
│         Configure:
│           maven-surefire-plugin 3.2.5+ (JUnit Platform support)
│           jacoco-maven-plugin 0.8.11+ (prepare-agent + report)
│         Report path: target/site/jacoco/jacoco.xml
│
├─ Both exist → Prefer Gradle (more modern, faster incremental builds)
│         Rationale: Gradle's build cache and incremental compilation make it
│         faster for iterative test development. Gradle Kotlin DSL
│         (build.gradle.kts) adds type safety.
│
└─ Neither → Check for wrapper scripts
    gradlew → Gradle project
    mvnw → Maven project
    Neither → Cannot determine build tool, recommend Gradle for new projects
```

### Step 6: Mocking Framework

```
Determine mocking framework based on language and existing dependencies.
├─ Java project (.java source files dominant)
│         ├─ Has mockito-core or mockito-junit-jupiter in dependencies? → Keep Mockito
│         ├─ Spring Boot project? → Mockito already included via spring-boot-starter-test
│         └─ No existing mocking → Mockito (industry standard for Java)
│             Extensions: @ExtendWith(MockitoExtension.class) for JUnit 5 integration
│             Patterns: @Mock, @InjectMocks, when/thenReturn, verify
│
├─ Kotlin project (.kt source files dominant or mixed)
│         ├─ Has mockk in dependencies? → Keep MockK
│         └─ No existing mocking → MockK (idiomatic Kotlin, supports coroutines)
│             Patterns: every/returns, verify, coEvery for suspend functions
│
└─ Mixed Java + Kotlin
    ├─ Kotlin tests → MockK (better coroutine and nullable support)
    └─ Java tests → Mockito (standard for JVM Java)
    Note: Both can coexist in the same project. Use MockitoExtension for Java
    test classes and MockKExtension for Kotlin test classes.

Detection: check source file extensions in src/main/java vs src/main/kotlin.
If Kotlin files >= 30% of total, treat as Kotlin project for mocking defaults.
```

### Step 7: Coverage Provider

```
Determine coverage approach:
├─ Gradle project → JaCoCo via Gradle plugin
│         Configure:
│           plugins { id 'jacoco' }
│           jacoco { toolVersion = "0.8.11" }
│           jacocoTestReport {
│               dependsOn test
│               reports {
│                   xml.required = true
│                   html.required = true
│               }
│           }
│         Run: ./gradlew test jacocoTestReport
│         Report: build/reports/jacoco/test/jacocoTestReport.xml
│         Enforce: jacocoTestCoverageVerification { violationRules { ... } }
│
├─ Maven project → JaCoCo via Maven plugin
│         Configure:
│           <plugin>
│             <groupId>org.jacoco</groupId>
│             <artifactId>jacoco-maven-plugin</artifactId>
│             <version>0.8.11</version>
│             <executions>
│               <execution><goals><goal>prepare-agent</goal></goals></execution>
│               <execution><id>report</id><phase>verify</phase>
│                 <goals><goal>report</goal></goals></execution>
│             </executions>
│           </plugin>
│         Run: mvn verify
│         Report: target/site/jacoco/jacoco.xml
│         Enforce: jacoco:check goal with rules configuration
│
└─ Default → JaCoCo (covers 99% of Java testing scenarios)
    JaCoCo is the standard coverage tool for JVM languages. It supports
    branch coverage, line coverage, and method coverage. It integrates
    with all major build tools and CI platforms.
```

## Confidence Thresholds for Recommendations

| Scenario | Confidence | Explanation |
|----------|------------|-------------|
| Existing JUnit 5 detected → Keep JUnit 5 | 0.95+ | JUnit 5 is already optimal |
| Existing JUnit 4, simple → JUnit 5 migration | 0.80+ | Mechanical migration, JUnit Vintage for compat |
| Existing JUnit 4, complex → Keep + Vintage Engine | 0.85+ | Stability, gradual adoption |
| No existing framework → JUnit 5 | 0.95+ | Modern standard for Java testing |
| Spring Boot detected → @SpringBootTest + slices | 0.90+ | Spring's official testing strategy |
| Gradle detected → Gradle test tasks | 0.90+ | Modern build tool with incremental compilation |
| Maven detected → Maven surefire/failsafe | 0.90+ | Standard Maven testing lifecycle |
| Mockito detected → Keep Mockito | 0.95+ | Industry standard for Java mocking |
| Kotlin detected → MockK | 0.85+ | Idiomatic Kotlin mocking |
| @WebMvcTest detected → Controller slice testing | 0.90+ | Spring's recommended controller test pattern |
| @DataJpaTest detected → Repository slice testing | 0.90+ | Spring's recommended repository test pattern |
| Testcontainers detected → Integration test infra | 0.85+ | Best practice for DB integration tests |

## Decision Summary Table

| Detected Stack | Test Runner | Mocking | Coverage | Test Annotations | Config File |
|----------------|-------------|---------|----------|------------------|-------------|
| Spring Boot (Gradle) | JUnit 5 via Gradle | Mockito + @MockBean | JaCoCo | @SpringBootTest, @WebMvcTest, @DataJpaTest | `build.gradle` |
| Spring Boot (Maven) | JUnit 5 via Maven | Mockito + @MockBean | JaCoCo | @SpringBootTest, @WebMvcTest, @DataJpaTest | `pom.xml` |
| Spring WebFlux (Gradle) | JUnit 5 via Gradle | Mockito + @MockBean | JaCoCo | @SpringBootTest, @WebFluxTest, WebTestClient | `build.gradle` |
| Plain Java (Gradle) | JUnit 5 via Gradle | Mockito | JaCoCo | @Test, @ParameterizedTest, @Nested | `build.gradle` |
| Plain Java (Maven) | JUnit 5 via Maven | Mockito | JaCoCo | @Test, @ParameterizedTest, @Nested | `pom.xml` |
| Kotlin + Spring Boot | JUnit 5 via Gradle | MockK | JaCoCo | @SpringBootTest, @WebMvcTest | `build.gradle.kts` |
| Kotlin (plain) | JUnit 5 via Gradle | MockK | JaCoCo | @Test, @ParameterizedTest | `build.gradle.kts` |
| Existing JUnit 4 (Gradle) | JUnit 5 + Vintage | Mockito | JaCoCo | Mixed JUnit 4/5 | `build.gradle` |
| Existing JUnit 4 (Maven) | JUnit 5 + Vintage | Mockito | JaCoCo | Mixed JUnit 4/5 | `pom.xml` |
| Existing JUnit 5 (Gradle) | JUnit 5 (keep) | Mockito | JaCoCo | Full JUnit 5 feature set | Existing config |
| Existing JUnit 5 (Maven) | JUnit 5 (keep) | Mockito | JaCoCo | Full JUnit 5 feature set | Existing config |
| Monorepo (Gradle) | JUnit 5 per module | Mockito | JaCoCo per module | Per-module testing | Root `settings.gradle` + per-module `build.gradle` |

## ADR Template

When the detection engine makes a framework recommendation, document it as an Architecture Decision Record in `.bestest/adrs/`:

```markdown
# ADR-NNN: [Test Framework Selection]

## Status: Proposed

## Context
- **Languages detected**: [from StackProfile.languages]
- **Java version**: [from StackProfile.runtime.java or "unknown"]
- **Build tool**: [Gradle/Maven from StackProfile.buildTool]
- **Framework**: [Spring Boot/none from StackProfile.frameworks]
- **Existing test framework**: [from StackProfile.testFrameworks.existing or "none"]
- **Kotlin present**: [detected or "none"]

## Decision
Adopt **JUnit 5** for [unit/integration] testing with [Mockito/MockK] and **JaCoCo** for coverage.

## Rationale
[Auto-populated from the decision tree path taken. Example:]
"JUnit 5 is the modern standard for Java testing. Spring Boot detected → spring-boot-starter-test
includes JUnit 5, Mockito, and AssertJ. Slice annotations (@WebMvcTest, @DataJpaTest) enable
focused testing without loading the full application context. JaCoCo provides branch and line
coverage via the Gradle plugin."

## Consequences
- [Specific benefit from the recommendation]
- [Any trade-off or limitation]
- [Migration effort if changing from existing framework]

## Alternatives Considered
- **JUnit 4**: [Legacy, no extension model, @Rule-based workarounds, no nested tests]
- **TestNG**: [Flexible but less Spring Boot integration, smaller community]
- **Spock**: [Groovy-based, excellent for specification-style tests, but adds Groovy dependency]
```

## Integration with Detection Engine

The Java decision tree is evaluated after the detection engine has populated all signal categories. The evaluation follows this sequence:

1. Build the StackProfile from all detected signals (including Java-specific signals)
2. Determine primary language → if Java, use this decision tree instead of python-decision-tree or js-ts-decision-tree
3. Evaluate Step 1–7 in order (short-circuit on first match)
4. Populate `testFrameworks.recommended`, `e2eFramework.recommended`, and `coverage.recommended`
5. Generate ADR if the recommendation differs from existing setup
6. Route to the appropriate spoke command (init, generate, fix)

The decision tree is deterministic: the same StackProfile always produces the same recommendation. This ensures reproducibility and makes the recommendation auditable via the ADR.

## Common Dependency Recommendations by Use Case

| Use Case | Dependency | Why |
|----------|------------|-----|
| Unit testing | junit-jupiter | JUnit 5 core (API + engine) |
| Mocking (Java) | mockito-core + mockito-junit-jupiter | Industry standard mocking with JUnit 5 integration |
| Mocking (Kotlin) | mockk | Idiomatic Kotlin mocking with coroutine support |
| Assertions | assertj-core | Fluent assertions, better readability than JUnit's |
| Spring Boot testing | spring-boot-starter-test | All-in-one: JUnit 5 + Mockito + AssertJ + Spring Test |
| Web layer tests | spring-boot-starter-web | Required for @WebMvcTest and MockMvc |
| JPA tests | spring-boot-starter-data-jpa | Required for @DataJpaTest |
| WebFlux tests | spring-boot-starter-webflux | Required for @WebFluxTest and WebTestClient |
| Testcontainers (core) | testcontainers | Infrastructure for integration tests |
| Testcontainers (JUnit 5) | testcontainers-junit-jupiter | JUnit 5 integration for Testcontainers |
| Testcontainers (PostgreSQL) | testcontainers-postgresql | PostgreSQL container for DB tests |
| Testcontainers (Redis) | testcontainers-redis | Redis container for cache tests |
| Parameterized tests | junit-jupiter-params | @ParameterizedTest, @ValueSource, @CsvSource |
| JSON testing | json-path | JSON response assertion in MockMvc tests |
| Coverage | jacoco (Gradle plugin / Maven plugin) | Line and branch coverage for JVM |
| Parallel execution | junit-platform-launcher config | junit.platform.execution.parallel.enabled=true |
| Legacy JUnit 4 compat | junit-vintage-engine | Run JUnit 4 tests on JUnit 5 Platform |
