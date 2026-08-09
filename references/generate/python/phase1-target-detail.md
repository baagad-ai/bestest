# Phase 1 — Target Selection Detail (Python)

On-demand sub-file for `spoke-generate-python.md`. Contains detailed path validation, targeting mode logic, Python naming conventions, virtual environment detection, and pytest plugin detection.

---

## Path Validation

Before processing any target path through the targeting modes below, validate the path to prevent filesystem traversal attacks, canonicalization issues, and invalid inputs. Apply these six validation steps, **in this exact order**, to every user-supplied path — ordering matters for security:

```
1. Traversal rejection: Reject raw user_path containing ".." or starting with "/".
   if ".." in user_path.split(os.sep) or user_path.startswith("/"):
     print(f"Invalid path: directory traversal detected.")
     Exit.

2. Canonicalize: Resolve symlinks and relative segments (./) using os.path.realpath().
   canonical = os.path.realpath(user_path)

3. Boundary check: Verify the canonical path is within the project root.
   Prefix-collision-safe check — require root itself OR root followed by a separator,
   so a sibling like /project-root-evil cannot pass.
   if canonical != project_root and not canonical.startswith(project_root + os.sep):
     print(f"Path escapes project boundary: {user_path}")
     Exit.

4. Existence check: Verify the file or directory exists.
   if not os.path.exists(canonical):
     print(f"Path does not exist: {user_path}")
     Exit.

5. File type check: If targeting a single file, verify it matches *.py.
   if is_file and not canonical.endswith('.py'):
     print(f"File type not supported: {canonical}. Expected .py.")
     Exit.

6. Sensitive file exclusion: Reject files matching sensitive filename patterns.
   Sensitive BASENAME patterns (case-insensitive): .env, .env.*, *.pem, *.key, *.p12,
     *.pfx, *.jks, id_rsa*, id_ed25519*, id_ecdsa*, credentials.*, service-account*.json,
     .netrc, .npmrc, .pypirc, *.keystore, *.truststore
   Sensitive DIRECTORY patterns (matched against the FULL canonical path, not basename):
     .aws/, .ssh/, .gnupg/, .git/, .hg/, .svn/, node_modules/, .venv/, .tox/, secrets/
   basename = os.path.basename(canonical)
   if fnmatch.fnmatch(basename.lower(), any sensitive basename pattern) \
      or any(f"/{d}" in canonical or canonical.startswith(d) for d in sensitive_dirs):
     print(f"Sensitive file rejected: {canonical}. Test generation for credential and key files is blocked for security.")
     Exit.
```

All six checks must pass before the path enters any targeting mode below. If any check fails, print the error and exit — do not fall through to other modes.

---

### Monorepo Path Boundary

In monorepos (`monorepo.detected` is true in StackProfile / `monorepo.enabled` in config), the project root for the boundary check is the **package root**, not the repo root:

```
If monorepo is detected:
  packageRoot = directory containing the nearest package manifest
  projectRoot (for the boundary check) = packageRoot
  paths.src and paths.test globs are evaluated relative to packageRoot

Else:
  projectRoot = repo root (single-package behavior)
```

This prevents cross-package targeting from a single-package generate invocation while still allowing explicit cross-package paths when the user passes a full path. If `monorepo.detected` is true but no package manifest is found near the target, fall back to the repo root with a warning.


## Targeting Modes

### Mode 1: Explicit path argument

```
If a <path> argument is provided:
  Resolve the path relative to the project root.
  If path is a file:
    Validate it matches paths.src glob pattern.
    If it's a test file (test_*.py or *_test.py): error, "Cannot generate tests for a test file."
    If it's conftest.py: error, "Cannot generate tests for conftest.py — fixtures only."
    Set targets = [path]
  If path is a directory:
    Glob all files matching paths.src within the directory.
    Filter out files already covered by existing tests (from testInventory).
    Set targets = matched files.
  Skip all other targeting modes.
```

### Mode 2: `--untested` flag

```
If --untested flag is set:
  If mode is "scan-guided":
    Filter gaps[] where hasTest == false.
    Set targets = gaps[].sourcePath sorted by priority (critical first).
  If mode is "filesystem-scan":
    Glob all files matching paths.src.
    For each source file, check if corresponding test file exists by naming convention:
      src/utils/calculate.py → tests/test_calculate.py or tests/utils/test_calculate.py
    Set targets = source files with no corresponding test file.
```

### Mode 3: `--type <kind>` flag

```
If --type <kind> is specified (kind = unit | integration | e2e):
  If mode is "scan-guided":
    Filter gaps[] by the type of test that would be generated.
    Unit tests: files in src/ matching standard patterns.
    Integration tests: files importing multiple modules, API routes, database interactions.
    E2E tests: route handlers, view functions, app entry points.
  Else:
    Glob files matching paths.src and classify by type heuristics.
  Set targets = filtered files sorted by priority.
```

