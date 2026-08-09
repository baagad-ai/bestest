#!/usr/bin/env bash
# validate-contracts.sh — Golden-fixture contract validation for the bestest skill
# Verifies that the JSON fixture files in scripts/fixtures/ match the schemas they
# represent, and that every spoke's documented read/write fields exist in the
# corresponding fixture. This catches the class of "status reads total_tests but
# run reports have no such field" drift that structural checks cannot see.
# Exit 0 if all pass, exit 1 on any critical failure.

set -uo pipefail

SKILL_DIR="${SKILL_DIR:-$HOME/.agents/skills/bestest}"
FIXTURES="$SKILL_DIR/scripts/fixtures"
REFERENCES="$SKILL_DIR/references"

PASS=0
FAIL=0
WARN=0
CRITICAL=0
RESULTS=()

check() {
  local description="$1"
  local code="$2"
  local severity="${3:-critical}"
  local cmd="$4"

  if eval "$cmd"; then
    RESULTS+=("  ✅ $code ($severity): $description")
    PASS=$((PASS + 1))
  else
    RESULTS+=("  ❌ $code ($severity): $description")
    if [ "$severity" = "critical" ]; then
      CRITICAL=$((CRITICAL + 1))
      FAIL=$((FAIL + 1))
    else
      WARN=$((WARN + 1))
      FAIL=$((FAIL + 1))
    fi
  fi
}

echo "═══ bestest contract validation (golden fixtures) ═══"
echo "Skill directory: $SKILL_DIR"
echo ""

# ─── Domain A: Fixture files exist and parse as valid JSON ─────────────────
echo "── Domain A: Fixture Integrity ──"

for fixture in stack-profile.json scan-report.json run-report.json run-report-companion.json doctor-report.json coverage-report.json metrics.json; do
  check "Fixture '$fixture' exists and parses as valid JSON" "C001" "critical" \
    "[ -s '$FIXTURES/$fixture' ] && python3 -c \"import json; json.load(open('$FIXTURES/$fixture'))\""
done

# ─── Domain B: schemaVersion presence ─────────────────────────────────────
echo "── Domain B: schemaVersion Parity ──"

# Each JSON fixture (except doctor-report which has no schemaVersion) must declare one
check "stack-profile.json declares schemaVersion" "C002" "critical" \
  "python3 -c \"import json; d=json.load(open('$FIXTURES/stack-profile.json')); assert 'schemaVersion' in d\""
check "scan-report.json declares schemaVersion" "C002" "critical" \
  "python3 -c \"import json; d=json.load(open('$FIXTURES/scan-report.json')); assert 'schemaVersion' in d\""
check "run-report.json declares schemaVersion" "C002" "critical" \
  "python3 -c \"import json; d=json.load(open('$FIXTURES/run-report.json')); assert 'schemaVersion' in d\""
check "coverage-report.json declares schemaVersion" "C002" "critical" \
  "python3 -c \"import json; d=json.load(open('$FIXTURES/coverage-report.json')); assert 'schemaVersion' in d\""
check "metrics.json declares schemaVersion" "C002" "critical" \
  "python3 -c \"import json; d=json.load(open('$FIXTURES/metrics.json')); assert 'schemaVersion' in d\""

# doctor-report uses healthScore (no schemaVersion by design)
check "doctor-report.json has healthScore field" "C003" "critical" \
  "python3 -c \"import json; d=json.load(open('$FIXTURES/doctor-report.json')); assert 'healthScore' in d\""

# ─── Domain C: Companion-report contract ───────────────────────────────────
echo "── Domain C: Companion Report Contract ──"

# Companion run report must have suiteFilter "generated" and companionTo present
check "run-report-companion.json has suiteFilter 'generated'" "C004" "critical" \
  "python3 -c \"import json; d=json.load(open('$FIXTURES/run-report-companion.json')); assert d.get('suiteFilter') == 'generated'\""
check "run-report-companion.json has companionTo present" "C004" "critical" \
  "python3 -c \"import json; d=json.load(open('$FIXTURES/run-report-companion.json')); assert 'companionTo' in d\""
# Full-suite run report must NOT have companionTo
check "run-report.json has no companionTo field" "C004" "critical" \
  "python3 -c \"import json; d=json.load(open('$FIXTURES/run-report.json')); assert 'companionTo' not in d\""

# ─── Domain D: Spoke read-field contracts ─────────────────────────────────
echo "── Domain D: Spoke Field Contracts ──"

# helper: does a JSON path exist in a fixture? Path is dot-separated; [] after a key means
# "descend into first array element". e.g. tests[]cases[]name → tests[0].cases[0].name
json_has_path() {
  local fixture="$1"
  local path="$2"
  python3 - "$FIXTURES/$fixture" "$path" <<'PYEOF'
import json, sys, re
fixture, path = sys.argv[1], sys.argv[2]
data = json.load(open(fixture))

# Convert "a.b[]c[]d" into "a['b'][0]['c'][0]['d']"-style traversal
tokens = []
for part in path.split('.'):
    if part == '':
        continue
    # part may be like "b[]c" (key then array marker then next key concatenated)
    m = re.fullmatch(r'([^[]*)(\[\])?(.*)', part)
    if not m:
        sys.exit(1)
    key, arr, rest = m.groups()
    if key:
        tokens.append(('key', key))
    if arr:
        tokens.append(('arr', 0))
    if rest:
        # rest is another key possibly followed by [] e.g. "cases[]"
        m2 = re.fullmatch(r'([^[]*)(\[\])?', rest)
        if m2 and m2.group(1):
            tokens.append(('key', m2.group(1)))
        if m2 and m2.group(2):
            tokens.append(('arr', 0))

cur = data
try:
    for kind, val in tokens:
        if kind == 'key':
            if not isinstance(cur, dict) or val not in cur:
                sys.exit(1)
            cur = cur[val]
        else:  # arr
            if not isinstance(cur, list) or len(cur) == 0:
                sys.exit(1)
            cur = cur[val]
except (KeyError, IndexError, TypeError):
    sys.exit(1)
sys.exit(0)
PYEOF
}

