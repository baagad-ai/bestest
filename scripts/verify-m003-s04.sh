#!/usr/bin/env bash
# verify-m003-s04.sh — Structural verification for M003/S04 (CI Spoke) deliverables
# Validates file existence, spoke structure completeness, all 6 phases present,
# HITL gate, error handling, cross-references, multi-language handling, config update logic.

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

echo "=== M003/S04 Structural Verification (CI Spoke) ==="
echo ""

# ── T01 Checks: CI patterns and templates ──────────────────────────────────────

echo "--- a. T01: File Existence (CI patterns + 3 templates) ---"

check "ci-patterns.md exists"                          test -f "$SKILL_DIR/references/ci-patterns.md"
check "templates/ci/github-actions-test.yml exists"    test -f "$SKILL_DIR/references/templates/ci/github-actions-test.yml"
check "templates/ci/gitlab-ci-test.yml exists"         test -f "$SKILL_DIR/references/templates/ci/gitlab-ci-test.yml"
check "templates/ci/jenkinsfile-test.groovy exists"    test -f "$SKILL_DIR/references/templates/ci/jenkinsfile-test.groovy"

echo ""

echo "--- b. T01: CI Patterns Content ---"

CP="$SKILL_DIR/references/ci-patterns.md"
check "ci-patterns.md has 4-Stage Architecture section"      grep -q "4-Stage Architecture" "$CP"
check "ci-patterns.md has Coverage Gates section"            grep -q "Coverage Gates" "$CP"
check "ci-patterns.md has Flaky Test Handling section"       grep -q "Flaky Test Handling" "$CP"
check "ci-patterns.md has Multi-Language Monorepo section"    grep -q "Multi-Language Monorepo" "$CP"
check "ci-patterns.md references vitest/pytest/go test"       grep -q "vitest" "$CP" && grep -q "pytest" "$CP" && grep -q "go test" "$CP"

echo ""

echo "--- c. T01: YAML Template Validity ---"

GA="$SKILL_DIR/references/templates/ci/github-actions-test.yml"
GL="$SKILL_DIR/references/templates/ci/gitlab-ci-test.yml"
JK="$SKILL_DIR/references/templates/ci/jenkinsfile-test.groovy"

# GitHub Actions YAML validity
check "github-actions-test.yml is valid YAML"              python3 -c "import yaml; yaml.safe_load(open('$GA'))"
check "gitlab-ci-test.yml is valid YAML"                    python3 -c "import yaml; yaml.safe_load(open('$GL'))"

echo ""

echo "--- d. T01: 4-Stage Structure in Templates ---"

# GitHub Actions stage labels
check "github-actions has fast stage jobs"                  grep -q "fast-" "$GA"
check "github-actions has medium stage jobs"                grep -q "medium-" "$GA"
check "github-actions has slow stage jobs"                  grep -q "slow-" "$GA"
check "github-actions has quality stage jobs"               grep -q "quality" "$GA"

# GitLab CI stages
check "gitlab-ci defines 4 stages"                          grep -q "fast" "$GL" && grep -q "medium" "$GL" && grep -q "slow" "$GL" && grep -q "quality" "$GL"

# Jenkins stages
check "jenkinsfile has 4 stages"                            grep -q "Fast" "$JK" && grep -q "Medium" "$JK" && grep -q "Slow" "$JK" && grep -q "Quality" "$JK"

echo ""

echo "--- e. T01: Language Commands Present ---"

# Check all templates reference all 4 languages
check "github-actions has JS/TS commands (vitest/jest)"     grep -qE "vitest|jest" "$GA"
check "github-actions has Python commands (pytest)"          grep -q "pytest" "$GA"
check "github-actions has Java commands (gradlew/mvnw)"     grep -qE "gradlew|mvnw" "$GA"
check "github-actions has Go commands (go test)"             grep -q "go test" "$GA"

check "gitlab-ci has Python commands (pytest)"               grep -q "pytest" "$GL"
check "gitlab-ci has Go commands (go test)"                  grep -q "go test" "$GL"

check "jenkinsfile has Java commands (gradlew)"              grep -q "gradlew" "$JK"
check "jenkinsfile has Python commands (pytest)"             grep -q "pytest" "$JK"

echo ""

echo "--- f. T01: Coverage Gates ---"

check "github-actions has coverage gate (COVERAGE_THRESHOLD)"  grep -q "COVERAGE_THRESHOLD" "$GA"
check "gitlab-ci has coverage gate"                             grep -q "COVERAGE_THRESHOLD" "$GL"
check "jenkinsfile has coverage gate"                           grep -q "COVERAGE_THRESHOLD" "$JK"

echo ""

echo "--- g. T01: Retry Logic ---"

check "github-actions has retry loops"                         grep -qE "for i in|retry" "$GA"
check "gitlab-ci has retry keyword"                             grep -q "retry" "$GL"
check "jenkinsfile has retry blocks"                            grep -q "retry" "$JK"

echo ""

# ── T02 Checks: CI Generation Spoke ────────────────────────────────────────────

echo "--- h. T02: spoke-ci.md File Existence ---"

SC="$SKILL_DIR/references/spoke-ci.md"
check "spoke-ci.md exists"                                     test -f "$SC"

SC_LINES=$(wc -l < "$SC" 2>/dev/null | tr -d ' ' || echo "0")
check "spoke-ci.md is 700+ lines (found $SC_LINES)"            [ "$SC_LINES" -ge 700 ]

echo ""

