# StackProfile Schema

The StackProfile is the primary output of the detection engine. It captures the complete technology stack of a repository with confidence scores and evidence, then drives framework recommendation and command routing.

## JSON Shape

```json
{
  "schemaVersion": "1.3",
  "selectedLanguage": "string | null",
  "languages": [
    {
      "name": "string",
      "confidence": 0.0,
      "evidence": ["string"],
      "role": "string"
    }
  ],
  "runtime": {
    "node": "string | null",
    "python": "string | null",
    "jvm": "string | null",
    "go": "string | null"
  },
  "buildTool": "string | null",
  "frameworks": ["string"],
  "testFrameworks": {
    "existing": "string[] | null",
    "recommended": "string",
    "conflicts": "object | null",
    "legacyDetected": false,
    "legacyFrameworks": [],
    "inventory": {}
  },
  "brownfield": false,
  "testInventory": {},
  "existingConfig": {},
  "e2eFramework": {
    "existing": "string | null",
    "recommended": "string | null"
  },
  "ciProvider": "string | null",
  "monorepo": {
    "detected": false,
    "tool": "string | null"
  },
  "packageManager": "string | null",
  "frontend": "string | null",
  "databases": ["string"],
  "messageQueues": ["string"],
  "coverage": {
    "provider": "string | null",
    "recommended": "string"
  }
}
```

## Field Descriptions

### `schemaVersion`

| Field | Type | Description |
|-------|------|-------------|
| `schemaVersion` | string | Schema version identifier (e.g., `"1.3"`). Used to detect breaking changes to the StackProfile shape. Incremented when fields are removed or renamed; not incremented for additive changes. See `references/schema-contract.md` for the full versioning policy. |

### `selectedLanguage`

| Field | Type | Description |
|-------|------|-------------|
| `selectedLanguage` | string \| null | Language selected by user for test generation (via `--lang` flag or R10 selection prompt). Set on first generation. Null before any selection. Subsequent generate calls use this value to skip re-prompting. |

### `languages`

Array of detected programming languages, ordered by prevalence.

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Language identifier: `typescript`, `javascript`, `python`, `java`, `kotlin`, `go`, `ruby`, `rust`, `csharp`, `php` |
| `confidence` | number | 0–1 confidence score (see semantics below) |
| `evidence` | string[] | Files, fields, or patterns that triggered this detection |
| `role` | string | Classification of this language's role in the project. Values: `primary` (config at project root, multiplier 1.0), `isolated-primary` (config in subdirectory only, multiplier 1.0 for subdirectory scope / 0.7 for project scope), `secondary` (only source files in scripts/tools/examples, multiplier 0.7), `incidental` (only file-extension matches, multiplier 0.4). Set by the Context Relevance Modifier in detection-engine.md. |

### `runtime`

Detected runtime versions. Only populated for languages that have a runtime version (not compile-to targets like TypeScript). Values are version strings or `null`.

### `buildTool`

Primary build/bundler tool: `vite`, `webpack`, `turbopack`, `gradle`, `maven`, `pip`, `poetry`, `go-modules`, `cargo`, `bundler`, or `null`.

### `frameworks`

Application frameworks detected: `next.js`, `remix`, `express`, `fastify`, `django`, `fastapi`, `flask`, `spring-boot`, `gin`, `echo`, `rails`, `actix`, etc.

### `testFrameworks`

