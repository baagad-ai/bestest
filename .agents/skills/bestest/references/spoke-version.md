# /bestest version

## Purpose

Display bestest version, skill location, and environment information. The `version` command is a read-only terminal spoke that works unconditionally — no `.bestest/` directory or configuration is required.

Use `/bestest version` to verify the installed version, locate the skill files, and check the runtime environment.

## Prerequisites

- **None** — The version spoke is always available regardless of project state.

## Pre-Flight Checks

No pre-flight checks required. The version spoke must not fail under any circumstances.

> See **references/pre-flight-protocol.md** for the standard 3-step `.bestest/` validation pattern and spoke-specific variants.

---

## Workflow

### Step 1: Display version header

```
─── bestest version ───
```

### Step 2: Read skill metadata

Read the SKILL.md frontmatter from the skill directory:

```
Read ~/.agents/skills/bestest/SKILL.md
Extract frontmatter fields:
  name: "bestest"
  version: "{version from frontmatter}"
  description: "{description from frontmatter}"
```

### Step 3: Display version information

```
  Name:         bestest
  Version:      {version}
  Description:  {description}
```

### Step 4: Display skill location

```
  Skill directory:  ~/.agents/skills/bestest/
  SKILL.md:         ~/.agents/skills/bestest/SKILL.md
  References:       ~/.agents/skills/bestest/references/
```

### Step 5: Display reference file count

```
Count files in references/ directory:
  total = number of .md files in references/

  Spoke files:       {count of spoke-*.md files}
  Detection files:   {count of *-decision-tree.md, detection-*.md files}
  Schema files:      {count of *-schema.md files}
  Template files:    {count of files in references/templates/}
  Generation guides: {count of ai-generation-guide*.md files}
  Other references:  {remaining files}

  Total: {total} reference files
```

### Step 6: Display project context (if available)

```
If .bestest/config.yaml exists and is valid YAML:
  Parse config
  Print: ""
  Print: "─── Project Context ───"
  Print: ""
  Print: "  Framework:  {config.framework}"
  Print: "  Language:   {config.language}"
  Print: "  Config:     .bestest/config.yaml"
  Print: "  Last scan:  {config.state.last_scan or 'never'}"
  Print: "  Last run:   {config.state.last_run or 'never'}"
  Print: "  Last doctor:{config.state.last_doctor or 'never'}"
Else:
  Print: ""
  Print: "  No .bestest/ directory found (run /bestest init to set up)"
```

### Step 7: Display environment information

```
Print: ""
Print: "─── Environment ───"
Print: ""
Print: "  Working directory: {cwd}"
Print: "  Node.js:           {node --version or 'not found'}"
Print: "  Python:            {python3 --version or 'not found'}"
Print: "  Java:              {java --version (first line) or 'not found'}"
Print: "  Go:                {go version or 'not found'}"
```

### Step 8: Display footer

```
Print: ""
Print: "Run /bestest help for available commands."
```

---

## Error Handling

### 1. SKILL.md cannot be read

**Trigger**: The skill directory or SKILL.md is missing or unreadable.

**Response**:
```
Warning: Could not read SKILL.md from ~/.agents/skills/bestest/
Version information may be incomplete.

Name:    bestest
Version: (unknown — SKILL.md not found)
```
Continue with available information. Do not exit.

### 2. Frontmatter parsing fails

**Trigger**: SKILL.md exists but the YAML frontmatter is malformed.

**Response**:
```
Warning: Could not parse SKILL.md frontmatter.
Displaying file information without version metadata.
```
Continue without version number. Display the raw SKILL.md path.

### 3. Corrupted config.yaml during project context

**Trigger**: `.bestest/config.yaml` exists but contains invalid YAML.

**Response**:
```
  Config: .bestest/config.yaml (invalid YAML — run /bestest config validate)
```
Continue with remaining output. Do not exit.

### 4. Environment detection failures

**Trigger**: One or more language runtimes are not installed.

**Response**:
```
  Node.js:  not found
  Python:   Python 3.12.4
  Java:     not found
  Go:       go version go1.22.0 linux/amd64
```
Display "not found" for missing runtimes. Do not exit — missing runtimes are expected in single-language projects.

---

## Downstream Reference

### Input Data Contracts

| Source | Fields Used | Purpose |
|--------|------------|---------|
| `SKILL.md` frontmatter | `name`, `version`, `description` | Version display |
| `config.yaml` (optional) | `framework`, `language`, `state.*` | Project context display |

### Output Data Contracts

The version spoke produces only console output — no files are written.

### Spoke Relationships

```
spoke-version → reads SKILL.md frontmatter and optionally config.yaml
spoke-help → provides command reference (cross-linked)
spoke-init → creates .bestest/ that version reads for project context
spoke-config → manages config.yaml that version displays
```

### See Also

- `SKILL.md` — Source of version metadata
- `references/config-schema.md` — Config field definitions
