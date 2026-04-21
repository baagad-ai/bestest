#!/usr/bin/env bash
# verify-m003-s01.sh — Structural verification for M003/S01 (Python spoke) deliverables
# Validates file existence, decision tree, config template, generation guide,
# generation spoke, run/fix extensions, SKILL.md routing, and cross-file consistency.

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

echo "=== M003/S01 Structural Verification (Python Spoke) ==="
echo ""

# ── a. File Existence (6 checks) ─────────────────────────────────────────────
echo "--- a. File Existence ---"

check "python-decision-tree.md exists"       test -f "$SKILL_DIR/references/python-decision-tree.md"
check "templates/config-pytest.yaml exists"  test -f "$SKILL_DIR/references/templates/config-pytest.yaml"
check "python-generation-guide.md exists"    test -f "$SKILL_DIR/references/python-generation-guide.md"
check "spoke-generate-python.md exists"      test -f "$SKILL_DIR/references/spoke-generate-python.md"
check "spoke-run.md exists"                  test -f "$SKILL_DIR/references/spoke-run.md"
check "spoke-fix.md exists"                  test -f "$SKILL_DIR/references/spoke-fix.md"

echo ""

# ── b. Decision Tree Completeness (3 checks) ─────────────────────────────────
echo "--- b. Decision Tree Completeness ---"

DT="$SKILL_DIR/references/python-decision-tree.md"
DT_STEPS=$(grep -cE "^## Step|^### Step" "$DT" || true)
check "python-decision-tree has 4+ decision steps (found $DT_STEPS)" [ "$DT_STEPS" -ge 4 ]
check "python-decision-tree references pytest/FastAPI/Flask/Django" grep -qiE "pytest|FastAPI|Flask|Django" "$DT"
check "python-decision-tree has ADR template or cross-reference"     grep -qiE "ADR|architectural decision" "$DT"

echo ""

# ── c. Config Template Validity (3 checks) ───────────────────────────────────
echo "--- c. Config Template Validity ---"

CFG="$SKILL_DIR/references/templates/config-pytest.yaml"
check "config-pytest.yaml has framework: pytest"   grep -q "framework: pytest" "$CFG"
check "config-pytest.yaml has paths section with Python globs" grep -qE '__pycache__|\.pyc|venv' "$CFG"
check "config-pytest.yaml has generation section"  grep -qE "generation:" "$CFG"

echo ""

# ── d. Generation Guide Completeness (4 checks) ──────────────────────────────
echo "--- d. Generation Guide Completeness ---"

GG="$SKILL_DIR/references/python-generation-guide.md"
GG_SECTIONS=$(grep -c "^## " "$GG" || true)
check "python-generation-guide has 6+ main sections (found $GG_SECTIONS)" [ "$GG_SECTIONS" -ge 6 ]
check "python-generation-guide has quality rubric/scoring"   grep -qiE "quality.*(rubric|score)|rubric|scoring" "$GG"
check "python-generation-guide has pytest fixture patterns"  grep -qiE "fixture|@pytest.fixture" "$GG"
check "python-generation-guide has FastAPI/Django/Flask test client patterns" grep -qiE "TestClient|test.client|test_client" "$GG"

echo ""

# ── e. Generation Spoke Completeness (10 checks) ─────────────────────────────
echo "--- e. Generation Spoke Completeness ---"

GS="$SKILL_DIR/references/spoke-generate-python.md"
check "spoke-generate-python has Pre-Flight section"          grep -qiE "pre.?flight" "$GS"
GS_PHASES=$(grep -cE "^## Phase|^### Phase" "$GS" || true)
check "spoke-generate-python has all 7 phases (found $GS_PHASES)" [ "$GS_PHASES" -ge 7 ]
check "spoke-generate-python has HITL Gate section"           grep -qiE "HITL|human.in.the.loop" "$GS"
check "spoke-generate-python has Error Handling section"      grep -qiE "error.handling" "$GS"
check "spoke-generate-python has Downstream Reference"        grep -qiE "downstream" "$GS"
check "spoke-generate-python references python-generation-guide" grep -q "python-generation-guide" "$GS"
check "spoke-generate-python references anti-patterns"        grep -qiE "anti.?pattern|antipattern" "$GS"
check "spoke-generate-python references config-schema/yaml"   grep -qiE "config.schema|config.yaml|config-schema" "$GS"

GS_LINES=$(wc -l < "$GS" | tr -d ' ')
check "spoke-generate-python is 800+ lines (found $GS_LINES)" [ "$GS_LINES" -ge 800 ]

# Cross-reference to decision tree or framework selection
check "spoke-generate-python has framework detection logic" grep -qiE "framework.*(detect|determin)|detect.*framework" "$GS"

echo ""

# ── f. Run/Fix Extension Verification (4 checks) ────────────────────────────
echo "--- f. Run/Fix Extension Verification ---"

SR="$SKILL_DIR/references/spoke-run.md"
SF="$SKILL_DIR/references/spoke-fix.md"
check "spoke-run.md mentions pytest"                  grep -qi "pytest" "$SR"
check "spoke-run.md has language field handling"       grep -qi "language" "$SR"
check "spoke-run.md has virtualenv handling"           grep -qiE "virtualenv|venv" "$SR"
check "spoke-fix.md mentions Python-specific patterns (ModuleNotFoundError)" grep -q "ModuleNotFoundError" "$SF"

echo ""

# ── g. SKILL.md Routing (3 checks) ──────────────────────────────────────────
echo "--- g. SKILL.md Routing ---"

SM="$SKILL_DIR/SKILL.md"
check "SKILL.md references spoke-generate-python"     grep -q "spoke-generate-python" "$SM"
check "SKILL.md Context7 mappings include Python frameworks (pytest/FastAPI/Flask)" grep -qiE "pytest|FastAPI|Flask" "$SM"
check "SKILL.md has language dispatch mechanism"       grep -qiE "language.*(dispatch|routing)|python.*spoke|spoke.*python" "$SM"

echo ""

# ── h. Cross-File Consistency (2 checks) ────────────────────────────────────
echo "--- h. Cross-File Consistency ---"

check "spoke-generate-python references python-generation-guide.md" grep -q "python-generation-guide" "$GS"
check "spoke-generate-python references anti-patterns"        grep -qiE "anti.?pattern" "$GS"
check "spoke-generate-python references config-schema/yaml"    grep -qiE "config.schema|config.yaml" "$GS"

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All M003/S01 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
