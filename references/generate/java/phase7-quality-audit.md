# Phase 7 — Quality Audit (Java)

Score each generated test file against the assertion quality rubric. Detect anti-patterns from `references/anti-patterns.md` and Java-specific anti-patterns. Run stability testing.

> **Guide:** See `references/java-generation-guide.md` for the Java-specific generation patterns (Mockito, @ParameterizedTest, @Nested, Spring slices, Testcontainers) that inform these scores.

## Step 1: Assertion quality scoring

Score each test file on the 0-100 rubric:

| Dimension | Max Points | What to check |
|-----------|-----------|---------------|
| Assertion Quality | 30 | Specific AssertJ assertions (`assertThat(x).isEqualTo(y)`, `assertThatThrownBy`), not bare `assertThat(result)`. Edge cases covered. Error paths tested with `assertThatThrownBy` or `assertThrows`. |
| Test Structure | 20 | Clear Arrange-Act-Assert. Descriptive names (`shouldX_whenY` or `@DisplayName`). `@Nested` grouping for context. Single concept per test. |
| Independence | 20 | `@BeforeEach` provides fresh state. No shared mutable static fields. Proper mock reset via MockitoExtension. Test order independence. |
| Coverage Value | 15 | Happy path + error paths + boundary values. Tests meaningful branches. No coverage-only tests (tests that exercise code but assert nothing meaningful). |
| Maintainability | 15 | Builder/factory methods for test data. No magic numbers. No hardcoded IDs/dates. Follows project conventions. Constants for repeated values. |

**Scoring process:**
```
For each generated test file:
  Read the test file content.
  Evaluate each dimension:
    +3 per distinct edge case assertion
    +2 per error path assertion (using assertThatThrownBy or assertThrows)
    +2 per test with descriptive name following naming pattern
    +3 per builder/factory method with sensible defaults
    +2 per @ParameterizedTest with meaningful test data
    +2 per @Nested class for context grouping
    -5 per bare `assertThat(result)` on a non-boolean value without further assertion
    -5 per mutable static field modified in test without cleanup
    -3 per test with generic name ('test1', 'testMethod')
    -3 per magic number without constant or comment
    -8 per `assertThat(true).isTrue()` or tautological assertion
    -10 per assertion comparing a value to itself
    -10 per `@Disabled` left in generated code without a linked issue

  Compute total score (0-100).
  If score < quality_threshold * 100 (default: 70):
    Flag file for quality improvement.
    Identify lowest-scoring dimension for targeted fix suggestions.
```

## Step 2: Anti-pattern detection

Run the test smell checks from `references/anti-patterns.md` against each generated test file, PLUS Java-specific anti-patterns:

**Critical checks (zero tolerance — auto-fix):** tautological assertions (`assertThat(true).isTrue()`), hardcoded secrets (passwords, API keys in test data), tests with no assertions, `@Test` methods that only call `verify()` without state assertions.

**High checks (auto-fix when detected):** `Thread.sleep()` in tests (replace with `Awaitility.await()` or proper mock), test interdependencies (shared static mutable state), empty `catch` blocks (use `assertThatThrownBy`), flaky indicators (unmocked `LocalDateTime.now()`, `UUID.randomUUID()`, network calls in unit tests), missing `@ExtendWith(MockitoExtension.class)` when using `@Mock`, using `@MockBean` in non-Spring tests.

**Medium checks (flag for review):** overly broad assertions (bare `assertThat(result).isNotNull()` when specific value is knowable), implementation coupling (accessing private fields via reflection), wrong mock target (mocking interface instead of implementation), missing cleanup (`@TempDir` not cleaned, database rows not deleted), large hardcoded JSON strings (use object builders instead).

**Low checks (style suggestions):** duplicate test logic (use `@ParameterizedTest`), `import org.junit.Test` instead of `import org.junit.jupiter.api.Test` (JUnit 4 import), using `assertEquals(expected, actual)` instead of AssertJ `assertThat(actual).isEqualTo(expected)`, hardcoded ports in `@SpringBootTest` (use `RANDOM_PORT`).

**Auto-fix capability for common smells:**
```
If bare assertThat(result) on non-boolean → add specific assertion (.isEqualTo(expected))
If assertThat(true).isTrue() → replace with specific assertion
If Thread.sleep() → replace with Awaitility.await() or mock
If missing @ExtendWith(MockitoExtension.class) with @Mock present → add the annotation
If JUnit 4 import (org.junit.Test) → replace with org.junit.jupiter.api.Test
If try/catch with empty body → replace with assertThatThrownBy
If assertThat(result).isNotNull() when exact value known → replace with .isEqualTo(expected)
```

## Step 3: Stability testing

```
Run each generated test file 5 times sequentially:
  Gradle: ./gradlew test --tests "com.example.*Test" -x compileJava (5 sequential executions)
  Maven:  ./mvnw test -Dtest="com.example.*Test" (5 sequential executions)

Track results across all 5 runs:
  If any test passes in some runs and fails in others:
    Flag as "flaky" with the inconsistency pattern.
    Common Java causes: unmocked LocalDateTime.now(), UUID.randomUUID(), concurrent state,
    test execution order dependencies, Spring context caching issues, database sequence gaps.
    Attempt auto-fix (mock time/UUID, add @DirtiesContext, reset shared state in @BeforeEach).
    Re-test after fix.
  If all 5 runs produce identical results:
    Mark as "stable".
```

## Step 4: Quality report

```
Assemble quality report for each generated file:
  {
    file: "src/test/java/com/example/service/UserServiceTest.java",
    sourceFile: "src/main/java/com/example/service/UserService.java",
    score: 85,
    dimensions: {
      assertionQuality: 26,
      testStructure: 18,
      independence: 18,
      coverageValue: 13,
      maintainability: 10
    },
    antiPatterns: [],
    stability: "stable",
    coverageDelta: { before: "0%", after: "87%", lines: "+87%", branches: "+72%" },
    testsGenerated: 8,
    testsPassed: 8,
    testsFailed: 0
  }

If score < quality_threshold * 100:
  Print: "Quality score {score} is below threshold {threshold}. Suggested improvements:"
  For the lowest-scoring dimension:
    Print: "  - {dimension}: {score}/{max} — {specific improvement suggestions}"
```

## External Calibration

### Known Limitation: LLM Self-Evaluation Bias

The quality scoring in this phase is performed by the same LLM agent that generated the tests. Research on LLM self-evaluation consistently shows 15–25% optimism bias when models evaluate their own outputs. Tests scoring 70-75 (near the threshold) may actually be 55-65 quality.

### Mitigation: Mutation Testing (Optional Phase 7b)

If Pitest (pitest-maven or pitest-gradle plugin) is configured:

```
1. Run: mvn pitest:mutationCoverage (Maven) or ./gradlew pitest (Gradle)
2. Check mutation score:
   - Score ≥ 60%: Tests are catching real defects. Confidence: HIGH.
   - Score 40-60%: Tests have gaps. Flag for review.
   - Score < 40%: Tests may be exercising mocks, not real code. Flag as low-quality.
3. Add mutation score to the quality report.
```

### Mitigation: Coverage Delta Verification

After Phase 7 scoring, cross-check the quality score against the JaCoCo coverage delta:
- If quality score ≥ 70 but coverage delta is 0% → tests may be exercising mocks only. Downgrade quality score by 10 points.
- If quality score ≥ 70 and coverage delta > 5% → score is plausible.
```
