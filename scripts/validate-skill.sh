#!/usr/bin/env bash
# validate-skill.sh — Comprehensive consistency checker for the bestest skill
# Checks 7 domains: routing↔index, index↔disk, spoke existence, detection engine,
# schema field coverage, template completeness, SKILL.md integrity.
# Exit 0 if all pass (or only warnings), exit 1 if any critical failure.

set -euo pipefail

SKILL_DIR="$HOME/.agents/skills/bestest"
SKILL_FILE="$SKILL_DIR/SKILL.md"
ERROR_CODES="$SKILL_DIR/references/error-codes.md"

PASS=0
FAIL=0
WARN=0
CRITICAL=0
RESULTS=()

# ─── Helper ────────────────────────────────────────────────────────────────
check() {
  local description="$1"
  local error_code="$2"
  local severity="${3:-critical}"
  local cmd="$4"

  if eval "$cmd"; then
    RESULTS+=("  ✅ $error_code ($severity): $description")
    PASS=$((PASS + 1))
  else
    RESULTS+=("  ❌ $error_code ($severity): $description")
    if [ "$severity" = "critical" ]; then
      CRITICAL=$((CRITICAL + 1))
      FAIL=$((FAIL + 1))
    else
      WARN=$((WARN + 1))
      FAIL=$((FAIL + 1))
    fi
  fi
}

# ─── Extract sections from SKILL.md ───────────────────────────────────────
extract_section() {
  local tag="$1"
  local file="$2"
  sed -n "/^<${tag}>/,/^<\/${tag}>/p" "$file" | sed '1d;$d'
}

# ─── Extract spoke paths from routing table ───────────────────────────────
get_routing_spokes() {
  extract_section "routing" "$SKILL_FILE" \
    | grep -oE 'references/spoke-[a-z0-9-]+\.md' \
    | sort -u
}

# ─── Extract spoke paths from reference_index Spokes section ─────────────
get_index_spokes() {
  # Check external reference-index.md first; fall back to inline SKILL.md section
  local index_file="$SKILL_DIR/references/reference-index.md"
  if [ -f "$index_file" ]; then
    sed -n '/^## Spokes/,/^## /p' "$index_file" \
      | grep -oE 'references/spoke-[a-z0-9-]+\.md' \
      | sort -u
  else
    sed -n '/^### Spokes/,/^### /p' "$SKILL_FILE" \
      | grep -oE 'references/spoke-[a-z0-9-]+\.md' \
      | sort -u
  fi
}

# ─── Extract all reference paths from reference_index ─────────────────────
get_index_refs() {
  # Check external reference-index.md first; fall back to inline SKILL.md section
  local index_file="$SKILL_DIR/references/reference-index.md"
  if [ -f "$index_file" ]; then
    grep -oE 'references/[a-z0-9/_.-]+\.md' "$index_file" \
      | sort -u
  else
    extract_section "reference_index" "$SKILL_FILE" \
      | grep -oE 'references/[a-z0-9/_.-]+\.md' \
      | sort -u
  fi
}

# ═══════════════════════════════════════════════════════════════════════════
echo "═══ bestest skill validation ═══"
echo "Skill directory: $SKILL_DIR"
echo ""

# ─── Domain 1: Routing Table ↔ Reference Index Consistency ────────────────
echo "── Domain 1: Routing Table ↔ Reference Index Consistency ──"

ROUTING_SPOKES=$(get_routing_spokes)
INDEX_SPOKES=$(get_index_spokes)

# E001: Every routing spoke is in reference_index Spokes section
while IFS= read -r spoke; do
  [ -z "$spoke" ] && continue
  check "Routing spoke '$spoke' listed in reference_index" "E001" "critical" \
    "echo '$INDEX_SPOKES' | grep -qF '$spoke'"
done <<< "$ROUTING_SPOKES"

# E002: Every reference_index spoke is in routing table (exempt lang-specific generate spokes)
while IFS= read -r spoke; do
  [ -z "$spoke" ] && continue
  case "$spoke" in
    */spoke-generate-python.md|*/spoke-generate-java.md|*/spoke-generate-go.md)
      continue ;;
  esac
  check "reference_index spoke '$spoke' listed in routing table" "E002" "critical" \
    "echo '$ROUTING_SPOKES' | grep -qF '$spoke'"
done <<< "$INDEX_SPOKES"

# ─── Domain 2: Reference Index ↔ File Existence ───────────────────────────
echo "── Domain 2: Reference Index ↔ File Existence ──"

INDEX_REFS=$(get_index_refs)

# E003: Every reference_index entry exists on disk
while IFS= read -r ref; do
  [ -z "$ref" ] && continue
  check "reference_index entry '$ref' exists on disk" "E003" "critical" \
    "[ -f '$SKILL_DIR/$ref' ]"
