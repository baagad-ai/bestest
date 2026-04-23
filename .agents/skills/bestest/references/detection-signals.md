# Detection Signals Catalog

Comprehensive catalog of all signals the detection engine checks to build a StackProfile. Signals are organized by category. Each signal lists what to check, what it indicates, and its strength.

## Signal Strength Definitions

| Strength | Weight | Description |
|----------|--------|-------------|
| **high** | `0.40` | Definitive proof: config file at expected path, explicit dependency |
| **medium** | `0.20` | Strong indicator: lock file, script command, workspace config |
| **low** | `0.08` | Supporting evidence: file extension, import pattern, heuristic |

Multiple signals compound via noisy-OR: `confidence = min(0.99, 1 - Π(1 - w_i))`. Each additional signal increases confidence with diminishing returns. See the Confidence Scoring Algorithm section in `references/detection-engine.md` for the full formula and rules.

---

## Language Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `tsconfig.json` exists | File existence check | TypeScript | high (0.40) |
| `*.ts`, `*.tsx` source files | Glob for `src/**/*.{ts,tsx}` | TypeScript | high (0.40) |
| `package.json` exists | File existence check | JavaScript/TypeScript ecosystem | high (0.40) |
| `*.js`, `*.jsx` source files | Glob for `src/**/*.{js,jsx}` | JavaScript | medium (0.20) |
| `requirements.txt` exists | File existence check | Python | high (0.40) |
| `pyproject.toml` exists | File existence check | Python | high (0.40) |
| `setup.py` exists | File existence check | Python | high (0.40) |
| `*.py` source files | Glob for `**/*.py` | Python | medium (0.20) |
| `go.mod` exists | File existence check | Go | high (0.40) |
| `*.go` source files | Glob for `**/*.go` | Go | medium (0.20) |
| `pom.xml` exists | File existence check | Java/Maven | high (0.40) |
| `build.gradle` or `build.gradle.kts` exists | File existence check | Java/Kotlin/Gradle | high (0.40) |
| `*.java` source files | Glob for `src/**/*.java` | Java | medium (0.20) |
| `*.kt` source files | Glob for `src/**/*.kt` | Kotlin | medium (0.20) |
| `Gemfile` exists | File existence check | Ruby | high (0.40) |
| `*.rb` source files | Glob for `**/*.rb` | Ruby | medium (0.20) |
| `Cargo.toml` exists | File existence check | Rust | high (0.40) |
| `*.rs` source files | Glob for `src/**/*.rs` | Rust | medium (0.20) |
| `*.csproj` exists | Glob for `**/*.csproj` | C# / .NET | high (0.40) |

## Runtime Version Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `.nvmrc` or `.node-version` | Read file content | Node version | high (0.40) |
| `"engines"` field in `package.json` | Parse JSON field | Node version constraint | high (0.40) |
| `actions/setup-node` with `node-version` | Parse YAML in `.github/workflows/*.yml` | Node CI version | medium (0.20) |
| `.python-version` or `runtime.txt` | Read file content | Python version | high (0.40) |
| `requires-python` in `pyproject.toml` | Parse TOML field | Python version constraint | high (0.40) |
| `go.mod` `go` directive | Parse first line of go.mod | Go version | high (0.40) |
| `sourceCompatibility` in `build.gradle` | Parse Gradle field | JVM target version | medium (0.20) |
| `java.version` in `pom.xml` | Parse XML field | JVM source version | medium (0.20) |
| `JAVA_HOME` environment variable | Check env var | Java runtime installation path | medium (0.20) |
| `java -version` output | Parse command output (first line, version pattern) | Installed Java major version | high (0.40) |

## Build Tool Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `vite.config.*` exists | Glob for `vite.config.{ts,js,mjs}` | Vite bundler | high (0.40) |
| `"vite"` in `package.json` devDependencies | Parse JSON field | Vite dependency | high (0.40) |
| `webpack.config.*` exists | Glob for `webpack.config.{ts,js}` | Webpack bundler | high (0.40) |
| `"webpack"` in `package.json` devDependencies | Parse JSON field | Webpack dependency | high (0.40) |
| `next.config.*` exists | Glob for `next.config.{ts,js,mjs}` | Next.js (acts as build tool) | high (0.40) |
| `build.gradle` or `build.gradle.kts` exists | File existence check | Gradle build tool | high (0.40) |
| `gradlew` exists | File existence check | Gradle wrapper (confirms Gradle project) | medium (0.20) |
| `build.gradle.kts` exists (Kotlin DSL) | File existence check | Gradle with Kotlin DSL (type-safe config) | high (0.40) |
| `pom.xml` exists | File existence check | Maven build tool | high (0.40) |
| `mvnw` exists | File existence check | Maven wrapper (confirms Maven project) | medium (0.20) |
| `Makefile` exists | File existence check | Make-based builds | medium (0.20) |
| `turbo.json` exists | File existence check | Turborepo build orchestrator | high (0.40) |

