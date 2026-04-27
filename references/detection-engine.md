# Detection Engine

<detection_engine>

## Purpose

Profile the repository's technology stack and produce a `StackProfile` JSON that drives all downstream decisions. The StackProfile schema is defined in `references/stack-profile-schema.md`.

## Detection Order

Follow this order for optimal performance — cheap file-existence checks first, then dependency parsing:

### Phase 1: Language and Ecosystem

1. Check for `package.json` — if found, this is JS/TS ecosystem (highest signal)
   - Check `tsconfig.json` → TypeScript detected, confidence > 0.95
   - Check `*.ts`, `*.tsx` source files → additional TypeScript evidence
   - Check `*.js`, `*.jsx` source files → JavaScript evidence
2. Check for `requirements.txt`, `pyproject.toml`, `setup.py` → Python ecosystem
3. Check for `go.mod` → Go ecosystem
4. Check for `pom.xml`, `build.gradle`, `build.gradle.kts` → JVM ecosystem
5. Check for `Cargo.toml` → Rust ecosystem
6. Check for `Gemfile` → Ruby ecosystem
7. Check for `*.csproj` → .NET ecosystem

If none of these files exist, stop. The repository is not a supported ecosystem. Inform the user.

## Confidence Scoring Algorithm

All confidence scores are computed via **noisy-OR signal aggregation**, which produces deterministic results regardless of LLM provider — no subjective judgment calls.

### Formula Definition

```
confidence(category) = min(0.99, 1 - Π(1 - w_i))    for all matching signals i ∈ category
```

Where `w_i` is the concrete signal weight determined by strength:

| Strength | Weight `w_i` | When Used |
|----------|-------------|-----------|
| **high** | `0.40` | Definitive proof: config file at expected path, explicit dependency declaration |
| **medium** | `0.20` | Strong indicator: lock file presence, script command reference, workspace config |
| **low** | `0.08` | Supporting evidence: file extension pattern, import heuristic, indirect reference |

**Cap:** `0.99` — confidence never reaches 1.0 (certainty is never absolute from signals alone).

**Mathematical property:** Each additional signal increases confidence with diminishing returns. Two high signals: `1 - (1-0.40)(1-0.40) = 0.64`. Three high signals: `1 - (1-0.40)³ = 0.784`. The formula approaches but never exceeds 1.0.

For confidence score range semantics (0.9+, 0.7–0.9, etc.), see `references/stack-profile-schema.md`.

### Definitive Single Signal Override

When **exactly one** signal is detected AND that signal is a definitive ecosystem config file, set confidence immediately to **0.95** without requiring corroboration:

| Definitive Signal | Language |
|-------------------|----------|
| `tsconfig.json` | TypeScript |
| `go.mod` | Go |
| `pom.xml` | Java/Maven |
| `pyproject.toml` | Python |
| `Cargo.toml` | Rust |
| `Gemfile` | Ruby |
| `build.gradle` or `build.gradle.kts` | Java/Kotlin/Gradle |

After the override, continue checking for corroborating signals. Apply the noisy-OR formula with the definitive signal at weight 0.95 and additional signals at their normal weights:

```
confidence = 1 - (1 - 0.95) × Π(1 - w_j)    for additional signals j
```

Example: `tsconfig.json` alone → 0.95. `tsconfig.json` + `package.json` + `*.ts` files → `1 - (1-0.95)(1-0.40)(1-0.40) = 1 - 0.05×0.36 = 0.982 → 0.98`.

### Context Relevance Modifier (Polyglot Projects)

For projects with multiple languages, apply a **context relevance multiplier** to signal weights based on the language's role:

```
effective_w_i = w_i × context_relevance(language, project)
```

| Classification | Condition | Multiplier |
|---------------|-----------|------------|
| **Primary** | Config file exists at project root | `1.0` |
| **Isolated primary** | Config file exists in a subdirectory only (e.g., `microservice/go.mod`) | `1.0` for subdirectory scope, `0.7` for project scope |
| **Secondary** | Only source files in `scripts/`, `tools/`, `examples/`, `hack/` | `0.7` |
| **Incidental** | Only file-extension matches, no config file anywhere | `0.4` |

