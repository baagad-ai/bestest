# bestest — Complete 10-Section Architecture Design Document

Recovered from Claude Code sessions:
- Session 1: a530df75-3575-4ce8-835b-683d8ddfebd2 (initial design)
- Session 2: 7ae48567-d6a8-4a0e-97ae-3e05b2bd0265 (resume attempt)

---

Using **brainstorming** skill first since this is creative work, then dispatching parallel research agents.

---

Following the brainstorming process. Let me first understand the project context and existing skills, then launch deep parallel research.

---

Research complete. I now have deep context on:
- All existing skill patterns in your ecosystem (TDD, debugging, content-engine orchestrator, etc.)
- Enterprise testing architecture (pyramid/trophy/honeycomb, frameworks, AI testing tools)
- Test harness engineering, CI patterns, monorepo strategies
- Skill creation best practices

Following the brainstorming process — let me start refining your vision one question at a time.

---

Clear. I have everything I need. Let me now present the architecture section by section, checking with you as I go.

## Section 1: Vision & Principles

**bestest** is an enterprise-grade, language-agnostic testing architect skill for Claude Code. It serves both developers and QA engineers, establishing, maintaining, and expanding a complete testing architecture in any repository.

### Core Principles

1. **Test Architecture, Not Just Tests** — bestest doesn't just write tests. It architects the entire testing layer: strategy, configuration, CI pipelines, coverage gates, flaky test management, and documentation. Tests are the output; architecture is the product.

2. **Repo as Source of Truth** — All state lives in `.testing/` inside the repo. Version-controlled, auditable, shareable across the team. No external state stores.

3. **AI-Native, Verification-Driven** — Claude generates tests, but every generated test must compile, pass, and cover meaningful behavior. Coverage theater is explicitly prevented via mutation-awareness and assertion quality checks.

4. **Progressive Complexity** — Init gives you a production-grade foundation. Each subsequent command adds capability. The skill meets you where you are — from zero tests to enterprise-grade coverage.

5. **Framework-Agnostic Intelligence** — The skill detects your stack, recommends the right framework, but never forces a choice. It generates framework-specific configs, templates, and tests for Vitest, Jest, pytest, JUnit 5, Go testing, Playwright, and more.

6. **Living Documentation** — `TESTING.md` is generated once, updated automatically on every scan. It captures strategy, decisions, coverage baselines, and known gaps. It's the team's testing constitution.

Does this vision and principles section look right so far?

---

Great call. Adding a HITL principle:

**7. Strategic Human-In-The-Loop** — bestest operates autonomously for routine work (generating tests, fixing flakiness, updating reports) but pauses for human judgment at decision gates: framework selection, coverage targets, CI pipeline design, and before committing generated tests. The human approves *architectural* decisions; the skill handles *execution* autonomously.

The pattern: `scan → propose → approve → execute → verify → report`. The human sees proposals, approves or adjusts, then the skill does the work and shows results.

Now presenting the full architecture.

## Section 2: Architecture — Orchestrator + Spoke Model

```
bestest/
├── SKILL.md                          # Orchestrator — routes commands to spokes
├── lib/
│   ├── detector.sh                   # Language/framework detection
│   ├── coverage.sh                   # Coverage analysis helper
│   ├── flaky-detector.sh             # Flaky test identification
│   ├── report-generator.sh           # Report generation scripts
│   └── ci-generator.sh               # CI workflow generation
├── templates/
│   ├── vitest.config.ts              # Vitest config templates
│   ├── jest.config.ts                # Jest config templates
│   ├── pytest.ini                    # pytest config templates
│   ├── playwright.config.ts          # Playwright config templates
│   ├── junit5/                       # JUnit 5 templates
│   │   └── build.gradle.kts
│   ├── go/
│   │   └── testing_helpers.go
│   └── ci/
│       ├── github-actions.yml        # GitHub Actions workflows
│       ├── gitlab-ci.yml             # GitLab CI templates
│       └── jenkinsfile               # Jenkins templates
├── references/
│   ├── testing-strategies.md         # Testing pyramid/trophy/honeycomb
│   ├── framework-matrix.md           # When to use which framework
│   ├── anti-patterns.md              # Testing anti-patterns catalog
│   ├── coverage-standards.md         # Coverage targets & standards
│   ├── ai-generation-guide.md        # How to write good AI-generated tests
│   └── ci-patterns.md                # CI pipeline design patterns
└── spoke-skills/
    ├── bestest-init.md               # Full initialization workflow
    ├── bestest-scan.md               # Audit current test state
    ├── bestest-generate.md           # AI test generation
    ├── bestest-run.md                # Execute test suites
    ├── bestest-fix.md                # Fix failing/flaky tests
    ├── bestest-report.md             # Generate test reports
    ├── bestest-coverage.md           # Coverage gap analysis
    ├── bestest-doctor.md             # Health check test infra
    ├── bestest-expand.md             # Add new test types
    ├── bestest-migrate.md            # Migrate test frameworks
    ├── bestest-config.md             # Manage test configuration
    └── bestest-ci.md                 # CI pipeline generation
```

The orchestrator (`SKILL.md`) parses the sub-command, reads any args, and dispatches to the appropriate spoke skill. Each spoke is a focused, self-contained workflow with its own HITL gates defined.

---

Excellent point. This is critical for an enterprise tool. Here's the freshness strategy:

**Dynamic Knowledge Layer** — Instead of relying solely on static templates/references:

1. **Context7 Integration** — The orchestrator uses `mcp__plugin_context7_context7__resolve-library-id` and `mcp__plugin_context7_context7__query-docs` to fetch the latest framework documentation *at execution time*. Templates are fallback defaults; Context7 is the source of truth.

2. **Web Search for Validation** — Before generating config or tests, the skill does a quick web search to verify the framework version and any breaking changes since the last known version.

3. **`bestest doctor` Includes Freshness Checks** — The doctor command checks:
   - Is the installed test framework version current?
   - Are config options still valid for the installed version?
   - Have any recommended practices changed?
   - Flags outdated patterns with links to migration guides

4. **References as Principles, Not Prescriptions** — The reference files encode *principles* (testing strategies, anti-patterns) that are stable across versions. *Specific API calls and config options* come from live documentation.

5. **Templates are Scaffolds, Not Final** — Templates provide structure. The skill fills in version-specific details from live docs.

Adding to the architecture:
```
lib/
  ...
  freshness-check.sh     # Compares installed vs latest versions
```

The orchestrator always calls Context7 before framework-specific generation. Static templates are only used when offline or when Context7 is unavailable.

---

## Section 3: State Model — `.testing/` Directory

All persistent state lives in a version-controlled `.testing/` directory at the repo root:

```
.testing/
├── TESTING.md                    # Living test strategy document
├── config.yaml                   # Central test configuration
├── state/
│   ├── coverage-baseline.json    # Last known coverage snapshot
│   ├── coverage-history.json     # Coverage trend over time
│   ├── flaky-tests.json          # Tracked flaky tests with metadata
│   ├── test-inventory.json       # Catalog of all test files & types
│   └── framework-versions.json   # Locked framework versions for freshness checks
├── adrs/
│   ├── 001-framework-selection.md
│   ├── 002-coverage-targets.md
│   └── 003-ci-strategy.md
├── reports/
│   ├── latest/                   # Most recent scan/generate/run reports
│   └── history/                  # Archived reports (gitignored after 30 days)
├── scripts/
│   ├── setup-test-env.sh         # Environment setup
│   ├── seed-test-data.sh         # Test data seeding
│   └── cleanup-test-artifacts.sh # Post-run cleanup
└── .gitignore                    # Ignore transient files (reports/history, etc.)
```

### Key State Files

**`config.yaml`** — The brain of the system:
```yaml
version: 1
framework:
  unit: vitest          # or jest, pytest, junit5, go-testing
  e2e: playwright       # or cypress
  api: supertest        # or rest-assured, pytest-httpx
coverage:
  target:
    line: 80
    branch: 75
    critical_path: 100
  enforce_in_ci: true
ci:
  provider: github-actions   # or gitlab-ci, jenkins
  stages:
    - name: fast
      timeout: 5m
      tests: [unit, integration]
    - name: full
      timeout: 60m
      tests: [e2e, api]
flaky:
  max_retries: 2
  quarantine_after: 3
  auto_remove_after: 30  # days
languages:
  primary: typescript
  secondary: []
```

