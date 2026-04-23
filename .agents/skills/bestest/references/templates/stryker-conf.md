# Stryker Configuration Templates

Complete, syntactically valid Stryker mutation testing configs for two common test runner variants. Each variant is a standalone config — copy the one that matches your project's test framework.

---

## Variant 1: Vitest-Based Project

For projects using Vitest as the test runner. Stryker will use `@stryker-mutator/vitest-runner` to execute mutants.

```json5
// stryker.conf.json
{
  // Package manager for dependency resolution
  "$schema": "./node_modules/@stryker-mutator/core/schema/stryker-schema.json",
  "packageManager": "npm",

  // Test runner — Vitest integration
  "testRunner": "vitest",
  "vitest": {
    // Path to vitest config if non-standard
    "configFile": "vitest.config.ts"
  },

  // Coverage analysis speeds up mutation testing by only running
  // tests that cover the mutated code path
  "coverageAnalysis": "perTest",

  // Reporters — choose output formats
  "reporters": [
    "clear-text",     // Console output with clear formatting
    "progress",       // Progress bar during execution
    "html",           // HTML report in reports/ directory
    "dashboard"       // Optional: send results to Stryker dashboard
  ],

  // Files to mutate — target source code, not tests
  "mutate": [
    "src/**/*.ts",
    "src/**/*.tsx",
    "!src/**/*.d.ts",
    "!src/**/index.ts",
    "!src/**/types.ts",
    "!src/test/**"
  ],

  // Mutation score thresholds — enforce quality gates
  "thresholds": {
    "high": 80,    // Green: score >= 80%
    "low": 60,     // Red: score < 60%
    "break": null  // Set a number (e.g., 70) to fail CI when below
  },

  // Concurrency — adjust based on available CPU cores
  "concurrency": 4,

  // Timeout for individual test runs (milliseconds)
  "timeoutMS": 10000,

  // Timeout for test runner startup (milliseconds)
  "timeoutFactor": 1.5,

  // Clean temporary files after run
  "cleanTempFiles": true,

  // HTML report output directory
  "htmlReporter": {
    "fileName": "reports/mutation/index.html"
  },

  // Ignore specific mutations that are not meaningful
  "excludedMutations": [],

  // Disable type checking for faster mutation (optional)
  "typeCheck": false
}
```

Required devDependencies:
```
@stryker-mutator/core @stryker-mutator/vitest-runner
```

---

## Variant 2: Jest-Based Project

For projects using Jest as the test runner. Stryker will use `@stryker-mutator/jest-runner` to execute mutants.

```json5
// stryker.conf.json
{
  "$schema": "./node_modules/@stryker-mutator/core/schema/stryker-schema.json",
  "packageManager": "npm",

  // Test runner — Jest integration
  "testRunner": "jest",
  "jest": {
    // Path to Jest config if non-standard
    "configFile": "jest.config.ts",
    // Enable project-level Jest config discovery
    "projectType": "custom"
  },

  // Coverage analysis — perTest requires Jest coverage data
  "coverageAnalysis": "perTest",

  // Reporters
  "reporters": [
    "clear-text",
    "progress",
    "html",
    "dashboard"
  ],

  // Files to mutate
  "mutate": [
    "src/**/*.{ts,tsx,js,jsx}",
    "!src/**/*.{test,spec}.{ts,tsx,js,jsx}",
    "!src/**/*.d.ts",
    "!src/**/index.{ts,js}",
    "!src/**/types.ts"
  ],

  // Mutation score thresholds
  "thresholds": {
    "high": 80,
    "low": 60,
    "break": null
  },

  // Concurrency
  "concurrency": 4,

  // Timeout settings
  "timeoutMS": 10000,
  "timeoutFactor": 1.5,

  // Cleanup
  "cleanTempFiles": true,

  // HTML report output
  "htmlReporter": {
    "fileName": "reports/mutation/index.html"
  },

  // Ignore mutations that produce false positives
  "excludedMutations": [
    "StringLiteral"  // Often produces noise in log messages
  ],

  // Disable type checking for faster mutation (optional)
  "typeCheck": false
}
```

Required devDependencies:
```
@stryker-mutator/core @stryker-mutator/jest-runner
```

---

## Running Mutation Tests

```bash
# Run mutation testing (full scan)
npx stryker run

# Run with specific config file
npx stryker run stryker.conf.json

# Run mutation on a single file (faster iteration)
npx stryker run --mutate src/utils/format.ts
```

## CI Integration

Add to your CI pipeline to enforce mutation score thresholds:

```yaml
# GitHub Actions example
- name: Mutation Testing
  run: npx stryker run
  env:
    STRYKER_DASHBOARD_API_KEY: ${{ secrets.STRYKER_API_KEY }}
```

Set `"thresholds": { "break": 70 }` to fail the CI build when mutation score drops below 70%.