echo "--- i. T02: Spoke Structure Completeness ---"

check "spoke-ci.md has Purpose section"                        grep -q "## Purpose" "$SC"
check "spoke-ci.md has Prerequisites section"                  grep -q "## Prerequisites" "$SC"
check "spoke-ci.md has Pre-Flight Checks section"              grep -q "## Pre-Flight Checks" "$SC"
check "spoke-ci.md has Error Handling section"                 grep -q "## Error Handling" "$SC"
check "spoke-ci.md has Downstream Reference section"           grep -q "## Downstream Reference" "$SC"
check "spoke-ci.md has Output section"                         grep -q "## Output" "$SC"
check "spoke-ci.md has See Also section"                       grep -q "## See Also" "$SC"

echo ""

echo "--- j. T02: All 6 Phases Present ---"

check "spoke-ci.md has Phase 1 (Detect CI Provider)"           grep -q "Phase 1" "$SC" && grep -qi "detect.*provider" "$SC"
check "spoke-ci.md has Phase 2 (Fetch Provider Docs)"          grep -q "Phase 2" "$SC" && grep -qi "provider.*doc\|Context7" "$SC"
check "spoke-ci.md has Phase 3 (Stage Definition)"             grep -q "Phase 3" "$SC" && grep -qi "stage.*definition\|Stage Definition" "$SC"
check "spoke-ci.md has Phase 4 (Template Assembly)"            grep -q "Phase 4" "$SC" && grep -qi "template.*assembly\|Template Assembly" "$SC"
check "spoke-ci.md has Phase 5 (HITL Gate)"                    grep -q "Phase 5" "$SC" && grep -qi "HITL\|human.in.the.loop" "$SC"
check "spoke-ci.md has Phase 6 (Write Files)"                  grep -q "Phase 6" "$SC" && grep -qi "write.*file\|Write Files" "$SC"

echo ""

echo "--- k. T02: HITL Gate Detail ---"

check "spoke-ci.md has Approve/Modify/Cancel options"          grep -qi "approve" "$SC" && grep -qi "cancel" "$SC"
check "spoke-ci.md describes edit-before-write flow"           grep -qi "edit" "$SC"

echo ""

echo "--- l. T02: Error Handling Scenarios ---"

EH_COUNT=$(grep -cE "^### [0-9]+\." "$SC" 2>/dev/null || echo "0")
check "spoke-ci.md has 6+ error scenarios (found $EH_COUNT)"   [ "$EH_COUNT" -ge 6 ]

check "spoke-ci.md handles no-config error"                    grep -qi "no .bestest\|\.bestest.*does not exist" "$SC"
check "spoke-ci.md handles unknown provider"                   grep -qi "unknown.*provider\|unknown CI" "$SC"
check "spoke-ci.md handles write permission"                   grep -qi "write permission\|permission denied\|cannot write" "$SC"
check "spoke-ci.md handles Context7 unavailable"               grep -qi "context7.*unavailable\|could not fetch" "$SC"

echo ""

echo "--- m. T02: Cross-References ---"

check "spoke-ci.md references ci-patterns.md"                  grep -q "ci-patterns" "$SC"
check "spoke-ci.md references spoke-doctor"                    grep -q "spoke-doctor" "$SC"
check "spoke-ci.md references config-schema"                   grep -q "config-schema" "$SC"
check "spoke-ci.md references templates/ci/"                   grep -q "templates/ci" "$SC"
check "spoke-ci.md references spoke-run"                       grep -q "spoke-run" "$SC"

echo ""

echo "--- n. T02: Multi-Language Handling ---"

check "spoke-ci.md has multi-language monorepo section"        grep -qi "multi.language\|monorepo" "$SC"
check "spoke-ci.md describes parallel jobs per language"        grep -qi "parallel.*job\|parallel.*language" "$SC"
check "spoke-ci.md has weighted coverage aggregation"          grep -qi "weighted.*coverage\|weighted.*average" "$SC"
check "spoke-ci.md describes all 4 languages (JS/TS/Python/Java/Go)"  grep -qiE "javascript|typescript" "$SC" && grep -qi "python" "$SC" && grep -qi "java" "$SC" && grep -qi "go\b" "$SC"

echo ""

echo "--- o. T02: Config Update Logic ---"

check "spoke-ci.md describes ci.enabled update"                grep -q "ci.enabled" "$SC"
check "spoke-ci.md describes ci.provider update"               grep -q "ci.provider" "$SC"
check "spoke-ci.md describes state.last_ci update"             grep -q "state.last_ci" "$SC"

echo ""

echo "--- p. T02: Provider Coverage ---"

check "spoke-ci.md covers GitHub Actions"                      grep -qi "github.actions" "$SC"
check "spoke-ci.md covers GitLab CI"                           grep -qi "gitlab.ci" "$SC"
check "spoke-ci.md covers Jenkins"                             grep -qi "jenkins" "$SC"

echo ""

echo "--- q. T02: Per-Stage Command Tables ---"

check "spoke-ci.md has Fast stage commands"                    grep -qi "fast.*command\|fast stage" "$SC"
check "spoke-ci.md has Medium stage commands"                  grep -qi "medium.*command\|medium stage" "$SC"
check "spoke-ci.md has Slow stage commands"                    grep -qi "slow.*command\|slow stage" "$SC"
check "spoke-ci.md has Quality stage commands"                 grep -qi "quality.*command\|quality stage\|mutation" "$SC"

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All M003/S04 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