**`TESTING.md`** — Auto-generated strategy document covering:
- Framework choices and rationale
- Coverage targets and current status
- Test type breakdown (unit/integration/e2e/api counts)
- Known gaps and TODOs
- CI pipeline description
- Flaky test status
- Last scan timestamp

---

Good call — branded and cleaner. All state lives in `.bestest/`. Moving on.

## Section 4: Command Catalog — The 12 Commands

### Command Routing

The orchestrator parses `/bestest <command> [args]` and dispatches. Each command has its own spoke skill with HITL gates.

---

### 1. `bestest init` — Initialize Test Architecture

**Purpose**: Full audit + scaffold of testing infrastructure for a repo.

**Flow**:
1. Detect languages, frameworks, build tools, package managers
2. Scan existing tests — what exists, what's missing, coverage gaps
3. Fetch latest framework docs via Context7
4. **HITL Gate**: Present findings + recommend frameworks, ask for approval
5. Generate `.bestest/` directory with config, TESTING.md, ADRs
6. Scaffold test configs (vitest.config.ts / pytest.ini / etc.)
7. Generate test helpers (fixtures, factories, mocks setup)
8. **HITL Gate**: Review generated infrastructure, approve or adjust
9. Run initial test suite (if any existing tests)
10. Generate CI workflow files
11. Commit with message: `chore(test): initialize bestest testing architecture`

---

### 2. `bestest scan` — Audit Current Test State

**Purpose**: Deep audit of the current testing state — what's good, what's missing, what's broken.

**Flow**:
1. Run all existing tests, capture results
2. Analyze coverage (line, branch, function)
3. Identify untested modules/files
4. Detect anti-patterns (shared mutable state, missing assertions, test interdependencies)
5. Check flaky test history
6. Verify CI pipeline health
7. Update `.bestest/state/` files
8. Regenerate TESTING.md with current snapshot
9. **Output**: Prioritized action plan (critical gaps first)

---

### 3. `bestest generate [target]` — AI Test Generation

**Purpose**: Generate tests for specified code. Most powerful command.

**Args**:
- `generate src/auth/login.ts` — generate tests for specific file
- `generate --untested` — generate tests for all untested files
- `generate --type unit|integration|e2e|api` — specify test type
- `generate --critical` — generate tests for critical path modules

**Flow**:
1. Read target source code
2. Fetch latest framework docs via Context7
3. Analyze: exports, functions, classes, edge cases, error paths
4. Identify test type needed (unit for pure logic, integration for DB/API, etc.)
5. Generate tests with:
   - Descriptive test names (behavior-focused, not implementation-focused)
   - Edge case coverage (null, empty, boundary, error states)
   - Proper mocking boundaries (mock external deps, not internal modules)
   - Test data factories (not hardcoded fixtures)
6. **HITL Gate**: Show generated tests for review, allow edits
7. Run generated tests — verify they pass
8. If tests fail, auto-fix and retry (max 3 iterations)
9. Update test inventory in `.bestest/state/test-inventory.json`
10. Update coverage baseline

---

### 4. `bestest run [suite]` — Execute Test Suites

**Args**: `run`, `run unit`, `run integration`, `run e2e`, `run all`, `run --affected` (only changed files)

**Flow**:
1. Read `.bestest/config.yaml` for framework and suite definitions
2. Execute via framework-native runner
3. Capture results (pass/fail/skip/flaky)
4. Update `.bestest/state/coverage-baseline.json`
5. Flag new flaky tests
6. Generate summary report

---

### 5. `bestest fix [target]` — Fix Failing/Flaky Tests

**Args**: `fix`, `fix --flaky`, `fix path/to/test.ts`

