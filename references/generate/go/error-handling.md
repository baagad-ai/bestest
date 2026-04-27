# Error Handling — Go Generate Spoke

All error scenarios for the Go generate spoke with trigger conditions and prescribed responses.

## 1. No target files found

**Trigger:** Target selection (Phase 1) returns zero files to generate tests for.

**Response:**
```
Print: "No target files found for generation."
Print: "This could mean:"
Print: "  1. All source files already have tests — use /bestest scan to verify"
Print: "  2. The paths.src glob pattern doesn't match any files — check config.yaml"
Print: "  3. The specified path doesn't exist or was excluded by paths.ignore"
Print: "  4. All .go files are in vendor/ or are code-generated — excluded by default"
```
Exit. No files generated.

## 2. Source file has syntax errors

**Trigger:** Source file cannot be parsed (`go vet` or `go build` fails on the source).

**Response:**
```
Print: "Source file {path} has compilation errors and cannot be analyzed."
Print: "Error: {first compilation error}"
Print: "Skipping this file. Fix the source errors and re-run generation."
```
Never attempt to fix source code. Skip the file and continue with the next target.

## 3. Context7 unavailable

**Trigger:** `resolve_library` or `get_library_docs` fails or times out.

**Response:**
```
Print: "Context7 documentation fetch failed: {error}"
Print: "Falling back to static reference patterns from this spoke."
Print: "Generated tests will use common API patterns but may not be version-accurate."
```
Continue with static patterns. Quality may be slightly lower for framework-specific features.

## 4. Go toolchain not installed

**Trigger:** `go version` fails or Go is not in PATH.

**Response:**
```
Print: "Error: Go toolchain not found. bestest requires Go 1.18+."
Print: "Install Go: https://go.dev/dl/"
Print: "  macOS: brew install go"
Print: "  Linux: snap install go --classic"
Print: "Verify: go version"
```
Exit. Cannot compile or run tests without Go toolchain.

## 5. No go.mod found

**Trigger:** No `go.mod` file found in the project root.

**Response:**
```
Print: "Error: No go.mod found. bestest requires a Go module."
Print: "Initialize a module: go mod init <module-path>"
```
Exit. Cannot determine module path or dependencies without go.mod.

## 6. Compilation fails after max retries

**Trigger:** Phase 5 retry loop exhausts `max_compilation_attempts` without successful compilation.

**Response:**
```
Print: "Generated test {file} could not be compiled after {max_compilation_attempts} attempts."
Print: "Remaining errors:"
For each remaining error:
  Print: "  - {file}:{line}: {message}"
Print: "The test file is preserved for manual review."
```
Mark as "compilation-failed". Present in HITL gate. Do not delete the generated file — the user can fix it manually.

## 7. Race conditions detected

**Trigger:** `go test -race` detects a data race in generated tests or source code.

**Response:**
```
Print: "Race condition detected in {package}:"
Print the full race report (goroutine stack traces).
If the race is in test setup/teardown:
  Add proper synchronization (sync.Mutex, sync.WaitGroup, or channel).
  Re-test with -race.
If the race is in source code:
  Note: "Race condition detected in source code, not in generated tests."
  Note: "This is a genuine bug in the source. Test correctly identifies it."
  Flag for source fix in HITL report.
```

## 8. testify not available

**Trigger:** testify is not in go.mod and `go.testify.enabled` is true.

**Response:**
```
Print: "Warning: testify is not in go.mod. It provides superior assertion diagnostics."
Print: "Install: go get github.com/stretchr/testify"
Print: "Falling back to standard library testing.T assertions."
Print: "Generated tests will use t.Errorf/t.Fatalf instead of assert.Equal/require.NoError."
```
Continue in degraded mode. Tests will use `t.Errorf`/`t.Fatalf` instead of testify assertions. Quality scores may be lower due to less specific failure messages.

## 9. Large file exceeding token budget

**Trigger:** Source file is too large to analyze in a single context window (roughly >1500 lines).

**Response:**
```
Print: "Source file {path} is large ({lines} lines). Splitting generation."
Strategy:
  1. Read only type declarations, method signatures, and struct definitions (first ~300 lines typically).
  2. Generate tests for each method individually, reading only the relevant method body.
  3. Split the generated test file into multiple files if needed:
     service/user_test.go → service/user_create_test.go + service/user_get_test.go + service/user_update_test.go
  4. Each split file targets a specific subset of methods.
  5. Use t.Run subtests for further organization within each file.
```
This prevents context overflow while ensuring all methods get test coverage.

## 10. Existing test file conflict

**Trigger:** A test file already exists for the target source file.

**Response:**
```
If existing test file was detected in Phase 2:
  Print: "Existing test file found: {test-path}"
  Print: "New tests will be generated for uncovered functions only."

  Generate tests only for functions not covered by existing tests.
  Add new test functions directly to the existing file.
  Add comment: "// Generated by bestest — {timestamp}"
Else (no test file but file exists at the target path):
  Print: "Warning: File exists at {test-path} but was not detected as a test file."
  Print: "Generating to {test-path}.new to avoid overwriting."
  Generate to a .new suffixed file and present for manual merge.
```

## 11. Multi-module Go workspace

**Trigger:** `go.work` file found indicating a Go workspace with multiple modules.

**Response:**
```
For each target file in a multi-module workspace:
  Determine which module it belongs to (from go.work use directives and directory structure).
  Read that module's go.mod for dependencies.
  Run compilation and tests in the module context:
    cd /path/to/module && go test ./...
  Generate tests using the module's dependencies and configuration.
```
Each module is handled independently. A failure in one module does not block others.
