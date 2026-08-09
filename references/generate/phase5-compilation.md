# Phase 5 — Compilation Verification

> **On-demand load:** When compilation verification is needed, read this file. Apply the auto-fix patterns and retry loop defined here.

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

# Tier 2 — file-processing breadth (checked by the generation loop between files)
# files_processed is maintained by the orchestrator; if files_processed >= generation.max_files (default: 50),
# break out of the generation loop and emit the diagnostic summary.

# Legacy compatibility: if only generation.max_iterations is set, both tiers inherit its value.

# Recompilation guard
if generation.recompilation_guard is true:
  phase5_entry_count[<test-file>] += 1
  if phase5_entry_count[<test-file>] > 2 AND file has no successful Phase 6 pass:
    Print: "Recompilation guard: deferring {file} for manual review (entered Phase 5 {count} times without Phase 6 success)."
    Skip to next file.

If generation.verify_compilation is true:
  Run TypeScript compiler on each generated test file.

  Vitest project:
    Command: npx tsc --noEmit --pretty <test-file-path>
    (Also: npx vite build --mode test for full build check if tsc passes)

  Jest project:
    Command: npx tsc --noEmit --pretty <test-file-path>
    (Or: npx jest --typecheck if ts-jest is configured)

Else:
  Skip this phase. Proceed to Phase 6.
```

## Auto-fix Patterns

When compilation fails, analyze errors and apply common fixes:

| Error Type | Auto-Fix |
|-----------|----------|
| Missing import (`Cannot find name 'describe'`) | Add `import { describe, test, expect } from 'vitest'` or `'@jest/globals'` |
| Wrong import path | Check source file location, fix relative path |
| Incorrect mock type | Cast with `vi.fn() as unknown as typeof original` or add proper generic |
| Missing type annotation | Add explicit type annotation matching source signature |
| Missing dependency type | Check whether the missing package is a test-only dependency. With user approval (HITL), install it: `{packageManager} install -D <package>`. If the user declines, note the missing package in the quality report and continue — do NOT auto-install without approval. |
| Unused import | Remove unused import |

## Fix Loop

```
compilation_attempts = 0
max_compilation_attempts = 3

while compilation fails AND compilation_attempts < max_compilation_attempts:
  compilation_attempts += 1
  Analyze the compilation error output.
  Apply matching auto-fix from the table above.
  Re-run the compiler.
  If compilation succeeds: break.

If compilation still fails after max attempts:
  Print: "Compilation failed after {max_compilation_attempts} attempts for {test-file}."
  Print: "Error details: {last compilation error output}"
  Print: "The test file will be presented to the user for manual resolution."
  Mark the test file as "compilation-failed" in the generation report.
  Continue to the next file (do not proceed to Phase 6 for this file).
```
