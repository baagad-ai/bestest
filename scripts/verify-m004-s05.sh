#!/usr/bin/env bash
# verify-m004-s05.sh — S05 verification: Phase 1 quick wins + key Phase 2 security items
# Validates R1, R4, R5, R6, R7, R10, R11, R15, README.md, CHANGELOG.md, version bump.
# Extends (does not replace) verify-m004-s04.sh which covers S01-S03 deliverables.

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

echo "=== M004/S05 Verification — Phase 1 Quick Wins + Phase 2 Security ==="
echo ""

SM="$SKILL_DIR/SKILL.md"
REFS="$SKILL_DIR/references"

# ── Group 1: R1 — Content-boundary markers in all 4 generate spokes (4 checks) ──────
echo "--- Group 1: R1 — Content-Boundary Markers ---"

for spoke in spoke-generate.md spoke-generate-python.md spoke-generate-java.md spoke-generate-go.md; do
  check "$spoke has BEGIN_UNTRUSTED_SOURCE marker" \
    grep -q "BEGIN_UNTRUSTED_SOURCE" "$REFS/$spoke"
done

echo ""

# ── Group 2: R4 — State corruption handling in 7 spoke files (7 checks) ──────────────
echo "--- Group 2: R4 — State Corruption Handling ---"

for spoke in spoke-init.md spoke-generate.md spoke-generate-python.md spoke-generate-java.md spoke-generate-go.md spoke-run.md spoke-fix.md; do
  check "$spoke has state corruption handling" \
    grep -qiE "corrupt|state.*valid|JSON.*pars" "$REFS/$spoke"
done

echo ""

# ── Group 3: R5 — Confidence gate at routing layer in SKILL.md (2 checks) ───────────
echo "--- Group 3: R5 — Confidence Gate at Routing Layer ---"

check "SKILL.md has confidence gate with 0.6 threshold" \
  grep -qE "confidence.*0\.6|0\.6.*threshold" "$SM"
check "SKILL.md warns user when confidence below threshold" \
  grep -qiE "warn.*user.*confidence|low confidence" "$SM"

echo ""

# ── Group 4: R6 — Write-to-disk language in all 4 generate spokes (4 checks) ────────
echo "--- Group 4: R6 — Write-to-Disk Language (Auto-Commit Clarification) ---"

for spoke in spoke-generate.md spoke-generate-python.md spoke-generate-java.md spoke-generate-go.md; do
  check "$spoke uses write-to-disk terminology" \
    grep -qiE "write.to.disk|write-to-disk" "$REFS/$spoke"
done

echo ""

# ── Group 5: R7 — spoke-init title lists all 4 languages (1 check) ───────────────────
echo "--- Group 5: R7 — spoke-init Multi-Language Title ---"

check "spoke-init.md title mentions all 4 languages (JS/TS, Python, Java, Go)" \
  grep -q "JS/TS, Python, Java, Go" "$REFS/spoke-init.md"

echo ""

# ── Group 6: R10 — Multi-language routing in SKILL.md (2 checks) ────────────────────
echo "--- Group 6: R10 — Multi-Language Project Routing ---"

check "SKILL.md has polyglot/multi-language handling section" \
  grep -qiE "polyglot|multi.*language.*project|Multi-Language Projects" "$SM"
check "SKILL.md offers sequential generation for multiple languages" \
  grep -qiE "queue multiple|sequentially" "$SM"

echo ""

# ── Group 7: R11 — HITL scoped to mutating commands only (2 checks) ──────────────────
echo "--- Group 7: R11 — HITL Scoped to Mutating Commands ---"

check "SKILL.md specifies HITL applies to mutating commands only" \
  grep -qi "mutating commands only" "$SM"
check "SKILL.md lists read-only commands exempt from HITL" \
  grep -qi "Read-only commands" "$SM"

echo ""

# ── Group 8: R15 — Version compatibility check (2 checks) ────────────────────────────
echo "--- Group 8: R15 — Version Compatibility Check ---"

check "spoke-init.md has version compatibility check section" \
  grep -qiE "version.*compat|compat.*check|Version Compatibility" "$REFS/spoke-init.md"
check "spoke-doctor.md has version compatibility check" \
  grep -qiE "version.*compat|compat.*check|Version compatibility" "$REFS/spoke-doctor.md"

echo ""

# ── Group 9: README.md (3 checks) ────────────────────────────────────────────────────
echo "--- Group 9: README.md ---"

check "README.md exists" test -f "$SKILL_DIR/README.md"
check "README.md is non-empty (>10 lines)" test "$(wc -l < "$SKILL_DIR/README.md")" -gt 10
check "README.md has quick start or installation section" \
  grep -qiE "quick start|installation|install" "$SKILL_DIR/README.md"

echo ""

# ── Group 10: CHANGELOG.md + version bump (3 checks) ─────────────────────────────────
echo "--- Group 10: CHANGELOG.md + Version Bump ---"

check "CHANGELOG.md has [1.2.0] entry" \
  grep -q "1.2.0" "$SKILL_DIR/CHANGELOG.md"
check "SKILL.md frontmatter version is 1.2.0" \
  grep -q 'version: "1.2.0"' "$SM"
check "SKILL.md remains ≤ 500 lines" \
  test "$(wc -l < "$SM")" -le 500

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed (total $((PASS + FAIL)) checks)"
echo "═══════════════════════════════════════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  echo "❌ VERIFICATION FAILED — $FAIL check(s) did not pass"
  exit 1
else
  echo "✅ ALL CHECKS PASSED — All S05 changes structurally verified"
  exit 0
fi
