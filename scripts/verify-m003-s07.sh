#!/usr/bin/env bash
# verify-m003-s07.sh — Structural verification for M003/S07 (Doctor/Report/Expand multi-language) deliverables
# Validates spoke-doctor.md, spoke-report.md, and spoke-expand.md for Python/Java/Go extensions.

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

echo "=== M003/S07 Structural Verification (Doctor/Report/Expand Multi-Language) ==="
echo ""

# ── 1. File Existence (3 checks) ─────────────────────────────────────────────
echo "--- 1. File Existence ---"

SD="$SKILL_DIR/references/spoke-doctor.md"
SR="$SKILL_DIR/references/spoke-report.md"
SE="$SKILL_DIR/references/spoke-expand.md"

check "spoke-doctor.md exists and non-empty" test -s "$SD"
check "spoke-report.md exists and non-empty" test -s "$SR"
check "spoke-expand.md exists and non-empty" test -s "$SE"

echo ""

# ── 2. Doctor spoke checks (12 checks) ───────────────────────────────────────
echo "--- 2. spoke-doctor.md — Multi-Language Extensions ---"

check "Phase 2 references pyproject.toml (Python manifest)" \
  grep -q "pyproject.toml" "$SD"

check "Phase 2 references build.gradle (Java manifest)" \
  grep -q "build.gradle" "$SD"

check "Phase 2 references go.mod (Go manifest)" \
  grep -q "go.mod" "$SD"

check "Phase 2 has language dispatch block (If language is python/java/go branches)" \
  grep -qE 'If language is "python"' "$SD"

check "Phase 3 accepts pytest as valid framework value" \
  grep -q '"pytest"' "$SD"

check "Phase 3 accepts junit5 as valid framework value" \
  grep -q '"junit5"' "$SD"

check "Phase 3 accepts go_testing as valid framework value" \
  grep -q '"go_testing"' "$SD"

check "Phase 3 has language-specific config block checks (pytest.*/junit5.*/go.*)" \
  grep -qE "pytest\.\*|junit5\.\*|go\.\*" "$SD"

check "Phase 8 has CI health scored transition (score = 70 for configured_unknown)" \
  grep -q "score = 70" "$SD"

check "Phase 8 has GitLab CI check (glab CLI)" \
  grep -q "glab" "$SD"

check "Phase 11 has language-aware remediation (pip install for Python)" \
  grep -q "pip install" "$SD"

check "Error handling has Python/Java/Go manifest not-found scenarios" \
  bash -c 'grep -q "Python manifest not found" "$0" && grep -q "Java manifest not found" "$0" && grep -q "Go manifest not found" "$0"' "$SD"

echo ""

# ── 3. Report spoke checks (9 checks) ────────────────────────────────────────
echo "--- 3. spoke-report.md — Multi-Language Extensions ---"

check "Phase 1 extracts language field from run-results.json" \
  grep -qE "language.*run.results|language.*string" "$SR"

check "Phase 1 builds language inventory (isMultiLanguage flag)" \
  grep -q "isMultiLanguage" "$SR"

check "Coverage heatmap has Language column for multi-language" \
  bash -c 'grep -q "Language column" "$0" && grep -q "isMultiLanguage" "$0"' "$SR"

check "Summary table has per-language pass rates when multi-language" \
  grep -qE "per.language.*pass rate|per-language.*pass" "$SR"

check "Report header includes language(s)" \
  grep -qE "Language:.*language|multi-language" "$SR"

check "Run history has Language column when multi-language" \
  bash -c 'grep -q "Language column" "$0" && grep -q "isMultiLanguage" "$0"' "$SR"

check "Handles n/a for language-specific unavailable metrics" \
  grep -q "n/a" "$SR"

check "Handles Python metrics (coverage.py no statements)" \
  grep -qiE "coverage\.py|no statements" "$SR"

check "Handles Go metrics (no branches metric)" \
  grep -qiE "no branch|go test" "$SR"

echo ""

# ── 4. Expand spoke checks (12 checks) ───────────────────────────────────────
echo "--- 4. spoke-expand.md — Multi-Language Extensions ---"

check "Pre-Flight detects language from config.yaml" \
  grep -qE "language.*field|config\.language|language.*config" "$SE"

check "Test type catalog has Python framework options (requests, mutmut, pact-python, locust)" \
  bash -c 'grep -q "mutmut" "$0" && grep -q "pact-python" "$0" && grep -q "locust" "$0"' "$SE"

check "Test type catalog has Java framework options (rest-assured, pitest, pact-jvm)" \
  bash -c 'grep -q "rest-assured\|REST Assured" "$0" && grep -q "pitest" "$0" && grep -q "pact-jvm" "$0"' "$SE"

check "Test type catalog has Go framework options (net/http/httptest, pact-go)" \
  bash -c 'grep -q "httptest" "$0" && grep -q "pact-go" "$0"' "$SE"

check "Context7 mapping table includes Python libraries (requests, mutmut, locust)" \
  bash -c 'grep -q "/psf/requests" "$0" && grep -q "/boxed/mutmut" "$0" && grep -q "/locustio/locust" "$0"' "$SE"

check "Context7 mapping table includes Java libraries (rest-assured, pitest, pact-jvm)" \
  bash -c 'grep -q "/rest-assured/rest-assured" "$0" && grep -q "/hcoles/pitest" "$0" && grep -q "/DiUS/pact-jvm" "$0"' "$SE"

check "Phase 6 has Python scaffold templates (conftest.py)" \
  grep -q "conftest.py" "$SE"

check "Phase 6 has Java scaffold templates (REST Assured base)" \
  grep -qE "REST Assured base|ApiBaseTest" "$SE"

check "Phase 6 has Go scaffold templates (httptest)" \
  grep -q "httptest" "$SE"

check "Phase 7 has Python install commands (pip/poetry)" \
  bash -c 'grep -q "pip install" "$0" && grep -q "poetry add" "$0"' "$SE"

check "Phase 7 has Java install commands (gradle/maven)" \
  bash -c 'grep -q "./gradlew" "$0" || grep -q "gradle" "$0"' "$SE"

check "Phase 7 has Go install commands (go get)" \
  grep -q "go get" "$SE"

echo ""

# ── 5. Regression checks (3 checks) ──────────────────────────────────────────
echo "--- 5. Regression (JS/TS References Preserved) ---"

check "spoke-doctor.md still has vitest/jest references" \
  bash -c 'grep -q "vitest" "$0" && grep -q "jest" "$0"' "$SD"

check "spoke-report.md still has existing JS/TS report structure" \
  grep -q "javascript\|typescript" "$SR"

check "spoke-expand.md still has existing 6 test types with JS/TS frameworks" \
  bash -c 'grep -q "Playwright" "$0" && grep -q "Supertest\|Stryker\|Pact\|k6" "$0"' "$SE"

echo ""

# ── 6. File size checks (3 checks) ───────────────────────────────────────────
echo "--- 6. File Size Growth ---"

check "spoke-doctor.md grew from 1291 lines (now >1291)" \
  bash -c '[ $(wc -l < "$0") -gt 1291 ]' "$SD"

check "spoke-report.md grew from 929 lines (now >929)" \
  bash -c '[ $(wc -l < "$0") -gt 929 ]' "$SR"

check "spoke-expand.md grew from 1234 lines (now >1234)" \
  bash -c '[ $(wc -l < "$0") -gt 1234 ]' "$SE"

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All M003/S07 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
