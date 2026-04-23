<role_identity>
role: "Output Contract Reviewer — Senior API Design & Schema Contract Expert"
domain: "Schema versioning, data model evolution, cross-phase contract integrity"
skill_name: "bestest"
focus_questions:
  - "Are the existing schemas sufficient for the new observability metrics (flakiness rates, trends, health scores)?"
  - "Does the schema-contract versioning policy handle the evolution from 'test generator' to 'test infrastructure plugin'?"
  - "What new schemas are needed: a health-report schema? a test-metrics time-series schema? a dashboard-config schema?"
  - "How should the existing scan-report-schema evolve to support historical trend data and flakiness detection?"
files_reviewed:
  - "references/schema-contract.md"
  - "references/scan-report-schema.md"
  - "references/config-schema.md"
  - "references/stack-profile-schema.md"
  - "references/dot-bestest-schema.md"
  - "SKILL.md"
</role_identity>

<executive_summary>
Bestest v1.3.0 has an unusually mature schema contract for a skill — the semver-minor versioning policy, per-spoke validation algorithm, and explicit breaking/non-breaking change taxonomy are well-designed. Its primary strength is the self-contained, versioned artifact model where each report carries its `schemaVersion` and `configSnapshot`. However, the schemas are exclusively point-in-time snapshots with no time-series, aggregation, or health-scoring primitives. This makes them structurally insufficient for the planned observability transformation (flakiness rates, trend analysis, health visualizations) without significant new schema introduction and careful evolution of existing ones. The most critical gap is the absence of a metrics time-series schema — without it, flakiness detection is limited to per-scan static analysis signals rather than empirical pass/fail rate tracking across runs. Overall risk level: **high** — the existing versioning policy can absorb additive changes, but the conceptual leap from "snapshot reports" to "longitudinal observability" will require at least two entirely new schemas and a minor-version evolution of the scan-report, and the schema-contract document itself needs a new section governing time-series data retention and cross-artifact correlation.
</executive_summary>

<findings>

<finding>
id: F1
severity: critical
file: "references/scan-report-schema.md"
line_ref: "flakyTests section (entire)"
observation: "The `flakyTests` array captures only static-analysis signals (uncontrolled-time, network-calls, etc.) with a heuristic riskLevel. There is no mechanism to track empirical flakiness — i.e., a test that passed in scan N-2, failed in scan N-1, and passed again in scan N. The `signals` array is detection-time only, with no run-to-run correlation."
evidence: "From scan-report-schema.md flakyTests section: `signals: string[] — List of flakiness signals detected` and `riskLevel determination: high = 3+ signals, medium = 2 signals, low = 1 signal`. There is no field for pass/fail history, flakiness rate (e.g., 0.33 = failed 1 of 3 runs), first-seen timestamp, last-flaked timestamp, or run-count context."
impact: "Without empirical flakiness tracking, the planned 'flakiness tracking' feature will be limited to static analysis heuristics — exactly what exists today. Users cannot see that a test has a 40% failure rate over the last 10 runs, which is the core value proposition of flakiness observability. The `spoke-doctor` and any future `spoke-health` will have no time-series data to consume."
confidence: 1.0
</finding>

<finding>
id: F2
severity: critical
file: "references/dot-bestest-schema.md"
line_ref: "Full directory tree and Report File Patterns section"
observation: "There is no schema or file pattern for a time-series metrics store. Reports are isolated `scan-<timestamp>.json` and `run-<timestamp>.json` files with no cross-report aggregation layer. The retention model (`reports.max_retained: 50`) deletes old reports, destroying the historical data needed for trend analysis."
evidence: "From dot-bestest-schema.md: `Report Retention — Only spoke-scan implements automatic report rotation: Controlled by config.yaml state.max_retained (default: 5). After each scan, if the number of scan-*.json files exceeds max_retained, the oldest scan-*.json files are deleted.` No mention of a metrics aggregation, time-series rollup, or summary that survives individual report deletion."
impact: "Trend analysis and flakiness detection require historical data. The current retention model deletes the raw data after 5–50 reports. Without an aggregated time-series artifact (e.g., `.bestest/state/metrics-timeline.json` or `.bestest/reports/trends.json`), trend visualization is impossible once old reports rotate out. This is a data-loss-in-waiting problem."
confidence: 1.0
</finding>

