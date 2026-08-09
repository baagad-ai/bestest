# Contributing to bestest

Thank you for contributing to **bestest**, the enterprise-grade testing architect skill. This guide covers the two most common contribution paths: adding a new command spoke and adding support for a new programming language.

---

## General Principles

- **Reference files are loaded on demand.** SKILL.md lists them in the `reference_index` but only loads the spoke needed for the current command. Keep spokes self-contained.
- **Schema versions must be bumped** when the JSON shape of `stack-profile-schema.md` or `scan-report-schema.md` changes. Add the new version to CHANGELOG.md.
- **All file paths are relative to the skill root directory** (wherever bestest is installed). Never use absolute paths in spoke references.

---

## Adding a New Command Spoke

Use this template when creating a new spoke file (e.g., `references/spoke-<command>.md`).

### Spoke Template

```markdown
# <Command> Spoke

Invoked by: `/bestest <command> [args]`

## Purpose

<One-sentence description of what this spoke does.>

## Preconditions

- `.bestest/` directory exists (run `init` first if not).
- <Any other requirements — e.g., "StackProfile loaded", "test framework configured">

## Steps

### Step 1: <Step Title>

<What to do, what to read, what to produce.>

### Step 2: <Step Title>

<Continue for each step.>

## Output

- `<file path>` — <description of the file produced>
- <Any in-terminal output or side effects>

## Error Handling

| Condition | Action |
|-----------|--------|
| <error condition> | <what to do — print message, exit, fallback> |

## Cross-References

- Reads: `<related file>` — <why>
- Writes: `<related file>` — <why>
- Used by: `<other spoke or SKILL.md section>` — <why>
```

### Registration Checklist

After writing the spoke file:

1. **Add to the routing table** in SKILL.md's `<routing>` section — add a row to the Command Routing table with the command name, spoke file path, and purpose.
2. **Add to the reference_index** in SKILL.md — add a row to the "Command Spokes (Load on Demand)" table.
3. **Update reference-index.md** — add the new spoke file to the file catalog table in `references/reference-index.md` with a description.
4. **Add to the Quick Reference** in SKILL.md — add a row to the Command Quick Reference table if the command has user-facing arguments.
5. **Update version** — bump `version` in SKILL.md frontmatter and add a CHANGELOG.md entry.

---

## Adding a New Language

