# Phase 1 — Target Selection Detail

> **On-demand load:** When detailed targeting heuristics or path validation rules are needed, read this file. The hub file contains the compressed targeting overview (4 modes, priority formula summary, default behavior).

---

## Path Validation

Before processing any target path through the targeting modes, validate the path to prevent filesystem traversal attacks, canonicalization issues, and invalid inputs. Apply these six validation steps, **in this exact order**, to every user-supplied path — ordering matters for security:

```
1. Traversal rejection: Reject raw userPath containing ".." or starting with "/".
   if (userPath contains ".." or starts with "/"):
     error: "Invalid path: directory traversal detected."
     Exit.

2. Canonicalize: Resolve symlinks and relative segments (./) using path.resolve() or realpath.
   canonical = fs.realpathSync(path.resolve(userPath))

3. Boundary check: Verify the canonical path is within the project root.
   if (!canonical.startsWith(projectRoot)):
     error: "Path escapes project boundary: {userPath}"
     Exit.

4. Existence check: Verify the file or directory exists.
   if (!fs.exists(canonical)):
     error: "Path does not exist: {userPath}"
     Exit.

5. File type check: If targeting a single file, verify it matches the expected extension pattern.
   If language is TypeScript/JavaScript: must match *.ts, *.tsx, *.js, *.jsx
   If language is Python: must match *.py
   If language is Java: must match *.java
   If language is Go: must match *.go
   if (isFile && !matchesExpectedExtension(canonical)):
     error: "File type not supported: {canonical}. Expected {extension}."
     Exit.

6. Sensitive file exclusion: Reject files matching sensitive filename patterns.
   Sensitive patterns (case-insensitive): .env, .env.*, *.pem, *.key, *.p12, *.pfx, *.jks,
     id_rsa*, id_ed25519*, id_ecdsa*, credentials.*, service-account*.json,
     .netrc, .npmrc, .pypirc, .aws/*, .ssh/*, .gnupg/*, *.keystore, *.truststore
   basename = path.basename(canonical)
   if (basename matches any sensitive pattern, case-insensitive):
     error: "Sensitive file rejected: {canonical}. Test generation for credential and key files is blocked for security."
     Exit.
```

All six checks must pass before the path enters any targeting mode. If any check fails, print the error and exit — do not fall through to other modes.

---

## Targeting Mode Detail

### Mode 1: Explicit path argument

```
If a <path> argument is provided:
  Resolve the path relative to the project root.
  If path is a file:
    Validate it matches paths.src glob pattern.
    If it's a test file (matches paths.test glob): error, "Cannot generate tests for a test file."
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
      src/utils/format.ts → src/utils/format.test.ts or src/utils/format.spec.ts
    Set targets = source files with no corresponding test file.
```

### Mode 3: `--type <kind>` flag

```
If --type <kind> is specified (kind = unit | integration | e2e):
  If mode is "scan-guided":
    Filter gaps[] by the type of test that would be generated.
    Unit tests: files in src/ matching standard patterns.
    Integration tests: files importing multiple modules, API routes, database interactions.
    E2E tests: files in app/ or pages/ directories, route handlers.
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
      - Entry points: main.ts, index.ts at package root, route handlers
      - Files with high cyclomatic complexity (estimate from branch count)
  Set targets = prioritized files.
```

---

## Pre-Flight Detail: State Corruption Handling

When StackProfile JSON parsing fails during Pre-Flight Check 2:

```
If JSON parsing fails:
  Print: "⚠ State file corruption detected: .bestest/state/stack-profile.json"
  Print: "  The file contains invalid JSON and cannot be read."
  Print: "  Options:"
  Print: "    (a) Regenerate — delete .bestest/ and re-run /bestest init."
  Print: "    (b) Manual fix — edit the file to correct the JSON syntax."
  Print: "    (c) Abort — exit without proceeding."
  Wait for user choice. Do NOT proceed with corrupted state.
```

### Framework Detection Fallback

When StackProfile doesn't exist and framework must be detected from `package.json`:

```
Set framework = detect from package.json devDependencies (vitest or jest)
If framework cannot be detected:
  Print: "Cannot determine test framework. Specify in config.yaml or install vitest/jest."
  Exit.
```

### Schema Version Validation Detail

Validate artifact schemaVersions against expected ranges:

```
Validate stack-profile.json schemaVersion:
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

Validate scan-report.json schemaVersion:
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
 a note and continue.
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
