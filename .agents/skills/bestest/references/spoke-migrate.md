# /bestest migrate

## Purpose

Framework migration spoke that transforms test suites from one testing framework to another using AST-aware transformation rules. Accepts `bestest migrate <from> <to>` with support for three migration paths:

| Migration Path | CLI Command | Scope |
|---------------|-------------|-------|
| Jest → Vitest | `bestest migrate jest vitest` | All `*.test.{ts,tsx,js,jsx}` files + jest.config |
| JUnit 4 → JUnit 5 | `bestest migrate junit4 junit5` | All `*Test.java` files with JUnit 4 imports + build config |
| Cypress → Playwright | `bestest migrate cypress playwright` | All `*.cy.{js,ts}` files + cypress.config |

The migrate spoke uses a git-based backup strategy (stash) for safe rollback, performs per-file complexity classification before transformation, applies AST-aware rules from `references/migration-rules.md` augmented with live Context7 documentation, and verifies post-migration correctness with an auto-fix loop.

**Safety boundary:** The migrate spoke NEVER modifies production source code — only test files, test configuration, and build configuration. If a test failure is caused by a source bug, it is flagged for manual resolution.

## Prerequisites

- `.bestest/` directory with valid `config.yaml` (run `/bestest init` first)
- **Git repository** — git MUST be initialized (`.git` directory exists). The migrate spoke uses `git stash` for backup/rollback. If git is not initialized, the spoke BLOCKS with a clear message — migrations without version control are unsafe.
- StackProfile at `.bestest/state/stack-profile.json` is recommended for framework detection accuracy but not required.
- The source framework must be detectable in the project (config files, imports, or dependency declarations).

---

## Pre-Flight Checks

> **Shared protocol:** This spoke uses the **Standard 3-Step `.bestest/` Validation** from `references/pre-flight-protocol.md` (Steps 1–3: `.bestest/` existence, `config.yaml` presence, YAML validity). Read that document for the full validation specification including error message templates.

Spoke-specific additions beyond the shared protocol:

Parse and extract fields used during migration:
- `framework` — current test framework (should match source framework)
- `language` — primary language (affects file patterns)
- `paths.test` — test file glob pattern
- `paths.src` — source file glob pattern

### Check git is initialized

```
If .git directory does not exist:
  Print: "╔══════════════════════════════════════════════════════════════╗"
  Print: "║  BLOCKED: Git repository required for safe migration        ║"
  Print: "╠══════════════════════════════════════════════════════════════╣"
  Print: "║                                                              ║"
  Print: "║  bestest migrate uses git stash for backup and rollback.    ║"
  Print: "║  Without git, a failed migration cannot be reversed.        ║"
  Print: "║                                                              ║"
  Print: "║  To proceed:                                                 ║"
  Print: "║    1. Run: git init                                          ║"
  Print: "║    2. Commit your current test files                         ║"
  Print: "║    3. Re-run: bestest migrate <from> <to>                   ║"
  Print: "╚══════════════════════════════════════════════════════════════╝"
  Exit. No migration performed.

If git working tree has uncommitted changes:
  Print: "Warning: Uncommitted changes detected in working tree."
  Print: "These will NOT be included in the migration backup."
  Print: "Consider committing or stashing before migration."
  Print: ""
  Print: "Proceed anyway? (y/N)"
  If user declines:
    Exit.
```

### Check source framework is detected

Validate that the source framework is actually present in the project. Detection patterns:

| Source Framework | Detection Patterns |
|-----------------|-------------------|
| **jest** | `jest.config.{js,ts,mjs,cjs}`, `jest` in `package.json` devDependencies, `@jest/globals` in imports, `*.test.{ts,tsx,js,jsx}` files with `jest` globals |
| **junit4** | `@org.junit.Test` imports in `*Test.java` files, `junit:junit:4.x` in `pom.xml` or `build.gradle`, `@RunWith` annotations |
| **cypress** | `cypress.config.{js,ts}`, `cypress` in `package.json` devDependencies, `cypress/` directory, `*.cy.{js,ts}` files |

```
If source framework cannot be detected:
  Print: "Cannot detect '{from}' framework in this project."
  Print: "Checked for: {detection patterns for this framework}"
  Print: ""
  Print: "If you believe {from} is present, ensure:"
  Print: "  - Config files exist at the project root"
  Print: "  - Dependencies are declared in package.json or build config"
  Print: "  - Test files use {from} imports or syntax"
  Exit. No migration performed.
```

### Validate target framework

Check that the requested migration path is supported:

```
Normalize arguments:
  'jest' | 'Jest' → 'jest'
  'vitest' | 'Vitest' → 'vitest'
  'junit4' | 'junit-4' | 'JUnit4' | 'junit' → 'junit4'
  'junit5' | 'junit-5' | 'JUnit5' → 'junit5'
  'cypress' | 'Cypress' → 'cypress'
  'playwright' | 'Playwright' → 'playwright'

If the migration path is not in the supported list:
  Print: "Unsupported migration path: {from} → {to}"
  Print: "Supported paths:"
  Print: "  jest → vitest"
  Print: "  junit4 → junit5"
  Print: "  cypress → playwright"
  Exit. No migration performed.
```

### 5. Check target framework is not already in use

```
Detect if target framework is already configured in the project:
  vitest: vitest.config.{js,ts}, 'vitest' in devDependencies
  junit5: @org.junit.jupiter.api imports, 'junit-jupiter' in dependencies
  playwright: playwright.config.{js,ts}, '@playwright/test' in devDependencies

If target framework is already in use:
  Print: "Warning: Target framework '{to}' appears to already be configured."
  Print: "Found: {evidence of target framework}"
  Print: ""
  Print: "This could mean:"
  Print: "  1. A previous partial migration — some files may already be migrated"
  Print: "  2. Both frameworks are intentionally used side-by-side"
  Print: ""
  Print: "Continue migration for remaining files? (y/N)"
  If user declines:
    Exit.
```

### 6. Create git stash backup

Create a backup of all test files that will be modified during migration:

```
Determine file globs to stash based on source framework:
  jest:      *.test.{ts,tsx,js,jsx} jest.config.{js,ts,mjs,cjs} package.json package-lock.json
  junit4:    *Test.java build.gradle build.gradle.kts pom.xml
  cypress:   *.cy.{js,ts} cypress.config.{js,ts} cypress/support/**/* package.json package-lock.json

stash_tag = "bestest-migrate-pre-{from}-{to}-{timestamp}"

Run: git stash push -m "{stash_tag}" -- {file_globs}

If stash fails (e.g., no tracked files match):
  Print: "Warning: No tracked test files found to stash."
  Print: "Migration will proceed without backup."
  Set backup_created = false
  Set stash_ref = null
Else:
  Set stash_ref = extract from git stash list output
  Set backup_created = true
  Verify stash: git stash list | grep "{stash_tag}"
  If not found:
    Print: "Error: Git stash was created but could not be verified."
    Print: "Aborting migration to ensure safety."
    Exit.
```

### 7. Record backup state

Write migration state to `.bestest/state/migration-backup.json`:

```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "from": "jest",
  "to": "vitest",
  "stash_ref": "stash@{0}",
  "stash_tag": "bestest-migrate-pre-jest-vitest-20250115T103000",
  "files_targeted": ["src/utils/format.test.ts", "src/components/App.test.tsx"],
  "status": "in_progress",
  "phase": "pre-flight-complete",
  "rollback_available": true
}
```

This state file enables any agent to detect an interrupted migration and decide whether to resume or rollback.

---

## Phase 1 — Analysis & Planning

Discover all test files, classify complexity, and generate the migration plan.

### 1.1 Discover Test Files

Scan for all test files matching the source framework patterns:

| Source Framework | File Patterns | Detection Method |
|-----------------|---------------|-----------------|
| **jest** | `**/*.test.{ts,tsx,js,jsx}`, `**/*.spec.{ts,tsx,js,jsx}` | Glob patterns; verify `jest`/`@jest/globals` imports |
| **junit4** | `**/*Test.java` | Glob pattern; scan for `@org.junit.Test` annotation |
| **cypress** | `cypress/e2e/**/*.cy.{js,ts}`, `cypress/e2e/**/*.spec.{js,ts}` | Glob pattern; verify in `cypress/` directory |

Also discover config files:
- jest: `jest.config.{js,ts,mjs,cjs}`, `jest.setup.{js,ts}`
- junit4: `build.gradle`, `build.gradle.kts`, `pom.xml`
- cypress: `cypress.config.{js,ts}`, `cypress/support/e2e.{js,ts}`, `cypress/plugins/index.{js,ts}`

```
For each discovered file:
  Verify it contains source framework patterns (not just name-matched).
  Files that match the glob but don't contain source framework patterns are excluded.

Set test_files = verified test files
Set config_files = discovered config files
Set total_file_count = test_files.length + config_files.length

If total_file_count == 0:
  Print: "No files found matching '{from}' patterns."
  Print: "Cannot proceed with migration — nothing to transform."
  Cleanup: Remove backup state file if backup was created.
  Exit.
```

### 1.2 Classify File Complexity

For each test file, classify its migration complexity using the criteria from `references/migration-rules.md` Section 4.2:

```
For each file in test_files:
  Read file content.
  Scan for patterns based on migration path:

  jest → vitest:
    simple:    basic expect() assertions, no jest.fn/mock/spyOn, no lifecycle hooks
    moderate:  jest.fn(), jest.spyOn(), jest.mock(), beforeEach/afterEach, jest.useFakeTimers, snapshot assertions
    complex:   __mocks__ directories, custom transformers, jasmine globals, jest-community plugins,
               jest.retryTimes, custom reporters, jest.requireActual inside mock factories

  junit4 → junit5:
    simple:    @Test methods with assertEquals/assertTrue, no @Rule, no @RunWith, no parameterized tests
    moderate:  @Before/@After lifecycle, @Ignore, @RunWith(Parameterized), @Test(expected=), assertThat with Hamcrest
    complex:   @Rule/@ClassRule (custom rules), @RunWith(custom runner), ExpectedException rule,
               ErrorCollector, custom test watchers, Theories runner

  cypress → playwright:
    simple:    basic cy.visit/click/type with .should() assertions, no custom commands
    moderate:  custom commands, cy.intercept, cy.fixture, beforeEach with page setup, config customization
    complex:   conditional testing, cy.session/cy.origin, plugins directory, cy.task,
               third-party plugins, iframe interactions

  Set file.complexity = classification result
  Set file.flags = list of detected patterns requiring attention
```

### 1.3 Generate Per-File Migration Plan

For each file, generate a migration plan entry:

```
For each file:
  plan_entry = {
    file: file.path,
    complexity: file.complexity,
    flags: file.flags,
    risk: classify_risk(file.complexity),
    manual_review: file.complexity == "complex",
    estimated_transforms: count_of_pattern_matches(file)
  }

  Risk classification:
    simple    → low risk
    moderate  → medium risk
    complex   → high risk
```

### 1.4 HITL Gate 1 — Migration Plan Approval

<!-- gate_tier: manual — Full human approval required. Migration transforms are destructive AST changes that are difficult to reverse without git. -->

Present the migration plan to the user for approval before transformation:

