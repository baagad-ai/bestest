# Contributing to bestest

Thank you for contributing to **bestest**, the enterprise-grade testing architect skill. This guide covers the two most common contribution paths: adding a new command spoke and adding support for a new programming language.

---

## General Principles

- **Reference files are loaded on demand.** SKILL.md lists them in the `reference_index` but only loads the spoke needed for the current command. Keep spokes self-contained.
- **Schema versions must be bumped** when the JSON shape of `stack-profile-schema.md` or `scan-report-schema.md` changes. Add the new version to CHANGELOG.md.
- **All file paths are relative to `~/.agents/skills/bestest/`.** Never use absolute paths in spoke references.

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
3. **Add to the Quick Reference** in SKILL.md — add a row to the Command Quick Reference table if the command has user-facing arguments.
4. **Update version** — bump `version` in SKILL.md frontmatter and add a CHANGELOG.md entry.

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
- [ ] Detection signals added to `references/detection-engine.md`
- [ ] Language added to routing table in SKILL.md
- [ ] Language added to reference_index in SKILL.md
- [ ] StackProfile schema updated with language identifier
- [ ] Version bumped in SKILL.md frontmatter
- [ ] CHANGELOG.md entry added

---

## Style Conventions

- **Markdown tables** for structured data (field descriptions, error handling, routing).
- **Fenced code blocks** with `json` or `typescript` language tags for all code examples.
- **Relative paths** — always reference files relative to `~/.agents/skills/bestest/`.
- **Self-contained spokes** — each spoke file must work when loaded alone, without needing other spoke files.

---

## Testing Your Changes

There is no automated test suite for the skill itself. Validate changes by:

1. **Grep checks** — Verify all referenced files exist: `grep -o 'references/[a-z0-9-]*.md' SKILL.md | sort -u | while read f; do test -f "$HOME/.agents/skills/bestest/$f" && echo "OK $f" || echo "MISSING $f"; done`
2. **Routing consistency** — Every spoke in the routing table should appear in the reference_index and vice versa.
3. **Schema validation** — Ensure example JSON in schema docs is valid JSON.
4. **Dry run** — Invoke `/bestest <your-command>` in a test repo and verify the spoke loads and produces expected output.

---

## Project Structure

```
.agents/skills/bestest/
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
│   ├── js-ts-generation-guide.md
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
    ├── validate-skill.sh             # 288+ automated consistency checks
    └── verify-m005-s05.sh            # S05 verification script
```
