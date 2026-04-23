<role_identity>
role: "Quality & Coverage Analyst"
domain: "Test health observability, legacy framework edge cases, flakiness detection reliability"
skill_name: "bestest"
focus_questions:
  - "How well does the existing `doctor` command cover observability requirements — can it evolve into a health dashboard backend?"
  - "The skill claims Vitest, Jest, pytest, JUnit 5, Go testing — how complete is coverage for existing/legacy frameworks (Mocha, Jasmine, TestNG, etc.)?"
  - "What edge cases emerge when the skill encounters existing test infrastructure it didn't generate — conflicting configs, partial coverage, mixed frameworks?"
  - "What metrics should a test health observability system track, and what are the edge cases in computing them (e.g., flakiness detection false positives)?"
files_reviewed:
  - "SKILL.md"
  - "references/spoke-init.md"
  - "references/spoke-scan.md"
  - "references/spoke-doctor.md"
  - "references/spoke-fix.md"
  - "references/spoke-coverage.md"
  - "references/spoke-report.md"
  - "references/anti-patterns.md"
  - "references/detection-engine.md"
</role_identity>

<executive_summary>
Bestest's primary strength is its deep, structured analysis pipeline — the 9-dimension doctor scoring, 20-category anti-pattern catalog, and 4-category failure taxonomy form a genuinely comprehensive test health assessment framework. The most critical weakness is the gap between detection breadth and action breadth: the detection engine identifies Mocha, Jasmine, TestNG, Ava, and other legacy frameworks, but the generation, fix, and migration spokes only handle Vitest, Jest, pytest, JUnit 5, and Go testing. This means the skill can *diagnose* a legacy project but cannot meaningfully *improve* it beyond basic anti-pattern reporting. The overall risk level is **high** because the user's transformation goals (handle existing infrastructure + add observability) expose this exact gap.
</executive_summary>

<findings>

<finding>
id: F1
severity: critical
file: "SKILL.md (routing section) + references/spoke-generate*.md"
line_ref: "L34–L54 (routing table)"
observation: "The detection engine detects Mocha, Jasmine, TestNG, Ava, and other legacy frameworks (Phase 5 in detection-engine.md uses category-based conflict detection for 'same-category-competing' pairs like Vitest+Mocha), but the generation, fix, and migration spokes have zero support for these frameworks. The generate routing table maps only JS/TS→spoke-generate.md, Python→spoke-generate-python.md, Java→spoke-generate-java.md, Go→spoke-generate-go.md. There is no spoke-generate-mocha.md, spoke-generate-jasmine.md, or spoke-migrate for legacy frameworks (except jest→vitest, junit4→junit5, cypress→playwright)."
evidence: "SKILL.md routing table explicitly lists: 'generate (JS/TS) → references/spoke-generate.md', 'generate (Python) → references/spoke-generate-python.md', 'generate (Java) → references/spoke-generate-java.md', 'generate (Go) → references/spoke-generate-go.md'. Migration paths are limited to: 'jest→vitest, junit4→junit5, cypress→playwright'. Detection-engine.md Phase 5 lists category-based conflict detection including Mocha, Jasmine, TestNG — these are detected but not actionable."
impact: "When a user runs `/bestest generate` on a Mocha, Jasmine, or TestNG project, the skill detects the framework, generates a StackProfile, but then either routes to a Vitest/Jest generate spoke (incorrect) or fails silently. The init spoke's HITL gate recommends Vitest/Jest over Mocha/Jasmine/TestNG, but cannot generate or fix tests in the existing framework. This is the #1 blocker for the user's goal of handling existing test infrastructure."
confidence: 0.95
</finding>

