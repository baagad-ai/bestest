<!-- skill-expert-report.md — per-subagent findings template for skill audits
     Path: templates/skill-expert-report.md
     Used by: audit-skill.md S02 research subagents — each expert fills one copy.
     Consumers: S03 synthesis (skill-audit-synthesis.md)
-->

<role_identity>
role: "Agentic Workflow Designer"
domain: "Multi-step workflow architecture, data aggregation pipelines, and spoke router patterns for LLM-based tooling"
skill_name: "bestest v1.3.0"
focus_questions:
  - "The spoke pattern (15 independent command docs) avoids subagent dispatch — is this the right model for observability commands that need to aggregate data from multiple sources?"
  - "How should new 'existing test architecture analysis' workflows relate to existing scan and init spokes — extend or separate?"
  - "What's the right architecture for test health visualizations: a new dashboard spoke, extension of report, or something fundamentally different?"
  - "Should the plugin introduce a data aggregation layer (e.g., a metrics store in .bestest/) that multiple spokes contribute to?"
files_reviewed:
  - "SKILL.md — routing architecture, reference index, command routing table"
  - "references/spoke-init.md — full audit + scaffold workflow (1078 lines)"
  - "references/spoke-scan.md — deep audit workflow (1249 lines)"
  - "references/spoke-report.md — report generation (comprehensive)"
  - "references/spoke-doctor.md — health check (1606 lines)"
  - "references/spoke-run.md — test execution (1783 lines)"
  - "references/spoke-coverage.md — coverage analysis (922 lines)"
  - "references/scan-report-schema.md — scan output contract"
  - "references/dot-bestest-schema.md — .bestest/ directory structure"
  - "references/config-schema.md — full config schema"
</role_identity>

<executive_summary>
Bestest's 15-spoke router is a well-engineered single-agent dispatch model that excels at isolation and token efficiency — each invocation loads exactly one spoke document, avoiding context window pollution. The skill's primary architectural strength is its disciplined data contract layer: scan reports, run results, and doctor reports all write to a shared `.bestest/reports/` directory with versioned JSON schemas, enabling downstream spokes (report, doctor, coverage, fix) to aggregate across sources without coupling. The most critical weakness is that observability and aggregation spokes (report, doctor, coverage) must re-read and re-parse all historical artifacts on every invocation — there is no materialized metrics store, so trend computation, flakiness tracking, and dashboard visualization are all recomputed from raw JSON files. This approach will degrade significantly as report history grows. Overall risk level: **medium** — the current spoke-only model works for the existing command set, but the planned observability and visualization features will expose architectural limits that require a new aggregation layer, not just more spokes.
</executive_summary>

<findings>

<finding>
id: F1
severity: major
file: "references/spoke-report.md, references/spoke-doctor.md, references/spoke-coverage.md"
line_ref: "spoke-report.md Phase 1–2 (full data loading); spoke-doctor.md Phase 1 (full data loading)"
observation: "Report, doctor, and coverage spokes each independently read, parse, and aggregate ALL historical JSON artifacts from .bestest/reports/ on every invocation. There is no materialized intermediate state — no metrics store, no pre-computed trend data, no deduplicated anti-pattern index. The report spoke's Phase 1 loads all run-*.json and scan-*.json files into memory; Phase 2 then recomputes pass/fail trends, coverage history, flaky test history, and anti-pattern distribution from scratch."
evidence: "spoke-report.md Phase 1 Step 1: 'Read all run reports — Glob for run-*.json files in .bestest/reports/. Sort by filename... For each file: Parse the JSON file.' spoke-report.md Phase 2: 'Compute Aggregations — Pass/Fail Trends: For each pair of consecutive run reports... Coverage Trends: Collect coverage data points from all sources... Flaky Test History: Aggregate flaky test data across all scan reports... Anti-Pattern Distribution: Aggregate anti-patterns from all scan reports.' spoke-doctor.md Phase 1 repeats the same loading pattern identically."
impact: "Three consequences: (1) O(N) disk I/O and JSON parsing per invocation, where N is total report count — performance degrades linearly with usage. (2) Identical aggregation logic is duplicated across report, doctor, and coverage spokes (all three independently compute coverage trends and flaky test history), violating DRY and creating drift risk. (3) Any future dashboard/visualization spoke would need to duplicate this same loading+aggregation pattern again, making the problem worse. At 50 retained reports (the configured default), this is tolerable. At 500+ (a project that runs scan in CI nightly), this becomes a real latency problem."
confidence: 0.95
</finding>