## Framework Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `next.config.*` exists | Glob for config file | Next.js framework | high (0.40) |
| `"next"` in `package.json` dependencies | Parse JSON field | Next.js framework | high (0.40) |
| `remix.config.*` exists | Glob for config file | Remix framework | high (0.40) |
| `"@remix-run/react"` in dependencies | Parse JSON field | Remix framework | high (0.40) |
| `"express"` in `package.json` dependencies | Parse JSON field | Express framework | high (0.40) |
| `"fastify"` in `package.json` dependencies | Parse JSON field | Fastify framework | high (0.40) |
| `"@nestjs/core"` in dependencies | Parse JSON field | NestJS framework | high (0.40) |
| `"react"` in `package.json` dependencies | Parse JSON field | React library | high (0.40) |
| `"vue"` in `package.json` dependencies | Parse JSON field | Vue library | high (0.40) |
| `"svelte"` in `package.json` devDependencies | Parse JSON field | Svelte framework | high (0.40) |
| `"solid-js"` in `package.json` dependencies | Parse JSON field | SolidJS library | high (0.40) |
| `"@angular/core"` in dependencies | Parse JSON field | Angular framework | high (0.40) |
| `"django"` in `requirements.txt` or `pyproject.toml` | Parse dependency list | Django framework | high (0.40) |
| `"fastapi"` in `requirements.txt` or `pyproject.toml` | Parse dependency list | FastAPI framework | high (0.40) |
| `"flask"` in `requirements.txt` or `pyproject.toml` | Parse dependency list | Flask framework | high (0.40) |
| `"spring-boot"` in `build.gradle` or `pom.xml` | Parse build file | Spring Boot framework | high (0.40) |
| `@SpringBootApplication` in `*.java` source | Grep for annotation | Spring Boot application class | high (0.40) |
| `"spring-boot-starter-*"` in `build.gradle` or `pom.xml` | Parse build file dependencies | Spring Boot starter dependencies (web, data-jpa, etc.) | high (0.40) |
| `"spring-boot-starter-webflux"` in dependencies | Parse build file | Spring WebFlux (reactive) | high (0.40) |
| `"gin-gonic/gin"` in `go.mod` | Parse go.mod require | Gin framework (Go) | high (0.40) |
| `"labstack/echo"` in `go.mod` | Parse go.mod require | Echo framework (Go) | high (0.40) |

## Test Framework Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `vitest.config.*` exists | Glob for `vitest.config.{ts,js}` | Vitest test runner | high (0.40) |
| `"vitest"` in `package.json` devDependencies | Parse JSON field | Vitest dependency | high (0.40) |
| `vitest.workspace.*` exists | Glob for `vitest.workspace.{ts,js}` | Vitest workspace mode | high (0.40) |
| `"test"` script references `vitest` | Parse `scripts.test` in `package.json` | Vitest is the test runner | medium (0.20) |
| `jest.config.*` exists | Glob for `jest.config.{ts,js,cjs,mjs}` | Jest test runner | high (0.40) |
| `"jest"` in `package.json` devDependencies | Parse JSON field | Jest dependency | high (0.40) |
| `"test"` script references `jest` | Parse `scripts.test` in `package.json` | Jest is the test runner | medium (0.20) |
| `"@swc/jest"` in devDependencies | Parse JSON field | SWC-accelerated Jest | medium (0.20) |
| `pytest.ini` or `pyproject.toml` `[tool.pytest` | File/config existence | pytest test runner | high (0.40) |
| `"pytest"` in `requirements.txt` or `pyproject.toml` | Parse dependency list | pytest dependency | high (0.40) |
| `conftest.py` files exist | Glob for `**/conftest.py` | pytest is in use | medium (0.20) |
| `unittest` imports in `*.py` test files | Grep for `import unittest` | Python unittest usage | low (0.08) |
| `build.gradle` has `useJUnitPlatform()` | Parse Gradle test block | JUnit 5 test runner | high (0.40) |
| `pom.xml` has `junit-jupiter` dependency | Parse XML dependencies | JUnit 5 test runner | high (0.40) |
| `pom.xml` has `junit` (non-jupiter) dependency | Parse XML dependencies | JUnit 4 test runner | high (0.40) |
| `@Test` annotation in `src/test/java/**/*.java` | Grep for JUnit test annotation | JUnit test files present | medium (0.20) |
| `@ExtendWith` annotation in test files | Grep for JUnit 5 extension usage | JUnit 5 extensions in use | medium (0.20) |
| `"mockito-core"` in `build.gradle` or `pom.xml` | Parse build file dependencies | Mockito mocking framework | high (0.40) |
| `"mockito-junit-jupiter"` in dependencies | Parse build file dependencies | Mockito JUnit 5 integration | medium (0.20) |
| `"org.mockito"` imports in test files | Grep for Mockito usage | Mockito is actively used | medium (0.20) |
| `*_test.go` files exist | Glob for `**/*_test.go` | Go testing in use | high (0.40) |
| `"github.com/stretchr/testify"` in `go.mod` | Parse go.mod require | testify assertions | medium (0.20) |

