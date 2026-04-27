# JS/TS Framework Decision Tree

Complete framework selection decision tree for JavaScript/TypeScript repositories. The detection engine uses this tree to populate the `testFrameworks` and `e2eFramework` recommendations in the StackProfile.

## Decision Flow

### Step 1: Check for Vite

```
Has "vite" in dependencies or vite.config.* exists?
├─ YES → Recommend Vitest
│         Rationale: Native Vite transform pipeline. 5-10x faster than Jest for
│         TypeScript because it reuses Vite's already-configured transforms instead
│         of running a separate Babel/swc compilation step.
│
│         Additional plugins based on frontend:
│         ├─ Has "react" → Add @vitejs/plugin-react, recommend React Testing Library
│         ├─ Has "vue" → Add @vitejs/plugin-vue, recommend Vue Test Utils
│         ├─ Has "svelte" → Add @sveltejs/vite-plugin-svelte
│         └─ Has "solid-js" → Add vite-plugin-solid, recommend Solid Testing Library
│
│         Coverage: V8 provider (@vitest/coverage-v8)
│         Config file: vitest.config.ts
│
└─ NO → Proceed to Step 2
```

### Step 2: Check for Next.js

```
Has "next" in dependencies or next.config.* exists?
├─ YES → Recommend Vitest
│         Rationale: Official Next.js recommendation since 2024. Vitest handles
│         Server Component testing via browser mode. Jest requires custom
│         configuration for Next.js App Router.
│
│         Additional: Recommend Playwright for E2E (Next.js has official Playwright examples)
│         Coverage: V8 provider
│         Config file: vitest.config.ts (with Next.js plugin)
│
└─ NO → Proceed to Step 2.5
```

### Step 2.5: Check for Legacy Test Frameworks (Brownfield Detection)

```
Has any legacy test framework been detected by Phase 5.5?
(Mocha, Jasmine, Ava, tap, node:test, Karma)

├─ YES → Determine handling mode based on test inventory size and framework depth:

│         **Mocha detected?**
│         ├─ Has >30 test files? → Coexist mode
│         │     Recommend: Vitest alongside Mocha
│         │     Rationale: Large Mocha test suites have significant migration cost.
│         │     Coexistence allows gradual migration. New tests use Vitest, existing
│         │     tests continue running via Mocha. Config: separate vitest.config.ts,
│         │     Mocha config preserved as-is.
│         │     Coverage: V8 provider for Vitest tests, Mocha tests excluded from
│         │     bestest coverage tracking initially.
│         │
│         ├─ Has 10-30 test files with simple config? → Present migration option
│         │     Check: Does .mocharc use custom reporters, parallel mode, or file watches?
│         │     If simple config (just spec paths + maybe a reporter) → Offer full migration
│         │       - Vitest supports Mocha-style describe/it natively
│         │       - chai assertions → expect (mechanical transform)
│         │       - Mocha hooks (before/after/beforeEach/afterEach) → Vitest equivalents
│         │     If complex config (custom loaders, programmatic API, browser testing) → Coexist
│         │
│         └─ Has <10 test files? → Replace mode
│               Recommend: Full migration to Vitest
│               Rationale: Small test count means migration is cheap. Vitest is
│               a superset of Mocha's API. The describe/it/beforeEach patterns
│               transfer directly. Remove Mocha dependency, install Vitest.
│
│         **Jasmine detected?**
│         ├─ Has >20 test files? → Coexist mode
│         │     Recommend: Vitest alongside Jasmine
│         │     Rationale: Jasmine's assertion API differs significantly from Jest/Vitest
│         │     (expect(x).toBe(y) vs expect(x).toEqual(y) patterns differ).
│         │     Large suites require careful migration of matchers.
│         │
│         ├─ Has 5-20 test files? → Present migration option
│         │     Check: Custom matchers (jasmine.addMatchers)? Custom reporters?
│         │     If standard matchers only → Offer full migration
│         │     If heavy custom matchers → Coexist
│         │
│         └─ Has <5 test files? → Replace mode
│               Recommend: Full migration to Vitest
│
│         **Ava detected?**
│         ├─ Any test count → Coexist or Replace
│         │     Ava's concurrent-by-default model differs from Vitest/Jest.
│         │     Ava uses `test()` not `describe/it`. Migration requires test structure changes.
│         │     For <15 files → Replace mode (structural changes are manageable)
│         │     For >=15 files → Coexist mode (migrate incrementally)
│         │
│         **tap/node:test detected?**
│         ├─ Any test count → Coexist mode preferred
│         │     tap and node:test use TAP protocol, fundamentally different from Jest/Vitest.
│         │     Coexistence is cleaner than migration. New tests go to Vitest.
│         │     node:test is stdlib — no migration possible, only coexistence.
│         │
│         **Karma detected?**
│         ├─ Any test count → Replace mode
│         │     Karma is deprecated. Recommend migration regardless of test count.
│         │     Karma tests run in real browsers; migrate to Vitest with jsdom/happy-dom
│         │     for unit tests, Playwright for browser-level tests.
│         │
│         **Brownfield mode selection:**
│         ├─ Coexist → StackProfile.brownfield = true, config.state.init_type = "brownfield-coexist"
│         │             config.state.existing_frameworks_preserved = ["mocha"] (etc.)
│         │             Existing test files untouched, new tests use Vitest
│         ├─ Migrate → StackProfile.brownfield = true, config.state.init_type = "brownfield-migrate"
│         │             Migration plan generated, tests converted incrementally
│         └─ Replace → StackProfile.brownfield = true, config.state.init_type = "brownfield-replace"
│                       Legacy framework removed, all tests rewritten for Vitest
│
│         **testInventory snapshot** (computed for all brownfield inits):
│         - Count existing test files by framework (by pattern matching)
│         - Estimate uncovered source (by comparing test dirs to source dirs)
│         - Store in StackProfile.testInventory for scan/generate spoke gap analysis
│
│         Coverage: V8 provider (Vitest primary)
│         Config file: vitest.config.ts (alongside preserved legacy config)
│
└─ NO → Proceed to Step 3
```

