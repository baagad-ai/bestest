# Phase 6 Execution Verification — Go

Run generated tests, analyze failures, and fix tests (never source code) in a controlled retry loop.

## Execution

```
If generation.verify_pass is true:
  Run generated tests using go test with race detection and verbose output.

  Build command flags:
    -v (verbose, if go.verbose is true)
    -race (if go.race_detection is true)
    -timeout {go.test_timeout}
    -coverprofile=coverage.out -covermode={go.cover_mode}
    -tags={go.build_tags} (if non-empty)

  Command: go test -v -race -timeout 5m -coverprofile=coverage.out -covermode=atomic ./path/to/package/

  Parse output for pass/fail/skip counts and failure messages.

  go test exit codes:
    0 — All tests passed
    1 — Some tests failed
    2 — Invalid command-line arguments
    * — (compilation failure, panic, or race detected — also non-zero)

  Handle each outcome:
    0: All passed → proceed to coverage check.
    1: Failures → enter fix-and-rerun loop.
    Race detected: Race condition output includes "DATA RACE" → analyze race, add synchronization.
    Panic: Test panics → check for nil pointer dereference, index out of range, type assertion failure.
    Timeout: Test exceeds go.test_timeout → check for unmocked blocking operations.

Else:
  Skip this phase. Proceed to Phase 7.
```

## Failure Analysis

When a test fails, determine the root cause:

| Root Cause | Detection | Action |
|-----------|-----------|--------|
| **Test bug** | Wrong expected value, mock misconfigured, wrong test setup | Fix the test |
| **Source bug** | Source returns unexpected value that the test correctly identifies | Do NOT fix source. Document behavior. Present to user. |
| **Environment** | Missing env var, missing testdata file, wrong working directory | Fix test environment |
| **Race condition** | `DATA RACE` in output, `-race` flag detected data race | Add synchronization (mutex, channel, or use race-safe pattern). If race is in source code, note it. |
| **Goroutine leak** | `goleak` detected leaked goroutine, or test hangs on WaitGroup | Ensure all goroutines complete. Add proper context cancellation or timeout. |
| **Timeout** | `panic: test timed out` in output | Check for unmocked blocking operations. Add context with timeout. |
| **Nil pointer dereference** | `panic: runtime error: invalid memory address or nil pointer dereference` | Check mock return values. Ensure mock is configured for all called methods. |
| **Import cycle at runtime** | Compilation succeeded but test fails with cycle error | Move test to `xxx_test` package. |

## Fix-and-Rerun Loop

```
retry_count = 0
max_retries = generation.max_retries (default: 2)

while tests fail AND retry_count < max_retries:
  retry_count += 1
  For each failing test:
    Read the failure output (error message, expected vs received, panic stack trace).
    Determine root cause using the table above.
    If "test bug": fix assertion, mock setup, add missing mock return, fix helper function.
    If "source bug": add comment `// NOTE: Source behavior documented for regression detection.` Adjust test to pass with current behavior. Flag in HITL report.
    If "environment": fix test setup (add t.Setenv, create testdata, fix import path).
    If "race condition": add mutex/channel synchronization or fix concurrent access pattern.
    If "nil pointer dereference": add mock return values for all called methods.
    If "timeout": add context with timeout, mock slow dependencies, or use require.Eventually.
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

## Race Detection Verification

After all tests pass:

```
Run tests with the race detector to verify no data races:

Command: go test -race ./path/to/package/

If "DATA RACE" is detected:
  Print: "Race condition detected in {package}:"
  Print the full race report (showing goroutine stack traces).
  Attempt auto-fix:
    - Shared variable → add sync.Mutex or sync.RWMutex
    - Map concurrent access → add sync.Mutex or use sync.Map
    - Slice append → use channel or mutex
    - Global state → refactor to instance state with proper synchronization
  Re-test after fix.
If no races detected:
  Mark as "race-free".
```

## Coverage Delta Verification

After all tests pass (or retry loop completes):

```
Run coverage on the specific test file to measure contribution:

Command: go test -coverprofile=coverage.out -covermode=atomic ./path/to/package/
Command: go tool cover -func=coverage.out

For each generated test file:
  Compare coverage delta (before → after) for the source file it tests.
  If coverage delta is 0% and tests pass:
    Print: "Warning: {test-file} passes but contributes no coverage to {source-file}."
    Print: "Tests may be testing mock behavior instead of real code."
    Flag for quality review in Phase 7.
  If coverage tool fails entirely:
    Print: "Coverage collection failed. Proceeding without coverage verification."
    Continue without coverage data. Phase 7 will skip Coverage Value scoring.
```
