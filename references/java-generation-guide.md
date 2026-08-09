# Java Test Generation Guide

Java-specific generation guide for the bestest generate pipeline. Complements the shared `references/ai-generation-guide.md` principles with JUnit 5 / Java idioms: build tool commands, mocking with Mockito, parameterized tests, @Nested classes, test data builders, and Spring Boot slice testing.

## Phase 1: Code Analysis (Java)

Analyze a target Java source file for test generation:

### Exports

- **Classes** — every public class is a test target. Record the class name, package, and constructor signature.
- **Methods** — public methods are testable; static methods and utility classes are high-value targets.
- **Fields** — private fields are reachable only through constructors/setters; do not test fields directly.
- **Interfaces / abstract classes** — not directly testable; test concrete implementations.

### Dependencies

Classify constructor/method dependencies:
- **Pure logic** (no external I/O) — no mock needed.
- **Database/Repository** — mock at the repository interface (`@Mock` + `@InjectMocks`).
- **External service / HTTP client** — mock with Mockito; for Spring use `@MockBean` or `@WebMvcTest` slices.
- **Filesystem / network** — mock or use `@TempDir` for filesystem isolation.
- **Time / random** — inject a `Clock` or use a fixed seed.

### Complexity

Estimate cyclomatic complexity from branching (`if`/`switch`/`ternary`), loops, and `try/catch`. Map to test count:
- 1–3 branches → 2–3 tests
- 4–8 → 4–6 tests
- 9–15 → 6–10 tests
- 16+ → 10+ tests (consider suggesting source refactoring)

### Prioritization

Prioritize (for `--critical` and default targeting):
- Controllers and REST endpoints (public API surface)
- Service classes with business logic
- Repository implementations
- Utility/helper classes
- Configuration classes last (often trivial getters)

## Phase 2: Test Strategy Selection

| Code Type | Strategy | Test Structure |
|-----------|----------|----------------|
| **Pure logic** (utility/helper) | Input/output assertions with boundary values | `@ParameterizedTest` with `@CsvSource` or `@MethodSource` |
| **Service class** | Mock collaborators, test method behavior | `@ExtendWith(MockitoExtension.class)` + `@Mock` + `@InjectMocks` |
| **Controller / REST endpoint** | Request/response via MockMvc (Spring) or unit-level | `@WebMvcTest` + MockMvc, or construct controller with mocked deps |
| **Repository** | Integration test with Testcontainers or `@DataJpaTest` | `@DataJpaTest` (Spring Data JPA) or Testcontainers |
| **Exception handling** | Assert thrown exceptions and messages | `assertThrows(ExpectedException.class, () -> ...)` + message assert |

## Phase 3: Data Generation (Java)

### Test Data Builders

Prefer a builder over many constructor arguments:

```java
private static User buildUser() {
    return User.builder()
        .id(1L)
        .name("Alice")
        .email("alice@example.com")
        .build();
}
```

### @ParameterizedTest Patterns

```java
@ParameterizedTest
@CsvSource({
    "0, INVALID",
    "18, ADULT",
    "120, ELDERLY"
})
void classifiesAge(int age, String expected) {
    assertEquals(expected, classifier.classify(age));
}
```

For objects, use `@MethodSource`:

```java
@ParameterizedTest
@MethodSource("ageBatches")
void classifiesBatches(int[] ages, String expected) {
    // ...
}

static Stream<Arguments> ageBatches() {
    return Stream.of(
        Arguments.of(new int[]{10, 15}, "MINOR"),
        Arguments.of(new int[]{18, 30}, "ADULT")
    );
}
```

### Equivalence Classes & Boundaries

For a method accepting an age range 0–150:
- Valid: 0, 1, 75, 149, 150
- Invalid: -1, 151
- Boundary: 0/1 (lower), 149/150 (upper)
- Null input (if not rejected by type system, e.g., wrapped types)

## Phase 4: Test Writing (Java)

### Naming Convention

Follow `[unit] [behavior] when [condition]`:
```
Good: shouldReturnUser_whenIdExists
Good: processPayment_returnsReceipt_onSuccess
Bad:  test1, testMethod, handleError
```

Use `@DisplayName` for human-readable descriptions when method names get long.

### Arrange-Act-Assert Structure

```java
@Test
void shouldReturnDiscountedPrice_whenLoyalCustomer() {
    // Arrange
    Customer customer = Customer.loyal("cust-1");
    Order order = Order.of(customer, 100.0);

    // Act
    double result = pricingService.calculate(order);

    // Assert
    assertEquals(90.0, result, 0.001);
}
```

### Mockito Patterns

```java
@ExtendWith(MockitoExtension.class)
class PaymentServiceTest {
    @Mock
    private PaymentGateway gateway;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private PaymentService paymentService;

    @Test
    void shouldChargeWhenUserHasBalance() {
        // Arrange
        when(userRepository.findById("u1")).thenReturn(Optional.of(user));
        when(gateway.charge(any(), eq(50.0))).thenReturn(true);

        // Act
        boolean ok = paymentService.pay("u1", 50.0);

        // Assert
        assertTrue(ok);
        verify(gateway).charge(any(), eq(50.0));
    }

    @Test
    void shouldReject_whenUserNotFound() {
        when(userRepository.findById("ghost")).thenReturn(Optional.empty());

        assertThrows(NoSuchElementException.class, () -> paymentService.pay("ghost", 50.0));
    }
}
```

### @Nested Classes for Grouping

```java
class PricingServiceTest {
    @Nested
    class HappyPath {
        @Test void appliesLoyaltyDiscount() { /* ... */ }
    }
    @Nested
    class EdgeCases {
        @Test void rejectsNegativeAmount() { /* ... */ }
        @Test void handlesNullCustomer() { /* ... */ }
    }
}
```

### Spring Boot Slice Testing

- `@WebMvcTest(Controller.class)` + `@MockBean` for service dependencies → controller tests.
- `@DataJpaTest` for repository tests (in-memory DB by default).
- `@SpringBootTest` + `TestRestTemplate` or `@AutoConfigureMockMvc` for full-context integration.
- Use `MockMvc` for HTTP-layer assertions:

```java
@WebMvcTest(UserController.class)
class UserControllerTest {
    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Test
    void shouldReturnUser() throws Exception {
        when(userService.find(1L)).thenReturn(Optional.of(user));

        mockMvc.perform(get("/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Alice"));
    }
}
```

### Testcontainers for Integration

When a repository test needs a real database:

```java
@Testcontainers
class UserRepositoryIntegrationTest {
    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    // @DynamicPropertySource to wire the datasource URL
}
```

## Phase 5: Compilation Verification (Java)

- Gradle: `./gradlew compileTestJava` then `./gradlew test`
- Maven: `./mvnw test-compile` then `./mvnw test`
- If compilation fails, add missing imports and (with user approval) missing test-scope dependencies to `build.gradle`/`pom.xml`.

## Phase 6: Execution Verification (Java)

- Run only the generated test class: `./gradlew test --tests "com.example.PaymentServiceTest"` (or `./mvnw test -Dtest=PaymentServiceTest`).
- Parse failures and apply the fix-and-rerun loop from `references/generate/java/phase6-execution.md`.

## Phase 7: Quality Scoring

Score on the 0–100 rubric (Assertion Quality 30, Test Structure 20, Independence 20, Coverage Value 15, Maintainability 15) per `references/generate/java/phase7-quality-audit.md`. Detect Java-specific anti-patterns: over-mocking (`when` on every call), testing private methods via reflection, assert-free tests, `Thread.sleep` in tests, and redundant `@BeforeEach` setup.
