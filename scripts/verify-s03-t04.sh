#!/usr/bin/env bash
set -euo pipefail

echo "=== T04 Verification: Metrics update wired into remaining spokes ==="

PASS=0
FAIL=0

# Check all 8 new spokes have Metrics Update section
for spoke in spoke-fix spoke-generate spoke-generate-python spoke-generate-java spoke-generate-go spoke-coverage spoke-migrate spoke-report; do
  FILE=".agents/skills/bestest/references/${spoke}.md"
  if grep -q "## Metrics Update" "$FILE"; then
    echo "✅ ${spoke}.md has Metrics Update section"
    ((PASS++))
  else
    echo "❌ ${spoke}.md MISSING Metrics Update section"
    ((FAIL++))
  fi

  # Verify protocol steps present
  if grep -q "Never abort the spoke" "$FILE"; then
    echo "  ✅ Graceful degradation protocol present"
    ((PASS++))
  else
    echo "  ❌ Missing graceful degradation protocol"
    ((FAIL++))
  fi

  # Verify field mapping table present
  if grep -q "Fields Updated by ${spoke}" "$FILE"; then
    echo "  ✅ Per-spoke field mapping table present"
    ((PASS++))
  else
    echo "  ❌ Missing per-spoke field mapping table"
    ((FAIL++))
  fi
done

# Check SKILL.md has metrics-schema.md in reference index
if grep -q "metrics-schema.md" ".agents/skills/bestest/SKILL.md"; then
  echo "✅ SKILL.md references metrics-schema.md"
  ((PASS++))
else
  echo "❌ SKILL.md missing metrics-schema.md reference"
  ((FAIL++))
fi

# Check schemas section count updated
if grep -q "Schemas (4)" ".agents/skills/bestest/SKILL.md"; then
  echo "✅ SKILL.md Schemas section count updated to 4"
  ((PASS++))
else
  echo "❌ SKILL.md Schemas section count not updated"
  ((FAIL++))
fi

# Verify previously wired spokes still intact (T03 regression check)
for spoke in spoke-run spoke-scan spoke-doctor; do
  FILE=".agents/skills/bestest/references/${spoke}.md"
  if grep -q "## Metrics Update" "$FILE"; then
    echo "✅ ${spoke}.md (T03) still has Metrics Update"
    ((PASS++))
  else
    echo "❌ ${spoke}.md (T03) REGRESSION — Metrics Update lost"
    ((FAIL++))
  fi
done

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