<finding>
id: F3
severity: major
file: "references/schema-contract.md"
line_ref: "Version History table and Consuming Spoke Validation section"
observation: "The schema-contract governs four artifact types (stack-profile, scan-report, run-results, config) but has no provision for cross-artifact correlation or a 'master health score' that aggregates across them. The versioning policy handles individual schema evolution well but does not address versioned schemas that reference each other (e.g., a health-report that references scan-report v1.2 and run-results v1.0)."
evidence: "From schema-contract.md validation algorithm: `Compare against the spoke's known-compatible version range. If MAJOR version matches and MINOR version ≤ spoke's known version: proceed normally.` There is no concept of a composite version or cross-schema compatibility matrix. The Cross-Reference section lists individual schemas but no inter-schema dependency graph."
impact: "When a new health-report schema aggregates data from scan-reports and run-results, it will need to declare which versions of those schemas it can consume. The current contract has no mechanism for this. A health-report consuming a scan-report v2.0 (future breaking change) could produce incorrect health scores silently."
confidence: 0.85
</finding>

<finding>
id: F4
severity: major
file: "references/scan-report-schema.md"
line_ref: "summary section"
observation: "The `summary` object is an aggregate snapshot with no delta or trend fields. It cannot express 'coverage increased by 2.3% since last scan' or '3 new anti-patterns introduced' because it carries no reference to previous state."
evidence: "From scan-report-schema.md summary fields: `totalTests, totalTestFiles, passed, failed, skipped, testTypes`. No `previousScanRef`, `deltas`, `trends`, or `sinceLastScan` fields exist. The Report Retention section mentions `Downstream tooling can compare consecutive reports` but provides no schema support for this comparison — it is left entirely to consuming code."
impact: "Every consumer that wants trend data must re-implement report comparison logic. The health observability features will require N different consumers to independently parse historical reports and compute deltas. This violates the 'single source of truth' principle stated in SKILL.md and leads to divergent trend calculations."
confidence: 0.9
</finding>

<finding>
id: F5
severity: major
file: "references/config-schema.md"
line_ref: "state.* section"
observation: "The `state.*` block tracks only timestamps of last execution (`last_scan`, `last_run`, `last_generate`, `last_doctor`). There is no observability state — no `last_health_score`, no `flakiness_trend`, no `coverage_trend_direction`, no `degraded_since` flag."
evidence: "From config-schema.md: `state.last_scan: ISO 8601 timestamp of last bestest scan execution`, `state.last_run`, `state.last_generate`, `state.last_doctor` — all timestamps only. No numeric health metrics, no trend indicators, no alert thresholds."
impact: "The config schema cannot support CI gate decisions like 'block merge if health score < 60' because there is no persisted health score. Each CI run would need to recompute from scratch, defeating the purpose of incremental observability. Config-driven health thresholds (e.g., `health.min_score: 70`) have no corresponding state field to compare against."
confidence: 0.85
</finding>

<finding>
id: F6
severity: major
file: "references/scan-report-schema.md → testInventory section"
line_ref: "testInventory[].status and testInventory[].lastRun"
observation: "The testInventory tracks per-file status as a single enum (`passed`, `failed`, `skipped`, `mixed`) with one `lastRun` timestamp. There is no execution history per test file — no array of recent outcomes, no failure streak counter, no pass rate. This makes per-file flakiness scoring impossible from the scan report alone."
evidence: "From scan-report-schema.md testInventory: `status: 'passed' | 'failed' | 'skipped' | 'mixed'`, `lastRun: ISO 8601 or null`. A single status and single timestamp. No `recentOutcomes: Array<{runId, timestamp, status}>`, no `failureCount`, no `passRate`."
impact: "The planned flakiness tracking cannot derive per-file flakiness rates from the scan report. It would need to cross-reference all historical `run-<timestamp>.json` reports (which are being rotated/deleted per F2). This creates a dependency chain that breaks under retention limits."
confidence: 0.9
</finding>

