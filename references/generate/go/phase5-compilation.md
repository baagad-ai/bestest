# Phase 5 Compilation Verification — Go

Go's strict compilation rules mean every generated test must pass `go vet`, `go build`, and test compilation. This phase runs a 3-stage verification pipeline.

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

# Recompilation guard
if generation.recompilation_guard is true:
  phase5_entry_count[<test-file>] += 1
  if phase5_entry_count[<test-file>] > 2 AND file has no successful Phase 6 pass:
    Print: "Recompilation guard: deferring {file} for manual review (entered Phase 5 {count} times without Phase 6 success)."
    Skip to next file.

If generation.verify_compilation is true:
  Run three-stage verification on each generated test file.

  Stage 1 — Static analysis:
    Command: go vet ./path/to/package/
    Verifies code correctness (unused imports, unreachable code, incorrect format strings).

  Stage 2 — Compilation check:
    Command: go build ./path/to/package/
    Verifies all types resolve, imports are valid, syntax is correct.

  Stage 3 — Test compilation without execution:
    Command: go test -run='^$' ./path/to/package/
    Compiles test binary without running any tests (matches empty regex).
    Verifies test file compiles with test-specific dependencies.

Else:
  Skip this phase. Proceed to Phase 6.
```

## Auto-Fix Patterns

When compilation fails, analyze errors and apply common fixes:

| Error Type | Auto-Fix |
|-----------|----------|
| **Unused import** (`imported and not used`) | Remove the unused import. Or add blank identifier usage: `_ = "package"` if needed for side effects. |
| **Import cycle** (`import cycle not allowed`) | Move the test to an external test package (`package xxx_test`). Import the source package normally. |
| **Undefined symbol** (`undefined: X`) | Fix the import path. Verify the source file exports the symbol (capitalized first letter). Check module path in go.mod. |
| **Type mismatch** (`cannot use X as Y`) | Fix the test's types to match source signatures. Do not change source types. |
| **Syntax error** (`syntax error`) | Fix the test code structure (missing braces, incorrect slice syntax, wrong var declaration). |
| **Wrong package declaration** (`found packages X and Y`) | Ensure the test file's package declaration matches the source file's package (or uses `xxx_test` for black-box). |
| **Missing `go.sum` entry** | Run `go mod tidy` to update go.sum with new testify dependency. |
| **Missing test dependency in go.mod** | With user approval (HITL), add the dependency: `go get <module>@latest` then `go mod tidy`. If the user declines, note the missing dependency in the quality report and continue — do NOT modify go.mod without approval. |
| **Build tag mismatch** | Add required build tags: `go test -tags=integration ./...` |

## Fix Loop

```
compilation_attempts = 0
max_compilation_attempts = 3

while compilation fails AND compilation_attempts < max_compilation_attempts:
  compilation_attempts += 1

  1. Parse error output. Extract all error messages.
  2. Go compilation errors are typically precise (file:line:col: message).
  3. For each error:
     - Apply matching auto-fix from the table above.
     - If no auto-fix matches, attempt: check source file for correct API, fix import/type.
  4. Re-run the failing compilation stage.
  5. If compilation succeeds: break.

If compilation still fails after max attempts:
  Print: "Compilation failed after {max_compilation_attempts} attempts for {test-file}."
  Print: "Error details:"
  For each remaining error:
    Print: "  - {file}:{line}: {message}"
  Print: "The test file will be presented to the user for manual resolution."
  Mark the test file as "compilation-failed" in the generation report.
  Continue to the next file (do not proceed to Phase 6 for this file).
```