```
Print: "╔══════════════════════════════════════════════════════════════╗"
Print: "║               Migration Plan: {from} → {to}                 ║"
Print: "╠══════════════════════════════════════════════════════════════╣"
Print: "║                                                              ║"
Print: "║  Files to migrate:    {total}                                 ║"
Print: "║    Simple:            {simple_count}   (auto-transform)       ║"
Print: "║    Moderate:          {moderate_count} (auto + verify)        ║"
Print: "║    Complex:           {complex_count}  (flag for review)     ║"
Print: "║                                                              ║"
Print: "║  Config files:        {config_count}                          ║"
Print: "║  Files for review:    {manual_review_count}                   ║"
Print: "║  Overall risk:        {overall_risk}                          ║"
Print: "║                                                              ║"
Print: "║  Backup:              {backup_status}                         ║"
Print: "║  Stash ref:           {stash_ref}                             ║"
Print: "║                                                              ║"

If manual_review_count > 0:
  Print: "║  Files requiring manual review:                              ║"
  For each manual_review_file:
    Print: "║    • {file} ({flags})                                        ║"

Print: "║                                                              ║"
Print: "║  Proceed with migration? (Y/n)                               ║"
Print: "╚══════════════════════════════════════════════════════════════╝"

If user declines:
  Print: "Migration cancelled."
  Cleanup: Remove backup state file.
  If backup was created: optionally drop stash.
  Exit.
```

---

## Phase 2 — Context7 Fetch

Fetch version-specific documentation for the target framework and merge with static migration rules.

### 2.1 Resolve Target Framework Library

```
Resolve Context7 library ID for the target framework:
  vitest:      resolve_library({ libraryName: "vitest", query: "vitest migration config" })
  junit5:      resolve_library({ libraryName: "junit-jupiter", query: "junit 5 assertions extensions" })
  playwright:  resolve_library({ libraryName: "playwright", query: "playwright test api config" })

If resolve_library fails or returns no results:
  Print: "Context7 library resolution failed for '{to}'."
  Print: "Falling back to static migration rules only."
  Set live_docs = null
  Continue to Step 2.3.
```

### 2.2 Fetch Live Documentation

```
Fetch targeted documentation for version-accurate transformations:
  vitest:      get_library_docs({ libraryId: id, query: "vi mock assertions config migration from jest", tokens: 5000 })
  junit5:      get_library_docs({ libraryId: id, query: "junit 5 assertions parameterized test extensions migration", tokens: 5000 })
  playwright:  get_library_docs({ libraryId: id, query: "playwright test page locator assertions config migration from cypress", tokens: 5000 })

If get_library_docs fails:
  Print: "Context7 documentation fetch failed: {error}"
  Print: "Continuing with static migration rules from references/migration-rules.md"
  Set live_docs = null
```

### 2.3 Load Static Migration Rules

```
Read static transformation rules from references/migration-rules.md:
  - Section 1 (Jest → Vitest) or Section 2 (JUnit 4 → 5) or Section 3 (Cypress → Playwright)
  - Section 4 (General Migration Principles)

Set static_rules = parsed rules from the appropriate sections
```

### 2.4 Merge Live and Static Rules

```
If live_docs is not null:
  Merge live documentation with static rules.
  Conflict resolution: live docs override static rules for version-specific API changes.
  Static rules provide the structural transformation patterns.
  Live docs provide version-accurate parameter names, config fields, and API signatures.

  Set merged_rules = merge(static_rules, live_docs)
Else:
  Set merged_rules = static_rules

The merged_rules are used in Phase 4 (Transform) for AST-aware file transformation.
```

---

## Phase 3 — Transform

Apply AST-aware transformation rules to each test file. Transformations are atomic per-file — a failure in one file does not block others. Per-file results are tracked in the migration plan for the final report.

### 3.1 Transformation Strategy by Complexity

| Complexity | Strategy | On Failure |
|-----------|----------|-----------|
| **simple** | Full auto-transformation. Apply all rules. No HITL needed. | Log error, skip file, continue. |
| **moderate** | Full auto-transformation + post-transform verification (Phase 5). Flag patterns needing manual validation. | Log error, skip file, continue. |
| **complex** | Partial auto-transformation. Insert `// TODO: migrate manually` comments for unsupported patterns. Full transformation of supported subsets. | Log error, skip file, continue. |

All files are transformed independently. A single file failure sets that file's status to `transform-failed` and continues with remaining files.

### 3.2 Per-File Transformation Tracking

Each file gets a transformation record:

```json
{
  "file": "src/utils/format.test.ts",
  "status": "success | failed | skipped",
  "complexity": "simple | moderate | complex",
  "transformations_applied": {
    "imports_changed": 0,
    "mocks_changed": 0,
    "assertions_changed": 0,
    "lifecycle_hooks_changed": 0,
    "annotations_changed": 0,
    "config_fields_mapped": 0
  },
  "auto_fixes_applied": 0,
  "flags": [],
  "errors": []
}
```

### 3.3 Jest → Vitest: File Transformation

Apply the following transformation sequence to each Jest test file. Rules reference: `migration-rules.md → Jest → Vitest Rules → Import Replacements` and `Jest → Vitest: Mock API Mapping`.

#### 3.3.1 Import Transformation

Apply import replacements in order. Each replacement is a scoped transformation that updates only the import statement and its references.

**Step 1: Replace `@jest/globals` imports with `vitest` imports.**

| Source Pattern | Target Pattern |
|---------------|---------------|
| `import { describe, it, expect, jest } from '@jest/globals'` | `import { describe, it, expect, vi } from 'vitest'` |
| `import { jest } from '@jest/globals'` | `import { vi } from 'vitest'` |
| `import { describe, it, expect, jest, beforeAll, afterAll, beforeEach, afterEach } from '@jest/globals'` | `import { describe, it, expect, vi, beforeAll, afterAll, beforeEach, afterEach } from 'vitest'` |

Rules:
- Remove `jest` from the import specifier, add `vi` if not present.
- Remove the `@jest/globals` import entirely if it only contained `describe`, `it`, `expect`, `beforeEach`, `afterEach`, `beforeAll`, `afterAll` (these are auto-imported by Vitest).
- If the file uses `jest.fn()` or other mock APIs, ensure `vi` is imported from `vitest`.
- Increment `imports_changed` counter for each import statement modified.

**Step 2: Replace `jest` globals imports.**

| Source Pattern | Target Pattern |
|---------------|---------------|
| `import jest from 'jest'` | Remove (not needed in Vitest) |
| `const { jest } = require('@jest/globals')` | `import { vi } from 'vitest'` |

**Step 3: Detect implicit `jest` global usage.**

If the file uses `jest.fn()`, `jest.mock()`, `jest.spyOn()`, or any `jest.*` call without an explicit import (Jest injects these as globals):
- Add `import { vi } from 'vitest'` at the top of the file (after existing imports).
- Do NOT add if `vi` is already imported.

#### 3.3.2 Mock API Transformation

Replace all `jest.*` mock API calls with `vi.*` equivalents. See `migration-rules.md → Jest → Vitest: Mock API Mapping`.

| Source API | Target API | Notes |
|-----------|-----------|-------|
| `jest.fn()` | `vi.fn()` | Direct replacement |
| `jest.fn(implementation)` | `vi.fn(implementation)` | Implementation argument preserved |
| `jest.spyOn(obj, method)` | `vi.spyOn(obj, method)` | Direct replacement |
| `jest.mock('module')` | `vi.mock('module')` | Direct replacement |
| `jest.mock('module', factory)` | `vi.mock('module', factory)` | Factory function preserved; note: Vitest factory receives `importOriginal` helper |
| `jest.doMock('module')` | `vi.doMock('module')` | Direct replacement |
| `jest.unmock('module')` | `vi.unmock('module')` | Direct replacement |
| `jest.createMockFromModule('module')` | `vi.createMockFromModule('module')` | Direct replacement |
| `jest.requireActual('module')` | `importActual from vi.mock factory` | See note below |
| `jest.useFakeTimers()` | `vi.useFakeTimers()` | Direct replacement |
| `jest.advanceTimersByTime(ms)` | `vi.advanceTimersByTime(ms)` | Direct replacement |
| `jest.advanceTimersToNextTimer()` | `vi.advanceTimersToNextTimer()` | Direct replacement |
| `jest.clearAllTimers()` | `vi.clearAllTimers()` | Direct replacement |
| `jest.getTimerCount()` | `vi.getTimerCount()` | Direct replacement |
| `jest.now()` | `vi.now()` | Direct replacement |
| `jest.setSystemTime(date)` | `vi.setSystemTime(date)` | Direct replacement |
| `jest.clearAllMocks()` | `vi.clearAllMocks()` | Direct replacement |
| `jest.resetAllMocks()` | `vi.resetAllMocks()` | Direct replacement |
| `jest.restoreAllMocks()` | `vi.restoreAllMocks()` | Direct replacement |
| `jest.setTimeout(ms)` | `vi.setConfig({ testTimeout: ms })` | Different API shape |
| `jest.retryTimes(n)` | `vi.setConfig({ retry: n })` | Different API shape |
| `jest.replaceProperty(obj, prop, value)` | `vi.spyOn(obj, prop, 'get').mockReturnValue(value)` | Requires structural change — flag complex files |

**`jest.requireActual` transformation:**
```
Source:
  jest.mock('module', () => {
    const actual = jest.requireActual('module');
    return { ...actual, foo: jest.fn() };
  });

Target:
  vi.mock('module', async (importOriginal) => {
    const actual = await importOriginal();
    return { ...actual, foo: vi.fn() };
  });
```

For each mock API replacement, increment `mocks_changed` in the transformation record.

#### 3.3.3 Mock Module Resolution (`__mocks__` Directories)

Jest auto-loads mocks from `__mocks__/` directories adjacent to the mocked module. Vitest also supports `__mocks__` but only when `vi.mock()` is explicitly called.

**Detection:**
```
1. Scan for __mocks__/ directories in the project.
2. For each mock file in __mocks__/, identify the corresponding source module.
3. Check if the test file has an explicit vi.mock() (or jest.mock()) call for that module.
```

**Transformation:**
```
For each test file that uses a module with a __mocks__/ counterpart:
  If the file has jest.mock('module') → already has explicit mock call, no action needed.
  If the file has NO jest.mock('module') → add vi.mock('module') at the top of the test file
    (after imports, before describe blocks).
  Add comment: "// Vitest requires explicit vi.mock() for __mocks__ to activate"
```

Document in the migration report: `__mocks__` directories are preserved (no structural change), but explicit `vi.mock()` calls are added where needed.

#### 3.3.4 Assertion Handling

Most Jest assertions work identically in Vitest (Vitest is Jest-compatible). No transformation needed for:
- `expect(value).toBe(expected)`
- `expect(value).toEqual(expected)`
- `expect(value).toThrow()`
- `.resolves` / `.rejects` — identical API in Vitest
- All standard matchers (`toHaveBeenCalled`, `toHaveBeenCalledWith`, `toHaveLength`, etc.)

**Exceptions requiring transformation:**

| Source Pattern | Target Pattern | Notes |
|---------------|---------------|-------|
| `expect.extend({ ... })` | `expect.extend({ ... })` | API is compatible, but custom matchers may need Vitest-specific types. Flag complex files. |

Increment `assertions_changed` only if a transformation was actually applied (most files: 0).

#### 3.3.5 Snapshot Handling

Vitest reads Jest snapshots natively — no transformation needed for:
- `expect(value).toMatchSnapshot()`
- `expect(value).toMatchInlineSnapshot()`
- `expect(value).toThrowErrorMatchingSnapshot()`

**Add a comment block at the top of `__snapshots__/` directories (if they exist):**
```
// MIGRATION NOTE: Snapshots were created with Jest.
// Vitest reads Jest snapshot format natively.
// New snapshots created after migration will use Vitest format.
// If snapshot format issues arise, run: npx vitest --update
```

