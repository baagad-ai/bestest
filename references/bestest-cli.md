# bestest CLI Helper

The deterministic helper layer for the bestest skill. `scripts/bestest-cli.py` (stdlib-only Python 3.8+) owns the *mechanical* operations that spokes previously described only in prose. It runs in any project with `python3` available; when it is not available, spokes fall back to the documented manual steps (graceful degradation — a core bestest principle).

## Why a CLI?

The skill is a markdown spec — the agent's judgment drives strategy, framework selection, and test generation. But file I/O and report bookkeeping were pure prose, which let behavioral drift slip in (e.g., a spoke reading a field name the schema doesn't define). The CLI makes the mechanical operations **deterministic**:

- Report selection (with companion filtering) follows the exact priority chain in `data-source-discovery.md`.
- Config read/write/validate follows `config-schema.md` field rules.
- Metrics merges are schema-shaped and atomic.
- Locks follow the Concurrency Lock Protocol in `pre-flight-protocol.md`.

## Invocation

```
python3 <skill-dir>/scripts/bestest-cli.py <subcommand> [args]
# or, via the wrapper (resolves its own location):
<skill-dir>/scripts/bestest <subcommand> [args]
```

Every subcommand emits a single JSON object to stdout (agent-parseable). Use `--human` for pretty-printed output. Exit code is `0` on success, `1` on operational failure, `2` when `python3` is unavailable.

## Subcommands

| Subcommand | Responsibility | Example |
|------------|----------------|---------|
| `detect [--phase N]` | Deterministic stack/language/toolchain signal scan → StackProfile-shaped JSON | `bestest-cli detect` |
| `config validate` | Validate `.bestest/config.yaml` (required fields + version) | `bestest-cli config validate` |
| `config read <dot.path>` | Read a config field by dot path | `bestest-cli config read coverage.target` |
| `config write <dot.path> <value>` | Write a config field atomically, preserving all other fields | `bestest-cli config write state.last_scan "2026-05-01T00:00:00Z"` |
| `report list [--kind K] [--latest]` | List reports of a kind, newest-first | `bestest-cli report list --kind run` |
| `report latest-full` | Resolve the authoritative data source per `data-source-discovery.md` priority chain (non-companion run → scan → companion run) | `bestest-cli report latest-full` |
| `lock acquire <name>` / `lock release <name>` | Acquire/release an advisory lock (flock, mkdir fallback) | `bestest-cli lock acquire .metrics` |
| `metrics read` | Read `.bestest/state/metrics.json` | `bestest-cli metrics read` |
| `metrics merge <section> <json-file>` | Merge a JSON payload into `metrics.json` under a section, atomically | `bestest-cli metrics merge tests /tmp/tests.json` |
| `render <template-path> <json-params>` | Fill `{{placeholder}}` values in a template | `bestest-cli render templates/testing-md.md '{"coverage_target":"80"}'` |
| `contracts check` | Run the golden-fixture contract validator | `bestest-cli contracts check` |

## Companion Filtering in `report latest-full`

This is the single most important correctness guarantee the CLI provides. The priority chain (mirroring `references/data-source-discovery.md`) is:

1. Most recent **non-companion** `run-*.json` (excludes `suiteFilter: "generated"` and reports with `companionTo`).
2. Most recent `scan-*.json`.
3. Most recent **companion** run report (partial — generated-tests-only; the consumer must warn).
4. `null` → the spoke prints the standard "no data found" guidance.

## Deploying to Spokes

Spokes SHOULD call the CLI as the primary path for mechanical operations, with the manual prose as fallback:

```
If python3 is available:
  result = python3 <skill-dir>/scripts/bestest-cli.py <subcommand> ...
  Use result fields (parse JSON from stdout).
Else:
  Follow the manual steps documented in this spoke (graceful degradation).
```

Additions to existing spokes are intentionally surgical — the CLI is a *helper*, not a replacement for agent judgment. Generation, strategy, and quality scoring remain in the spokes.
