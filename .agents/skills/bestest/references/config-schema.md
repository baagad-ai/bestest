# Config Schema Reference

Complete schema for `.bestest/config.yaml`. This file is the single source of truth for all bestest spoke commands — init, scan, generate, and any future commands read from and write to this schema.

## Field Inventory

### Top-Level Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `framework` | string | — | Test framework: `vitest`, `jest`, `pytest`, `junit5`, or `go_testing`. **Required.** |
| `language` | string | auto-detected | Primary language: `javascript`, `typescript`, `python`, `java`, or `go`. Auto-detected during init if not set. |
| `version` | string | `"1.0"` | Schema version. Managed by bestest — do not edit. |

### `coverage.*`

Coverage collection and reporting settings.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `coverage.enabled` | boolean | `true` | `true`, `false` | Enable coverage collection |
| `coverage.target` | number | `80` | 0–100 | Target coverage percentage |
| `coverage.provider` | string | `"v8"` (vitest), `"istanbul"` (jest), `"pytest-cov"` (pytest), `"jacoco"` (junit5), `"go_cover"` (go_testing) | `v8`, `istanbul`, `pytest-cov`, `jacoco`, `go_cover` | Coverage instrumentation provider. Must match the active framework. |
| `coverage.reporters` | string[] | `["text", "html", "json-summary"]` (JS/TS), `["term-missing", "html", "json"]` (pytest), `["xml", "html"]` (junit5), `["func", "html"]` (go_testing) | JS/TS: `text`, `html`, `json-summary`, `json`, `lcov`; Python: `term-missing`, `html`, `json`, `xml`, `lcov`, `annotate`; Java: `xml`, `html`, `csv`; Go: `func`, `html` | Output formats for coverage reports. Valid values depend on the active framework's coverage provider. |

### `paths.*`

Source and test file location settings.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `paths.test` | string | `"src/**/*.{test,spec}.{ts,tsx}"` | Glob pattern for test files |
| `paths.src` | string | `"src/**/*.{ts,tsx}"` | Glob pattern for source files (coverage collection target) |
| `paths.ignore` | string[] | `["**/node_modules/**", "**/dist/**", "**/.bestest/**"]` | Glob patterns to exclude from scanning and coverage |

### `e2e.*`

End-to-end testing settings.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `e2e.enabled` | boolean | `false` | `true`, `false` | Enable E2E test scaffolding |
| `e2e.framework` | string or null | `null` | `playwright`, `cypress`, `null` | E2E test framework. `null` for API-only projects. |

### `api.*`

API testing settings. Used for HTTP-level integration tests against REST or GraphQL endpoints.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `api.enabled` | boolean | `false` | `true`, `false` | Enable API test type |
| `api.framework` | string or null | `null` | `supertest`, `msw`, `null` | API testing framework |
| `api.base_url` | string | `"http://localhost:3000"` | Any URL | Default base URL for API tests |

### `mutation.*`

Mutation testing settings. Measures test suite effectiveness by injecting code mutations and checking if tests catch them.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `mutation.enabled` | boolean | `false` | `true`, `false` | Enable mutation testing |
| `mutation.framework` | string or null | `null` | `stryker`, `null` | Mutation testing framework |
| `mutation.config_path` | string | `"stryker.conf.json"` | Any file path | Path to mutation config |
| `mutation.threshold` | number | `80` | 0–100 | Mutation score target |

### `contract.*`

Contract testing settings. Used for verifying API compatibility between services (consumer-driven contracts).

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `contract.enabled` | boolean | `false` | `true`, `false` | Enable contract testing |
| `contract.framework` | string or null | `null` | `pact`, `null` | Contract testing framework |
| `contract.provider` | string or null | `null` | Any string | Provider service name for Pact |
| `contract.consumer` | string or null | `null` | Any string | Consumer service name for Pact |

### `chaos.*`