#### 3.3.6 Lifecycle Hooks

Lifecycle hooks have identical APIs in Jest and Vitest — no transformation needed:
- `beforeEach(fn)`, `afterEach(fn)`, `beforeAll(fn)`, `afterAll(fn)`

**Note for documentation:** Vitest 2.0+ changed default hook execution from parallel to serial. If the project relies on parallel hook execution (rare), flag for manual review. Increment `lifecycle_hooks_changed` only if any hook-specific transformation was applied (typically 0 for Jest→Vitest).

#### 3.3.7 Per-File Transformation Procedure

```
For each file in test_files (sorted by complexity: simple first):

  1. Read file content into memory.
  2. Initialize file_transform_record = { file, status: "in_progress", transformations_applied: all zeros }
  3. Apply transformations IN ORDER:
     a. Import transformation (Section 3.3.1)
     b. Mock API transformation (Section 3.3.2)
     c. __mocks__ resolution (Section 3.3.3) — if applicable
     d. Assertion handling (Section 3.3.4) — typically no-op
     e. Snapshot comments (Section 3.3.5) — if applicable
     f. Lifecycle hooks (Section 3.3.6) — typically no-op

  4. After all transformations applied:
     - Validate the file can be parsed (TypeScript/JavaScript syntax check).
     - If parse succeeds:
       file_transform_record.status = "success"
       Write transformed file to disk (overwrite original).
     - If parse fails:
       Print: "Syntax error after transformation: {file}"
       Attempt auto-fix (fix import syntax, remove duplicate imports).
       If auto-fix succeeds: status = "auto-fixed", write file.
       If auto-fix fails:
         Restore original file from in-memory content.
         file_transform_record.status = "failed"
         file_transform_record.errors.push(parse_error)
         Print: "Skipping file due to transform failure: {file}"

  5. Append file_transform_record to migration_plan.per_file_status.

  6. Check failure threshold:
     failed_count = count of files with status "failed"
     If failed_count > 50% of total files:
       Print: "Critical: >50% of files failed transformation. Aborting."
       Trigger Phase 6 (Rollback).
       Exit Phase 3.

After all files processed:
  If all files succeeded or auto-fixed:
    Proceed to Phase 4 (Config Migration).
  If some files failed (but <50%):
    Proceed to Phase 4 (Config Migration) — failures tracked for Phase 5 (Verification).
```

### 3.4 JUnit 4 → JUnit 5: File Transformation

Apply the following transformation sequence to each JUnit 4 test file. Rules reference: `migration-rules.md → JUnit 4 → JUnit 5: Annotation Mapping` and `JUnit 4 → JUnit 5: Assertion Parameter Reordering`.

#### 3.4.1 Annotation Transformation

Replace JUnit 4 annotations with JUnit 5 equivalents. See `migration-rules.md → JUnit 4 → JUnit 5: Annotation Mapping`.

| Source Annotation | Target Annotation | Transformation Notes |
|------------------|------------------|---------------------|
| `@org.junit.Test` | `@org.junit.jupiter.api.Test` | Remove `expected` and `timeout` params (handled separately) |
| `@Test` (unqualified, in JUnit 4 context) | `@Test` (from `org.junit.jupiter.api.Test`) | Update import only |
| `@Before` | `@BeforeEach` | Direct replacement + update import |
| `@After` | `@AfterEach` | Direct replacement + update import |
| `@BeforeClass` | `@BeforeAll` | Verify method is `static`. If not static, flag for manual review. |
| `@AfterClass` | `@AfterAll` | Verify method is `static`. If not static, flag for manual review. |
| `@Ignore` | `@Disabled` | Direct replacement + update import |
| `@Ignore("reason")` | `@Disabled("reason")` | Preserve reason string |
| `@RunWith(MockitoJUnitRunner.class)` | `@ExtendWith(MockitoExtension.class)` | Update import to `org.mockito.junit.jupiter.MockitoExtension` |
| `@RunWith(SpringRunner.class)` | `@ExtendWith(SpringExtension.class)` | Update import to `org.springframework.test.context.junit.jupiter.SpringExtension` |
| `@Rule` | `@ExtendWith(...)` or `@RegisterExtension` | See Section 3.4.5 for rule-specific handling |
| `@ClassRule` | `@RegisterExtension` (static field) | See Section 3.4.5 for rule-specific handling |
| `@RunWith(Parameterized.class)` | `@ParameterizedTest` + `@MethodSource` / `@CsvSource` | See Section 3.4.6 for parameterized test handling |

For each annotation replacement, increment `annotations_changed` in the transformation record.

#### 3.4.2 Import Changes

Update import statements:

| Source Import | Target Import |
|-------------|-------------|
| `import org.junit.Test;` | `import org.junit.jupiter.api.Test;` |
| `import org.junit.Before;` | `import org.junit.jupiter.api.BeforeEach;` |
| `import org.junit.After;` | `import org.junit.jupiter.api.AfterEach;` |
| `import org.junit.BeforeClass;` | `import org.junit.jupiter.api.BeforeAll;` |
| `import org.junit.AfterClass;` | `import org.junit.jupiter.api.AfterAll;` |
| `import org.junit.Ignore;` | `import org.junit.jupiter.api.Disabled;` |
| `import org.junit.Assert.*;` | `import org.junit.jupiter.api.Assertions.*;` |
| `import static org.junit.Assert.assertEquals;` | `import static org.junit.jupiter.api.Assertions.assertEquals;` |
| `import static org.junit.Assert.assertTrue;` | `import static org.junit.jupiter.api.Assertions.assertTrue;` |
| `import static org.junit.Assert.assertThat;` | `import static org.hamcrest.MatcherAssert.assertThat;` | 
| `import org.junit.runner.RunWith;` | `import org.junit.jupiter.api.extension.ExtendWith;` |
| `import org.mockito.junit.MockitoJUnitRunner;` | `import org.mockito.junit.jupiter.MockitoExtension;` |

**Additional imports to add if needed:**
- `import org.junit.jupiter.params.ParameterizedTest;` — for parameterized tests
- `import org.junit.jupiter.params.provider.MethodSource;` — for `@MethodSource`
- `import org.junit.jupiter.params.provider.CsvSource;` — for `@CsvSource`
- `import java.time.Duration;` — for timeout transformations (Section 3.4.4)
- `import org.junit.jupiter.api.Assertions;` — for `assertThrows` and `assertTimeout`

Increment `imports_changed` for each import modified or added.

#### 3.4.3 Assertion Parameter Reordering

**CRITICAL:** JUnit 4 places the message parameter first; JUnit 5 places it last. Incorrect reordering silently changes test semantics. This is the highest-risk transformation. See `migration-rules.md → JUnit 4 → JUnit 5: Assertion Parameter Reordering`.

**Detection heuristic:**
- 3-arg `assertEquals("message", expected, actual)` → the first argument is a string literal AND is NOT the expected value. If both expected and message are string literals, use type context (JUnit 4 pattern: message is always first).
- 2-arg `assertTrue("message", condition)` → first argument is a string literal, second is a boolean expression.

| Source Pattern | Target Pattern | Risk |
|---------------|---------------|------|
| `assertEquals("msg", expected, actual)` | `assertEquals(expected, actual, "msg")` | Medium — message moves from first to last |
| `assertEquals(expected, actual)` | `assertEquals(expected, actual)` | None — no change needed |
| `assertTrue("msg", condition)` | `assertTrue(condition, "msg")` | Medium |
| `assertFalse("msg", condition)` | `assertFalse(condition, "msg")` | Medium |
| `assertNull("msg", object)` | `assertNull(object, "msg")` | Medium |
| `assertNotNull("msg", object)` | `assertNotNull(object, "msg")` | Medium |
| `assertSame("msg", expected, actual)` | `assertSame(expected, actual, "msg")` | Medium |
| `assertNotSame("msg", expected, actual)` | `assertNotSame(expected, actual, "msg")` | Medium |
| `assertArrayEquals("msg", expected, actual)` | `assertArrayEquals(expected, actual, "msg")` | Medium |
| `assertThat("msg", actual, matcher)` | `assertThat(actual, matcher)` + add comment `// Original message: "msg"` | Medium — Hamcrest assertThat drops message in JUnit 5 |

**Safety rule:** If the assertion has ambiguous parameter types (e.g., `assertEquals(stringA, stringB)` with no message — both strings could be expected/actual), do NOT reorder. Add a `// TODO: verify parameter order` comment and flag for manual review in the migration report.

Increment `assertions_changed` for each assertion reordered.

#### 3.4.4 Exception Test Transformation

Transform `@Test(expected = X.class)` to `Assertions.assertThrows()`. This is a structural transformation requiring lambda wrapping.

**Source pattern:**
```java
@Test(expected = IllegalArgumentException.class)
public void shouldThrowOnInvalidInput() {
    service.process(null);
}
```

**Target pattern:**
```java
@Test
void shouldThrowOnInvalidInput() {
    Assertions.assertThrows(IllegalArgumentException.class, () -> {
        service.process(null);
    });
}
```

**Transformation rules:**
1. Remove `expected = X.class` from `@Test` annotation.
2. Extract the method body.
3. Wrap the body in `Assertions.assertThrows(X.class, () -> { ... });`.
4. If the method body contains multiple statements, wrap all of them in the lambda.
5. If the method body is a single expression, the lambda can be a single-line expression.

**Timeout transformation:**
```java
// Source:
@Test(timeout = 1000)
public void shouldCompleteQuickly() { ... }

// Target:
@Test
void shouldCompleteQuickly() {
    Assertions.assertTimeout(Duration.ofMillis(1000), () -> {
        // original method body
    });
}
```

**Combined expected + timeout:**
```java
// Source:
@Test(expected = IOException.class, timeout = 5000)
public void shouldTimeoutAndThrow() { ... }

// Target:
@Test
void shouldTimeoutAndThrow() {
    Assertions.assertTimeout(Duration.ofMillis(5000), () -> {
        Assertions.assertThrows(IOException.class, () -> {
            // original method body
        });
    });
}
```

Increment `annotations_changed` for each exception/timeout transformation.

#### 3.4.5 Rule Migration

Transform JUnit 4 `@Rule` and `@ClassRule` to JUnit 5 extensions. See `migration-rules.md → JUnit 4 → JUnit 5: Rule Migration Strategies`.

| Rule Type | Migration Strategy |
|----------|-------------------|
| `ExpectedException` | Replace with `Assertions.assertThrows()`. Flag for manual review — the rule-based pattern is more flexible than assertThrows. |
| `TemporaryFolder` | Replace with `@TempDir` annotation from `org.junit.jupiter.api.io.TempDir`. |
| `ErrorCollector` | No direct JUnit 5 equivalent. Flag for manual review. Consider `assertAll()` or third-party library. |
| `Verifier` | No direct equivalent. Flag for manual review. |
| `TestWatcher` | Replace with `@ExtendWith(TestWatcherExtension.class)` or implement `TestExecutionExceptionHandler`. |
| `Timeout` | Replace with `@Timeout` annotation from `org.junit.jupiter.api.Timeout`. |
| `ExternalResource` | Replace with `@ExtendWith(ExternalResourceExtension.class)` or use `@BeforeAll`/`@AfterAll`. |
| `MockitoRule` (`MockitoJUnit.rule()`) | Replace with `@ExtendWith(MockitoExtension.class)`. Remove manual `MockitoAnnotations.initMocks()` calls. |
| Custom rules | Insert `// TODO: migrate @Rule {ruleName} manually — no automated transformation available`. Flag for manual review. |