When adding support for a new programming language (e.g., Rust, Ruby, C#):

### 1. Create a Decision Tree

Create `references/<language>-decision-tree.md` following the 7-step structure used by existing decision trees:

1. **Existing Framework?** — Check for configured test runners.
2. **Project Type** — Library, web app, API, CLI, etc.
3. **Ecosystem Compatibility** — Which frameworks integrate with the detected build tool.
4. **Feature Requirements** — Async, snapshot, parallel, coverage.
5. **Team Preferences** — Config files, assertion style.
6. **Performance Characteristics** — Speed, isolation model.
7. **Recommendation** — Final pick with ADR template.

### 2. Create a Generate Spoke

Create `references/spoke-generate-<language>.md` following the pattern of existing generate spokes:

- Language-specific import patterns
- Framework-specific test templates
- Language-appropriate assertion styles
- Build/run commands for verification

### 3. Update Detection Engine

In `references/detection-engine.md`, add detection signals for the new language:

- File extensions and naming conventions
- Config file patterns (e.g., `Cargo.toml` for Rust, `.gemspec` for Ruby)
- Dependency file entries
- Build tool identification

### 4. Update Routing

In SKILL.md `<routing>` section:

1. Add a row to the language-aware routing table mapping the language to the new generate spoke.
2. Add the mapping in the Language Detection section.
3. Add the language to the "Unsupported language" error message list.

### 5. Update Schemas

- In `stack-profile-schema.md`, add the language to the `name` field description if not already listed.
- Add example outputs for the new language following the existing pattern.

### 6. Registration Checklist

- [ ] Decision tree file created: `references/<language>-decision-tree.md`
- [ ] Generate spoke created: `references/spoke-generate-<language>.md`
- [ ] **Create generation sub-files** — Create the 6 required pipeline sub-files in `references/generate/<lang>/`:
  - `phase1-target-detail.md` — Target selection heuristics and path validation
  - `phase4-generation-detail.md` — Language-specific test generation patterns and mocking
  - `phase5-compilation.md` — Compilation verification with auto-fix
  - `phase6-execution.md` — Execution verification with fix-and-rerun loop
  - `phase7-quality-audit.md` — Quality scoring rubric and flakiness testing
  - `error-handling.md` — Language-specific error scenarios
  
  Use an existing language's sub-files (e.g., `references/generate/python/`) as a template.
- [ ] Detection signals added to `references/detection-engine.md`
- [ ] Language added to routing table in SKILL.md
- [ ] Language added to reference_index in SKILL.md
- [ ] reference-index.md updated with new spoke file and language sub-files
- [ ] pipeline-shared.md sections reviewed for language-specific applicability (e.g., HITL Gate Core, Downstream Reference Core, Metrics Update Core)
- [ ] Add a run-report companion fixture to `scripts/fixtures/` for the new language (see `scripts/fixtures/run-report-companion.json`) and re-run `scripts/validate-contracts.sh`
- [ ] CLI smoke test: run `python3 <skill-dir>/scripts/bestest-cli.py detect` on a representative project of the new language
- [ ] StackProfile schema updated with language identifier
- [ ] Version bumped in SKILL.md frontmatter
- [ ] CHANGELOG.md entry added

---

## Style Conventions

- **Markdown tables** for structured data (field descriptions, error handling, routing).
- **Fenced code blocks** with `json` or `typescript` language tags for all code examples.
- **Relative paths** — always reference files relative to the skill root directory.
- **Self-contained spokes** — each spoke file must work when loaded alone, without needing other spoke files.

---

## Testing Your Changes

Validate changes using the built-in validation scripts:

1. **Run `scripts/validate-plugin.sh`** — automated checks covering file structure, cross-references, schema compliance, and content completeness.
2. **Run `scripts/validate-skill.sh`** — automated consistency checks across 9 validation domains.
3. **Run `scripts/validate-contracts.sh`** — golden-fixture contract checks (C001–C030) verifying every spoke's documented read/write fields exist in `scripts/fixtures/`. When you add a new report type or change a report field, update the corresponding fixture and re-run this.
4. **Routing consistency** — Every spoke in the routing table should appear in the reference_index and vice versa.
5. **Schema validation** — Ensure example JSON in schema docs is valid JSON.
6. **Dry run** — Invoke `/bestest <your-command>` in a test repo and verify the spoke loads and produces expected output.
7. **CLI changes** — If you modify `scripts/bestest-cli.py`, run `python3 -m py_compile scripts/bestest-cli.py` and smoke-test affected subcommands against a fixture repo (see `references/bestest-cli.md`).

---

## Project Structure

```
bestest/
├── SKILL.md                          # Orchestrator — command routing, principles, reference index
├── README.md                         # Skill documentation
├── CONTRIBUTING.md                   # This file
├── CHANGELOG.md                      # Version history
│
├── references/                       # Spokes & schema files (loaded on demand)
│   ├── spoke-init.md
│   ├── spoke-generate.md             # JS/TS (Vitest, Jest, Mocha, Jasmine, Playwright)
│   ├── spoke-generate-python.md
│   ├── spoke-generate-java.md        # JUnit 5, TestNG
│   ├── spoke-generate-go.md
│   ├── spoke-run.md
│   ├── spoke-fix.md
│   ├── spoke-scan.md
│   ├── spoke-coverage.md
│   ├── spoke-doctor.md
│   ├── spoke-ci.md
│   ├── spoke-migrate.md
│   ├── spoke-report.md
│   ├── spoke-expand.md
│   ├── spoke-config.md
│   ├── spoke-help.md                 # Help UX spoke
│   ├── spoke-explain.md              # Explain UX spoke
│   ├── spoke-status.md               # Status UX spoke
│   ├── spoke-version.md              # Version UX spoke
│   ├── detection-engine.md
│   ├── detection-signals.md
│   ├── parallel-dispatch.md          # Parallel dispatch protocol for multi-worker generation
│   ├── pre-flight-protocol.md        # Pre-flight checks before generation
│   ├── quick_reference.md            # Quick reference card
│   ├── stack-profile-schema.md
│   ├── scan-report-schema.md
│   ├── config-schema.md              # Configuration schema
│   ├── dot-bestest-schema.md         # .bestest directory schema
│   ├── metrics-schema.md             # metrics.json specification
│   ├── schema-contract.md            # Schema versioning contract
│   ├── error-codes.md                # Error code reference
│   ├── context7-helper.md            # Context7 integration helper
│   ├── js-ts-decision-tree.md        # JavaScript/TypeScript decision tree
│   ├── python-decision-tree.md       # Python decision tree
│   ├── java-decision-tree.md         # Java decision tree
│   ├── go-decision-tree.md           # Go decision tree
│   ├── anti-patterns.md
│   ├── ci-patterns.md
│   ├── framework-decisions.md
│   ├── migration-rules.md
│   ├── ai-generation-guide.md
│   ├── python-generation-guide.md
│   ├── go-generation-guide.md
│   │
│   ├── generate/                     # Generate phase detail files (on-demand)
│   │
│   └── templates/                    # Config templates & dashboard
│       ├── config-vitest.yaml
│       ├── config-jest.yaml
│       ├── config-pytest.yaml
│       ├── config-junit5.yaml
│       ├── config-go.yaml
│       ├── config-monorepo.yaml
│       ├── dashboard.html            # Self-contained health dashboard
│       └── ...
│
└── scripts/
    ├── validate-plugin.sh            # integrity checks
    ├── validate-skill.sh             # consistency checks
    ├── validate-contracts.sh         # golden-fixture contract checks (C001–C030)
    ├── bestest                       # thin wrapper → bestest-cli.py
    ├── bestest-cli.py                # deterministic helper layer (detect/config/report/lock/metrics/render/contracts)
    ├── fixtures/                     # golden JSON fixtures for contract validation
    │   ├── stack-profile.json
    │   ├── scan-report.json
    │   ├── run-report.json
    │   ├── run-report-companion.json
    │   ├── doctor-report.json
    │   ├── coverage-report.json
    │   ├── metrics.json
    │   └── config.yaml
    └── validate-to-junit.sh          # JUnit XML conversion for CI
```