Chaos testing settings. Used for resilience testing by injecting failures into running services.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `chaos.enabled` | boolean | `false` | `true`, `false` | Enable chaos testing |
| `chaos.framework` | string or null | `null` | `custom`, `null` | Chaos testing approach (typically custom) |
| `chaos.targets` | string[] | `[]` | Service identifiers | Services to target for chaos experiments |

### `performance.*`

Performance testing settings. Used for load testing, response time benchmarking, and throughput measurement.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `performance.enabled` | boolean | `false` | `true`, `false` | Enable performance testing |
| `performance.framework` | string or null | `null` | `k6`, `artillery`, `null` | Performance testing framework |
| `performance.config_path` | string or null | `null` | Any file path | Path to performance config/scripts |
| `performance.threshold_ms` | number | `500` | Any positive number | Default response time threshold in milliseconds |

### `ci.*`

CI/CD pipeline integration settings.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `ci.enabled` | boolean | `false` | `true`, `false` | Enable CI pipeline scaffolding |
| `ci.provider` | string or null | `null` | `github-actions`, `gitlab-ci`, `jenkins`, `circleci`, `null` | CI platform for pipeline generation |

### `vitest.*`

Vitest-specific configuration. Only used when `framework` is `vitest`.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `vitest.config_path` | string | `"vitest.config.ts"` | Any file path | Path to vitest config file |
| `vitest.globals` | boolean | `false` | `true`, `false` | Enable Vitest global APIs (`describe`, `it`, `expect` without imports) |
| `vitest.environment` | string | `"jsdom"` | `node`, `jsdom`, `happy-dom` | Default test environment |
| `vitest.setup_files` | string[] | `[]` | File paths | Setup files run before each test suite |
| `vitest.include` | string[] | `["src/**/*.{test,spec}.{ts,tsx}"]` | Glob patterns | Test file inclusion patterns |

### `jest.*`

Jest-specific configuration. Only used when `framework` is `jest`.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `jest.config_path` | string | `"jest.config.ts"` | Any file path | Path to Jest config file |
| `jest.transform` | string | `"swc"` | `swc`, `babel`, `ts-jest` | TypeScript transform strategy |
| `jest.environment` | string | `"jsdom"` | `node`, `jsdom` | Default test environment |
| `jest.module_name_mapper` | object | `{}` | Path alias mapping | Module path aliases (e.g., `@/*` → `src/*`) |

### `pytest.*`

pytest-specific configuration. Only used when `framework` is `pytest`.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `pytest.config_path` | string | `"pyproject.toml"` | Any file path | Path to pytest config file (pyproject.toml section or pytest.ini) |
| `pytest.asyncio_mode` | string | `"strict"` | `auto`, `strict`, `off` | asyncio test mode. `auto` marks async functions automatically, `strict` requires explicit `@pytest.mark.asyncio` |
| `pytest.plugins` | string[] | `[]` | pytest plugin names | List of pytest plugins to install and configure (e.g., `["pytest-asyncio", "pytest-cov", "httpx"]`) |
| `pytest.addopts` | string[] | `["--strict-markers", "--tb=short"]` | Any pytest CLI flags | Additional pytest command-line options |
| `pytest.markers` | string[] | `[]` | Custom marker names | Custom test markers for categorization (e.g., `["asyncio", "integration", "slow"]`) |
| `pytest.testpaths` | string[] | `["tests"]` | Directory paths | Directories to search for tests |

### `junit5.*`