```
Has jest.config.* or "jest" in devDependencies?
├─ YES → Check customization depth
│         ├─ Has @swc/jest or custom transformers? → Keep Jest (already optimized)
│         ├─ Has custom matchers (jest-extended, etc.)? → Keep Jest
│         ├─ Has complex setup files (global mocks, custom environment)? → Keep Jest
│         ├─ Has >50 test files already? → Keep Jest (migration cost high)
│         ├─ Has 20-50 test files? → Evaluate migration ROI
│         │     Check: How many custom matchers / setup files depend on Jest globals?
│         │     If mostly standard assertions (expect, mock, spy) → Present migration option
│         │     If heavy Jest-specific plugins (jest-extended, jest-image-snapshot) → Keep Jest
│         │     Rationale: 20-50 files is the inflection point where migration cost is
│         │     moderate — large enough to matter, small enough to be feasible. The deciding
│         │     factor is dependency on Jest-specific APIs vs standard Jest-compatible patterns.
│         └─ Simple config with <20 test files? → Present migration option to user
│
│         Rationale: Migration cost exceeds benefit for established Jest setups.
│         Only recommend Vitest migration for small/medium setups where the Jest
│         config is straightforward.
│
│         If keeping Jest:
│         Coverage: Istanbul (via babel-jest or @swc/jest)
│         Consider: Add @swc/jest for TS speed improvement
│
└─ NO → Proceed to Step 4
```

### Step 4: Default Recommendation

```
No existing test framework detected.
├─ TypeScript project → Vitest (future-proof, Jest-compatible API, native TS)
├─ JavaScript project → Vitest (same reasons, simpler setup than Jest)
└─ Reasoning: Vitest is the forward-looking choice. Its API is Jest-compatible
    so any existing Jest knowledge transfers. Native ESM support, faster for TS,
    and built-in coverage.
```

