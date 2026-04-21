#!/usr/bin/env bash
# verify-s06.sh — Structural verification for S06 deliverables
# Checks: spoke-expand.md completeness, test type catalog, Context7 integration,
#          HITL gate, content quality, cross-file consistency, SKILL.md routing,
#          config schema updates, and template files

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

echo "=== S06 Structural Verification (Expand Command) ==="
echo ""

SPOKE="$SKILL_DIR/references/spoke-expand.md"

# ── a. File Existence (5 checks) ──
echo "--- File Existence ---"

check "spoke-expand.md exists" test -f "$SPOKE"
check "verify-s06.sh exists (self-check)" test -f "scripts/verify-s06.sh"
check "playwright-config-ts.md template exists" test -f "$SKILL_DIR/references/templates/playwright-config-ts.md"
check "supertest-helpers.md template exists" test -f "$SKILL_DIR/references/templates/supertest-helpers.md"
check "stryker-conf.md template exists" test -f "$SKILL_DIR/references/templates/stryker-conf.md"

echo ""

# ── b. Spoke Structural Completeness (7 checks) ──
echo "--- Spoke Structural Completeness ---"

check "spoke-expand.md has Pre-Flight Checks section" grep -q "Pre-Flight" "$SPOKE"

PHASES_FOUND=$(grep -cE "^## Phase [0-9]+" "$SPOKE")
check "spoke-expand.md has 8+ phases (found $PHASES_FOUND)" [ "$PHASES_FOUND" -ge 8 ]

check "spoke-expand.md has Error Handling section" grep -q "Error Handling" "$SPOKE"

check "spoke-expand.md has Downstream Reference section" grep -q "Downstream Reference" "$SPOKE"

check "spoke-expand.md has Output section" grep -qE "^## Output" "$SPOKE"

check "spoke-expand.md has Prerequisites section" grep -q "Prerequisites" "$SPOKE"

check "spoke-expand.md has Purpose section" grep -qE "^## Purpose" "$SPOKE"

echo ""

# ── c. Test Type Catalog (6 checks — one per type) ──
echo "--- Test Type Catalog ---"

check "E2E / Playwright referenced" grep -qiE "e2e|playwright" "$SPOKE"

check "API / Supertest referenced" grep -qiE "supertest" "$SPOKE"

check "Mutation / Stryker referenced" grep -qiE "stryker" "$SPOKE"

check "Contract / Pact referenced" grep -qiE "contract|pact" "$SPOKE"

check "Chaos testing referenced" grep -qiE "chaos" "$SPOKE"

check "Performance / k6 or Artillery referenced" grep -qiE "performance|k6|artillery" "$SPOKE"

echo ""

# ── d. Context7 Integration (3 checks) ──
echo "--- Context7 Integration ---"

check "Context7 mentioned in spoke" grep -qE "Context.?7|context.?7" "$SPOKE"

check "resolve_library pattern referenced" grep -q "resolve_library" "$SPOKE"

check "Graceful fallback mentioned" grep -qiE "graceful.*fallback|fallback" "$SPOKE"

echo ""

# ── e. HITL Gate (2 checks) ──
echo "--- HITL Gate ---"

check "HITL gate section present" grep -qiE "hitl|human.in.the.loop|HITL" "$SPOKE"

check "Approve/modify/cancel options present" grep -qiE "approve.*modify.*cancel|approve.*modify" "$SPOKE"

echo ""

# ── f. Content Quality (4 checks) ──
echo "--- Content Quality ---"

TODO_COUNT=$(grep -cE "^\s*-\s*(TODO|TBD)\b|^\s*(TODO|TBD)\s*$" "$SPOKE" 2>/dev/null || true)
if [ "$TODO_COUNT" = "" ]; then TODO_COUNT=0; fi
check "No standalone TODO/TBD placeholders in spoke-expand.md (found $TODO_COUNT)" [ "$TODO_COUNT" -eq 0 ]

SPOKE_LINES=$(wc -l < "$SPOKE" | tr -d ' ')
check "spoke-expand.md is 600+ lines (found $SPOKE_LINES)" [ "$SPOKE_LINES" -ge 600 ]

check "spoke-expand.md references config-schema or config.yaml" grep -qE "config\.schema|config\.yaml|config-schema" "$SPOKE"

check "spoke-expand.md references spoke-init.md (scaffolding pattern)" grep -qiE "spoke-init" "$SPOKE"

echo ""

# ── g. Cross-file Consistency (3 checks) ──
echo "--- Cross-file Consistency ---"

check "spoke-expand.md references spoke-generate.md or generate pattern" grep -qiE "spoke-generate|generate.*pattern" "$SPOKE"

check "spoke-expand.md references spoke-scan.md or scan pattern" grep -qiE "spoke-scan|scan.*pattern" "$SPOKE"

check "spoke-expand.md references config-schema or config.yaml" grep -qE "config\.schema|config\.yaml|config-schema" "$SPOKE"

echo ""

# ── h. SKILL.md Routing (3 checks) ──
echo "--- SKILL.md Routing ---"

SKILL="$SKILL_DIR/SKILL.md"

check "SKILL.md has expand entry in routing table" grep -qiE "expand.*spoke-expand|spoke-expand.*expand" "$SKILL"

check "SKILL.md has expand entry in quick_reference table" grep -qiE "^\|\s*\`?expand\`?" "$SKILL"

check "SKILL.md has spoke-expand.md in reference_index" grep -qE "spoke-expand" "$SKILL"

echo ""

# ── i. Config Schema (3 checks) ──
echo "--- Config Schema ---"

CONFIG_SCHEMA="$SKILL_DIR/references/config-schema.md"

check "config-schema.md has api.enabled field" grep -qE "api\.enabled|api.enabled" "$CONFIG_SCHEMA"

check "config-schema.md has mutation.enabled field" grep -qE "mutation\.enabled|mutation.enabled" "$CONFIG_SCHEMA"

check "config-schema.md has performance.enabled field" grep -qE "performance\.enabled|performance.enabled" "$CONFIG_SCHEMA"

echo ""

# ── j. Templates (3 checks) ──
echo "--- Templates ---"

check "playwright-config-ts.md has multiple variants" grep -qiE "variant" "$SKILL_DIR/references/templates/playwright-config-ts.md"

check "supertest-helpers.md references supertest or request" grep -qiE "supertest|request" "$SKILL_DIR/references/templates/supertest-helpers.md"

check "stryker-conf.md references stryker" grep -qiE "stryker" "$SKILL_DIR/references/templates/stryker-conf.md"

echo ""

# ── Summary ──
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All S06 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
