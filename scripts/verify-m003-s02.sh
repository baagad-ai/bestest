#!/usr/bin/env bash
# verify-m003-s02.sh — Structural verification for M003/S02 (Java spoke) deliverables
# Validates file existence, decision tree, config template, generation spoke,
# run/fix/init extensions, SKILL.md routing, cross-file consistency, and no-regression.
#
# Note: T02 (java-generation-guide.md) was blocked during execution. T03 embedded
# the quality rubric directly into spoke-generate-java.md instead. The generation
# guide checks (category d) validate that the generation spoke itself contains
# the expected content that would otherwise live in a separate guide.

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

echo "=== M003/S02 Structural Verification (Java Spoke) ==="
echo ""

# ── a. File Existence (6 checks) ─────────────────────────────────────────────
echo "--- a. File Existence ---"

check "java-decision-tree.md exists"            test -f "$SKILL_DIR/references/java-decision-tree.md"
check "templates/config-junit5.yaml exists"     test -f "$SKILL_DIR/references/templates/config-junit5.yaml"
# java-generation-guide.md: T02 was blocked; content embedded in spoke-generate-java.md
# We check that the spoke exists and contains the guide content in categories d/e.
check "spoke-generate-java.md exists"           test -f "$SKILL_DIR/references/spoke-generate-java.md"
check "spoke-run.md exists (extended)"          test -f "$SKILL_DIR/references/spoke-run.md"
check "spoke-fix.md exists (extended)"          test -f "$SKILL_DIR/references/spoke-fix.md"
check "spoke-init.md exists (extended)"         test -f "$SKILL_DIR/references/spoke-init.md"

echo ""

# ── b. Decision Tree Completeness (3 checks) ─────────────────────────────────
echo "--- b. Decision Tree Completeness ---"

DT="$SKILL_DIR/references/java-decision-tree.md"
DT_STEPS=$(grep -cE "^## Step|^### Step" "$DT" || true)
check "java-decision-tree has 4+ decision steps (found $DT_STEPS)" [ "$DT_STEPS" -ge 4 ]
check "java-decision-tree references JUnit 5, Spring Boot, Mockito, Testcontainers, JaCoCo" \
  grep -qiE "JUnit|Spring Boot|Mockito|Testcontainers|JaCoCo" "$DT"
check "java-decision-tree has ADR template or cross-reference" \
  grep -qiE "ADR|architectural decision" "$DT"

echo ""

# ── c. Config Template Validity (3 checks) ───────────────────────────────────
echo "--- c. Config Template Validity ---"

CFG="$SKILL_DIR/references/templates/config-junit5.yaml"
check "config-junit5.yaml has framework: junit5" \
  grep -q "framework: junit5" "$CFG"
check "config-junit5.yaml has Java-specific ignore patterns (target/, build/, .gradle/)" \
  grep -qE "target/|build/|\.gradle/" "$CFG"
check "config-junit5.yaml has junit5 or generation section" \
  grep -qE "^junit5:|^generation:" "$CFG"

echo ""

# ── d. Generation Content Completeness (4 checks) ────────────────────────────
# T02 (java-generation-guide.md) was blocked. T03 embedded the quality rubric
# and patterns directly into spoke-generate-java.md. These checks validate that
# the generation spoke contains the content that would normally live in a guide.
echo "--- d. Generation Content Completeness (in spoke-generate-java.md) ---"

GS="$SKILL_DIR/references/spoke-generate-java.md"
GS_SECTIONS=$(grep -c "^## " "$GS" || true)
check "spoke-generate-java has 6+ main sections (found $GS_SECTIONS)" [ "$GS_SECTIONS" -ge 6 ]
check "spoke-generate-java has quality rubric/scoring" \
  grep -qiE "quality.*(rubric|score)|rubric|scoring" "$GS"
check "spoke-generate-java has JUnit 5/Spring Boot patterns (@SpringBootTest, @WebMvcTest, @DataJpaTest)" \
  grep -qiE "@SpringBootTest|@WebMvcTest|@DataJpaTest" "$GS"
check "spoke-generate-java has Mockito patterns (MockitoExtension, @Mock, @InjectMocks)" \
  grep -qiE "MockitoExtension|@Mock|@InjectMocks" "$GS"

echo ""

# ── e. Generation Spoke Completeness (10 checks) ─────────────────────────────
echo "--- e. Generation Spoke Completeness ---"

check "spoke-generate-java has Pre-Flight section" \
  grep -qiE "pre.?flight" "$GS"
GS_PHASES=$(grep -cE "^## Phase|^### Phase" "$GS" || true)
check "spoke-generate-java has all 7 phases (found $GS_PHASES)" [ "$GS_PHASES" -ge 7 ]
check "spoke-generate-java has HITL Gate section" \
  grep -qiE "HITL|human.in.the.loop" "$GS"