| Field | Type | Description |
|-------|------|-------------|
| `existing` | string[] \| null | Currently configured test runner(s). Always an array, even for single framework: `["vitest"]`, `["pytest"]`, `["junit5"]`, `["go_testing"]`. Multiple competing frameworks: `["vitest", "jest"]`, `["junit4", "junit5"]`. Null if none detected. Single strings were valid in schema <1.3; consumers should normalize legacy string values to a single-element array. |
| `recommended` | string | Best-fit test runner for this stack based on the decision tree |
| `conflicts` | object \| null | Populated when multi-framework conflict detected by the category-based algorithm in detection-engine.md Phase 5. Shape: `{ "type": "same-category-competing" \| "legacy-modern-coexistence", "category": "unit" \| "e2e" \| "bdd" \| "mock", "frameworks": string[], "recommendation": string, "rationale": string }`. Null when no conflict. |
| `legacyDetected` | boolean | `true` when Phase 5.5 of the detection engine finds one or more legacy test frameworks (Mocha, Jasmine, Ava, tap, node:test, Karma, nose2). Signals the init spoke to activate brownfield handling (coexist/migrate/replace). Defaults to `false`. |
| `legacyFrameworks` | array | Array of detected legacy framework objects. Each entry: `{ "name": "mocha" \| "jasmine" \| "ava" \| "tap" \| "node:test" \| "karma" \| "nose2", "confidence": number, "evidence": string[] }`. Empty when no legacy frameworks detected. |
| `inventory` | object \| null | Lightweight test inventory snapshot computed by Phase 5.5 when legacy frameworks are detected. Shape: `{ "totalFiles": number, "byPattern": { "glob_pattern": count }, "byDirectory": { "directory_path": count } }`. Used by scan/generate spokes for gap analysis. Null when no legacy frameworks detected. |

### `brownfield`

| Field | Type | Description |
|-------|------|-------------|
| `brownfield` | boolean | `true` when the init spoke is running on a brownfield repo — one with existing test infrastructure. Set when any legacy framework is detected OR when `testFrameworks.existing` contains a framework the init spoke didn't install. Defaults to `false`. This is the primary flag the init spoke checks to enter brownfield mode. |

### `testInventory`

| Field | Type | Description |
|-------|------|-------------|
| `testInventory` | object | Summary of existing test files in the repository. Computed during detection Phase 5.5 when `brownfield` is `true`. Shape: `{ "totalFiles": number, "unit": number, "integration": number, "e2e": number, "byFramework": { "framework_name": count }, "uncovered": { "estimatedPercentage": number } }`. Empty object `{}` for greenfield repos. Consumed by the scan spoke for gap analysis and the generate spoke for targeting untested code. |

### `existingConfig`

| Field | Type | Description |
|-------|------|-------------|
| `existingConfig` | object | Captures the existing test configuration that the init spoke found, so downstream spokes can understand what was already in place. Shape: `{ "frameworks": { "name": string, "configPath": string \| null, "version": string \| null }[], "scripts": { "test": string \| null, "test:watch": string \| null, "test:coverage": string \| null }, "setupFiles": string[], "transformers": string[] }`. Empty object `{}` for greenfield repos. The init spoke populates this from Phase 5.5 detections. |

### `e2eFramework`

| Field | Type | Description |
|-------|------|-------------|
| `existing` | string or null | Currently configured E2E runner: `playwright`, `cypress`, `selenium` |
| `recommended` | string or null | Recommended E2E runner (null if no frontend) |

### `ciProvider`

Detected CI platform: `github-actions`, `gitlab-ci`, `jenkins`, `circleci`, `azure-pipelines`, `bitbucket-pipelines`, or `null`.

### `monorepo`

| Field | Type | Description |
|-------|------|-------------|
| `detected` | boolean | Whether monorepo tooling was found |
| `tool` | string or null | Monorepo orchestrator: `pnpm-workspace`, `nx`, `turborepo`, `lerna`, `bazel`, `gradle-multi`, `lerna` |

### `packageManager`

Package/dependency manager: `npm`, `yarn`, `pnpm`, `pip`, `poetry`, `gradle`, `maven`, `go-modules`, `cargo`, `bundler`, or `null`.

### `frontend`

Primary frontend library/framework: `react`, `vue`, `svelte`, `solid`, `angular`, `htmx`, or `null` (server-rendered or API-only).

### `databases`

Array of detected database technologies: `postgresql`, `mysql`, `sqlite`, `mongodb`, `redis`, `elasticsearch`, `dynamodb`, etc.

### `messageQueues`

Array of detected message queue/streaming: `rabbitmq`, `kafka`, `sqs`, `redis-pubsub`, etc.

### `coverage`

| Field | Type | Description |
|-------|------|-------------|
| `provider` | string or null | Currently configured coverage tool. Valid values: `v8`, `istanbul` (JS/TS), `pytest-cov` (Python), `jacoco` (Java), `go_cover` (Go), `simplecov` (Ruby). Null if none detected. |
| `recommended` | string | Best-fit coverage tool for the recommended framework |

## Confidence Score Semantics