<finding>
id: F2
severity: critical
file: "references/spoke-doctor.md"
line_ref: "Phase 1–11 (entire spoke)"
observation: "The doctor command produces a single-point-in-time health report with no historical aggregation, no time-series storage, and no visualization-ready data format. Reports are individual JSON files in `.bestest/reports/doctor-<timestamp>.json` with no cross-report index. The composite score is computed fresh each run with no retention of previous scores for trend comparison. There is no metric export capability (no Prometheus, OpenTelemetry, or webhook support)."
evidence: "spoke-doctor.md Phase 11 writes a single `doctor-<timestamp>.json` file. The scoring formula (Phase 'Composite Scoring') computes `compositeScore = sum(score * weight) / sum(weight)` on current data only. No mention of historical trend persistence, alerting thresholds, or metric export. The report output format is JSON for single consumption, not time-series data."
impact: "Doctor cannot serve as a health dashboard backend without substantial additions: (1) a time-series aggregation layer over the individual report files, (2) configurable alerting thresholds per dimension, (3) metric export in standard formats, (4) a summary API endpoint or CLI query for latest scores. The user's transformation goal of 'test health observability with visualizations' requires all four."
confidence: 0.9
</finding>

<finding>
id: F3
severity: major
file: "references/spoke-scan.md"
line_ref: "Phase 4 (Analyze Test Quality) — anti-pattern grep tables"
observation: "The anti-pattern detection grep patterns are Vitest/Jest-centric for JS/TS, pytest-centric for Python, JUnit 5-centric for Java, and Go-stdlib-centric. Mocha-style tests (`describe()`, `it()`, `before()`, `after()` with done callbacks), Jasmine-style tests (`describe()`, `it()`, `expect(x).toBe(y)` without import), TestNG annotations (`@Test`, `@DataProvider`, `@Parameters`), and Ava tests (`test()` with default exports) use different APIs that the grep patterns partially match but were not designed for."
evidence: "spoke-scan.md Phase 4 grep tables use: `expect\(([^)]+)\)\.(toBe|toEqual|toStrictEqual)\(\1\)` — this assumes `expect().toBe()` syntax (Jest/Vitest). Jasmine uses `expect(x).toBe(y)` directly (same syntax but different mock APIs: `spyOn` vs `vi.fn()`). Mocha uses `done()` callbacks not covered in the 'Test Interdependencies' detection. Java grep targets `assertEquals`, `Assertions.`, `verify(` — TestNG uses `Assert.assertEquals()` which partially matches but `@DataProvider` patterns are absent."
impact: "Anti-pattern detection on Mocha/Jasmine/TestNG projects will have false negatives for framework-specific patterns (e.g., Mocha's `done()` callback issues, Jasmine's `spyOn` without `and.callThrough()`, TestNG's `@DataProvider` without assertions). It will also have false positives where framework-specific APIs are misidentified as anti-patterns."
confidence: 0.85
</finding>

<finding>
id: F4
severity: major
file: "references/spoke-scan.md"
line_ref: "Phase 5 (Detect Flaky Tests) — flakiness signal detection"
observation: "The flakiness detection uses static signal analysis with binary grep-based matching, producing both false positives and false negatives. False positives: (1) `time.Now()` in Go test that's used for logging, not assertion, is flagged as `uncontrolled-time`; (2) `time.Sleep()` in test setup (not in assertion path) flagged as `sleep-based-waits`; (3) `requests.get()` in integration test files is excluded by directory check, but files in non-standard paths (e.g., `test_integration/` instead of `tests/integration/`) would be falsely flagged. False negatives: (1) tests that always pass but validate nothing (not caught by any flakiness signal); (2) resource leaks (open connections, file handles) that cause intermittent failures not detected by any signal category; (3) database state contamination between tests not using shared-state detection."
evidence: "spoke-scan.md Phase 5 Step 1: 'Grep for `time.Now()`, `time.Sleep()` without injection' — no distinction between assertion path and setup/logging path. Step 1: 'Exclude files in `e2e/` directories' — but the exclusion patterns are hardcoded to specific directory names. Step 4 risk level: '3+ signals detected' — but signal quality is not weighted (a low-signal `filesystem-access` counts same as high-signal `network-calls`)."
impact: "Flakiness detection will produce noisy reports on real projects: (1) developers will learn to ignore flaky test warnings if 30%+ are false positives, (2) genuinely flaky tests caused by resource leaks or database contamination will be missed, (3) the risk-level categorization ('high' for 3+ signals) can be gamed by tests that legitimately use multiple APIs (e.g., a test that reads config from filesystem and makes network calls)."
confidence: 0.8
</finding>