For complex rules (ExpectedException, ErrorCollector, custom rules), insert a TODO comment and flag in the migration report. These require human judgment.

#### 3.4.6 Parameterized Test Transformation

Transform `@RunWith(Parameterized.class)` + `@Parameters` to JUnit 5 `@ParameterizedTest`. This is classified as complex because it involves structural changes.

**Source pattern:**
```java
@RunWith(Parameterized.class)
public class CalculatorTest {
    @Parameterized.Parameters(name = "{0}")
    public static Collection<Object[]> data() {
        return Arrays.asList(new Object[][] {
            { "2+2=4", 2, 2, 4 },
            { "1+1=2", 1, 1, 2 }
        });
    }

    private String name;
    private int a, b, expected;

    public CalculatorTest(String name, int a, int b, int expected) {
        this.name = name;
        this.a = a;
        this.b = b;
        this.expected = expected;
    }

    @Test
    public void testAddition() {
        assertEquals(expected, Calculator.add(a, b));
    }
}
```

**Target pattern:**
```java
class CalculatorTest {
    @ParameterizedTest(name = "{0}")
    @MethodSource("additionProvider")
    void testAddition(String name, int a, int b, int expected) {
        assertEquals(expected, Calculator.add(a, b));
    }

    static Stream<Arguments> additionProvider() {
        return Stream.of(
            Arguments.of("2+2=4", 2, 2, 4),
            Arguments.of("1+1=2", 1, 1, 2)
        );
    }
}
```

**Transformation rules:**
1. Remove `@RunWith(Parameterized.class)` from class.
2. Remove the constructor and field declarations (parameters move to test method parameters).
3. Convert `@Parameterized.Parameters` method to a `static Stream<Arguments>` provider method.
4. Add `@ParameterizedTest` and `@MethodSource("providerMethodName")` to the test method.
5. Add `@ParameterizedTest` import and `@MethodSource` / `@CsvSource` imports.
6. Convert `Object[]` data to `Arguments.of(...)` calls.

**For simple CSV data**, prefer `@CsvSource`:
```java
@ParameterizedTest
@CsvSource({ "2, 2, 4", "1, 1, 2" })
void testAddition(int a, int b, int expected) { ... }
```

**Flag as complex** in the migration report. Auto-transformation handles standard cases; unusual patterns get `// TODO: verify parameterized test migration` comments.

#### 3.4.7 Visibility Transformation (Optional)

JUnit 5 allows package-private (default) visibility for test classes and methods. JUnit 4 required `public`.

**Apply `--visibility` flag only:**
```
If --visibility flag is set:
  For each test class: remove `public` modifier → package-private.
  For each @Test method: remove `public` modifier → package-private.
  Do NOT remove `public` from @BeforeAll/@AfterAll methods (they must be public or package-private).
  Do NOT change visibility of non-test methods.
```

If `--visibility` flag is NOT set: no visibility changes. Document in migration report that `--visibility` can be used for a follow-up cleanup.

#### 3.4.8 Per-File Transformation Procedure (JUnit)

```
For each file in test_files (sorted by complexity: simple first):

  1. Read file content into memory.
  2. Initialize file_transform_record = { file, status: "in_progress", transformations_applied: all zeros }

  3. Apply transformations IN ORDER:
     a. Annotation transformation (Section 3.4.1)
     b. Import changes (Section 3.4.2)
     c. Assertion parameter reordering (Section 3.4.3)
     d. Exception test transformation (Section 3.4.4)
     e. Timeout transformation (Section 3.4.4)
     f. Rule migration (Section 3.4.5)
     g. Parameterized test transformation (Section 3.4.6)
     h. Visibility transformation (Section 3.4.7) — if --visibility flag

  4. After all transformations applied:
     - Validate the file compiles (Java syntax check via javac or parser).
     - If compile succeeds:
       file_transform_record.status = "success"
       Write transformed file to disk.
     - If compile fails:
       Print: "Compile error after transformation: {file}"
       Attempt auto-fix (fix import conflicts, missing semicolons).
       If auto-fix succeeds: status = "auto-fixed", write file.
       If auto-fix fails:
         Restore original file.
         file_transform_record.status = "failed"
         file_transform_record.errors.push(compile_error)
         Print: "Skipping file due to transform failure: {file}"

  5. Append file_transform_record to migration_plan.per_file_status.

  6. Check failure threshold:
     failed_count = count of files with status "failed"
     If failed_count > 50% of total files:
       Trigger Phase 6 (Rollback). Exit Phase 3.

After all files processed:
  Proceed to Phase 4 (Config Migration).
```

### 3.5 Cypress → Playwright: File Transformation

Apply the following transformation sequence to each Cypress test file. This is a **partial transformation** — mechanical replacements are automated but complex patterns are flagged for manual review. Rules reference: `migration-rules.md → Cypress → Playwright: Command Mapping` and `Cypress → Playwright: Assertion Mapping`.

**Key structural shift:** Cypress uses a synchronous, chainable API (`cy.*`) with implicit queuing. Playwright uses explicit async/await with `page` and `locator` objects. Every Playwright action and assertion requires `await`.

#### 3.5.1 Command Transformation

Replace Cypress commands with Playwright equivalents. See `migration-rules.md → Cypress → Playwright: Command Mapping`.

| Source Pattern | Target Pattern | Transformation Notes |
|---------------|---------------|---------------------|
| `cy.visit('/path')` | `await page.goto('/path')` | Must add `await`; returns response |
| `cy.get('.selector')` | `page.locator('.selector')` | Returns lazy locator — no await needed for creation |
| `cy.get('.item').first()` | `page.locator('.item').first()` | Identical chain pattern |
| `cy.get('.item').eq(n)` | `page.locator('.item').nth(n)` | `.eq()` → `.nth()` |
| `cy.contains('text')` | `page.getByText('text')` | Direct semantic mapping |
| `cy.contains('selector', 'text')` | `page.locator('selector').filter({ hasText: 'text' })` | Split into locator + filter |
| `cy.get('[data-testid=foo]')` | `page.getByTestId('foo')` | Prefer semantic locator |
| `cy.get('[data-cy=foo]')` | `page.getByTestId('foo')` | Requires `data-testid` config in Playwright |
| `cy.click()` | `await locator.click()` | Must add `await` on action |
| `cy.type('text')` | `await locator.fill('text')` | `fill` clears first; use `pressSequentially('text')` for append behavior |
| `cy.clear()` | `await locator.clear()` | Direct mapping |
| `cy.check()` | `await locator.check()` | Direct mapping |
| `cy.uncheck()` | `await locator.uncheck()` | Direct mapping |
| `cy.select('value')` | `await locator.selectOption('value')` | Method name change |
| `cy.url()` | `page.url()` | Property access, not method call — no `await` |
| `cy.title()` | `await page.title()` | `await` required |
| `cy.go('back')` | `await page.goBack()` | Named method |
| `cy.go('forward')` | `await page.goForward()` | Named method |
| `cy.reload()` | `await page.reload()` | Direct mapping |
| `cy.wait(1000)` | `await page.waitForTimeout(1000)` | Discouraged; prefer auto-wait via `waitFor()` |
| `cy.scrollTo(position)` | `await page.evaluate(() => window.scrollTo(x, y))` | Use evaluate or locator scroll |
| `cy.screenshot()` | `await page.screenshot()` | Direct mapping |
| `cy.log('msg')` | `console.log('msg')` | Simple replacement |
| `cy.wrap(subject)` | *(remove — not needed)* | Playwright uses different chaining model |
| `cy.intercept(method, url, handler)` | `await page.route(url, handler)` | Different API shape — flag complex cases |
| `cy.request(method, url, body)` | `await page.request[method](url, { data: body })` | Use Playwright API request context |
| `cy.fixture('data')` | Read via `fs` or Playwright fixture | No direct equivalent — use different strategy |

For each command replacement, increment `transformations_applied` counter for the file.

#### 3.5.2 Assertion Transformation

Cypress uses chained `.should()` assertions. Playwright uses `await expect(locator).toBeX()` or `await expect(page).toHaveX()`.

| Source Pattern | Target Pattern | Transformation Notes |
|---------------|---------------|---------------------|
| `.should('exist')` | `await expect(locator).toBeAttached()` | `toBeAttached` checks DOM presence |
| `.should('be.visible')` | `await expect(locator).toBeVisible()` | Direct mapping |
| `.should('have.text', 'foo')` | `await expect(locator).toHaveText('foo')` | Direct mapping |
| `.should('include.text', 'foo')` | `await expect(locator).toContainText('foo')` | Partial text match |
| `.should('have.value', 'bar')` | `await expect(locator).toHaveValue('bar')` | Input value assertion |
| `.should('have.attr', 'href', '/url')` | `await expect(locator).toHaveAttribute('href', '/url')` | Attribute assertion |
| `.should('have.class', 'active')` | `await expect(locator).toHaveClass(/active/)` | Uses regex for class matching |
| `.should('have.length', 5)` | `await expect(locator).toHaveCount(5)` | Element count |
| `.should('not.exist')` | `await expect(locator).not.toBeVisible()` | Negation via `.not` |
| `.should('be.disabled')` | `await expect(locator).toBeDisabled()` | Direct mapping |
| `.should('be.checked')` | `await expect(locator).toBeChecked()` | Direct mapping |
| `.should('be.focused')` | `await expect(locator).toBeFocused()` | Direct mapping |
| `cy.url().should('include', '/path')` | `await expect(page).toHaveURL(/\/path/)` | URL assertion on `page`, uses regex |
| `cy.title().should('include', 'text')` | `await expect(page).toHaveTitle(/text/)` | Title assertion on `page` |

**Assertion chain splitting:** A single Cypress chain like `cy.get('.btn').should('be.visible').and('have.text', 'Submit')` must be split into separate Playwright assertions:
```typescript
// Source (Cypress):
cy.get('.btn').should('be.visible').and('have.text', 'Submit');

// Target (Playwright):
await expect(page.locator('.btn')).toBeVisible();
await expect(page.locator('.btn')).toHaveText('Submit');
```

Increment `assertions_changed` for each assertion transformed.

#### 3.5.3 Hook Transformation

Replace Cypress hooks with Playwright `test.*` hooks.

| Source Pattern | Target Pattern | Transformation Notes |
|---------------|---------------|---------------------|
| `before(() => { ... })` | `test.beforeAll(async () => { ... })` | Add `async` if not present |
| `beforeEach(() => { ... })` | `test.beforeEach(async ({ page }) => { ... })` | Add `async` + destructure `page` |
| `afterEach(() => { ... })` | `test.afterEach(async ({ page }) => { ... })` | Add `async` + destructure `page` |
| `after(() => { ... })` | `test.afterAll(async () => { ... })` | Add `async` if not present |

**Structural change:** Cypress test files use `describe()` / `it()` from Mocha. Playwright uses `test.describe()` / `test()` from `@playwright/test`.

| Source Pattern | Target Pattern |
|---------------|---------------|
| `describe('name', () => { ... })` | `test.describe('name', () => { ... })` |
| `it('should work', () => { ... })` | `test('should work', async ({ page }) => { ... })` |
| `context('name', () => { ... })` | `test.describe('name', () => { ... })` |
| `specify('name', () => { ... })` | `test('name', async ({ page }) => { ... })` |

