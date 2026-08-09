# Phase 7 — Quality Audit

> **On-demand load:** When quality audit scoring or anti-pattern detection is needed, read this file. Apply the scoring rubric, anti-pattern checks, and flakiness testing defined here.

---

## Step 1: Assertion Quality Scoring

Score each test file on the 0-100 rubric from `references/ai-generation-guide.md` Phase 6:

| Dimension | Max Points | What to check |
|-----------|-----------|---------------|
| Assertion Quality | 30 | Specific matchers (`toBe`, `toEqual`), not `toBeTruthy` on non-booleans. Edge cases covered. Error paths tested. |
| Test Structure | 20 | Clear Arrange-Act-Assert. Descriptive names (`[unit] [behavior] when [condition]`). Single concept per test. |
| Independence | 20 | `beforeEach` resets all state. No shared mutable variables. Proper mock cleanup. Factory functions. |
| Coverage Value | 15 | Happy path + error paths + boundary values. Tests meaningful branches. No coverage-only tests. |
| Maintainability | 15 | Factory functions for data. No magic numbers. No hardcoded IDs/dates. Follows project conventions. |

**Scoring process:**
```
For each generated test file:
  Read the test file content.
  Evaluate each dimension using the scoring adjustments from ai-generation-guide.md:
    +3 per distinct edge case assertion
    +2 per error path assertion
    +2 per test with descriptive name following pattern
    +3 per factory function with sensible defaults
    -5 per toBeTruthy on a non-boolean value
    -5 per shared let variable mutated without beforeEach reset
    -3 per test with generic name ('works', 'test1')
    -3 per magic number without comment or constant
    -8 per expect.anything() as sole assertion
    -10 per tautological assertion
    -10 per .only or .skip left in committed code

  Compute total score (0-100).
  If score < quality_threshold * 100 (default: 70):
    Flag file for quality improvement.
    Identify lowest-scoring dimension for targeted fix suggestions.
```

## Step 2: Anti-Pattern Detection

Run the 20 test smell checks from `references/anti-patterns.md` against each generated test file:

**Critical checks (zero tolerance — auto-fix):** tautological assertions, hardcoded secrets, missing assertions.

**High checks (auto-fix when detected):** sleep-based waits, test interdependencies, empty catch blocks, flaky indicators (unmocked Date/Random), mystery guest (external state), mock overuse, happy path only, missing cleanup.

**Medium checks (flag for review):** overly broad matchers, implementation coupling, snapshot drift, hardcoded test data, assertion roulette, fragile selectors, complex test logic.

**Low checks (style suggestions):** duplicate test logic, test-only code in source, meaningful test names.

**Auto-fix capability for common smells:**
```
If toBeTruthy() on non-boolean → replace with toBe(expectedValue) or toBeGreaterThan(0)
If toBeFalsy() on non-boolean → replace with toBe(expectedValue) or toBe(0) or toBeNull()
If expect.anything() as sole assertion → replace with specific shape assertion
If missing afterEach for beforeEach with timers → add afterEach with vi.useRealTimers()
If missing beforeEach for shared mutable state → add beforeEach with reset
If sleep/timeout wait → replace with waitFor() or proper async pattern
```

## Step 3: Flakiness Testing

```
Run each generated test file 5 times sequentially:
  Vitest: npx vitest run <test-file> (5 sequential executions)
  Jest: npx jest <test-file> (5 sequential executions)

Track results across all 5 runs:
  If any test passes in some runs and fails in others:
    Flag as "flaky" with the inconsistency pattern.
    Common causes: uncontrolled time, uncontrolled randomness, race conditions.
    Attempt auto-fix (add fake timers, seed Math.random, add proper awaits).
    Re-test after fix.
  If all 5 runs produce identical results:
    Mark as "stable".
```

## Step 4: Quality Report

```
Assemble quality report for each generated file:
  {
    file: "src/utils/pricing.test.ts",
    sourceFile: "src/utils/pricing.ts",
    score: 85,
    dimensions: {
      assertionQuality: 26,
      testStructure: 17,
      independence: 18,
      coverageValue: 13,
      maintainability: 11
    },
    antiPatterns: [],  // Hopefully empty
    flakiness: "stable",
    coverageDelta: { before: "0%", after: "92%", lines: "+92%", branches: "+85%" },
    testsGenerated: 6,
    testsPassed: 6,
    testsFailed: 0
  }

If score < quality_threshold * 100:
  Print: "Quality score {score} is below threshold {threshold}. Suggested improvements:"
  For the lowest-scoring dimension:
    Print: "  - {dimension}: {score}/{max} — {specific improvement suggestions}"
```

## External Calibration

### Known Limitation: LLM Self-Evaluation Bias

The quality scoring in this phase is performed by the same LLM agent that generated the tests. Research on LLM self-evaluation consistently shows 15–25% optimism bias when models evaluate their own outputs. This means:
- Tests scoring 70-75 (near the default threshold) may actually be 55-65 quality
- The auto-commit threshold (`quality_threshold × 100`) should be treated as a soft gate, not a guarantee

### Mitigation: Mutation Testing (Optional Phase 7b)

For projects with critical testing requirements, run an optional mutation testing pass after Phase 7:

```
If stryker/stryker-cli is available in the project:
  1. Run: npx stryker run
  2. Check mutation score:
     - Score ≥ 60%: Tests are catching real defects. Confidence: HIGH.
     - Score 40-60%: Tests have gaps. Flag for review.
     - Score < 40%: Tests may be testing mocks, not real code. Flag as low-quality.
  3. Add mutation score to the quality report.
```

### Mitigation: Coverage Delta Verification

After Phase 7 scoring, cross-check the quality score against the coverage delta:
- If quality score ≥ 70 but coverage delta is 0% → tests may be exercising mocks only. Downgrade quality score by 10 points.
- If quality score ≥ 70 and coverage delta > 5% → score is plausible.
- This cross-check provides a lightweight external anchor without requiring mutation testing tooling.
