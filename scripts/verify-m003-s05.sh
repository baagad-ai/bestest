#!/usr/bin/env bash
# verify-m003-s05.sh — Structural verification for M003/S05 (Migration spoke) deliverables
# Validates file existence, spoke structure, migration rules completeness, per-path content,
# git rollback documentation, SKILL.md integration, and cross-file consistency.

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

echo "=== M003/S05 Structural Verification (Migration Spoke) ==="
echo ""

# ── a. File Existence (3 checks) ─────────────────────────────────────────────
echo "--- a. File Existence ---"

check "spoke-migrate.md exists"          test -f "$SKILL_DIR/references/spoke-migrate.md"
check "migration-rules.md exists"        test -f "$SKILL_DIR/references/migration-rules.md"
check "SKILL.md exists"                  test -f "$SKILL_DIR/SKILL.md"

echo ""

# ── b. Spoke Structure (5 checks) ────────────────────────────────────────────
echo "--- b. Spoke Structure ---"

SM="$SKILL_DIR/references/spoke-migrate.md"
SM_PHASES=$(grep -cE "^## Phase|^## Pre-Flight" "$SM" || true)
check "spoke-migrate.md has all 8 phases (Pre-Flight + Phase 1-7, found $SM_PHASES)" [ "$SM_PHASES" -ge 8 ]
check "spoke-migrate.md has Pre-Flight section"       grep -qiE "pre.?flight" "$SM"
check "spoke-migrate.md has HITL gates"               grep -qiE "HITL|human.in.the.loop" "$SM"
check "spoke-migrate.md has Error Handling section"   grep -qiE "error.handling" "$SM"
check "spoke-migrate.md has Downstream Reference"     grep -qiE "downstream.reference" "$SM"

echo ""

# ── c. Migration Rules Completeness (4 checks) ──────────────────────────────
echo "--- c. Migration Rules Completeness ---"

MR="$SKILL_DIR/references/migration-rules.md"
check "migration-rules.md has Jest→Vitest section"          grep -qiE "Jest.*Vitest.*Import|Jest → Vitest" "$MR"
check "migration-rules.md has JUnit 4→5 section"            grep -qiE "JUnit 4.*JUnit 5.*Annotation|JUnit 4 → JUnit 5" "$MR"
check "migration-rules.md has Cypress→Playwright section"   grep -qiE "Cypress.*Playwright.*Command|Cypress → Playwright" "$MR"
check "migration-rules.md has General Migration Principles"  grep -qiE "General Migration Principles" "$MR"

echo ""

# ── d. Jest→Vitest Content (4 checks) ───────────────────────────────────────
echo "--- d. Jest→Vitest Content ---"

check "spoke-migrate.md has Jest→Vitest import replacement rules"   grep -q "3.3.1 Import Transformation" "$SM"
check "spoke-migrate.md has Jest→Vitest mock API mapping"           grep -q "3.3.2 Mock API Transformation" "$SM"
check "spoke-migrate.md has Jest→Vitest config field mapping"       grep -q "4.1.1 Config File Transformation" "$SM"
check "spoke-migrate.md has __mocks__ handling documented"          grep -qiE "__mocks__" "$SM"

echo ""

# ── e. JUnit4→5 Content (4 checks) ──────────────────────────────────────────
echo "--- e. JUnit4→5 Content ---"

check "spoke-migrate.md has JUnit4→5 annotation mapping"            grep -q "3.4.1 Annotation Transformation" "$SM"
check "spoke-migrate.md has assertion parameter reordering"         grep -qiE "assertion.parameter.reorder|Parameter Reordering" "$SM"
check "spoke-migrate.md has exception test transformation"          grep -qiE "Exception Test Transformation|assertThrows" "$SM"
check "spoke-migrate.md has JUnit build config changes"             grep -qiE "Gradle Transformation|Maven Transformation" "$SM"

echo ""

# ── f. Cypress→Playwright Content (4 checks) ────────────────────────────────
echo "--- f. Cypress→Playwright Content ---"

check "spoke-migrate.md has Cypress→Playwright command mapping"     grep -qiE "cy\.visit.*page\.goto|Command Transformation.*cypress" "$SM"
check "spoke-migrate.md has Cypress→Playwright assertion mapping"   grep -qiE "\.should.*expect.*toBeVisible|Assertion Transformation" "$SM"
check "spoke-migrate.md has Cypress→Playwright hook mapping"        grep -qiE "beforeEach.*test\.beforeEach|Hook Transformation" "$SM"
check "spoke-migrate.md has partial transformation flag/manual review" grep -qiE "partial.transformation|manual.review.*flag" "$SM"

echo ""

# ── g. Git Rollback (3 checks) ──────────────────────────────────────────────
echo "--- g. Git Rollback ---"

check "spoke-migrate.md documents git stash mechanism"              grep -qiE "git.stash" "$SM"
check "spoke-migrate.md documents backup state file schema"         grep -qiE "migration-backup.json" "$SM"
check "spoke-migrate.md documents non-git fallback (block migration)" grep -qiE "BLOCK.*git.*migration|git.repository.required" "$SM"

echo ""

# ── h. SKILL.md Integration (5 checks) ──────────────────────────────────────
echo "--- h. SKILL.md Integration ---"

SKILL="$SKILL_DIR/SKILL.md"
check "SKILL.md has migrate command in routing table"              grep -q "spoke-migrate.md" "$SKILL"
check "SKILL.md documents supported migration paths"               grep -qiE "Supported migration paths" "$SKILL"
check "SKILL.md has Context7 mappings for migration targets"       grep -qiE "Migration Target Mappings" "$SKILL"
check "SKILL.md documents --gradual flag"                          grep -q "\-\-gradual" "$SKILL"
check "SKILL.md has Migration Command Routing subsection"          grep -qiE "Migration Command Routing" "$SKILL"

echo ""

# ── i. Cross-File Consistency (3 checks) ────────────────────────────────────
echo "--- i. Cross-File Consistency ---"

check "spoke-migrate.md references migration-rules.md"             grep -q "migration-rules.md" "$SM"
check "spoke-migrate.md references spoke-run.md for verification"  grep -q "spoke-run.md" "$SM"
check "spoke-migrate.md references spoke-fix.md for auto-fix"      grep -q "spoke-fix.md" "$SM"

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All M003/S05 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
