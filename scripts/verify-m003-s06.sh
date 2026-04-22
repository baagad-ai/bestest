#!/usr/bin/env bash
# verify-m003-s06.sh — Structural verification for M003/S06 (Coverage/Scan/Config multi-language) deliverables
# Validates spoke-coverage.md, spoke-scan.md, and spoke-config.md for Python/Java/Go extensions.

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

echo "=== M003/S06 Structural Verification (Coverage/Scan/Config Multi-Language) ==="
echo ""

# ── a. File Existence (3 checks) ─────────────────────────────────────────────
echo "--- a. File Existence ---"

check "spoke-coverage.md exists"      test -f "$SKILL_DIR/references/spoke-coverage.md"
check "spoke-scan.md exists"          test -f "$SKILL_DIR/references/spoke-scan.md"
check "spoke-config.md exists"        test -f "$SKILL_DIR/references/spoke-config.md"

echo ""

# ── b. spoke-coverage.md — Multi-Language Extensions (10 checks) ─────────────
echo "--- b. spoke-coverage.md — Multi-Language Extensions ---"

SC="$SKILL_DIR/references/spoke-coverage.md"

check "spoke-coverage.md has language-specific raw coverage artifacts (Pre-Flight)" \
  grep -qiE "language.specific raw coverage artifacts" "$SC"

check "spoke-coverage.md has Python coverage.py JSON parsing (Phase 1)" \
  grep -q "coverage.py JSON" "$SC"

check "spoke-coverage.md has Java JaCoCo XML parsing (Phase 1)" \
  grep -q "JaCoCo XML" "$SC"

check "spoke-coverage.md has Go coverage.out parsing (Phase 1)" \
  grep -q "coverage.out" "$SC"

check "spoke-coverage.md has Python test naming conventions (test_*.py)" \
  grep -q "test_.*\\.py" "$SC"

check "spoke-coverage.md has Java test naming conventions (*Test.java)" \
  grep -q "Test.java" "$SC"

check "spoke-coverage.md has Go test naming conventions (*_test.go)" \
  grep -q "_test.go" "$SC"

check "spoke-coverage.md has null metric handling (n/a status)" \
  grep -qiE "n/a|null metric" "$SC"

check "spoke-coverage.md has Error Handling #7 (pytest-cov)" \
  grep -qiE "pytest.cov not installed" "$SC"

check "spoke-coverage.md has Error Handling #8-10 (JaCoCo/Go/Mixed)" \
  grep -q "JaCoCo report not found" "$SC"

echo ""

# ── c. spoke-scan.md — Multi-Language Extensions (10 checks) ─────────────────
echo "--- c. spoke-scan.md — Multi-Language Extensions ---"

SS="$SKILL_DIR/references/spoke-scan.md"

check "spoke-scan.md has Python framework detection (pytest)" \
  grep -q "pytest" "$SS"

check "spoke-scan.md has Java framework detection (junit5)" \
  grep -q "junit5" "$SS"

check "spoke-scan.md has Go framework detection (go_testing)" \
  grep -q "go_testing" "$SS"

check "spoke-scan.md has Python test discovery (test_*.py)" \
  grep -q "test_.*\\.py" "$SS"

check "spoke-scan.md has Java test discovery (*Test.java)" \
  grep -q "Test.java" "$SS"

check "spoke-scan.md has Go test discovery (*_test.go)" \
  grep -q "_test.go" "$SS"

check "spoke-scan.md has anti-pattern patterns for Python (tautological-assertions)" \
  grep -q "tautological-assertions" "$SS"

check "spoke-scan.md has flakiness signals for Python/Java/Go" \
  grep -qE "freezegun|DirtiesContext|unbuffered" "$SS"

check "spoke-scan.md has Error Handling #9 (pytest-cov)" \
  grep -qiE "pytest.cov Not Installed" "$SS"

check "spoke-scan.md has Error Handling #10-12 (JaCoCo/Go/Mixed)" \
  grep -q "JaCoCo Report Not Found" "$SS"

echo ""

# ── d. spoke-config.md — Multi-Language Extensions (10 checks) ───────────────
echo "--- d. spoke-config.md — Multi-Language Extensions ---"

CFG="$SKILL_DIR/references/spoke-config.md"

check "spoke-config.md has language field in Core section" \
  grep -q "language" "$CFG"

check "spoke-config.md framework values include pytest, junit5, go_testing" \
  grep -q "go_testing" "$CFG"

check "spoke-config.md has pytest.* validation table (6 fields)" \
  grep -q "pytest.config_path" "$CFG"

check "spoke-config.md has junit5.* validation table (9 fields)" \
  grep -q "junit5.build_tool" "$CFG"

check "spoke-config.md has go.* validation table (16 fields)" \
  grep -q "go.module_path" "$CFG"

check "spoke-config.md set workflow lists pytest keys" \
  grep -q "pytest: pytest.config_path" "$CFG"

check "spoke-config.md set workflow lists junit5 keys" \
  grep -q "JUnit5: junit5.build_tool" "$CFG"

check "spoke-config.md set workflow lists go keys" \
  grep -q "Go: go.module_path" "$CFG"

check "spoke-config.md reset workflow has config-pytest.yaml template routing" \
  grep -q "config-pytest.yaml" "$CFG"

check "spoke-config.md validate workflow has language consistency check" \
  grep -qiE "Language consistency" "$CFG"

echo ""

# ── e. Cross-Spoke Consistency (4 checks) ────────────────────────────────────
echo "--- e. Cross-Spoke Consistency ---"

check "spoke-config.md references spoke-coverage.md in Downstream" \
  grep -q "coverage" "$CFG"

check "spoke-config.md references spoke-scan.md in Downstream" \
  grep -q "scan" "$CFG"

check "All three spokes reference same framework field (vitest/jest/pytest/junit5/go_testing)" \
  bash -c "for f in $SKILL_DIR/references/spoke-coverage.md $SKILL_DIR/references/spoke-scan.md $SKILL_DIR/references/spoke-config.md; do grep -q go_testing \"\$f\" || exit 1; done"

check "spoke-config.md code blocks balanced (even count)" \
  bash -c 'count=$(grep -c "^\`\`\`" "$CFG"); [ $((count % 2)) -eq 0 ]'

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All M003/S06 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