<finding>
id: F5
severity: major
file: "references/spoke-init.md"
line_ref: "Phase 3 (HITL Gate) — conflict resolution"
observation: "When the skill encounters existing test infrastructure with conflicting frameworks (e.g., a project with both Mocha and Jest configs, or Jasmine + Karma), the init spoke's HITL gate presents the conflict but only offers three options: accept recommendation, keep both, or select an alternative from the *recommended* frameworks (Vitest, Jest). There is no option to keep and work within the existing legacy framework."
evidence: "spoke-init.md Phase 3 Response Handling: 'modify: Allow the user to override specific values: --framework <vitest|jest>'. The modify options list only `vitest` and `jest` as valid overrides. Detection-engine.md Phase 5 conflict detection identifies Mocha, Jasmine, TestNG — but init's HITL gate doesn't offer these as selectable frameworks."
impact: "Users with existing Mocha/Jasmine/TestNG infrastructure who run `/bestest init` are forced into a framework migration they may not want. The skill positions itself as a testing architect but can only architect within its supported frameworks — it cannot serve as a health/quality tool for projects that want to stay on their existing framework."
confidence: 0.9
</finding>

<finding>
id: F6
severity: major
file: "references/spoke-doctor.md"
line_ref: "Phase 4 (Coverage Trend) — data point extraction"
observation: "The coverage trend computation has an edge case with mixed data sources: when a project has both `run-*.json` reports and `scan-*.json` reports, the trend uses coverage from both, but scan reports and run reports may measure coverage differently (scan uses `--coverage` flag output, run uses standard coverage output). This can produce misleading trend arrows — e.g., coverage appears to 'drop' when switching from run-based to scan-based data, even though actual coverage hasn't changed."
evidence: "spoke-doctor.md Phase 4 Step 1: 'dataPoints = []. For each run report... For each scan report...' — both sources are mixed into the same timeline without source differentiation. Step 3: 'delta = newest - oldest' — no normalization between scan and run coverage measurement methodologies."
impact: "The coverage trend indicator in doctor reports can show false decline/improvement when data sources switch. This undermines trust in the health score. A dashboard backend would amplify this problem since trends would be displayed graphically."
confidence: 0.75
</finding>

<finding>
id: F7
severity: major
file: "references/spoke-scan.md"
line_ref: "Phase 2 (Discover Tests) — test count extraction"
observation: "The test counting logic has edge cases with parameterized/dynamic tests across frameworks. For JS/TS, `test.each`/`it.each` parsing requires extracting row counts from data arrays, which fails for computed arrays (`test.each(generateCases())`) — marked as `-1`. For Python, `@pytest.mark.parametrize` with indirect parametrization (`pytest_generate_tests`) is also marked `-1`. For Java, `@TestFactory` dynamic tests are `-1`. These `-1` entries propagate through the summary counts, making `summary.totalTests` unreliable (it sums `-1` as a valid count)."
evidence: "spoke-scan.md Phase 2 Step 3: 'Dynamic test generation: if the count cannot be determined statically, mark it as `-1` and note "dynamic" in the report.' Step 5: 'summary.totalTests = sum of all `tests` fields' — if a file has `tests: -1`, this propagates into the sum."
impact: "Total test counts in scan reports are unreliable for projects using dynamic test generation. Doctor's dead-test percentage (`deadPct = deadCount / totalCount * 100`) divides by `totalCount` which may include `-1` entries, producing nonsensical percentages. The health score's dead-tests dimension would be inaccurate."
confidence: 0.85
</finding>

<finding>
id: F8
severity: minor
file: "references/spoke-doctor.md"
line_ref: "Phase 2 (Framework Version Check) — version comparison"
observation: "The framework version comparison does not account for pre-release versions, nightly builds, or backported patches. The scoring table compares '1 minor behind = 80, 1 major behind = 40' but `1.5.0-beta.1` vs `1.5.0` would be scored as 'current' rather than 'pre-release' (which might deserve a slightly lower score). Similarly, `2.0.0-alpha.3` vs `1.6.0` would score 40 (1 major behind) when it's actually ahead on the pre-release channel."
evidence: "spoke-doctor.md Phase 2 Step 3: 'Parse major.minor.patch for both installed and latest. If majorDiff >= 2: score = 0. Else if majorDiff == 1: score = 40...' — no handling for pre-release identifiers in semver (e.g., `-beta`, `-alpha`, `-rc`)."
impact: "Minor scoring inaccuracy for projects using pre-release or nightly versions of test frameworks. Low impact on overall health score since framework version has weight 1.0 (lowest alongside execution time)."
confidence: 0.7
</finding>

