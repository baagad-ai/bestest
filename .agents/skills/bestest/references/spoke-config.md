# /bestest config

## Purpose

View and modify the `.bestest/config.yaml` test configuration. This spoke is loaded when the user runs `/bestest config` with an optional sub-command. It supports displaying current configuration, setting individual values with schema-enforced validation, validating the entire config file for correctness, and resetting to framework defaults.

## Prerequisites

- `.bestest/` directory must exist — if missing, suggest the user run `/bestest init` first
- `config.yaml` must be present inside `.bestest/` and be valid YAML — if missing, suggest `/bestest init`
- `config-schema.md` is the authoritative source for all field definitions, types, valid values, ranges, and defaults
- StackProfile in `.bestest/state/stack-profile.json` provides context for smart defaults during reset

## Sub-command Parsing

Parse the first argument after `config` to determine the action:

| Sub-command | Args | Action |
|-------------|------|--------|
| `show` | (none) or `<key>` | Display configuration — default if no sub-command given |
| `set` | `<key> <value>` | Update a single configuration value |
| `validate` | (none) | Check config.yaml against the schema for errors |
| `reset` | (none) | Restore config.yaml to framework defaults |

If no sub-command is provided, default to `show`.

If an unrecognized sub-command is provided, display the table above with valid sub-commands and exit.

---

## Workflow: show

Display the current configuration from `.bestest/config.yaml`.

### Steps