<finding>
id: F2
severity: major
file: "SKILL.md — routing section"
line_ref: "L74-L110 (Command Routing table)"
observation: "The spoke router is a flat 15-command dispatch table with no composition or pipeline mechanism. Each spoke is fully self-contained — there is no way for one spoke to delegate a sub-task to another spoke within the same invocation, nor is there a shared 'aggregation spoke' that other spokes can contribute to. The only cross-spoke communication is indirect: writing artifacts to .bestest/reports/ and having the next spoke read them."
evidence: "SKILL.md routing section: 'Parse the subcommand from /bestest <command> [args] and load the corresponding spoke reference file. Only one spoke loads per invocation.' The migration pre-hook is the sole exception: 'After migration: run spoke-run.md to verify migrated tests pass. If failures occur, spoke-fix.md is invoked for auto-fix.' — but this is sequential user-level invocation, not in-context composition."
impact: "This flat dispatch prevents the new observability features from following the natural architecture. A flakiness tracking system needs to run a detection phase (currently in scan), a historical aggregation phase (currently in report), and a visualization phase (new) — ideally as a composed pipeline. With the current model, each of these would be a separate invocation that re-reads all prior data. Adding a 'dashboard' or 'trends' command as a 16th spoke with the same pattern would mean yet another full re-read of all historical artifacts. The user would also need to run 3 commands to get what should be one view."
confidence: 0.9
</finding>

<finding>
id: F3
severity: major
file: "references/spoke-report.md, references/spoke-doctor.md"
line_ref: "spoke-report.md Phase 2 (Flaky Test History, Anti-Pattern Distribution); spoke-doctor.md Phase 5 (Anti-Pattern Summary), Phase 6 (Flaky Test Budget)"
observation: "Duplicated aggregation logic across spokes. Report spoke and doctor spoke independently compute flaky test history, anti-pattern distribution, and coverage trends using nearly identical algorithms. The report spoke aggregates across all scan reports; the doctor spoke reads the most recent scan report for its dimensions. This is not a code reuse problem (they're separate documents) — it's a semantic consistency problem. If the algorithms drift (e.g., report uses 'most recent scan' while doctor uses 'all scans'), the user sees contradictory health information."
evidence: "spoke-report.md Phase 2 'Flaky Test History': 'flakyTestMap = Map<testIdentifier, { name, path, occurrences: [], riskLevels: [] }> For each scan report: For each entry in flakyTests[]...' spoke-doctor.md Phase 6 'Flaky Test Budget': 'For each scan report (sorted newest first): If report.flakyTests exists and is an array: flakyTests = report.flakyTests; break' — doctor uses only the MOST RECENT scan, while report aggregates across ALL scans. This produces different flaky test counts for the same project."
impact: "The user runs `doctor` and sees '2 flaky tests', then runs `report` and sees '3 flaky tests' (because report aggregates historical occurrences). This is confusing and undermines trust. As more aggregation spokes are added (trends, dashboard), the drift risk compounds. Each new spoke must independently decide: most-recent-only vs. all-history, deduplication strategy, risk recency weighting — with no shared logic to keep them consistent."
confidence: 0.95
</finding>

<finding>
id: F4
severity: minor
file: "references/spoke-scan.md — Phase 5 (Detect Flaky Tests)"
line_ref: "spoke-scan.md Phase 5 Step 3 (Historical pattern comparison)"
observation: "Flaky test historical comparison in scan reads only the most recent prior scan report, not all historical reports. This means flakiness risk escalation (e.g., 'flagged in 3 consecutive scans → high risk') is limited to 2-scan history, not true multi-scan trend analysis. Meanwhile, the report spoke's flaky test history (Phase 2) reads ALL scan reports to build a complete cross-scan view. These two analysis depths are inconsistent for the same concept (flaky test history)."
evidence: "spoke-scan.md Phase 5 Step 3: 'If prior scan reports exist in .bestest/reports/, load the most recent report and compare' — single prior report only. spoke-report.md Phase 2 'Flaky Test History': 'For each scan report: For each entry in flakyTests[]: ... If key not in flakyTestMap: Add entry with first occurrence. Else: Append this scan's timestamp to occurrences' — all scan reports."
impact: "Scan's flakiness detection gives a shallow 2-point comparison. Report gives a deep N-point analysis. The user may see different risk levels for the same test depending on which command they run. For a planned flakiness tracking feature with trend visualization, scan's limited history is insufficient — the feature would need to replicate report's deeper aggregation, further duplicating logic."
confidence: 0.85
</finding>