**Import transformation:**
```
Remove: Any Cypress imports (import Cypress from 'cypress', etc.)
Add:    import { test, expect } from '@playwright/test';
```

Increment `lifecycle_hooks_changed` for each hook/describe/it transformation.

#### 3.5.4 Structural Transformation: cy → page Context

Cypress tests access `cy` as a global. Playwright tests receive `page` via test fixture destructuring. This requires:

1. **Add `({ page })` parameter** to every `test()` callback.
2. **Replace `cy` references** with `page` for top-level navigation/URL commands.
3. **Introduce local `locator` variables** for repeated selectors:
```typescript
// Instead of:
await page.locator('.submit-btn').click();
await expect(page.locator('.submit-btn')).toBeVisible();

// Prefer:
const submitBtn = page.locator('.submit-btn');
await expect(submitBtn).toBeVisible();
await submitBtn.click();
```

4. **Add `await` to every action and assertion.** This is the most common source of post-migration errors. Rules:
   - `page.goto()` → `await`
   - `locator.click()` → `await`
   - `locator.fill()` → `await`
   - `expect(locator).toBeX()` → `await`
   - `page.locator()` → NO await (lazy, returns locator)
   - `page.url()` → NO await (synchronous property)

#### 3.5.5 Custom Command Migration

Cypress custom commands (`Cypress.Commands.add`) have no direct Playwright equivalent. They map to:

| Source Pattern | Target Pattern | Transformation Notes |
|---------------|---------------|---------------------|
| `Cypress.Commands.add('login', (email, pw) => { ... })` | Helper function or Page Object | Extract to imported utility |
| Custom command using `cy` chain | Helper using `page` parameter | Must accept `page` as parameter |

**Strategy:**
1. Extract each custom command as a standalone async function.
2. Place extracted functions in a shared utility file (e.g., `tests/helpers/commands.ts`).
3. Replace `Cypress.Commands.add('login', ...)` call sites with `await login(page, email, pw)`.
4. Add `// TODO: verify custom command migration` comment at each extraction site.

**Flag as complex** — all files using custom commands are flagged for manual review.

#### 3.5.6 Complex File Detection & Flagging

The following patterns indicate complex files that should be flagged for manual review rather than auto-transformed:

| Pattern | Detection Method | Flag Reason |
|---------|-----------------|-------------|
| `Cypress.Commands.add(...)` | Grep for pattern | Custom commands require manual extraction |
| `cypress/plugins/` directory | File path check | Plugin system fundamentally different in Playwright |
| `cy.session(...)` | Grep for pattern | Session management requires Playwright-specific approach |
| `cy.origin(...)` | Grep for pattern | Cross-origin handled differently in Playwright |
| Conditional testing (`if` with `cy.*`) | AST pattern | Conditional logic incompatible with Playwright's model |
| Third-party Cypress plugins | Import analysis | Plugin APIs have no Playwright equivalent |
| `cy.task(...)` | Grep for pattern | No task/plugin system in Playwright |
| `cy.within(...)` | Grep for pattern | Scoped queries handled via locator chaining |

**For flagged files:**
1. Apply mechanical transformations to supported subsets.
2. Insert `// TODO: migrate manually — {reason}` at flagged locations.
3. Set `manual_review: true` in the file's transformation record.
4. Add to `files_manual_review` count in migration report.

#### 3.5.7 Per-File Transformation Procedure (Cypress)

```
For each file in test_files (sorted by complexity: simple first):

  1. Read file content into memory.
  2. Initialize file_transform_record = { file, status: "in_progress", transformations_applied: all zeros }

  3. Apply transformations IN ORDER:
     a. Import transformation (Section 3.5.3) — remove Cypress imports, add Playwright imports
     b. Describe/it → test.describe/test (Section 3.5.3)
     c. Hook transformation (Section 3.5.3)
     d. Command transformation (Section 3.5.1) — cy.* → page/locator.*
     e. Assertion transformation (Section 3.5.2) — .should() → expect()
     f. Context threading (Section 3.5.4) — add ({ page }), add await keywords
     g. Custom command migration (Section 3.5.5) — if applicable
     h. Complex file flagging (Section 3.5.6) — mark for manual review

  4. After all transformations applied:
     - Validate the file can be parsed (TypeScript/JavaScript syntax check).
     - If parse succeeds:
       file_transform_record.status = "success"
       Write transformed file to disk.
       Note: file may need renaming from .cy.ts to .spec.ts
     - If parse fails:
       Print: "Syntax error after transformation: {file}"
       Attempt auto-fix (fix missing awaits, resolve scoping issues).
       If auto-fix succeeds: status = "auto-fixed", write file.
       If auto-fix fails:
         Restore original file.
         file_transform_record.status = "failed"
         file_transform_record.errors.push(parse_error)
         Print: "Skipping file due to transform failure: {file}"

  5. Append file_transform_record to migration_plan.per_file_status.

  6. Check failure threshold:
     If >50% of files failed transformation:
       Trigger Phase 6 (Rollback). Exit Phase 3.

After all files processed:
  Proceed to Phase 4 (Config Migration).

File renaming:
  *.cy.{js,ts} → *.spec.{js,ts}
  cypress/e2e/**/*.cy.{js,ts} → tests/**/*.spec.{js,ts}
  Update imports in other files that reference renamed test files.
```

### 3.6 Single-File Migration

Support `bestest migrate <from> <to> <file>` to migrate a single file:

```
If a specific file path is provided as the 3rd argument:
  Validate the file exists and matches source framework patterns.
  Set test_files = [specified file only].
  Skip config file discovery and migration.
  Proceed through Phase 3 (transform this one file only).
  Skip Phase 4 (Config Migration).
  Run Phase 5 (Verification) on this single file.
  Generate a single-file migration report.
```

This is useful for incremental migration or verifying transformation rules before a full project migration.

---

## Phase 4 — Config Migration

Migrate framework configuration files and update dependency declarations. Config migration runs AFTER all file transformations succeed (Phase 3). If any config files fail to migrate, the entire migration is flagged but test files are preserved in their transformed state.

### 4.1 Jest → Vitest: Config Transformation

Transform `jest.config.{ts,js,mjs,cjs}` to `vitest.config.ts`. See `migration-rules.md → Jest → Vitest: Config Field Mapping`.

#### 4.1.1 Config File Transformation

**Source:** `jest.config.{ts,js,mjs,cjs}` (or `jest` key in `package.json`)

**Target:** `vitest.config.ts`

| Source Config Field | Target Config Field | Transformation Notes |
|--------------------|--------------------|---------------------|
| `transform: { "^.+\\.tsx?$": "ts-jest" }` | Remove entirely | Vite handles TypeScript natively — no transform config needed |
| `transform: { "^.+\\.jsx?$": "babel-jest" }` | Remove entirely | Vite handles JSX natively |
| `moduleNameMapper: { "^@/(.*)$": "<rootDir>/src/$1" }` | `resolve.alias: { '@/': path.resolve(__dirname, './src/') }` | Convert from jest pattern to Vite alias format. Note trailing slash convention. |
| `moduleNameMapper: { "\\.(css|less|scss)$": "identity-obj-proxy" }` | `css: { modules: { classNameStrategy: 'non-scoped' } }` or remove | CSS module mocking handled differently in Vitest |
| `testEnvironment: "jsdom"` | `test: { environment: "jsdom" }` | Move inside `test` block |
| `testEnvironment: "node"` | `test: { environment: "node" }` | Move inside `test` block (or omit — node is default) |
| `setupFilesAfterFramework: ["./jest.setup.ts"]` | `test: { setupFiles: ["./jest.setup.ts"] }` | Field name change |
| `setupFiles: ["./jest.polyfills.ts"]` | `test: { setupFiles: ["./jest.polyfills.ts"] }` | Same field name, move inside `test` block |
| `collectCoverageFrom: ["src/**/*.{ts,tsx}"]` | `coverage: { include: ["src/**/*.{ts,tsx}"] }` | Field name change |
| `coverageDirectory: "coverage"` | `coverage: { reportsDirectory: "coverage" }` | Field name change |
| `coverageThreshold: { global: { branches: 80 } }` | `coverage: { thresholds: { branches: 80 } }` | Restructured |
| `testMatch: ["**/__tests__/**/*.{ts,tsx}"]` | `test: { include: ["**/__tests__/**/*.{ts,tsx}"] }` | Field name change |
| `testPathIgnorePatterns: ["/node_modules/", "/dist/"]` | `test: { exclude: ["node_modules", "dist"] }` | Field name + format change |
| `transformIgnorePatterns: [...]` | Remove entirely | Vite handles module transformation |
| `moduleFileExtensions: ["ts", "tsx", "js", "jsx", "json"]` | Remove entirely | Vite detects file types automatically |
| `globals: { "ts-jest": { ... } }` | Remove entirely | No ts-jest in Vitest |
| `reporters: ["default", "jest-junit"]` | `reporters: ["default", "junit"]` (use `@vitest/reporter` if needed) | Reporter format may differ |
| `bail: 1` | `test: { bail: 1 }` | Move inside `test` block |
| `maxWorkers: 4` | Remove (Vitest uses different pool config) | Use `pool: 'forks'` and `poolOptions` if needed |

**Config file generation procedure:**
```
1. Read source jest.config (or jest key from package.json).
2. For each field in source config:
   a. If field is in the mapping table → apply transformation.
   b. If field is NOT in the mapping table → add as comment: // TODO: manually migrate jest config field '{field}'
3. Generate vitest.config.ts with mapped fields.
4. Write vitest.config.ts to project root.
5. Delete or rename original jest.config file (jest.config.js.bak).
6. Increment config_fields_mapped in the transformation record.
```

**Example output:**
```typescript
// vitest.config.ts — migrated from jest.config.js by bestest migrate
import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    environment: 'jsdom',
    setupFiles: ['./jest.setup.ts'],
    include: ['**/*.test.{ts,tsx}'],
    exclude: ['node_modules', 'dist'],
  },
  resolve: {
    alias: {
      '@/': path.resolve(__dirname, './src/'),
    },
  },
  coverage: {
    include: ['src/**/*.{ts,tsx}'],
    reportsDirectory: 'coverage',
    thresholds: {
      branches: 80,
    },
  },
});
```

#### 4.1.2 Package.json Dependency Update

```
In package.json:

Remove from devDependencies:
  - "jest"
  - "@types/jest" (if present)
  - "ts-jest"
  - "babel-jest"
  - "jest-environment-jsdom" (Vitest bundles jsdom support)
  - "identity-obj-proxy" (CSS module mocking handled differently)
  - Any jest-* plugin packages (e.g., "jest-junit", "jest-extended")

Add to devDependencies:
  - "vitest" (latest stable version)
  - "@vitest/coverage-v8" (if coverage was configured in Jest)
  - "jsdom" (if testEnvironment was "jsdom" — Vitest needs it as peer dep)

Update scripts in package.json:
  - "test": "jest ..." → "test": "vitest run"
  - "test:watch": "jest --watch" → "test:watch": "vitest"
  - "test:coverage": "jest --coverage" → "test:coverage": "vitest run --coverage"
  - "test:ci": "jest --ci" → "test:ci": "vitest run --reporter=junit"

If no test scripts exist, add:
  - "test": "vitest run"
  - "test:watch": "vitest"
```

#### 4.1.3 Update .bestest/config.yaml

```yaml
# Update framework field
framework: vitest

# Update state section
state:
  last_migrate: "<ISO 8601 timestamp>"
  migration_from: "jest"
  migration_to: "vitest"
```

