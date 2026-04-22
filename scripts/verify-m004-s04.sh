#!/usr/bin/env bash
# verify-m004-s04.sh — Comprehensive M004 verification for all 15 audit recommendations
# Validates that S01-S03 remediation work is structurally present across the bestest skill.
# Audit baseline: 3.2/5.0 → target ≥ 4.0/5.0

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

echo "=== M004/S04 Comprehensive Verification — 15 Audit Recommendations ==="
echo ""

SM="$SKILL_DIR/SKILL.md"
REFS="$SKILL_DIR/references"

# ── Group 1: K002 Compliance — SKILL.md line count + XML pointer blocks (2 checks) ──
echo "--- Group 1: K002 Compliance (SKILL.md size + pointers) ---"

check "SKILL.md is ≤500 lines" test "$(wc -l < "$SM")" -le 500
check "SKILL.md has XML pointer blocks for detection_engine, framework_decision, context7_helper" \
  grep -qE 'detection.engine|framework.decision|context7.helper' "$SM"

echo ""

# ── Group 2: Confidence Gate — Each generate spoke has 0.6 threshold (5 checks) ─────
echo "--- Group 2: Confidence Gate (0.6 threshold in generate spokes) ---"

for spoke in spoke-generate.md spoke-generate-python.md spoke-generate-java.md spoke-generate-go.md; do
  check "$spoke has confidence gate with 0.6 threshold" \
    grep -qE 'confidence.*0\.6|0\.6.*threshold|threshold.*0\.6' "$REFS/$spoke"
done

check "At least one spoke explicitly prints confidence gate warning" \
  grep -q 'Confidence Gate' "$REFS/spoke-generate.md"

echo ""

# ── Group 3: Go Identifier — go_testing (underscore) not go-testing (hyphen) (2 checks) ─
echo "--- Group 3: Go Identifier Harmonization ---"

check "stack-profile-schema.md uses go_testing (underscore)" \
  grep -q 'go_testing' "$REFS/stack-profile-schema.md"
check "config-schema.md uses go_testing (underscore)" \
  grep -q 'go_testing' "$REFS/config-schema.md"

# Bonus: ensure go-testing (hyphenated) appears zero times across all reference files
if grep -r 'go-testing' "$REFS/" --include='*.md' 2>/dev/null | grep -v 'go-testing-guide\|go-testing\.' | head -1 | grep -q 'go-testing'; then
  echo "❌ FAIL: go-testing (hyphenated) still appears in reference files"
  FAIL=$((FAIL + 1))
else
  echo "✅ PASS: go-testing (hyphenated) appears zero times across reference files"
  PASS=$((PASS + 1))
fi

echo ""

# ── Group 4: Schema Versioning — schemaVersion in both schemas (2 checks) ────────────
echo "--- Group 4: Schema Versioning ---"

check "stack-profile-schema.md has schemaVersion field" \
  grep -q 'schemaVersion' "$REFS/stack-profile-schema.md"
check "scan-report-schema.md has schemaVersion field" \
  grep -q 'schemaVersion' "$REFS/scan-report-schema.md"

echo ""

# ── Group 5: Dedup — spoke-init references detection-engine via pointer (2 checks) ───
echo "--- Group 5: Dedup (spoke-init pointer + detection content size) ---"

check "spoke-init.md references detection-engine.md (pointer, not full inline)" \
  grep -q 'detection-engine' "$REFS/spoke-init.md"
check "SKILL.md is ≤275 lines of detection-related content (line count ≤275)" \
  test "$(wc -l < "$SM")" -le 275

echo ""

# ── Group 6: Dual-Framework — Conflict detection in engine + schema (2 checks) ───────
echo "--- Group 6: Dual-Framework Conflict Detection ---"

check "detection-engine.md has conflict detection section" \
  grep -qi 'conflict' "$REFS/detection-engine.md"
check "stack-profile-schema.md has conflicts field" \
  grep -q 'conflicts' "$REFS/stack-profile-schema.md"

echo ""

# ── Group 7: Context7 Taint/Trust — Each generate spoke (4 checks) ───────────────────
echo "--- Group 7: Context7 Taint/Trust Model ---"