## E2E Test Framework Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `playwright.config.*` exists | Glob for `playwright.config.{ts,js}` | Playwright E2E | high (0.40) |
| `"@playwright/test"` in devDependencies | Parse JSON field | Playwright dependency | high (0.40) |
| `cypress.config.*` exists | Glob for `cypress.config.{ts,js}` | Cypress E2E | high (0.40) |
| `"cypress"` in devDependencies | Parse JSON field | Cypress dependency | high (0.40) |
| `cypress/` directory exists | Directory existence check | Cypress E2E setup | medium (0.20) |
| `"pytest-playwright"` in requirements | Parse dependency list | pytest-playwright E2E | high (0.40) |
| `"selenium"` in dependencies | Parse dependency list | Selenium E2E | high (0.40) |

## CI Provider Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `.github/workflows/` directory exists | Directory existence check | GitHub Actions | high (0.40) |
| `.github/workflows/*.yml` files | Glob for YAML files | GitHub Actions configured | high (0.40) |
| `.gitlab-ci.yml` exists | File existence check | GitLab CI | high (0.40) |
| `Jenkinsfile` exists | File existence check | Jenkins | high (0.40) |
| `.circleci/` directory exists | Directory existence check | CircleCI | high (0.40) |
| `.circleci/config.yml` exists | File existence check | CircleCI configured | high (0.40) |
| `azure-pipelines.yml` exists | File existence check | Azure Pipelines | high (0.40) |
| `bitbucket-pipelines.yml` exists | File existence check | Bitbucket Pipelines | high (0.40) |

## Monorepo Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `pnpm-workspace.yaml` exists | File existence check | pnpm workspace monorepo | high (0.40) |
| `"workspaces"` field in root `package.json` | Parse JSON field | npm/yarn workspaces | high (0.40) |
| `nx.json` exists | File existence check | Nx monorepo | high (0.40) |
| `"nx"` in devDependencies | Parse JSON field | Nx monorepo tool | high (0.40) |
| `turbo.json` exists | File existence check | Turborepo monorepo | high (0.40) |
| `"turbo"` in devDependencies | Parse JSON field | Turborepo tool | high (0.40) |
| `lerna.json` exists | File existence check | Lerna monorepo | high (0.40) |
| `bazel` workspace files (`WORKSPACE`, `BUILD.bazel`) | File existence check | Bazel monorepo | high (0.40) |
| `settings.gradle` with multiple `include` | Parse Gradle settings | Gradle multi-module | high (0.40) |
| Multiple `package.json` in subdirectories | Glob for `packages/*/package.json` | Likely monorepo structure | medium (0.20) |
| `apps/` and `packages/` directories exist | Directory existence check | Monorepo convention | low (0.08) |

## Package Manager Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `pnpm-lock.yaml` exists | File existence check | pnpm package manager | high (0.40) |
| `yarn.lock` exists | File existence check | yarn package manager | high (0.40) |
| `package-lock.json` exists | File existence check | npm package manager | high (0.40) |
| `bun.lockb` exists | File existence check | bun package manager | high (0.40) |
| `"packageManager"` field in `package.json` | Parse JSON field | Explicit PM declaration (Corepack) | high (0.40) |
| `poetry.lock` exists | File existence check | Poetry package manager (Python) | high (0.40) |
| `Pipfile.lock` exists | File existence check | Pipenv package manager (Python) | medium (0.20) |
| `uv.lock` exists | File existence check | uv package manager (Python) | high (0.40) |
| `go.sum` exists | File existence check | Go modules | high (0.40) |

## Frontend Library Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `"react"` in dependencies | Parse JSON field | React | high (0.40) |
| `"react-dom"` in dependencies | Parse JSON field | React with DOM rendering | high (0.40) |
| `"@vitejs/plugin-react"` in devDependencies | Parse JSON field | React + Vite integration | medium (0.20) |
| `"vue"` in dependencies | Parse JSON field | Vue | high (0.40) |
| `"@vitejs/plugin-vue"` in devDependencies | Parse JSON field | Vue + Vite integration | medium (0.20) |
| `"svelte"` in devDependencies | Parse JSON field | Svelte | high (0.40) |
| `"@sveltejs/vite-plugin-svelte"` in devDependencies | Parse JSON field | Svelte + Vite | medium (0.20) |
| `"solid-js"` in dependencies | Parse JSON field | SolidJS | high (0.40) |
| `"vite-plugin-solid"` in devDependencies | Parse JSON field | SolidJS + Vite | medium (0.20) |
| `"@angular/core"` in dependencies | Parse JSON field | Angular | high (0.40) |
| `"htmx"` or `"htmx.org"` in dependencies | Parse JSON field | HTMX | medium (0.20) |
| No frontend library detected + no `src/` patterns | Absence of all above signals | Server-rendered or API-only | low (0.08) |