**Flow**:
1. Identify failing tests (from last run or specified)
2. For each failure:
   - Read test + source code
   - Determine root cause: code bug, test bug, environment issue, timing issue
   - **If code bug**: Flag to developer (don't fix silently)
   - **If test bug**: Fix the test (wrong assertion, outdated selector, etc.)
   - **If flaky**: Apply pattern-specific fix (event-based waits, proper isolation, etc.)
3. **HITL Gate**: Show proposed fixes, allow selective approval
4. Run fixed tests to verify
5. Update flaky test tracking

---

### 6. `bestest report` — Generate Test Reports

**Output**: Rich HTML/Markdown report with:
- Test suite summary (pass/fail/skip counts)
- Coverage heatmap by module
- Flaky test trends
- Coverage history chart
- Uncovered critical paths
- Action items (prioritized)

---

### 7. `bestest coverage` — Coverage Gap Analysis

**Flow**:
1. Run coverage analysis
2. Compare against targets in `.bestest/config.yaml`
3. Identify gaps by:
   - Module (which modules are under-covered)
   - Type (line vs branch vs function)
   - Criticality (critical path gaps vs nice-to-have)
4. Suggest specific files/functions to test next
5. **HITL Gate**: Present gap analysis, ask which gaps to address
6. Optionally auto-chain to `generate` for selected gaps

---

### 8. `bestest doctor` — Health Check Test Infrastructure

**Checks**:
- Framework versions up-to-date? (freshness check)
- Config valid for installed versions?
- Coverage trending up or down?
- Flaky test count within budget?
- CI pipeline running correctly?
- Test execution time acceptable?
- Anti-patterns present in test code?
- Dead tests (testing removed code)?
- Duplicate test coverage?

**Output**: Health score (0-100) + prioritized remediation list

---

### 9. `bestest expand` — Add New Test Types

**Purpose**: Expand the testing strategy. E.g., "we have unit tests, now add E2E" or "add mutation testing".

**Flow**:
1. Show current test types in use
2. **HITL Gate**: Ask what to add (E2E, API, mutation, contract, chaos, performance)
3. Fetch latest docs for chosen type via Context7
4. Scaffold config, templates, helpers, CI stage
5. Generate initial tests for new type
6. Update TESTING.md and config.yaml

---

### 10. `bestest migrate [from] [to]` — Migrate Test Frameworks

**Examples**: `migrate jest vitest`, `migrate junit4 junit5`, `migrate cypress playwright`

**Flow**:
1. Fetch latest docs for target framework via Context7
2. Analyze existing test suite — patterns used, custom configs
3. Generate migration plan (file by file)
4. **HITL Gate**: Present plan, approve before executing
5. Migrate config files
6. Migrate test files (transform assertions, mocks, lifecycle hooks)
7. Run migrated tests, fix failures
8. Update `.bestest/config.yaml`

---

### 11. `bestest config` — Manage Configuration

**Sub-commands**: `config show`, `config set <key> <value>`, `config validate`

**Purpose**: View and modify `.bestest/config.yaml` through a validated interface.

---

### 12. `bestest ci` — Generate CI Pipelines

**Args**: `ci`, `ci github-actions`, `ci gitlab-ci`, `ci jenkins`

**Flow**:
1. Read `.bestest/config.yaml` for framework, stages, coverage targets
2. Detect CI provider from repo files
3. Fetch latest CI provider docs via Context7
4. Generate multi-stage workflow:
   - Stage 1: Fast tests (unit + narrow integration, <5min)
   - Stage 2: Medium tests (broad integration + contract, <20min)
   - Stage 3: Full suite (E2E, <60min)
   - Coverage gates between stages
   - Flaky test quarantine handling
   - Test result artifact upload
5. **HITL Gate**: Review pipeline, approve
6. Write workflow files

---

## Section 5: Multi-Language Support Matrix

Each language ecosystem has a detection strategy, framework recommendations, and generation patterns:

### Detection Matrix

| Signal | Detected By |
|--------|------------|
| `package.json` with `vitest`/`jest` | JS/TS ecosystem |
| `tsconfig.json` | TypeScript specifically |
| `requirements.txt` / `pyproject.toml` / `setup.py` | Python ecosystem |
| `pom.xml` / `build.gradle` / `build.gradle.kts` | Java/JVM |
| `go.mod` | Go ecosystem |
| `playwright.config.*` | E2E layer exists |
| Dockerfile / docker-compose | Container-based testing possible |

### Framework Selection Logic

```
For JS/TS:
  Has Vite? → Vitest (native integration)
  Has Next.js/Remix? → Vitest + Playwright
  Existing Jest? → Keep Jest (don't force migrate)
  Monorepo? → Vitest Workspace / Jest Projects

For Python:
  Has pytest? → Keep pytest
  Has unittest only? → Recommend pytest migration
  Has FastAPI/Django/Flask? → pytest + framework-specific fixtures
  Needs E2E? → pytest-playwright

For Java/JVM:
  Has JUnit 4? → Recommend JUnit 5 migration
  Has Spring Boot? → JUnit 5 + Spring Test + Testcontainers
  Has Gradle? → JUnit 5 + Gradle test tasks
  Needs E2E? → Playwright Java / Selenide

For Go:
  Standard → Go testing package + table-driven tests
  Needs assertions? → testify
  Needs integration? → testcontainers-go
  Needs mocking? → gomock / testify/mock
```

### Per-Language Test Templates

Each language has templates for:
- Test config file
- Test helper utilities (fixtures, factories, mocks)
- Example tests per type (unit, integration, e2e, api)
- CI workflow stages
- Coverage configuration

All templates are scaffold defaults — actual content is generated dynamically using Context7-fetched documentation for the exact framework version installed.

---

You're right — that was surface-level. Let me go deeper with proper research and a more rigorous system.

---

Now I have the depth needed. Here's the revised Section 5:

---

## Section 5 (Revised): Multi-Language Support — Deep Architecture

### 5A. Detection Engine

The skill doesn't just detect "is this Python?" — it builds a complete **Stack Profile** with confidence scoring:

```
Detection signals → Stack Profile → Framework Recommendation → Config Scaffold
```

**Detection is multi-layered:**

| Layer | Signals | Determines |
|-------|---------|------------|
| **Language** | file extensions, `package.json`, `go.mod`, `pom.xml`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `Gemfile` | Primary + secondary languages |
| **Runtime** | Node version, Python version, JVM version, Go version | Feature availability, compatibility |
| **Build Tool** | Vite, Webpack, Turbopack, Gradle, Maven, pip, Poetry, Go modules | How to wire test runner into build |
| **Framework** | Next.js, Remix, Express, Fastify, Django, FastAPI, Flask, Spring Boot, Gin, Echo | Test helpers, fixtures, mocking boundaries |
| **Test Framework** | Existing vitest.config, jest.config, pytest.ini, build.gradle test blocks | Keep or migrate decision |
| **CI Provider** | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/` | Pipeline generation target |
| **Monorepo** | `pnpm-workspace.yaml`, `nx.json`, `turbo.json`, Lerna, Bazel, Gradle multi-module | Test orchestration strategy |
| **Package Manager** | npm, yarn, pnpm, pip, Poetry, Gradle, Go modules | Install commands for deps |
| **Frontend** | React, Vue, Svelte, Solid, Angular, HTMX, server-rendered | Component testing strategy |

**Output: A `StackProfile` object stored in `.bestest/state/stack-profile.json`:**

```json
{
  "languages": [
    {"name": "typescript", "confidence": 0.98, "evidence": ["tsconfig.json", "package.json"]},
    {"name": "python", "confidence": 0.72, "evidence": ["requirements.txt", "scripts/"]}
  ],
  "runtime": {"node": "20.x", "python": "3.12"},
  "buildTool": "vite",
  "frameworks": ["next.js", "express"],
  "testFrameworks": {"existing": "jest", "recommended": "vitest"},
  "ciProvider": "github-actions",
  "monorepo": false,
  "packageManager": "pnpm",
  "frontend": "react",
  "databases": ["postgresql"],
  "messageQueues": [],
  "coverage": {"provider": null, "recommended": "v8"}
}
```

### 5B. Framework Decision Engine

Not a simple lookup table — a decision tree with reasoning that gets documented as ADRs:

#### JS/TS Decision Tree

```
Has Vite in deps?
  YES → Vitest (native Vite transform pipeline, 5-10x faster than Jest for TS)
         ├─ Has React? → Add @vitejs/plugin-react, React Testing Library
         ├─ Has Vue? → Add @vitejs/plugin-vue, Vue Test Utils
         ├─ Has Svelte? → Add @sveltejs/vite-plugin-svelte
         └─ Has Solid? → Add vite-plugin-solid
  NO
    Has Next.js?
      YES → Vitest (official Next.js recommendation since 2024)
             + Server Component testing via vitest browser mode
      NO
        Has existing Jest config with heavy customization?
          YES → Keep Jest (migration cost > benefit)
                 Recommend: add @swc/jest for TS speed
          NO → Vitest (future-proof, Jest-compatible API)

Monorepo?
  YES → Vitest Workspace (defineWorkspace in vitest.workspace.ts)
        Each package: own vitest.config.ts
        Filter: vitest --project=core
        Coverage: unified via --coverage flag

E2E needed?
  YES → Playwright
         ├─ Multi-browser: chromium, firefox, webkit
         ├─ Component testing: same Playwright config
         ├─ API testing: request context in same test file
         └─ CI sharding: npx playwright test --shard=1/4
  Consider Cypress only if: team has deep Cypress expertise AND project uses Cypress plugins

API testing only (no browser)?
  → Supertest (Express/Fastify) or MSW (framework-agnostic mock service worker)
```

#### Python Decision Tree

```
Has pytest in deps?
  YES → Keep pytest. Period.
        ├─ Has Django?
        │     → pytest-django + django.test.TransactionTestCase for DB tests
        │     → Factory Boy for test data
        │     → pytest-django's @pytest.mark.django_db marker
        ├─ Has FastAPI?
        │     → httpx.TestClient (FastAPI's official testing approach)
        │     → pytest-asyncio for async endpoints
        │     → Override dependencies via app.dependency_overrides
        ├─ Has Flask?
        │     → Flask test client via app.test_client()
        │     → Application factory pattern for test configs
        └─ Has SQLAlchemy?
              → pytest fixture with session rollback per test
              → Or Testcontainers PostgreSQL for real DB tests

  NO
    Has unittest only?
      → Recommend pytest migration (backward-compatible, runs unittest tests)
    No tests at all?
      → pytest + pytest-cov + pytest-asyncio (if async)

Mocking:
  HTTP → responses library or pytest-httpserver
  DB → Factory Boy + Testcontainers (avoid in-memory SQLite if prod uses PostgreSQL)
  Time → freezegun or pytest-freezegun
  Env → pytest-env or monkeypatch fixture

E2E:
  → pytest-playwright (sync and async APIs)
    pytest fixtures: page, browser, context, browser_context_args

Coverage:
  → coverage.py (v7+) + pytest-cov
    Branch coverage enabled: --cov --cov-branch
    Fail under threshold: --cov-fail-under=80
```

#### Java/JVM Decision Tree

```
Has JUnit 4?
  YES → Recommend JUnit 5 migration
        └─ Use JUnit Vintage for gradual migration
           Run JUnit 4 + 5 tests side by side
Has JUnit 5?
  YES → Keep. Full feature set:
        ├─ @ParameterizedTest with @ValueSource, @CsvSource, @MethodSource, @EnumSource
        ├─ @Nested for grouped test contexts
        ├─ Extensions: @ExtendWith, BeforeAllCallback, TestInstancePostProcessor
        ├─ Parallel execution: junit.jupiter.execution.parallel.enabled=true
        │   Strategies: dynamic, fixed, custom
        └─ TestInstance Lifecycle: PER_METHOD (default) or PER_CLASS

  Has Spring Boot?
    → @SpringBootTest (full context)
      ├─ @WebMvcTest(Controller.class) — web layer only
      ├─ @DataJpaTest — JPA repository layer only
      ├─ @WebFluxTest — reactive web layer
      ├─ @MockBean / @SpyBean — replace beans in context
      └─ @TestConfiguration — override beans for tests

    Integration:
      → Testcontainers + Spring Boot
        @Testcontainers
        @Container
        static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16")

  Has Kotlin?
    → Consider Kotest (multi-paradigm: assertion, behavior, property-based)
    → MockK (not Mockito) for Kotlin — handles coroutines, companion objects

  Build Tool:
    Gradle:
      → test { useJUnitPlatform() }
        failFast = true
        maxParallelForks = Runtime.runtime.availableProcessors().intdiv(2) ?: 1
    Maven:
      → maven-surefire-plugin (unit) + maven-failsafe-plugin (integration)
        + jacoco-maven-plugin for coverage

  Mocking:
    → Mockito with inline mock maker (bytecode-free since 5.x)
    → WireMock for HTTP service mocking
    → Testcontainers for real DB/message queue testing

  Coverage:
    → JaCoCo
      Rules: line > 80%, branch > 75%
      Exclusions: generated code, config classes, DTOs
```

#### Go Decision Tree

```
Go testing philosophy: stdlib-first, minimal frameworks

Default: Go testing package + table-driven tests
  ├─ func TestXxx(t *testing.T) { ... }
  ├─ Subtests: t.Run("case name", func(t *testing.T) { ... })
  ├─ Parallel: t.Parallel()
  ├─ Benchmarks: func BenchmarkXxx(b *testing.B) { ... }
  ├─ Examples: func ExampleXxx() { ... }
  └─ Fuzzing: func FuzzXxx(f *testing.F) { ... }

Needs fluent assertions?
  → testify/assert (most popular)
    assert.Equal(t, expected, actual, "should be equal")
    require.NoError(t, err) — fails immediately

Needs test suites (setup/teardown)?
  → testify/suite
    type MySuite struct { suite.Suite }
    func (s *MySuite) SetupTest() { ... }
    func (s *MySuite) TearDownTest() { ... }

Needs mocking?
  → go.uber.org/mock (actively maintained gomock fork)
    mockgen -source=interface.go -destination=mock.go
    OR
  → testify/mock (simpler, less type-safe)

Needs integration tests?
  → testcontainers-go
    postgres.RunContainer(ctx, testcontainers.WithImage("postgres:16"))
    + Build tag separation: //go:build integration
    Run: go test -tags=integration ./...

Needs HTTP testing?
  → net/http/httptest (stdlib)
    httptest.NewServer(handler)
    httptest.NewRecorder()

Coverage:
  → go test -cover -coverprofile=coverage.out
    Modes: -covermode=set|count|atomic
    Cross-package: -coverpkg=./...
    Report: go tool cover -html=coverage.out
    Enforce threshold: custom script or gocov

  Fuzz testing (built-in since Go 1.18):
    → go test -fuzz=FuzzFunctionName
```

### 5C. Framework Capabilities Matrix

| Capability | Vitest | Jest | pytest | JUnit 5 | Go testing |
|---|---|---|---|---|---|
| **Watch mode** | Native (Vite HMR) | `--watch` | pytest-watch | IDE-only | `go test ./... -v` loop |
| **Coverage** | V8/Istanbul built-in | Istanbul via babel-jest | coverage.py + pytest-cov | JaCoCo | go test -cover |
| **Parallel** | Worker threads | Worker threads | pytest-xdist | Configurable strategy | t.Parallel() |
| **Snapshot** | Built-in (Jest compat) | Built-in | pytest-snapshot | No native | cupaloy |
| **Browser mode** | Native (Playwright) | Via jsdom/node-only | pytest-playwright | Playwright Java | playwright-go |
| **Monorepo** | Workspace config | Projects config | conftest layering | Gradle multi-module | Go modules |
| **Mocking** | vi.mock/vi.fn | jest.mock/jest.fn | unittest.mock/pytest-mock | Mockito/MockK | gomock/testify |
| **In-source testing** | Yes | No | No | No | No |
| **Component testing** | Via browser mode | Via Testing Library | N/A | N/A | N/A |
| **E2E** | Playwright (separate) | Playwright/Cypress | pytest-playwright | Playwright Java | playwright-go |
| **Parametrize** | `it.each` / `test.each` | `it.each` / `test.each` | @pytest.mark.parametrize | @ParameterizedTest | Table-driven |
| **Fixtures** | beforeEach/All | beforeEach/All | @pytest.fixture (scoped) | @BeforeEach/All | Setup/teardown funcs |
| **Tags/Markers** | `test.skip`, `test.todo` | `describe.skip`, `test.todo` | @pytest.mark.* | @Tag, @Disabled | t.Skip() |
| **Timeout** | Per-test config | Per-test config | @pytest.mark.timeout | @Timeout | t.Deadline |
| **Benchmark** | Built-in | Not native | pytest-benchmark | JMH | Built-in |

### 5D. Mocking Strategy Per Layer

| What to Mock | JS/TS | Python | Java | Go |
|---|---|---|---|---|
| **HTTP APIs** | MSW / nock | responses / pytest-httpserver | WireMock / MockWebServer | httpmock / httptest |
| **Functions** | vi.fn() / vi.mock() | unittest.mock.patch | Mockito.when() | gomock / testify/mock |
| **Modules** | vi.mock('module') | unittest.mock.patch | @MockBean (Spring) | interface mocks |
| **Database** | Testcontainers / Prisma test helpers | Testcontainers / Factory Boy | Testcontainers + @DataJpaTest | testcontainers-go |
| **Time** | vi.useFakeTimers() | freezegun | Clock injection | Manual time injection |
| **Environment** | vi.stubEnv() | monkeypatch.setenv() | @TestPropertySource | os.Setenv + t.Cleanup |
| **Browser APIs** | jsdom / happy-dom | N/A | N/A | N/A |
| **File System** | memfs / vi.mock('fs') | tmp_path fixture | @TempDir | t.TempDir() |

### 5E. CI Integration Per Stack

```
JS/TS (Vitest + Playwright):
  Stage 1: pnpm test --run           (unit, <3min)
  Stage 2: pnpm test --run --project=integration  (integration, <10min)
  Stage 3: pnpm exec playwright test --shard=1/4  (E2E, sharded)
  Coverage gate: vitest --coverage --coverage.threshold=80

Python (pytest):
  Stage 1: pytest -x -q --ignore=tests/e2e  (unit, <3min)
  Stage 2: pytest -m integration             (integration, <10min)
  Stage 3: pytest -m e2e                     (E2E)
  Coverage gate: pytest --cov --cov-fail-under=80 --cov-branch

Java (JUnit 5 + Gradle):
  Stage 1: ./gradlew test                   (unit, <5min)
  Stage 2: ./gradlew integrationTest        (integration, <15min)
  Stage 3: ./gradlew e2eTest                (E2E)
  Coverage gate: jacocoTestCoverageVerification { violationRules { rule { limit { minimum = 0.80 } } } }

Go:
  Stage 1: go test ./... -short             (unit, <3min)
  Stage 2: go test -tags=integration ./...  (integration)
  Coverage gate: go test -cover -coverprofile=coverage.out ./... + threshold check script
```

---

## Section 6: AI Test Generation Strategy

This is the heart of `bestest generate`. The skill must produce *meaningful* tests — not coverage theater.

### 6A. Generation Pipeline

```
Source Code → Analysis → Test Design → Generation → Verification → Commit
     ↑                                                    │
     └──────────────── Feedback Loop (max 3 iterations) ───┘
```

### 6B. Code Analysis Phase

Before writing a single test, the skill deeply analyzes the target code:

1. **Interface Analysis**: All exports (functions, classes, types, constants)
2. **Dependency Map**: What does this module depend on? What depends on it?
3. **Complexity Analysis**: Cyclomatic complexity, branching paths, error handling paths
4. **Contract Analysis**: What are the preconditions, postconditions, invariants?
5. **Side Effect Analysis**: Does it touch DB, filesystem, network, time, env vars?
6. **Edge Case Identification**: Null/undefined, empty inputs, boundary values, concurrent access
7. **Existing Test Gaps**: If tests exist, what paths are untested?

### 6C. Test Design Principles (Encoded in the Skill)

Every generated test follows these rules:

| Rule | Rationale |
|------|-----------|
| **Test behavior, not implementation** | Don't test private methods or internal state. Test what the function *does*, not *how*. |
| **One assertion per concept** | Group related assertions, but each test validates one behavior. |
| **Descriptive names**: `should reject login when password is empty` | Test name = documentation. Anyone reading the test list understands the contract. |
| **Mock at boundaries only** | Mock external services (HTTP, DB, filesystem). Never mock internal modules. |
| **Factory data, not hardcoded** | Use `buildUser()`, not `{ name: "John", email: "john@test.com" }` everywhere. |
| **Cover the unhappy paths** | Error handling, validation failures, edge cases — not just the happy path. |
| **Arrange-Act-Assert** | Every test follows this structure. No exceptions. |
| **No test interdependence** | Each test runs independently, in any order. |

### 6D. Generation Templates Per Test Type

**Unit Test Pattern** (applies to all languages):
```
1. Import the function/class under test
2. Set up inputs (using factory functions)
3. Mock ONLY external boundaries (not internal helpers)
4. Call the function
5. Assert the output/behavior
6. Assert side effects (if any)
7. Clean up mocks

Edge cases always covered:
- Happy path (valid input → expected output)
- Empty/null input
- Boundary values (0, -1, MAX, empty string, empty array)
- Error conditions (invalid input → expected error)
- Concurrent access (if applicable)
```

**Integration Test Pattern**:
```
1. Spin up real dependency (Testcontainers or test server)
2. Seed known data state
3. Execute the flow (multiple functions/modules working together)
4. Assert end-to-end behavior
5. Clean up data/container

Key difference from unit tests:
- NO mocking of internal modules
- Real database, real HTTP (or WireMock for external services)
- Tests the wiring, not just the logic
```

**API Test Pattern**:
```
1. Set up request (headers, body, auth)
2. Send request to endpoint
3. Assert status code
4. Assert response shape (contract)
5. Assert response data (correctness)
6. Assert side effects (database state changed correctly)

Also generates:
- Invalid request body tests
- Auth failure tests
- Rate limiting tests
- Content-type negotiation tests
```

**E2E Test Pattern**:
```
1. Navigate to page/URL
2. Perform user actions (click, type, scroll)
3. Assert visible state (text, elements, URL)
4. Assert data persistence (if applicable)

Uses Playwright best practices:
- data-testid selectors (not CSS classes, not text content for unstable text)
- Auto-wait (Playwright's built-in)
- Page Object Model for complex flows
- Trace capture on failure for debugging
```

### 6E. Anti-Pattern Detection (Built Into Generation)

The skill explicitly avoids generating these:

| Anti-Pattern | What It Looks Like | Why It's Bad |
|---|---|---|
| **Coverage Theater** | Test that calls a function but asserts nothing meaningful | 100% coverage, 0% confidence |
| **Testing Mocks** | Asserting that a mock was called instead of asserting behavior | Tests the test, not the code |
| **Shared Mutable State** | Tests that modify global state | Order-dependent, flaky |
| **Sleep/Wait** | `setTimeout(fn, 5000)` or `time.sleep(5)` | Non-deterministic, slow |
| **Brittle Selectors** | `document.querySelector('.btn-primary-v2')` | Breaks on any CSS change |
| **Hardcoded Secrets** | `apiKey: "sk-abc123..."` in test files | Security risk |
| **Testing Private Methods** | Accessing internal state via reflection/backdoors | Coupled to implementation |
| **Ice Cream Cone** | More E2E tests than unit tests | Slow, expensive, brittle |

### 6F. Verification Loop

After generating tests:

1. **Compile check** — Do the tests compile? Fix syntax errors.
2. **Run check** — Do the tests pass? If fail, analyze failure and fix (max 3 retries).
3. **Coverage check** — Did the tests actually cover new code paths?
4. **Assertion quality check** — Do assertions test behavior (not just "no error thrown")?
5. **Anti-pattern scan** — Run anti-pattern detection on generated code.
6. **HITL Gate** — Present final tests for human review before committing.

---

Now I have the depth. Let me rewrite Section 6 properly.

---

## Section 6 (Revised): AI Test Generation — Full Engineering Specification

### 6A. Generation Pipeline — Seven Phases

```
┌─────────────────────────────────────────────────────────┐
│  Phase 1: CODE ANALYSIS                                  │
│  Parse → Build dependency graph → Score testability      │
├─────────────────────────────────────────────────────────┤
│  Phase 2: TEST DESIGN                                    │
│  Identify test cases → Select test types → Plan data     │
├─────────────────────────────────────────────────────────┤
│  Phase 3: DATA GENERATION                                │
│  Equivalence classes → Boundary values → Factories        │
├─────────────────────────────────────────────────────────┤
│  Phase 4: TEST GENERATION                                │
│  Write tests → Match existing conventions → Add fixtures │
├─────────────────────────────────────────────────────────┤
│  Phase 5: VERIFICATION LOOP                              │
│  Compile → Run → Coverage gate → Mutation gate → Retry   │
├─────────────────────────────────────────────────────────┤
│  Phase 6: QUALITY AUDIT                                  │
│  Test smell scan → Assertion quality score → Flakiness   │
├─────────────────────────────────────────────────────────┤
│  Phase 7: HITL GATE                                      │
│  Present → Approve → Commit → Update .bestest/ state     │
└─────────────────────────────────────────────────────────┘
```

### 6B. Phase 1 — Code Analysis (What Happens Before Any Test Is Written)

The skill builds a **CodeAnalysisReport** with these dimensions:

**1. Interface Analysis:**
```
For each export:
  - Type: function | class | constant | type | interface | enum
  - Signature: params with types, return type
  - Visibility: public | exported | internal
  - Complexity: cyclomatic complexity score (1-20+)
  - Purity: pure function | side-effecting | mixed
```

**2. Dependency Graph:**
```
For the target module:
  - Direct imports (what it uses)
  - Inverse imports (what uses it) — from code-review-graph or grep
  - External boundaries (DB, HTTP, filesystem, env, time)
  - Internal helpers (shared utilities within the project)
  Classification:
    MOCKABLE = external boundaries (HTTP services, databases, filesystem)
    REAL = internal project modules (test with real code, not mocks)
    CONFIG = environment variables, feature flags (inject via test config)
```

**3. Testability Score (0-100):**
```
Factors:
  + Pure functions: +20 (easy to test)
  + Clear types/signatures: +15
  + Dependency injection: +15
  + Documented behavior (docstrings): +10
  - Hidden state/global variables: -20
  - Tight coupling to framework: -15
  - Non-deterministic behavior: -25
  - Complex async flows: -10
  Score:
    80-100: Trivial to test. Generate comprehensive suite.
    50-79:  Standard. Generate with appropriate mocking.
    20-49:  Difficult. Flag for refactoring suggestions before testing.
    0-19:   Untestable. Recommend refactoring first.
```

**4. Path Analysis:**
```
For each function:
  - Happy path (normal execution)
  - Error paths (all catch/throw branches)
  - Edge cases (null, undefined, empty, boundary values)
  - Async paths (promise rejection, timeout, race conditions)
  - State transitions (if stateful)
Total paths = basis for how many test cases to generate
```

### 6C. Phase 2 — Test Design (Planning Before Writing)

From the CodeAnalysisReport, the skill creates a **TestPlan**:

**Test Case Inventory** — For each testable unit, enumerate:

| Test Category | What It Covers | Priority |
|---|---|---|
| **Happy path** | Normal input → expected output | MUST |
| **Boundary values** | Min, max, zero, empty, full | MUST |
| **Equivalence classes** | One representative per input class | MUST |
| **Error paths** | Invalid input → correct error | MUST |
| **Null/undefined handling** | Missing optional params | SHOULD |
| **Concurrency** | Race conditions, parallel access | SHOULD (if async) |
| **Idempotency** | Same input twice → same result | SHOULD |
| **Round-trip** | encode(decode(x)) == x | SHOULD (if applicable) |
| **State transitions** | All valid transitions, rejected transitions | MUST (if stateful) |
| **Performance regression** | Execution time under threshold | MAY |
| **Security** | Injection, XSS, auth bypass | MUST (if handling input) |

**Equivalence Class Partitioning** (automated):
```
For a function validateAge(age: number):
  Classes:
    - Invalid negative: age < 0       → test: -1
    - Valid child:     0 <= age < 18  → test: 10
    - Valid adult:     18 <= age < 65 → test: 30
    - Valid senior:    65 <= age <= 150 → test: 80
    - Invalid high:    age > 150      → test: 200
    - Non-integer:     3.5, NaN       → test: NaN
    - Null/undefined:  null, undefined → test: null
  Total: 7 test cases from 1 parameter
```

**Boundary Value Analysis** (automated):
```
For a function accepting array length [1, 100]:
  Boundaries:
    - Empty array: []           (below min)
    - Single item: [x]          (at min)
    - Two items: [x, y]         (just above min)
    - 99 items: [...]           (just below max)
    - 100 items: [...]          (at max)
    - 101 items: [...]          (above max)
```

### 6D. Phase 3 — Test Data Generation

**Factory Pattern** — Generated tests use factory functions, not hardcoded data:

```typescript
// Instead of:
const user = { name: "John", email: "john@test.com", age: 30 };

// Generate:
function buildUser(overrides?: Partial<User>): User {
  return {
    id: faker.string.uuid(),
    name: faker.person.fullName(),
    email: faker.internet.email(),
    age: faker.number.int({ min: 18, max: 80 }),
    ...overrides,
  };
}
```

**Data generation strategies by type:**

| Input Type | Generation Strategy |
|---|---|
| **Primitives** | Boundary values + random valid/invalid |
| **Objects/DTOs** | Factory functions with `overrides` pattern |
| **Collections** | Empty, single, typical, boundary-size, with-duplicates |
| **Dates** | Past, now, future, epoch, leap year, timezone edges |
| **Strings** | Empty, whitespace, unicode, very long, special chars, SQL/XSS payloads |
| **Enums** | All valid values + invalid value |
| **Async results** | Resolved, rejected, timeout, multiple resolutions |

**Property-based test data** (for complex logic):
```typescript
// Generated automatically when function has mathematical properties
import fc from 'fast-check';

test('sort is idempotent', () => {
  fc.assert(fc.property(fc.array(fc.integer()), (arr) => {
    expect(sort(sort(arr))).toEqual(sort(arr));
  }));
});

test('sort preserves length', () => {
  fc.assert(fc.property(fc.array(fc.integer()), (arr) => {
    expect(sort(arr)).toHaveLength(arr.length);
  }));
});
```

The skill identifies when property-based testing is applicable:
- Mathematical operations → commutativity, associativity, identity
- Serialization → round-trip (encode/decode)
- Sorting/filtering → idempotency, length preservation
- Transformations → inverse exists, output constraints

### 6E. Phase 4 — Test Generation (The Actual Writing)

**Per-language generation conventions:**

**JS/TS (Vitest):**
```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { functionUnderTest } from './module';

describe('functionUnderTest', () => {
  // Happy path
  it('should return expected result for valid input', () => {
    const input = buildValidInput();
    const result = functionUnderTest(input);
    expect(result).toEqual(expectedOutput);
  });

  // Edge cases from equivalence classes
  it('should handle empty input', () => {
    expect(() => functionUnderTest([])).toThrow('Input cannot be empty');
  });

  // Error path
  it('should reject invalid email format', () => {
    const input = buildInput({ email: 'not-an-email' });
    expect(() => functionUnderTest(input)).toThrow(ValidationError);
  });

  // Async path (if applicable)
  it('should handle concurrent requests without race conditions', async () => {
    const results = await Promise.all([
      functionUnderTest(buildInput()),
      functionUnderTest(buildInput()),
    ]);
    results.forEach(r => expect(r.status).toBe('ok'));
  });
});
```

**Python (pytest):**
```python
import pytest
from module import function_under_test

class TestFunctionUnderTest:
    """Tests for function_under_test."""

    def test_valid_input_returns_expected(self):
        result = function_under_test(build_valid_input())
        assert result == expected_output

    @pytest.mark.parametrize("invalid_input,expected_error", [
        (None, TypeError),
        ("", ValueError),
        (-1, ValueError),
    ])
    def test_rejects_invalid_inputs(self, invalid_input, expected_error):
        with pytest.raises(expected_error):
            function_under_test(invalid_input)

    def test_handles_database_failure(self, db_mock):
        db_mock.query.side_effect = ConnectionError("timeout")
        with pytest.raises(ServiceUnavailable):
            function_under_test(build_input())
```

**Java (JUnit 5):**
```java
@ExtendWith(MockitoExtension.class)
class FunctionUnderTestTest {
    @Mock private Database db;
    @InjectMocks private Service underTest;

    @ParameterizedTest
    @CsvSource({
        "'valid@email.com', true",
        "'invalid', false",
        "'', false"
    })
    void shouldValidateEmail(String email, boolean expected) {
        assertThat(underTest.validateEmail(email)).isEqualTo(expected);
    }

    @Test
    void shouldPropagateDatabaseFailure() {
        when(db.query(any())).thenThrow(new ConnectionException("timeout"));
        assertThatThrownBy(() -> underTest.process(buildInput()))
            .isInstanceOf(ServiceUnavailableException.class);
    }
}
```

**Go:**
```go
func TestFunctionUnderTest(t *testing.T) {
    tests := []struct {
        name     string
        input    Input
        expected Output
        wantErr  bool
    }{
        {"valid input returns expected", buildValidInput(), expectedOutput, false},
        {"empty input returns error", Input{}, Output{}, true},
        {"boundary value zero", buildInput(WithAge(0)), Output{}, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := FunctionUnderTest(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("FunctionUnderTest() error = %v, wantErr %v", err, tt.wantErr)
            }
            if !reflect.DeepEqual(got, tt.expected) {
                t.Errorf("FunctionUnderTest() = %v, want %v", got, tt.expected)
            }
        })
    }
}
```

### 6F. Phase 5 — Verification Loop (Coverage-Gated Acceptance)

Adopting the Cover-Agent/TestGen-LLM pattern:

```
Iteration 1:
  1. Generate test
  2. Compile check → If fails: fix syntax, retry
  3. Run test → If fails: analyze failure, fix test (not source code), retry
  4. Coverage check → Did coverage increase?
     YES → Proceed to quality audit
     NO → Regenerate with different approach
  5. Mutation check → Do tests catch at least 1 mutant?
     YES → Accept
     NO → Strengthen assertions, retry

Max iterations: 3 per test case
If all 3 fail → Flag for human review, don't commit bad tests
```

**Flakiness detection** (from Meta's TestGen-LLM):
```
After test passes:
  Run the same test 5 times in sequence
  If any run fails → test is flaky
  Fix: replace timeouts with event-based waits, isolate state, seed randomness
  Re-run flakiness check after fix
```

### 6G. Phase 6 — Quality Audit

Every generated test is scored against:

**Test Smell Scanner** (20 smells checked):

| Smell | Detection Method | Auto-fix? |
|---|---|---|
| No assertions | Count `expect`/`assert` calls; 0 = fail | YES: add assertions |
| Mystery Guest | Test reads from file/DB not visible in test | YES: inline data |
| Sleep/Wait | Regex for `setTimeout`, `time.sleep`, `time.After` | YES: replace with event-based |
| Hardcoded data | Magic numbers/strings not in constants | YES: extract to factory |
| Mock overuse | Mock count > external boundary count | YES: reduce mocks |
| Shared mutable state | Global var modified in test | YES: isolate per test |
| Catch-and-ignore | Empty catch/except block | YES: add assertion |
| Testing private methods | Reflection access or `_` prefix access | YES: remove, test public API |
| Assertion roulette | 5+ assertions without description | YES: split or add messages |
| Happy path only | No error/failure test cases | YES: add error paths |
| Duplicate test | Similar setup+assertion in multiple tests | YES: extract shared helper |
| Fragile selector | CSS class-based selectors in E2E | YES: use data-testid |
| Test depends on order | Uses `beforeAll` to set shared state | YES: convert to `beforeEach` |
| Overly broad assertion | `toBeTruthy()`, `toBeDefined()` only | YES: narrow assertion |
| Complex test logic | Conditionals/loops in test body | YES: simplify, parametrize |
| Missing cleanup | Resources opened but no afterEach/finally | YES: add cleanup |
| Production logic in test | Complex algorithms in test code | YES: move to helpers |
| Time-dependent without fake | Uses `Date.now()` without fake timers | YES: inject time |
| Random without seed | Uses `Math.random()` without seed | YES: seed randomness |
| Test tests mock behavior | Asserts mock.callCount instead of outcome | YES: assert real outcome |

**Assertion Quality Score (0-100):**
```
+20  Specific assertion (exact value comparison)
+15  Tests error message content (not just "throws")
+10  Tests side effects (DB state, API calls made)
+10  Tests edge case (not just happy path)
+10  Uses meaningful test data (not "test", "foo", 123)
+10  Descriptive test name
+10  Independent (no shared state)
+5   Tests async behavior correctly
-20  No assertion
-20  Overly broad assertion (toBeDefined, toBeTruthy)
-15  Asserts mock behavior instead of outcome
-10  Hardcoded magic values
-10  Depends on execution order
```

### 6H. Phase 7 — HITL Gate

After quality audit:

```
1. Show summary:
   - X test cases generated for Y functions
   - Coverage impact: +Z% (from A% to B%)
   - Quality score: 87/100
   - 0 test smells detected
   - Flakiness: tested 5x, all pass

2. Show each test file with diff view

3. Ask: Approve all / Edit / Reject specific tests

4. On approval:
   - Write tests to disk
   - Update .bestest/state/test-inventory.json
   - Update .bestest/state/coverage-baseline.json
   - Update TESTING.md with new coverage numbers
   - Commit with message referencing the generated module
```

---

## Section 7: CI/CD Pipeline Generation

### 7A. `bestest ci` Flow

The skill reads `.bestest/config.yaml` and generates CI workflows that match the team's testing strategy:

```
config.yaml → Stage definitions → Framework commands → Coverage gates → Workflow file
```

### 7B. Stage Architecture

```yaml
# Generated pipeline follows this pattern:
Stage 1: FAST (< 5 min)
  - Linting + type checking
  - Unit tests (isolated, no external deps)
  - Narrow integration tests (mocked boundaries)
  Gate: All pass + coverage threshold met

Stage 2: MEDIUM (< 20 min)
  - Broad integration tests (Testcontainers for real DBs)
  - API contract tests
  - Service-level tests
  Gate: All pass + no new flaky tests

Stage 3: SLOW (< 60 min, may be nightly or on merge)
  - E2E tests (Playwright, sharded across N machines)
  - Cross-browser tests
  - Performance benchmarks
  - Security scans
  Gate: All pass + performance thresholds met

Stage 4: QUALITY (nightly or weekly)
  - Mutation testing (Stryker/PITest)
  - Full coverage analysis + trending
  - Test smell scan
  - Flaky test quarantine review
  Gate: Mutation score > threshold
```

### 7C. Generated Workflow Templates

**GitHub Actions (JS/TS + Vitest + Playwright):**
```yaml
# .github/workflows/test.yml — generated by bestest ci
name: Test Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  fast-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with: { node-version: lts/* }
      - run: pnpm install --frozen-lockfile
      - run: pnpm test --run
      - run: pnpm exec vitest run --coverage
      - uses: codecov/codecov-action@v4

  medium-tests:
    needs: fast-tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env: { POSTGRES_DB: test, POSTGRES_PASSWORD: test }
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports: ['5432:5432']
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: pnpm test --run --project=integration
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with: { name: integration-results, path: test-results/ }

  e2e-tests:
    needs: medium-tests
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        shardIndex: [1, 2, 3, 4]
        shardTotal: [4]
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: npx playwright install --with-deps
      - run: npx playwright test --shard=${{ matrix.shardIndex }}/${{ matrix.shardTotal }}
      - name: Upload blob report
        if: always()
        uses: actions/upload-artifact@v4
        with: { name: blob-report-${{ matrix.shardIndex }}, path: blob-report/ }

  merge-reports:
    if: always()
    needs: e2e-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pnpm install --frozen-lockfile
      - run: npx playwright merge-reports --reporter=html ./blob-report
      - uses: actions/upload-artifact@v4
        with: { name: playwright-report, path: playwright-report/ }
```

**GitHub Actions (Python + pytest):**
```yaml
name: Test Pipeline

on: [push, pull_request]

jobs:
  fast-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install -e ".[dev]"
      - run: pytest -x -q --ignore=tests/e2e -m "not integration"
      - run: pytest --cov --cov-branch --cov-fail-under=80 -m "not integration"

  integration-tests:
    needs: fast-tests
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env: { POSTGRES_DB: testdb, POSTGRES_PASSWORD: postgres }
        ports: ['5432:5432']
    steps:
      - uses: actions/checkout@v4
      - run: pip install -e ".[dev]"
      - run: pytest -m integration --cov --cov-branch

  e2e-tests:
    needs: integration-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: pip install -e ".[dev]"
      - run: playwright install --with-deps chromium
      - run: pytest -m e2e
```

### 7D. Coverage Gate Enforcement

The generated pipeline enforces coverage at multiple points:

```yaml
# Coverage gate configuration (in .bestest/config.yaml)
coverage:
  enforce_in_ci: true
  target:
    line: 80
    branch: 75
    critical_path: 100
  fail_on_regression: true       # Fail if coverage drops from baseline
  diff_coverage: true            # Only check coverage on changed files
  report_to: codecov             # Upload to Codecov/Coveralls
```

### 7E. Flaky Test Handling in CI

```yaml
# Generated CI includes flaky test handling
flaky:
  detection:
    retry_count: 2               # Retry failed tests up to 2 times
    track_results: true           # Log retries to .bestest/state/flaky-tests.json
  quarantine:
    after_failures: 3             # Auto-quarantine after 3 flaky detections
    separate_suite: true          # Quarantined tests run in separate job
    auto_remove_days: 30          # Remove from quarantine after 30 days
```

---

## Section 8: Memory, Context & Hooks

### 8A. Cross-Session Memory (`.bestest/` + Claude Memory)

The skill uses a **dual memory model**:

**Repo Memory (`.bestest/`)** — Version-controlled, shared across team:
```
.bestest/
├── TESTING.md                    # Living strategy doc
├── config.yaml                   # Test architecture config
├── state/
│   ├── stack-profile.json        # Detected language/framework stack
│   ├── coverage-baseline.json    # Latest coverage snapshot
│   ├── coverage-history.json     # Coverage trend (date → coverage)
│   ├── flaky-tests.json          # Tracked flaky tests + metadata
│   ├── test-inventory.json       # All test files cataloged
│   ├── framework-versions.json   # Installed versions for freshness
│   └── generation-log.json       # History of AI-generated tests
├── adrs/                         # Architecture Decision Records
├── scripts/                      # Utility scripts
└── reports/                      # Latest + archived reports
```

**Claude Memory** — Per-user, cross-repo learning:
```markdown
# user testing preferences
- Prefers Vitest over Jest for new projects
- Coverage target: 85% line, 80% branch
- Uses GitHub Actions for CI

# project testing context
- Repo uses TypeScript + Python (polyglot monorepo)
- Primary test runner: Vitest (JS/TS), pytest (Python)
- Flaky test budget: 2% max
- Last scan: 2026-04-20, coverage 72% → target 85%
```

### 8B. Context Loading Strategy

When the skill is invoked, it loads context in priority order:

```
1. .bestest/config.yaml          → Current test architecture config
2. .bestest/TESTING.md            → Strategy and current state
3. .bestest/state/stack-profile   → What language/framework are we working with
4. Context7                       → Latest framework documentation
5. .bestest/state/test-inventory  → What tests exist, what's missing
6. .bestest/state/coverage-*      → Coverage baselines and history
7. Source code under test          → The actual code to generate tests for
```

This ensures every command has the full context of the project's testing state.

### 8C. Hook System

**Pre-hooks** (run before command execution):

| Hook | When | Purpose |
|------|------|---------|
| `validate-config` | Before any command | Ensure `.bestest/config.yaml` is valid and present |
| `freshness-check` | Before `generate`, `expand`, `migrate` | Verify framework docs are current via Context7 |
| `stack-detect` | Before `init`, `scan` | Ensure stack profile is up-to-date |
| `coverage-baseline` | Before `generate`, `fix` | Capture current coverage for delta calculation |

**Post-hooks** (run after command completion):

| Hook | When | Purpose |
|------|------|---------|
| `update-coverage` | After `run`, `generate`, `fix` | Update coverage baseline and history |
| `update-inventory` | After `generate`, `fix`, `migrate` | Refresh test file catalog |
| `update-testing-md` | After any state-changing command | Regenerate TESTING.md with latest data |
| `check-flaky` | After `run` | Detect new flaky tests, update tracking |
| `report-generation` | After `run`, `scan`, `coverage` | Generate summary report |

**Hook implementation**: Hooks are defined in the orchestrator `SKILL.md` and executed as mandatory steps in each spoke skill's flow. They're not optional — the skill always runs them.

### 8D. State Transitions

```
init → creates .bestest/ from scratch
scan → reads + updates .bestest/state/*
generate → reads state → creates tests → updates inventory + coverage
run → reads config → executes → updates coverage + flaky
fix → reads flaky-tests.json → fixes → updates flaky tracking
doctor → reads all state → produces health report
expand → reads config → adds new framework → updates config
migrate → reads config → transforms tests → updates config + inventory
ci → reads config → generates workflow → writes CI files
config → reads + writes config.yaml
report → reads all state → generates report
```

Every state transition is **atomic**: the skill reads state, performs work, then writes updated state. If the command fails mid-way, the previous state remains intact.

---

## Section 9: Reference Materials & Knowledge Base

### 9A. Static References (Ship With the Skill)

These encode **stable principles** that don't change with framework versions:

**`references/testing-strategies.md`** — Testing model selection guide:
- Testing Pyramid (monolith), Testing Trophy (frontend), Testing Honeycomb (microservices), Testing Diamond (modern API-centric)
- When to apply which model
- Test level definitions (what counts as "unit" vs "integration" vs "E2E")

**`references/anti-patterns.md`** — Full testing anti-pattern catalog:
- 20 test smells with detection and fixes (from Section 6G)
- Ice cream cone anti-pattern
- Coverage theater
- Mock overuse / under-use
- Flaky test root causes catalog
- Test data anti-patterns

**`references/coverage-standards.md`** — Coverage philosophy:
- Line vs branch vs function vs mutation coverage
- Recommended targets by project criticality
- Diff coverage (new code vs existing code)
- MC/DC for critical paths
- When 100% coverage is wrong

**`references/ci-patterns.md`** — CI pipeline design patterns:
- Fast-feedback loop design
- Test splitting strategies
- Flaky test quarantine workflows
- Coverage gate enforcement
- Artifact management (reports, traces, screenshots)

**`references/ai-generation-guide.md`** — AI test generation principles:
- The 7-phase generation pipeline
- Equivalence class partitioning
- Boundary value analysis
- Property-based test derivation
- Test data factory pattern
- Verification loop mechanics

### 9B. Dynamic References (Fetched at Runtime)

These are fetched via **Context7** or **web search** during execution:

| What | When Fetched | Source |
|------|-------------|--------|
| Vitest API + config | Before generating JS/TS tests | Context7: `/vitest-dev/vitest` |
| Playwright API + config | Before generating E2E tests | Context7: `/microsoft/playwright.dev` |
| pytest API + fixtures | Before generating Python tests | Context7: `/websites/pytest_en_stable` |
| JUnit 5 API + extensions | Before generating Java tests | Context7: `/websites/junit_current` |
| Testcontainers API | Before integration test generation | Context7 |
| React Testing Library | Before React component tests | Context7 |
| Coverage tool config | Before coverage setup | Context7 |
| CI provider syntax | Before CI workflow generation | Web search |

### 9C. Generated Project-Level References

These are generated in `.bestest/` and maintained by the skill:

**`TESTING.md`** — The living test strategy document:
```markdown
# Testing Strategy — [Project Name]
> Last updated: 2026-04-20 by bestest

## Stack
- **Languages**: TypeScript, Python
- **Unit Runner**: Vitest (JS/TS), pytest (Python)
- **E2E Runner**: Playwright
- **CI Provider**: GitHub Actions

## Coverage Targets
| Metric | Target | Current |
|--------|--------|---------|
| Line   | 80%    | 72%     |
| Branch | 75%    | 64%     |

## Test Inventory
| Type         | Count | Status |
|--------------|-------|--------|
| Unit         | 142   | All passing |
| Integration  | 38    | 1 flaky |
| E2E          | 12    | All passing |
| API          | 27    | All passing |

## Known Gaps
- [ ] src/payment/stripe-webhook.ts — 0% coverage (critical path)
- [ ] src/auth/session-refresh.ts — 45% coverage, missing error paths
- [ ] scripts/data-migration.py — untested

## Flaky Tests (2 in quarantine)
| Test | First Seen | Root Cause | Status |
|------|-----------|------------|--------|
| auth-flow.test.ts:login timeout | 2026-04-15 | Race condition | Under investigation |
| api-rate-limit.test.ts:429 handling | 2026-04-18 | Timing dependent | Fix in progress |

## CI Pipeline
- Fast tests: < 3 min (PR gate)
- Integration: < 10 min (PR gate)
- E2E: < 30 min (merge gate)
```

**`adrs/`** — Architecture Decision Records:
```markdown
# ADR-001: Vitest as primary test runner

## Status: Accepted (2026-04-20)

## Context
Project uses Vite as build tool. Jest requires Babel/swc transform
for TypeScript, adding ~3s startup time. Vitest uses Vite's transform
pipeline natively.

## Decision
Adopt Vitest for all JS/TS unit and integration tests.

## Consequences
- Faster test execution (5-10x for TypeScript)
- Native ESM support
- Jest-compatible API reduces migration effort
- Browser mode available for component testing
```

---

## Section 10: Implementation Roadmap

### Phase Breakdown — Build Spoke by Spoke

```
Phase 1: Foundation (init + config + doctor)
  ├─ Orchestrator SKILL.md (command router)
  ├─ Detection engine (lib/detector.sh logic encoded in spoke)
  ├─ .bestest/ state model
  ├─ bestest-init spoke
  ├─ bestest-config spoke
  └─ bestest-doctor spoke

Phase 2: Analysis (scan + coverage + report)
  ├─ bestest-scan spoke
  ├─ bestest-coverage spoke
  └─ bestest-report spoke

Phase 3: Generation (generate — JS/TS only)
  ├─ bestest-generate spoke (Vitest + Playwright)
  ├─ 7-phase generation pipeline
  ├─ Test smell scanner
  └─ JS/TS templates + factories

Phase 4: Generation Expansion (generate — Python + Java + Go)
  ├─ pytest generation support
  ├─ JUnit 5 generation support
  └─ Go testing generation support

Phase 5: Operations (run + fix + expand)
  ├─ bestest-run spoke
  ├─ bestest-fix spoke (flaky test fixing)
  └─ bestest-expand spoke (add new test types)

Phase 6: Infrastructure (ci + migrate)
  ├─ bestest-ci spoke (GitHub Actions, GitLab CI, Jenkins)
  └─ bestest-migrate spoke (Jest→Vitest, JUnit4→5, Cypress→Playwright)

Phase 7: Polish
  ├─ Pressure testing all spoke skills
  ├─ Edge case handling
  ├─ Error recovery
  └─ Documentation
```

### Dependencies Between Phases

```
Phase 1 ──→ Phase 2 ──→ Phase 3 ──→ Phase 5
                                    ↗
              Phase 4 ──────────────
                                    ↘
              Phase 6 ──────────────→ Phase 7
```

- Phase 1 must be first (foundation everything depends on)
- Phase 2 depends on Phase 1 (needs .bestest/ state)
- Phase 3 depends on Phase 2 (needs coverage baselines for delta)
- Phase 4 can run in parallel with Phase 3
- Phase 5 depends on Phase 3 (needs generation working)
- Phase 6 can start after Phase 3
- Phase 7 is final polish

### Per-Spoke Skill Template

Each spoke follows this structure:

```markdown
# bestest-<command>

## Purpose
One-line description of what this command does.

## Prerequisites
- .bestest/config.yaml must exist (or: will be created)
- Stack profile detected

## Context Loading
1. Read .bestest/config.yaml
2. Read .bestest/state/<relevant-files>
3. Fetch latest framework docs via Context7 (if needed)

## Flow
Step-by-step process with HITL gates clearly marked.

## HITL Gates
- Gate 1: <what the human approves>
- Gate 2: <what the human approves>

## Post-Hooks
- <which hooks run after>

## Error Recovery
- If <condition>: <action>
- If <condition>: <action>

## Output
- Files created/modified
- State updates
- User-visible summary
```

---



# SESSION 2 ADDITIONS

No previous session context found — no memory files, no planning files, and only the initial commit exists (`fab0914 chore: init gsd`).

This appears to be a fresh project. There's nothing to resume from a previous session.

What were you working on, or what would you like to start?

---

I've recovered the entire design. Now let me also check what user messages were sent to capture your decisions, and then I'll save this properly.

---

Good — your original prompt was the first one. Let me also check the subagents for any written output files.

---

Good. The session got stuck before it could write the architecture to disk. I have the **complete 10-section design** from the conversation. Let me save it now.

---

Using **dispatching-parallel-agents** to scan all local data sources, and **writing-skills** since this is a skill design. I already recovered the full 10-section design from your previous session. Let me dispatch agents to check for any additional context while I write the complete doc.

---

Using **dispatching-parallel-agents** to scan all data sources in parallel, while I write the recovered design to disk.

---

3 agents dispatched in background. Now writing the complete architecture doc to disk — this is the critical part.

---