**Evaluation procedure:**
```
for each detected language L:
  if L has config file in project root → PRIMARY (1.0)
  elif L has config file in any subdirectory → ISOLATED_PRIMARY (1.0 sub, 0.7 project)
  elif L has only source files in scripts/tools/examples/hack → SECONDARY (0.7)
  elif L has only file-extension matches → INCIDENTAL (0.4)
  else → PRIMARY (1.0)  // default
```

### Multi-Language Ranking Algorithm

When multiple languages exceed the confidence threshold, rank by:

1. **Primary sort:** Descending confidence score
2. **Tiebreaker (within 0.05):** Language with more source files wins
3. **Final tiebreaker:** Detection order preference: `TypeScript > JavaScript > Python > Go > Java > Kotlin > Rust > Ruby > C#/.NET > PHP`

```
languages.sort((a, b) => {
  if (abs(a.confidence - b.confidence) > 0.05) return b.confidence - a.confidence
  if (a.sourceFileCount !== b.sourceFileCount) return b.sourceFileCount - a.sourceFileCount
  return detectionOrder.indexOf(a.name) - detectionOrder.indexOf(b.name)
})
```

Present the top 3 languages to the user if confidence ≥ 0.6. The first language in the ranked list is the **primary language** for routing.

### Phase 2: Package Manager

Check for lock files and package manager markers:
- `pnpm-lock.yaml` → pnpm (confidence 0.95+)
- `yarn.lock` → yarn (confidence 0.95+)
- `package-lock.json` → npm (confidence 0.95+)
- `bun.lockb` → bun (confidence 0.95+)
- `packageManager` field in `package.json` → explicit declaration (confidence 0.99)
- `poetry.lock` → Poetry (confidence 0.95+)
- `uv.lock` → uv (confidence 0.95+)
- `go.sum` → Go modules (confidence 0.95+)

### Phase 3: Build Tool

Check for config files:
- `vite.config.{ts,js,mjs}` → Vite
- `webpack.config.{ts,js}` → Webpack
- `next.config.{ts,js,mjs}` → Next.js (acts as build tool)
- `turbo.json` → Turborepo
- Also check `package.json` devDependencies for corresponding packages

### Phase 4: Framework

Parse `package.json` dependencies (or equivalent):
- `"next"` → Next.js
- `"@remix-run/react"` → Remix
- `"express"` → Express
- `"fastify"` → Fastify
- `"@nestjs/core"` → NestJS
- `"react"` → React
- `"vue"` → Vue
- `"svelte"` → Svelte
- `"solid-js"` → SolidJS
- `"@angular/core"` → Angular

For Python: parse `requirements.txt` or `pyproject.toml` for `django`, `fastapi`, `flask`.
For Go: parse `go.mod` require directives.
For JVM: parse `build.gradle` or `pom.xml`.

### Phase 5: Test Framework

Check for existing test infrastructure:
- `vitest.config.*` or `"vitest"` in devDependencies → Vitest
- `jest.config.*` or `"jest"` in devDependencies → Jest
- `pytest.ini` or `[tool.pytest` in `pyproject.toml` → pytest
- `useJUnitPlatform()` in `build.gradle` → JUnit 5
- `junit:junit` (non-jupiter) in dependencies → JUnit 4
- `*_test.go` files → Go testing

#### Multi-Framework Conflict Detection (Category-Based)

When multiple test frameworks are detected, apply a **category-based detection algorithm** that catches any multi-framework scenario within the same ecosystem — not just 2 hardcoded pairs.

**Algorithm:**

1. **Group by ecosystem:** Collect all detected test frameworks and group by language ecosystem (JS/TS, Python, JVM, Go). Conflict detection is **always per-ecosystem** — cross-language combinations are never conflicts (e.g., Vitest + pytest is not a conflict).

2. **Filter known non-conflicts:** Remove pairs that represent normal coexistence:
   - pytest + unittest → pytest runs unittest natively
   - testify + gomock → complementary (assertions + generated mocks)
   - builtin_go + testify → testify extends builtin
   - Mockito + MockK → Java vs Kotlin mocking (complementary in mixed projects)

3. **Group by category:** For each ecosystem, group remaining frameworks into categories: **unit**, **e2e**, **bdd**, **mock**.

4. **Detect conflicts:** For each category with >1 framework in the same ecosystem, classify:
   - `same-category-competing` — two frameworks serving the same testing function (e.g., Vitest + Mocha, JUnit5 + TestNG, Cypress + Playwright)
   - `legacy-modern-coexistence` — old + new framework during migration period (e.g., JUnit4 + JUnit5, Vitest + Jest)

