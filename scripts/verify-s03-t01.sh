#!/usr/bin/env bash
# verify-s03-t01.sh — Verify T01 deliverables: metrics-schema.md + cross-reference updates
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

# 1. metrics-schema.md exists
check "metrics-schema.md exists" "test -f '$REF/metrics-schema.md'"

# 2. Contains required top-level sections
for section in schemaVersion lastUpdated healthScore coverage tests flakiness runs modules slowest failures activity; do
  check "metrics-schema.md contains '$section' section" "grep -q '\"$section\"' '$REF/metrics-schema.md'"
done

# 3. Contains schemaVersion in version table (schema-contract.md)
check "schema-contract.md lists metrics.json in version table" \
  "grep -q 'metrics.json' '$REF/schema-contract.md'"

# 4. schema-contract.md has metrics-schema version history
check "schema-contract.md has metrics-schema version history" \
  "grep -q 'metrics-schema' '$REF/schema-contract.md'"

# 5. dot-bestest-schema.md references metrics.json in state/ tree
check "dot-bestest-schema.md shows metrics.json in state/ tree" \
  "grep -q 'metrics.json' '$REF/dot-bestest-schema.md'"

# 6. dot-bestest-schema.md has metrics.json file reference section
check "dot-bestest-schema.md has .bestest/state/metrics.json section" \
  "grep -q 'state/metrics.json' '$REF/dot-bestest-schema.md'"

# 7. dot-bestest-schema.md Spoke Creation Matrix includes metrics.json
check "dot-bestest-schema.md spoke-init creates metrics.json" \
  "grep -q 'spoke-init.*metrics.json' '$REF/dot-bestest-schema.md'"

# 8. config-schema.md has state.last_metrics field
check "config-schema.md has state.last_metrics field" \
  "grep -q 'state.last_metrics' '$REF/config-schema.md'"

# 9. All 6 example configs include last_metrics
EXAMPLE_COUNT=$(grep -c 'last_metrics:' "$REF/config-schema.md" || true)
check "config-schema.md has last_metrics in all examples (expected 6)" \
  "test '$EXAMPLE_COUNT' -eq 6"

# 10. metrics-schema.md references the update protocol
check "metrics-schema.md defines Update Protocol section" \
  "grep -q 'Update Protocol' '$REF/metrics-schema.md'"

# 11. metrics-schema.md defines Default Values
check "metrics-schema.md defines Default Values section" \
  "grep -q 'Default Values' '$REF/metrics-schema.md'"

# 12. metrics-schema.md defines Dashboard Consumption
check "metrics-schema.md defines Dashboard Consumption section" \
  "grep -q 'Dashboard Consumption' '$REF/metrics-schema.md'"

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
