<div align="center">

# bestest

**Enterprise-grade testing architect for AI coding agents**

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/prajwalmishra/bestest/actions/workflows/validate-plugin.yml/badge.svg)](https://github.com/prajwalmishra/bestest/actions/workflows/validate-plugin.yml)
[![Version](https://img.shields.io/badge/version-1.4.0-brightgreen.svg)](https://github.com/prajwalmishra/bestest/blob/main/.agents/skills/bestest/CHANGELOG.md)

Detects your stack · Recommends frameworks · Generates production-quality tests · Manages CI pipelines · Maintains living documentation

</div>

---

## Features

- **Stack detection** — Identifies languages, frameworks, build tools, and existing test infrastructure from 80+ detection signals
- **Framework recommendation** — Deterministic decision trees for JS/TS (Vitest/Jest/Mocha/Jasmine), Python (pytest), Java (JUnit 5/TestNG), and Go
- **AI test generation** — Generates tests that compile, pass, and cover meaningful behavior — unit, integration, and E2E
- **CI pipeline generation** — Generates GitHub Actions, GitLab CI, or Jenkins pipelines with test stages
- **Health dashboard** — Self-contained HTML dashboard with health gauge, coverage trends, and flaky test alerts (no server, no build step)
- **Living documentation** — Auto-maintains `TESTING.md` with strategy, decisions, and coverage baselines
- **Framework migration** — Migrates Jest→Vitest, JUnit 4→5, Cypress→Playwright
- **Metrics & reporting** — JUnit XML output, structured metrics store, and coverage gap analysis

## Quick Start

```bash
# Install — copy the plugin to your agents directory
cp -r bestest/ ~/.agents/skills/bestest/
```

Then in any GSD/pi session:

```
/bestest init          # Audit repo, scaffold test infrastructure
/bestest generate src/ # Generate tests for a directory or file
/bestest run           # Execute test suites with result capture
/bestest scan          # Deep audit of current test state
/bestest doctor        # Health check test infrastructure
```

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

## Supported Languages & Frameworks

| Language | Test Frameworks | Generate Spoke |
|----------|----------------|----------------|
| JavaScript / TypeScript | Vitest, Jest, **Mocha**, **Jasmine**, Playwright | `spoke-generate.md` |
| Python | pytest, unittest | `spoke-generate-python.md` |
| Java | JUnit 5, JUnit 4, **TestNG** | `spoke-generate-java.md` |
| Go | testing (stdlib) | `spoke-generate-go.md` |

## Dashboard

The health dashboard (`dashboard.html`) is a self-contained HTML file generated inside `.bestest/`. Open it in any browser — no server or build step required.

It shows:

- **Health gauge** — Overall test health score (green/yellow/red) based on pass rates, coverage, and flaky test ratio
- **Coverage trends** — Coverage percentage over time with sparkline charts
- **Flaky test alerts** — Tests that fail intermittently with failure frequency and patterns
- **Framework status** — Per-framework pass/fail/skip breakdown

The dashboard updates automatically as a side-effect of `scan`, `run`, and `doctor` commands.

## Architecture

bestest uses a **lean orchestrator + spoke** pattern:

```
SKILL.md (orchestrator)
├── references/
│   ├── spoke-init.md          ← loaded on demand
│   ├── spoke-generate.md      ← JS/TS tests
│   ├── spoke-generate-python.md
│   ├── spoke-generate-java.md
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
│   └── spoke-config.md
└── scripts/
    └── validate-plugin.sh     ← 275+ consistency checks
```

`SKILL.md` routes commands to language-specific reference files loaded on demand — only one spoke loads per invocation. This keeps the context window small while supporting 12 commands across 4 languages.

All state lives in `.bestest/` inside the repo: version-controlled, auditable, and shareable across the team.

## Installation

Requires [GSD/pi](https://github.com/anthropics/gsd-pi) or any agent runtime that loads skills from `~/.agents/skills/`.

```bash
# Clone and install
git clone https://github.com/prajwalmishra/bestest.git
cp -r bestest/.agents/skills/bestest/ ~/.agents/skills/bestest/
```

## Documentation

- [CONTRIBUTING.md](.agents/skills/bestest/CONTRIBUTING.md) — Spoke template guide and language-addition instructions
- [CHANGELOG.md](.agents/skills/bestest/CHANGELOG.md) — Version history
- [LICENSE](LICENSE) — MIT License

## License

[MIT](LICENSE) © 2025–2026 Prajwal Mishra and contributors
