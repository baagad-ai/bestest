# Phase 6 — Execution Verification (Python)

On-demand sub-file for `spoke-generate-python.md`. Contains execution verification, failure analysis, fix-and-rerun loop, and coverage delta verification.

---

## Execution

```
If generation.verify_pass is true:
  Run generated tests using pytest.

  Command: pytest <test-file-path> -v --tb=short
  Parse output for pass/fail/skip counts and failure messages.

  pytest exit codes:
    0 — All tests passed
    1 — Some tests failed
    2 — Test execution was interrupted (keyboard interrupt)
    3 — Internal error during test execution
    4 — pytest command-line usage error
    5 — No tests were collected

  Handle each exit code:
    0: All passed → proceed to coverage check.
    1: Failures → enter fix-and-rerun loop.
    2: Interrupted → investigate; likely a hanging test or unawaited coroutine.
    3: Internal error → check pytest plugins and conftest.py for errors.
    4: Usage error → check command syntax and pytest config.
    5: No tests collected → check file naming (test_* prefix), check pytest.testpaths, check for syntax errors preventing collection.

Else:
  Skip this phase. Proceed to Phase 7.
```

## Failure analysis

When a test fails, determine the root cause:

| Root Cause | Detection | Action |
|-----------|-----------|--------|
| **Test bug** | AssertionError with wrong expected value, mock misconfigured | Fix the test |
| **Source bug** | Source raises/returns unexpected value test correctly identifies | Do NOT fix source. Document behavior. Present to user. |
| **Environment** | Missing env var, missing conftest.py, wrong working directory | Fix test environment |
| **Timeout** | Exceeds default timeout, unmocked async operation | Add proper awaits or mock slow dependencies |
| **Import error at runtime** | Module found during collection but fails at import during execution | Fix the import path or add missing conftest fixture |
| **Fixture not found** | `fixture 'xyz' not found` | Define the fixture locally or verify conftest.py placement |
| **Missing marker** | `django_db` or `asyncio` marker not applied | Add the required marker to the test function |

## Fix-and-rerun loop

```
retry_count = 0
max_retries = generation.max_retries (default: 2)

while tests fail AND retry_count < max_retries:
  retry_count += 1
  For each failing test:
    Read the failure output (error message, expected vs received, traceback).
    Determine root cause using the table above.
    If "test bug": fix assertion, mock setup, add await, or update mock return value.
    If "source bug": add comment `# NOTE: Source behavior documented for regression detection.` Adjust test to pass with current behavior. Flag in HITL report.
    If "environment": fix test setup (add env vars, imports, fixtures, conftest.py).
    If "missing marker": add `@pytest.mark.asyncio` or `@pytest.mark.django_db`.
    If "fixture not found": define the missing fixture in the test file.
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
Run coverage on the specific test file to measure contribution:

Command: pytest <test-file-path> --cov=<source-module-path> --cov-report=term-missing --cov-branch

For each generated test file:
  Compare coverage delta (before → after) for the source file it tests.
  If coverage delta is 0% and tests pass:
    Print: "Warning: {test-file} passes but contributes no coverage to {source-file}."
    Print: "Tests may be testing mock behavior instead of real code."
    Flag for quality review in Phase 7.
  If coverage tool fails entirely:
    Print: "Coverage collection failed. Proceeding without coverage verification."
    Continue without coverage data. Phase 7 will skip coverage-value scoring.
```