<finding>
id: F9
severity: informational
file: "references/spoke-report.md"
line_ref: "Phase 3 (Generate Markdown Report) — entire section"
observation: "The report spoke already produces rich markdown output with coverage heatmap, flaky test trends, anti-pattern distribution, and prioritized action items. It includes multi-language support with emoji indicators. This is a strong foundation for visualization — the data structures (coverage heatmap, trend timelines, severity distributions) map well to dashboard widgets (sparklines, heat grids, severity donuts)."
evidence: "spoke-report.md Phase 2: 'Coverage Heatmap: Assign emoji indicator: coverage >= 80%: 🟢, coverage >= 50%: 🟡, coverage > 0%: 🔴, coverage == 0%: ⬛'. Phase 3 Section 2: 'Per-module coverage table with emoji indicators'. Phase 2: 'Flaky Test History: aggregate across all scan reports'. Phase 2: 'Anti-Pattern Distribution: grouped by severity and pattern type'."
impact: "The report spoke's data structures can be directly consumed by a visualization layer. The markdown format is already structured (tables with fixed schemas) and could be parsed or the underlying JSON reports could feed a dashboard API. This reduces the effort needed for the user's visualization goal."
confidence: 0.9
</finding>

<finding>
id: F10
severity: informational
file: "references/anti-patterns.md"
line_ref: "Categories 13–20 (extended catalog)"
observation: "The anti-pattern catalog has 20 well-defined categories with severity levels, detection methods, and examples. The extended categories (13–20: Mystery Guest, Hardcoded Test Data, Mock Overuse, Assertion Roulette, Happy Path Only, Fragile Selectors, Complex Test Logic, Missing Cleanup) provide strong coverage of AI-generated test quality issues. This catalog is one of the skill's strongest assets and requires minimal extension for observability purposes."
evidence: "anti-patterns.md defines 20 categories with: severity (critical/high/medium/low), grep patterns, evaluation criteria, examples (BAD/GOOD), and cross-reference notes. Categories 13–20 were specifically added 'to provide comprehensive coverage of test smells required for AI-generated test quality auditing (per R012)'."
impact: "The anti-pattern catalog is ready to serve as the basis for trend tracking in a health dashboard. Each category maps to a metric that can be tracked over time (e.g., 'missing-assertions count per sprint')."
confidence: 0.95
</finding>

</findings>

<dimension_scores>

| Dimension | Score (1–5) | Rationale |
|-----------|-------------|-----------|
| Legacy Framework Coverage | 2 | Detection engine identifies legacy frameworks but generation/fix/migration spokes have zero support for them — diagnosis without treatment. |
| Observability Readiness | 3 | Doctor's 9-dimension scoring and report's structured output provide a solid foundation, but no time-series aggregation, alerting, or metric export capability. |
| Edge Case Handling | 3 | Pre-flight checks and error handling are thorough for supported frameworks, but critical edge cases in dynamic test counting, mixed data sources, and false-positive flakiness detection are unhandled. |
| Anti-Pattern Detection Depth | 4 | 20 well-categorized patterns with language-specific grep tables, severity levels, and cross-reference notes — comprehensive and well-structured. |
| Flakiness Detection Reliability | 3 | Good signal taxonomy (9 categories per language) but binary grep-based matching produces both false positives (setup code flagged) and false negatives (resource leaks missed). |

</dimension_scores>

<recommendations>

