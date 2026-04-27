# Phase 5 — Compilation Verification (Python)

On-demand sub-file for `spoke-generate-python.md`. Contains compilation verification logic for generated Python tests.

---

## Execution

```
If generation.verify_compilation is true:
  Run two-stage verification on each generated test file.

  Stage 1 — Syntax check:
    Command: python -m py_compile <test-file-path>
    Verifies Python syntax is valid (no indentation errors, missing colons, etc.)

  Stage 2 — Import check:
    Command: python -c "import <test_module>"
    Verifies all imports in the test file resolve correctly.

  Stage 3 — Collection check:
    Command: pytest --collect-only <test-file-path>
    Verifies pytest can discover and collect the test functions.

Else:
  Skip this phase. Proceed to Phase 6.
```

## Auto-fix patterns

When compilation/collection fails, analyze errors and apply common fixes:

| Error Type | Auto-Fix |
|-----------|----------|
| Missing import (`ModuleNotFoundError`) | Check source file location, fix import path. Verify `__init__.py` exists in package directories. |
| Circular import | Restructure import to use local import inside test function, or mock the circular dependency. |
| Syntax error (indentation, colon) | Fix indentation to match surrounding code. Add missing colon after `def`, `if`, `for`, `with`. |
| `NameError: name 'pytest' is not defined` | Add `import pytest` at the top of the file. |
| Missing `conftest.py` fixture | If test references a fixture that doesn't exist, define it locally in the test file. |
| `@pytest.mark.asyncio` not recognized | Verify `pytest-asyncio` is installed. If missing, note it; if present, check `asyncio_mode` config. |
| Missing dependency type | Note missing package, do not install automatically. |

## Fix loop

```
compilation_attempts = 0
max_compilation_attempts = 3

while compilation fails AND compilation_attempts < max_compilation_attempts:
  compilation_attempts += 1
  Analyze the error output.
  Apply matching auto-fix from the table above.
  Re-run the compiler/collection check.
  If compilation succeeds: break.

If compilation still fails after max attempts:
  Print: "Compilation failed after {max_compilation_attempts} attempts for {test-file}."
  Print: "Error details: {last error output}"
  Print: "The test file will be presented to the user for manual resolution."
  Mark the test file as "compilation-failed" in the generation report.
  Continue to the next file (do not proceed to Phase 6 for this file).
```
