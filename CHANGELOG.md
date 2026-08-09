# Changelog

All notable changes to the **bestest** skill are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) conventions. Version numbers align with the `version` field in `SKILL.md` frontmatter.

---

## [2.0.0] — 2026-08-09

### Added

- **Deterministic CLI helper** (`scripts/bestest-cli.py`, stdlib-only Python): mechanical operations — `detect`, `config read/write/validate`, `report list/latest-full` (with companion-run filtering), `lock acquire/release`, `metrics read/merge`, `render`, `contracts check`. Spokes delegate to it when `python3` is available, falling back to documented manual steps (graceful degradation). See `references/bestest-cli.md`.
- **Golden-fixture contract validation** (`scripts/validate-contracts.sh`, C001–C030): verifies every fixture parses, matches its schema, and that every spoke's documented read/write fields exist in the corresponding fixture. Catches the "status reads `total_tests` but the schema defines `summary.totalTests`" class of drift that structural checks cannot see. Fixtures in `scripts/fixtures/` (7 JSON + config.yaml).
- **Contract fixtures CI job** in `.github/workflows/validate-plugin.yml` (validate-contracts job).
- **Java generation guide** (`references/java-generation-guide.md`): JUnit 5, Mockito, @ParameterizedTest, @Nested, Spring slice testing, Testcontainers.
- **`config unset`** subcommand in the config spoke.
- **`--force` / `--reinit`** flag for init with backup-preserving reinitialize.
- **`--lang all`** for CI batch multi-language generation.
- **Run-report rotation** (spoke-run + spoke-scan): `run-*.json` now bounded by `reports.max_retained` (default 50), matching scan rotation.
- **Monorepo path boundary** in all 4 phase1 files: boundary check scoped to the package root in monorepos.
- **Sensitive directory patterns** in path validation: `.aws/`, `.ssh/`, `.gnupg/` etc. matched against the full canonical path (previously dead basename-only patterns).
- **CGO check** in Go environment detection; **toolchain pre-flight check** for JS/TS; **shared test utilities step** for JS/TS Phase 2.
- **Zero-testable-exports and all-covered** generation scenarios in JS/TS error handling.
- **Deno / Bun runtime detection signals** (JS/TS projects).
- **Error envelope + contract codes** (C001–C030) documented in error-codes.md.

### Changed

- **Canonical quality scale is 0–100 everywhere.** `generation.quality_threshold` (0–1) converts at the gate via `threshold_pts = quality_threshold × 100` (default 70). Applied to HITL Gate Core, parallel-dispatch worker self-assessment, Java/Go gates, and all generation guides.
- **Two-tier iteration budget implemented consistently** in all 8 phase5/6 files (`max_files` default 50, `max_retries_per_file` default 5; legacy `max_iterations` kept). Documented in config-schema.md and pre-flight-protocol.md.
- **Companion run reports are now filtered by consumers.** `data-source-discovery.md` defines a canonical priority chain (non-companion run → scan → companion); fix/coverage/doctor/status/report honor it. `fix --flaky` counts full-suite runs only. Report trends label companion runs and deduplicate same-timestamp scan/run points.
- **`validate-skill.sh` honors `SKILL_DIR` env var** (was hardcoded to `$HOME/.agents/skills/bestest`, so CI validated a stale copy). Fixed the 2 real bugs this masked: reference-index self-exclusion (E004) and dashboard reference in spoke-init (E020).
- **Error-code catalog unified with the validation scripts**: E009a–E009j documented, E017 bounds corrected (200–350), E022–E025 moved from "planned" to live checks with a dedicated Domain 8, Domain 8 numbering collision resolved.
- **Metrics protocol single-sourced**: corruption-backup step added to all duplicated copies, `lastWriteConflict` added to the JSON shape, `suiteFilter`→`history[].scope` mapping documented, config-lock ordering note added.
- **CI templates**: replaced `bc`/`jq` (not guaranteed on runners) with `python3`; wired `MUTATION_THRESHOLD` from config; fixed Stryker report path (`reports/mutation/mutation.json`); added Java coverage gate; added GitLab Python/Java mutation jobs + slow-java Maven fallback; documented `needs:` pruning after language-job removal.
- **spoke-status schema fixes**: reads `summary.totalTests`, `coverage.lines.pct`, `healthScore`, dimensions-keyed-by-id — the fields the schemas actually define.
- **Config schema/templates**: `language` added to JS/TS templates; `flaky.retries`, `e2e.config_path`, `state.last_fix`, `state.last_report`, `generation.max_files/max_retries_per_file` documented; `api.framework` valid values language-scoped; three-way `framework` valid-value sets reconciled.
- **spoke-help accuracy**: removed phantom commands (`run --watch`, `fix --report`, `report summary/coverage/flaky`, `expand integration/snapshot/visual`, `migrate cypress playwright --gradual`).
- **README accuracy**: 19 commands (was 16), 347 structural + 77 contract checks (was 304), Runtime Model callout added.
- **Fixed broken `workflows/` cross-references** in spoke-run/spoke-fix → `references/`. Corrected false "fix reports read by doctor/report" claims.
- **Cleaned copy-paste damage**: dangling fragments + duplicated schema-validation blocks in 3 phase1 files, duplicate step numbers in scan/run/fix, cross-language mutation content in the JS/TS phase7 file.