### Mode 4: `--critical` flag

```
If --critical flag is set:
  Prioritize entry points, authentication modules, data handling, payment logic, error-prone modules.
  If mode is "scan-guided":
    Filter gaps[] where priority is "critical".
    If no critical gaps: expand to "high" priority.
  Else:
    Identify critical files by heuristics:
      - Files imported by 5+ other files (high impact radius)
      - Files matching patterns: auth*, login*, payment*, checkout*, permission*, middleware*
      - Entry points: app.py, main.py, manage.py, wsgi.py, asgi.py
      - Files with high cyclomatic complexity (estimate from branch count)
  Set targets = prioritized files.
```

---

## Python test file naming conventions

Generated test files follow the project's existing naming convention. If no convention is established, use `tests/test_<module>.py`:

| Source File | Generated Test File |
|-------------|-------------------|
| `src/utils/calculate.py` | `tests/test_calculate.py` or `tests/utils/test_calculate.py` |
| `src/api/users.py` | `tests/test_users.py` or `tests/api/test_users.py` |
| `app/services/cart.py` | `tests/test_cart.py` or `tests/services/test_cart.py` |

Detect existing convention by scanning `pytest.testpaths` config and existing test file locations. Match the dominant pattern (flat `tests/test_*.py` vs nested `tests/*/test_*.py`).

---

## Virtual environment detection

```
Check for virtual environment:
  1. Check VIRTUAL_ENV environment variable → if set, use it.
  2. Check for .venv/ directory in project root → if found, activate it.
  3. Check for poetry env (pyproject.toml with [tool.poetry]) → run poetry env info.
  4. Check for conda env (environment.yml or .conda/) → run conda info --envs.
  5. Check for pipenv (Pipfile) → run pipenv --venv.

If no virtual environment is found:
  Print: "Warning: No Python virtual environment detected."
  Print: "Tests will generate but may not execute correctly without isolated dependencies."
  Print: "Create one with: python -m venv .venv && source .venv/bin/activate"
  Continue in degraded mode (Phase 5/6 may fail).
```

---

## pytest plugin detection

Check for pytest plugins after confirming pytest is installed:

- **pytest-asyncio**: required for async test functions
- **pytest-mock**: recommended for cleaner mock lifecycle
- **pytest-cov**: required for coverage collection
- **httpx**: required for FastAPI route testing
- **pytest-django**: required for Django ORM testing

Note missing plugins but do not block generation — only skip tests requiring the plugin.

---

## State corruption handling

If `.bestest/state/stack-profile.json` exists but JSON parsing fails:

```
Print: "⚠ State file corruption detected: .bestest/state/stack-profile.json"
Print: "  The file contains invalid JSON and cannot be read."
Print: "  Options:"
Print: "    (a) Regenerate — delete .bestest/ and re-run /bestest init."
Print: "    (b) Manual fix — edit the file to correct the JSON syntax."
Print: "    (c) Abort — exit without proceeding."
Wait for user choice. Do NOT proceed with corrupted state.
```

---

## Schema version validation

```
Validate stack-profile.json schemaVersion (if loaded):
  Expected version: ≤ 1.3 (current known version).
  If schemaVersion is missing:
    Treat as version "1.0" (pre-versioning legacy). Print a note and continue.
  If MAJOR version matches (1.x) and MINOR ≤ 3:
    Proceed normally.
  If MAJOR version matches but MINOR > 3:
    Print: "⚠ stack-profile.json schemaVersion {version} is newer than expected (≤ 1.3). Proceeding — unrecognized fields will be ignored."
    Continue with warning.
  If MAJOR version differs:
    Print: "Error: stack-profile.json schemaVersion {version} has an incompatible MAJOR version. Expected 1.x."
    Print: "Update bestest to the latest version, or re-run /bestest init to regenerate."
    Exit.

Validate scan-report.json schemaVersion (if loaded):
  Expected version: ≤ 1.2 (current known version).
  If schemaVersion is missing:
    Treat as version "1.0" (pre-versioning legacy). Print a note and continue.
  If MAJOR version matches (1.x) and MINOR ≤ 2:
    Proceed normally.
  If MAJOR version matches but MINOR > 2:
    Print: "⚠ scan-report.json schemaVersion {version} is newer than expected (≤ 1.2). Proceeding — unrecognized fields will be ignored."
    Continue with warning.
  If MAJOR version differs:
    Print: "Error: scan-report.json schemaVersion {version} has an incompatible MAJOR version. Expected 1.x."
    Print: "Update bestest to the latest version, or re-run /bestest scan to regenerate."
    Exit.
```

