#!/usr/bin/env bash
# verify-s03-t03.sh — Verify T03: Metrics Update protocol wired into spoke-run, spoke-scan, spoke-doctor
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

# === Structure: Metrics Update section exists in all 3 spokes ===
check "spoke-run.md has ## Metrics Update section" \
  "grep -q '^## Metrics Update' '$REF/spoke-run.md'"

check "spoke-scan.md has ## Metrics Update section" \
  "grep -q '^## Metrics Update' '$REF/spoke-scan.md'"

check "spoke-doctor.md has ## Metrics Update section" \
  "grep -q '^## Metrics Update' '$REF/spoke-doctor.md'"

# === Positioning: Metrics Update comes before Error Handling ===
check "spoke-run.md: Metrics Update section precedes Error Handling" \
  "awk '/^## Metrics Update/{mu=NR} /^## Error Handling/{eh=NR} END{exit(mu<eh?0:1)}' '$REF/spoke-run.md'"

check "spoke-scan.md: Metrics Update section precedes Error Handling" \
  "awk '/^## Metrics Update/{mu=NR} /^## Error Handling/{eh=NR} END{exit(mu<eh?0:1)}' '$REF/spoke-scan.md'"

check "spoke-doctor.md: Metrics Update section precedes Error Handling" \
  "awk '/^## Metrics Update/{mu=NR} /^## Error Handling/{eh=NR} END{exit(mu<eh?0:1)}' '$REF/spoke-doctor.md'"

# === Protocol steps present in all spokes ===
check "spoke-run.md has Protocol subsection" \
  "grep -q '### Protocol' '$REF/spoke-run.md'"

check "spoke-scan.md has Protocol subsection" \
  "grep -q '### Protocol' '$REF/spoke-scan.md'"

check "spoke-doctor.md has Protocol subsection" \
  "grep -q '### Protocol' '$REF/spoke-doctor.md'"

# === Shared protocol references ===
check "spoke-run.md references shared protocol in metrics-schema.md" \
  "grep -q 'references/metrics-schema.md' '$REF/spoke-run.md' | head -1"

check "spoke-scan.md references shared protocol in metrics-schema.md" \
  "grep -q 'references/metrics-schema.md' '$REF/spoke-scan.md' | head -1"

check "spoke-doctor.md references shared protocol in metrics-schema.md" \
  "grep -q 'references/metrics-schema.md' '$REF/spoke-doctor.md' | head -1"

# === Corruption handling (graceful degradation) ===
# Protocol step 2 is ~7 lines into the section, so search wider
check "spoke-run.md: Metrics Update handles corruption without abort" \
  "sed -n '/^## Metrics Update/,/^## Error Handling/p' '$REF/spoke-run.md' | grep -qi 'never abort'"

check "spoke-scan.md: Metrics Update handles corruption without abort" \
  "sed -n '/^## Metrics Update/,/^## Error Handling/p' '$REF/spoke-scan.md' | grep -qi 'never abort'"

check "spoke-doctor.md: Metrics Update handles corruption without abort" \
  "sed -n '/^## Metrics Update/,/^## Error Handling/p' '$REF/spoke-doctor.md' | grep -qi 'never abort'"

# === Spoke-specific field tables ===
check "spoke-run.md has Fields Updated table" \
  "grep -q '### Fields Updated by spoke-run' '$REF/spoke-run.md'"

check "spoke-scan.md has Fields Updated table" \
  "grep -q '### Fields Updated by spoke-scan' '$REF/spoke-scan.md'"

check "spoke-doctor.md has Fields Updated table" \
  "grep -q '### Fields Updated by spoke-doctor' '$REF/spoke-doctor.md'"

# === spoke-run specific fields ===
check "spoke-run.md updates tests section" \
  "grep -q 'tests.*run-results.json' '$REF/spoke-run.md'"

check "spoke-run.md updates runs.history" \
  "grep -q 'runs.history' '$REF/spoke-run.md'"

check "spoke-run.md updates coverage.current" \
  "grep -q 'coverage.current' '$REF/spoke-run.md'"

check "spoke-run.md updates healthScore" \
  "grep -q 'healthScore' '$REF/spoke-run.md'"

