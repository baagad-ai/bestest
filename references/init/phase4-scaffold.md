Part of **/bestest init** (see references/spoke-init.md). Load on-demand when reaching Phase 4.

## Phase 4 — Scaffold

Create the `.bestest/` directory structure and populate it with configuration files. All files use templates from `references/templates/` with `{{variable}}` placeholders filled from the StackProfile. The complete config schema contract is defined in `references/config-schema.md` — consult it for field types, valid values, and defaults when filling templates.

### Directory Structure

```
.bestest/
├── config.yaml              # Main test configuration
├── .gitignore               # Ignore state/reports/cache/lock files
├── .config.lock             # Advisory lock for config.yaml concurrency control
├── adrs/
│   └── ADR-001-test-framework.md   # Framework decision record (generated in Phase 2)
├── state/
│   ├── stack-profile.json   # Detected stack profile (from Phase 1)
│   └── .metrics.lock        # Advisory lock for metrics.json concurrency control
└── reports/                  # Empty directory for scan/generate output
```

Additionally, create at the **repo root** (NOT inside `.bestest/`):

**JS/TS projects:**
```
TESTING.md                    # Living test documentation
vitest.config.ts              # Framework config (if Vitest recommended)
  OR
jest.config.ts                # Framework config (if Jest recommended)
```

**Python projects:**
```
TESTING.md                    # Living test documentation
```

For Python, pytest configuration is embedded in `pyproject.toml` `[tool.pytest.ini_options]` — do not create a separate config file. If no `pyproject.toml` exists, create a minimal one with the pytest configuration section. If one exists, add or update the `[tool.pytest.ini_options]` section.

The Python conftest structure is:
```
tests/
├── conftest.py          # Root fixtures (shared across all tests)
├── unit/
│   ├── conftest.py      # Unit test fixtures
│   └── test_*.py        # Unit test files
└── integration/
    ├── conftest.py      # Integration test fixtures
    └── test_*.py        # Integration test files
```

**Java projects:**
```
TESTING.md                    # Living test documentation
```

For Java, no separate test configuration file is needed — JUnit 5 is configured in the build tool (`build.gradle` or `pom.xml`). The `useJUnitPlatform()` directive in Gradle or `maven-surefire-plugin` in Maven handles test execution configuration.

The Java test directory structure follows Maven/Gradle conventions:
```
src/
├── main/java/               # Application source code
│   └── com/example/         # Package structure
└── test/java/               # Test source code
    └── com/example/         # Mirror package structure
        ├── ClassNameTest.java      # Unit tests
        └── ClassNameIT.java        # Integration tests (IT suffix convention)
```

**Go projects:**
```
TESTING.md                    # Living test documentation
```

For Go, test files follow the `*_test.go` convention and live alongside source files in the same package (or in a separate `*_test` package for black-box testing). No separate test configuration file is needed — Go's testing infrastructure is built into the toolchain.

The Go test directory structure follows Go conventions:
```
pkg/
├── user/
│   ├── user.go              # Application source code
│   ├── user_test.go         # White-box tests (same package: package user)
│   └── user_internal_test.go # Internal tests (same package: package user)
├── handler/
│   ├── handler.go           # Application source code
│   └── handler_test.go      # Black-box tests (package handler_test)
└── integration/
    └── integration_test.go  # Integration tests (//go:build integration tag)
```

### Template Resolution

For each file, read the corresponding template and fill all `{{variable}}` placeholders:

#### `.bestest/config.yaml`

Select the config template based on detected stack type:

> **Minimal configuration:** For manual setup, only `framework` is required. See `references/config-schema.md` → **Minimal Configuration** for a 3-field quickstart example.

| Stack Type | Template File |
|------------|--------------|
| Vitest single-package | `references/templates/config-vitest.yaml` |
| Jest (existing setup) | `references/templates/config-jest.yaml` |
| Monorepo (any tool) | `references/templates/config-monorepo.yaml` |
| Python / pytest | `references/templates/config-pytest.yaml` |
| Java / JUnit 5 (Gradle) | `references/templates/config-junit5.yaml` |
| Java / JUnit 5 (Maven) | `references/templates/config-junit5.yaml` |
| Go / testing + testify | `references/templates/config-go.yaml` |

For Python projects, fill these placeholders from the StackProfile and detection results:

| Placeholder | Source |
|-------------|--------|
| `{{project_name}}` | `name` field from `pyproject.toml` `[project]`, or directory name |
| `{{detected_stack_summary}}` | Comma-separated list of key detections (e.g., "FastAPI + Python 3.11 + pytest") |
| `{{coverage_target}}` | Default `80` (user can modify via HITL) |
| `{{paths_test}}` | `tests/**/*.py` (convention) or `test_*.py` / `*_test.py` patterns |
| `{{paths_src}}` | `src/**/*.py` or `**/*.py` depending on project layout |
| `{{e2e_enabled}}` | `true` if frontend/browser testing detected, `false` otherwise |
| `{{e2e_framework}}` | `playwright` if pytest-playwright detected, `null` otherwise |
| `{{api_enabled}}` | `true` if web framework detected (FastAPI, Flask, Django), `false` otherwise |
| `{{api_framework}}` | `httpx` for FastAPI/async, `requests` for sync, `null` if no web framework |
| `{{ci_enabled}}` | `true` if CI provider detected, `false` otherwise |
| `{{ci_provider}}` | From `StackProfile.ciProvider`, or `null` |
| `{{pytest_asyncio_mode}}` | `"auto"` if async detected, `"strict"` otherwise |
| `{{pytest_plugins}}` | List of detected/recommended plugins (e.g., `["pytest-asyncio", "pytest-cov", "httpx"]`) |
| `{{pytest_markers}}` | Custom markers based on framework (e.g., `["asyncio", "integration", "slow"]`) |
| `{{paths_test_dir}}` | `"tests"` (convention) |

