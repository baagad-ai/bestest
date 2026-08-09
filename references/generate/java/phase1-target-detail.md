# Phase 1 — Target Selection Detail (Java)

Detailed targeting heuristics, path validation, and preflight environment checks for Java projects.

## Path Validation

Before processing any target path through the targeting modes, validate the path to prevent filesystem traversal attacks, canonicalization issues, and invalid inputs. Apply these six validation steps, **in this exact order**, to every user-supplied path — ordering matters for security:

```
1. Traversal rejection: Reject raw userPath with a ".." path segment or starting with "/".
   String[] segments = userPath.split("[\\\\/]");
   if (any segment equals ".." or userPath.startsWith("/")):
     print(f"Invalid path: directory traversal detected.")
     Exit.
   (Segment-based, not substring: a legitimate filename like "file..name" must NOT be rejected.)

2. Canonicalize: Resolve symlinks and relative segments (./) using Path.toRealPath().
   canonical = Paths.get(userPath).toRealPath()

3. Boundary check: Verify the canonical path starts with the project root.
   if (!canonical.startsWith(projectRoot)):
     print(f"Path escapes project boundary: {userPath}")
     Exit.

4. Existence check: Verify the file or directory exists.
   if (!Files.exists(canonical)):
     print(f"Path does not exist: {userPath}")
     Exit.

5. File type check: If targeting a single file, verify it matches *.java.
   if (isFile && !canonical.toString().endsWith(".java")):
     print(f"File type not supported: {canonical}. Expected .java.")
     Exit.

6. Sensitive file exclusion: Reject files matching sensitive filename patterns.
   Sensitive BASENAME patterns (case-insensitive): .env, .env.*, *.pem, *.key, *.p12,
     *.pfx, *.jks, id_rsa*, id_ed25519*, id_ecdsa*, credentials.*, service-account*.json,
     .netrc, .npmrc, .pypirc, *.keystore, *.truststore
   Sensitive DIRECTORY patterns (matched against the FULL canonical path, not basename):
     .aws/, .ssh/, .gnupg/, .git/, .hg/, .svn/, node_modules/, .venv/, .tox/, secrets/
   String basename = canonical.getFileName().toString()
   if (basename matches any sensitive basename pattern, case-insensitive
       OR canonical.toString().contains any sensitive directory pattern):
     print(f"Sensitive file rejected: {canonical}. Test generation for credential and key files is blocked for security.")
     Exit.
```

All six checks must pass before the path enters any targeting mode below. If any check fails, print the error and exit — do not fall through to other modes.

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
    If it's a test file (*Test.java or *Tests.java): error, "Cannot generate tests for a test file."
    If it's in src/test/java: error, "Cannot generate tests for a test source file."
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
    Glob all files matching paths.src (src/main/java/**/*.java).
    For each source file, check if corresponding test file exists by naming convention:
      src/main/java/com/example/UserService.java → src/test/java/com/example/UserServiceTest.java
    Set targets = source files with no corresponding test file.
```

### Mode 3: `--type <kind>` flag

```
If --type <kind> is specified (kind = controller | service | repository | component | configuration | utility):
  Filter source files by Spring annotation or code type:
    controller: files containing @Controller, @RestController
    service: files containing @Service
    repository: files containing @Repository or extending JpaRepository/CrudRepository
    component: files containing @Component (not @Service, @Controller, @Repository)
    configuration: files containing @Configuration or @SpringBootApplication
    utility: files with no Spring annotations and only static methods
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
      - Classes imported by 10+ other classes (high impact radius)
      - Files matching patterns: Auth*, Login*, Payment*, Checkout*, Permission*, Security*
      - Entry points: Application.java, *Application.java, *Config.java
      - Classes with high method count (10+ public methods)
      - Classes with complex generics or nested type parameters
  Set targets = prioritized files.
```

### Default (no flags)

```
If no targeting flag is provided and no path argument:
  If mode is "scan-guided":
    Set targets = gaps[] sorted by priority (critical → high → medium), limited to top 10 files.
  Else:
    Print: "No target specified. Use one of:"
    Print: "  /bestest generate <path>        — Generate for a specific file or directory"
    Print: "  /bestest generate --untested     — Generate for all files with no tests"
    Print: "  /bestest generate --type <kind>  — Generate for a specific code type"
    Print: "  /bestest generate --critical     — Generate for critical-priority gaps"
    Exit.
