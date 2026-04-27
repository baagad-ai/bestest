# Phase 4 — Generation Detail (Java)

Detailed mocking patterns, @ParameterizedTest usage, @Nested inner classes, complete test file examples, and test data builder patterns for JUnit 5 test generation.

## Mocking patterns

### Unit test with Mockito (preferred for @Service, @Component)

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;

    @Test
    void shouldReturnUser_whenUserExists() {
        // Arrange
        User expected = new User("user-1", "John", "john@example.com");
        when(userRepository.findById("user-1")).thenReturn(Optional.of(expected));

        // Act
        User result = userService.getUser("user-1");

        // Assert
        assertThat(result).isEqualTo(expected);
        verify(userRepository).findById("user-1");
    }
}
```

### Spring Boot controller test with @WebMvcTest

```java
@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Test
    void shouldReturn200_withUser_whenUserExists() throws Exception {
        // Arrange
        User user = new User("user-1", "John", "john@example.com");
        when(userService.getUser("user-1")).thenReturn(user);

        // Act & Assert
        mockMvc.perform(get("/api/users/user-1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("John"))
            .andExpect(jsonPath("$.email").value("john@example.com"));
    }
}
```

### Repository test with @DataJpaTest + Testcontainers

```java
@DataJpaTest
@Testcontainers
class UserRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TestEntityManager entityManager;

    @Test
    void shouldFindUserByEmail_whenUserExists() {
        // Arrange
        User user = new User("user-1", "John", "john@example.com");
        entityManager.persistAndFlush(user);

        // Act
        Optional<User> found = userRepository.findByEmail("john@example.com");

        // Assert
        assertThat(found).isPresent();
        assertThat(found.get().getName()).isEqualTo("John");
    }
}
```

### Integration test with @SpringBootTest

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ApplicationIntegrationTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void contextLoads() {
        // Spring context starts successfully
    }

    @Test
    void shouldReturn200_forHealthEndpoint() {
        ResponseEntity<String> response = restTemplate.getForEntity("/actuator/health", String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
    }
}
```

## Test data builders

Always generate builder methods or factory methods for test data. Never hardcode objects inline in multiple tests.

```java
private User createUser(String id, String name, String email) {
    return new User(id, name, email);
}

private User createDefaultUser() {
    return new User("user-1", "Test User", "test@example.com");
}

private User createDefaultUserWithOverrides(Consumer<User.UserBuilder> overrides) {
    User.UserBuilder builder = User.builder()
        .id("user-1")
        .name("Test User")
        .email("test@example.com");
    overrides.accept(builder);
    return builder.build();
}
```

For classes without builders:
```java
private CreateOrderRequest createOrderRequest(String customerId, List<String> itemIds) {
    CreateOrderRequest request = new CreateOrderRequest();
    request.setCustomerId(customerId);
    request.setItemIds(itemIds);
    return request;
}
```

## @ParameterizedTest patterns

Use `@ParameterizedTest` for data-driven testing of the same behavior with different inputs:

```java
@ParameterizedTest
@CsvSource({
    "100, 20, 80",
    "100, 0, 100",
    "50, 50, 25",
    "0, 20, 0"
})
void shouldCalculateDiscount(double price, double percent, double expected) {
    double result = discountCalculator.calculate(price, percent);
    assertThat(result).isEqualTo(expected);
}
```

For exception-testing with parameterized tests:
```java
@ParameterizedTest
@CsvSource({
    "-10, 20",
    "100, -5",
    "100, 150"
})
void shouldThrowException_forInvalidInput(double price, double percent) {
    assertThatThrownBy(() -> discountCalculator.calculate(price, percent))
        .isInstanceOf(IllegalArgumentException.class);
}
```

Using `@ValueSource` for simple single-parameter tests:
```java
@ParameterizedTest
@ValueSource(strings = {"", " ", "   "})
void shouldThrowException_forBlankName(String name) {
    assertThatThrownBy(() -> validator.validateName(name))
        .isInstanceOf(ValidationException.class);
}
```

Using `@MethodSource` for complex parameter objects:
```java
@ParameterizedTest
@MethodSource("discountScenarios")
void shouldApplyCorrectDiscount(DiscountScenario scenario) {
    double result = discountCalculator.calculate(scenario.getPrice(), scenario.getPercent());
    assertThat(result).isEqualTo(scenario.getExpected());
}

private static Stream<DiscountScenario> discountScenarios() {
    return Stream.of(
        new DiscountScenario(100, 20, 80),
        new DiscountScenario(100, 0, 100),
        new DiscountScenario(50, 50, 25)
    );
}
```

## @Nested inner classes for context grouping

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserService userService;

    @Nested
    class GetUser {

        @Test
        void shouldReturnUser_whenUserExists() {
            // ...
        }

        @Test
        void shouldThrowNotFoundException_whenUserDoesNotExist() {
            // ...
        }
    }

    @Nested
    class CreateUser {

        @Test
        void shouldCreateUser_withValidInput() {
            // ...
        }

        @Test
        void shouldThrowException_whenEmailAlreadyExists() {
            // ...
        }
    }
}
```

## Complete example: well-generated test file

This is the target quality level for every generated file:

```java
package com.example.pricing;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.Mock;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@ExtendWith(MockitoExtension.class)
class DiscountCalculatorTest {

    @Mock
    private PricingRules pricingRules;

    private DiscountCalculator calculator;

    @BeforeEach
    void setUp() {
        calculator = new DiscountCalculator(pricingRules);
    }

    @Nested
    class CalculateDiscount {

        @Test
        void shouldReturnDiscountedPrice_whenPercentageIsValid() {
            assertThat(calculator.calculate(100.0, 20.0)).isEqualTo(80.0);
        }

        @Test
        void shouldReturnFullPrice_whenDiscountIsZero() {
            assertThat(calculator.calculate(50.0, 0.0)).isEqualTo(50.0);
        }

        @Test
        void shouldReturnZero_whenPriceIsZero() {
            assertThat(calculator.calculate(0.0, 20.0)).isEqualTo(0.0);
        }

        @ParameterizedTest
        @CsvSource({
            "-10, 20",
            "100, -5",
            "100, 150"
        })
        void shouldThrowException_forInvalidInput(double price, double percent) {
            assertThatThrownBy(() -> calculator.calculate(price, percent))
                .isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Nested
    class ApplyBulkDiscount {

        @Test
        void shouldApplyTenPercent_forTenOrMoreItems() {
            double result = calculator.applyBulkDiscount(120.0, 12);
            assertThat(result).isEqualTo(108.0);
        }

        @Test
        void shouldReturnFullTotal_forFewerThanTenItems() {
            double result = calculator.applyBulkDiscount(50.0, 5);
            assertThat(result).isEqualTo(50.0);
        }
    }
}
```
