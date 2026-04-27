# Error Handling (Python)

On-demand sub-file for `spoke-generate-python.md`. Contains all error handling scenarios for the Python generate spoke.

---

## 1. No target files found

**Trigger:** Target selection (Phase 1) returns zero files to generate tests for.

**Response:**
```
Print: "No target files found for generation."
Print: "This could mean:"
Print: "  1. All source files already have tests — use /bestest scan to verify"
Print: "  2. The paths.src glob pattern doesn't match any files — check config.yaml"
Print: "  3. The specified path doesn't exist or was excluded by paths.ignore"
Print: "  4. All .py files are in migrations/ or __pycache__/ — excluded by default"
```
Exit. No files generated.

---

## 2. Source file has syntax errors

**Trigger:** Source file cannot be parsed (Python syntax errors in the source).

**Response:**
```
Print: "Source file {path} has syntax errors and cannot be analyzed."
Print: "Error: {first syntax error}"
Print: "Skipping this file. Fix the source errors and re-run generation."
```
Never attempt to fix source code. Skip the file and continue with the next target.

---

## 3. Context7 unavailable

**Trigger:** `resolve_library` or `get_library_docs` fails or times out.

**Response:**
```
Print: "Context7 documentation fetch failed: {error}"
Print: "Falling back to static reference patterns from python-generation-guide.md."
Print: "Generated tests will use common API patterns but may not be version-accurate."
```
Continue with static patterns. Quality may be slightly lower for framework-specific features.

---

## 4. pytest not installed

**Trigger:** `import pytest` fails or pytest binary is not found.

**Response:**
```
Print: "pytest is not installed in the active Python environment."
Print: "Install it with: pip install pytest pytest-cov pytest-mock"
Print: "Or run /bestest init to set up dependencies."
```
Exit. Cannot generate tests without pytest to target.

---

## 5. Virtual environment not activated

**Trigger:** No `VIRTUAL_ENV`, `.venv/`, or Poetry/Conda environment detected.

**Response:**
```
Print: "Warning: No Python virtual environment detected."
Print: "Tests will be generated but may not execute against correct dependencies."
Print: "Create and activate a virtual environment:"
Print: "  python -m venv .venv && source .venv/bin/activate"
Print: "Continuing in degraded mode — Phase 5/6 may fail."
```
Continue in degraded mode. Compilation and execution checks may fail.

---

## 6. Generated test can't pass after max retries

**Trigger:** Phase 6 retry loop exhausts `max_retries` without all tests passing.

**Response:**
```
Print: "Generated test {file} could not be made to pass after {max_retries} attempts."
Print: "Remaining failures:"
For each failing test:
  Print: "  - {test name}: {error message}"
Print: "The test file is preserved for manual review."
```
Mark as "execution-failed". Present in HITL gate. Do not delete the generated file — the user can fix it manually.

---

## 7. Coverage tool fails

**Trigger:** `pytest-cov` is not installed or coverage collection command errors.

**Response:**
```
Print: "Coverage collection failed: {error}"
Print: "Proceeding without coverage verification."
Print: "Tests were verified to compile and pass, but coverage contribution is unknown."
Print: "Install pytest-cov: pip install pytest-cov"
Print: "Run /bestest doctor to diagnose coverage tool issues."
```
Continue without coverage data. Phase 7 scoring will skip the Coverage Value dimension and adjust the total proportionally.

---

## 8. Missing __init__.py in test package

**Trigger:** Test file is in a subdirectory (e.g., `tests/api/`) but `__init__.py` is missing, causing import failures.

**Response:**
```
Print: "Missing __init__.py in tests/api/ — adding it for proper test discovery."
Create empty __init__.py files in the test directory path.
Re-run compilation check.
```
Auto-fix by creating the missing `__init__.py` files.

---

## 9. Large file exceeding token budget

**Trigger:** Source file is too large to analyze in a single context window (roughly >1500 lines).

**Response:**
```
Print: "Source file {path} is large ({lines} lines). Splitting generation."
Strategy:
  1. Read only function/class signatures (first ~200 lines typically).
  2. Generate tests for each function/class individually, reading only the relevant body.
  3. Split the generated test file into multiple files if needed:
     test_pricing.py → test_pricing_calculation.py + test_pricing_validation.py
  4. Each split file targets a specific subset of symbols.
```
This prevents context overflow while ensuring all symbols get test coverage.

---

## 10. Existing test file conflict

**Trigger:** A test file already exists for the target source file.

**Response:**
```
If existing test file was detected in Phase 2:
  Print: "Existing test file found: {test-path}"
  Print: "New tests will be generated for uncovered functions only."
  Print: "Existing tests will be preserved — new tests will be appended or generated in a separate class."
  Generate tests only for functions not covered by existing tests.
  Use a separate class or section with comment: "# Generated by bestest — {timestamp}"
Else (no test file but file exists at the target path):
  Print: "Warning: File exists at {test-path} but was not detected as a test file."
  Print: "Generating to {test-path}.new to avoid overwriting."
  Generate to a .new suffixed file and present for manual merge.
```

---

## 11. Monorepo with multiple Python packages

**Trigger:** Project has multiple Python packages with separate `pyproject.toml` or `setup.py` files.

**Response:**
```
For each target file in a monorepo:
  Determine which package it belongs to.
  Read that package's pyproject.toml for dependency detection.
  Use package-specific pytest config if present.
  Generate tests using the package's dependencies and config.
  Run compilation and execution in the package context.
```
Each package is handled independently. A failure in one package does not block others.