<finding>
id: F7
severity: minor
file: "references/schema-contract.md"
line_ref: "Breaking vs Non-Breaking Changes section"
observation: "The breaking/non-breaking taxonomy is clear and correct, but it does not address additive-then-breaking patterns — where a field is added as optional in N.MINOR, then later made required in (N+1).MAJOR. This pattern is common in schema evolution and the current taxonomy does not provide guidance for it."
evidence: "From schema-contract.md: `Non-Breaking: Adding a new optional field`, `Breaking: Changing a field from required to optional (or vice versa)`. The second rule covers the eventual breaking change, but there is no guidance on the transitional pattern or how consuming spokes should handle the 'optional now, required later' lifecycle."
impact: "Low immediate impact. The new schemas being introduced will likely start with optional fields that become required. Without lifecycle guidance, different spokes may handle the transition inconsistently. This is a governance gap rather than a functional bug."
confidence: 0.7
</finding>

<finding>
id: F8
severity: minor
file: "references/dot-bestest-schema.md"
line_ref: "Ephemeral Report Files section"
observation: "Ephemeral files (vitest-run.json, jest-run.json, coverage.json, etc.) are overwritten each run and not versioned. These contain the richest per-test execution data (individual test durations, failure messages, stack traces) but are discarded before they can feed a time-series."
evidence: "From dot-bestest-schema.md Ephemeral Report Files: `These are intermediate artifacts produced during spoke execution. They are overwritten on each invocation and not rotated.` The vitest-run.json and jest-run.json contain per-test results with timing — exactly the data needed for flakiness rate computation — but they are treated as disposable."
impact: "Rich per-test execution data (the kind needed for flakiness rate, test duration trends, and failure clustering) is destroyed on each run. The run-<timestamp>.json reports that persist are aggregated summaries, losing the test-level granularity needed for observability dashboards."
confidence: 0.8
</finding>

<finding>
id: F9
severity: informational
file: "references/stack-profile-schema.md"
line_ref: "Full schema"
observation: "The stack-profile schema is well-isolated from the observability transformation. It describes technology detection, not test health. It should not need changes for the new features unless health scoring becomes stack-aware (e.g., different health weights for Go vs. Python projects)."
evidence: "Stack-profile fields: languages, runtime, buildTool, frameworks, testFrameworks, e2eFramework, ciProvider, monorepo, packageManager, frontend, databases, messageQueues, coverage. All are detection-time technology descriptors. No health or metrics fields."
impact: "None — this is a positive observation. The stack-profile schema is stable and decoupled from the observability concerns. It can remain at v1.3 through the transformation."
confidence: 1.0
</finding>

</findings>

<dimension_scores>

| Dimension | Score (1–5) | Rationale |
|-----------|-------------|-----------|
| Schema Versioning Maturity | 4 | The semver-minor policy with per-spoke validation and explicit breaking/non-breaking taxonomy is solid and production-ready — minor gap in cross-schema dependency and field lifecycle governance. |
| Data Model Completeness for Observability | 1 | No time-series primitives, no empirical flakiness metrics, no health scores, no trend deltas — the current model is exclusively point-in-time snapshots with no longitudinal data support. |
| Cross-Artifact Contract Integrity | 3 | Individual schemas are well-defined with clear versioning, but there is no inter-schema correlation layer, no composite health model, and retention policies destroy data needed for aggregation. |
| Evolution Readiness (Generator → Infrastructure) | 2 | The additive-change path is well-supported, but the conceptual leap to observability infrastructure requires new schemas, new state fields, and new retention semantics that the current contract does not anticipate or govern. |

</dimension_scores>

<recommendations>

1. **Introduce a `metrics-timeline.json` schema** (addresses: F1, F2, F6, effort: high)
   Create `references/metrics-timeline-schema.md` defining a time-series artifact stored at `.bestest/state/metrics-timeline.json`. This schema should contain: per-test pass/fail history (last N runs), per-test flakiness rate (computed as `failures / total_runs`), coverage trend points (timestamp + coverage.pct per scan), anti-pattern count trend, and a computed health score. This is the foundational artifact for all observability features. The file should be append-only (not rotated like reports) and carry its own `schemaVersion`. Estimated fields: ~40-60 across nested objects.

2. **Add a `health-report` schema** (addresses: F3, F4, effort: medium)
   Create `references/health-report-schema.md` defining the output of a health computation (whether from spoke-doctor or a new spoke-health). Should declare which schema versions it consumes (`dependencies: { scanReport: ">=1.2", runResults: ">=1.0", metricsTimeline: ">=1.0" }`), produce a composite health score (0-100), and include dimension scores (coverage, flakiness, anti-patterns, gaps, execution stability). Register it in the schema-contract's artifact table with its own `schemaVersion`. Written to `.bestest/reports/health-<timestamp>.json`.

