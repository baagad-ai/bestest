# Error Handling (Java Generate)

## 1. No target files found

**Trigger:** Target selection (Phase 1) returns zero files to generate tests for.

**Response:**
```
Print: "No target files found for generation."
Print: "This could mean:"
Print: "  1. All source files already have tests — use /bestest scan to verify"
Print: "  2. The paths.src glob pattern doesn't match any files — check config.yaml"
Print: "  3. The specified path doesn't exist or was excluded by paths.ignore"
Print: "  4. All .java files are in generated/ or build/ — excluded by default"
```
Exit. No files generated.

## 2. Source file has syntax errors

**Trigger:** Source file cannot be parsed (Java compilation errors in the source).

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

## 4. JDK not installed

**Trigger:** `java -version` fails or `javac` is not found.

**Response:**
```
Print: "Error: Java JDK not found. Compilation requires a JDK (not JRE)."
Print: "Install JDK 11+ and set JAVA_HOME:"
Print: "  macOS: brew install openjdk@17"
Print: "  Linux: sudo apt install openjdk-17-jdk"
Print: "  Windows: Download from https://adoptium.net/"
Print: "Verify: java -version && javac -version"
```
Exit. Cannot compile or run tests without a JDK.

## 5. Gradle/Maven not found

**Trigger:** No `gradlew`, `mvnw`, `build.gradle`, `build.gradle.kts`, or `pom.xml` found in the project.

**Response:**
```
Print: "Error: No build tool detected. bestest requires Gradle or Maven."
Print: "Initialize a project:"
Print: "  Gradle: gradle init (creates build.gradle + wrapper)"
Print: "  Maven:  mvn archetype:generate (creates pom.xml + wrapper)"
```
Exit. Cannot compile or run tests without a build tool.

## 6. Compilation fails after max retries

**Trigger:** Phase 5 retry loop exhausts `max_compilation_attempts` without successful compilation.

**Response:**
```
Print: "Generated test {file} could not be compiled after {max_compilation_attempts} attempts."
Print: "Root cause errors remaining:"
For each unique root cause:
  Print: "  - {error message}"
Print: "The test file is preserved for manual review."
```
Mark as "compilation-failed". Present in HITL gate. Do not delete the generated file — the user can fix it manually.

## 7. JaCoCo not configured

**Trigger:** JaCoCo plugin is not in `build.gradle` or `pom.xml`.

**Response:**
```
Print: "JaCoCo coverage plugin is not configured."
Print: "Proceeding without coverage verification."
Print: "Tests were verified to compile and pass, but coverage contribution is unknown."
Print: "Add JaCoCo:"
Print: "  Gradle: plugins { id 'jacoco' } + jacocoTestReport { dependsOn test }"
Print: "  Maven:  Add jacoco-maven-plugin with prepare-agent and report executions"
Print: "Run /bestest doctor to diagnose coverage tool issues."
```
Continue without coverage data. Phase 7 scoring will skip the Coverage Value dimension and adjust the total proportionally.

## 8. Spring context fails to start

**Trigger:** `@SpringBootTest` or slice test fails with `BeanCreationException`, `NoSuchBeanDefinitionException`, or `UnsatisfiedDependencyException`.

**Response:**
```
Print: "Spring application context failed to start."
Print: "Error: {BeanCreationException message}"
Identify the missing or misconfigured bean:
  1. NoSuchBeanDefinitionException → add @MockBean for the missing bean type
  2. UnsatisfiedDependencyException → check dependency chain, mock the failing dependency
  3. BeanCreationException → check configuration, may need @TestConfiguration
Attempt fix:
  1. If a bean is missing → add @MockBean for that type.
  2. If a dependency chain fails → narrow the test scope (use @WebMvcTest instead of @SpringBootTest).
  3. If a configuration property is missing → add @TestPropertySource with test values.
If fix succeeds: continue.
If fix fails:
  Print: "Could not resolve Spring context failure automatically."
  Print: "Consider using a narrower slice test annotation:"
  Print: "  @WebMvcTest for controllers"
  Print: "  @DataJpaTest for repositories"
  Print: "  @ExtendWith(MockitoExtension.class) for pure unit tests"
  Mark as "execution-failed".
```

## 9. Large file exceeding token budget

**Trigger:** Source file is too large to analyze in a single context window (roughly >1500 lines).

**Response:**
```
Print: "Source file {path} is large ({lines} lines). Splitting generation."
Strategy:
  1. Read only class declaration, method signatures, and field declarations (first ~300 lines typically).
  2. Generate tests for each method individually, reading only the relevant method body.
  3. Split the generated test file into multiple files if needed:
     UserServiceTest.java → UserServiceFindTest.java + UserServiceCreateTest.java + UserServiceUpdateTest.java
  4. Each split file targets a specific subset of methods.
  5. Use @Nested classes within each split file for further organization.
```
This prevents context overflow while ensuring all methods get test coverage.

## 10. Existing test file conflict

**Trigger:** A test file already exists for the target source class.

**Response:**
```
If existing test file was detected in Phase 2:
  Print: "Existing test file found: {test-path}"
  Print: "New tests will be generated for uncovered methods only."
  Print: "Existing tests will be preserved — new tests will be added as new @Nested classes."
  Generate tests only for methods not covered by existing tests.
  Use a new @Nested class with comment: "// Generated by bestest — {timestamp}"
Else (no test file but file exists at the target path):
  Print: "Warning: File exists at {test-path} but was not detected as a test file."
  Print: "Generating to {test-path}.new to avoid overwriting."
  Generate to a .new suffixed file and present for manual merge.
```

## 11. Multi-module Gradle project

**Trigger:** `settings.gradle` includes multiple subprojects, and the target file is in a submodule.

**Response:**
```
For each target file in a multi-module project:
  Determine which submodule it belongs to (from settings.gradle include paths).
  Read that submodule's build.gradle for dependencies.
  Run compilation and tests in the submodule context:
    ./gradlew :submodule:compileTestJava
    ./gradlew :submodule:test --tests "com.example.TestClass"
  Generate tests using the submodule's dependencies and configuration.
```
Each submodule is handled independently. A failure in one submodule does not block others.