# --- status spoke: reads fields that MUST exist in the schemas ---
# These are the exact fields spoke-status.md now reads (after the v2.0 schema fix).
status_scan_fields="timestamp summary.totalTests summary.totalTestFiles coverage.lines.pct antiPatterns flakyTests"
for field in $status_scan_fields; do
  check "spoke-status reads scan field '$field' (exists in scan fixture)" "C010" "critical" \
    "json_has_path scan-report.json '$field'"
done

status_run_fields="timestamp summary.totalTests summary.passed summary.failed summary.skipped execution.durationMs"
for field in $status_run_fields; do
  check "spoke-status reads run field '$field' (exists in run fixture)" "C010" "critical" \
    "json_has_path run-report.json '$field'"
done

status_doctor_fields="timestamp healthScore status dimensions"
for field in $status_doctor_fields; do
  check "spoke-status reads doctor field '$field' (exists in doctor fixture)" "C010" "critical" \
    "json_has_path doctor-report.json '$field'"
done

# --- report spoke: trend/history fields ---
report_run_fields="timestamp summary.totalTests summary.passed summary.failed summary.skipped coverage.lines.pct execution.durationMs suiteFilter framework.name language errors"
for field in $report_run_fields; do
  check "spoke-report reads run field '$field' (exists in run fixture)" "C011" "critical" \
    "json_has_path run-report.json '$field'"
done

# --- fix spoke: failure-extraction fields ---
fix_run_fields="tests errors framework.name summary timestamp tests[]cases[]name"
for field in $fix_run_fields; do
  check "spoke-fix reads run field '$field' (exists in run fixture)" "C012" "critical" \
    "json_has_path run-report.json '$field'"
done

# --- coverage spoke: gap fields ---
coverage_gap_fields="timestamp configSnapshot targetComparison gaps summary"
for field in $coverage_gap_fields; do
  check "spoke-coverage reads coverage field '$field' (exists in coverage fixture)" "C013" "critical" \
    "json_has_path coverage-report.json '$field'"
done

# --- generate spoke: scan gap fields (generate reads gaps[] from scan) ---
generate_scan_fields="gaps testInventory configSnapshot summary"
for field in $generate_scan_fields; do
  check "spoke-generate reads scan field '$field' (exists in scan fixture)" "C014" "critical" \
    "json_has_path scan-report.json '$field'"
done

# --- metrics consumers: fields doctor/report/status read from metrics.json ---
metrics_fields="schemaVersion lastUpdated healthScore coverage tests flakiness runs modules slowest failures activity"
for field in $metrics_fields; do
  check "metrics.json has top-level '$field'" "C015" "critical" \
    "json_has_path metrics.json '$field'"
done

# --- doctor report dimensions is an object keyed by id with label/score ---
check "doctor dimensions is an object keyed by dimension-id" "C016" "critical" \
  "python3 -c \"import json; d=json.load(open('$FIXTURES/doctor-report.json')); assert isinstance(d['dimensions'], dict); dim=next(iter(d['dimensions'].values())); assert 'label' in dim and 'score' in dim and 'id' in dim\""

# ─── Domain E: Companion filtering keywords in consumers ──────────────────
echo "── Domain E: Companion Filtering Consumers ──"

for spoke in spoke-fix spoke-coverage spoke-report spoke-doctor spoke-status; do
  check "Consumer '$spoke' references companion filtering (suiteFilter/companionTo)" "C020" "warning" \
    "grep -qE 'suiteFilter|companionTo|companion' '$REFERENCES/$spoke.md'"
done

check "data-source-discovery.md defines companion filtering" "C020" "critical" \
  "grep -q 'companion' '$REFERENCES/data-source-discovery.md'"

# ─── Domain F: Run report suiteFilter values ──────────────────────────────
echo "── Domain F: suiteFilter Semantics ──"

check "run-report.json suiteFilter is a valid full-suite value" "C030" "critical" \
  "python3 -c \"import json; d=json.load(open('$FIXTURES/run-report.json')); assert d.get('suiteFilter') in ('unit','integration','e2e','all','affected')\""

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "═══ Results ═══"
for r in "${RESULTS[@]}"; do
  echo "$r"
done
echo ""
TOTAL=$((PASS + CRITICAL + WARN))
echo "Summary: $PASS passed, $CRITICAL critical, $WARN warnings out of $TOTAL checks"

if [ "$CRITICAL" -gt 0 ]; then
  echo ""
  echo "❌ FAILED — $CRITICAL critical contract violation(s) found"
  exit 1
else
  echo ""
  echo "✅ PASSED — all contract checks passed (with $WARN warnings)"
  exit 0
fi