3. **Evolve scan-report-schema to v1.3** with trend deltas (addresses: F4, F6, effort: medium)
   Add an optional `trends` top-level field to scan-report containing: `sinceLastScan: { coverageDelta: number, testsAdded: integer, testsRemoved: integer, newAntiPatterns: integer, resolvedAntiPatterns: integer, newFlaky: integer, resolvedFlaky: integer }`. Also add to each `testInventory[]` entry: `passRate: number | null` (computed from metrics-timeline, null if <3 data points) and `flakinessScore: number | null` (0-1, null if insufficient data). These are additive, non-breaking changes → bump scan-report to v1.3.

4. **Extend config-schema with observability settings** (addresses: F5, effort: low)
   Add to config.yaml: `health: { enabled: true, min_score: null, dimensions: { coverage: { weight: 1.0 }, flakiness: { weight: 1.0 }, anti_patterns: { weight: 0.5 }, gaps: { weight: 0.8 } }, alerts: { degraded_threshold: 10, flaky_threshold: 0.3 } }` and `state.health_score: number | null`, `state.health_last_computed: string | null`. Also add `reports.retain_metrics_timeline: true` to prevent the metrics-timeline from being affected by report rotation. These are additive fields → config schema stays at v1.0 with minor note in version history.

5. **Add cross-schema dependency declaration to schema-contract** (addresses: F3, F7, effort: low)
   Extend schema-contract.md with a new section "Cross-Schema Dependencies" that defines: (a) which schemas consume which other schemas, (b) how a consuming schema declares its minimum compatible version of a dependency, (c) the field lifecycle pattern (optional → required transitions). This prevents silent misinterpretation when a health-report reads a scan-report whose schema has evolved beyond what the health-report was designed for.

6. **Preserve ephemeral per-test data into metrics-timeline** (addresses: F8, effort: low)
   Before overwriting ephemeral files (vitest-run.json, jest-run.json, etc.), extract per-test outcomes and append them to the metrics-timeline. This requires a small extraction step in spoke-run and spoke-scan between Phase 3 (parse results) and the ephemeral overwrite. The extraction schema should capture: test file path, test name, status, duration_ms, failure_message (truncated), timestamp. This feeds the flakiness rate computation without requiring full ephemeral retention.

7. **Do NOT modify stack-profile-schema** (addresses: F9, effort: none)
   The stack-profile is correctly decoupled. Leave it at v1.3 unless health scoring needs stack-aware weights in the future, which can be handled purely in config.yaml's health.dimensions block.

</recommendations>

<open_questions>

- "What is the target retention period for flakiness trend data? The metrics-timeline append-only design assumes indefinite retention — does the user want a configurable window (e.g., last 90 days) or full history?" — needs user clarification on retention policy.

- "Will the health score be computed on-demand (when `bestest doctor` or `bestest report` runs) or incrementally updated after every scan/run? This affects whether metrics-timeline.json is the source-of-truth or a cache." — needs spoke-doctor/spoke-report design decision from the skill owner.

- "Should the dashboard-config schema (mentioned in the user's goals) define terminal output formatting (ASCII charts, markdown tables) or also support web/HTML visualization output? The config-schema currently has no visualization settings at all." — needs user clarification on visualization scope.

- "The schema-contract uses MAJOR.MINOR (no patch). When new schemas are introduced at v1.0, should they follow the same two-part version scheme, or should the new observability schemas adopt full semver (MAJOR.MINOR.PATCH) for finer-grained change tracking?" — needs schema-contract owner input on consistency vs. improvement opportunity.

</open_questions>

<confidence_score>
0.92 — Direct evidence from all five schema files plus SKILL.md routing context. The versioning policy, field inventory, and cross-reference relationships are fully documented. One inference: the absence of time-series primitives is a structural gap rather than an intentional design choice, based on the scan-report's retention section explicitly suggesting that "downstream tooling can compare consecutive reports" — indicating the intent exists but the schema support does not. The stack-profile assessment (F9) is a positive observation with 100% confidence since its fields are entirely technology-detection oriented.
</confidence_score>