### 4.2 JUnit 4 → JUnit 5: Config Transformation

Transform build configuration (Gradle or Maven) to use JUnit Platform. See `migration-rules.md → JUnit 4 → JUnit 5: Visibility, Vintage Engine & Build Config`.

#### 4.2.1 Gradle Transformation

**Source:** `build.gradle` or `build.gradle.kts`

| Source Configuration | Target Configuration | Notes |
|---------------------|---------------------|-------|
| `test { useJUnit() }` | `test { useJUnitPlatform() }` | Required for JUnit 5 |
| `testImplementation 'junit:junit:4.13.2'` | Remove | JUnit 4 dependency no longer needed (unless using Vintage Engine) |
| — | `testImplementation 'org.junit.jupiter:junit-jupiter-api:5.10.2'` | Add JUnit Jupiter API |
| — | `testRuntimeOnly 'org.junit.jupiter:junit-jupiter-engine:5.10.2'` | Add JUnit Jupiter Engine (required for running) |
| `testImplementation 'org.mockito:mockito-core:4.x'` | `testImplementation 'org.mockito:mockito-core:4.x'` | Keep (compatible) |
| — | `testImplementation 'org.mockito:mockito-junit-jupiter:4.x'` | Add for `@ExtendWith(MockitoExtension.class)` |
| `testImplementation 'org.hamcrest:hamcrest:2.2'` | `testImplementation 'org.hamcrest:hamcrest:2.2'` | Keep (Hamcrest still works with `assertThat`) |

**Gradle config migration procedure:**
```
1. Read build.gradle or build.gradle.kts.
2. Locate test { ... } block.
3. Replace useJUnit() with useJUnitPlatform().
4. Remove junit:junit dependency.
5. Add junit-jupiter-api and junit-jupiter-engine dependencies.
6. Add mockito-junit-jupiter dependency if Mockito is used.
7. Write updated build file.
8. Increment config_fields_mapped.

If --gradual flag is set:
  - Update only build config (useJUnitPlatform + Jupiter deps).
  - Do NOT transform test files.
  - Add junit-vintage-engine dependency:
    testRuntimeOnly 'org.junit.vintage:junit-vintage-engine:5.10.2'
  - This allows JUnit 4 and JUnit 5 tests to coexist.
  - Skip Phase 3 (file transformation) entirely.
```

#### 4.2.2 Maven Transformation

**Source:** `pom.xml`

| Source Configuration | Target Configuration | Notes |
|---------------------|---------------------|-------|
| `<dependency>junit:junit:4.13.2</dependency>` | Remove | JUnit 4 dep no longer needed |
| — | `<dependency>org.junit.jupiter:junit-jupiter-api:5.10.2</dependency>` | Add Jupiter API |
| — | `<dependency>org.junit.jupiter:junit-jupiter-engine:5.10.2</dependency>` | Add Jupiter Engine (scope: test) |
| `maven-surefire-plugin` (version < 2.22.0) | Update to ≥ 2.22.0 | Required for JUnit Platform |
| — | Ensure `<dependencyManagement>` has `junit-bom` (optional but recommended) | Aligns all Jupiter module versions |

**Maven config migration procedure:**
```
1. Read pom.xml.
2. Remove junit:junit dependency.
3. Add junit-jupiter-api and junit-jupiter-engine dependencies (test scope).
4. Update maven-surefire-plugin to version ≥ 2.22.0 if needed.
5. Optionally add junit-bom to dependencyManagement.
6. Add mockito-junit-jupiter dependency if Mockito is used.
7. Write updated pom.xml.
8. Increment config_fields_mapped.

If --gradual flag is set:
  - Add Jupiter dependencies WITHOUT removing JUnit 4 dep.
  - Add junit-vintage-engine for backward compatibility.
  - Update surefire plugin.
  - Skip Phase 3 (file transformation) entirely.
```

#### 4.2.3 Update .bestest/config.yaml

```yaml
# Update framework field
framework: junit5

# Update state section
state:
  last_migrate: "<ISO 8601 timestamp>"
  migration_from: "junit4"
  migration_to: "junit5"
```

### 4.3 Cypress → Playwright: Config Transformation

Transform Cypress configuration to Playwright configuration. See `migration-rules.md → Cypress → Playwright: Hook & Config Mapping`.

#### 4.3.1 Config File Transformation

**Source:** `cypress.config.{js,ts}`

**Target:** `playwright.config.ts`

| Source Config Field | Target Config Field | Transformation Notes |
|--------------------|--------------------|---------------------|
| `baseUrl: 'http://localhost:3000'` | `use: { baseURL: 'http://localhost:3000' }` | Move into `use` block |
| `viewportWidth: 1280` + `viewportHeight: 720` | `use: { viewport: { width: 1280, height: 720 } }` | Combine into single viewport object |
| `defaultCommandTimeout: 10000` | `use: { actionTimeout: 10000 }` | Field name change |
| `responseTimeout: 30000` | `use: { navigationTimeout: 30000 }` | Different timeout scope |
| `video: true` | `use: { video: 'on' }` | Boolean → string enum |
| `video: false` | `use: { video: 'off' }` | Boolean → string enum |
| `screenshotOnRunFailure: true` | `use: { screenshot: 'only-on-failure' }` | Semantic change in config shape |
| `screenshotsFolder: 'cypress/screenshots'` | `use: { screenshot: { mode: 'only-on-failure' } }` | Different config structure |
| `trashAssetsBeforeRuns: true` | Remove | Playwright handles cleanup differently |
| `videoUploadOnPasses: false` | Remove | No Playwright equivalent |
| `projectId: 'abc123'` | Remove | No Playwright equivalent |
| `retries: 1` | `retries: 1` | Direct mapping |
| `env: { ... }` | `use: { ... }` | Merge env vars into use block or keep as env |
| `experimentalStudio: true` | Remove | No Playwright equivalent |
| `experimentalSessionAndOrigin: true` | Remove | No Playwright equivalent |

**Config file generation procedure:**
```
1. Read source cypress.config.{js,ts}.
2. For each field in source config:
   a. If field is in the mapping table → apply transformation.
   b. If field is NOT in the mapping table → add as comment: // TODO: manually migrate cypress config field '{field}'
3. Generate playwright.config.ts with mapped fields wrapped in defineConfig.
4. Add sensible defaults for Playwright-specific fields:
   - testDir: './tests' (or './e2e')
   - fullyParallel: true
   - forbidOnly: !!process.env.CI
   - retries: process.env.CI ? 2 : 0
   - workers: process.env.CI ? 1 : undefined
   - reporter: 'html'
5. Write playwright.config.ts to project root.
6. Delete or rename original cypress.config file (cypress.config.js.bak).
7. Increment config_fields_mapped in the transformation record.
```

**Example output:**
```typescript
// playwright.config.ts — migrated from cypress.config.ts by bestest migrate
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  use: {
    baseURL: 'http://localhost:3000',
    viewport: { width: 1280, height: 720 },
    actionTimeout: 10000,
    navigationTimeout: 30000,
    video: 'on',
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
  ],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
});
```

#### 4.3.2 Package.json Dependency Update

```
In package.json:

Remove from devDependencies:
  - "cypress"
  - "@cypress/code-coverage" (if present)
  - "@cypress/react" (if present)
  - "@cypress/webpack-devserver" (if present)
  - "@cypress/vite-devserver" (if present)
  - Any cypress-* plugin packages

Add to devDependencies:
  - "@playwright/test" (latest stable version)
  - "@playwright/browser-chromium" (optional — for single-browser install)

Update scripts in package.json:
  - "cypress:open" or "cypress open" → remove (replaced by Playwright UI mode)
  - "cypress:run" or "cypress run" → "test:e2e": "playwright test"
  - "test:e2e": "cypress run ..." → "test:e2e": "playwright test"
  - Add: "test:e2e:ui": "playwright test --ui"
  - Add: "test:e2e:debug": "playwright test --debug"

If no e2e test scripts exist, add:
  - "test:e2e": "playwright test"
  - "test:e2e:ui": "playwright test --ui"
```

#### 4.3.3 Directory Structure Migration

```
Migrate test file directories:
  cypress/e2e/ → tests/ (preferred) or e2e/
  cypress/fixtures/ → tests/fixtures/ (Playwright convention)
  cypress/support/ → Remove (Cypress-specific; extract reusable helpers to tests/helpers/)

Custom commands from cypress/support/commands.{js,ts}:
  Extract each custom command as a standalone helper function.
  Place in tests/helpers/commands.ts.
  Import helpers in test files that use them.
```

#### 4.3.4 Update .bestest/config.yaml

```yaml
# Update framework field
framework: playwright

# Update e2e config
e2e:
  framework: playwright

# Update paths
paths:
  test: "tests/**/*.spec.{ts,js}"

# Update state section
state:
  last_migrate: "<ISO 8601 timestamp>"
  migration_from: "cypress"
  migration_to: "playwright"
```

### 4.4 Config Migration Error Handling

```
If config file transformation fails:
  Print: "Config migration failed for: {config_file}"
  Print: "Error: {error}"
  Print: ""
  Print: "Test files have been transformed but config was not updated."
  Print: "Options:"
  Print: "  1. Fix config manually and re-run verification"
  Print: "  2. Rollback all changes (Phase 6)"
  Set config_migrated = false in migration state.
  Proceed to Phase 5 (Verification) — tests may fail without config update.

If config file does not exist:
  Print: "No {source} config file found. Generating default {target} config."
  Generate a default config file with sensible defaults:
    vitest: defineConfig with test.include, test.environment defaults
    junit5: Add useJUnitPlatform() and Jupiter deps to existing build file
  Proceed with generated config.
```

---

## Phase 5 — Verification & Auto-Fix

Run the migrated test suite to verify correctness. If tests fail, attempt auto-fix for up to 3 rounds. If failures persist beyond the auto-fix budget, present HITL Gate 2 for user decision.

### 5.1 Post-Migration Test Run

Execute the target framework's test suite on all transformed files. Test execution uses `bestest run` (see `references/spoke-run.md`).

```
1. Run: bestest run --framework {to}
   - For vitest: equivalent to `npx vitest run --reporter=json`
   - For junit5: equivalent to `./gradlew test` or `mvn test`
   - For playwright: equivalent to `npx playwright test --reporter=json`

2. Capture run results:
   - Parse run-results.json from .bestest/reports/
   - Extract: total tests, passed, failed, errors, duration
   - Map results back to individual migrated files

3. Compare with pre-migration baseline:
   - If pre-migration test count was available (from .bestest state), compare counts.
   - Significant test count reduction (>5%) indicates transformation issues.

4. Record verification state:
   Set migration_state.verification = {
     tests_run: total,
     tests_passed: passed,
     tests_failed: failed,
     failure_rate: failed / total,
     auto_fix_rounds_remaining: 3
   }
```

### 5.2 Decision: Pass or Auto-Fix

```
If tests_failed == 0:
  Print: "✓ All {total} tests passed after migration."
  Set migration_report.tests_run = total
  Set migration_report.tests_passed = total
  Set migration_report.tests_failed = 0
  Proceed to Phase 7 (Finalization).

If tests_failed > 0:
  Print: "Migration verification: {failed}/{total} tests failed."
  Print: ""
  For each failing test:
    Print: "  FAIL: {test_file} → {test_name}"
    Print: "    Error: {failure_message}"

  failure_rate = failed / total

  If failure_rate > 0.20 (>20% failure):
    Print: "Failure rate ({failure_rate}% exceeds 20% threshold."
    Print: "This suggests a systematic migration issue."
    Proceed to Section 5.4 (HITL Gate 2) directly — skip auto-fix.

  Else (failure rate ≤ 20%):
    Print: "Attempting auto-fix for {failed} failing tests..."
    Proceed to Section 5.3 (Auto-Fix Loop).
```

