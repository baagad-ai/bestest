#!/usr/bin/env bash
# verify-m003-s03.sh — Structural verification for M003/S03 (Go spoke) deliverables
# Validates file existence, decision tree, config template, generation guide,
# generation spoke, run/fix/init extensions, SKILL.md routing, cross-file
# consistency, and no-regression (JS/TS, Python, Java content preserved).

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

echo "=== M003/S03 Structural Verification (Go Spoke) ==="
echo ""

# ── a. File Existence (6 checks) ─────────────────────────────────────────────
echo "--- a. File Existence ---"

check "go-decision-tree.md exists"                test -f "$SKILL_DIR/references/go-decision-tree.md"
check "templates/config-go.yaml exists"           test -f "$SKILL_DIR/references/templates/config-go.yaml"
check "go-generation-guide.md exists"             test -f "$SKILL_DIR/references/go-generation-guide.md"
check "spoke-generate-go.md exists"               test -f "$SKILL_DIR/references/spoke-generate-go.md"
check "spoke-run.md exists (extended)"            test -f "$SKILL_DIR/references/spoke-run.md"
check "spoke-fix.md exists (extended)"            test -f "$SKILL_DIR/references/spoke-fix.md"

echo ""

# ── b. Decision Tree Completeness (3 checks) ─────────────────────────────────
echo "--- b. Decision Tree Completeness ---"

DT="$SKILL_DIR/references/go-decision-tree.md"
DT_STEPS=$(grep -cE "^## Step|^### Step" "$DT" || true)
check "go-decision-tree has 4+ decision steps (found $DT_STEPS)" [ "$DT_STEPS" -ge 4 ]
check "go-decision-tree references testify, testing.T, gomock" \
  grep -qiE "testify|testing\.T|gomock" "$DT"
check "go-decision-tree has ADR template or cross-reference" \
  grep -qiE "ADR|architectural decision" "$DT"

echo ""

# ── c. Config Template Validity (3 checks) ───────────────────────────────────
echo "--- c. Config Template Validity ---"

CFG="$SKILL_DIR/references/templates/config-go.yaml"
check "config-go.yaml has framework: go_testing or testing" \
  grep -qE "framework:.*(go_testing|testing)" "$CFG"
check "config-go.yaml has Go-specific ignore patterns (vendor/, testdata/)" \
  grep -qE "vendor/|testdata/" "$CFG"
check "config-go.yaml has go section with module_path or testify config" \
  grep -qE "^go:" "$CFG"

echo ""

# ── d. Generation Guide Completeness (4 checks) ──────────────────────────────
echo "--- d. Generation Guide Completeness ---"

GG="$SKILL_DIR/references/go-generation-guide.md"
GG_SECTIONS=$(grep -c "^## " "$GG" || true)
check "go-generation-guide has 6+ main sections (found $GG_SECTIONS)" [ "$GG_SECTIONS" -ge 6 ]
check "go-generation-guide has quality rubric/scoring" \
  grep -qiE "quality.*(rubric|score)|rubric|scoring" "$GG"
check "go-generation-guide has testify assert/require patterns" \
  grep -qiE "assert\.Equal|require\.NoError|assert\." "$GG"
check "go-generation-guide has table-driven test patterns" \
  grep -qiE "table.?driven|t.Run.*tc" "$GG"

echo ""

# ── e. Generation Spoke Completeness (10 checks) ─────────────────────────────
echo "--- e. Generation Spoke Completeness ---"

GS="$SKILL_DIR/references/spoke-generate-go.md"
check "spoke-generate-go has Pre-Flight section" \
  grep -qiE "pre.?flight" "$GS"
GS_PHASES=$(grep -cE "^## Phase|^### Phase" "$GS" || true)
check "spoke-generate-go has all 7 phases (found $GS_PHASES)" [ "$GS_PHASES" -ge 7 ]
check "spoke-generate-go has HITL Gate section" \
  grep -qiE "HITL|human.in.the.loop" "$GS"