### Step 5: Monorepo Consideration

```
Is monorepo detected? (pnpm-workspace, nx, turbo, lerna)
├─ YES → Use Vitest Workspace
│         Config: vitest.workspace.ts (or vitest.workspace.js)
│         Each package: own vitest.config.ts
│         Root: defineWorkspace(['packages/*'])
│         Filter tests: vitest --project=<package-name>
│         Coverage: unified report via --coverage at root level
│
│         Monorepo tool specifics:
│         ├─ pnpm workspace → Vitest workspace works directly
│         ├─ Nx → Use @nx/vite plugin, Vitest workspace for cross-package
│         ├─ Turborepo → Add "test" task to turbo.json, Vitest workspace underneath
│         └─ Lerna → Vitest workspace, each package independent
│
│         Rationale: Vitest Workspace is purpose-built for monorepo testing.
│         Jest Projects also works but has more config overhead.
│
└─ NO → Standard single-package setup
```

### Step 6: E2E Framework Selection

```
Does the project have a frontend (React, Vue, Svelte, Solid, Angular)?
├─ YES → Recommend Playwright
│         Rationale: Multi-browser support (Chromium, Firefox, WebKit), component
│         testing in same config, API testing via request context, CI sharding
│         built-in, auto-wait by default, trace viewer for debugging.
│
│         Only recommend Cypress if:
│         - Team has deep existing Cypress expertise AND
│         - Project already uses Cypress plugins that lack Playwright equivalents AND
│         - Migration cost is prohibitive
│
│         Playwright setup:
│         Config: playwright.config.ts
│         Install: @playwright/test
│         CI sharding: npx playwright test --shard=1/4
│         Trace: trace: 'on-first-retry'
│         Selectors: data-testid preferred
│
├─ NO (API-only) → Skip E2E framework recommendation
│         API testing options:
│         ├─ Express/Fastify → Supertest (HTTP assertions)
│         ├─ Any framework → MSW (Mock Service Worker for API mocking)
│         └─ NestJS → @nestjs/testing + Supertest
│
│         Rationale: API-only projects don't need browser automation.
│         Supertest provides clean HTTP-level testing. MSW handles
│         external service mocking without starting a real server.
│
└─ Unknown → Present both options, default to Playwright
```

### Step 7: Coverage Provider

```
Determine coverage provider based on test framework:
├─ Vitest → @vitest/coverage-v8 (default) or @vitest/coverage-istanbul
│         V8 is faster. Istanbul handles edge cases better (branch coverage on
│         complex expressions). Default to V8 unless user needs Istanbul precision.
├─ Jest → Istanbul (built-in, via babel-jest or @swc/jest)
│         No additional install needed for coverage.
└─ Go with Vitest → V8 coverage is the recommended default.
```

## Confidence Thresholds for Recommendations

| Scenario | Confidence | Explanation |
|----------|------------|-------------|
| Vite detected → Vitest | 0.95+ | Direct evidence, native pairing |
| Next.js detected → Vitest | 0.90+ | Official recommendation, well-documented |
| Existing Jest, simple config → Migration option | 0.70-0.80 | Strong case but migration has risk |
| Existing Jest, complex config → Keep Jest | 0.90+ | Stability over novelty |
| No existing framework → Vitest | 0.80+ | Best default for new projects |
| Frontend detected → Playwright | 0.90+ | Industry standard, multi-browser |
| API-only → Supertest/MSW | 0.85+ | Purpose-built for API testing |
| Monorepo → Vitest Workspace | 0.85+ | Purpose-built for monorepo |

## Decision Summary Table

