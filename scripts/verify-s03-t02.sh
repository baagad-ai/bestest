#!/usr/bin/env bash
# verify-s03-t02.sh — Verify T02: metrics creation wired into spoke-init + pre-flight validation
set -uo pipefail

PASS=0; FAIL=0

check() {
  local desc="$1"
  local result
  result=$(eval "$2" 2>/dev/null) && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "✅ $desc"
    PASS=$((PASS+1))
  else
    echo "❌ $desc"
    FAIL=$((FAIL+1))
  fi
}

REF=".agents/skills/bestest/references"

# === spoke-init.md: directory structure ===
# 1. Directory structure lists metrics.json
check "spoke-init.md directory tree includes metrics.json in state/" \
  "grep -q 'metrics.json.*Continuous test health metrics' '$REF/spoke-init.md'"

# === spoke-init.md: Phase 4 creation instructions ===
# 2. Has metrics.json creation subsection (heading uses backticks in markdown)
check "spoke-init.md has .bestest/state/metrics.json template section" \
  "grep -q 'bestest/state/metrics.json' '$REF/spoke-init.md' && grep -q 'Create the initial metrics store' '$REF/spoke-init.md'"

# 3. References metrics-schema.md defaults
check "spoke-init.md metrics creation references metrics-schema.md defaults" \
  "grep -q 'references/metrics-schema.md' '$REF/spoke-init.md'"

# 4. Mentions Default Values (Initial State) section
check "spoke-init.md references Default Values section from metrics-schema" \
  "grep -q 'Default Values (Initial State)' '$REF/spoke-init.md'"

# 5. Documents key defaults (healthScore.overall = 0.0)
check "spoke-init.md documents healthScore.overall default 0.0" \
  "grep -q 'healthScore.overall.*0.0' '$REF/spoke-init.md'"

# 6. Documents safe-to-delete property
check "spoke-init.md documents metrics.json safe to delete" \
  "grep -q 'safe to delete' '$REF/spoke-init.md'"

# === spoke-init.md: Phase 6 File Existence Check ===
# 7. JS/TS file existence check includes metrics.json
check "spoke-init.md JS/TS file existence check includes metrics.json" \
  "awk '/JS.TS projects/{found=1} found && /stack-profile.json/{getline; if(/metrics.json/) exit 0; else exit 1}' '$REF/spoke-init.md'"

# 8. All 4 ecosystems have metrics.json in file existence checks
METRICS_IN_CHECKS=$(grep -c 'metrics.json.*valid JSON matching references/metrics-schema.md' "$REF/spoke-init.md" || true)
check "spoke-init.md has metrics.json in file existence checks for all 4 ecosystems (expected 4)" \
  "test '$METRICS_IN_CHECKS' -eq 4"

# 9. File existence check references metrics-schema.md
check "spoke-init.md file existence check references metrics-schema.md" \
  "grep -q 'references/metrics-schema.md' '$REF/spoke-init.md'"

# === spoke-init.md: Summary Output table ===
# 10. Created Files table includes metrics.json
check "spoke-init.md Created Files table includes metrics.json" \
  "grep -q 'metrics.json.*Continuous test health metrics' '$REF/spoke-init.md'"

# === spoke-init.md: Output tables ===
# 11. All 4 ecosystem output tables include metrics.json
METRICS_IN_OUTPUT=$(grep -c 'metrics.json.*bestest/state.*metrics' "$REF/spoke-init.md" || true)
# Check more broadly - each output table should reference metrics.json in .bestest/state/
METRICS_IN_OUTPUT2=$(grep -c '\`metrics.json\`.*\`.bestest/state/\`' "$REF/spoke-init.md" || true)
check "spoke-init.md Output tables include metrics.json for all ecosystems (expected 4)" \
  "test '$METRICS_IN_OUTPUT2' -ge 4"

# === pre-flight-protocol.md ===
# 12. Has metrics.json pre-read validation step
check "pre-flight-protocol.md has Step 4 metrics.json pre-read validation" \
  "grep -q 'Step 4.*metrics.json' '$REF/pre-flight-protocol.md'"

# 13. Graceful degradation rules present
check "pre-flight-protocol.md describes graceful degradation for metrics corruption" \
  "grep -q 'Do NOT abort the spoke' '$REF/pre-flight-protocol.md'"

# 14. References metrics-schema.md for full protocol
check "pre-flight-protocol.md references metrics-schema.md Graceful Degradation" \
  "grep -q 'references/metrics-schema.md' '$REF/pre-flight-protocol.md'"

# 15. Pattern Selection Guide updated
check "pre-flight-protocol.md Pattern Selection Guide mentions Step 4" \
  "grep -q 'Step 4 if reading metrics' '$REF/pre-flight-protocol.md'"

# === dot-bestest-schema.md consistency ===
# 16. dot-bestest-schema.md already has metrics.json (from T01)
check "dot-bestest-schema.md has metrics.json file reference" \
  "grep -q 'state/metrics.json' '$REF/dot-bestest-schema.md'"

# 17. dot-bestest-schema.md shows spoke-init creates metrics.json
check "dot-bestest-schema.md spoke-init creates metrics.json" \
  "grep -q 'spoke-init.*creates.*metrics.json' '$REF/dot-bestest-schema.md'"

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