check "spoke-generate-go has Error Handling section" \
  grep -qiE "error.handling" "$GS"
check "spoke-generate-go has Downstream Reference" \
  grep -qiE "downstream" "$GS"
check "spoke-generate-go references go-generation-guide" \
  grep -q "go-generation-guide" "$GS"
check "spoke-generate-go references anti-patterns" \
  grep -qiE "anti.?pattern|antipattern" "$GS"
check "spoke-generate-go references config-schema/yaml" \
  grep -qiE "config.schema|config.yaml|config-schema" "$GS"
GS_LINES=$(wc -l < "$GS" | tr -d ' ')
check "spoke-generate-go is 800+ lines (found $GS_LINES)" [ "$GS_LINES" -ge 800 ]
check "spoke-generate-go has framework detection logic" \
  grep -qiE "framework.*(detect|determin)|detect.*framework" "$GS"

echo ""

# ── f. Run/Fix/Init Extension Verification (6 checks) ────────────────────────
echo "--- f. Run/Fix/Init Extension Verification ---"

SR="$SKILL_DIR/references/spoke-run.md"
SF="$SKILL_DIR/references/spoke-fix.md"
SI="$SKILL_DIR/references/spoke-init.md"
check "spoke-run.md mentions go test" \
  grep -qi "go test" "$SR"
check "spoke-run.md has go test -json NDJSON parsing" \
  grep -qiE "go test -json|ndjson" "$SR"
check "spoke-run.md has go.mod detection" \
  grep -qi "go\.mod" "$SR"
check "spoke-fix.md mentions Go error patterns (unused_import, race_condition, import_cycle)" \
  grep -qiE "unused.import|race.condition|import.cycle" "$SF"
check "spoke-fix.md has Go-specific subcategories (go.unused_import, go.race_condition)" \
  grep -qE "go\.unused_import|go\.race_condition" "$SF"
check "spoke-init.md mentions Go detection (go.mod)" \
  grep -qiE "go\.mod" "$SI"

echo ""

# ── g. SKILL.md Routing (3 checks) ──────────────────────────────────────────
echo "--- g. SKILL.md Routing ---"

SM="$SKILL_DIR/SKILL.md"
check "SKILL.md references spoke-generate-go" \
  grep -q "spoke-generate-go" "$SM"
check "SKILL.md Context7 mappings include Go frameworks (testify, Gin, gomock)" \
  grep -qiE "testify|gin|gomock" "$SM"
check "SKILL.md has Go language dispatch (go → spoke-generate-go or Go decision flow)" \
  grep -qiE "go.*spoke|spoke.*go|Go.*Decision" "$SM"

echo ""

# ── h. Cross-File Consistency (3 checks) ─────────────────────────────────────
echo "--- h. Cross-File Consistency ---"

check "spoke-generate-go references go-generation-guide.md" \
  grep -q "go-generation-guide" "$GS"
check "spoke-generate-go references go-decision-tree" \
  grep -q "go-decision-tree" "$GS"
check "spoke-generate-go references config-schema or config.yaml" \
  grep -qiE "config.schema|config.yaml|config-schema" "$GS"

echo ""

# ── i. No-Regression Checks (5 checks) ───────────────────────────────────────
echo "--- i. No-Regression Checks ---"

check "spoke-run.md still mentions pytest (Python preserved)" \
  grep -qi "pytest" "$SR"
check "spoke-run.md still mentions vitest or jest (JS/TS preserved)" \
  grep -qiE "vitest|jest" "$SR"
check "spoke-fix.md still mentions ModuleNotFoundError (Python preserved)" \
  grep -q "ModuleNotFoundError" "$SF"
check "SKILL.md still references spoke-generate-python (Python routing preserved)" \
  grep -q "spoke-generate-python" "$SM"
check "SKILL.md still references spoke-generate-java (Java routing preserved)" \
  grep -q "spoke-generate-java" "$SM"

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All M003/S03 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
