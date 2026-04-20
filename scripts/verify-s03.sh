#!/usr/bin/env bash
# verify-s03.sh — Structural verification for S03 deliverables
# Checks: spoke-config.md completeness, schema coverage, SKILL.md update, no placeholders

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

echo "=== S03 Structural Verification ==="
echo ""

# ── a. File Existence (1 check) ──
echo "--- File Existence ---"

check "spoke-config.md exists" test -f "$SKILL_DIR/references/spoke-config.md"

echo ""

# ── b. Spoke Completeness (6 checks) ──
echo "--- Spoke Completeness ---"

SPOKE="$SKILL_DIR/references/spoke-config.md"

SPOKE_LINES=$(wc -l < "$SPOKE" | tr -d ' ')
check "spoke-config.md >= 250 lines (found $SPOKE_LINES)" [ "$SPOKE_LINES" -ge 250 ]

# Check all 4 sub-command workflow sections exist
SECTIONS_FOUND=0
for section in "Workflow: show" "Workflow: set" "Workflow: validate" "Workflow: reset"; do
  if grep -q "$section" "$SPOKE"; then
    SECTIONS_FOUND=$((SECTIONS_FOUND + 1))
  fi
done
check "spoke-config.md has all 4 sub-command sections (found $SECTIONS_FOUND/4)" [ "$SECTIONS_FOUND" -ge 4 ]

check "spoke-config.md has Error Handling section" grep -q "## Error Handling" "$SPOKE"

check "spoke-config.md has Validation Rules Reference section" grep -q "## Validation Rules Reference" "$SPOKE"

ERROR_SCENARIOS=0
for scenario in ".bestest/.* missing\|directory missing\|directory not found" \
                "config.yaml.* missing\|config.yaml not found" \
                "invalid YAML\|YAML syntax error\|parse.*config" \
                "Unknown.*key\|Unknown config key" \
                "Invalid value\|Invalid.*type\|Expected.*type" \
                "out of range\|Valid range" \
                "state.*read-only\|Cannot set.*state\|state fields are read-only" \
                "framework.*switch\|Switching framework" \
                "Cannot reset\|framework.*not found.*reset\|determine.*template"; do
  if grep -qi "$scenario" "$SPOKE"; then
    ERROR_SCENARIOS=$((ERROR_SCENARIOS + 1))
  fi
done
check "spoke-config.md covers all 9 error scenarios (matched $ERROR_SCENARIOS/9)" [ "$ERROR_SCENARIOS" -ge 8 ]

check "spoke-config.md has Output Specification section" grep -q "## Output Specification" "$SPOKE"

echo ""

# ── c. Schema Coverage (2 checks) ──
echo "--- Schema Coverage ---"

check "spoke-config.md references config-schema.md" grep -q "config-schema" "$SPOKE"

FIELD_GROUPS=0
for group in framework coverage paths e2e ci vitest jest monorepo generation state; do
  if grep -q "$group" "$SPOKE"; then
    FIELD_GROUPS=$((FIELD_GROUPS + 1))
  fi
done
check "spoke-config.md mentions all 10 field groups (found $FIELD_GROUPS/10)" [ "$FIELD_GROUPS" -ge 10 ]

echo ""

# ── d. SKILL.md Update (1 check) ──
echo "--- SKILL.md Update ---"

check "SKILL.md quick reference includes reset for config command" grep -q "reset" "$SKILL_DIR/SKILL.md"

echo ""

# ── e. No Placeholders (1 check) ──
echo "--- No TODO/TBD Placeholders ---"

TODO_COUNT=$(grep -cil "TODO\|TBD" "$SPOKE" 2>/dev/null | head -1 || true)
if [ "$TODO_COUNT" = "" ]; then TODO_COUNT=0; fi
check "No TODO/TBD placeholders in spoke-config.md (found $TODO_COUNT files)" [ "$TODO_COUNT" -eq 0 ]

echo ""

# ── Summary ──
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All S03 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
