#!/usr/bin/env bash
# validate-to-junit.sh — Convert validate-plugin.sh output to JUnit XML
# Reads validation output from stdin or a file argument and produces
# a JUnit XML report. Each check becomes a testcase; failed checks
# get a <failure> element with the error code and description.
#
# Usage:
#   bash scripts/validate-plugin.sh 2>&1 | bash scripts/validate-to-junit.sh [output.xml]
#   bash scripts/validate-to-junit.sh input.txt [output.xml]

set -euo pipefail

OUTPUT_FILE="${2:-}"
INPUT_FILE="${1:-}"

# If only one arg and it looks like an output path (ends in .xml), treat it as output
if [ $# -eq 1 ] && [[ "$1" == *.xml ]]; then
  OUTPUT_FILE="$1"
  INPUT_FILE=""
fi

# Default output path
if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE=".bestest/reports/junit-validation.xml"
fi

# Create output directory
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Read input: from file arg or stdin
if [ -n "$INPUT_FILE" ] && [ -f "$INPUT_FILE" ]; then
  INPUT=$(cat "$INPUT_FILE")
else
  INPUT=$(cat)
fi

# Parse check results from validation output
# Lines look like: "  ✅ E001 (critical): Routing spoke 'x' listed in reference_index"
# or:               "  ❌ E001 (critical): Routing spoke 'x' listed in reference_index"
PASS_COUNT=0
FAIL_COUNT=0
TESTCASES=""

echo "$INPUT" | while IFS= read -r line; do
  # Match check result lines: "  ✅ E001 (critical): description" or "  ❌ E001 (critical): description"
  # Use grep to extract fields since bash regex has issues with Unicode in some versions
  if ! echo "$line" | grep -qE '^\s*(✅|❌)\s+[A-Z][0-9]+\s*\([^)]+\):'; then
    continue
  fi

  # Extract status character
  STATUS=$(echo "$line" | grep -oE '✅|❌' | head -1)
  # Extract error code (e.g. E001)
  ERROR_CODE=$(echo "$line" | grep -oE '[A-Z][0-9]+' | head -1)
  # Extract severity
  SEVERITY=$(echo "$line" | grep -oE '\(([^)]+)\)' | tr -d '()' | head -1)
  # Extract description (everything after the colon)
  DESCRIPTION=$(echo "$line" | sed 's/^[^:]*:[[:space:]]*//' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

  CLASSNAME="bestest.validation"
  TESTNAME="$ERROR_CODE: $DESCRIPTION"

  if [ "$STATUS" = "✅" ]; then
    echo "PASS|$CLASSNAME|$TESTNAME"
  else
    echo "FAIL|$CLASSNAME|$TESTNAME|$ERROR_CODE|$SEVERITY|$DESCRIPTION"
  fi
done > /tmp/junit-parsed-$$.txt

while IFS='|' read -r type classname testname error_code severity description; do
  if [ "$type" = "PASS" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    TESTCASES+="    <testcase classname=\"$classname\" name=\"$testname\" time=\"0\" />"$'\n'
  elif [ "$type" = "FAIL" ]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TESTCASES+="    <testcase classname=\"$classname\" name=\"$testname\" time=\"0\">"$'\n'
    TESTCASES+="      <failure message=\"$error_code ($severity): $description\" type=\"$severity\">$error_code: $description</failure>"$'\n'
    TESTCASES+="    </testcase>"$'\n'
  fi
done < /tmp/junit-parsed-$$.txt
rm -f /tmp/junit-parsed-$$.txt

TOTAL=$((PASS_COUNT + FAIL_COUNT))

# Write JUnit XML
cat > "$OUTPUT_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="bestest-plugin-validation" tests="$TOTAL" failures="$FAIL_COUNT" errors="0" skipped="0" time="0">
${TESTCASES}  </testsuite>
</testsuites>
EOF

echo "JUnit XML report written to $OUTPUT_FILE ($TOTAL tests, $FAIL_COUNT failures)"
