# Phase 5 — Compilation Verification

> **On-demand load:** When compilation verification is needed, read this file. Apply the auto-fix patterns and retry loop defined here.

---

## Execution

```
# Global iteration budget check
global_iterations += 1
if global_iterations > generation.max_iterations (default: 10):
  Emit diagnostic summary (see Global Iteration Budget in references/generate/pipeline-shared.md).
  Halt. Do not proceed with this phase.

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
| Missing dependency type | Note missing package, do not install automatically |
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
