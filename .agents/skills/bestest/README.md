# bestest

Enterprise-grade testing architect skill for AI coding agents. Detects your stack, recommends frameworks, generates production-quality tests, manages CI pipelines, and maintains living test documentation.

## What It Does

**bestest** is a skill for [GSD/pi](https://github.com/anthropics/gsd-pi) that turns an AI agent into a testing architect. Instead of writing individual tests by hand, you describe what you need and bestest handles strategy, scaffolding, generation, and verification.

- **Stack detection** — Identifies languages, frameworks, build tools, and existing test infrastructure from 80+ detection signals.
- **Framework recommendation** — Deterministic decision trees for JS/TS (Vitest/Jest), Python (pytest), Java (JUnit 5), and Go.
- **AI test generation** — Generates tests that compile, pass, and cover meaningful behavior. Supports unit, integration, and E2E.
- **CI pipeline generation** — Generates GitHub Actions, GitLab CI, or Jenkins pipelines with test stages.
- **Living documentation** — Auto-maintains `TESTING.md` with strategy, decisions, and coverage baselines.
- **Framework migration** — Migrates Jest→Vitest, JUnit 4→5, Cypress→Playwright.

## Installation

Copy the skill directory to your local agents path:

```bash
cp -r bestest/ ~/.agents/skills/bestest/
```

Requires GSD/pi or any agent runtime that loads skills from `~/.agents/skills/`.

## Quick Start

```
/bestest init          # First run: audit repo, scaffold test infrastructure
/bestest generate src/ # Generate tests for a directory or file
/bestest run           # Execute test suites
/bestest scan          # Deep audit of current test state
/bestest doctor        # Health check test infrastructure
```

## Supported Languages & Frameworks

| Language | Test Frameworks | Generate Spoke |
|----------|----------------|----------------|
| JavaScript / TypeScript | Vitest, Jest, Playwright | `spoke-generate.md` |
| Python | pytest, unittest | `spoke-generate-python.md` |
| Java | JUnit 5, JUnit 4 | `spoke-generate-java.md` |
| Go | testing (stdlib) | `spoke-generate-go.md` |

## Commands

| Command | Description |
|---------|-------------|
| `init` | Full audit + scaffold test infrastructure |
| `config` | View/modify `.bestest/config.yaml` |
| `scan` | Deep audit of current test state |
| `generate` | AI-generate tests for target code |
| `run` | Execute test suites with result capture |
| `fix` | Fix failing and flaky tests |
| `coverage` | Coverage gap analysis |
| `report` | Generate test reports |
| `doctor` | Health check test infrastructure |
| `expand` | Add new test types |
| `migrate` | Migrate test frameworks |
| `ci` | Generate CI pipelines |

## Architecture

bestest uses a **lean orchestrator + spoke** pattern. `SKILL.md` routes commands to language-specific reference files loaded on demand — only one spoke loads per invocation. This keeps the context window small while supporting 12 commands across 4 languages.

State lives in `.bestest/` inside the repo: version-controlled, auditable, and shareable across the team.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the spoke template guide and language-addition instructions.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## License

MIT