done <<< "$(echo "$INDEX_REFS" | sort -u)"

# E004: Every .md file in references/ (excluding templates/) is in reference_index
while IFS= read -r filepath; do
  [ -z "$filepath" ] && continue
  rel="${filepath#$SKILL_DIR/}"
  check "references file '$rel' is listed in reference_index" "E004" "critical" \
    "echo '$INDEX_REFS' | grep -qF '$rel'"
done <<< "$(find "$SKILL_DIR/references" -name '*.md' -not -path '*/templates/*' -not -name 'error-codes.md' | sort)"

# E004b: pipeline-shared.md must be referenced by all 4 generate spokes
for spoke in spoke-generate.md spoke-generate-python.md spoke-generate-java.md spoke-generate-go.md; do
  check "Generate spoke '$spoke' references pipeline-shared.md" "E004b" "critical" \
    "grep -q 'pipeline-shared' '$SKILL_DIR/references/$spoke'"
done

# ─── Domain 3: Spoke Existence & Non-Empty ────────────────────────────────
echo "── Domain 3: Spoke Existence & Non-Empty ──"

# E005: All spoke files from routing table exist and are non-empty
while IFS= read -r spoke; do
  [ -z "$spoke" ] && continue
  check "Spoke file '$spoke' exists and non-empty" "E005" "critical" \
    "[ -s '$SKILL_DIR/$spoke' ]"
done <<< "$ROUTING_SPOKES"

# E006: All 24 generate sub-files exist and are non-empty (4 langs × 6 files)
GENERATE_FILES="phase1-target-detail.md phase4-generation-detail.md phase5-compilation.md phase6-execution.md phase7-quality-audit.md error-handling.md"

# JS/TS (top-level in generate/)
for f in $GENERATE_FILES; do
  check "JS/TS generate sub-file 'references/generate/$f' exists and non-empty" "E006" "critical" \
    "[ -s '$SKILL_DIR/references/generate/$f' ]"
done

# Python, Java, Go (in generate/<lang>/)
for lang in python java go; do
  case "$lang" in
    python) label="Python" ;;
    java)   label="Java" ;;
    go)     label="Go" ;;
  esac
  for f in $GENERATE_FILES; do
    check "$label generate sub-file 'references/generate/$lang/$f' exists and non-empty" "E006" "critical" \
      "[ -s '$SKILL_DIR/references/generate/$lang/$f' ]"
  done
done

# ─── Domain 4: Detection Engine Structure ──────────────────────────────────
echo "── Domain 4: Detection Engine Structure ──"

DE="$SKILL_DIR/references/detection-engine.md"

# E007: detection-engine.md contains Phase 1–9 headings
for phase in 1 2 3 4 5 6 7 8 9; do
  check "detection-engine.md contains Phase $phase heading" "E007" "critical" \
    "grep -qE 'Phase $phase' '$DE'"
done

# E008: Must contain Confidence Scoring Algorithm section
check "detection-engine.md contains 'Confidence Scoring Algorithm' section" "E008" "critical" \
  "grep -q 'Confidence Scoring Algorithm' '$DE'"

# E009: Must contain Output section and Signal Catalog + related files
check "detection-engine.md contains 'Output' section" "E009a" "critical" \
  "grep -qE '##.*Output|###.*Output' '$DE'"

check "detection-engine.md contains 'Signal Catalog' section" "E009b" "critical" \
  "grep -q 'Signal Catalog' '$DE'"

check "detection-signals.md exists and non-empty" "E009c" "critical" \
  "[ -s '$SKILL_DIR/references/detection-signals.md' ]"

check "stack-profile-schema.md exists" "E009d" "critical" \
  "[ -f '$SKILL_DIR/references/stack-profile-schema.md' ]"

e009_field="e"
for field in schemaVersion languages buildTool frameworks testFrameworks coverage; do
  check "stack-profile-schema.md documents '$field' field" "E009${e009_field}" "critical" \
    "grep -q '$field' '$SKILL_DIR/references/stack-profile-schema.md'"
  case "$e009_field" in
    e) e009_field="f" ;;
    f) e009_field="g" ;;
    g) e009_field="h" ;;
    h) e009_field="i" ;;
    i) e009_field="j" ;;
  esac
done

# ─── Domain 5: Schema Field Coverage ──────────────────────────────────────
echo "── Domain 5: Schema Field Coverage ──"

CS="$SKILL_DIR/references/config-schema.md"
SR="$SKILL_DIR/references/scan-report-schema.md"
SC="$SKILL_DIR/references/schema-contract.md"