JUnit 5-specific configuration. Only used when `framework` is `junit5`.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `junit5.build_tool` | string | `"gradle"` | `gradle`, `maven` | Build tool for test execution and dependency management |
| `junit5.test_src_dir` | string | `"src/test/java"` | Any directory path | Path to test source root |
| `junit5.main_src_dir` | string | `"src/main/java"` | Any directory path | Path to main source root (coverage target) |
| `junit5.dependency_management` | string | `"gradle"` | `gradle`, `maven` | How to declare and resolve dependencies |
| `junit5.coverage_provider` | string | `"jacoco"` | `jacoco` | Coverage instrumentation provider |
| `junit5.use_junit_platform` | boolean | `true` | `true`, `false` | Configure JUnit Platform in build tool (`useJUnitPlatform()` for Gradle, surefire-provider for Maven) |
| `junit5.test_annotations` | string[] | `["@Test", "@ParameterizedTest", "@Nested"]` | JUnit 5 annotations | Annotations available for generated tests |
| `junit5.parallel_execution` | boolean | `false` | `true`, `false` | Enable JUnit 5 parallel test execution |
| `junit5.java_version` | string | auto-detected | Java version strings | Source compatibility version (from `sourceCompatibility` or `"17"`) |

### `go.*`

Go-specific configuration. Only used when `framework` is `go_testing`.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `go.module_path` | string | auto-detected | Go module path | Module path from go.mod (e.g., `"github.com/user/project"`) |
| `go.go_version` | string | auto-detected | Go version strings | Go version from go.mod `go` directive (e.g., `"1.22"`) |
| `go.test_timeout` | string | `"5m"` | Go duration strings | Global timeout for `go test` (e.g., `"30s"`, `"5m"`) |
| `go.race_detection` | boolean | `true` | `true`, `false` | Enable `-race` flag for race condition detection |
| `go.verbose` | boolean | `true` | `true`, `false` | Enable `-v` flag for verbose test output |
| `go.cover_mode` | string | `"atomic"` | `set`, `count`, `atomic` | Coverage mode. `atomic` for race-safe coverage, `set` for fastest, `count` for frequency |
| `go.build_tags` | string[] | `[]` | Go build tags | Build tags for conditional compilation (e.g., `["integration"]`) |
| `go.test_packages` | string[] | `["./..."]` | Go package patterns | Packages to test (e.g., `["./..."]` for all, or specific packages) |
| `go.testify.enabled` | boolean | `true` | `true`, `false` | Enable testify assertion library |
| `go.testify.packages` | string[] | `["assert", "require"]` | `assert`, `require`, `mock`, `suite` | testify packages to use |
| `go.testify.suite` | boolean | `false` | `true`, `false` | Enable suite.Suite for structured test grouping |
| `go.testify.mock` | boolean | `false` | `true`, `false` | Enable mock.Mock for interaction testing |
| `go.mocking_strategy` | string | `"interface_fakes"` | `interface_fakes`, `testify_mock`, `gomock` | Preferred mocking approach |
| `go.http_framework` | string | `"none"` | `none`, `stdlib`, `gin`, `echo`, `chi`, `grpc` | Detected HTTP framework for test pattern selection |
| `go.parallel` | boolean | `true` | `true`, `false` | Enable `t.Parallel()` in generated tests where safe |
| `go.fuzz` | boolean | `false` | `true`, `false` | Enable fuzz testing support (Go 1.18+) |

### `monorepo.*`

Monorepo-specific settings. Only relevant when `monorepo.enabled` is `true`.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `monorepo.enabled` | boolean | `false` | `true`, `false` | Whether this is a monorepo project |
| `monorepo.tool` | string or null | `null` | `pnpm-workspace`, `nx`, `turborepo`, `lerna` | Monorepo orchestration tool |
| `monorepo.packages` | string[] | `[]` | Glob patterns or package paths | Package directories (e.g., `["packages/*"]`, `["apps/*", "libs/*"]`) |

### `generation.*`

Test generation behavior settings.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `generation.quality_threshold` | number | `0.7` | 0–1 | Minimum quality score for generated tests (agent self-assessment) |
| `generation.verify_compilation` | boolean | `true` | `true`, `false` | Run type-check after generation |
| `generation.verify_pass` | boolean | `true` | `true`, `false` | Run tests after generation to verify they pass |
| `generation.max_retries` | number | `2` | 0–5 | Maximum retry attempts when generated tests fail verification |

### `reports.*`

Scan report retention settings. Controls how many historical scan reports are kept on disk.