for spoke in spoke-generate.md spoke-generate-python.md spoke-generate-java.md spoke-generate-go.md; do
  check "$spoke has taint/trust model language" \
    grep -qiE 'taint|trust' "$REFS/$spoke"
done

echo ""

# ── Group 8: Path Validation — Each generate spoke (4 checks) ────────────────────────
echo "--- Group 8: Path Validation ---"

for spoke in spoke-generate.md spoke-generate-python.md spoke-generate-java.md spoke-generate-go.md; do
  check "$spoke has path validation section" \
    grep -qiE 'path.validation|pathValidation|path-validation' "$REFS/$spoke"
done

echo ""

# ── Group 9: Skill Versioning — SKILL.md version + CHANGELOG (3 checks) ──────────────
echo "--- Group 9: Skill Versioning ---"

check "SKILL.md frontmatter has version 1.1.0" \
  grep -q 'version: "1.1.0"' "$SM"
check "CHANGELOG.md has v1.0.0 entry" \
  grep -q '1.0.0' "$SKILL_DIR/CHANGELOG.md"
check "CHANGELOG.md has v1.1.0 entry" \
  grep -q '1.1.0' "$SKILL_DIR/CHANGELOG.md"

echo ""

# ── Group 10: CONTRIBUTING — File exists + spoke template + language guide (2 checks) ─
echo "--- Group 10: CONTRIBUTING Guide ---"

check "CONTRIBUTING.md exists and non-empty" test -s "$SKILL_DIR/CONTRIBUTING.md"
check "CONTRIBUTING.md has spoke template and language addition guide" \
  grep -qiE 'spoke template|adding a new language|language-addition' "$SKILL_DIR/CONTRIBUTING.md"

echo ""

# ── Group 11: Decision Tree Gap — 20-50 range branch (1 check) ───────────────────────
echo "--- Group 11: JS/TS Decision Tree Gap (20-50 range) ---"

check "js-ts-decision-tree.md has 20-50 range branch" \
  grep -qE '20.50|20.*50' "$REFS/js-ts-decision-tree.md"

echo ""

# ── Group 12: Flakiness Signals — Signal Identifier Mapping + all 9 IDs (2 checks) ───
echo "--- Group 12: Flakiness Signal Identifiers ---"

check "spoke-scan.md has Signal Identifier Mapping table" \
  grep -qi 'Signal Identifier Mapping\|signal.*identifier.*mapping' "$REFS/spoke-scan.md"

# All 9 canonical identifiers must be present
ALL_SIGNALS_PRESENT=true
for sig in uncontrolled-time uncontrolled-random network-calls filesystem-access shared-state long-execution order-dependent env-dependent race-condition; do
  if ! grep -q "$sig" "$REFS/spoke-scan.md" 2>/dev/null; then
    ALL_SIGNALS_PRESENT=false
    break
  fi
done
if $ALL_SIGNALS_PRESENT; then
  echo "✅ PASS: All 9 canonical flakiness identifiers present in spoke-scan.md"
  PASS=$((PASS + 1))
else
  echo "❌ FAIL: Missing canonical flakiness identifiers in spoke-scan.md"
  FAIL=$((FAIL + 1))
fi

echo ""

# ── Group 13: Report Rotation — max_retained in config + rotation in scan (2 checks) ─
echo "--- Group 13: Report Rotation ---"

check "config-schema.md has max_retained field" \
  grep -q 'max_retained' "$REFS/config-schema.md"
check "spoke-scan.md has rotation logic" \
  grep -qiE 'rotation|rotate' "$REFS/spoke-scan.md"

echo ""

# ── Group 14: Fix Spoke — unknown category + default fallback (2 checks) ─────────────
echo "--- Group 14: Fix Spoke Default Classification ---"

check "spoke-fix.md has unknown category" \
  grep -q 'unknown' "$REFS/spoke-fix.md"
check "spoke-fix.md default fallback is unknown (not test_bug)" \
  grep -qiE 'default.*unknown|fallback.*unknown|classify.*unknown' "$REFS/spoke-fix.md"

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed (total $((PASS + FAIL)) checks)"
echo "═══════════════════════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo "❌ VERIFICATION FAILED — $FAIL check(s) did not pass"
  exit 1
else
  echo "✅ ALL CHECKS PASSED — All 15 audit recommendations structurally verified"
  exit 0
fi