For Java projects, fill these placeholders from the StackProfile and detection results:

| Placeholder | Source |
|-------------|--------|
| `{{project_name}}` | `artifactId` from `pom.xml` or `rootProject.name` from `settings.gradle`, or directory name |
| `{{detected_stack_summary}}` | Comma-separated list of key detections (e.g., "Spring Boot 3.2 + Java 17 + JUnit 5 + Gradle") |
| `{{coverage_target}}` | Default `80` (user can modify via HITL) |
| `{{paths_test}}` | `src/test/java/**/*Test.java` (standard Maven/Gradle convention) |
| `{{paths_src}}` | `src/main/java/**/*.java` (standard Maven/Gradle convention) |
| `{{e2e_enabled}}` | `false` for most Java projects (E2E handled separately) |
| `{{e2e_framework}}` | `null` for most Java projects |
| `{{api_enabled}}` | `true` if Spring Boot Web or WebFlux detected, `false` otherwise |
| `{{api_framework}}` | `mockmvc` for Spring MVC, `webtestclient` for WebFlux, `null` if no web framework |
| `{{ci_enabled}}` | `true` if CI provider detected, `false` otherwise |
| `{{ci_provider}}` | From `StackProfile.ciProvider`, or `null` |
| `{{junit5_build_tool}}` | `"gradle"` if `build.gradle` found, `"maven"` if only `pom.xml` found |
| `{{junit5_test_src_dir}}` | `"src/test/java"` (standard convention) |
| `{{junit5_main_src_dir}}` | `"src/main/java"` (standard convention) |
| `{{junit5_dependency_management}}` | `"gradle"` or `"maven"` — same as build_tool |
| `{{junit5_java_version}}` | From `sourceCompatibility` (Gradle) or `<java.version>` (Maven), or `"17"` default |

For Go projects, fill these placeholders from the StackProfile and detection results:

| Placeholder | Source |
|-------------|--------|
| `{{project_name}}` | Module path from go.mod (e.g., `github.com/user/project`) or directory name |
| `{{detected_stack_summary}}` | Comma-separated list of key detections (e.g., "Gin + Go 1.22 + testify") |
| `{{coverage_target}}` | Default `80` (user can modify via HITL) |
| `{{paths_test}}` | `**/*_test.go` (Go convention) |
| `{{paths_src}}` | `**/*.go` (all Go source files, excluding *_test.go) |
| `{{e2e_enabled}}` | `false` for most Go projects (E2E handled via integration tests) |
| `{{e2e_framework}}` | `null` for most Go projects |
| `{{api_enabled}}` | `true` if HTTP framework detected (Gin, Echo, Chi, stdlib net/http), `false` otherwise |
| `{{api_framework}}` | `httptest` for HTTP projects, `null` if no HTTP framework |
| `{{ci_enabled}}` | `true` if CI provider detected, `false` otherwise |
| `{{ci_provider}}` | From `StackProfile.ciProvider`, or `null` |
| `{{go_module_path}}` | Module path from go.mod `module` directive (e.g., `"github.com/user/project"`) |
| `{{go_go_version}}` | From go.mod `go` directive (e.g., `"1.22"`), or `"1.22"` default |
| `{{go_mocking_strategy}}` | `"interface_fakes"` by default, `"gomock"` if gomock detected, `"testify_mock"` if testify mock detected |
| `{{go_http_framework}}` | `"gin"`, `"echo"`, `"chi"`, `"grpc"`, `"stdlib"`, or `"none"` based on detection |

For JS/TS projects, fill these placeholders from the StackProfile and detection results:

| Placeholder | Source |
|-------------|--------|
| `{{project_name}}` | `name` field from `package.json` |
| `{{detected_stack_summary}}` | Comma-separated list of key detections (e.g., "Vite + React + TypeScript") |
| `{{coverage_target}}` | Default `80` (user can modify via HITL) |
| `{{paths_test}}` | `src/**/*.{test,spec}.{ts,tsx}` for single-package, `**/*.{test,spec}.{ts,tsx}` for monorepo |
| `{{paths_src}}` | `src/**/*.{ts,tsx}` for single-package, `**/*.{ts,tsx}` for monorepo |
| `{{e2e_enabled}}` | `true` if frontend detected, `false` otherwise |
| `{{e2e_framework}}` | `playwright` if frontend detected, `null` if API-only |
| `{{ci_enabled}}` | `true` if CI provider detected, `false` otherwise |
| `{{ci_provider}}` | From `StackProfile.ciProvider`, or `null` |
| `{{vitest_environment}}` | `jsdom` for frontend projects, `node` for API-only |
| `{{vitest_setup_files}}` | `[]` by default (user adds setup files later) |
| `{{jest_config_path}}` | Path to existing `jest.config.*` or `"jest.config.ts"` |
| `{{jest_transform}}` | `"swc"` (recommended), `"babel"`, or `"ts-jest"` based on existing setup |
| `{{jest_environment}}` | `"jsdom"` for frontend, `"node"` for API-only |
| `{{jest_module_name_mapper}}` | `{}` by default, or populated from `tsconfig.json` paths |
| `{{monorepo_tool}}` | From `StackProfile.monorepo.tool` |
| `{{monorepo_packages}}` | From workspace config (e.g., `["packages/*"]`) |

#### `vitest.config.ts` (repo root)

Select the variant from `references/templates/vitest-config-ts.md`:

| Stack Variant | Template Section |
|---------------|-----------------|
| Vite + React | Variant 1: Vite + React |
| Next.js | Variant 2: Next.js |
| Express / Fastify / API-only | Variant 3: Express / API-Only |
| Plain TypeScript / no framework | Variant 4: Plain TypeScript |

Copy the selected variant verbatim. Do not strip comments — they are instructional for the user.

#### `jest.config.ts` (repo root)

If Jest was recommended or kept, use `references/templates/jest-config-ts.md`. Select the transform option based on the StackProfile:
- SWC (default, fastest) — unless user specifies otherwise
- Babel — if existing babel config is found
- ts-jest — if existing ts-jest setup is found

#### `TESTING.md` (repo root)

Use `references/templates/testing-md.md`. Fill placeholders:

| Placeholder | Source |
|-------------|--------|
| `{{project_name}}` | `name` from `package.json` |
| `{{timestamp}}` | Current ISO 8601 date |
| `{{detected_stack_summary}}` | Comma-separated key detections |
| `{{test_framework}}` | Recommended framework name |
| `{{coverage_provider}}` | V8 or Istanbul |
| `{{framework_rationale}}` | 1-2 sentence summary from ADR |
| `{{test_file_pattern}}` | `*.test.ts` or `*.spec.ts` |
| `{{e2e_framework}}` | Playwright or "N/A" |
| `{{coverage_target}}` | Default 80 |
| `{{current_coverage}}` | `—` (dash, not yet measured) |
| `{{coverage_command}}` | `npx vitest --coverage` or `npx jest --coverage` |
| `{{test_command}}` | `npx vitest` or `npx jest` |
| `{{e2e_command}}` | `npx playwright test` or "N/A" |
| `{{test_inventory_table}}` | `—` (populated by `bestest scan`) |
| `{{known_gaps}}` | `—` (populated by `bestest scan`) |
| `{{flaky_tests}}` | `—` (populated by `bestest scan`) |
| `{{ci_provider}}` | Detected CI provider or "Not configured" |
| `{{adr_001_title}}` | "Test Framework Selection" |
| `{{adr_001_status}}` | "Proposed" |

#### `.bestest/.gitignore`

Copy `references/templates/bestest-gitignore` verbatim. No placeholder substitution needed.

#### Lock Files

Create empty lock files for concurrency control:

```bash
touch .bestest/state/.metrics.lock
touch .bestest/.config.lock
```

These are advisory lock files used by the Concurrency Lock Protocol (see `references/pre-flight-protocol.md` → Concurrency Lock Protocol). They are created as empty files during init so that `flock` has a target file descriptor to lock. The `*.lock` pattern in `.bestest/.gitignore` ensures they are not tracked by git.

#### `.bestest/dashboard.html`

Copy `references/templates/dashboard.html` to `.bestest/dashboard.html`. No placeholder substitution needed. The dashboard is a self-contained HTML file that reads `.bestest/state/metrics.json` and renders health gauges, coverage trends, and flaky test alerts. It updates automatically as a side-effect of `scan`, `run`, and `doctor` commands.

### Context7 Integration

Before generating `vitest.config.ts` or `jest.config.ts`, attempt to fetch current framework documentation:

1. Call `resolve_library` with the framework name (e.g., `vitest` or `jest`).
2. Call `get_library_docs` with the resolved library ID and a focused query (e.g., `"vitest config coverage v8"` for Vitest, `"jest config typescript transform"` for Jest).
3. Use the fetched docs to validate that the template patterns are still current. If the docs reveal breaking changes or new recommended patterns, update the generated config accordingly.

If Context7 is unavailable or returns no results:
- Fall back to static templates from `references/templates/` without modification.
- Print: "Note: Framework documentation fetch was unavailable. Generated config uses static defaults. Run /bestest doctor to validate against your installed version."

#### Clean Up Checkpoint

```
After scaffolding completes successfully:
  Delete .bestest/.init-checkpoint (if it exists).
  The checkpoint is no longer needed after successful Phase 4 completion.
```

---