| Range | Meaning | Typical Evidence |
|-------|---------|-----------------|
| **> 0.9** | Direct evidence | Config file exists at expected path (e.g., `tsconfig.json` → TypeScript, `next.config.js` → Next.js) |
| **0.7–0.9** | Strong indirect evidence | Dependency listed in `package.json`, lock file present, import patterns in source files |
| **0.5–0.7** | Moderate evidence | Script commands reference the tool, CI config mentions it, indirect file references |
| **< 0.5** | Weak/inferred | File extensions present but no config, partial matches, heuristic-only |

Confidence scores are additive: multiple corroborating signals increase the score. A single high-strength signal (e.g., `next.config.js` exists) typically pushes confidence above 0.9.

## Example Outputs

### Vite + React

```json
{
  "languages": [
    { "name": "typescript", "confidence": 0.98, "evidence": ["tsconfig.json", "package.json devDependencies.typescript"] },
    { "name": "javascript", "confidence": 0.60, "evidence": ["*.js files in scripts/"] }
  ],
  "runtime": { "node": "20.x", "python": null, "jvm": null, "go": null },
  "buildTool": "vite",
  "frameworks": ["react"],
  "testFrameworks": { "existing": null, "recommended": "vitest" },
  "e2eFramework": { "existing": null, "recommended": "playwright" },
  "ciProvider": "github-actions",
  "monorepo": { "detected": false, "tool": null },
  "packageManager": "pnpm",
  "frontend": "react",
  "databases": [],
  "messageQueues": [],
  "coverage": { "provider": null, "recommended": "v8" }
}
```

### Next.js (Full-Stack)

```json
{
  "languages": [
    { "name": "typescript", "confidence": 0.98, "evidence": ["tsconfig.json", "next.config.ts"] },
    { "name": "javascript", "confidence": 0.55, "evidence": ["next.config.js fallback pattern"] }
  ],
  "runtime": { "node": "20.x", "python": null, "jvm": null, "go": null },
  "buildTool": "next",
  "frameworks": ["next.js", "react"],
  "testFrameworks": { "existing": ["jest"], "recommended": "vitest" },
  "e2eFramework": { "existing": null, "recommended": "playwright" },
  "ciProvider": "github-actions",
  "monorepo": { "detected": false, "tool": null },
  "packageManager": "npm",
  "frontend": "react",
  "databases": ["postgresql"],
  "messageQueues": [],
  "coverage": { "provider": "istanbul", "recommended": "v8" }
}
```

### Express API-Only

```json
{
  "languages": [
    { "name": "typescript", "confidence": 0.95, "evidence": ["tsconfig.json"] }
  ],
  "runtime": { "node": "18.x", "python": null, "jvm": null, "go": null },
  "buildTool": null,
  "frameworks": ["express"],
  "testFrameworks": { "existing": null, "recommended": "vitest" },
  "e2eFramework": { "existing": null, "recommended": null },
  "ciProvider": "gitlab-ci",
  "monorepo": { "detected": false, "tool": null },
  "packageManager": "yarn",
  "frontend": null,
  "databases": ["mongodb"],
  "messageQueues": ["rabbitmq"],
  "coverage": { "provider": null, "recommended": "v8" }
}
```

### pnpm Monorepo

```json
{
  "languages": [
    { "name": "typescript", "confidence": 0.98, "evidence": ["tsconfig.json", "packages/*/tsconfig.json"] },
    { "name": "python", "confidence": 0.72, "evidence": ["requirements.txt", "scripts/"] }
  ],
  "runtime": { "node": "20.x", "python": "3.12", "jvm": null, "go": null },
  "buildTool": "vite",
  "frameworks": ["react", "express"],
  "testFrameworks": { "existing": ["vitest"], "recommended": "vitest" },
  "e2eFramework": { "existing": null, "recommended": "playwright" },
  "ciProvider": "github-actions",
  "monorepo": { "detected": true, "tool": "pnpm-workspace" },
  "packageManager": "pnpm",
  "frontend": "react",
  "databases": ["postgresql"],
  "messageQueues": [],
  "coverage": { "provider": "v8", "recommended": "v8" }
}
```

### Existing Jest