| Detected Stack | Test Runner | E2E Runner | Coverage | Config File |
|----------------|-------------|------------|----------|-------------|
| Vite + React | Vitest | Playwright | V8 | `vitest.config.ts` |
| Vite + Vue | Vitest | Playwright | V8 | `vitest.config.ts` |
| Vite + Svelte | Vitest | Playwright | V8 | `vitest.config.ts` |
| Next.js | Vitest | Playwright | V8 | `vitest.config.ts` |
| Express (no frontend) | Vitest | None (Supertest for API) | V8 | `vitest.config.ts` |
| Fastify (no frontend) | Vitest | None (Supertest for API) | V8 | `vitest.config.ts` |
| Existing Jest (simple) | Jest or Vitest (user choice) | Playwright | Istanbul | `jest.config.ts` |
| Existing Jest (complex) | Jest (keep) | Playwright or keep Cypress | Istanbul | `jest.config.ts` |
| pnpm monorepo | Vitest Workspace | Playwright | V8 | `vitest.workspace.ts` |
| Nx monorepo | Vitest Workspace | Playwright | V8 | `vitest.workspace.ts` |
| Turborepo monorepo | Vitest Workspace | Playwright | V8 | `vitest.workspace.ts` |
| No framework detected | Vitest | Playwright (if frontend) | V8 | `vitest.config.ts` |
| **Existing Mocha (>30 tests)** | **Vitest (coexist)** | Playwright (if frontend) | V8 | `vitest.config.ts` + `.mocharc.*` preserved |
| **Existing Mocha (<10 tests)** | **Vitest (replace)** | Playwright (if frontend) | V8 | `vitest.config.ts` |
| **Existing Jasmine (>20 tests)** | **Vitest (coexist)** | Playwright (if frontend) | V8 | `vitest.config.ts` + `jasmine.json` preserved |
| **Existing Jasmine (<5 tests)** | **Vitest (replace)** | Playwright (if frontend) | V8 | `vitest.config.ts` |
| **Existing Ava (<15 tests)** | **Vitest (replace)** | Playwright (if frontend) | V8 | `vitest.config.ts` |
| **Existing Ava (>=15 tests)** | **Vitest (coexist)** | Playwright (if frontend) | V8 | `vitest.config.ts` + `ava.config.*` preserved |
| **Existing tap/node:test** | **Vitest (coexist)** | Playwright (if frontend) | V8 | `vitest.config.ts` |
| **Existing Karma** | **Vitest (replace)** | Playwright | V8 | `vitest.config.ts` |

## ADR Template

When the detection engine makes a framework recommendation, document it as an Architecture Decision Record in `.bestest/adrs/`:

```markdown
# ADR-NNN: [Test Framework Selection]

## Status: Proposed

## Context
- **Languages detected**: [from StackProfile.languages]
- **Build tool**: [from StackProfile.buildTool]
- **Frameworks**: [from StackProfile.frameworks]
- **Existing test framework**: [from StackProfile.testFrameworks.existing or "none"]
- **Monorepo**: [from StackProfile.monorepo]

## Decision
Adopt **[recommended framework]** for [unit/integration/E2E] testing.

## Rationale
[Auto-populated from the decision tree path taken. Example:]
"Vite is the build tool. Vitest uses Vite's native transform pipeline, providing
5-10x faster test execution for TypeScript compared to Jest which requires a
separate Babel/swc compilation step. Vitest's API is Jest-compatible, reducing
learning curve."

## Consequences
- [Specific benefit from the recommendation]
- [Any trade-off or limitation]
- [Migration effort if changing from existing framework]

## Alternatives Considered
- **[Alternative 1]**: [Why it was not chosen]
- **[Alternative 2]**: [Why it was not chosen]
```

## Integration with Detection Engine

The decision tree is evaluated after the detection engine has populated all signal categories. The evaluation follows this sequence:

1. Build the StackProfile from all detected signals
2. Evaluate Step 1–7 in order (short-circuit on first match)
3. Populate `testFrameworks.recommended`, `e2eFramework.recommended`, and `coverage.recommended`
4. Generate ADR if the recommendation differs from existing setup
5. Route to the appropriate spoke command (init, generate, migrate)

The decision tree is deterministic: the same StackProfile always produces the same recommendation. This ensures reproducibility and makes the recommendation auditable via the ADR.