### Fixed

- Companion run reports omitted `configSnapshot`/`raw_output` — now included in all 4 generate spokes.
- `flock` flag confusion in pre-flight-protocol (`-s` shared vs `-x` exclusive) — corrected to exclusive for read-modify-write.
- Prefix-collision boundary check (`startsWith` allowed `/project-root-evil`) — now requires root or root+separator.
- Traversal rejection unified to segment-based checks across all 4 languages (substring `..` over-rejected legit filenames).
- `--visibility` flag added to migrate arg parsing; Context7 pre-hook contradiction fixed (target framework, not source).
- Broken `migration-rules.md Section 4.2` reference → `Per-File Complexity Classification`.
- JUnit 5 branch added to fix spoke's framework-installed check.
- Coverage report now carries `schemaVersion`; registered in schema-contract.md; generate fallback reads coverage reports for gaps.
- Stale `reports.max_retained` default (5 → 50) reconciled across dot-bestest-schema.
- `reference-index.md` self-reference (E004) and `dashboard.html` init reference (E020) fixed.

## [1.4.0] — 2026-04-27

### Added

- Parallel dispatch architecture (`parallel-dispatch.md`): agent-agnostic 6-platform cascade for multi-agent test generation.
- UX command spokes: `spoke-help.md`, `spoke-explain.md`, `spoke-status.md`, `spoke-version.md` — interactive skill self-service commands.
- Documentation reconciliation: deployed/repo parity + pre-flight protocol references synced across both copies.
- Shared pipeline extraction: `pipeline-shared.md` — 7-phase skeleton eliminating ~60% duplication across language branches.
- Metrics schema integration: `metrics-schema.md` + spoke responsibility matrix across all schema files and spokes.
- `validate-skill.sh` expanded to 304 automated checks across 7 validation domains.

### Changed

- Maturity score improved from 4.3 → 4.4/5.0 (all dimensions ≥ 4.2) per structured 5-dimension re-audit.

### Fixed

- Repair 9 systemic workflow handoff breakages across spokes.
- Scan now writes companion run report for downstream consumption.
- Fix now accepts scan reports as fallback data source.
- Auto-chain HITL gates on scan and run spokes to offer fix/coverage.
- Init recommends `/bestest run` instead of raw test runners.

---

## [1.3.0] — 2026-04-23

### Added

