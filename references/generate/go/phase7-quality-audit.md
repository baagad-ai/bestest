# Phase 7 Quality Audit — Go

Score each generated test file against the assertion quality rubric from `references/go-generation-guide.md`. Detect anti-patterns from `references/anti-patterns.md` and Go-specific anti-patterns. Run stability testing.

## Step 1: Assertion Quality Scoring

Score each test file on the 0-100 rubric from `references/go-generation-guide.md`:

| Dimension | Max Points | What to check |
|-----------|-----------|---------------|
| Assertion Quality | 30 | Specific assertions (`assert.Equal`, `require.NoError`, `assert.Contains`), not bare `assert.True(t, ok)` on non-boolean values. Edge cases covered. Error paths tested with `require.Error` + `assert.Contains`. |
| Test Structure | 20 | Clear Arrange-Act-Assert. Descriptive names (`Test{Unit}_{Behavior}_when_{Condition}`). Table-driven pattern for parameterized cases. Single concept per test. |
| Independence | 20 | Fresh instances per test. No shared package-level mutable variables. Proper cleanup via `t.Cleanup`. No test order dependencies. |
| Coverage Value | 15 | Happy path + error paths + boundary values. Tests meaningful branches. No coverage-only tests (tests that call code but assert nothing). |
| Maintainability | 15 | Helper functions for data construction. No magic numbers. No hardcoded IDs/dates. Follows Go conventions. Named test cases in table-driven tests. |

**Scoring process:**
```
For each generated test file:
  Read the test file content.
  Evaluate each dimension using the scoring adjustments from go-generation-guide.md:
    +3 per distinct edge case assertion
    +2 per error path assertion (using require.Error + assert.Contains or assert.ErrorIs)
    +2 per test with descriptive name following the Test{Unit}_{Behavior}_when_{Condition} pattern
    +3 per helper function with sensible defaults and override support
    +3 per properly structured table-driven test with named cases
    -5 per bare assert.True(t, ok) on a non-boolean value
    -5 per package-level mutable variable modified without t.Cleanup reset
    -3 per test with generic name ('TestWorks', 'Test1')
    -3 per magic number without an explanatory comment or named constant
    -8 per assert.True(t, true) or tautological assertion
    -10 per assertion comparing a value to itself
    -10 per t.Skip left in generated code without a linked issue comment

  Compute total score (0-100).
  If score < quality_threshold * 100 (default: 70):
    Flag file for quality improvement.
  Identify lowest-scoring dimension for targeted fix suggestions.
```

## Step 2: Anti-Pattern Detection

Run the 20 test smell checks from `references/anti-patterns.md` against each generated test file, PLUS the Go-specific anti-patterns from `references/go-generation-guide.md`:

**Critical checks (zero tolerance — auto-fix):** tautological assertions (`assert.True(t, true)`), hardcoded secrets (passwords, API keys in test data), tests with no assertions (`Test` function with no `assert.*` or `require.*` calls), unchecked error returns (`_` for error values), unused imports (Go compiler rejects these), race conditions in tests (detected by `-race` flag).

**High checks (auto-fix when detected):** `time.Sleep` in tests (replace with `require.Eventually` or channel-based waiting), test interdependencies (shared package-level mutable state without `t.Cleanup`), goroutine leaks (started goroutines not tracked), flaky indicators (unmocked `time.Now()`, unmocked HTTP calls, uncontrolled concurrency), missing `t.Helper()` on custom assertion helpers, bare `t.Error`/`t.Fatal` without structured assertions when testify is available.

**Medium checks (flag for review):** overly broad assertions (`assert.True(t, ok)` on non-boolean values, `assert.NotNil` when exact value is knowable), implementation coupling (accessing unexported fields via reflection), overly broad `mock.Anything` usage, table-driven tests without named `name` fields, missing `t.Parallel()` for independent long-running tests.

**Low checks (style suggestions):** duplicate test logic (use table-driven tests), non-descriptive test names (`Test1`, `TestFunction`), hardcoded struct literals repeated across tests, hardcoded file paths (use `t.TempDir()`), using `log` instead of `t.Log` in tests.

**Auto-fix capability for common smells:**
```
If bare assert.True(t, ok) on non-boolean → replace with assert.Equal(t, expected, actual)
If assert.True(t, true) or tautological → replace with specific assertion
If time.Sleep() in test → replace with require.Eventually or channel-based waiting
If unchecked error return (_ = ...) → add require.NoError or require.Error
If missing t.Helper() on custom helper → add t.Helper() call at function start
If assert result is not None when exact value known → replace with specific value assertion
If hardcoded file path → replace with t.TempDir()
If using log.Printf in test → replace with t.Logf
```

## Step 3: Stability Testing

```
Run each generated test file 5 times sequentially:
  Command: go test -v -count=1 ./path/to/package/ (5 sequential executions)
  Note: -count=1 disables test caching to ensure genuine re-execution.

Track results across all 5 runs:
  If any test passes in some runs and fails in others:
    Flag as "flaky" with the inconsistency pattern.
    Common Go causes: unmocked time.Now(), unmocked HTTP calls, filesystem state,
    shared package-level variables, goroutine timing, unbuffered channel blocking,
    test execution order dependencies.
    Attempt auto-fix (mock time/random, use t.TempDir, reset shared state in t.Cleanup, add proper synchronization).
    Re-test after fix.
  If all 5 runs produce identical results:
    Mark as "stable".
```

## Step 4: Quality Report

```
Assemble quality report for each generated file:
  {
    file: "calc/discount_test.go",
    sourceFile: "calc/discount.go",
    score: 88,
    dimensions: {
      assertionQuality: 26,
      testStructure: 18,
      independence: 18,
      coverageValue: 14,
      maintainability: 12
    },
    antiPatterns: [],
    stability: "stable",
    raceFree: true,
    coverageDelta: { before: "0%", after: "92%", statements: "+92%", functions: "+100%" },
    testsGenerated: 6,
    testsPassed: 6,
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

If `gremlins` is available:

```
1. Run: gremlins unleash
2. Check mutation score:
   - Score ≥ 60%: Tests are catching real defects. Confidence: HIGH.
   - Score 40-60%: Tests have gaps. Flag for review.
   - Score < 40%: Tests may be exercising mocks, not real code. Flag as low-quality.
3. Add mutation score to the quality report.
```

### Mitigation: Coverage Delta Verification

After Phase 7 scoring, cross-check the quality score against the `go test -coverprofile` delta:
- If quality score ≥ 70 but coverage delta is 0% → tests may be exercising mocks only. Downgrade quality score by 10 points.
- If quality score ≥ 70 and coverage delta > 5% → score is plausible.
```