## Database Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `"pg"` or `"@neondatabase/serverless"` in dependencies | Parse JSON field | PostgreSQL | high (0.40) |
| `"mysql2"` in dependencies | Parse JSON field | MySQL | high (0.40) |
| `"better-sqlite3"` or `"sqlite3"` in dependencies | Parse JSON field | SQLite | high (0.40) |
| `"mongodb"` or `"mongoose"` in dependencies | Parse JSON field | MongoDB | high (0.40) |
| `"ioredis"` or `"redis"` in dependencies | Parse JSON field | Redis | high (0.40) |
| `"@elastic/elasticsearch"` in dependencies | Parse JSON field | Elasticsearch | high (0.40) |
| `"@aws-sdk/client-dynamodb"` in dependencies | Parse JSON field | DynamoDB | high (0.40) |
| `"prisma"` or `"@prisma/client"` in dependencies | Parse JSON field | Prisma ORM (detect underlying DB from `schema.prisma`) | high (0.40) |
| `"drizzle-orm"` in dependencies | Parse JSON field | Drizzle ORM | high (0.40) |
| `"sqlalchemy"` in requirements | Parse dependency list | SQLAlchemy (Python, detect DB from connection strings) | medium (0.20) |
| `"django"` + DB backend in `settings.py` | Parse Django config | Django DB backend | medium (0.20) |
| `docker-compose.yml` with database services | Parse YAML services | Database in Docker stack | medium (0.20) |
| `"testcontainers"` in dependencies (any language) | Parse dependency list | Testcontainers (integration test DB) | medium (0.20) |

## Message Queue Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `"amqplib"` or `"rabbitmq"` in dependencies | Parse JSON field | RabbitMQ | high (0.40) |
| `"kafkajs"` or `"@confluentinc/kafka-javascript"` in dependencies | Parse JSON field | Kafka | high (0.40) |
| `"@aws-sdk/client-sqs"` in dependencies | Parse JSON field | AWS SQS | high (0.40) |
| `"bull"` or `"bullmq"` in dependencies | Parse JSON field | Redis-based job queue (Bull) | medium (0.20) |
| `"celery"` in requirements | Parse dependency list | Celery task queue (Python) | high (0.40) |

## Coverage Tool Detection

| Signal | Check | Indicates | Strength |
|--------|-------|-----------|----------|
| `"@vitest/coverage-v8"` in devDependencies | Parse JSON field | V8 coverage provider | high (0.40) |
| `"@vitest/coverage-istanbul"` in devDependencies | Parse JSON field | Istanbul coverage (Vitest) | high (0.40) |
| `"istanbul"` or `"nyc"` in devDependencies | Parse JSON field | Istanbul/NYC coverage | high (0.40) |
| `"pytest-cov"` in requirements | Parse dependency list | pytest coverage plugin | high (0.40) |
| `"coverage.py"` or `"coverage"` in requirements | Parse dependency list | Python coverage.py | high (0.40) |
| `"jacoco"` in `build.gradle` or `pom.xml` plugins | Parse build file | JaCoCo coverage (Java) | high (0.40) |
| `jacoco` Gradle plugin applied | Parse Gradle plugins block | JaCoCo via Gradle plugin | high (0.40) |
| `jacoco-maven-plugin` in `pom.xml` | Parse XML plugin configuration | JaCoCo via Maven plugin | high (0.40) |
| `"go test -cover"` in scripts or Makefile | Grep for cover flags | Go built-in coverage | medium (0.20) |

## Detection Order

Signals should be checked in this order for optimal performance:

1. **Language** — determines which subsequent checks are relevant
2. **Package manager** — lock files are quick file-existence checks
3. **Build tool** — config files are quick file-existence checks
4. **Framework** — requires parsing `package.json` or equivalent
5. **Test framework** — requires parsing `package.json` or equivalent
6. **E2E framework** — requires parsing `package.json` or equivalent
7. **CI provider** — directory/file existence checks
8. **Monorepo** — directory/file existence checks
9. **Frontend** — requires parsing dependencies
10. **Database** — requires parsing dependencies
11. **Message queues** — requires parsing dependencies
12. **Coverage** — requires parsing dependencies

Early termination: if no `package.json`, `requirements.txt`, `pyproject.toml`, `go.mod`, `pom.xml`, or `build.gradle` is found, the repository is likely not a supported ecosystem.
