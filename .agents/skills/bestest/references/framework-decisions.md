# Framework Decision Trees

<framework_decision>

## Purpose

Run the language-appropriate framework decision tree against the StackProfile to produce test framework and E2E recommendations with documented rationale.

## Language Dispatch

After the detection engine builds the StackProfile, select the decision tree based on the primary language detected:

| Primary Language | Decision Tree | Spoke File |
|-----------------|---------------|------------|
| JavaScript / TypeScript | `references/js-ts-decision-tree.md` | `references/spoke-generate.md` |
| Python | `references/python-decision-tree.md` | `references/spoke-generate-python.md` |
| Java | `references/java-decision-tree.md` | `references/spoke-generate-java.md` |
| Go | `references/go-decision-tree.md` | `references/spoke-generate-go.md` |

The primary language is determined by the first entry in `StackProfile.languages` with the highest confidence score. If multiple languages have equal confidence, prefer the language with the most source files.

## JS/TS Decision Flow

Follow the 7-step decision tree in `references/js-ts-decision-tree.md`:

1. **Vite detected?** → Recommend Vitest (native transform pipeline, 5-10x faster for TS)
2. **Next.js detected?** → Recommend Vitest (official Next.js recommendation since 2024)
3. **Existing Jest?** → Evaluate customization depth. Heavy config: keep Jest. Simple config: present migration option.
4. **Multiple unit frameworks detected?** → Flag as conflict per the detection engine (references/detection-engine.md Phase 5) category-based algorithm. Recommend Vitest as primary (preference: Vitest > Jest > Mocha). Rationale: Vitest's Jest-compatible API means existing Jest tests can run under Vitest with minimal changes; use Vitest as the primary runner and migrate incrementally. Present the conflict at the HITL gate (Phase 3) for user decision.
5. **Default** → Vitest (future-proof, Jest-compatible API, native TS)
6. **Monorepo?** → Vitest Workspace (`vitest.workspace.ts`)
7. **Frontend detected?** → Playwright for E2E. API-only → Supertest/MSW.
8. **Coverage** → V8 provider with Vitest, Istanbul with Jest.

## Python Decision Flow

Follow the 7-step decision tree in `references/python-decision-tree.md`:

1. **Existing pytest?** → Keep pytest (already optimal for Python)
2. **Existing unittest?** → Evaluate migration: pytest as runner for existing unittest tests
3. **Default** → pytest (industry standard, richest plugin ecosystem)
4. **Async detected?** → Add pytest-asyncio plugin, configure asyncio_mode
5. **Web framework?** → FastAPI → httpx, Flask → pytest-flask, Django → pytest-django
6. **HTTP endpoints?** → Integration tests via test client. Browser E2E → pytest-playwright
7. **Coverage** → pytest-cov (wraps coverage.py) with branch coverage

The decision tree is deterministic: same StackProfile always produces the same recommendation.

## Java Decision Flow

Follow the 7-step decision tree in `references/java-decision-tree.md`:

1. **Existing JUnit 5?** → Keep. Full feature set (parameterized, nested, extensions)
2. **Existing JUnit 4?** → Recommend JUnit 5 migration via JUnit Vintage Engine
3. **Multiple unit frameworks detected?** → Flag as conflict per the detection engine (references/detection-engine.md Phase 5) category-based algorithm. Recommend JUnit 5 as primary (preference: JUnit5 > JUnit4, JUnit5 > TestNG). Rationale: JUnit 5 is the modern standard; use JUnit Vintage Engine to run JUnit 4 tests under JUnit 5 for gradual migration. Present the conflict at the HITL gate (Phase 3) for user decision.
4. **Default** → JUnit 5 (modern standard, superset of JUnit 4)
5. **Spring Boot detected?** → Add @SpringBootTest layer, Mockito, Testcontainers
6. **Build tool?** → Gradle (useJUnitPlatform) vs Maven (surefire/failsafe)
7. **Mocking?** → Mockito (Java) / MockK (Kotlin)
8. **Coverage?** → JaCoCo (Gradle plugin or Maven plugin)

The decision tree is deterministic: same StackProfile always produces the same recommendation.

## Go Decision Flow

Follow the 7-step decision tree in `references/go-decision-tree.md`:

1. **Existing testify?** → Keep testify (already optimal for Go assertions)
2. **Existing plain testing.T?** → Add testify alongside (purely additive, no migration)
3. **Default** → Go testing package + testify assert/require (industry standard)
4. **HTTP framework?** → Gin → httptest + gin test mode, Echo → httptest + echo.New(), Chi → httptest + chi.Mux, stdlib → httptest, gRPC → bufconn
5. **Mocking?** → Interface fakes (Go idiom) / gomock (generated) / testify/mock (lightweight)
6. **Integration testing?** → testcontainers-go for services, httptest for HTTP, bufconn for gRPC
7. **Coverage** → go test -coverprofile (built-in, no external dependency needed)

The decision tree is deterministic: same StackProfile always produces the same recommendation.

## ADR Generation

When the recommendation differs from existing setup, generate an Architecture Decision Record in `.bestest/adrs/` using the ADR template from the relevant decision tree file. The ADR captures:

- Context (detected stack)
- Decision (recommended framework)
- Rationale (why this choice)
- Consequences (trade-offs and migration effort)
- Alternatives considered

Populate `testFrameworks.recommended`, `e2eFramework.recommended`, and `coverage.recommended` in the StackProfile.

</framework_decision>
