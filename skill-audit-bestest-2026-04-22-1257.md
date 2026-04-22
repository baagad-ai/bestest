# Skill Audit: bestest

<overview>
skill_name: "bestest"
skill_path: "~/.agents/skills/bestest"
complexity_tier: "enterprise"
experts_consulted: "Prompt Architect, Technical Writer Auditor, Cognitive Load Analyst, Agentic Workflow Designer, Quality & Coverage Analyst, Security & Injection Auditor, Output Contract Reviewer, Enterprise Readiness Auditor"
review_date: "2026-04-22"
overall_risk: "high"
one_line_verdict: "An impressively comprehensive testing architect skill with strong verification pipelines and consistent spoke structure, undermined by deep redundancy between SKILL.md and spoke files, missing schema versioning, and no confidence gating in the detection-to-generation pipeline."
</overview>

<structural_health>

| Check | Result | Detail |
|-------|--------|--------|
| YAML frontmatter present | ✅ | name + description fields present |
| SKILL.md line count | 536 lines | K002 VIOLATION — exceeds 500 line maximum |
| No markdown headings in SKILL.md body | ❌ | K001 VIOLATION — 49 markdown headings (## and ###) |
| workflows/ directory present | ❌ | 0 workflow files (spokes live in references/) |
| Output contracts defined | ✅ | stack-profile-schema.md, scan-report-schema.md, config-schema.md |
| Subagent dispatch present | ❌ | No subagent dispatch detected |
| User input accepted | ✅ | HITL gates in init and generate spokes |
| External service calls | ✅ | resolve_library, get_library_docs (Context7 integration) |

Structural violations detected:
- major K002: SKILL.md has 536 lines; maximum is 500 in SKILL.md
- minor K001: SKILL.md body contains 49 markdown headings; use XML tags instead in SKILL.md

</structural_health>

<maturity_scorecard>

| Dimension | Score (1–5) | Scored By | Key Evidence |
|-----------|-------------|-----------|--------------|
| Prompt Clarity | 3.2 | Prompt Architect, Cognitive Load Analyst, Technical Writer Auditor | Dual hierarchy (XML + markdown headings) forces agents to navigate two competing structural systems. Routing tables are unambiguous once found but buried behind detection internals. |
| Workflow Robustness | 3.1 | Agentic Workflow Designer, Output Contract Reviewer | Strong within-spoke phase structure (pre-flight → phases → HITL → output). Cross-spoke handoffs are fragile: no confidence gating, no staleness detection, no state coherence checks. |
| Security Posture | 2.8 | Security & Injection Auditor | Good HITL gates before commits, source-file boundary in fix spoke. Gaps: Context7 content injected without taint tracking, no path traversal validation, no secret scanning tool integration. |
| Quality Coverage | 3.3 | Quality & Coverage Analyst | Genuine 7-phase verification pipeline (compile → execute → coverage → quality audit → flakiness). Weak conflict resolution when detection signals disagree. |
| Enterprise Readiness | 3.5 | Enterprise Readiness Auditor | Solid architectural foundation, comprehensive documentation, 4-language support. Missing concurrency protection, skill-level versioning, and contributor onboarding guide. |

**Overall Maturity Score: 3.2 / 5.0**
**Maturity Tier: v1-ready**

</maturity_scorecard>

<per_role_highlights>

| Role | 1-Sentence Finding | Highest Severity | Confidence |
|------|--------------------|-----------------|------------|
| Prompt Architect | Dual XML/markdown hierarchy and 536-line SKILL.md create structural ambiguity; decision tree gap zones break determinism guarantee | major | 0.82 |
| Technical Writer Auditor | No 60-second onboarding path — command table buried behind 430 lines of detection internals | major | 0.88 |
| Cognitive Load Analyst | Severe redundancy: detection phases, decision trees, and Context7 helper duplicated 2-3x across SKILL.md and spoke files | critical | 0.88 |
| Agentic Workflow Designer | No minimum confidence threshold allows low-confidence StackProfile to silently route to wrong generation spoke | critical | 0.87 |
| Quality & Coverage Analyst | Strong 7-phase verification pipeline but no conflict resolution when both Jest and Vitest are detected | major | 0.85 |
| Security & Injection Auditor | Context7-fetched docs injected without sanitization; file paths accepted without traversal validation | major | 0.82 |
| Output Contract Reviewer | Go framework identifier mismatch (go-testing vs go_testing) between schemas; no versioning on 2 of 3 schemas | critical | 0.85 |
| Enterprise Readiness Auditor | No concurrency protection on .bestest/ state, no skill-level versioning, no contributor onboarding guide | major | 0.82 |

</per_role_highlights>

<cross_cutting_findings>

<cross_finding>
id: X1
raised_by: "Prompt Architect, Cognitive Load Analyst, Technical Writer Auditor"
finding: "SKILL.md contains ~270 lines of reference material (detection_engine, framework_decision, context7_helper) that only init and generate commands need, but it loads on every invocation. Three experts independently identified these same sections as misplaced content causing K002 violation and token waste."
why_it_matters: "For 13 of 15 commands (fix, coverage, doctor, report, run, scan, config, expand, migrate, ci, etc.), the agent loads ~2K tokens of detection logic, decision trees, and Context7 mappings it will never use. This is the single most impactful structural fix available."
</cross_finding>

<cross_finding>
id: X2
raised_by: "Prompt Architect, Cognitive Load Analyst"
finding: "The 7-phase detection sequence and all four framework decision trees are fully specified in both SKILL.md AND spoke-init.md — verbatim duplication. The Context7 helper pattern is triplicated across SKILL.md, spoke-init.md, and spoke-generate.md."
why_it_matters: "Any update to detection logic must be synchronized across 2-3 files or they will diverge — a latent correctness bug. The agent reads the same logic twice during init flows, wasting ~3K tokens and creating reconciliation overhead."
</cross_finding>

<cross_finding>
id: X3
raised_by: "Agentic Workflow Designer, Quality & Coverage Analyst"
finding: "No minimum confidence threshold exists anywhere in the pipeline. A StackProfile with TypeScript at 0.35 confidence (because only a few .ts files were found) routes identically to one with 0.98 confidence. The generate spoke's pre-flight only checks for file existence, not confidence quality."
why_it_matters: "An ambiguous or misdetected stack will silently route to the wrong generation spoke, producing syntactically valid but contextually wrong test files. The user only discovers this after the entire 7-phase generation pipeline has run."
</cross_finding>

<cross_finding>
id: X4
raised_by: "Agentic Workflow Designer, Output Contract Reviewer"
finding: "SKILL.md's detection engine and spoke-init.md's Phase 1 implement different detection depths — init has expanded Java/Go sub-steps not present in the canonical spec. Different code paths produce different StackProfiles from the same repository."
why_it_matters: "Non-deterministic detection depending on which code path executes. If generate re-runs detection instead of reading the cached StackProfile, it may get a different result than init produced."
</cross_finding>

<cross_finding>
id: X5
raised_by: "Output Contract Reviewer, Technical Writer Auditor"
finding: "StackProfile and scan-report schemas have no version field; only config has version '1.0'. No migration strategy is documented for any schema. The version on config is described as 'do not edit' with no migration logic in any spoke."
why_it_matters: "Any field addition, rename, or removal in StackProfile or scan-report is a silent breaking change. Downstream consumers cannot detect schema version and may misinterpret data."
</cross_finding>

<cross_finding>
id: X6
raised_by: "Quality & Coverage Analyst, Security & Injection Auditor"
finding: "When both Jest and Vitest are detected with high confidence (common in migrating codebases), the StackProfile schema records a single string for testFrameworks.existing, silently overwriting one. The HITL gate presents only the final recommendation, hiding the conflict."
why_it_matters: "Dual-framework repos get an incorrect single-framework recommendation. The user cannot make an informed 'modify' choice because the conflict data is hidden from the HITL gate."
</cross_finding>

</cross_cutting_findings>

<contradictions>

<contradiction>
topic: "Decision tree determinism"
expert_a: "Prompt Architect says the JS/TS tree has gap zones (20-50 file range with moderate config, unknown frontend HITL branch) that break the stated determinism guarantee"
expert_b: "Agentic Workflow Designer says decision trees are 'deterministic by design' with clean phase sequencing"
resolution: "Prompt Architect's evidence is stronger — the 20-50 file gap zone in JS/TS Step 3 has no explicit else/default branch, and the 'Unknown frontend' branch in Step 6 introduces session-variable behavior. The determinism guarantee is aspirational, not fully realized."
</contradiction>

</contradictions>

<prioritized_recommendations>

| Rank | Recommendation | Source | Effort | Impact |
|------|---------------|--------|--------|--------|
| 1 | Extract detection_engine, framework_decision, context7_helper from SKILL.md into dedicated reference files; bring SKILL.md to ~300 lines | X1, X2 | medium | Eliminates K002 violation, saves ~2K tokens/invocation, removes dual-maintenance |
| 2 | Add minimum confidence gate (0.6 threshold) before routing to generation spoke; warn user on low confidence | X3 | medium | Prevents silent wrong-routing on ambiguous stacks |
| 3 | Fix go-testing/go_testing identifier mismatch between StackProfile and config schemas; create canonical enum registry | OCR:F1 | low | Fixes hard failure for entire Go ecosystem |
| 4 | Add version fields to StackProfile and scan-report schemas; document versioning policy | X5 | low | Enables safe schema evolution |
| 5 | Deduplicate detection and decision-tree content: keep in spoke-init.md exclusively, add one-line pointer in SKILL.md | X2 | medium | Eliminates ~240 lines of redundancy, prevents divergence |
| 6 | Add conflict resolution when both Jest and Vitest detected; surface conflict in HITL gate | X6 | medium | Prevents wrong framework recommendation for migrating codebases |
| 7 | Canonicalize detection engine: move expanded Java/Go steps into shared reference, eliminate divergence | X4 | low | Ensures consistent StackProfile regardless of execution path |
| 8 | Add taint markers for Context7-fetched content; instruct agent to treat as documentation-only | SIA:F1 | medium | Closes indirect prompt injection vector |
| 9 | Add path canonicalization and boundary validation for user-provided file paths | SIA:F2 | low | Prevents path traversal in generate/fix/scan commands |
| 10 | Add skill-level versioning (version field in SKILL.md frontmatter + CHANGELOG) | ERA:F2 | low | Enables reproducibility tracing and upgrade detection |
| 11 | Create CONTRIBUTING.md with spoke template and language-addition guide | ERA:F3 | medium | Reduces contributor onboarding from hours to minutes |
| 12 | Add explicit else/default branch to JS/TS decision tree Step 3 (20-50 file range) | PA:F3 | low | Restores determinism guarantee |
| 13 | Harmonize flakiness signal identifiers between spoke-scan Phase 5 and scan-report-schema | OCR:F2 | medium | Prevents schema validation failures on flakiness data |
| 14 | Add report rotation (configurable max count, default 50) to prevent unbounded .bestest/reports/ growth | ERA:F6 | low | Prevents progressive slowdown in long-running CI |
| 15 | Change fix spoke default classification from test_bug to unknown; skip auto-fix on ambiguity | QCA:F7 | low | Prevents incorrect test modifications on unclassifiable failures |

</prioritized_recommendations>

<remediation_plan>

**Phase 1 — Blockers (fix before any broader use)**

These cause hard failures or silent data corruption:

- [ ] Fix go-testing/go_testing identifier mismatch in schemas (Rank 3) — Go projects fail silently
- [ ] Add minimum confidence gate to generation routing (Rank 2) — Wrong test generation on ambiguous stacks
- [ ] Extract heavy sections from SKILL.md to fix K002 violation (Rank 1) — Structural violation on every load

Estimated effort: 2-3 hours

**Phase 2 — Quality (fix before broader rollout)**

These improve correctness and prevent divergence:

- [ ] Deduplicate detection/decision-tree content (Rank 5) — Dual-maintenance risk
- [ ] Add conflict resolution for dual-framework detection (Rank 6) — Wrong recommendations
- [ ] Canonicalize detection engine across SKILL.md and spoke-init.md (Rank 7) — Non-deterministic detection
- [ ] Add version fields to StackProfile and scan-report schemas (Rank 4) — Silent breaking changes
- [ ] Add taint markers for Context7-fetched content (Rank 8) — Indirect prompt injection
- [ ] Harmonize flakiness signal identifiers (Rank 13) — Schema validation failures

Estimated effort: 4-6 hours

**Phase 3 — Polish (fix when convenient)**

Improvements that reduce friction or improve maintainability:

- [ ] Add path canonicalization for user-provided paths (Rank 9)
- [ ] Add skill-level versioning to SKILL.md (Rank 10)
- [ ] Create CONTRIBUTING.md with spoke template (Rank 11)
- [ ] Add else/default branch to JS/TS decision tree (Rank 12)
- [ ] Add report rotation (Rank 14)
- [ ] Change fix spoke default classification to unknown (Rank 15)

Estimated effort: 3-4 hours

**Phase 4 — Monitoring (ongoing)**

Items that need periodic review:

- [ ] Monitor Context7 content quality for injection patterns — review quarterly
- [ ] Validate schema consistency when adding new language spokes — per-contribution
- [ ] Audit spoke pre-flight check synchronization after spoke modifications — per-change

</remediation_plan>

<open_questions>

- "What is the exact confidence scoring formula?" — raised by Agentic Workflow Designer; needs a computation spec in detection-signals.md with worked examples
- "Does Context7 have its own content sanitization pipeline?" — raised by Security & Injection Auditor; needs Context7 platform verification to determine F1 severity adjustment
- "Are the unread spoke files (fix, coverage, expand, run, config) consistent with schema contracts?" — raised by Output Contract Reviewer; needs full spoke audit to confirm no additional contract violations
- "What happens when the agent runtime has built-in path validation that the skill doesn't document?" — raised by Security & Injection Auditor; needs agent-framework-specific testing

</open_questions>

<run_metadata>
skill_version: "1.0"
skill_audited: "bestest"
roles_dispatched: [Prompt Architect, Technical Writer Auditor, Cognitive Load Analyst, Agentic Workflow Designer, Quality & Coverage Analyst, Security & Injection Auditor, Output Contract Reviewer, Enterprise Readiness Auditor]
completed_roles: 8/8
failed_roles: none
timed_out_roles: none
run_date: 2026-04-22
estimated_token_cost: "~8000 tokens (8 roles × ~1000 tokens each)"
maturity_score: "3.2/5.0 (v1-ready)"
overall_risk: "high"
</run_metadata>