```json
{
  "languages": [
    { "name": "javascript", "confidence": 0.90, "evidence": ["package.json", "*.js source files"] }
  ],
  "runtime": { "node": "18.x", "python": null, "jvm": null, "go": null },
  "buildTool": "webpack",
  "frameworks": ["react"],
  "testFrameworks": { "existing": ["jest"], "recommended": "jest" },
  "e2eFramework": { "existing": "cypress", "recommended": "playwright" },
  "ciProvider": "github-actions",
  "monorepo": { "detected": false, "tool": null },
  "packageManager": "npm",
  "frontend": "react",
  "databases": [],
  "messageQueues": [],
  "coverage": { "provider": "istanbul", "recommended": "istanbul" }
}
```

### Multi-Framework Conflict (Vitest + Jest)

```json
{
  "languages": [
    { "name": "typescript", "confidence": 0.95, "evidence": ["tsconfig.json"] }
  ],
  "runtime": { "node": "20.x", "python": null, "jvm": null, "go": null },
  "buildTool": "vite",
  "frameworks": ["react"],
  "testFrameworks": {
    "existing": ["vitest", "jest"],
    "recommended": "vitest",
    "conflicts": {
      "type": "legacy-modern-coexistence",
      "category": "unit",
      "frameworks": ["vitest", "jest"],
      "recommendation": "vitest",
      "rationale": "Vitest is the recommended primary — native TS/ESM, faster transforms, Jest-compatible API allows gradual migration."
    },
    "legacyDetected": false,
    "legacyFrameworks": [],
    "inventory": null
  },
  "brownfield": false,
  "testInventory": {},
  "existingConfig": {},
  "e2eFramework": { "existing": null, "recommended": "playwright" },
  "ciProvider": "github-actions",
  "monorepo": { "detected": false, "tool": null },
  "packageManager": "pnpm",
  "frontend": "react",
  "databases": [],
  "messageQueues": [],
  "coverage": { "provider": "v8", "recommended": "v8" }
}
```

### Brownfield (Existing Mocha)

```json
{
  "schemaVersion": "1.3",
  "selectedLanguage": null,
  "languages": [
    { "name": "javascript", "confidence": 0.92, "evidence": ["package.json", "src/**/*.js"] }
  ],
  "runtime": { "node": "18.x", "python": null, "jvm": null, "go": null },
  "buildTool": "webpack",
  "frameworks": ["express"],
  "testFrameworks": {
    "existing": ["mocha"],
    "recommended": "vitest",
    "conflicts": {
      "type": "legacy-modern-coexistence",
      "category": "unit",
      "frameworks": ["mocha", "vitest"],
      "recommendation": "vitest",
      "rationale": "Mocha is legacy; Vitest offers faster transforms, Jest-compatible API, and built-in coverage. Coexistence mode recommended for gradual migration."
    },
    "legacyDetected": true,
    "legacyFrameworks": [
      { "name": "mocha", "confidence": 0.88, "evidence": [".mocharc.yml", "devDependencies.mocha", "scripts.test references mocha"] }
    ],
    "inventory": {
      "totalFiles": 42,
      "byPattern": {
        "test/**/*.test.js": 28,
        "test/**/*.spec.js": 14
      },
      "byDirectory": {
        "test/unit": 22,
        "test/integration": 20
      }
    }
  },
  "brownfield": true,
  "testInventory": {
    "totalFiles": 42,
    "unit": 22,
    "integration": 20,
    "e2e": 0,
    "byFramework": { "mocha": 42 },
    "uncovered": { "estimatedPercentage": 65 }
  },
  "existingConfig": {
    "frameworks": [
      { "name": "mocha", "configPath": ".mocharc.yml", "version": "10.2.0" }
    ],
    "scripts": {
      "test": "mocha --recursive test/",
      "test:watch": null,
      "test:coverage": null
    },
    "setupFiles": ["test/setup.js"],
    "transformers": []
  },
  "e2eFramework": { "existing": null, "recommended": null },
  "ciProvider": "github-actions",
  "monorepo": { "detected": false, "tool": null },
  "packageManager": "npm",
  "frontend": null,
  "databases": ["mongodb"],
  "messageQueues": [],
  "coverage": { "provider": null, "recommended": "v8" }
}
```

### Python + FastAPI

