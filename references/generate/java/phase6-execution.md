# Phase 6 — Execution Verification (Java)

Run generated tests, analyze failures, and fix tests (never source code) in a controlled retry loop.

## Execution

```
# Global iteration budget check
global_iterations += 1
if global_iterations > generation.max_iterations (default: 10):
  Emit diagnostic summary (see Global Iteration Budget in references/generate/pipeline-shared.md).
  Halt. Do not proceed with this phase.

If generation.verify_pass is true:
  Run generated tests using the build tool.

  Gradle command: ./gradlew test --tests "com.example.package.TestClass" --console=plain
  Maven command:  ./mvnw test -Dtest="com.example.package.TestClass"

  Parse output for pass/fail/error counts and failure messages.

  Gradle exit codes:
    0 — Build successful (all tests passed)
    1 — Build failed (compilation or test failures)
    2 — Build failed with exceptions

  Maven exit codes:
    0 — Build successful (all tests passed)
    1 — Build failed (compilation or test failures)

  Handle outcomes:
    All tests pass: proceed to coverage check.
    Test failures: enter fix-and-rerun loop.
    Spring context fails to start: see Error Handling scenario 8.
    No tests discovered: check class naming (*Test.java), check @Test annotations.

Else:
  Skip this phase. Proceed to Phase 7.
```

## Failure analysis

When a test fails, determine the root cause:

| Root Cause | Detection | Action |
|-----------|-----------|--------|
| **Test bug** | `AssertionError` with wrong expected value, mock misconfigured, wrong stub setup | Fix the test |
| **Source bug** | Source throws/returns unexpected value that the test correctly identifies | Do NOT fix source. Document behavior. Present to user. |
| **Environment** | Missing env var, missing Spring profile, wrong database URL | Fix test environment setup |
| **Spring context failure** | `BeanCreationException`, `NoSuchBeanDefinitionException`, `UnsatisfiedDependencyException` | Add `@MockBean` for missing beans, or narrow test scope with slice annotations |
| **Timeout** | Test exceeds default timeout, unmocked blocking operation | Add `@Timeout` annotation, mock slow dependencies |
| **NullPointerException** | Mock returns null when value expected | Add `when(mock.method()).thenReturn(value)` stub |
| **Missing test data** | Database query returns empty, mock not configured for the test case | Add test data setup or mock return value |

## Fix-and-rerun loop

```
retry_count = 0
max_retries = generation.max_retries (default: 2)

while tests fail AND retry_count < max_retries:
  retry_count += 1
  For each failing test:
    Read the failure output (exception message, expected vs actual, stack trace).
    Determine root cause using the table above.
    If "test bug": fix assertion, mock setup, add stub, update expected value.
    If "source bug": add comment `// NOTE: Source behavior documented for regression detection.` Adjust test to pass with current behavior. Flag in HITL report.
    If "environment": fix test setup (add @TestPropertySource, @MockBean, @ActiveProfiles).
    If "Spring context failure": add @MockBean for missing beans, or switch to narrower slice test (@WebMvcTest instead of @SpringBootTest).
    If "NullPointerException": add mock stub for the missing return value.
  Re-run tests.
  If all tests pass: break.

If tests still fail after max_retries:
  Print: "Tests failed after {max_retries} fix attempts for {test-file}."
  Print: "Remaining failures:"
  For each still-failing test:
    Print: "  - {test name}: {failure message}"
  Print: "These tests will be presented to the user for manual resolution."
  Mark these tests as "execution-failed" in the generation report.
```

## Coverage delta verification

After all tests pass (or retry loop completes):

```
Run JaCoCo coverage on the specific test class to measure contribution:

Gradle: ./gradlew test jacocoTestReport --tests "com.example.package.TestClass"
Maven:  ./mvnw verify -Dtest="com.example.package.TestClass"

Parse JaCoCo XML report (build/reports/jacoco/test/jacocoTestReport.xml or target/site/jacoco/jacoco.xml).

For each generated test file:
  Compare coverage delta (before → after) for the source class it tests.
  If coverage delta is 0% and tests pass:
    Print: "Warning: {test-file} passes but contributes no coverage to {source-file}."
    Print: "Tests may be testing mock behavior instead of real code."
    Flag for quality review in Phase 7.
  If JaCoCo is not configured:
    Print: "JaCoCo not configured. Skipping coverage verification."
    Print: "Add JaCoCo: plugins { id 'jacoco' } in build.gradle"
    Continue without coverage data. Phase 7 will skip Coverage Value scoring.
```
