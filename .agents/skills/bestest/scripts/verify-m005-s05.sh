#!/usr/bin/env bash
# verify-m005-s05.sh — Validate the complete decomposition of all 4 generate spokes
# Part of M005/S05: Decompose generate spokes into hub + sub-files
set -euo pipefail

PASS=0
FAIL=0
ERRORS=""

pass() { PASS=$((PASS + 1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  ❌ $1"; ERRORS="${ERRORS}\n  - $1"; }

cd "$(dirname "$0")/.."

echo "========================================="
echo " M005/S05 Decomposition Verification"
echo "========================================="
echo ""

# --- Check 1: Hub line counts ≤420 ---
echo "Check 1: Hub line counts (target ≤400, ceiling ≤420)"
for hub in references/spoke-generate.md references/spoke-generate-python.md references/spoke-generate-java.md references/spoke-generate-go.md; do
  lines=$(wc -l < "$hub" | tr -d ' ')
  if [ "$lines" -le 420 ]; then
    pass "$hub: $lines lines"
  else
    fail "$hub has $lines lines (max 420)"
  fi
done
echo ""

# --- Check 2: Sub-file existence (24 total) ---
echo "Check 2: Sub-file existence (24 files)"
missing=0
for lang in '' 'python/' 'java/' 'go/'; do
  for phase in phase1-target-detail phase4-generation-detail phase5-compilation phase6-execution phase7-quality-audit error-handling; do
    path="references/generate/${lang}${phase}.md"
    if [ -s "$path" ]; then
      pass "$path exists"
    else
      fail "Missing or empty: $path"
      missing=$((missing + 1))
    fi
  done
done
if [ "$missing" -gt 0 ]; then
  fail "$missing sub-files missing or empty"
fi
echo ""

# --- Check 3: Defense markers survive ---
echo "Check 3: Defense markers (L1/L2/L3) in all hubs"
for hub in references/spoke-generate*.md; do
  basename=$(basename "$hub")
  l1_ok=true; l2_ok=true; l3_ok=true

  if grep -q "BEGIN_UNTRUSTED_SOURCE" "$hub"; then
    pass "$basename: L1 (BEGIN_UNTRUSTED_SOURCE) present"
  else
    fail "$basename: missing L1 (BEGIN_UNTRUSTED_SOURCE)"
    l1_ok=false
  fi

  if grep -q "Taint notice" "$hub"; then
    pass "$basename: L2 (Taint notice) present"
  else
    fail "$basename: missing L2 (Taint notice)"
    l2_ok=false
  fi

  if grep -q "Pre-read instruction" "$hub"; then
    pass "$basename: L3 (Pre-read instruction) present"
  else
    fail "$basename: missing L3 (Pre-read instruction)"
    l3_ok=false
  fi
done
echo ""

# --- Check 4: L2 ordering — Taint notice before Context7 fetch step ---
echo "Check 4: L2 ordering (taint notice before Context7 fetch step)"
for hub in references/spoke-generate*.md; do
  basename=$(basename "$hub")
  # The taint notice line itself contains "Context7" so we look for the
  # actual Step heading that uses Context7 (e.g., "### Step 3: Fetch ... Context7")
  # or any heading containing Context7 that is NOT the taint line itself.
  taint_line=$(grep -n "Taint notice" "$hub" | head -1 | cut -d: -f1)
  # Find first line with "Context7" that is NOT the taint notice line itself
  context7_line=$(grep -n "Context7" "$hub" | grep -v "^${taint_line}:" | head -1 | cut -d: -f1)

  if [ -z "$context7_line" ]; then
    # Fallback: no separate Context7 line found beyond taint — this is fine
    # (taint notice mentions Context7, no separate Context7 reference)
    pass "$basename: no separate Context7 reference beyond taint line (OK)"
  elif [ "$taint_line" -lt "$context7_line" ]; then
    pass "$basename: taint@$taint_line < context7@$context7_line"
  else
    fail "$basename: L2 ordering wrong — taint=$taint_line, context7=$context7_line"
  fi
done
echo ""

# --- Check 5: Loading instructions present ---
echo "Check 5: On-demand load instructions (≥4 per hub)"
for hub in references/spoke-generate*.md; do
  basename=$(basename "$hub")
  count=$(grep -c "On-demand load" "$hub" || true)
  if [ "$count" -ge 4 ]; then
    pass "$basename: $count loading instructions"
  else
    fail "$basename has only $count loading instructions (need ≥4)"
  fi
done
echo ""

# --- Check 6: SKILL.md routing unchanged ---
echo "Check 6: SKILL.md routing for all 4 generate spokes"
for spoke in spoke-generate.md spoke-generate-python.md spoke-generate-java.md spoke-generate-go.md; do
  if grep -q "$spoke" SKILL.md; then
    pass "SKILL.md references $spoke"
  else
    fail "SKILL.md missing routing for $spoke"
  fi
done
echo ""

# --- Check 7: Content preservation (±15% of original) ---
echo "Check 7: Content preservation (hub + sub-files ≈ original ±15%)"
for lang in js python java go; do
  case $lang in
    js)     hub="references/spoke-generate.md";        subs="references/generate/";     original=959;;
    python) hub="references/spoke-generate-python.md"; subs="references/generate/python/"; original=1175;;
    java)   hub="references/spoke-generate-java.md";   subs="references/generate/java/";   original=1424;;
    go)     hub="references/spoke-generate-go.md";     subs="references/generate/go/";     original=1450;;
  esac

  hub_lines=$(wc -l < "$hub" | tr -d ' ')
  sub_lines=0
  for f in "${subs}"*.md; do
    sub_lines=$((sub_lines + $(wc -l < "$f" | tr -d ' ')))
  done
  total=$((hub_lines + sub_lines))

  min=$((original * 85 / 100))
  max=$((original * 115 / 100))

  if [ "$total" -ge "$min" ] && [ "$total" -le "$max" ]; then
    pass "$lang: $total lines (hub $hub_lines + subs $sub_lines) within [$min, $max] (original $original)"
  else
    fail "$lang: total $total lines outside range [$min, $max] (original $original, hub=$hub_lines, subs=$sub_lines)"
  fi
done
echo ""

# --- Check 8: Sub-file directory structure ---
echo "Check 8: Sub-file directory structure"
for dir in "references/generate" "references/generate/python" "references/generate/java" "references/generate/go"; do
  if [ -d "$dir" ]; then
    file_count=$(ls -1 "${dir}/"*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$file_count" -eq 6 ]; then
      pass "$dir/ has 6 sub-files"
    else
      fail "$dir/ has $file_count sub-files (expected 6)"
    fi
  else
    fail "Missing directory: $dir/"
  fi
done
echo ""

# --- Summary ---
echo "========================================="
echo " Results: $PASS passed, $FAIL failed"
echo "========================================="

if [ "$FAIL" -gt 0 ]; then
  echo -e "Failures:$ERRORS"
  exit 1
fi

echo ""
echo "ALL CHECKS PASS"
exit 0
