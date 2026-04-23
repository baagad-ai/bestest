# Agent-Agnostic Parallel Dispatch Protocol

Canonical reference for parallel test generation dispatch. All generate spokes (JS/TS, Python, Java, Go) reference this file when the target count exceeds the parallel threshold.

## Detection

Before dispatching, the orchestrator must determine whether the host agent supports subagent invocation. Use this IF/ELSE cascade:

```
IF the "subagent" tool is available (Claude Code / GSD)
  → dispatch_mode = "subagent"
  → mechanism: call subagent tool with agent="bestest-worker", task=<worker instructions>

ELSE IF running in Cursor 2.0+ (multi-agent composer detected)
  → dispatch_mode = "cursor-composer"
  → mechanism: spawn agent tabs via composer API, each with worker instructions

ELSE IF Gemini CLI subagent tools are available
  → dispatch_mode = "gemini-subagent"
  → mechanism: use Gemini subagent dispatch with worker instructions

ELSE IF Kiro workspace skills with script execution detected
  → dispatch_mode = "kiro-scripts"
  → mechanism: invoke bestest skill with worker scope via Kiro workspace

ELSE IF Codex CLI or Windsurf agent dispatch is available
  → dispatch_mode = "cli-agent"
  → mechanism: spawn CLI agent processes with worker instructions

ELSE
  → dispatch_mode = "sequential"
  → mechanism: process targets one at a time through standard generate pipeline
  → NO parallelism — fall back gracefully
```

Detection runs once at the start of each `bestest generate` invocation. If no dispatch tool is found, the entire pipeline runs sequentially without error.

## Dispatch Protocol

The core decision logic for parallel vs sequential generation:

```
IF dispatch_mode != "sequential"
  AND generation.parallel.enabled == true
  AND target_count >= generation.parallel.min_targets
THEN
  1. Partition targets into groups of generation.parallel.group_size (default: 5)
     - Last group may be smaller
     - Each group gets non-overlapping source files (natural by scan partition)
  
  2. For each group:
     - Dispatch one worker with the Worker Instructions Template (see below)
     - Set depth_limit: 1 — worker MUST NOT spawn further workers
     - Worker reads .bestest/config.yaml (read-only) for framework, paths, coverage settings
  
  3. Wait for ALL workers to complete before proceeding
  
  4. Collect structured summaries from each worker
  
  5. Merge quality scores:
     - overall_quality = weighted average of per-worker quality scores
     - flag any individual file below generation.quality_threshold
  
  6. Present merged HITL (Human-In-The-Loop) gate:
     - Show all generated test files grouped by source file
     - Highlight any files below quality threshold
     - User approves/rejects/requests revisions for the ENTIRE batch
  
ELSE
  Process targets sequentially through standard generate pipeline
  (one file at a time, standard HITL gate after each file)
```

### Partitioning Rules

- Source files are grouped by directory proximity — files in the same package/module stay together
- No source file appears in more than one group
- Test file paths are derived from source file paths (no collision possible)
- Group size is capped at `generation.parallel.group_size` (default: 5, max: 10)

## Worker Instructions Template

Each dispatched worker receives these instructions. The structured JSON summary below is a **natural-language template for LLM agents**, not a strict machine-parsed schema — workers should populate it descriptively in their output, and orchestrators should parse it leniently.

```
SIGNAL: BESTEST_WORKER_MODE=true
If you detect this signal, you are running as a dispatched worker. Skip any parallel dispatch decision logic — you MUST NOT re-dispatch or attempt further subagent spawning. Proceed directly to generation for your assigned files.

You are a bestest generation worker. Your task:

1. READ .bestest/config.yaml for framework, paths, and coverage settings.
2. For each source file in your assigned group:
   a. Follow the pre-flight protocol (references/pre-flight-protocol.md)
   b. Follow the language-specific generate spoke:
      - JS/TS: references/spoke-generate.md
      - Python: references/spoke-generate-python.md
      - Java: references/spoke-generate-java.md
      - Go: references/spoke-generate-go.md
   c. Generate test file per conventions in config
   d. Self-assess quality score (0-1) for generated test
3. Output a structured summary:

   {
     "worker_id": "<group_index>",
     "files_processed": <count>,
     "results": [
       {
         "source_file": "<path>",
         "test_file": "<path>",
         "quality_score": <0-1>,
         "issues": ["<issue>" | null]
       }
     ],
     "overall_quality": <weighted average 0-1>
   }

CONSTRAINTS:
- depth_limit: 1 — you MUST NOT dispatch further workers
- Read .bestest/ config as READ-ONLY
- Do NOT modify config, scan reports, or other workers' output
- Target files: <assigned_file_list>
```

## Constraints

These constraints are non-negotiable and apply to ALL parallel dispatch scenarios:

1. **depth_limit: 1** — Workers never spawn workers. The agent tree is exactly 2 levels: orchestrator → workers. No recursive dispatch. Workers MUST detect `BESTEST_WORKER_MODE=true` and skip any dispatch decision logic.

2. **Non-overlapping targets** — Each source file is assigned to exactly one worker group. Test file paths are derived from source paths, so collisions are structurally impossible.

3. **Read-only config** — Workers read `.bestest/config.yaml` and `.bestest/reports/` but MUST NOT modify them during generation. Only the orchestrator updates state after all workers complete.

