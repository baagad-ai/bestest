#!/usr/bin/env bash
# verify-s02.sh — Structural verification for S02 deliverables
# Checks: file existence, config schema completeness, template validity,
#          spoke completeness, cross-file consistency, no TODO/TBD

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

echo "=== S02 Structural Verification ==="
echo ""

# ── a. File Existence (9 checks) ──
echo "--- File Existence ---"

check "config-schema.md exists"              test -f "$SKILL_DIR/references/config-schema.md"
check "config-vitest.yaml template exists"    test -f "$SKILL_DIR/references/templates/config-vitest.yaml"
check "config-jest.yaml template exists"      test -f "$SKILL_DIR/references/templates/config-jest.yaml"
check "config-monorepo.yaml template exists"  test -f "$SKILL_DIR/references/templates/config-monorepo.yaml"
check "testing-md.md template exists"         test -f "$SKILL_DIR/references/templates/testing-md.md"
check "vitest-config-ts.md template exists"   test -f "$SKILL_DIR/references/templates/vitest-config-ts.md"
check "jest-config-ts.md template exists"     test -f "$SKILL_DIR/references/templates/jest-config-ts.md"
check "bestest-gitignore template exists"     test -f "$SKILL_DIR/references/templates/bestest-gitignore"
check "spoke-init.md exists"                  test -f "$SKILL_DIR/references/spoke-init.md"

echo ""

# ── b. Config Schema Completeness (3 checks) ──
echo "--- Config Schema Completeness ---"

SCHEMA="$SKILL_DIR/references/config-schema.md"

SCHEMA_HEADINGS=$(grep -c "^## " "$SCHEMA")
check "config-schema.md has >= 4 ## headings (found $SCHEMA_HEADINGS)" [ "$SCHEMA_HEADINGS" -ge 4 ]

SCHEMA_FIELDS=$(grep -c "framework\|coverage\|paths\|e2e\|ci\|vitest\|jest\|monorepo\|generation\|state" "$SCHEMA")
check "config-schema.md mentions all key field groups (matched $SCHEMA_FIELDS lines)" [ "$SCHEMA_FIELDS" -ge 10 ]

SCHEMA_EXAMPLES=$(grep -c '```yaml\|```javascript\|```typescript\|```json' "$SCHEMA")
check "config-schema.md has >= 1 example config block (found $SCHEMA_EXAMPLES)" [ "$SCHEMA_EXAMPLES" -ge 1 ]

echo ""

# ── c. Template Validity (5 checks) ──
echo "--- Template Validity ---"

for tpl in config-vitest.yaml config-jest.yaml config-monorepo.yaml; do
  PH_COUNT=$(grep -c "{{" "$SKILL_DIR/references/templates/$tpl")
  check "$tpl has >= 2 {{placeholders}} (found $PH_COUNT)" [ "$PH_COUNT" -ge 2 ]
done

TMD_PH=$(grep -c "{{" "$SKILL_DIR/references/templates/testing-md.md")
check "testing-md.md has >= 5 {{placeholders}} (found $TMD_PH)" [ "$TMD_PH" -ge 5 ]

VITEST_VARIANTS=$(grep -c "variant\|preset\|framework\|Vue\|React\|Svelte" "$SKILL_DIR/references/templates/vitest-config-ts.md")
check "vitest-config-ts.md covers >= 3 variants (matched $VITEST_VARIANTS lines)" [ "$VITEST_VARIANTS" -ge 3 ]

GITIGNORE_ENTRIES=$(grep -v "^#" "$SKILL_DIR/references/templates/bestest-gitignore" | grep -v "^$" | wc -l | tr -d ' ')
check "bestest-gitignore has >= 3 entries (found $GITIGNORE_ENTRIES)" [ "$GITIGNORE_ENTRIES" -ge 3 ]

JEST_TRANSFORM=$(grep -c "transform" "$SKILL_DIR/references/templates/jest-config-ts.md")
check "jest-config-ts.md mentions transform options (found $JEST_TRANSFORM refs)" [ "$JEST_TRANSFORM" -ge 1 ]

echo ""

# ── d. Spoke Completeness (6 checks) ──
echo "--- Spoke Completeness ---"

SPOKE="$SKILL_DIR/references/spoke-init.md"

SPOKE_LINES=$(wc -l < "$SPOKE" | tr -d ' ')
check "spoke-init.md >= 300 lines (found $SPOKE_LINES)" [ "$SPOKE_LINES" -ge 300 ]

REQUIRED_SECTIONS="Purpose Prerequisites Pre-Flight \"Phase 1\" \"Phase 2\" \"Phase 3\" \"Phase 4\" \"Phase 5\" \"Phase 6\" \"Error Handling\""
SECTIONS_FOUND=0
for section in Purpose Prerequisites Pre-Flight "Phase 1" "Phase 2" "Phase 3" "Phase 4" "Phase 5" "Phase 6" "Error Handling"; do
  if grep -q "$section" "$SPOKE"; then
    SECTIONS_FOUND=$((SECTIONS_FOUND + 1))
  fi
done
check "spoke-init.md has all required sections (found $SECTIONS_FOUND/10)" [ "$SECTIONS_FOUND" -ge 10 ]

check "spoke-init.md references config-schema" grep -q "config-schema" "$SPOKE"

SPOKE_TPL_REFS=$(grep -c "config-vitest\|config-jest\|config-monorepo\|testing-md\|vitest-config\|jest-config\|bestest-gitignore" "$SPOKE")
check "spoke-init.md references >= 3 template files (found $SPOKE_TPL_REFS refs)" [ "$SPOKE_TPL_REFS" -ge 3 ]

check "spoke-init.md contains HITL instructions" grep -q "HITL\|human-in-the-loop\|HITL gate" "$SPOKE"

check "spoke-init.md specifies TESTING.md at repo root" grep -q "repo root\|repository root" "$SPOKE"

echo ""

# ── e. Cross-File Consistency (2 checks) ──
echo "--- Cross-File Consistency ---"

# Check that schema field names appear in at least one template
SCHEMA_IN_TPL=0
for field in framework coverage "testDir\|test_dir\|paths" "reporters\|reporter" globals environment; do
  if grep -rl "$field" "$SKILL_DIR/references/templates/"*.yaml "$SKILL_DIR/references/templates/"*.md 2>/dev/null | grep -q .; then
    SCHEMA_IN_TPL=$((SCHEMA_IN_TPL + 1))
  fi
done
check "Schema field names appear in templates (matched $SCHEMA_IN_TPL/6 field groups)" [ "$SCHEMA_IN_TPL" -ge 3 ]

SPOKE_STACKS=$(grep -ci "react\|vue\|svelte\|next\|angular\|express\|astro\|nuxt\|remix" "$SPOKE")
check "spoke-init.md has >= 5 stack-type mappings (found $SPOKE_STACKS refs)" [ "$SPOKE_STACKS" -ge 5 ]

echo ""

# ── f. No Placeholders (1 check) ──
echo "--- No TODO/TBD Placeholders ---"

TODO_COUNT=$(grep -ril "TODO\|TBD" \
  "$SKILL_DIR/references/config-schema.md" \
  "$SKILL_DIR/references/spoke-init.md" \
  "$SKILL_DIR/references/templates/" \
  2>/dev/null | wc -l | tr -d ' ' || true)
if [ "$TODO_COUNT" = "" ]; then TODO_COUNT=0; fi
check "No TODO/TBD placeholders in any S02 file (found $TODO_COUNT files)" [ "$TODO_COUNT" -eq 0 ]

echo ""

# ── Summary ──
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All S02 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