### 5.3 Auto-Fix Loop

Attempt to automatically fix failing tests using patterns from `references/spoke-fix.md`. Up to 3 rounds of fix attempts.

```
Set auto_fix_round = 0
Set auto_fixes_applied = 0
Set max_rounds = 3

WHILE auto_fix_round < max_rounds AND tests_failed > 0:

  auto_fix_round += 1
  Print: "--- Auto-fix round {auto_fix_round}/{max_rounds} ---"

  // Analyze failures
  For each failing test:
    1. Read failure message and stack trace.
    2. Classify failure type:

       jest → vitest failure types:
         - import_error: "Cannot find module 'vitest'" or "vi is not defined"
           → Fix: verify import statement, add missing import.
         - mock_error: "vi.fn is not a function" or "vi.mock is not a function"
           → Fix: verify vi import, check vitest version.
         - config_error: "Unknown option" or "Configuration error"
           → Fix: verify vitest.config.ts field names.
         - snapshot_mismatch: "Snapshot has changed"
           → Fix: flag for manual review (snapshot may legitimately differ).
         - assertion_error: "expected X, received Y"
           → Fix: check if assertion parameter reordering was incorrect.
         - timeout_error: "Test timed out"
           → Fix: check if vi.useFakeTimers setup is correct.
         - other: unrecognized pattern
           → Flag for manual review.

       junit4 → junit5 failure types:
         - compile_error: "cannot find symbol" for JUnit 4 imports
           → Fix: verify import replacements, check for missed annotations.
         - assertion_error: "AssertionFailedError" with unexpected values
           → Fix: check assertion parameter reordering (message/expected may be swapped).
         - lifecycle_error: "@BeforeAll method must be static"
           → Fix: add static modifier to @BeforeAll/@AfterAll methods.
         - parameterized_error: "No MethodSource declared"
           → Fix: verify @MethodSource method name matches exactly.
         - missing_dependency: "NoClassDefFoundError: org/junit/jupiter"
           → Fix: verify junit-jupiter-engine is in testRuntimeOnly scope.
         - other: unrecognized pattern
           → Flag for manual review.

       cypress → playwright failure types:
         - import_error: "Cannot find module '@playwright/test'"
           → Fix: verify package.json has @playwright/test installed, run npx playwright install.
         - await_error: "page.goto is not a function" or "locator.click is not awaited"
           → Fix: add missing `await` keywords on actions and assertions.
         - selector_error: "strict mode violation: locator resolved to N elements"
           → Fix: add `.first()` to locator chain or narrow selector.
         - context_error: "page is not defined" or "page is not a function"
           → Fix: verify test callback has `({ page })` parameter destructuring.
         - config_error: "Unknown option" or "Configuration error" in playwright.config.ts
           → Fix: verify config field names against Playwright schema.
         - assertion_error: "expect(received).toBeVisible()" but element not found
           → Fix: check selector mapping, verify cy.get → page.locator conversion.
         - timeout_error: "Timeout 30000ms exceeded"
           → Fix: verify auto-wait migration (cy.wait → waitFor patterns), check for missing awaits.
         - hook_error: "test.beforeEach is not a function"
           → Fix: verify import { test } from '@playwright/test', check hook syntax.
         - custom_command_error: "Cypress is not defined"
           → Fix: verify custom command extraction, replace with helper function import.
         - other: unrecognized pattern
           → Flag for manual review.

    3. Apply fix if classified and fixable:
       - Modify the specific file to address the failure.
       - auto_fixes_applied += 1
       - Track: { file, failure_type, fix_applied }

    4. If not fixable (snapshot_mismatch, other):
       - Add to manual_review list.
       - Skip in subsequent rounds.

  // Re-run tests after fixes
  Run: bestest run --framework {to}
  Capture updated test results.
  tests_failed = updated failed count.

  If tests_failed == 0:
    Print: "✓ Auto-fix round {auto_fix_round} resolved all failures."
    Break loop.

  If tests_failed is same as previous round (no progress):
    Print: "Auto-fix made no progress in round {auto_fix_round}."
    Print: "Stopping auto-fix loop to avoid wasted effort."
    Break loop.

  If tests_failed decreased:
    Print: "Progress: {previous_failed} → {tests_failed} failures remaining."
    Continue to next round.

End WHILE.

// After loop exits
migration_report.auto_fixes_applied = auto_fixes_applied

If tests_failed == 0:
  Proceed to Phase 7 (Finalization).

If tests_failed > 0:
  Proceed to Section 5.4 (HITL Gate 2).
```

### 5.4 HITL Gate 2 — Partial Migration Decision

When tests still fail after auto-fix (or failure rate exceeds 20% threshold), present the user with a decision:

```
Print: "╔══════════════════════════════════════════════════════════════╗"
Print: "║              Migration Verification: Partial Success        ║"
Print: "╠══════════════════════════════════════════════════════════════╣"
Print: "║                                                              ║"
Print: "║  Migration: {from} → {to}                                     ║"
Print: "║  Total tests:       {total}                                    ║"
Print: "║  Passed:            {passed}                                   ║"
Print: "║  Failed:            {failed}                                   ║"
Print: "║  Auto-fix rounds:   {rounds_used}/{max_rounds}                          ║"
Print: "║  Auto-fixes applied: {auto_fixes_applied}                      ║"
Print: "║                                                              ║"
Print: "║  Failed tests:                                               ║"
For each failing test (up to 20):
  Print: "║    • {test_file}: {test_name}                                   ║"
If more than 20 failing tests:
  Print: "║    ... and {remaining} more                                     ║"
Print: "║                                                              ║"
Print: "╠══════════════════════════════════════════════════════════════╣"
Print: "║                                                              ║"
Print: "║  Choose an action:                                           ║"
Print: "║                                                              ║"
Print: "║  (a) Keep partial migration                                  ║"
Print: "║      Proceed with successfully migrated files.               ║"
Print: "║      Failed files listed in report for manual fix.           ║"
Print: "║      Status: 'partial'                                       ║"
Print: "║                                                              ║"
Print: "║  (b) Rollback all changes                                    ║"
Print: "║      Restore all files to pre-migration state via git stash. ║"
Print: "║      Status: 'rolled_back'                                   ║"
Print: "║                                                              ║"
Print: "║  (c) Force-commit migration                                  ║"
Print: "║      Accept all changes, including failures.                 ║"
Print: "║      Known failures documented in migration report.          ║"
Print: "║      Status: 'forced'                                        ║"
Print: "║                                                              ║"
Print: "║  Choice (a/b/c):                                             ║"
Print: "╚══════════════════════════════════════════════════════════════╝"
```

**Handle user choice:**

| Choice | Action |
|-------|--------|
| **(a) Keep partial** | Set migration report status to `partial`. List failed files in report. Proceed to Phase 7 (Finalization). Failed files retain transformed state but are flagged. |
| **(b) Rollback** | Execute Phase 6 (Rollback). Set migration report status to `rolled_back`. Restore all files to pre-migration state. |
| **(c) Force-commit** | Set migration report status to `forced`. Document all known failures in migration report. Proceed to Phase 7 (Finalization). Add `## Known Migration Failures` section to TESTING.md. |

### 5.5 Gradual Mode Verification (--gradual flag)

When `--gradual` flag is used with `junit4 → junit5`:

```
--gradual mode behavior:
  - Phase 3 (file transformation) is SKIPPED entirely.
  - Phase 4 (config migration) adds JUnit Platform + Jupiter deps + Vintage Engine.
  - Phase 5 (verification):
    1. Run tests via JUnit Platform (which runs both JUnit 4 and JUnit 5 tests).
    2. All existing JUnit 4 tests should still pass (via Vintage Engine).
    3. If any tests fail:
       Print: "Tests failed after gradual config migration."
       Print: "This should not happen — JUnit 4 tests should run unchanged via Vintage Engine."
       Print: "Rolling back config changes."
       Execute Phase 6 (Rollback) for config files only.
    4. If all tests pass:
       Print: "✓ Gradual migration setup complete."
       Print: "JUnit 5 is now configured alongside JUnit 4."
       Print: "New tests can use JUnit 5 annotations."
       Print: "Use 'bestest migrate junit4 junit5' (without --gradual) to transform existing tests."
       Proceed to Phase 7 (Finalization).
```

### 5.6 Single-File Verification

When a specific file was targeted (`bestest migrate <from> <to> <file>`):

```
1. Run: bestest run --framework {to} --file {file}
   Execute only the migrated file's tests.

2. If all tests pass:
   Print: "✓ Single file migration verified: {file}"
   Generate single-file report.
   Proceed to Phase 7 (Finalization).

3. If tests fail:
   Attempt auto-fix (same as Section 5.3, but only for this file).
   After auto-fix, present HITL Gate 2 if still failing.
```

---

## Phase 6 — Rollback

Restore the pre-migration state using the git stash backup created during Pre-Flight.

### 6.1 When Rollback Is Triggered

Rollback is triggered in these scenarios:
- Verification phase reports >20% file failure rate after auto-fix
- User explicitly requests rollback during any HITL gate
- Critical error during transformation that corrupts files
- Target framework test suite cannot be installed or configured

### 6.2 Rollback Procedure

```
Read migration state from .bestest/state/migration-backup.json

If status != "in_progress":
  Print: "No in-progress migration to rollback."
  Exit.

If rollback_available != true:
  Print: "Rollback backup is not available (stash may have been dropped)."
  Print: "Manual recovery required — check git reflog for recent stashes."
  Exit.

Execute rollback:
  1. Run: git stash pop {stash_ref}
     - This restores all files to their pre-migration state

  2. If stash pop succeeds:
     Print: "Rollback complete. All files restored to pre-migration state."
     Print: "Restored {files_targeted.length} files."

  3. If stash pop fails due to conflicts:
     Print: "╔══════════════════════════════════════════════════════════════╗"
     Print: "║  ROLLBACK CONFLICT DETECTED                                  ║"
     Print: "╠══════════════════════════════════════════════════════════════╣"
     Print: "║                                                              ║"
     Print: "║  The git stash pop encountered merge conflicts.             ║"
     Print: "║  This means files were modified outside the migration.      ║"
     Print: "║                                                              ║"
     Print: "║  Options:                                                    ║"
     Print: "║    1. Resolve conflicts manually (git mergetool)             ║"
     Print: "║    2. Force restore: git checkout stash -- {files}           ║"
     Print: "║    3. Preserve stash for later: git stash drop               ║"
     Print: "║                                                              ║"
     Print: "║  The stash is preserved at: {stash_ref}                      ║"
     Print: "╚══════════════════════════════════════════════════════════════╝"
     DO NOT auto-resolve conflicts. Present to user for manual resolution.
     Preserve stash (do not drop). Update state file with status "rollback-conflict".
     Exit.
```

### 6.3 Post-Rollback Verification