1. **Add legacy framework compatibility layer for generation and fix spokes** (addresses: F1, F5, effort: high)
   For Mocha, Jasmine, and TestNG: create adapter modules that translate the existing generate/fix spoke's output into legacy framework syntax. Start with Mocha (most common legacy JS framework): Mocha uses `describe/it` (same as Jest) but different mock APIs (`sinon` vs `vi.fn`) and assertion libraries (`chai.expect` vs `expect`). The init HITL gate should offer detected legacy frameworks as selectable options alongside Vitest/Jest.

2. **Add time-series aggregation layer to doctor for dashboard readiness** (addresses: F2, effort: medium)
   Create a `.bestest/state/health-timeline.json` file that doctor appends to on each run (timestamp + composite score + per-dimension scores). Add a `doctor --history` flag that outputs the full timeline as JSON, consumable by visualization tools. This is the minimum viable change to support dashboard backends — the individual `doctor-*.json` reports remain for detailed drill-down.

3. **Normalize coverage trend data across mixed sources** (addresses: F6, effort: low)
   Tag each data point in the coverage timeline with its source type (`run` or `scan`). When computing trends, weight or normalize based on source methodology. At minimum, add a warning when the data source type changes between consecutive data points: "Coverage trend comparison mixes run and scan data — readings may differ due to measurement methodology."

4. **Fix dynamic test count propagation bug** (addresses: F7, effort: low)
   In scan Phase 2 Step 5, filter out `tests: -1` entries before computing `summary.totalTests`. Track `summary.dynamicTests` as a separate count. Update doctor's dead-test computation to exclude dynamic tests from the denominator. This is a one-line fix in the counting logic that prevents nonsensical percentages.

5. **Reduce flakiness detection false positives with path-aware signal filtering** (addresses: F4, effort: medium)
   Add AST-level (or regex-level) function boundary detection to distinguish between signal usage in assertion paths vs. setup/logging paths. For Go: only flag `time.Now()` if it appears in a comparison or assertion context, not in `t.Log()` calls. For Python: only flag `time.sleep()` if it appears between a function call and an assertion, not in fixture setup. Add configurable exclusion patterns for project-specific non-standard test directories.

6. **Extend anti-pattern detection tables for legacy framework APIs** (addresses: F3, effort: medium)
   Add framework-specific grep patterns to the anti-pattern detection tables: Mocha (`done()` callback issues, `this.timeout()` in test bodies), Jasmine (`spyOn` without `and.callThrough()`, `jasmine.createSpyObj` overuse), TestNG (`@DataProvider` return types, `@Parameters` without conversion). These can be added as additional rows in the existing per-language detection tables without structural changes.

7. **Add metric export capability for observability integration** (addresses: F2, effort: medium)
   Add a `doctor --format prometheus` flag that outputs metrics in Prometheus exposition format (e.g., `bestest_health_score 82`, `bestest_coverage_lines_pct 82.7`, `bestest_flaky_tests_count 2`). Add `doctor --webhook <url>` to POST the health report JSON to an external endpoint. These enable integration with Grafana, Datadog, or custom dashboards without requiring bestest to build its own visualization layer.

</recommendations>

<open_questions>

- "Can the detection engine's category-based conflict detection be extended to produce framework-specific adapter selections at runtime?" — needs architectural decision on whether adapters are separate spoke files or conditional branches within existing spokes.

- "What is the user's target visualization platform?" — needs user input to determine whether to build a built-in HTML dashboard (e.g., using the report spoke's markdown as a base), integrate with external tools via metric export, or both.

- "Are there existing test health dashboard implementations (e.g., CircleCI test insights, Jest circus reporting) that should inform the data model?" — needs research on existing tools to ensure the time-series schema is compatible with industry patterns.

</open_questions>

<confidence_score>
0.88 — Direct evidence from all 9 primary skill files (SKILL.md, 7 spokes, anti-patterns.md, detection-engine.md). Research queries confirmed edge-case patterns from industry literature (legacy framework analysis challenges, flakiness false positive mechanisms). Two areas of uncertainty: (1) whether the generate spokes' language-specific sub-files (6 per language) have additional framework-specific logic that wasn't visible in the top-level spoke files, and (2) whether the user's "rename to plugin" goal implies a packaging/distribution change that affects the skill's internal architecture.
</confidence_score>