| Field | Type | Default | Valid Values | Description |
|-------|------|---------|--------------|-------------|
| `reports.max_retained` | integer | `50` | 1–10000 | Maximum number of scan reports to retain in `.bestest/reports/`. When exceeded, the oldest `scan-*.json` files are deleted after each scan. Minimum value is 1 (always keeps the latest report). |

### `state.*`

Runtime state managed by bestest. **DO NOT EDIT** — these fields are automatically updated.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `state.last_scan` | string or null | `null` | ISO 8601 timestamp of last `bestest scan` execution |
| `state.last_generate` | string or null | `null` | ISO 8601 timestamp of last `bestest generate` execution |
| `state.last_run` | string or null | `null` | ISO 8601 timestamp of last `bestest run` execution |
| `state.last_doctor` | string or null | `null` | ISO 8601 timestamp of last `bestest doctor` execution |
| `state.version` | string | `"1.0"` | Config schema version for migration support |

## Field Naming Convention

- All fields use `snake_case` in YAML (e.g., `quality_threshold`, `setup_files`)
- Nested access uses dot notation in documentation and code (e.g., `coverage.target`, `vitest.environment`)
- Arrays are represented as YAML lists
- Objects are represented as nested YAML maps

## Per-Framework Variation Blocks

### When `framework: vitest`

The `vitest.*` block is active. The `jest.*` block is ignored. Coverage defaults to `v8` provider. Config file is `vitest.config.ts`.

Key behaviors:
- Environment defaults to `jsdom` for frontend projects, `node` for API-only
- Globals default to `false` (explicit imports preferred for clarity)
- Setup files support `setupFiles` and `setupFilesAfterEnv` in vitest config

### When `framework: jest`

The `jest.*` block is active. The `vitest.*` block is ignored. Coverage defaults to `istanbul` provider. Config file is `jest.config.ts`.

Key behaviors:
- Transform defaults to `swc` for best TypeScript performance
- `jest.config.ts` should reference or extend existing config if present
- Module name mapper supports path aliases from `tsconfig.json` paths

### When `framework: pytest`

The `pytest.*` block is active. The `vitest.*` and `jest.*` blocks are ignored. Coverage defaults to `pytest-cov` provider. Config lives in `pyproject.toml` `[tool.pytest.ini_options]`.

Key behaviors:
- `asyncio_mode` defaults to `strict` — requires explicit `@pytest.mark.asyncio` unless set to `auto`
- Plugins are listed in `pytest.plugins` and installed via pip/poetry/uv
- Test paths default to `tests/` directory with `conftest.py` for fixtures
- Coverage uses `pytest-cov` which wraps `coverage.py`, with `--cov-branch` for branch coverage
- Python source paths use `src/` layout or flat layout depending on project structure

### When `framework: junit5`

The `junit5.*` block is active. The `vitest.*`, `jest.*`, and `pytest.*` blocks are ignored. Coverage defaults to `jacoco` provider. Config lives in `build.gradle` (test block) or `pom.xml` (maven-surefire-plugin).

Key behaviors:
- `build_tool` determines test execution: `./gradlew test` for Gradle, `mvn test` for Maven
- `use_junit_platform` defaults to `true` — configures Gradle `useJUnitPlatform()` or Maven surefire JUnit Platform provider
- `test_src_dir` defaults to `src/test/java` (Maven/Gradle standard layout); for Kotlin projects use `src/test/kotlin`
- `java_version` is auto-detected from `sourceCompatibility` in build.gradle or `java.version` in pom.xml, defaults to `"17"`
- Coverage uses JaCoCo: `./gradlew jacocoTestReport` (Gradle) or `mvn verify` (Maven)
- JaCoCo report path: `build/reports/jacoco/test/jacocoTestReport.xml` (Gradle) or `target/site/jacoco/jacoco.xml` (Maven)
- Spring Boot projects: `spring-boot-starter-test` provides JUnit 5 + Mockito + AssertJ automatically
- Test annotations include `@Test`, `@ParameterizedTest`, and `@Nested` by default
- `parallel_execution` is off by default; enable for large test suites via `junit-platform.properties`

