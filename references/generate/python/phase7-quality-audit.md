# Phase 7 — Quality Audit (Python)

On-demand sub-file for `spoke-generate-python.md`. Contains assertion quality scoring, anti-pattern detection, flakiness testing, and quality report generation.

---

## Step 1: Assertion quality scoring

Score each test file on the 0-100 rubric from `references/python-generation-guide.md`:

| Dimension | Max Points | What to check |
|-----------|-----------|---------------|
| Assertion Quality | 30 | Specific assertions (`==`, `pytest.raises`), not bare `assert result` on non-booleans. Edge cases covered. Error paths tested. |
| Test Structure | 20 | Clear Arrange-Act-Assert. Descriptive names (`test_{unit}_{behavior}_when_{condition}`). Single concept per test. |
| Independence | 20 | Fixtures provide fresh state. No shared mutable variables. Proper mock cleanup via `mocker` or `yield` fixtures. |
| Coverage Value | 15 | Happy path + error paths + boundary values. Tests meaningful branches. No coverage-only tests. |
| Maintainability | 15 | Factory functions for data. No magic numbers. No hardcoded IDs/dates. Follows project conventions. |

**Scoring process:**
```
For each generated test file:
  Read the test file content.
  Evaluate each dimension using the scoring adjustments from python-generation-guide.md:
    +3 per distinct edge case assertion
    +2 per error path assertion (using pytest.raises)
    +2 per test with descriptive name following pattern
    +3 per factory function with sensible defaults
    -5 per bare `assert result` on a non-boolean value
    -5 per module-level mutable variable modified without fixture reset
    -3 per test with generic name ('test_works', 'test_1')
    -3 per magic number without comment or named constant
    -8 per `assert True` or tautological assertion
    -10 per assertion comparing a value to itself
    -10 per `@pytest.mark.skip` or `pytest.skip()` left in committed code without a linked issue

  Compute total score (0-100).
  If score < quality_threshold * 100 (default: 70):
    Flag file for quality improvement.
    Identify lowest-scoring dimension for targeted fix suggestions.
```

---

## Step 2: Anti-pattern detection

Run the 20 test smell checks from `references/anti-patterns.md` against each generated test file, PLUS the Python-specific anti-patterns from `references/python-generation-guide.md`:

**Critical checks (zero tolerance — auto-fix):** tautological assertions, hardcoded secrets, missing assertions.

**High checks (auto-fix when detected):** sleep-based waits (`time.sleep` in tests), test interdependencies (shared module-level mutable state), empty except blocks (should use `pytest.raises`), flaky indicators (unmocked `datetime.now`, `random.random`, network calls), missing `@pytest.mark.asyncio` on async tests, missing `@pytest.mark.django_db` on ORM tests.

**Medium checks (flag for review):** overly broad assertions (bare `assert result` on non-boolean), implementation coupling (accessing `_private` attributes), wrong mock target path (patching where defined instead of used), missing cleanup (fake timers, env vars, temp files), snapshot drift (large hardcoded expected dicts).

**Low checks (style suggestions):** duplicate test logic (use `@pytest.mark.parametrize`), non-`test_` prefixed test functions (won't be collected), using `unittest.TestCase` in pytest, hardcoded file paths (use `tmp_path` fixture).

**Auto-fix capability for common smells:**
```
If bare `assert result` on non-boolean → replace with `assert result == expected_value`
If `assert True` or tautological → replace with specific assertion
If `time.sleep()` in test → replace with `mocker.patch("time.time")` or `freezegun`
If missing `@pytest.mark.asyncio` on async test → add the marker
If `try/except` with empty body → replace with `pytest.raises`
If `assert result is not None` when exact value is knowable → replace with specific value assertion
If hardcoded file path → replace with `tmp_path` fixture
```

---

## Step 3: Flakiness testing

```
Run each generated test file 5 times sequentially:
  Command: pytest <test-file> -v (5 sequential executions)

Track results across all 5 runs:
  If any test passes in some runs and fails in others:
    Flag as "flaky" with the inconsistency pattern.
    Common Python causes: unmocked `datetime.now()`, `random.random()`, filesystem state, database state, network calls, unawaited coroutines, race conditions in async code.
    Attempt auto-fix (add mock for time/random, use tmp_path, add proper awaits, mock network).
    Re-test after fix.
  If all 5 runs produce identical results:
    Mark as "stable".
```

---

## Step 4: Quality report

```
Assemble quality report for each generated file:
  {
    file: "tests/test_calculate.py",
    sourceFile: "src/utils/calculate.py",
    score: 85,
    dimensions: {
      assertionQuality: 26,
      testStructure: 17,
      independence: 18,
      coverageValue: 13,
      maintainability: 11
    },
    antiPatterns: [],
    flakiness: "stable",
    coverageDelta: { before: "0%", after: "92%", lines: "+92%", branches: "+85%" },
    testsGenerated: 6,
    testsPassed: 6,
    testsFailed: 0
  }

If score < quality_threshold * 100:
  Print: "Quality score {score} is below threshold {threshold}. Suggested improvements:"
  For the lowest-scoring dimension:
    Print: "  - {dimension}: {score}/{max} — {specific improvement suggestions}"
```
