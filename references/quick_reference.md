# Quick Reference

> On-demand reference for StackProfile examples, command quick reference, and ADR template.
> Load when generating ADRs or handling unknown/no-command scenarios.

## StackProfile JSON Example

```json
{
  "languages": [
    { "name": "typescript", "confidence": 0.98, "evidence": ["tsconfig.json", "next.config.ts"] }
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

## Command Quick Reference

| Command | What It Does | Key Args |
|---------|-------------|----------|
| `init` | Full audit + scaffold test infrastructure | — |
| `config` | View/modify test configuration | `show`, `set <key> <val>`, `validate`, `reset` |
| `scan` | Audit current test state | — |
| `generate` | AI-generate tests for target code | `<path>`, `--untested`, `--type <kind>`, `--critical` |
| `run` | Execute test suites | `unit`, `integration`, `e2e`, `all`, `--affected` |
| `fix` | Fix failing/flaky tests | `--flaky`, `<test-path>` |
| `coverage` | Coverage gap analysis | — |
| `report` | Generate test reports | — |
| `doctor` | Health check test infrastructure | — |
| `expand` | Add new test types | — |
| `migrate` | Migrate test frameworks | `<from> <to>` |
| `ci` | Generate CI pipelines | `github-actions`, `gitlab-ci`, `jenkins` |

## ADR Template

```markdown
# ADR-NNN: [Test Framework Selection]

## Status: Proposed

## Context
- **Languages**: [from StackProfile]
- **Build tool**: [from StackProfile]
- **Frameworks**: [from StackProfile]
- **Existing test framework**: [from StackProfile or "none"]

## Decision
Adopt **[framework]** for [unit/integration/E2E] testing.

## Rationale
[From decision tree path]

## Consequences
- [Specific benefit]
- [Trade-off]
- [Migration effort if applicable]

## Alternatives Considered
- **[Alternative]**: [Why not chosen]
```