### When `framework: go_testing`

The `go.*` block is active. The `vitest.*`, `jest.*`, `pytest.*`, and `junit5.*` blocks are ignored. Coverage defaults to `go_cover` provider (built-in Go toolchain). No separate config file — Go testing is configured via go.mod dependencies and `go test` flags.

Key behaviors:
- Test files follow `*_test.go` naming convention and live alongside source files
- `module_path` is extracted from go.mod `module` directive (e.g., `"github.com/user/project"`)
- `go_version` is extracted from go.mod `go` directive, defaults to `"1.22"`
- Coverage uses `go test -coverprofile=coverage.out` (built-in, no external dependency)
- Coverage report: `go tool cover -func=coverage.out` (per-function) or `go tool cover -html=coverage.out` (visual)
- `race_detection` defaults to `true` — Go's race detector catches data races at test time
- `cover_mode` defaults to `"atomic"` — race-safe coverage collection
- `mocking_strategy` defaults to `"interface_fakes"` — Go idiom of small interfaces + manual test implementations
- `http_framework` determines handler test pattern: Gin uses gin test mode + httptest.NewRecorder, Echo uses echo.New() + httptest, Chi uses chi.Mux + httptest.NewServer, gRPC uses bufconn
- `test_packages` defaults to `["./..."]` — test all packages recursively
- `parallel` defaults to `true` — `t.Parallel()` opt-in for safe concurrent test execution
- testify assert/require are the default assertion packages; mock and suite are opt-in

### Monorepo Mode

When `monorepo.enabled: true`:
- For Vitest: root config uses `projects` array (NOT `workspace`, deprecated in Vitest 3.2+)
- Each package has its own `vitest.config.ts` or inherits from root
- Coverage is collected per-package and unified at root level
- Generation targets packages independently

## Example Configs

### Example 1: Vitest Single-Package (Vite + React)

```yaml
framework: vitest
version: "1.0"

coverage:
  enabled: true
  target: 80
  provider: v8
  reporters:
    - text
    - html
    - json-summary

paths:
  test: "src/**/*.{test,spec}.{ts,tsx}"
  src: "src/**/*.{ts,tsx}"
  ignore:
    - "**/node_modules/**"
    - "**/dist/**"
    - "**/.bestest/**"

e2e:
  enabled: true
  framework: playwright

api:
  enabled: false
  framework: null
  base_url: "http://localhost:3000"

mutation:
  enabled: false
  framework: null
  config_path: "stryker.conf.json"
  threshold: 80

contract:
  enabled: false
  framework: null
  provider: null
  consumer: null

chaos:
  enabled: false
  framework: null
  targets: []

performance:
  enabled: false
  framework: null
  config_path: null
  threshold_ms: 500

ci:
  enabled: true
  provider: github-actions

vitest:
  config_path: vitest.config.ts
  globals: false
  environment: jsdom
  setup_files: []
  include:
    - "src/**/*.{test,spec}.{ts,tsx}"

jest: {}

monorepo:
  enabled: false
  tool: null
  packages: []

generation:
  quality_threshold: 0.7
  verify_compilation: true
  verify_pass: true
  max_retries: 2
reports:
  max_retained: 50

state:
  last_scan: null
  last_generate: null
  last_run: null
  last_doctor: null
  version: "1.0"
```

### Example 2: Existing Jest (React + Webpack)