<finding>
id: F5
severity: major
file: "references/dot-bestest-schema.md, references/config-schema.md"
line_ref: "dot-bestest-schema.md — .bestest/ directory tree; config-schema.md — state.* fields"
observation: "The .bestest/ data model is purely append-only JSON artifacts. There is no structured metrics store, no index of anti-patterns by file, no per-test execution history table, and no time-series data structure. The only 'state' is config.yaml timestamps (state.last_scan, state.last_run, etc.). Every query — 'how many times has test X been flaky?', 'what's the coverage trend for module Y?', 'which files have the most anti-patterns?' — requires reading and parsing all JSON artifacts from scratch."
evidence: "dot-bestest-schema.md directory tree: '.bestest/├── config.yaml ├── .gitignore ├── adrs/ ├── state/ │ ├── stack-profile.json │ └── migration-backup.json └── reports/ ├── scan-<timestamp>.json ├── run-<timestamp>.json ...' — no metrics/ or index/ directory. config-schema.md state fields: 'state.last_scan: ISO 8601 timestamp... state.last_run: ISO 8601 timestamp...' — only timestamps, no aggregated metrics."
impact: "This is the root cause of F1 and F3. Without a materialized metrics store, every aggregation command must re-read and re-parse raw artifacts. For the planned 'test health observability with visualizations (dashboards, flakiness tracking, trends)' feature, this is a hard blocker. A dashboard needs sub-second access to pre-computed trend data, not a 5-second scan of 50 JSON files. A flakiness tracker needs a per-test execution history that accumulates over time, not a flat array of test results embedded in scan reports."
confidence: 0.95
</finding>

<finding>
id: F6
severity: minor
file: "SKILL.md — routing section"
line_ref: "L74-L110"
observation: "The spoke model has no mechanism for 'partial results' or 'progressive loading'. A dashboard or trends visualization command would need to load and aggregate potentially months of data before producing any output. There is no caching layer, no incremental computation, and no way to produce a partial result while continuing to process. The spoke either completes fully or fails."
evidence: "SKILL.md routing: 'Only one spoke loads per invocation.' Each spoke runs to completion. spoke-report.md has no caching or incremental mechanism — Phase 1 loads everything, Phase 2 computes everything, Phase 3 renders everything. Error Handling section 8 (Very large data sets): 'Continue with full processing. For the markdown report: Pass/Fail Trends: show only the last 20 comparisons...' — the mitigation is output truncation, not incremental computation."
impact: "For a dashboard or real-time trends feature, the user expects fast, responsive updates. The current model would require a full re-aggregation on every dashboard load. In CI environments where scan runs nightly, a weekly trend chart would need to parse 7 full scan reports plus 7+ run reports. While acceptable for markdown report generation (a one-shot operation), this model is unsuitable for interactive or repeated visualization use cases."
confidence: 0.75
</finding>

<finding>
id: F7
severity: informational
file: "references/spoke-init.md, references/spoke-scan.md"
line_ref: "spoke-init.md Phase 1 (Detect Stack), spoke-scan.md Phase 2 (Discover Tests)"
observation: "The existing test architecture analysis currently exists in two places: init detects the test framework and produces a StackProfile; scan discovers tests, categorizes them by type, and evaluates quality. Neither spoke produces a comprehensive 'test architecture report' that answers questions like: How is the test suite structured? What test types exist and what's their distribution? What's the test-to-source ratio? How mature is the test infrastructure? Is the testing strategy coherent? This is a gap that the planned 'existing test architecture analysis' feature would fill."
evidence: "spoke-init.md produces: StackProfile (languages, frameworks, build tools) + ADR + config.yaml. spoke-scan.md produces: testInventory (file-level test counts) + antiPatterns + flakyTests + coverage gaps. Neither produces a synthesized 'architecture assessment' that evaluates the test strategy holistically — e.g., whether the unit/integration/e2e distribution is healthy, whether test naming conventions are consistent, whether the test directory structure follows best practices."
impact: "A new 'analyze' or 'assess' spoke could synthesize data that init and scan already partially collect. The question is whether to extend scan (making it even larger — already 1249 lines) or create a separate spoke that consumes scan output. Given scan's already substantial size and single-responsibility focus (detect problems, produce a report), a separate spoke is architecturally cleaner — but it would need scan output as a prerequisite."
confidence: 0.85
</finding>

