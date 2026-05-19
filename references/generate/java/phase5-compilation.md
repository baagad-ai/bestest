# Phase 5 — Compilation Verification (Java)

Java requires compilation before test execution. This phase runs a 3-stage compilation verification pipeline with cascade error deduplication — one bad import can produce 20+ error messages, so the fix loop must identify the root cause first.

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
  Run three-stage verification on each generated test file.

  Stage 1 — Syntax check:
    Command (Gradle): ./gradlew compileTestJava --console=plain 2>&1 | head -100
    Command (Maven):  ./mvnw test-compile 2>&1 | tail -50
    Verifies Java syntax is valid (no missing semicolons, type errors, etc.)
    Capture all compilation errors.

  Stage 2 — Full classpath resolution:
    Command (Gradle): ./gradlew compileTestJava --console=plain 2>&1
    Command (Maven):  ./mvnw test-compile 2>&1
    Verifies all imports resolve, dependencies are on classpath.
    Detect missing imports, wrong generic types, incompatible method signatures.

  Stage 3 — Test discovery:
    Command (Gradle): ./gradlew test --tests "com.example.*Test" --dry-run 2>&1
    Command (Maven):  ./mvnw test -Dtest="com.example.*Test" -DfailIfNoTests=false (check discovery output)
    Verifies JUnit Platform discovers the test class and its @Test methods.

Else:
  Skip this phase. Proceed to Phase 6.
```

## Compilation cascade error handling

**CRITICAL:** Java compilation errors cascade. One root cause (e.g., a missing import or wrong type) can produce 20+ error messages across multiple files. The fix loop MUST deduplicate and identify the ROOT cause before attempting fixes.

```
When compilation produces errors:
  1. Group errors by file and type.
  2. Identify ROOT cause errors vs CASCADE errors:
     ROOT causes: "package X does not exist", "cannot find symbol", "incompatible types"
     CASCADE errors: errors in other methods that depend on the unresolved symbol
  3. Count unique root causes. If 3 root causes produce 47 total errors, fix only the 3.
  4. Fix root causes in dependency order (missing imports first, then type mismatches).
  5. Re-compile after fixing root causes. Most cascade errors will resolve automatically.
  6. Only address remaining errors if they persist after root cause fixes.

Example cascade:
  Error: "package org.mockito.junit.jupiter does not exist" (ROOT - missing import)
  → 15 errors: "cannot find symbol: class MockitoExtension"
  → 8 errors: "method does not override or implement a method from a supertype"
  → 3 errors: "incompatible types"
  Fix: Add mockito-junit-jupiter to testImplementation dependencies.
  Result: All 26 errors resolve.
```

## Auto-fix patterns

When compilation fails, analyze errors and apply common fixes:

| Error Type | Auto-Fix |
|-----------|----------|
| `package X does not exist` | Missing import or missing dependency. Check build.gradle/pom.xml for the dependency. Add the import statement. |
| `cannot find symbol` | Wrong method name, missing import, or wrong class reference. Check the source file for the correct method signature. |
| `incompatible types` | Wrong generic type or return type. Use the correct type from the source file. |
| `method does not exist in class` | Method signature changed or wrong class. Check the actual source method signature. |
| `non-static method cannot be referenced from static context` | Missing instance creation. Use `@InjectMocks` or create instance manually. |
| `variable might not have been initialized` | Initialize the variable with a default value or mock. |
| `@Override method does not override` | Wrong method signature or interface change. Check the source interface. |
| Missing `@Test` import | Add `import org.junit.jupiter.api.Test;` |
| Missing Mockito import | Add `import org.mockito.*` or `import static org.mockito.Mockito.*;` |
| Missing AssertJ import | Add `import static org.assertj.core.api.Assertions.*;` |

## Fix loop

```
compilation_attempts = 0
max_compilation_attempts = 3

while compilation fails AND compilation_attempts < max_compilation_attempts:
  compilation_attempts += 1

  1. Parse error output. Extract all error messages.
  2. Deduplicate cascade errors:
     - Group by root cause (first unique error per file/type).
     - Ignore cascade errors that depend on unfixed root causes.
  3. For each root cause:
     - Apply matching auto-fix from the table above.
     - If no auto-fix matches, attempt: check source file for correct API, fix import/type.
  4. Re-run compilation.
  5. If compilation succeeds: break.

If compilation still fails after max attempts:
  Print: "Compilation failed after {max_compilation_attempts} attempts for {test-file}."
  Print: "Root cause errors remaining:"
  For each unique root cause:
    Print: "  - {error message} at line {line}"
  Print: "The test file will be presented to the user for manual resolution."
  Mark the test file as "compilation-failed" in the generation report.
  Continue to the next file (do not proceed to Phase 6 for this file).
```