```yaml
framework: jest
version: "1.0"

coverage:
  enabled: true
  target: 80
  provider: istanbul
  reporters:
    - text
    - html
    - json-summary

paths:
  test: "src/**/*.{test,spec}.{ts,tsx,js,jsx}"
  src: "src/**/*.{ts,tsx,js,jsx}"
  ignore:
    - "**/node_modules/**"
    - "**/dist/**"
    - "**/.bestest/**"

e2e:
  enabled: true
  framework: playwright

api:
  enabled: false
  framework: null
  base_url: "http://localhost:3000"

mutation:
  enabled: false
  framework: null
  config_path: "stryker.conf.json"
  threshold: 80

contract:
  enabled: false
  framework: null
  provider: null
  consumer: null

chaos:
  enabled: false
  framework: null
  targets: []

performance:
  enabled: false
  framework: null
  config_path: null
  threshold_ms: 500

ci:
  enabled: true
  provider: github-actions

vitest: {}

jest:
  config_path: jest.config.ts
  transform: swc
  environment: jsdom
  module_name_mapper:
    "@/(.*)": "src/$1"

monorepo:
  enabled: false
  tool: null
  packages: []

generation:
  quality_threshold: 0.7
  verify_compilation: true
  verify_pass: true
  max_retries: 2
reports:
  max_retained: 50

state:
  last_scan: null
  last_generate: null
  last_run: null
  last_doctor: null
  version: "1.0"
```

### Example 3: Monorepo (pnpm Workspace + Vitest)

```yaml
framework: vitest
version: "1.0"

coverage:
  enabled: true
  target: 80
  provider: v8
  reporters:
    - text
    - html
    - json-summary

paths:
  test: "**/*.{test,spec}.{ts,tsx}"
  src: "**/*.{ts,tsx}"
  ignore:
    - "**/node_modules/**"
    - "**/dist/**"
    - "**/.bestest/**"

e2e:
  enabled: true
  framework: playwright

api:
  enabled: false
  framework: null
  base_url: "http://localhost:3000"

mutation:
  enabled: false
  framework: null
  config_path: "stryker.conf.json"
  threshold: 80

contract:
  enabled: false
  framework: null
  provider: null
  consumer: null

chaos:
  enabled: false
  framework: null
  targets: []

performance:
  enabled: false
  framework: null
  config_path: null
  threshold_ms: 500

ci:
  enabled: true
  provider: github-actions

vitest:
  config_path: vitest.config.ts
  globals: false
  environment: jsdom
  setup_files: []
  include:
    - "**/*.{test,spec}.{ts,tsx}"

jest: {}

monorepo:
  enabled: true
  tool: pnpm-workspace
  packages:
    - "packages/*"

generation:
  quality_threshold: 0.7
  verify_compilation: true
  verify_pass: true
  max_retries: 2
reports:
  max_retained: 50

state:
  last_scan: null
  last_generate: null
  last_run: null
  last_doctor: null
  version: "1.0"
```

### Example 4: Python / pytest (FastAPI)

```yaml
framework: pytest
language: python
version: "1.0"

coverage:
  enabled: true
  target: 80
  provider: pytest-cov
  branch: true
  reporters:
    - term-missing
    - html
    - json

paths:
  test: "tests/**/*.py"
  src: "src/**/*.py"
  ignore:
    - "**/__pycache__/**"
    - "**/*.pyc"
    - "**/venv/**"
    - "**/.venv/**"
    - "**/site-packages/**"
    - "**/.bestest/**"
    - "**/migrations/**"

e2e:
  enabled: false
  framework: null

api:
  enabled: true
  framework: httpx
  base_url: "http://localhost:8000"

mutation:
  enabled: false
  framework: null
  config_path: null
  threshold: 80

contract:
  enabled: false
  framework: null
  provider: null
  consumer: null

chaos:
  enabled: false
  framework: null
  targets: []

performance:
  enabled: false
  framework: null
  config_path: null
  threshold_ms: 500

ci:
  enabled: true
  provider: github-actions

vitest: {}

jest: {}

pytest:
  config_path: pyproject.toml
  asyncio_mode: auto
  plugins:
    - pytest-asyncio
    - pytest-cov
    - httpx
  addopts:
    - "--strict-markers"
    - "--tb=short"
  markers:
    - asyncio
    - integration
    - slow
  testpaths:
    - "tests"

monorepo:
  enabled: false
  tool: null
  packages: []

generation:
  quality_threshold: 0.7
  verify_compilation: true
  verify_pass: true
  max_retries: 2
reports:
  max_retained: 50

state:
  last_scan: null
  last_generate: null
  last_run: null
  last_doctor: null
  version: "1.0"
```