4. **HITL gate from orchestrator ONLY** — The human review gate fires once, after ALL workers complete. Individual workers do not present HITL gates. The orchestrator merges all results and presents a unified review.

5. **Quality threshold per-file** — Each generated test file is scored independently. Files below `generation.quality_threshold` are flagged in the merged HITL presentation but do not block other files.

6. **Failure isolation** — If one worker fails (crash, timeout, malformed output), other workers continue. The orchestrator reports the failed group and proceeds with available results.

## Config Reference

Parallel dispatch behavior is controlled by `generation.parallel.*` fields in `.bestest/config.yaml`. See `references/config-schema.md` for the full schema.

| Field | Default | Purpose |
|-------|---------|---------|
| `generation.parallel.enabled` | `true` | Allow parallel dispatch when threshold is met |
| `generation.parallel.min_targets` | `5` | Minimum source files to trigger parallel mode |
| `generation.parallel.group_size` | `5` | Max source files per worker |
| `generation.parallel.depth_limit` | `1` | Max dispatch recursion (always 1) |

When `generation.parallel.enabled` is `false` or target count is below `min_targets`, generation runs sequentially regardless of dispatch tool availability.

## Worker Output Format

The structured JSON summary in the Worker Instructions Template is a **natural-language template for LLM agents**, not a strict machine-parsed schema. Workers populate it descriptively in their response text. Orchestrators parse it leniently — missing fields, extra fields, and prose annotations are all acceptable. The goal is human-readable structured output, not strict JSON validation.

## Merged HITL Gate — Parallel Mode

When parallel dispatch was used, the orchestrator presents a **merged HITL gate** that replaces the per-file sequential gate. This section defines the unified review format. All 4 generate spokes reference this section instead of duplicating parallel HITL logic.

### Presentation Format

```
═══════════════════════════════════════════════════
  BESTEST GENERATE — Parallel Results Summary
  Workers: <N>  |  Files: <M>  |  Duration: <T>
═══════════════════════════════════════════════════

  ✅ Worker 1 — 5 files — avg quality: 0.84
     src/auth/login.test.ts .......... 0.91 ✓
     src/auth/logout.test.ts ......... 0.88 ✓
     src/utils/token.test.ts ......... 0.82 ✓
     src/api/users.test.ts ........... 0.78 ✓
     src/middleware/auth.test.ts ...... 0.81 ✓

  ⚠️ Worker 2 — 4 files — avg quality: 0.68
     src/db/connection.test.ts ....... 0.72 ✓
     src/db/migrations.test.ts ....... 0.65 ⚠ (below threshold 0.7)
     src/services/user.test.ts ....... 0.71 ✓
     src/services/order.test.ts ...... 0.64 ⚠ (below threshold 0.7)

  ❌ Worker 3 — FAILED (timeout after 120s)
     src/legacy/processor.test.ts .... ⏳ not generated

───────────────────────────────────────────────────
  Overall quality: 0.76  |  Pass: 8  |  Flag: 2  |  Fail: 1
───────────────────────────────────────────────────

  Actions: [A]pprove all passing  [S]elect files  [R]egenerate flagged  [E]dit
═══════════════════════════════════════════════════
```

### Merge Rules

1. **Quality aggregation**: `overall_quality = sum(per_file_quality) / total_files`. Failed workers contribute 0 to the numerator but count in the denominator.

2. **Per-file threshold**: Files scoring below `generation.quality_threshold` (default: 0.7) are flagged with ⚠. They are written to disk but highlighted for manual review.

3. **Failed worker isolation**: If a worker fails (timeout, crash, malformed output), the orchestrator reports it as ❌ with the affected files. Other workers' results are presented normally.

4. **Single gate, single decision**: The user makes one approve/reject decision for the entire batch. They may approve only the passing files, request regeneration of flagged files, or manually edit.

5. **Sequential fallback**: When parallel dispatch was NOT used (sequential mode), the standard per-file HITL gate from each spoke applies. This merged gate is ONLY for parallel mode.

### Cross-references

All 4 generate spokes reference this section:
- `references/spoke-generate.md` → HITL Gate section notes "when parallel dispatch was used, present the merged HITL gate from `references/parallel-dispatch.md` → Merged HITL Gate — Parallel Mode"
- `references/spoke-generate-python.md` → same reference
- `references/spoke-generate-java.md` → same reference
- `references/spoke-generate-go.md` → same reference

## Platform Compatibility Matrix

| Platform | Dispatch Mechanism | Skill Format | Isolation Model |
|----------|-------------------|--------------|-----------------|
| Claude Code / GSD | `subagent` tool with named agent profiles | SKILL.md in `~/.agents/skills/` or `.claude/skills/` | Separate process per subagent, isolated context |
| Cursor 2.0+ | Multi-agent composer tabs | `.cursor/rules/` + agent config | Tab-level isolation, shared workspace |
| Gemini CLI | Subagent dispatch tools | Gemini agent config | Process-level isolation |
| Kiro | Workspace skills with script execution | `.kiro/skills/` | Workspace-scoped, script sandbox |
| Codex CLI | CLI agent process spawning | Agent YAML config | Process-level isolation |
| Windsurf | Agent dispatch via Cascade | `.windsurfrules/` + agent config | Tab/session isolation |

**Fallback behavior:** If none of these dispatch mechanisms are detected, bestest falls back to sequential processing. No error is raised — sequential mode is the safe default that works everywhere.