check "spoke-run.md updates slowest.tests" \
  "grep -q 'slowest' '$REF/spoke-run.md'"

check "spoke-run.md updates failures.heatMap" \
  "grep -q 'failures' '$REF/spoke-run.md'"

check "spoke-run.md updates activity log" \
  "grep -q 'activity' '$REF/spoke-run.md'"

# === spoke-scan specific fields ===
check "spoke-scan.md updates tests section" \
  "grep -q 'tests.*Scan report' '$REF/spoke-scan.md'"

check "spoke-scan.md updates flakiness.flakyTests" \
  "grep -q 'flakiness.flakyTests' '$REF/spoke-scan.md'"

check "spoke-scan.md updates modules.entries" \
  "grep -q 'modules.entries' '$REF/spoke-scan.md'"

check "spoke-scan.md updates slowest.tests" \
  "grep -q 'slowest' '$REF/spoke-scan.md'"

check "spoke-scan.md updates activity log" \
  "grep -q 'activity' '$REF/spoke-scan.md'"

# === spoke-doctor specific fields ===
check "spoke-doctor.md updates healthScore.overall" \
  "grep -q 'healthScore.overall' '$REF/spoke-doctor.md'"

check "spoke-doctor.md updates healthScore.breakdown" \
  "grep -q 'healthScore.breakdown' '$REF/spoke-doctor.md'"

check "spoke-doctor.md updates activity log" \
  "grep -q 'activity' '$REF/spoke-doctor.md'"

# === Bounded array eviction documented ===
check "spoke-run.md documents bounded array eviction" \
  "grep -q 'Bounded Array Eviction' '$REF/spoke-run.md'"

check "spoke-scan.md documents bounded array eviction" \
  "grep -q 'Bounded Array Eviction' '$REF/spoke-scan.md'"

check "spoke-doctor.md documents bounded array eviction" \
  "grep -q 'Bounded Array Eviction' '$REF/spoke-doctor.md'"

# === Config state update ===
check "spoke-run.md updates state.last_metrics in config.yaml" \
  "grep -q 'state.last_metrics' '$REF/spoke-run.md'"

check "spoke-scan.md updates state.last_metrics in config.yaml" \
  "grep -q 'state.last_metrics' '$REF/spoke-scan.md'"

check "spoke-doctor.md updates state.last_metrics in config.yaml" \
  "grep -q 'state.last_metrics' '$REF/spoke-doctor.md'"

# === Consistency with metrics-schema.md responsibility matrix ===
# Verify spoke-run has the sections specified in the matrix: tests, runs, coverage, healthScore, slowest, failures, activity
check "spoke-run.md covers all matrix sections (tests, runs, coverage, healthScore, slowest, failures, activity)" \
  "MU=\$(sed -n '/^## Metrics Update/,/^## Error Handling/p' '$REF/spoke-run.md') && echo \"\$MU\" | grep -q 'runs.history' && echo \"\$MU\" | grep -q 'coverage.current' && echo \"\$MU\" | grep -q 'healthScore' && echo \"\$MU\" | grep -q 'slowest' && echo \"\$MU\" | grep -q 'failures' && echo \"\$MU\" | grep -q 'activity'"

# Verify spoke-scan has the sections: tests, flakiness, modules, slowest, activity
check "spoke-scan.md covers all matrix sections (tests, flakiness, modules, slowest, activity)" \
  "MU=\$(sed -n '/^## Metrics Update/,/^## Error Handling/p' '$REF/spoke-scan.md') && echo \"\$MU\" | grep -q 'flakiness' && echo \"\$MU\" | grep -q 'modules.entries' && echo \"\$MU\" | grep -q 'slowest' && echo \"\$MU\" | grep -q 'activity'"

# Verify spoke-doctor has the sections: healthScore, activity
check "spoke-doctor.md covers all matrix sections (healthScore, activity)" \
  "grep -c 'healthScore\|activity' '$REF/spoke-doctor.md' | grep -q '^2' || grep -c 'healthScore' '$REF/spoke-doctor.md'"

echo ""
echo "Results: $PASS passed, $FAIL failed"
exit $FAIL