5. **Apply preference table for recommendation:**
   - **JS/TS unit:** Vitest > Jest > Mocha
   - **JS/TS e2e:** Playwright > Cypress > Selenium
   - **Python unit:** pytest > nose2 (unittest is stdlib, not a conflict)
   - **JVM unit:** JUnit5 > JUnit4, JUnit5 > TestNG
   - **Go unit:** builtin + testify > ginkgo

6. **Record conflict** in `testFrameworks.conflicts`:
   ```json
   {
     "type": "same-category-competing | legacy-modern-coexistence",
     "category": "unit | e2e | bdd | mock",
     "frameworks": ["framework_a", "framework_b"],
     "recommendation": "recommended_framework",
     "rationale": "1-2 sentence explanation"
   }
   ```

**Conflict resolution principle:** Always recommend the modern framework as primary with a migration path. Never silently drop a detected framework — both are recorded in `testFrameworks.existing` as an array, and the user chooses during the HITL gate (Phase 3 of spoke-init.md).

### Phase 5.5: Legacy Framework Detection

After modern test frameworks are identified in Phase 5, scan for legacy test frameworks that may already be in use. This phase is critical for brownfield repos — the init spoke needs to know what already exists to offer coexist, migrate, or replace modes.

**JS/TS legacy frameworks:**

1. **Mocha** — Check for `.mocharc.{js,json,yml,yaml,cjs}`, `"mocha"` in devDependencies, or `"mocha"` in test script.
2. **Jasmine** — Check for `spec/support/jasmine.json` or root `jasmine.json`, `"jasmine"` in devDependencies, or `"jasmine"` in test script.
3. **Ava** — Check for `ava.config.{js,cjs,mjs}`, `"ava"` in devDependencies, or `"ava"` in test script.
4. **tap** — Check for `.taprc` (or `.taprc.{yml,json,js}`), `"tap"` in devDependencies, or `"tap"` in test script.
5. **node:test** — Check for `import ... from 'node:test'` or `require('node:test')` in test files, or `"node --test"` in test script. This is Node.js's built-in runner (Node 18+) — it may coexist with other frameworks.
6. **Karma** — Check for `karma.conf.{js,ts,coffee}`, `"karma"` in devDependencies, or `"karma"` in test script.

**Python legacy frameworks:**

1. **nose2** — Check for `[tool.nose2]` in `pyproject.toml`, `unittest.cfg` at project root, `"nose2"` in requirements, or `"nose2"` in test script/target.

**Algorithm:**

1. For each legacy framework, collect signals using the same noisy-OR confidence scoring as Phase 5.
2. If confidence ≥ 0.60, record the framework in `testFrameworks.existing` alongside any modern frameworks from Phase 5.
3. Apply the category-based conflict detection from Phase 5 — legacy frameworks compete in the "unit" category against modern ones (e.g., Mocha vs Vitest is a `legacy-modern-coexistence` conflict).
4. Record a `legacyDetected` flag in the StackProfile to signal the init spoke that brownfield handling is needed:
   ```json
   {
     "testFrameworks": {
       "existing": ["mocha", "vitest"],
       "legacyDetected": true,
       "legacyFrameworks": [
         { "name": "mocha", "confidence": 0.95, "signals": [".mocharc.js", "devDependency"] }
       ]
     }
   }
   ```
5. If any legacy framework is detected, compute a lightweight **test inventory snapshot** — count test files by glob pattern (e.g., `test/**/*.test.js`, `spec/**/*.spec.js`, `tests/*_test.py`). This inventory is stored in `testFrameworks.inventory` for downstream gap analysis by the scan and generate spokes:
   ```json
   {
     "testFrameworks": {
       "inventory": {
         "totalFiles": 47,
         "byPattern": {
           "test/**/*.test.js": 32,
           "spec/**/*.spec.js": 15
         },
         "byFramework": {
           "mocha": { "estimatedFiles": 47, "configFile": ".mocharc.js" }
         }
       }
     }
   }
   ```

### Phase 6: E2E Framework

- `playwright.config.*` or `"@playwright/test"` in devDependencies → Playwright
- `cypress.config.*` or `"cypress"` in devDependencies → Cypress

