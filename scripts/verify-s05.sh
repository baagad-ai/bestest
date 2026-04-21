#!/usr/bin/env bash
# verify-s05.sh — Structural verification for S05 deliverables
# Checks: spoke-doctor.md completeness, dimension coverage, scoring logic,
#          CI graceful skip, remediation, content quality, cross-file consistency,
#          SKILL.md routing, and config schema state.last_doctor field

set -euo pipefail

SKILL_DIR="$HOME/.agents/skills/bestest"
PASS=0
FAIL=0

check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "✅ PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== S05 Structural Verification (Doctor Command) ==="
echo ""

SPOKE="$SKILL_DIR/references/spoke-doctor.md"

# ── a. File Existence (2 checks) ──
echo "--- File Existence ---"

check "spoke-doctor.md exists" test -f "$SPOKE"
check "verify-s05.sh exists (self-check)" test -f "scripts/verify-s05.sh"

echo ""

# ── b. Spoke Structural Completeness (7 checks) ──
echo "--- Spoke Structural Completeness ---"

check "spoke-doctor.md has Pre-Flight Checks section" grep -q "Pre-Flight" "$SPOKE"

PHASES_FOUND=$(grep -cE "^## Phase [0-9]+" "$SPOKE")
check "spoke-doctor.md has 10+ phases (found $PHASES_FOUND)" [ "$PHASES_FOUND" -ge 10 ]

check "spoke-doctor.md has Error Handling section" grep -q "Error Handling" "$SPOKE"

check "spoke-doctor.md has Downstream Reference section" grep -q "Downstream Reference" "$SPOKE"

check "spoke-doctor.md has Output section" grep -qE "^## Output" "$SPOKE"

check "spoke-doctor.md has Composite Scoring section" grep -q "Composite Scoring" "$SPOKE"

check "spoke-doctor.md has Prerequisites section" grep -q "Prerequisites" "$SPOKE"

echo ""

# ── c. Dimension Coverage (9 checks — one per dimension) ──
echo "--- Dimension Coverage ---"

check "dimension: Framework Version present" grep -qE "framework.version|framework-version|Framework Version" "$SPOKE"
check "dimension: Config Validity present" grep -qE "config.validity|config-validity|Config Validity" "$SPOKE"
check "dimension: Coverage Trend present" grep -qE "coverage.trend|coverage-trend|Coverage Trend" "$SPOKE"
check "dimension: Flaky Test Budget present" grep -qE "flaky.test|flaky-tests|Flaky Test Budget" "$SPOKE"
check "dimension: CI Health present" grep -qE "ci.health|ci-health|CI Health" "$SPOKE"
check "dimension: Execution Time present" grep -qE "execution.time|execution-time|Execution Time" "$SPOKE"
check "dimension: Anti-Pattern Summary present" grep -qE "anti.pattern|anti-patterns|Anti-Pattern Summary" "$SPOKE"
check "dimension: Dead Test Detection present" grep -qE "dead.test|dead-tests|Dead Test" "$SPOKE"
check "dimension: Duplicate Coverage present" grep -qE "duplicate.coverage|duplicate-coverage|Duplicate Coverage" "$SPOKE"

echo ""

# ── d. Scoring Logic (5 checks) ──
echo "--- Scoring Logic ---"

check "scoring: weighted average mentioned" grep -qE "weighted.*average|sum.*weight.*score" "$SPOKE"

check "scoring: score bands defined (Excellent/Good/Fair/Critical)" grep -qE "Excellent.*Good|Good.*Fair|Fair.*Critical|90.*100.*Excellent|0.*39.*Critical" "$SPOKE"

check "scoring: graceful skip logic described" grep -qE "skip|skipped|graceful" "$SPOKE"

check "scoring: 0-100 score range mentioned" grep -qE "0.?100|0–100" "$SPOKE"

check "scoring: minimum dimensions threshold" grep -qE "minimum.*dimension|3.*scorable|at least 3" "$SPOKE"