1. Read `.bestest/config.yaml`. If missing, report error (see Error Handling #2).
2. Parse YAML into structured key-value pairs. If invalid YAML, report error (see Error Handling #3).
3. If a dot-path key argument was provided (e.g. `coverage.target`, `vitest.environment`):
   a. Navigate the parsed config to the specified field
   b. Display the field name, current value, and its description from config-schema.md
   c. If the key does not exist in the config, report "Field not found" and list valid keys in that section
4. If no key argument, display the full configuration organized by section:

### Display Format (full config)

```
## Configuration (.bestest/config.yaml)

### Core
  framework: vitest
  language: typescript
  version: "1.0"

### Coverage
  enabled: true
  target: 80
  provider: v8
  reporters: [text, html, json-summary]

### Paths
  test: "src/**/*.{test,spec}.{ts,tsx}"
  src: "src/**/*.{ts,tsx}"
  ignore: ["**/node_modules/**", "**/dist/**", "**/.bestest/**"]

### E2E
  enabled: true
  framework: playwright

### CI
  enabled: true
  provider: github-actions

### Vitest
  config_path: vitest.config.ts
  globals: false
  environment: jsdom
  setup_files: []
  include: ["src/**/*.{test,spec}.{ts,tsx}"]

### Jest
  (inactive — framework is vitest)

### pytest
  (inactive — framework is vitest)

### junit5
  (inactive — framework is vitest)

### Go
  (inactive — framework is vitest)

### Monorepo
  enabled: false

### Generation
  quality_threshold: 0.7
  verify_compilation: true
  verify_pass: true
  max_retries: 2

### State (read-only)
  last_scan: 2025-04-18T10:30:00Z
  last_generate: null
  version: "1.0"
```

5. For inactive framework blocks (any block not matching the current `framework` value), display "(inactive — framework is <current>)" instead of the block's fields. For example, when framework is vitest, display `(inactive)` for jest, pytest, junit5, and go blocks. When framework is pytest, display `(inactive)` for vitest, jest, junit5, and go blocks.

### Output

- Displayed configuration to the user
- No files modified

---

## Workflow: set

Update a single configuration value in `.bestest/config.yaml` with full validation.

### Steps

1. Parse the two required arguments: `<key>` and `<value>`. If either is missing, report usage: `bestest config set <key> <value>` and exit.

2. **Validate key exists in schema.** Parse `<key>` as a dot-path (e.g. `coverage.target`, `vitest.environment`, `framework`). Look up the key in the validation rules reference below. If the key is unknown:
   - Display: `Unknown config key: "<key>"`
   - List all valid keys grouped by section:
     ```
     Valid keys:
       Core: framework, language, version
       Coverage: coverage.enabled, coverage.target, coverage.provider, coverage.reporters
       Paths: paths.test, paths.src, paths.ignore
       E2E: e2e.enabled, e2e.framework
       CI: ci.enabled, ci.provider
       Vitest: vitest.config_path, vitest.globals, vitest.environment, vitest.setup_files, vitest.include
       Jest: jest.config_path, jest.transform, jest.environment, jest.module_name_mapper
       pytest: pytest.config_path, pytest.asyncio_mode, pytest.plugins, pytest.addopts, pytest.markers, pytest.testpaths
       JUnit5: junit5.build_tool, junit5.test_src_dir, junit5.main_src_dir, junit5.dependency_management, junit5.coverage_provider, junit5.use_junit_platform, junit5.test_annotations, junit5.parallel_execution, junit5.java_version
       Go: go.module_path, go.go_version, go.test_timeout, go.race_detection, go.verbose, go.cover_mode, go.build_tags, go.test_packages, go.testify.enabled, go.testify.packages, go.testify.suite, go.testify.mock, go.mocking_strategy, go.http_framework, go.parallel, go.fuzz
       Monorepo: monorepo.enabled, monorepo.tool, monorepo.packages
       Generation: generation.quality_threshold, generation.verify_compilation, generation.verify_pass, generation.max_retries
     ```
   - Exit without modifying config.

3. **Reject state.* keys.** If the key starts with `state.`, display:
   ```
   Cannot set "<key>" — state fields are read-only.
   State is managed automatically by bestest commands (scan, generate, etc.).
   ```
   Exit without modifying config.

4. **Validate value type and range** against the schema. The validation rules are:

   - **String fields**: Accept any non-empty string. For enum fields (see table below), reject values not in the valid set and display valid options.
   - **Number fields**: Parse as number. Reject non-numeric values. Check range constraints (e.g. coverage.target 0–100, generation.quality_threshold 0–1, generation.max_retries 0–5).
   - **Boolean fields**: Accept `true`, `false` (case-insensitive). Also accept `"yes"/"no"` and `"1"/"0"` as aliases.
   - **Array fields** (coverage.reporters, paths.ignore, vitest.setup_files, vitest.include, monorepo.packages, pytest.plugins, pytest.addopts, pytest.markers, pytest.testpaths, go.build_tags, go.test_packages, go.testify.packages, junit5.test_annotations): Accept comma-separated values. Split on comma, trim whitespace. Validate each element against element-type rules if applicable (e.g. coverage.reporters elements must be valid for the active framework — JS/TS: `text`, `html`, `json-summary`, `json`, `lcov`; Python: `term-missing`, `html`, `json`, `xml`, `lcov`, `annotate`; Java: `xml`, `html`, `csv`; Go: `func`, `html`; pytest.asyncio_mode must be one of: `auto`, `strict`, `off`; go.cover_mode must be one of: `set`, `count`, `atomic`).
   - **Object fields** (jest.module_name_mapper): Accept JSON string (e.g. `'{"@/*":"src/*"}'`). Parse and validate as key-value pairs.

   On type/range mismatch, display:
   ```
   Invalid value for <key>: <value>
   Expected: <type> (e.g. <examples>)
   Valid values: <enum or range>
   ```
   Exit without modifying config.

5. **Cross-field dependency: framework switch.** If the key being set is `framework` and the value differs from the current value:
   - Determine the language implied by the new framework:
     - `vitest` → `typescript` (or `javascript`)
     - `jest` → `typescript` (or `javascript`)
     - `pytest` → `python`
     - `junit5` → `java`
     - `go_testing` → `go`
   - Display a warning:
     ```
     ⚠️  Switching framework from <current> to <new>.
     This will change the language from <current_lang> to <new_lang>.
     The <current>-specific block will become inactive and the <new>-specific block will activate.
     This changes which config fields are used at runtime.
     Proceed? (y/n)
     ```
   - If confirmed, also update the `language` field to match the new framework's implied language.
   - Wait for user confirmation before proceeding. If declined, exit without changes.

6. **Read and update config.yaml:**
   a. Read `.bestest/config.yaml`
   b. Parse YAML
   c. Navigate to the target key using dot-path
   d. Update the value
   e. Reconstruct the YAML file, preserving the original structure, comments, and layout as much as possible. Use the existing file as a formatting guide. If comments cannot be preserved exactly, prioritize correctness over comment retention.
   f. Write the updated YAML back to `.bestest/config.yaml`

7. **Post-update notice.** If `coverage.target` or `framework` was changed, display:
   ```
   Note: TESTING.md may need updating to reflect this change.
   Run /bestest scan to regenerate affected sections.
   ```

### Output

```
✅ Updated <key> = <value>
Config saved to .bestest/config.yaml
```

---

## Workflow: validate

Check the entire `.bestest/config.yaml` against the schema and report all errors found.

### Steps

1. Read `.bestest/config.yaml`. If missing, report error (see Error Handling #2).
2. Parse YAML. If invalid YAML, report parse error with line number (see Error Handling #3).
3. **Check every field against the schema** — collect ALL errors, do not fail on the first:
   a. **Required fields**: `framework` must be present and be one of `vitest`, `jest`, `pytest`, `junit5`, `go_testing`.
   b. **Schema version check**: If `version` field is present, compare against the spoke's known version. If the MAJOR component differs, report: `"Config version {version} is not recognized. This version of bestest supports config version 1.x. Update bestest or regenerate config with /bestest init."` If the MINOR component is higher than known, report a warning: `"Config version {version} is newer than bestest expects. Some fields may not be validated."`
   c. **Type checks**: Each field must match its declared type (string, number, boolean, array, object).
   d. **Enum checks**: Fields with valid-value constraints must have values in the allowed set.
   e. **Range checks**: Numeric fields must be within declared ranges.
   f. **Framework consistency**: If `framework` is `vitest`, the `vitest.*` block should have values and all other framework-specific blocks (`jest.*`, `pytest.*`, `junit5.*`, `go.*`) should be empty or `{}`. The same pattern applies for each framework — only the active block should have values, all others should be empty. Report if the active block is empty or any inactive block has values.
   g. **Language consistency**: The `language` field should match the framework — `vitest`/`jest` implies `javascript` or `typescript`, `pytest` implies `python`, `junit5` implies `java`, `go_testing` implies `go`. Report if language and framework are inconsistent (e.g., `framework: pytest` with `language: java`).
   h. **Read-only check**: `state.*` fields should not have been manually edited (compare against expected structure — `state.last_scan`, `state.last_generate`, `state.last_run`, `state.last_doctor`, `state.version`).

4. **Report results:**

   If errors were found:
   ```
   ❌ Config validation failed — <N> error(s) found:

   1. framework: required field missing
   2. coverage.target: expected number, got string "abc"
   3. vitest.environment: invalid value "chrome", must be one of: node, jsdom, happy-dom
   4. jest.config_path: non-empty jest block found but framework is vitest
   5. language: value "java" is inconsistent with framework "pytest" (expected "python")

   Fix these errors with: /bestest config set <key> <value>
   Or reset to defaults: /bestest config reset
   ```

   If no errors:
   ```
   ✅ Config validation passed — all fields valid.
   ```

### Output

- Validation report with pass/fail status and error list (if any)
- No files modified

---

## Workflow: reset

Reset `.bestest/config.yaml` to the framework's default template while preserving runtime state.

### Steps

1. Read current `.bestest/config.yaml`. If missing, report error (see Error Handling #2) — cannot determine which template to use.
2. **Determine the template to use:**
   a. Read `framework` value from the current config. If missing or unknown, report error (see Error Handling #9).
   b. Read `monorepo.enabled` value. If `true`, use `config-monorepo.yaml` template regardless of framework.
   c. Otherwise, use the framework-specific template:
     - `config-vitest.yaml` for `framework: vitest`
     - `config-jest.yaml` for `framework: jest`
     - `config-pytest.yaml` for `framework: pytest`
     - `config-junit5.yaml` for `framework: junit5`
     - `config-go.yaml` for `framework: go_testing`
3. **Load the template** from `references/templates/<template-name>`.
4. **Resolve {{variable}} placeholders** using current project state:
   - `{{project_name}}` — from `package.json` "name" field, `pyproject.toml` "name", or directory name
   - `{{detected_stack_summary}}` — from StackProfile summary, or "Unknown stack"
   - `{{language}}` — implied from framework (vitest→typescript, pytest→python, junit5→java, go_testing→go)
   - `{{coverage_target}}` — use current `coverage.target` value (preserve user's target)
   - `{{paths_test}}` — use current `paths.test` value
   - `{{paths_src}}` — use current `paths.src` value
   - `{{e2e_enabled}}` — use current `e2e.enabled` value
   - `{{e2e_framework}}` — use current `e2e.framework` value, or `null`
   - `{{ci_enabled}}` — use current `ci.enabled` value
   - `{{ci_provider}}` — use current `ci.provider` value, or `null`
   - **Vitest-specific**: `{{vitest_environment}}`, `{{vitest_setup_files}}` — use current vitest.* values or detect from StackProfile
   - **Jest-specific**: `{{jest_config_path}}`, `{{jest_transform}}`, `{{jest_environment}}`, `{{jest_module_name_mapper}}` — use current jest.* values or defaults
   - **pytest-specific**: `{{pytest_config_path}}` — use current value or `"pyproject.toml"`, `{{pytest_asyncio_mode}}` — use current value or `"strict"`, `{{pytest_plugins}}` — use current value or `[]`, `{{pytest_testpaths}}` — use current value or `["tests"]`
   - **JUnit5-specific**: `{{junit5_build_tool}}` — use current value or `"gradle"`, `{{junit5_java_version}}` — use current value or auto-detect from build.gradle sourceCompatibility, `{{junit5_test_src_dir}}` — use current value or `"src/test/java"`, `{{junit5_main_src_dir}}` — use current value or `"src/main/java"`
   - **Go-specific**: `{{go_module_path}}` — auto-detect from go.mod `module` directive, `{{go_go_version}}` — auto-detect from go.mod `go` directive, `{{go_http_framework}}` — detect from go.mod imports (gin, echo, chi, grpc), `{{go_mocking_strategy}}` — use current value or `"interface_fakes"`
   - `{{monorepo_tool}}` — from StackProfile monorepo detection, or current `monorepo.tool`
   - `{{monorepo_packages}}` — use current `monorepo.packages` value, or `["packages/*"]`
5. **Preserve runtime state.** After resolving the template, copy over the current `state.*` block values (last_scan, last_generate) so that reset does not lose scan/generate history.
6. **Overwrite `.bestest/config.yaml`** with the resolved template content.
7. **Report what was reset:**
   ```
   ✅ Config reset to defaults using <template-name> template.
   
   Preserved from previous config:
     - coverage.target: 80
     - paths.test: "src/**/*.{test,spec}.{ts,tsx}"
     - paths.src: "src/**/*.{ts,tsx}"
     - state.last_scan: 2025-04-18T10:30:00Z
   
   Reset to defaults:
     - All other fields restored to framework defaults
     - Comments and structure regenerated from template
   ```

### Output

- Reset confirmation with template used
- Updated `config.yaml` with preserved user values and runtime state

---

## Validation Rules Reference

This section provides the complete validation table for all config fields, derived from `config-schema.md`. Use this as the authoritative reference when validating keys and values in the `set` and `validate` workflows.

### Core Fields

| Field | Type | Required | Valid Values | Default | Read-Only |
|-------|------|----------|--------------|---------|-----------|
| `framework` | string | **Yes** | `vitest`, `jest`, `pytest`, `junit5`, `go_testing` | — | No |
| `language` | string | No | `javascript`, `typescript`, `python`, `java`, `go` | auto-detected | No |
| `version` | string | No | `"1.0"` | `"1.0"` | Yes (managed by bestest) |

### coverage.*

| Field | Type | Valid Values / Range | Default | Read-Only |
|-------|------|---------------------|---------|-----------|
| `coverage.enabled` | boolean | `true`, `false` | `true` | No |
| `coverage.target` | number | 0–100 | `80` | No |
| `coverage.provider` | string | `v8`, `istanbul`, `pytest-cov`, `jacoco`, `go_cover` | `v8` (vitest), `istanbul` (jest), `pytest-cov` (pytest), `jacoco` (junit5), `go_cover` (go_testing) | No |
| `coverage.reporters` | string[] | elements: `text`, `html`, `json-summary`, `json`, `lcov` (JS/TS); `term-missing`, `html`, `json`, `xml`, `lcov`, `annotate` (Python); `xml`, `html`, `csv` (Java); `func`, `html` (Go) | `["text", "html", "json-summary"]` (JS/TS), `["term-missing", "html", "json"]` (pytest), `["xml", "html"]` (junit5), `["func", "html"]` (go_testing) | No |

### paths.*

| Field | Type | Default | Read-Only |
|-------|------|---------|-----------|
| `paths.test` | string | `"src/**/*.{test,spec}.{ts,tsx}"` | No |
| `paths.src` | string | `"src/**/*.{ts,tsx}"` | No |
| `paths.ignore` | string[] | `["**/node_modules/**", "**/dist/**", "**/.bestest/**"]` | No |

### e2e.*

| Field | Type | Valid Values | Default | Read-Only |
|-------|------|-------------|---------|-----------|
| `e2e.enabled` | boolean | `true`, `false` | `false` | No |
| `e2e.framework` | string or null | `playwright`, `cypress`, `null` | `null` | No |

### ci.*

| Field | Type | Valid Values | Default | Read-Only |
|-------|------|-------------|---------|-----------|
| `ci.enabled` | boolean | `true`, `false` | `false` | No |
| `ci.provider` | string or null | `github-actions`, `gitlab-ci`, `jenkins`, `circleci`, `null` | `null` | No |

### vitest.*

Only active when `framework: vitest`.

| Field | Type | Valid Values | Default | Read-Only |
|-------|------|-------------|---------|-----------|
| `vitest.config_path` | string | Any file path | `"vitest.config.ts"` | No |
| `vitest.globals` | boolean | `true`, `false` | `false` | No |
| `vitest.environment` | string | `node`, `jsdom`, `happy-dom` | `"jsdom"` | No |
| `vitest.setup_files` | string[] | File paths | `[]` | No |
| `vitest.include` | string[] | Glob patterns | `["src/**/*.{test,spec}.{ts,tsx}"]` | No |

### jest.*

Only active when `framework: jest`.

| Field | Type | Valid Values | Default | Read-Only |
|-------|------|-------------|---------|-----------|
| `jest.config_path` | string | Any file path | `"jest.config.ts"` | No |
| `jest.transform` | string | `swc`, `babel`, `ts-jest` | `"swc"` | No |
| `jest.environment` | string | `node`, `jsdom` | `"jsdom"` | No |
| `jest.module_name_mapper` | object | Path alias mapping | `{}` | No |

### pytest.*

Only active when `framework: pytest`.

| Field | Type | Valid Values | Default | Read-Only |
|-------|------|-------------|---------|-----------|
| `pytest.config_path` | string | Any file path | `"pyproject.toml"` | No |
| `pytest.asyncio_mode` | string | `auto`, `strict`, `off` | `"strict"` | No |
| `pytest.plugins` | string[] | pytest plugin names | `[]` | No |
| `pytest.addopts` | string[] | Any pytest CLI flags | `["--strict-markers", "--tb=short"]` | No |
| `pytest.markers` | string[] | Custom marker names | `[]` | No |
| `pytest.testpaths` | string[] | Directory paths | `["tests"]` | No |

### junit5.*

Only active when `framework: junit5`.

| Field | Type | Valid Values | Default | Read-Only |
|-------|------|-------------|---------|-----------|
| `junit5.build_tool` | string | `gradle`, `maven` | `"gradle"` | No |
| `junit5.test_src_dir` | string | Any directory path | `"src/test/java"` | No |
| `junit5.main_src_dir` | string | Any directory path | `"src/main/java"` | No |
| `junit5.dependency_management` | string | `gradle`, `maven` | `"gradle"` | No |
| `junit5.coverage_provider` | string | `jacoco` | `"jacoco"` | No |
| `junit5.use_junit_platform` | boolean | `true`, `false` | `true` | No |
| `junit5.test_annotations` | string[] | JUnit 5 annotations | `["@Test", "@ParameterizedTest", "@Nested"]` | No |
| `junit5.parallel_execution` | boolean | `true`, `false` | `false` | No |
| `junit5.java_version` | string | Java version strings | auto-detected (`"17"`) | No |

### go.*

Only active when `framework: go_testing`.

| Field | Type | Valid Values | Default | Read-Only |
|-------|------|-------------|---------|-----------|
| `go.module_path` | string | Go module path | auto-detected | No |
| `go.go_version` | string | Go version strings | auto-detected (`"1.22"`) | No |
| `go.test_timeout` | string | Go duration strings | `"5m"` | No |
| `go.race_detection` | boolean | `true`, `false` | `true` | No |
| `go.verbose` | boolean | `true`, `false` | `true` | No |
| `go.cover_mode` | string | `set`, `count`, `atomic` | `"atomic"` | No |
| `go.build_tags` | string[] | Go build tags | `[]` | No |
| `go.test_packages` | string[] | Go package patterns | `["./..."]` | No |
| `go.testify.enabled` | boolean | `true`, `false` | `true` | No |
| `go.testify.packages` | string[] | `assert`, `require`, `mock`, `suite` | `["assert", "require"]` | No |
| `go.testify.suite` | boolean | `true`, `false` | `false` | No |
| `go.testify.mock` | boolean | `true`, `false` | `false` | No |
| `go.mocking_strategy` | string | `interface_fakes`, `testify_mock`, `gomock` | `"interface_fakes"` | No |
| `go.http_framework` | string | `none`, `stdlib`, `gin`, `echo`, `chi`, `grpc` | `"none"` | No |
| `go.parallel` | boolean | `true`, `false` | `true` | No |
| `go.fuzz` | boolean | `true`, `false` | `false` | No |

### monorepo.*

| Field | Type | Valid Values | Default | Read-Only |
|-------|------|-------------|---------|-----------|
| `monorepo.enabled` | boolean | `true`, `false` | `false` | No |
| `monorepo.tool` | string or null | `pnpm-workspace`, `nx`, `turborepo`, `lerna`, `null` | `null` | No |
| `monorepo.packages` | string[] | Glob patterns or paths | `[]` | No |

### generation.*

| Field | Type | Valid Values / Range | Default | Read-Only |
|-------|------|---------------------|---------|-----------|
| `generation.quality_threshold` | number | 0–1 | `0.7` | No |
| `generation.verify_compilation` | boolean | `true`, `false` | `true` | No |
| `generation.verify_pass` | boolean | `true`, `false` | `true` | No |
| `generation.max_retries` | number | 0–5 | `2` | No |

### state.*

**All state fields are read-only.** These are managed automatically by bestest commands.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `state.last_scan` | string or null | `null` | ISO 8601 timestamp of last scan |
| `state.last_generate` | string or null | `null` | ISO 8601 timestamp of last generate |
| `state.last_run` | string or null | `null` | ISO 8601 timestamp of last run |
| `state.last_doctor` | string or null | `null` | ISO 8601 timestamp of last doctor |
| `state.version` | string | `"1.0"` | Config schema version |

---

## Error Handling

Cover these scenarios in order of likelihood:

### 1. `.bestest/` directory missing

```
❌ .bestest/ directory not found.
   Run /bestest init first to set up test infrastructure.
```

Exit. Do not attempt to create the directory.

### 2. `config.yaml` missing inside `.bestest/`

```
❌ .bestest/config.yaml not found.
   Run /bestest init first to generate a config file.
```

Exit. Do not attempt to create the file.

### 3. `config.yaml` contains invalid YAML

```
❌ Failed to parse .bestest/config.yaml: YAML syntax error at line 14.
   Error: <raw error message>

   Fix the syntax error manually, or reset to defaults with:
   /bestest config reset
```

Report the line number if available from the YAML parser. Suggest manual fix or `config reset`.

### 4. Unknown key in `set` command

```
❌ Unknown config key: "<key>"
   
   Valid keys by section:
     Core: framework, language, version
     Coverage: coverage.enabled, coverage.target, coverage.provider, coverage.reporters
     Paths: paths.test, paths.src, paths.ignore
     E2E: e2e.enabled, e2e.framework
     CI: ci.enabled, ci.provider
     Vitest: vitest.config_path, vitest.globals, vitest.environment, vitest.setup_files, vitest.include
     Jest: jest.config_path, jest.transform, jest.environment, jest.module_name_mapper
     pytest: pytest.config_path, pytest.asyncio_mode, pytest.plugins, pytest.addopts, pytest.markers, pytest.testpaths
     JUnit5: junit5.build_tool, junit5.test_src_dir, junit5.main_src_dir, junit5.dependency_management, junit5.coverage_provider, junit5.use_junit_platform, junit5.test_annotations, junit5.parallel_execution, junit5.java_version
     Go: go.module_path, go.go_version, go.test_timeout, go.race_detection, go.verbose, go.cover_mode, go.build_tags, go.test_packages, go.testify.enabled, go.testify.packages, go.testify.suite, go.testify.mock, go.mocking_strategy, go.http_framework, go.parallel, go.fuzz
     Monorepo: monorepo.enabled, monorepo.tool, monorepo.packages
     Generation: generation.quality_threshold, generation.verify_compilation, generation.verify_pass, generation.max_retries
```

Exit without modifying config.

### 5. Invalid value type for key

```
❌ Invalid value for <key>: <value>
   Expected: <type> (e.g. <examples>)
   
   Examples:
     coverage.target: 80          (number, 0-100)
     vitest.globals: true         (boolean)
     e2e.framework: playwright    (string: playwright, cypress, null)
     coverage.reporters: text,html,json-summary  (comma-separated)
```

Show the expected format with concrete examples from the same field type.

### 6. Value out of valid range

```
❌ Value out of range for <key>: <value>
   Valid range: <min>–<max>
   Current value: <current>
```

Show the valid range and current value for context.

### 7. Attempt to set a state.* key

```
❌ Cannot set "<key>" — state fields are read-only.
   State is managed automatically by bestest commands:
     - state.last_scan: updated by /bestest scan
     - state.last_generate: updated by /bestest generate
     - state.last_run: updated by /bestest run
     - state.last_doctor: updated by /bestest doctor
     - state.version: managed by bestest internally
```

Exit without modifying config.

### 8. Framework switch warning

When `set framework <new>` is called and `<new>` differs from the current value:

```
⚠️  Switching framework from <current> to <new>.
   This will change the language from <current_lang> to <new_lang>.
   The <current>-specific block will become inactive:
     <current>.<relevant_fields>
   The <new>-specific block will activate with defaults:
     <new>.<relevant_fields>

   Proceed with framework switch? (y/n)
```

Cross-language switch examples:
- `vitest` → `pytest`: Language changes from typescript to python. The vitest block deactivates, pytest block activates.
- `junit5` → `go_testing`: Language changes from java to go. The junit5 block deactivates, go block activates.
- `jest` → `vitest`: Language stays typescript. The jest block deactivates, vitest block activates.

Require explicit user confirmation. If declined, exit without changes.

### 9. Reset with no existing framework value

```
❌ Cannot reset — framework value not found in current config.
   Cannot determine which template to use.
   
   Set framework first with: /bestest config set framework vitest
   Or run /bestest init to generate a complete config.
```

Exit. Do not guess a template.

---

## Output Specification

| Sub-command | Output |
|-------------|--------|
| `show` | Displayed configuration organized by section, with inactive framework block noted |
| `show <key>` | Single field name, value, and description from schema |
| `set <key> <value>` | Confirmation: `✅ Updated <key> = <value>` + optional TESTING.md notice |
| `validate` | `✅ Config validation passed` or `❌ Config validation failed — N error(s)` with numbered list |
| `reset` | Confirmation with template used, preserved values listed, and reset scope described |

---

## Downstream

- The `scan` spoke reads config.yaml for paths, coverage settings, and framework to determine analysis scope — supports Python/Java/Go framework branches
- The `generate` spoke reads config.yaml for generation.* settings, framework, language, and paths — routes to language-specific generation spokes
- The `run` spoke reads config.yaml for framework to determine which test runner to invoke — supports pytest, Gradle/Maven (junit5), and go test
- The `coverage` spoke reads config.yaml for coverage targets and framework to determine coverage parsing strategy — supports pytest-cov, JaCoCo, and go_cover
- Changes to `framework`, `language`, `coverage.target`, or `paths.*` may require TESTING.md regeneration (handled by scan)