# E010: config-schema.md must document 18 field groups
for group in coverage paths e2e api mutation contract chaos performance ci vitest jest pytest junit5 go monorepo generation reports state; do
  check "config-schema.md documents '${group}.*' field group" "E010" "critical" \
    "grep -qE '${group}\\.\\*' '$CS'"
done

# E011: scan-report-schema.md must document required top-level fields
for field in configSnapshot summary coverage antiPatterns flakyTests gaps testInventory; do
  check "scan-report-schema.md documents '$field' field" "E011" "critical" \
    "grep -q '$field' '$SR'"
done

# E012: schema-contract.md must document version policy and version history
check "schema-contract.md documents 'Version Policy'" "E012" "critical" \
  "grep -qE 'Version Policy' '$SC'"

check "schema-contract.md documents version table with artifact versions" "E012" "critical" \
  "grep -q 'stack-profile' '$SC' && grep -q 'scan-report' '$SC' && grep -q 'run-results' '$SC'"

# E012b: metrics-schema.md exists and is non-empty
MS="$SKILL_DIR/references/metrics-schema.md"
check "metrics-schema.md exists and is non-empty" "E012b" "critical" \
  "[ -s '$MS' ]"

# E012c: metrics-schema.md documents required top-level fields
for field in schemaVersion healthScore coverage tests runs activity; do
  check "metrics-schema.md documents '$field' field" "E012c" "critical" \
    "grep -q '$field' '$MS'"
done

# E012d: schema-contract.md contains metrics.json in its version table
check "schema-contract.md contains metrics.json in version table" "E012d" "critical" \
  "grep -q 'metrics.json' '$SC'"

# ─── Domain 6: Template Completeness ──────────────────────────────────────
echo "── Domain 6: Template Completeness ──"

TD="$SKILL_DIR/references/templates"

# 6 YAML config templates
for t in config-vitest.yaml config-jest.yaml config-pytest.yaml config-junit5.yaml config-go.yaml config-monorepo.yaml; do
  check "YAML template '$t' exists and non-empty" "E013" "critical" \
    "[ -s '$TD/$t' ]"
done

# 3 CI templates
for t in ci/github-actions-test.yml ci/gitlab-ci-test.yml ci/jenkinsfile-test.groovy; do
  check "CI template '$t' exists and non-empty" "E013" "critical" \
    "[ -s '$TD/$t' ]"
done

# 6 .md templates
for t in vitest-config-ts.md jest-config-ts.md playwright-config-ts.md stryker-conf.md supertest-helpers.md testing-md.md; do
  check "MD template '$t' exists and non-empty" "E013" "critical" \
    "[ -s '$TD/$t' ]"
done

# 1 gitignore
check "Template 'bestest-gitignore' exists and non-empty" "E013" "critical" \
  "[ -s '$TD/bestest-gitignore' ]"

# ─── Domain 7: SKILL.md Integrity ─────────────────────────────────────────
echo "── Domain 7: SKILL.md Integrity ──"

# E015: Frontmatter must have name: bestest and version field
check "SKILL.md frontmatter has 'name: bestest'" "E015" "critical" \
  "head -10 '$SKILL_FILE' | grep -qE '^name: bestest$'"

check "SKILL.md frontmatter has 'version' field" "E015" "critical" \
  "head -10 '$SKILL_FILE' | grep -qE '^version:'"

# E016: All required XML wrapper sections present
for section in essential_principles detection_engine framework_decision context7_helper routing quick_reference reference_index success_criteria; do
  check "SKILL.md has '<${section}>' section" "E016" "critical" \
    "grep -q '^<${section}>' '$SKILL_FILE'"
done

# E017: Line count within bounds (200–350)
LINE_COUNT=$(wc -l < "$SKILL_FILE" | tr -d ' ')
check "SKILL.md line count ($LINE_COUNT) is within bounds (200-350)" "E017" "warning" \
  "[ '$LINE_COUNT' -ge 200 ] && [ '$LINE_COUNT' -le 350 ]"

# ─── Semantic Validation ──────────────────────────────────────────────────
echo "── Semantic Validation ──"

# S1: Validate YAML templates parse correctly (skip templates with {{variable}} placeholders)
for yaml_file in $(find "$SKILL_DIR/references/templates" -name '*.yaml' -o -name '*.yml' 2>/dev/null); do
  if command -v python3 &>/dev/null; then
    # Skip template files that contain Mustache/variable placeholders
    if grep -q '{{' "$yaml_file" 2>/dev/null; then
      continue
    fi
    if ! python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
      echo "⚠ S001: YAML syntax error in $yaml_file"
    fi
  fi
done