echo ""

# ── e. CI Graceful Skip (3 checks) ──
echo "--- CI Graceful Skip ---"

check "CI: not_configured status documented" grep -qE "not_configured" "$SPOKE"

check "CI: skip/no-penalize logic documented" grep -qE "does not affect|not.*penalize|excluded.*composite|weight.*0" "$SPOKE"

check "CI: weight set to 0 when not configured" grep -qE "weight.*0|weight.*=.*0|weight:\s*0" "$SPOKE"

echo ""

# ── f. Remediation (3 checks) ──
echo "--- Remediation ---"

check "remediation: prioritized remediation list mentioned" grep -qE "prioritized.*remediation|remediation.*priorit" "$SPOKE"

check "remediation: remediation entries in dimension output" grep -qE '"remediation"' "$SPOKE"

check "remediation: suggested commands for each dimension" grep -qE "bestest fix|bestest coverage|bestest generate|bestest run" "$SPOKE"

echo ""

# ── g. Content Quality (4 checks) ──
echo "--- Content Quality ---"

TODO_COUNT=$(grep -cE "^\s*-\s*(TODO|TBD)\b|^\s*(TODO|TBD)\s*$" "$SPOKE" 2>/dev/null || true)
if [ "$TODO_COUNT" = "" ]; then TODO_COUNT=0; fi
check "No standalone TODO/TBD placeholders in spoke-doctor.md (found $TODO_COUNT)" [ "$TODO_COUNT" -eq 0 ]

SPOKE_LINES=$(wc -l < "$SPOKE" | tr -d ' ')
check "spoke-doctor.md is 600+ lines (found $SPOKE_LINES)" [ "$SPOKE_LINES" -ge 600 ]

check "spoke-doctor.md references config schema or config.yaml" grep -qE "config.schema|config.yaml|config-schema" "$SPOKE"

check "spoke-doctor.md references anti-patterns" grep -qE "anti-pattern|antiPattern" "$SPOKE"

echo ""

# ── h. Cross-file Consistency (3 checks) ──
echo "--- Cross-file Consistency ---"

check "spoke-doctor.md references spoke-run.md or run-results" grep -qE "spoke-run|run-results|run-\*\.json" "$SPOKE"

check "spoke-doctor.md references spoke-scan.md or scan reports" grep -qE "spoke-scan|scan-report|scan-\*\.json" "$SPOKE"

check "spoke-doctor.md references config-schema.md" grep -qE "config-schema" "$SPOKE"

echo ""

# ── i. SKILL.md Routing (3 checks) ──
echo "--- SKILL.md Routing ---"

SKILL="$SKILL_DIR/SKILL.md"

check "SKILL.md has doctor entry in routing table" grep -qE "doctor.*spoke-doctor|spoke-doctor.*doctor" "$SKILL"

check "SKILL.md has doctor entry in quick_reference table" grep -qE "^\|\s*\`?doctor\`?" "$SKILL"

check "SKILL.md has spoke-doctor.md in reference_index" grep -qE "spoke-doctor\.md.*doctor|doctor.*spoke-doctor\.md" "$SKILL"

echo ""

# ── j. Config Schema (2 checks) ──
echo "--- Config Schema ---"

CONFIG_SCHEMA="$SKILL_DIR/references/config-schema.md"

check "config-schema.md exists" test -f "$CONFIG_SCHEMA"

check "config-schema.md has state.last_doctor field" grep -qE "state\.last_doctor|last_doctor" "$CONFIG_SCHEMA"

echo ""

# ── k. JSON Report Structure (2 checks) ──
echo "--- JSON Report Structure ---"

check "spoke-doctor.md defines health report JSON schema" grep -qE "healthScore|health.*report.*JSON|JSON.*schema" "$SPOKE"

check "spoke-doctor.md defines console output format" grep -qE "Console.*Output|console.*summary|print.*summary" "$SPOKE"

echo ""

# ── Summary ──
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All S05 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
