# Phase 5 — Compilation Verification

> **On-demand load:** When compilation verification is needed, read this file. Apply the auto-fix patterns and retry loop defined here.

---

## Execution

```
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
