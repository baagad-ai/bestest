#!/usr/bin/env bash
# verify-s04.sh — Structural verification for S04 deliverables
# Checks: anti-patterns.md, scan-report-schema.md, spoke-scan.md completeness,
#          content quality, cross-file consistency, and SKILL.md routing

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

echo "=== S04 Structural Verification ==="
echo ""

# ── a. File Existence (4 checks) ──
echo "--- File Existence ---"

check "anti-patterns.md exists" test -f "$SKILL_DIR/references/anti-patterns.md"
check "scan-report-schema.md exists" test -f "$SKILL_DIR/references/scan-report-schema.md"
check "spoke-scan.md exists" test -f "$SKILL_DIR/references/spoke-scan.md"
check "verify-s04.sh exists (self-check)" test -f "scripts/verify-s04.sh"

echo ""

# ── b. Anti-pattern Catalog Completeness (3 checks) ──
echo "--- Anti-pattern Catalog Completeness ---"

AP="$SKILL_DIR/references/anti-patterns.md"

AP_HEADINGS=$(grep -c "^## " "$AP")
check "anti-patterns.md has 10+ ## headings (found $AP_HEADINGS)" [ "$AP_HEADINGS" -ge 10 ]

AP_PATTERNS=$(grep -c "Grep pattern\|Grep patterns\|grep pattern\|grep_pattern\|Evaluation criteria" "$AP")
check "anti-patterns.md has detection methods/patterns (found $AP_PATTERNS)" [ "$AP_PATTERNS" -ge 8 ]

AP_SEVERITY=0
for level in critical high medium low; do
  if grep -q "$level" "$AP"; then
    AP_SEVERITY=$((AP_SEVERITY + 1))
  fi
done
check "anti-patterns.md has all 4 severity levels (found $AP_SEVERITY/4)" [ "$AP_SEVERITY" -ge 4 ]

echo ""

# ── c. Scan Report Schema Completeness (3 checks) ──
echo "--- Scan Report Schema Completeness ---"

SCHEMA="$SKILL_DIR/references/scan-report-schema.md"

SCHEMA_HEADINGS=$(grep -c "^## " "$SCHEMA")
check "scan-report-schema.md has 5+ ## headings (found $SCHEMA_HEADINGS)" [ "$SCHEMA_HEADINGS" -ge 5 ]

SCHEMA_FIELDS=0
for field in summary coverage antiPatterns flakyTests gaps testInventory; do
  if grep -q "$field" "$SCHEMA"; then
    SCHEMA_FIELDS=$((SCHEMA_FIELDS + 1))
  fi
done
check "scan-report-schema.md defines all 6 required fields (found $SCHEMA_FIELDS/6)" [ "$SCHEMA_FIELDS" -ge 6 ]

check "scan-report-schema.md includes example JSON output" grep -q '```json' "$SCHEMA"

echo ""

# ── d. Spoke Completeness (8 checks) ──
echo "--- Spoke Completeness ---"

SPOKE="$SKILL_DIR/references/spoke-scan.md"

check "spoke-scan.md has Pre-Flight Checks section" grep -q "Pre-Flight" "$SPOKE"

PHASES_FOUND=0
for i in 1 2 3 4 5 6 7; do
  if grep -q "Phase $i" "$SPOKE"; then
    PHASES_FOUND=$((PHASES_FOUND + 1))
  fi
done
check "spoke-scan.md has all 7 phases (found $PHASES_FOUND/7)" [ "$PHASES_FOUND" -ge 7 ]

check "spoke-scan.md has Error Handling section" grep -q "Error Handling" "$SPOKE"

check "spoke-scan.md has Downstream Reference section" grep -q "Downstream" "$SPOKE"

check "spoke-scan.md has Output section" grep -q "## Output\|## Report Output\|Output Specification" "$SPOKE"

check "spoke-scan.md references anti-patterns.md" grep -q "anti-patterns" "$SPOKE"

check "spoke-scan.md references scan-report-schema.md" grep -q "scan-report-schema" "$SPOKE"

check "spoke-scan.md references config (schema or yaml)" grep -q "config" "$SPOKE"

echo ""

# ── e. Content Quality (3 checks) ──
echo "--- Content Quality ---"

TODO_COUNT=$(grep -ciP "^\s*[-*]?\s*(TODO|TBD)[\s:]" "$SPOKE" 2>/dev/null || true)
if [ "$TODO_COUNT" = "" ]; then TODO_COUNT=0; fi
check "No TODO/TBD placeholders in spoke-scan.md (found $TODO_COUNT)" [ "$TODO_COUNT" -eq 0 ]

SPOKE_LINES=$(wc -l < "$SPOKE" | tr -d ' ')
check "spoke-scan.md is 400+ lines (found $SPOKE_LINES)" [ "$SPOKE_LINES" -ge 400 ]

VITEST_COV=$(grep -c "vitest" "$SPOKE")
JEST_COV=$(grep -c "jest\|Jest" "$SPOKE")
check "spoke-scan.md specifies coverage for both Vitest ($VITEST_COV refs) and Jest ($JEST_COV refs)" [ "$VITEST_COV" -ge 1 ] && [ "$JEST_COV" -ge 1 ]

echo ""

# ── f. Cross-file Consistency (2 checks) ──
echo "--- Cross-file Consistency ---"

check "spoke-scan.md references TESTING.md template" grep -q "testing-md.md\|templates/testing-md" "$SPOKE"

check "spoke-scan.md specifies state.last_scan update" grep -q "last_scan" "$SPOKE"

echo ""

# ── g. SKILL.md Routing (1 check) ──
echo "--- SKILL.md Routing ---"

check "SKILL.md routes scan command to spoke-scan.md" grep -q "spoke-scan.md" "$SKILL_DIR/SKILL.md"

echo ""

# ── Summary ──
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All S04 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