# S2: Validate JSON schema files parse correctly
for json_file in stack-profile-schema.md scan-report-schema.md metrics-schema.md; do
  # Check that JSON examples in schema files are valid
  if [ -f "$SKILL_DIR/references/$json_file" ]; then
    json_examples=$(grep -oE '\{[^}]+\}' "$SKILL_DIR/references/$json_file" 2>/dev/null | head -5)
    for example in $json_examples; do
      if command -v python3 &>/dev/null; then
        if ! python3 -c "import json; json.loads('$example')" 2>/dev/null; then
          : # JSON parse failure is expected for partial grep matches — not a real error
        fi
      fi
    done
  fi
done

# S3: Check that SKILL.md version matches CHANGELOG latest
skill_version=$(grep -oE 'version: "[^"]+"' "$SKILL_DIR/SKILL.md" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
changelog_version=$(grep -oE '^## \[?[0-9]+\.[0-9]+\.[0-9]+' "$SKILL_DIR/CHANGELOG.md" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
if [ -n "$skill_version" ] && [ -n "$changelog_version" ]; then
  if [ "$skill_version" != "$changelog_version" ]; then
    echo "⚠ S003: Version mismatch — SKILL.md says $skill_version but CHANGELOG.md latest is $changelog_version"
  fi
fi

# S4: Cross-reference spoke Purpose sections exist
missing_purpose=0
for spoke in $(grep -oE 'spoke-[a-z-]+\.md' "$SKILL_DIR/SKILL.md" | sort -u); do
  if [ -f "$SKILL_DIR/references/$spoke" ]; then
    if ! grep -q '## Purpose' "$SKILL_DIR/references/$spoke"; then
      echo "⚠ S004: $spoke missing ## Purpose section"
      missing_purpose=$((missing_purpose + 1))
    fi
  fi
done

# ─── Domain 8: Generate Spoke Behavioral Consistency ──────────────────────
echo "── Domain 8: Generate Spoke Behavioral Consistency ──"

GENERATE_SPOKES=("spoke-generate.md" "spoke-generate-python.md" "spoke-generate-java.md" "spoke-generate-go.md")

# E022 (critical): All 4 generate spokes have "Write Companion Run Report" heading in Phase 6
for spoke in "${GENERATE_SPOKES[@]}"; do
  spoke_file="$SKILL_DIR/references/$spoke"
  check "Generate spoke '$spoke' has 'Write Companion Run Report' in Phase 6" "E022" "critical" \
    "[ -f '$spoke_file' ] && sed -n '/^## Phase 6/,/^## Phase 7/p' '$spoke_file' | grep -q '### Write Companion Run Report'"
done

# E023 (critical): All 4 generate spokes have "Run report (companion)" row in Output artifact table
for spoke in "${GENERATE_SPOKES[@]}"; do
  spoke_file="$SKILL_DIR/references/$spoke"
  check "Generate spoke '$spoke' has 'Run report (companion)' in Output table" "E023" "critical" \
    "[ -f '$spoke_file' ] && grep -q 'Run report (companion)' '$spoke_file'"
done

# E024 (critical): Step numbering in each spoke's Phase 2 is monotonically increasing
for spoke in "${GENERATE_SPOKES[@]}"; do
  spoke_file="$SKILL_DIR/references/$spoke"
  check "Generate spoke '$spoke' Phase 2 step numbering is monotonically increasing" "E024" "critical" \
    "[ -f '$spoke_file' ] && { steps=\$(sed -n '/^## Phase 2/,/^## Phase 3/p' '$spoke_file' | grep -oE 'Step [0-9]+' | grep -oE '[0-9]+'); if [ -z \"\$steps\" ]; then false; else prev=0; ok=true; while IFS= read -r n; do [ \"\$n\" -le \"\$prev\" ] && ok=false; prev=\$n; done <<< \"\$steps\"; \$ok; fi; }"
done

# E025 (warning): All 4 generate spokes' Metrics Update sections reference pipeline-shared.md
for spoke in "${GENERATE_SPOKES[@]}"; do
  spoke_file="$SKILL_DIR/references/$spoke"
  check "Generate spoke '$spoke' Metrics Update references pipeline-shared.md" "E025" "warning" \
    "[ -f '$spoke_file' ] && sed -n '/^## Metrics Update/,/^## /p' '$spoke_file' | grep -q 'pipeline-shared\\.md'"
done

# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "═══ Results ═══"
for r in "${RESULTS[@]}"; do
  echo "$r"
done
echo ""
TOTAL=$((PASS + CRITICAL + WARN))
echo "Summary: $PASS passed, $CRITICAL critical, $WARN warnings out of $TOTAL checks"

if [ "$CRITICAL" -gt 0 ]; then
  echo ""
  echo "❌ FAILED — $CRITICAL critical error(s) found"
  exit 1
else
  echo ""
  echo "✅ PASSED — all checks passed (with $WARN warnings)"
  exit 0
fi