```
After successful stash pop:
  1. Verify file count matches pre-migration count:
     current_count = count of files matching original patterns
     expected_count = files_targeted.length from backup state

     If current_count != expected_count:
       Print: "Warning: File count mismatch after rollback."
       Print: "  Expected: {expected_count} files"
       Print: "  Found:    {current_count} files"
       Print: "Some files may have been added or removed during migration."

  2. Report rollback summary:
     Print: "Rollback Report:"
     Print: "  Migration: {from} → {to}"
     Print: "  Stash ref: {stash_ref}"
     Print: "  Files restored: {files_targeted.length}"
     Print: "  Status: All changes reverted"

  3. Cleanup: Drop the stash now that rollback is confirmed
     Run: git stash drop {stash_ref}

  4. Update backup state:
     status = "rolled_back"
     rollback_available = false
     Write updated state to .bestest/state/migration-backup.json
```

---

## Phase 7 — Finalization

Complete the migration by cleaning up backup, updating configuration, and generating the final report.

### 7.1 Cleanup Backup

```
If backup was created and rollback was NOT needed:
  Run: git stash drop {stash_ref}
  Print: "Migration backup cleaned up (stash dropped)."

Update .bestest/state/migration-backup.json:
  status = "completed"
  rollback_available = false
  phase = "finalized"
```

### 7.2 Update Test Inventory

```
Read .bestest/state/test-inventory.json (if exists).
For each migrated test file:
  Update framework field from {from} to {to}
  Update path if file was renamed (e.g., .cy.ts → .spec.ts)
  Update lastModified timestamp
Write updated test-inventory.json.
```

### 7.3 Update Config

```
Update .bestest/config.yaml:
  framework: {to}
  state:
    last_migrate: "<ISO 8601 timestamp>"
    migration_from: "{from}"
    migration_to: "{to}"

If migration path affects e2e config:
  jest → vitest: no e2e config change needed
  junit4 → junit5: no e2e config change needed
  cypress → playwright:
    e2e.framework: "playwright"

If migration path affects path patterns:
  cypress → playwright:
    paths.test: "tests/**/*.spec.{ts,js}" (update from cypress pattern)
```

### 7.4 Generate Migration Report

Write migration report to `.bestest/reports/migration-{timestamp}.json`:

```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "from": "jest",
  "to": "vitest",
  "status": "completed",
  "files_total": 42,
  "files_migrated": 38,
  "files_skipped": 2,
  "files_manual_review": 2,
  "files_failed": 0,
  "tests_run": 156,
  "tests_passed": 154,
  "tests_failed": 2,
  "config_migrated": true,
  "dependencies_updated": true,
  "rollback_available": false,
  "auto_fixes_applied": 12,
  "duration_ms": 45230,
  "transformations": {
    "imports_changed": 38,
    "mocks_changed": 24,
    "assertions_changed": 15,
    "config_fields_mapped": 8,
    "lifecycle_hooks_changed": 6
  },
  "per_file_status": [
    {
      "file": "src/utils/format.test.ts",
      "status": "migrated",
      "complexity": "simple",
      "transformations": 5,
      "test_result": "passed"
    },
    {
      "file": "src/components/App.test.tsx",
      "status": "migrated",
      "complexity": "moderate",
      "transformations": 12,
      "test_result": "passed",
      "auto_fixes": 2
    },
    {
      "file": "src/integration/api.test.ts",
      "status": "manual_review",
      "complexity": "complex",
      "flags": ["custom-transformer", "jasmine-globals"],
      "test_result": "skipped"
    }
  ]
}
```

Report status values:
- `completed` — All files migrated, all tests passing
- `partial` — Some files migrated, some flagged for manual review
- `failed` — Critical failure, all files rolled back
- `rolled_back` — User-initiated rollback, all changes reverted

### 7.5 Update TESTING.md

```
If TESTING.md exists:
  Update framework references from {from} to {to}
  Update test commands (e.g., "npx jest" → "npx vitest")
  Update config file references
  Add migration note with date and summary
```

---

## Metrics Update

After Phase 7 (Finalization) completes and all artifacts are written, update `.bestest/state/metrics.json` per the shared protocol in `references/metrics-schema.md`. The migrate spoke logs migration activity and records a run entry for the post-migration verification.

### Protocol

1. **Read `.bestest/state/metrics.json`** — If the file does not exist, treat as first-time creation with defaults from `metrics-schema.md`.
2. **Parse** — If parsing fails (corruption), log a warning and reinitialize with defaults plus current migration data. **Never abort the spoke** — metrics are observability, not a gate.
3. **Validate `schemaVersion`** — Warn if MAJOR version differs; proceed if MINOR differs.
4. **Merge spoke-specific data** (see field mapping below).
5. **Write back** — Atomic write (write to temp file, then rename).
6. **Update `config.yaml`** — Set `state.last_metrics` to current ISO 8601 timestamp.

### Fields Updated by spoke-migrate

| Metrics Section | Source Data | Merge Logic |
|----------------|------------|-------------|
| `runs.total` | Cumulative | Increment by 1 (post-migration verification run counts as a run). |
| `runs.history[]` | Post-migration verification results | Append entry: `{ timestamp, spoke: "spoke-migrate", total, passed, failed, skipped, duration_ms, coverage }`. Evict oldest entries exceeding `historyMaxLength` (100). |
| `activity[]` | Migration summary | Append `{ timestamp, spoke: "spoke-migrate", action: "migrate", summary: "Migrated {from} → {to}: {successCount}/{totalCount} files transformed, {failedCount} failures" }`. Evict oldest entries exceeding `activityMaxLength` (200). |
| `lastUpdated` | Current time | Set to current ISO 8601 timestamp. |

### Bounded Array Eviction

All arrays use FIFO eviction: append new entry to end, then remove from beginning if length exceeds `*maxLength`. See `metrics-schema.md` → Bounded Array Eviction for the canonical algorithm.

---

## Error Handling

### 1. Git not initialized

**Trigger:** `.git` directory does not exist.

**Response:**
```
BLOCK migration. Print formatted error box (see Pre-Flight Check 2).
Exit. Do not attempt migration without git.
```

### 2. Source framework not detected

**Trigger:** No config files, imports, or dependency declarations matching the source framework found in the project.

**Response:**
```
Print: "Cannot detect '{from}' framework in this project."
Print detection patterns checked.
Print guidance for manual verification.
Exit. Cleanup backup if created.
```

### 3. Unsupported migration path

**Trigger:** The `<from> <to>` combination is not in the supported paths list.

**Response:**
```
Print: "Unsupported migration path: {from} → {to}"
Print supported paths list.
Exit. No backup created (exit before Pre-Flight Check 6).
```

### 4. Git stash creation fails

**Trigger:** `git stash push` returns non-zero exit code.

**Response:**
```
Print: "Error: Failed to create git stash backup."
Print: "Git error: {stderr}"
Print: ""
Print: "Migration requires a backup for safe rollback. Possible causes:"
Print: "  1. No tracked files match the test file patterns"
Print: "  2. Git index is locked (another git process running)"
Print: "  3. Disk space issues"
Print: ""
Print: "Resolve the issue and re-run /bestest migrate."
Exit. No files modified.
```

### 5. Target framework already in use

**Trigger:** Target framework config files or dependencies detected in the project.

**Response:**
```
Print: "Warning: Target framework '{to}' appears to already be configured."
Print evidence found.
Ask user to confirm: "Continue migration for remaining files? (y/N)"
If declined: Exit with cleanup.
If confirmed: Proceed, skipping already-migrated files.
```

### 6. No test files found

**Trigger:** Source framework is detected (config exists) but no test files matching patterns are found.

**Response:**
```
Print: "Source framework '{from}' is configured but no test files found."
Print: "Checked patterns: {file patterns for source framework}"
Print: ""
Print: "This could mean:"
Print: "  1. Test files are in an unexpected location — check paths.test in config.yaml"
Print: "  2. Tests use non-standard naming conventions"
Print: "  3. Config file exists but tests haven't been written yet"
Cleanup backup. Exit.
```

### 7. Context7 unavailable

**Trigger:** `resolve_library` or `get_library_docs` fails or times out.

**Response:**
```
Print: "Context7 documentation fetch failed: {error}"
Print: "Falling back to static migration rules from references/migration-rules.md."
Print: "Transformations will use stable API patterns but may not be version-accurate."
Continue with static rules only. Migration proceeds — Context7 is enhancement, not requirement.
```

### 8. Transformation produces syntax errors

**Trigger:** Post-transformation file cannot be parsed (TypeScript errors, Java compilation errors, etc.).

**Response:**
```
For the affected file:
  Print: "Transformation produced syntax errors in: {file}"
  Print: "Error: {first error}"
  Mark file as "transform-failed" in migration plan.
  Attempt auto-fix (fix import syntax, parameter ordering).
  If auto-fix resolves: mark as "auto-fixed", continue.
  If auto-fix fails after 2 attempts:
    Restore original file from stash data.
    Mark file as "skipped" with reason "transform-failed".
    Continue with remaining files (do not block on single file failure).
```

### 9. Post-migration test failures exceed threshold

**Trigger:** More than 20% of migrated test files have failing tests after auto-fix loop.

**Response:**
```
Print: "Post-migration failure rate ({failure_pct}%) exceeds threshold (20%)."
Print: "Triggering automatic rollback."
Trigger Phase 6 (Rollback).
Generate migration report with status "failed" and failure details.
```

### 10. Stash conflict during rollback

**Trigger:** `git stash pop` produces merge conflicts.

**Response:**
```
DO NOT auto-resolve conflicts.
Print formatted conflict box (see Phase 6.2).
Preserve stash for manual resolution.
Update backup state: status = "rollback-conflict".
Exit. User must resolve conflicts manually.
```

### 11. Interrupted migration detected

**Trigger:** `.bestest/state/migration-backup.json` exists with `status: "in_progress"` when a new migration command is issued.

**Response:**
```
Print: "Interrupted migration detected!"
Print: "  From: {from}"
Print: "  To: {to}"
Print: "  Phase: {phase}"
Print: "  Stash ref: {stash_ref}"
Print: ""
Print: "Options:"
Print: "  1. Rollback the interrupted migration (recommended)"
Print: "  2. Resume from where it left off (risky — may have partial changes)"
Print: "  3. Cancel — take no action"
If user chooses rollback:
  Execute Phase 6 (Rollback) with the stored stash_ref.
If user chooses resume:
  Continue from the recorded phase. Verify stash still exists first.
If user cancels:
  Exit.
```

---

## Downstream Reference

After `bestest migrate` completes, the user can:

| Command | Purpose |
|---------|---------|
| `/bestest scan` | Re-run scan to verify migration results and check coverage |
| `/bestest run` | Execute the migrated test suite to verify all tests pass |
| `/bestest fix` | Fix any remaining failing tests after migration |
| `/bestest doctor` | Health check the migrated test infrastructure |
| `/bestest generate --untested` | Generate tests for any coverage gaps revealed by migration |

The migrate spoke consumes these reference files:

| File | Usage |
|------|-------|
| `references/config-schema.md` | Config field structure for updating `.bestest/config.yaml` |
| `references/stack-profile-schema.md` | StackProfile JSON schema for framework detection |
| `references/migration-rules.md` | Static transformation rules for all 3 migration paths |
| `references/spoke-run.md` | Test execution commands for post-migration verification |
| `references/spoke-fix.md` | Fix strategies for failing tests after migration |

The migrate spoke produces:
- `.bestest/state/migration-backup.json` — Migration state (in-progress → completed/rolled_back)
- `.bestest/reports/migration-{timestamp}.json` — Structured migration report
- Updated `.bestest/config.yaml` — Framework field updated to target
- Updated `TESTING.md` — Framework references updated
- Transformed test files — All source files rewritten with target framework syntax