### Phase 7: CI, Monorepo, Database, Coverage

- `.github/workflows/` → GitHub Actions
- `pnpm-workspace.yaml`, `nx.json`, `turbo.json` → Monorepo detected
- Database drivers in dependencies (`pg`, `mongodb`, `ioredis`, etc.)
- Coverage providers (`@vitest/coverage-v8`, `pytest-cov`, `jacoco`, etc.)

### Phase 8: Java/JVM Detection (conditional)

If `pom.xml` or `build.gradle`/`build.gradle.kts` was detected in Phase 1:

1. **Build tool detection** — Determine Gradle vs Maven:
   - `build.gradle` or `build.gradle.kts` → Gradle
   - `pom.xml` → Maven
   - Both present → Gradle takes precedence (more common for modern projects)

2. **Java version detection** — Extract source compatibility:
   - Gradle: `sourceCompatibility` in `build.gradle` or `java.toolchain.languageVersion` in `build.gradle.kts`
   - Maven: `<java.version>` or `<source>` in `pom.xml` `<properties>`
   - Fallback: `java -version` from system

3. **Framework detection** — Check for Spring Boot:
   - `@SpringBootApplication` in source files → Spring Boot
   - `spring-boot-starter-test` in dependencies → Spring Boot
   - `@SpringBootConfiguration` → Spring Boot
   - Micronaut, Quarkus: check for respective annotations/configs
   - None of the above → Plain Java

4. **Test framework detection** — Check for existing test frameworks:
   - `junit-jupiter` or `useJUnitPlatform()` → JUnit 5
   - `junit:junit` (non-jupiter) → JUnit 4
   - `testng` → TestNG
   - None detected → No existing test framework

### Phase 9: Go Detection (conditional)

If `go.mod` was detected in Phase 1:

1. **Go version detection** — Extract from go.mod:
   - Parse `go` directive in go.mod (e.g., `go 1.22`)
   - Fallback: `go version` from system

2. **Module path detection** — Extract module path:
   - Parse `module` directive in go.mod (e.g., `module github.com/user/project`)

3. **Framework detection** — Check for HTTP frameworks:
   - `"github.com/gin-gonic/gin"` in go.mod require → Gin framework
   - `"github.com/labstack/echo"` in go.mod require → Echo framework
   - `"github.com/go-chi/chi"` in go.mod require → Chi router
   - `"google.golang.org/grpc"` in go.mod require → gRPC services
   - None of the above → Check for `net/http` usage in source files (stdlib HTTP)
   - No HTTP usage detected → Non-HTTP project (CLI/library)

4. **Test framework detection** — Check for existing test frameworks:
   - `"github.com/stretchr/testify"` in go.mod require → testify (assert/require/mock/suite)
   - `"github.com/golang/mock"` or `"go.uber.org/mock"` in go.mod require → gomock
   - `*_test.go` files with `func Test*` → Plain Go testing
   - None detected → No existing test framework

### Early Termination

Once confidence ≥ 0.90 for the primary category (computed via the noisy-OR algorithm above), skip remaining signal checks in that category. Focus effort on categories where confidence is still below 0.7. Implementation: evaluate signals sequentially and break out of the category loop once the threshold is met — this is both a performance optimization and an accuracy guard, since additional signals add negligible information once confidence is very high.

### Monorepo Detection

Do NOT rely on directory structure alone. Check workspace config files:
- `pnpm-workspace.yaml` → pnpm workspace
- `"workspaces"` in root `package.json` → npm/yarn workspaces
- `nx.json` → Nx
- `turbo.json` → Turborepo
- `lerna.json` → Lerna
- `WORKSPACE`, `BUILD.bazel` → Bazel
- `settings.gradle` with multiple `include` → Gradle multi-module

### Signal Catalog

The complete signal catalog with strength ratings is in `references/detection-signals.md`. Consult it for the full list of 80+ signals across 12 categories.

### Output

Produce a `StackProfile` JSON following the schema in `references/stack-profile-schema.md`. Include `confidence` scores (0–1) and `evidence` arrays for every detection. If Phase 5.5 detected any legacy frameworks, also include `testFrameworks.legacyDetected`, `testFrameworks.legacyFrameworks`, and `testFrameworks.inventory` in the output. Write it to `.bestest/state/stack-profile.json`.

</detection_engine>
