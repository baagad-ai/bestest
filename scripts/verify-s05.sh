#!/usr/bin/env bash
# verify-s05.sh — Structural verification for S05 deliverables
# Checks: spoke-generate.md, ai-generation-guide.md, anti-patterns.md completeness,
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

echo "=== S05 Structural Verification ==="
echo ""

# ── a. File Existence (4 checks) ──
echo "--- File Existence ---"

check "spoke-generate.md exists" test -f "$SKILL_DIR/references/spoke-generate.md"
check "ai-generation-guide.md exists" test -f "$SKILL_DIR/references/ai-generation-guide.md"
check "anti-patterns.md exists" test -f "$SKILL_DIR/references/anti-patterns.md"
check "verify-s05.sh exists (self-check)" test -f "scripts/verify-s05.sh"

echo ""

# ── b. Anti-pattern Catalog Completeness (3 checks) ──
echo "--- Anti-pattern Catalog Completeness ---"

AP="$SKILL_DIR/references/anti-patterns.md"

AP_NUMBERED=$(grep -c "^## [0-9]" "$AP")
check "anti-patterns.md has 20+ numbered categories (found $AP_NUMBERED)" [ "$AP_NUMBERED" -ge 20 ]

AP_PATTERNS=$(grep -c "Grep pattern\|Grep patterns\|grep pattern\|grep_pattern\|Evaluation criteria\|Detection method" "$AP")
check "anti-patterns.md has detection methods/patterns (found $AP_PATTERNS)" [ "$AP_PATTERNS" -ge 10 ]

AP_SEVERITY=0
for level in critical high medium low; do
  if grep -q "$level" "$AP"; then
    AP_SEVERITY=$((AP_SEVERITY + 1))
  fi
done
check "anti-patterns.md has all 4 severity levels (found $AP_SEVERITY/4)" [ "$AP_SEVERITY" -ge 4 ]

echo ""

# ── c. AI Generation Guide Completeness (3 checks) ──
echo "--- AI Generation Guide Completeness ---"

GUIDE="$SKILL_DIR/references/ai-generation-guide.md"

GUIDE_HEADINGS=$(grep -c "^## " "$GUIDE")
check "ai-generation-guide.md has 7+ ## headings (found $GUIDE_HEADINGS)" [ "$GUIDE_HEADINGS" -ge 7 ]

GUIDE_RUBRIC=$(grep -c "rubric\|scoring\|quality.*score\|Score.*dimension" "$GUIDE")
check "ai-generation-guide.md has quality rubric/scoring (found $GUIDE_RUBRIC refs)" [ "$GUIDE_RUBRIC" -ge 3 ]

GUIDE_STRATEGIES=0
for strat in "pure function\|pure-function" "component" "API\|api" "state" "async"; do
  if grep -q "$strat" "$GUIDE"; then
    GUIDE_STRATEGIES=$((GUIDE_STRATEGIES + 1))
  fi
done
check "ai-generation-guide.md has code type strategies (found $GUIDE_STRATEGIES/5)" [ "$GUIDE_STRATEGIES" -ge 4 ]

echo ""

# ── d. Spoke Completeness (10 checks) ──
echo "--- Spoke Completeness ---"

SPOKE="$SKILL_DIR/references/spoke-generate.md"

check "spoke-generate.md has Pre-Flight Checks section" grep -q "Pre-Flight" "$SPOKE"

PHASES_FOUND=0
for i in 1 2 3 4 5 6 7; do
  if grep -q "Phase $i" "$SPOKE"; then
    PHASES_FOUND=$((PHASES_FOUND + 1))
  fi
done
check "spoke-generate.md has all 7 phases (found $PHASES_FOUND/7)" [ "$PHASES_FOUND" -ge 7 ]

check "spoke-generate.md has HITL Gate section" grep -q "HITL" "$SPOKE"

check "spoke-generate.md has Error Handling section" grep -q "Error Handling" "$SPOKE"

check "spoke-generate.md has Downstream Reference section" grep -q "Downstream" "$SPOKE"

check "spoke-generate.md has Output section" grep -q "## Output\|## Report Output\|Output Specification" "$SPOKE"

check "spoke-generate.md references ai-generation-guide.md" grep -q "ai-generation-guide" "$SPOKE"

check "spoke-generate.md references anti-patterns.md" grep -q "anti-patterns" "$SPOKE"

check "spoke-generate.md references config schema or config.yaml" grep -q "config" "$SPOKE"

check "spoke-generate.md references scan-report-schema or gaps/testInventory" grep -q "scan-report-schema\|gaps\|testInventory" "$SPOKE"

echo ""

# ── e. Content Quality (4 checks) ──
echo "--- Content Quality ---"

TODO_COUNT=$(grep -c "^-\s*TODO\|^-\s*TBD\|^\s*TODO\s*$\|^\s*TBD\s*$\|^- TODO\|^- TBD" "$SPOKE" 2>/dev/null || true)
if [ "$TODO_COUNT" = "" ]; then TODO_COUNT=0; fi
check "No standalone TODO/TBD placeholders in spoke-generate.md (found $TODO_COUNT)" [ "$TODO_COUNT" -eq 0 ]

SPOKE_LINES=$(wc -l < "$SPOKE" | tr -d ' ')
check "spoke-generate.md is 600+ lines (found $SPOKE_LINES)" [ "$SPOKE_LINES" -ge 600 ]

VITEST_REFS=$(grep -ci "vitest" "$SPOKE")
check "spoke-generate.md has 5+ Vitest references (found $VITEST_REFS)" [ "$VITEST_REFS" -ge 5 ]

JEST_REFS=$(grep -ci "jest" "$SPOKE")
check "spoke-generate.md has 5+ Jest references (found $JEST_REFS)" [ "$JEST_REFS" -ge 5 ]

echo ""

# ── f. Cross-file Consistency (3 checks) ──
echo "--- Cross-file Consistency ---"

check "spoke-generate.md references Context7" grep -q "Context7\|context7" "$SPOKE"

GEN_CONFIG=0
for field in quality_threshold max_retries verify_compilation verify_pass; do
  if grep -q "$field" "$SPOKE"; then
    GEN_CONFIG=$((GEN_CONFIG + 1))
  fi
done
check "spoke-generate.md respects generation config fields (found $GEN_CONFIG/4)" [ "$GEN_CONFIG" -ge 3 ]

GUIDE_XREF=$(grep -c "anti-pattern\|spoke-generate\|spoke_generate" "$GUIDE")
check "ai-generation-guide.md cross-references anti-patterns or spoke-generate (found $GUIDE_XREF refs)" [ "$GUIDE_XREF" -ge 1 ]

echo ""

# ── g. SKILL.md Routing (1 check) ──
echo "--- SKILL.md Routing ---"

check "SKILL.md routes generate command to spoke-generate.md" grep -q "spoke-generate.md" "$SKILL_DIR/SKILL.md"

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
