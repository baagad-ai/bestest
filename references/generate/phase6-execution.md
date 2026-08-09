# Phase 6 — Execution Verification

> **On-demand load:** When execution verification is needed, read this file. Run generated tests, analyze failures, and apply the fix-and-rerun loop defined here.

---

## Execution

```
# Two-tier iteration budget check (see Global Iteration Budget in references/generate/pipeline-shared.md)
# Tier 1 — per-file retry depth
file_iterations[<test-file>] += 1
if file_iterations[<test-file>] > generation.max_retries_per_file (default: 5):
  Print: "Per-file retry budget exhausted for {file} ({max_retries_per_file} iterations)."
  Defer the file. Move to next file.
  Return to the generation loop (Phase 1).

# Tier 2 — file-processing breadth (maintained by the generation loop between files)
# If files_processed >= generation.max_files (default: 50), break out of the generation loop
# and emit the diagnostic summary.

# Legacy compatibility: if only generation.max_iterations is set, both tiers inherit its value.

If generation.verify_pass is true:
  Run generated tests using the project's test framework.

  Vitest:
    Command: npx vitest run <test-file-path> --reporter=verbose
    Parse output for pass/fail/skip counts and failure messages.

  Jest:
    Command: npx jest <test-file-path> --verbose
    Parse output for pass/fail/skip counts and failure messages.

Else:
  Skip this phase. Proceed to Phase 7.
```

## Failure Analysis

When a test fails, determine the root cause:

| Root Cause | Detection | Action |
|-----------|-----------|--------|
| **Test bug** | Assertion expects wrong value, mock misconfigured | Fix the test |
| **Source bug** | Source throws/returns unexpected value test correctly identifies | Do NOT fix source. Document behavior. Present to user. |
| **Environment** | Missing env var, wrong directory, missing setup | Fix test environment |
| **Timeout** | Exceeds default timeout, unmocked async | Add proper awaits or fake timers |

## Fix-and-Rerun Loop

```
retry_count = 0
max_retries = generation.max_retries (default: 2)

while tests fail AND retry_count < max_retries:
  retry_count += 1
  For each failing test:
    Read the failure output (error message, expected vs received, stack trace).
    Determine root cause using the table above.
    If "test bug": fix assertion, mock setup, add await, or update mock return value.
    If "source bug": add comment `// NOTE: Source behavior documented for regression detection.` Adjust test to pass with current behavior. Flag in HITL report.
    If "environment": fix test setup (add env vars, imports, configuration).
    
  **Phase 6→5 Back-Loop Check:**
  If any fix altered imports, types, type annotations, or structural code (not just assertion values or mock return values):
    Return to Phase 5 (Compilation Verification) for recompilation before re-running tests.
    Increment file_iterations[<test-file>] on re-entry (see pipeline-shared.md → Global Iteration Budget).
    The recompilation guard (3 Phase 5 entries without Phase 6 success) will catch pathological cycling.
    After successful recompilation, continue to re-run tests.
  
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

## Coverage Delta Verification

After all tests pass (or retry loop completes):

```
Run coverage on the specific test file to measure contribution:

Vitest:
  Command: npx vitest run <test-file-path> --coverage
  Parse coverage output for the corresponding source file.

Jest:
  Command: npx jest <test-file-path> --coverage
  Parse coverage output for the corresponding source file.

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