```json
{
  "languages": [
    { "name": "python", "confidence": 0.97, "evidence": ["pyproject.toml", "requirements.txt"] }
  ],
  "runtime": { "node": null, "python": "3.12", "jvm": null, "go": null },
  "buildTool": "pip",
  "frameworks": ["fastapi"],
  "testFrameworks": { "existing": null, "recommended": "pytest" },
  "e2eFramework": { "existing": null, "recommended": null },
  "ciProvider": "github-actions",
  "monorepo": { "detected": false, "tool": null },
  "packageManager": "pip",
  "frontend": null,
  "databases": ["postgresql"],
  "messageQueues": [],
  "coverage": { "provider": null, "recommended": "pytest-cov" }
}
```

### Java + Spring Boot

```json
{
  "languages": [
    { "name": "java", "confidence": 0.97, "evidence": ["pom.xml", "src/main/java"] }
  ],
  "runtime": { "node": null, "python": null, "jvm": "17", "go": null },
  "buildTool": "maven",
  "frameworks": ["spring-boot"],
  "testFrameworks": { "existing": ["junit5"], "recommended": "junit5" },
  "e2eFramework": { "existing": null, "recommended": null },
  "ciProvider": "github-actions",
  "monorepo": { "detected": false, "tool": null },
  "packageManager": "maven",
  "frontend": null,
  "databases": ["postgresql"],
  "messageQueues": [],
  "coverage": { "provider": null, "recommended": "jacoco" }
}
```

### Go + Gin

```json
{
  "languages": [
    { "name": "go", "confidence": 0.98, "evidence": ["go.mod", "main.go"] }
  ],
  "runtime": { "node": null, "python": null, "jvm": null, "go": "1.22" },
  "buildTool": "go-modules",
  "frameworks": ["gin"],
  "testFrameworks": { "existing": ["go_testing"], "recommended": "go_testing" },
  "e2eFramework": { "existing": null, "recommended": null },
  "ciProvider": "github-actions",
  "monorepo": { "detected": false, "tool": null },
  "packageManager": "go-modules",
  "frontend": null,
  "databases": ["postgresql"],
  "messageQueues": [],
  "coverage": { "provider": null, "recommended": "go_cover" }
}
```

### Polyglot Monorepo (Node.js + Go)

```json
{
  "schemaVersion": "1.3",
  "selectedLanguage": "typescript",
  "languages": [
    { "name": "typescript", "confidence": 0.98, "evidence": ["package.json", "tsconfig.json", "next.config.ts"], "role": "primary" },
    { "name": "javascript", "confidence": 0.55, "evidence": ["*.js files in scripts/"], "role": "secondary" },
    { "name": "go", "confidence": 0.665, "evidence": ["microservice/go.mod", "microservice/main.go"], "role": "isolated-primary" }
  ],
  "runtime": { "node": "20.x", "python": null, "jvm": null, "go": "1.22" },
  "buildTool": "next",
  "frameworks": ["next.js", "react", "gin"],
  "testFrameworks": { "existing": ["vitest"], "recommended": "vitest" },
  "e2eFramework": { "existing": null, "recommended": "playwright" },
  "ciProvider": "github-actions",
  "monorepo": { "detected": true, "tool": "pnpm-workspace" },
  "packageManager": "pnpm",
  "frontend": "react",
  "databases": ["postgresql"],
  "messageQueues": ["rabbitmq"],
  "coverage": { "provider": "v8", "recommended": "v8" }
}
```

Node.js is primary (config at project root, confidence 0.98). Go is isolated-primary — its `go.mod` exists only in `microservice/`, so the raw confidence of 0.95 is scaled by the 0.7 project-scope multiplier to yield 0.665. Downstream spokes use the `role` field to route correctly: primary languages drive the top-level test framework recommendation, while isolated-primary languages receive their own test configuration scoped to their subdirectory.

---

## Cross-Reference

- Schema contract: `references/schema-contract.md` (versioning policy)
- Config schema: `references/config-schema.md` (coverage.target field)
- Metrics store: `references/metrics-schema.md` (coverage trends, module breakdown, run history)
- Directory schema: `references/dot-bestest-schema.md` (file lifecycle and spoke matrices)
- Detection engine: `references/detection-engine.md` (how StackProfile fields are populated)