### Example 5: Java / JUnit 5 (Spring Boot)

```yaml
framework: junit5
language: java
version: "1.0"

coverage:
  enabled: true
  target: 80
  provider: jacoco
  reporters:
    - xml
    - html

paths:
  test: "src/test/java/**/*Test.java"
  src: "src/main/java/**/*.java"
  ignore:
    - "**/target/**"
    - "**/build/**"
    - "**/.gradle/**"
    - "**/out/**"
    - "**/.bestest/**"
    - "**/generated/**"

e2e:
  enabled: false
  framework: null

api:
  enabled: true
  framework: mockmvc
  base_url: "http://localhost:8080"

mutation:
  enabled: false
  framework: null
  config_path: null
  threshold: 80

contract:
  enabled: false
  framework: null
  provider: null
  consumer: null

chaos:
  enabled: false
  framework: null
  targets: []

performance:
  enabled: false
  framework: null
  config_path: null
  threshold_ms: 500

ci:
  enabled: true
  provider: github-actions

vitest: {}

jest: {}

pytest: {}

junit5:
  build_tool: gradle
  test_src_dir: "src/test/java"
  main_src_dir: "src/main/java"
  dependency_management: gradle
  coverage_provider: jacoco
  use_junit_platform: true
  test_annotations:
    - "@Test"
    - "@ParameterizedTest"
    - "@Nested"
  parallel_execution: false
  java_version: "17"

monorepo:
  enabled: false
  tool: null
  packages: []

generation:
  quality_threshold: 0.7
  verify_compilation: true
  verify_pass: true
  max_retries: 2
reports:
  max_retained: 50

state:
  last_scan: null
  last_generate: null
  last_run: null
  last_doctor: null
  version: "1.0"
```

### Example 6: Go / testing + testify (Gin HTTP)

```yaml
framework: go_testing
language: go
version: "1.0"

coverage:
  enabled: true
  target: 80
  provider: go_cover
  mode: atomic
  reporters:
    - func
    - html

paths:
  test: "**/*_test.go"
  src: "**/*.go"
  ignore:
    - "**/vendor/**"
    - "**/.git/**"
    - "**/.bestest/**"
    - "**/testdata/**"
    - "**/*_string.go"
    - "**/mock/**"
    - "**/pb/**"

e2e:
  enabled: false
  framework: null

api:
  enabled: true
  framework: httptest
  base_url: "http://localhost:8080"

mutation:
  enabled: false
  framework: null
  config_path: null
  threshold: 80

contract:
  enabled: false
  framework: null
  provider: null
  consumer: null

chaos:
  enabled: false
  framework: null
  targets: []

performance:
  enabled: false
  framework: null
  config_path: null
  threshold_ms: 500

ci:
  enabled: true
  provider: github-actions

vitest: {}

jest: {}

pytest: {}

junit5: {}

go:
  module_path: "github.com/example/project"
  go_version: "1.22"
  test_timeout: "5m"
  race_detection: true
  verbose: true
  cover_mode: atomic
  build_tags: []
  test_packages:
    - "./..."
  testify:
    enabled: true
    packages:
      - assert
      - require
    suite: false
    mock: false
  mocking_strategy: interface_fakes
  http_framework: gin
  parallel: true
  fuzz: false

monorepo:
  enabled: false
  tool: null
  packages: []

generation:
  quality_threshold: 0.7
  verify_compilation: true
  verify_pass: true
  max_retries: 2
reports:
  max_retained: 50

state:
  last_scan: null
  last_generate: null
  last_run: null
  last_doctor: null
  version: "1.0"
```
