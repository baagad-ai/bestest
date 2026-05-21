<div align="center">

# 🧪 bestest

**The testing architect for AI coding agents**

[![CI](https://github.com/baagad-ai/bestest/actions/workflows/validate-plugin.yml/badge.svg)](https://github.com/baagad-ai/bestest/actions/workflows/validate-plugin.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.4.0-brightgreen.svg)](CHANGELOG.md)

**Detect your stack · Pick the right framework · Generate tests that actually work · Ship with confidence**

[Getting Started](#getting-started) · [Commands](#commands) · [How It Works](#how-it-works) · [Supported Languages](#supported-languages) · [Contributing](CONTRIBUTING.md)

</div>

---

## What is bestest?

bestest is an AI-native testing skill that architects your entire testing layer — not just generates a test file and hopes for the best.

It's a **100+ file, ~40K-line specification** that lives inside your AI coding agent and handles strategy, framework selection, test generation, CI pipelines, flaky test management, framework migration, and living documentation. All version-controlled in your repo.

```
Other tools:  "Write a test for X"  →  a test file (maybe compiles, maybe passes)

bestest:      Detect stack → Pick framework → Generate → Compile → Run → Score → Ship
```

## Why bestest?

| Problem | What bestest does |
|---|---|
| "What testing framework should I use?" | 7-step decision trees per language, backed by evidence, recorded as ADRs |
| "Write tests for my codebase" | 7-phase pipeline: generate → compile → run → quality score (0–100) |
| "My tests are flaky" | Root-cause classification (test bug, source change, env, timing) + targeted fixes |
| "We need to migrate from Jest to Vitest" | AST-aware migration with `--gradual` safe mode |
| "No CI pipeline" | Generates GitHub Actions / GitLab CI / Jenkins configs |
| "Nobody knows our test strategy" | `TESTING.md` — living documentation, auto-updated on every scan |

## Getting Started

### Prerequisites

bestest works with any AI coding agent that loads skills from a local directory — including [GSD/pi](https://github.com/nicosql/gsd-pi) (an agent harness with auto-mode), [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Cursor](https://cursor.com), and others.

A **skill** is a directory of markdown instructions that AI coding agents read and follow. When you install bestest into your agent's skills directory, the agent gains the ability to architect your entire testing layer — detecting your stack, recommending frameworks, generating tests, and managing CI pipelines — all without leaving your editor.

### Install

```bash
# Clone the repo
git clone https://github.com/baagad-ai/bestest.git

# Copy to your agent's skills directory
cp -r bestest/ ~/.agents/skills/bestest/
```

### Use

In any agent session:

```
/bestest                    # First run? Initializes testing infrastructure
/bestest init               # Audit repo, scaffold test infrastructure
/bestest generate src/      # Generate tests for a file or directory
/bestest scan               # Deep audit of current test state
/bestest run                # Execute test suites with structured result capture
/bestest doctor             # Health check your test infrastructure
```

That's it. bestest detects your stack automatically — no config needed to start.

## Commands

### Core Lifecycle

```
init ──► scan ──► generate ──► run ──► coverage ──► fix
  │                       │                       │
  ▼                       ▼                       ▼
config.yaml          New test files           Fixed tests
TESTING.md           (compiled + passed)      (root-caused + verified)
stack-profile.json
```

| Command | Description |
|---|---|
| `init` | Full audit + scaffold: detects stack, recommends framework, writes configs |
| `scan` | Deep audit: anti-patterns, flaky tests, coverage gaps, full test inventory |
| `generate` | AI test generation through a 7-phase verified pipeline |
| `run` | Execute test suites with structured result capture |
| `fix` | Diagnose and fix failing/flaky tests with root-cause classification |
| `coverage` | Coverage gap analysis with actionable targets |
| `report` | Generate human-readable test reports |

### Infrastructure

| Command | Description |
|---|---|
| `config` | View and modify `.bestest/config.yaml` settings |
| `doctor` | 9-dimension health check of test infrastructure |
| `expand` | Add new test types (unit → integration → e2e → mutation) |
| `migrate` | Migrate frameworks: Jest→Vitest, JUnit 4→5, Cypress→Playwright |
| `ci` | Generate CI pipelines for GitHub Actions, GitLab CI, or Jenkins |

### Self-Service

| Command | Description |
|---|---|
| `help` | Show available commands, current config, quick-start guide |
| `explain` | Explain testing architecture decisions and ADRs |
| `status` | Show test health: coverage, last scan, flaky tests, CI status |
| `version` | Show bestest version and location |

## How It Works

### The Spoke Architecture

bestest uses a **lean orchestrator + spoke** pattern. Only one spoke loads per command, keeping context windows small while supporting 16 commands across 4 languages.

```
SKILL.md (orchestrator — routing, principles, reference index)
├── references/
│   ├── spoke-init.md                 ← /bestest init
│   ├── spoke-generate.md             ← /bestest generate (JS/TS)
│   ├── spoke-generate-python.md      ← /bestest generate (Python)
│   ├── spoke-generate-java.md        ← /bestest generate (Java)
│   ├── spoke-generate-go.md          ← /bestest generate (Go)
│   ├── spoke-scan.md                 ← /bestest scan
│   ├── spoke-run.md                  ← /bestest run
│   ├── spoke-fix.md                  ← /bestest fix
│   ├── spoke-coverage.md             ← /bestest coverage
│   ├── spoke-doctor.md               ← /bestest doctor
│   ├── spoke-migrate.md              ← /bestest migrate
│   ├── spoke-ci.md                   ← /bestest ci
│   └── ... (19 spokes total)
└── scripts/
    └── validate-skill.sh             ← 304 consistency checks
```

### The 7-Phase Generation Pipeline

When you run `/bestest generate`, it doesn't just spit out a test file. It runs a verified pipeline:

```
Phase 1: TARGET       →  Which files need tests?
Phase 2: CONTEXT      →  Read source, existing tests, framework docs (via Context7)
Phase 3: STRATEGY     →  Map each export to a test strategy (pure fn, component, API, etc.)
Phase 4: GENERATION   →  Write the test code with proper mocking and assertions
Phase 5: COMPILE      →  Run the compiler. Auto-fix if it fails. (3 retry attempts)
Phase 6: EXECUTE      →  Run the tests. Auto-fix if they fail. (2 retry attempts)
Phase 7: QUALITY AUDIT →  Score 0-100. Anti-pattern detection. Flakiness check.
```

Every generated test must **compile**, **pass**, and **score ≥ 70** on the quality rubric before it lands on disk.

### Detection Engine

bestest detects your stack from **80+ signals** across 12 categories, with confidence scores and evidence arrays:

```
Detected: TypeScript (0.94), React (0.88), Vitest (0.72), Vite (0.91)
Evidence: tsconfig.json, package.json → "typescript" in devDeps, src/**/*.ts, vite.config.ts
Framework recommendation: Vitest (existing framework — continue using it)
```

No "what framework are you using?" prompts. It knows.

## Supported Languages

| Language | Test Frameworks | Generate Spoke |
|---|---|---|
| JavaScript / TypeScript | Vitest, Jest, Mocha, Jasmine, Playwright | `spoke-generate.md` |
| Python | pytest, unittest | `spoke-generate-python.md` |
| Java | JUnit 5, JUnit 4, TestNG | `spoke-generate-java.md` |
| Go | testing (stdlib), testify | `spoke-generate-go.md` |

### Migration Paths

| From | To | Command |
|---|---|---|
| Jest | Vitest | `/bestest migrate jest vitest` |
| JUnit 4 | JUnit 5 | `/bestest migrate junit4 junit5` |
| Cypress | Playwright | `/bestest migrate cypress playwright` |

## State & Artifacts

All state lives in `.bestest/` inside your repo — version-controlled, auditable, shareable:

```
.bestest/
├── config.yaml                 ← Single source of truth
├── TESTING.md                  ← Living documentation (auto-updated)
├── state/
│   ├── stack-profile.json      ← Detected stack with confidence scores
│   └── metrics.json            ← Cross-spoke metrics store
├── adrs/
│   └── 001-vitest-over-jest.md ← Architecture Decision Records
└── reports/
    └── scan-2026-04-26.json    ← Timestamped scan reports
```

## Design Principles

1. **Test architecture, not just tests** — Tests are the output; architecture is the product
2. **Repo as source of truth** — All state in `.bestest/`, version-controlled, no external stores
3. **Progressive complexity** — `init` gives you a foundation; each command adds capability
4. **Human-in-the-loop on mutations** — Confirmation gates for `init`, `generate`, `fix`, `migrate`, `ci`. No gate on read-only commands (`scan`, `run`, `coverage`, `report`, `doctor`)
5. **Framework-agnostic** — Detects your stack, recommends the right tool, never forces a choice
6. **Verification-driven** — Every generated test compiles, passes, and covers meaningful behavior
7. **Living documentation** — `TESTING.md` is generated once, updated automatically on every scan

## Validation

bestest validates itself. A CI pipeline runs **304 automated checks** across 7 domains:

- File structure integrity
- Cross-reference validity (no phantom file references)
- Schema compliance
- Content completeness (no placeholders)
- Spoke consistency (shared sections match)
- Template validity
- Version parity

## Documentation

| File | Description |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to add spokes, languages, and contribute |
| [CHANGELOG.md](CHANGELOG.md) | Version history (currently v1.4.0) |
| [SECURITY.md](SECURITY.md) | Vulnerability reporting policy |
| [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) | Contributor Covenant v2.1 |
| [LICENSE](LICENSE) | MIT License |

## License

[MIT](LICENSE) © 2025–2026 Prajwal Mishra and contributors