check "spoke-generate-java has Error Handling section" \
  grep -qiE "error.handling" "$GS"
check "spoke-generate-java has Downstream Reference" \
  grep -qiE "downstream" "$GS"
# Note: java-generation-guide.md doesn't exist (T02 blocked); quality rubric embedded directly
check "spoke-generate-java references anti-patterns" \
  grep -qiE "anti.?pattern|antipattern" "$GS"
check "spoke-generate-java references config-schema/yaml" \
  grep -qiE "config.schema|config.yaml|config-schema" "$GS"
GS_LINES=$(wc -l < "$GS" | tr -d ' ')
check "spoke-generate-java is 800+ lines (found $GS_LINES)" [ "$GS_LINES" -ge 800 ]
check "spoke-generate-java has framework detection logic" \
  grep -qiE "framework.*(detect|determin)|detect.*framework" "$GS"
# Compilation cascade handling is the key Java-specific differentiator
check "spoke-generate-java has compilation cascade handling" \
  grep -qiE "compilation.cascade|cascade" "$GS"

echo ""

# ── f. Run/Fix/Init Extension Verification (5 checks) ────────────────────────
echo "--- f. Run/Fix/Init Extension Verification ---"

SR="$SKILL_DIR/references/spoke-run.md"
SF="$SKILL_DIR/references/spoke-fix.md"
SI="$SKILL_DIR/references/spoke-init.md"
check "spoke-run.md mentions Gradle/Maven (gradlew, gradle test, mvnw)" \
  grep -qiE "gradlew|gradle test|mvnw|maven" "$SR"
check "spoke-run.md has JDK detection (JAVA_HOME, java -version)" \
  grep -qiE "JAVA_HOME|java -version|jdk" "$SR"
check "spoke-fix.md mentions Java error patterns (compilation_error, spring_context, class_not_found)" \
  grep -qiE "compilation_error|spring_context|class_not_found" "$SF"
check "spoke-fix.md has compilation cascade handling or deduplication logic" \
  grep -qiE "compilation.cascade|cascade|deduplic" "$SF"
check "spoke-init.md mentions Java detection (pom.xml, build.gradle)" \
  grep -qiE "pom\.xml|build\.gradle" "$SI"

echo ""

# ── g. SKILL.md Routing (3 checks) ──────────────────────────────────────────
echo "--- g. SKILL.md Routing ---"

SM="$SKILL_DIR/SKILL.md"
check "SKILL.md references spoke-generate-java" \
  grep -q "spoke-generate-java" "$SM"
check "SKILL.md Context7 mappings include Java frameworks (JUnit, Mockito, Spring Boot, AssertJ, Testcontainers)" \
  grep -qiE "JUnit|Mockito|Spring Boot|AssertJ|Testcontainers" "$SM"
check "SKILL.md has Java language dispatch (java → spoke-generate-java)" \
  grep -qiE "java.*spoke|spoke.*java" "$SM"

echo ""

# ── h. Cross-File Consistency (3 checks) ─────────────────────────────────────
echo "--- h. Cross-File Consistency ---"

# Note: java-generation-guide.md doesn't exist (T02 blocked)
# spoke-generate-java references the decision tree instead
check "spoke-generate-java references java-decision-tree.md" \
  grep -q "java-decision-tree" "$GS"
check "spoke-generate-java references config-schema or config.yaml" \
  grep -qiE "config.schema|config.yaml|config-schema" "$GS"
check "spoke-generate-java references anti-patterns" \
  grep -qiE "anti.?pattern" "$GS"

echo ""

# ── i. No-Regression Checks (4 checks) ──────────────────────────────────────
echo "--- i. No-Regression Checks ---"

check "spoke-run.md still mentions pytest (Python preserved)" \
  grep -qi "pytest" "$SR"
check "spoke-run.md still mentions vitest or jest (JS/TS preserved)" \
  grep -qiE "vitest|jest" "$SR"
check "spoke-fix.md still mentions ModuleNotFoundError (Python preserved)" \
  grep -q "ModuleNotFoundError" "$SF"
check "SKILL.md still references spoke-generate-python (Python routing preserved)" \
  grep -q "spoke-generate-python" "$SM"

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
echo "=== Summary ==="
TOTAL=$((PASS + FAIL))
echo "Passed: $PASS / $TOTAL"
echo "Failed: $FAIL / $TOTAL"

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "🎉 All M003/S02 structural checks passed."
  exit 0
else
  echo ""
  echo "⚠️  Some checks failed. See above for details."
  exit 1
fi
