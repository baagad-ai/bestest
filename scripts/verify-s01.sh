#!/usr/bin/env bash
# verify-s01.sh — Structural verification for S01 deliverable
# Checks: file existence, line budgets, XML sections, heading counts, spoke structure, no TODO/TBD

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

echo "=== S01 Structural Verification ==="
echo ""

# 1. Check all expected files exist
echo "--- File Existence ---"

check "SKILL.md exists"               test -f "$SKILL_DIR/SKILL.md"
check "stack-profile-schema.md exists" test -f "$SKILL_DIR/references/stack-profile-schema.md"
check "detection-signals.md exists"    test -f "$SKILL_DIR/references/detection-signals.md"
check "js-ts-decision-tree.md exists"  test -f "$SKILL_DIR/references/js-ts-decision-tree.md"
check "spoke-init.md exists"           test -f "$SKILL_DIR/references/spoke-init.md"
check "spoke-config.md exists"         test -f "$SKILL_DIR/references/spoke-config.md"
check "spoke-scan.md exists"           test -f "$SKILL_DIR/references/spoke-scan.md"
check "spoke-generate.md exists"       test -f "$SKILL_DIR/references/spoke-generate.md"

echo ""

# 2. Validate SKILL.md line count is within budget (550 lines)
echo "--- SKILL.md Budget ---"

LINES=$(wc -l < "$SKILL_DIR/SKILL.md" | tr -d ' ')
check "SKILL.md line count ($LINES) within 550-line budget" [ "$LINES" -le 550 ]

echo ""

# 3. Check all required XML sections exist in SKILL.md
echo "--- SKILL.md XML Sections ---"

check "<detection_engine> section present"  grep -q "<detection_engine>" "$SKILL_DIR/SKILL.md"
check "<framework_decision> section present" grep -q "<framework_decision>" "$SKILL_DIR/SKILL.md"
check "<context7_helper> section present"   grep -q "<context7_helper>" "$SKILL_DIR/SKILL.md"
check "<routing> section present"           grep -q "<routing>" "$SKILL_DIR/SKILL.md"
check "<quick_reference> section present"   grep -q "<quick_reference>" "$SKILL_DIR/SKILL.md"
check "<reference_index> section present"   grep -q "<reference_index>" "$SKILL_DIR/SKILL.md"
check "<success_criteria> section present"  grep -q "<success_criteria>" "$SKILL_DIR/SKILL.md"

echo ""

# 4. Validate each reference file has >= 3 sections (## headings)
echo "--- Reference File Sections ---"

for ref in stack-profile-schema.md detection-signals.md js-ts-decision-tree.md; do
  COUNT=$(grep -c "^## " "$SKILL_DIR/references/$ref" 2>/dev/null || echo 0)
  check "$ref has >= 3 sections (found $COUNT)" [ "$COUNT" -ge 3 ]
done

echo ""

# 5. Validate each spoke stub has purpose, prerequisites, and workflow outline sections
echo "--- Spoke Stub Structure ---"

for spoke in spoke-init.md spoke-config.md spoke-scan.md spoke-generate.md; do
  check "$spoke has Purpose section"       grep -q "^## Purpose" "$SKILL_DIR/references/$spoke"
  check "$spoke has Prerequisites section" grep -q "^## Prerequisites" "$SKILL_DIR/references/$spoke"
  check "$spoke has Workflow Outline section" grep -q "^## Workflow Outline" "$SKILL_DIR/references/$spoke"
done

echo ""

# 6. Check for no TODO/TBD placeholders in any file
echo "--- No TODO/TBD Placeholders ---"

TODO_COUNT=$(grep -ril "TODO\|TBD" "$SKILL_DIR/references/" "$SKILL_DIR/SKILL.md" 2>/dev/null | wc -l | tr -d ' ' || true)
if [ "$TODO_COUNT" = "" ]; then TODO_COUNT=0; fi
check "No TODO/TBD placeholders in any file (found $TODO_COUNT files)" [ "$TODO_COUNT" -eq 0 ]

echo ""

# 7. Check routing table maps all 4 spoke commands
echo "--- Routing Table Integrity ---"

check "Routing table references spoke-init"     grep -q "spoke-init" "$SKILL_DIR/SKILL.md"
check "Routing table references spoke-config"   grep -q "spoke-config" "$SKILL_DIR/SKILL.md"
check "Routing table references spoke-scan"     grep -q "spoke-scan" "$SKILL_DIR/SKILL.md"
check "Routing table references spoke-generate" grep -q "spoke-generate" "$SKILL_DIR/SKILL.md"

echo ""

# Summary
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All S01 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