- Confidence scoring algorithm (noisy-OR) in detection-engine.md.
- Generalized conflict detection (category-based per-ecosystem).
- Path validation ordering fix (traversal → canonicalize → boundary).
- Language persistence in StackProfile (selectedLanguage field).
- Schema version contract (schema-contract.md) with validation in 10 consuming spokes.
- Generate spoke decomposition: 4 hub files (≤415 lines) + 24 on-demand sub-files.
- Security hardening: content boundary markers (`BEGIN_UNTRUSTED_SOURCE`) in 9 spokes.
- Taint notice positioned before Context7 fetch in all 6 fetching spokes.
- Complete reference_index: 67 entries across 12 categories.
- `quick_reference.md` extracted for on-demand loading (~68 lines saved).
- `pre-flight-protocol.md`: shared validation patterns reference (271 lines).
- `dot-bestest-schema.md`: complete `.bestest/` directory tree documentation (251 lines).
- `error-codes.md`: error taxonomy (E001–E025, 5 domains).
- `validate-skill.sh`: 266 automated consistency checks across 7 domains.
- GitHub Actions CI workflow for automated skill validation.

---

## [1.2.0] — 2026-04-22

### Added

- Confidence gate in generate routing (R5): warns when language detection confidence < 0.6, offers proceed/manual-select/abort options.
- Multi-language project routing (R10): detects polyglot projects with multiple languages ≥ 0.6 confidence, presents detected languages with scores, supports `--lang` flag for explicit selection.
- Content-boundary markers (R1): `<!-- BEGIN_UNTRUSTED_SOURCE -->` / `<!-- END_UNTRUSTED_SOURCE -->` HTML comment markers around source file read instructions in all generate spokes to mitigate indirect prompt injection.
- State corruption handling (R4): JSON validation blocks before `.bestest/state/*.json` reads across 7 spoke files, with 3-option recovery (regenerate/manual fix/abort).
- Version compatibility check (R15): compares `.bestest/config.yaml` version to SKILL.md frontmatter version in `init` and `doctor` spokes, warns on mismatch.
- `README.md` — user-facing documentation covering installation, quick start, supported languages, commands, and architecture.

### Fixed

- Auto-commit clarification (R6): renamed "Auto-commit criteria" to "Write-to-disk criteria" in all generate spokes with explicit note that git commits are never made without user approval.
- Spoke-init title (R7): corrected scope from "JS/TS repository" to "multi-language repository (JS/TS, Python, Java, Go)".
- Narrowed HITL principle scope (R11): principle 4 now specifies that human-in-the-loop gates apply to mutating commands only (`init`, `generate`, `fix`, `migrate`, `ci`) — not read-only commands (`scan`, `run`, `config show`, `coverage`, `report`, `doctor`).

---

## [1.1.0] — 2026-04-22

### Added

- Skill-level versioning: `version: "1.1.0"` in SKILL.md YAML frontmatter.
- `schemaVersion: "1.1"` top-level field in `stack-profile-schema.md` and `scan-report-schema.md` JSON shapes.
- `CHANGELOG.md` — this file.
- `CONTRIBUTING.md` — spoke template guide and language-addition guide for contributors.

### Fixed

- Removed phantom references (`testing-strategies.md`, `coverage-standards.md`) from SKILL.md `reference_index`. These files were listed but never existed on disk.
- Filled JS/TS decision tree gap for the 20–50 file range (`js-ts-decision-tree.md`).
- Changed fix spoke default classification from `test_bug` to `unknown` (`spoke-fix.md`).
- Harmonized flakiness signal identifiers between `spoke-scan.md` and `scan-report-schema.md`.
- Added report rotation config (`max_retained`) to `config-schema.md` and rotation logic to `spoke-scan.md`.

---

## [1.0.0] — 2026-04-18

### Added

- Initial release of the bestest skill.
- Stack detection engine with 80+ signals across 12 categories.
- Framework decision trees for JS/TS, Python, Java, and Go.
- Command spokes: `init`, `config`, `scan`, `generate`, `run`, `fix`, `coverage`, `report`, `doctor`, `expand`, `migrate`, `ci`.
- Context7 integration for version-specific framework documentation.
- Scan report schema with anti-pattern detection, flaky test identification, coverage gap analysis, and test inventory.
- StackProfile schema with confidence scores and evidence arrays.
- Migration support: Jest → Vitest, JUnit 4 → JUnit 5, Cypress → Playwright.
- CI pipeline generation for GitHub Actions, GitLab CI, and Jenkins.