```

## Priority Scoring Formula

When multiple targeting criteria overlap, score each file and process in order:

```
score = 0
if has no test file:                    score += 40
if priority == "critical":              score += 30
if priority == "high":                  score += 20
if imported by 10+ classes:            score += 15
if file is entry point or auth module:  score += 10
if coverage < 30% (has test but low):   score += 10
if has Spring annotations:              score += 5

Process files in descending score order.
```

## Java test file naming conventions

Generated test files follow the standard Maven/Gradle directory structure with package mirroring:

| Source File | Generated Test File |
|-------------|-------------------|
| `src/main/java/com/example/service/UserService.java` | `src/test/java/com/example/service/UserServiceTest.java` |
| `src/main/java/com/example/controller/AuthController.java` | `src/test/java/com/example/controller/AuthControllerTest.java` |
| `src/main/java/com/example/util/Calculator.java` | `src/test/java/com/example/util/CalculatorTest.java` |

Detect existing convention by scanning existing test file naming. Match the dominant pattern (`*Test.java` vs `*Tests.java`). Default to `*Test.java` if no convention established.

## Java Environment Detection Detail

### JDK detection

```
Check for JDK:
  1. Check JAVA_HOME environment variable → if set, verify it points to a JDK (not JRE).
     Test: $JAVA_HOME/bin/javac -version or $JAVA_HOME/bin/java -version
  2. Check java -version → verify it returns 11 or higher.
  3. Check javac -version → verify the Java compiler is available (JDK, not JRE).
  4. Check for JAVA_HOME/lib/tools.jar (JDK 8) or JAVA_HOME/release file with JAVA_VERSION (JDK 9+).

If no JDK is found:
  Print: "Error: No Java JDK found. JRE is not sufficient — compilation requires javac."
  Print: "Install JDK 11+ and set JAVA_HOME."
  Print: "  macOS: brew install openjdk@17"
  Print: "  Linux: sudo apt install openjdk-17-jdk"
  Print: "  Windows: Download from https://adoptium.net/"
  Exit.

Check Java version:
  If Java version < 11:
    Print: "Warning: Java {version} detected. JUnit 5 requires Java 8+, but Java 11+ is recommended."
    Print: "Generated tests using modern features (var, text blocks, records) may not compile."
    Continue with warning.
```

### Build tool detection (Maven/Gradle dual paths)

```
Check for build tool:
  1. Check for gradlew or gradlew.bat in project root → Gradle project.
  2. Check for mvnw or mvnw.cmd in project root → Maven project.
  3. Check for build.gradle or build.gradle.kts → Gradle project (no wrapper).
  4. Check for pom.xml → Maven project (no wrapper).

If neither build tool is found:
  Print: "Error: Neither Gradle nor Maven build tool detected."
  Print: "bestest requires a build tool to compile and run tests."
  Print: "Initialize a project with: gradle init or mvn archetype:generate"
  Exit.

Check for JUnit 5 in dependencies:
  Gradle: grep for useJUnitPlatform() or junit-jupiter in build.gradle
  Maven: grep for junit-jupiter in pom.xml
  If JUnit 5 is not configured:
    Print: "Warning: JUnit 5 not detected in build configuration."
    Print: "Tests will be generated using JUnit 5 conventions."
    Print: "Add JUnit 5 to your build:"
    Print: "  Gradle: testImplementation 'org.junit.jupiter:junit-jupiter:5.10.2'"
    Print: "  Gradle: test { useJUnitPlatform() }"
    Print: "  Maven: Add junit-jupiter dependency and maven-surefire-plugin 3.2.5+"
    Continue in degraded mode (compilation/execution may fail).
```

### State corruption handling

```
If JSON parsing fails for stack-profile.json:
  Print: "⚠ State file corruption detected: .bestest/state/stack-profile.json"
  Print: "  The file contains invalid JSON and cannot be read."
  Print: "  Options:"
  Print: "    (a) Regenerate — delete .bestest/ and re-run /bestest init."
  Print: "    (b) Manual fix — edit the file to correct the JSON syntax."
  Print: "    (c) Abort — exit without proceeding."
  Wait for user choice. Do NOT proceed with corrupted state.
```

### Schema version validation

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