<finding>
id: F8
severity: informational
file: "references/spoke-report.md"
line_ref: "spoke-report.md — complete document"
observation: "The report spoke is already the closest thing to an 'observability dashboard' in the current architecture. It aggregates from run + scan reports, computes trends, produces a structured markdown document with coverage heatmaps, flaky test trends, anti-pattern distribution, and prioritized action items. It is explicitly documented as a 'terminal spoke' — designed for human consumption, not machine consumption."
evidence: "spoke-report.md Purpose: 'The report command is a terminal spoke — it produces markdown for human consumption, not structured JSON for downstream tooling.' Phase 3 produces 8 sections: Summary, Coverage Heatmap, Flaky Test Trends, Coverage History, Uncovered Critical Paths, Anti-Pattern Distribution, Prioritized Action Items, Run History."
impact: "A 'dashboard' spoke would heavily overlap with report's existing functionality. The differentiation would need to be: (a) format (HTML with charts vs. markdown with tables), (b) interactivity (filterable/sortable vs. static), (c) temporal focus (trends/visualization vs. point-in-time report). The data aggregation logic would be nearly identical. This suggests that dashboard should either extend report (add HTML/chart output format) or consume report's existing JSON artifacts rather than re-implementing the same aggregation."
confidence: 0.9
</finding>

</findings>

<dimension_scores>

| Dimension | Score (1–5) | Rationale |
|-----------|-------------|-----------|
| Workflow Architecture | 3 | The single-spoke-per-invocation model is clean and token-efficient but prevents composition, shared state, and incremental computation — which the planned observability features require. |
| Data Flow Design | 4 | The artifact-based data contracts (versioned JSON schemas in .bestest/reports/) are excellent — the best part of the architecture. Spoke input/output boundaries are explicit and well-documented. |
| Aggregation Scalability | 2 | Full re-read and re-parse of all historical artifacts on every aggregation invocation is unsustainable for the planned visualization and trend features. No materialized intermediate state exists. |
| Cross-Spoke Consistency | 2 | Duplicated aggregation logic between report and doctor spokes produces semantically different results for the same concepts (flaky test counts, coverage trends). No shared computation layer to enforce consistency. |
| Extensibility | 3 | Adding a new spoke is straightforward (create spoke file, add routing entry). But adding observability features that cross-cut multiple data sources hits the limits of the flat spoke model — no composition, no shared metrics store, no incremental updates. |

</dimension_scores>

<recommendations>

1. Introduce a materialized metrics store at `.bestest/state/metrics.json` that is incrementally updated by scan, run, and fix spokes after each invocation (addresses: F1, F5, effort: high)
   This is the foundational change. After each `scan`, `run`, or `fix` invocation, the spoke appends structured data to a metrics store: per-test pass/fail history, per-file coverage snapshots, anti-pattern counts, flakiness signals. The store acts as a pre-computed aggregation layer that dashboard, trends, and report spokes read directly instead of re-parsing all raw JSON artifacts. Schema: `{ "testHistory": { "<testName>": [{ "timestamp", "status", "durationMs" }] }, "coverageSnapshots": [{ "timestamp", "lines", "branches", "functions", "statements" }], "antiPatternIndex": { "<file>": { "<pattern>": { "firstSeen", "lastSeen", "occurrences" } } }, "flakyTestIndex": { "<testId>": { "signals": [], "occurrences": [], "riskHistory": [] } } }`. Each contributing spoke updates only its section. This eliminates the O(N) re-read problem and provides sub-second access to trend data for visualizations.

2. Extract shared aggregation logic into a new reference file `references/lib-aggregation.md` that report, doctor, coverage, and any future dashboard spoke all reference (addresses: F3, F4, effort: medium)
   Define canonical algorithms for flaky test history aggregation, anti-pattern distribution, coverage trend computation, and gap analysis in a single reference document. Each aggregation spoke loads this library and uses its algorithms. This ensures semantic consistency (same flaky test count in doctor and report) and eliminates the drift risk from duplicated logic. The library is not a spoke — it's a shared computation reference that aggregation spokes include during Phase 2.

3. Design the 'dashboard' feature as a format variant of the report spoke, not a new spoke — add `--format html` and `--format chart` options to the existing report command (addresses: F8, F2, effort: medium)
   The report spoke already aggregates all the data a dashboard needs. Rather than creating a 16th spoke that duplicates this aggregation, extend report to support multiple output formats: `--format markdown` (current), `--format html` (new, with embedded SVG/Canvas charts), `--format json` (machine-readable). The HTML format can include trend charts (coverage over time), flakiness heatmaps, and anti-pattern severity charts — generated inline from the same data aggregation phases. This avoids both the spoke explosion problem and the re-aggregation problem. The spoke is already 1100+ lines, but format-specific rendering can be extracted to `references/lib-report-formats.md` to keep the main spoke manageable.

4. Create a new `references/spoke-analyze.md` spoke for test architecture analysis that consumes scan output (addresses: F7, effort: medium)
   This spoke answers strategic questions: Is the test strategy coherent? Is the unit/integration/e2e distribution healthy? Are test naming conventions consistent? Does the directory structure follow best practices? It consumes the most recent scan report's testInventory, antiPatterns, and gaps arrays, plus the StackProfile, and produces a synthesized architecture assessment. It does NOT re-run detection or coverage — it reads existing artifacts only. This keeps scan focused on detection and analyze focused on strategic interpretation. Route as `/bestest analyze`. Prerequisite: at least one prior `scan` execution.

5. For flakiness tracking specifically, extend the metrics store (Recommendation 1) to include a per-test `executionHistory` array that every `run` invocation appends to, then build the flakiness tracker as a lightweight query over this pre-computed data (addresses: F4, F5, effort: medium as part of R1)
   Currently, flakiness is detected only during `scan` by reading the most recent prior scan report. A true flakiness tracker needs per-execution data: each `run` invocation appends { timestamp, testName, status, durationMs } to the metrics store. The flakiness detection algorithm then operates on this accumulated history rather than comparing only 2 scan reports. This enables real flakiness scoring: 'test X failed 3 of last 10 runs' rather than 'test X had flaky signals in the last scan'.

6. Document the architectural decision: spoke-only model with metrics store vs. subagent dispatch, and commit to one before building dashboard/observability features (addresses: F2, effort: low)
   The current spoke-only model works for commands that perform a single action (generate tests, run tests, fix tests). The planned observability features (dashboard, trends, flakiness tracker) are fundamentally different — they are read-only aggregation queries over accumulated data. These do NOT need subagent dispatch (they don't perform independent actions that benefit from parallelism). They DO need a pre-computed metrics store. Document this decision: bestest remains a single-agent, single-spoke-per-invocation system, but adds a materialized metrics layer that aggregation spokes query. This avoids the complexity of subagent orchestration while solving the performance and consistency problems.

</recommendations>

<open_questions>

- "How large do typical .bestest/reports/ directories grow in real usage? The architecture assumes max 50 retained reports, but CI-nightly-scan projects may hit that in under 2 months. Understanding real-world growth rates would validate the urgency of the metrics store recommendation." — needs production usage data from early adopters or CI integration testing.
- "What visualization library or approach should the HTML dashboard format use? The recommendation to extend report with --format html depends on whether LLM agents can reliably generate SVG charts or Canvas-based visualizations, or whether a template-based charting approach (e.g., pre-built chart templates that the spoke fills with data) is more practical." — needs a spike on LLM-generated chart reliability.
- "Should the metrics store (metrics.json) be gitignored or committed? The current .bestest/.gitignore ignores state/ and reports/. If metrics.json lives in state/, it's gitignored and not shared across the team. If it lives at .bestest/metrics.json (not in state/), it could be committed for team visibility but would create merge conflicts in active development. This needs a conscious design decision." — needs team workflow analysis.

</open_questions>

<confidence_score>
0.9: Direct evidence from all 7 primary spoke files, the config schema, the directory schema, and the scan report schema. The routing architecture, data flow, and aggregation patterns were read in full. The only area with limited evidence is the planned-but-not-yet-built features (dashboard, flakiness tracker, test architecture analysis) — my recommendations for these are based on architectural pattern analysis from the existing spokes plus domain research on agentic aggregation pipelines, not on existing implementations within the skill.
</confidence_score>
