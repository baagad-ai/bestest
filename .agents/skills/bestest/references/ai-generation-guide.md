# AI Test Generation Guide

Authoritative reference for the 7-phase test generation pipeline used by `/bestest generate`. This guide defines quality standards, scoring rubrics, and design patterns that every generated test must satisfy. The generate spoke (`references/spoke-generate.md`) consumes this guide during Phase 4 (test writing) and Phase 6 (quality audit).

**Scope:** JavaScript and TypeScript projects using Vitest or Jest. All examples use Vitest-first syntax with Jest equivalents noted where they differ.

**Audience:** AI agents generating tests. This is not a human-facing tutorial — it is a machine-consumable specification for producing high-quality test suites.

---

## Phase 1: Code Analysis

Before writing any test, analyze the target source file across five dimensions. Each dimension determines a different aspect of the test strategy.

### Exports

Identify every named export, default export, and re-export. Each export is a testable unit. Classify exports by type:

| Export Type | Test Priority | Analysis Focus |
|-------------|---------------|----------------|
| Named function | High | Input/output contract, edge cases |
| Default function | High | Same as named function |
| Class | High | Constructor, public methods, lifecycle |
| Constant/enum | Low | Value correctness |
| Type/interface | None | No runtime behavior to test |
| Re-export | None | Covered by source module tests |

**Decision rule:** If an export has runtime behavior (functions, classes), it needs tests. If it is purely declarative (types, interfaces, constants), skip it.

### Types

Extract the TypeScript type signature for every function and method. The type signature defines the input space and output contract:

```typescript
// Source
export function parseConfig(raw: string, defaults?: Partial<Config>): Config;

// Analysis
// - Input space: any string + optional partial override
// - Output contract: Config object (shape known from type)
// - Edge cases: empty string, malformed JSON, missing optional fields
// - Throws: likely throws on invalid input (verify from source)
```

When types are unavailable (plain JS), infer them from JSDoc, default values, and usage patterns.

### Dependencies

Map every import to determine what needs mocking:

1. **Pure logic imports** (utility functions, constants) — No mock needed; test with real implementation.
2. **Side-effect imports** (database clients, HTTP libraries, filesystem) — Mock at the module boundary using `vi.mock()`.
3. **Framework imports** (React, Next.js, Express) — Use framework-specific test utilities (RTL, supertest).
4. **Internal module imports** (other project files) — Mock only if the dependency has side effects or complex setup.

**Decision rule:** Mock at architectural boundaries (network, filesystem, database), never at internal function boundaries. Testing with real internal logic catches integration bugs.

### Side Effects

Identify all side effects in the module:

- **Network calls:** `fetch`, `axios`, HTTP clients
- **Filesystem:** `fs.readFileSync`, `fs.promises.*`
- **Timers:** `setTimeout`, `setInterval`, `Date.now()`
- **Global state:** `process.env`, singleton stores, module-level caches
- **DOM manipulation:** Direct DOM access outside React/Vue

Each side effect must be controlled in tests. See Phase 4 for mocking patterns.

### Complexity

Estimate cyclomatic complexity to determine test count:

| Complexity | Minimum Tests | Strategy |
|------------|---------------|----------|
| 1-3 (simple) | 2-3 | Happy path + 1-2 edge cases |
| 4-8 (moderate) | 4-6 | Each branch + boundary values |
| 9-15 (complex) | 6-10 | Full branch coverage + error paths |
| 16+ (very complex) | 10+ | Consider splitting the function |

### Prioritization

When generating tests for multiple targets, sort by:

1. **Criticality:** Entry points, auth, data handling, payment logic first
2. **Risk:** High-complexity functions with many branches
3. **Coverage gap:** Modules with zero existing tests
4. **Stability:** Prefer stable APIs over code marked as experimental

---

## Phase 2: Test Strategy Selection

Match each export to a test strategy based on its type and dependencies. The decision matrix below maps code types to strategies.

### Decision Matrix

| Code Type | Strategy | Test Focus | Framework Utilities |
|-----------|----------|------------|---------------------|
| Pure function | Input/output assertions | Transform correctness, edge cases | `vi.fn()` for callback props |
| Component | Rendering + interaction | UI output, user events, accessibility | `@testing-library/react`, `@testing-library/user-event` |
| API route | Request/response integration | Status codes, response shape, error handling | `supertest`, MSW |
| State management | State transitions | Dispatch → state mapping, selectors, side effects | Render hook utilities, store mocks |
| Async operation | Async patterns with cleanup | Promise resolution, rejection, cancellation, timing | `vi.useFakeTimers()`, `waitFor()` |

### Pure Functions

Test every pure function with input/output assertions. No mocks needed.

```typescript
// Source: utils/calculate.ts
export function calculateDiscount(
  price: number,
  percent: number,
  mode: 'flat' | 'percentage' = 'percentage'
): number { /* ... */ }

// Test strategy: exhaustive input/output matrix
describe('calculateDiscount', () => {
  test.each([
    { price: 100, percent: 10, mode: 'percentage', expected: 90 },
    { price: 100, percent: 5, mode: 'flat', expected: 95 },
    { price: 0, percent: 10, mode: 'percentage', expected: 0 },
    { price: 50, percent: 0, mode: 'percentage', expected: 50 },
    { price: -10, percent: 10, mode: 'percentage', expected: -9 },
  ])('calculateDiscount($price, $percent, $mode) = $expected', ({ price, percent, mode, expected }) => {
    expect(calculateDiscount(price, percent, mode)).toBe(expected);
  });
});
```

### Components

Test rendering output and user interactions. Never test implementation details like internal state or lifecycle methods.

```typescript
// Source: components/SearchBar.tsx
export function SearchBar({ onSearch, isLoading }: Props) { /* ... */ }

// Test strategy: render → interact → assert visible output
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

describe('SearchBar', () => {
  test('calls onSearch with query when form is submitted', async () => {
    const onSearch = vi.fn();
    render(<SearchBar onSearch={onSearch} isLoading={false} />);

    const input = screen.getByRole('textbox', { name: /search/i });
    await userEvent.type(input, 'test query');
    await userEvent.click(screen.getByRole('button', { name: /search/i }));

    expect(onSearch).toHaveBeenCalledWith('test query');
  });

  test('disables submit while loading', () => {
    render(<SearchBar onSearch={vi.fn()} isLoading={true} />);
    expect(screen.getByRole('button', { name: /search/i })).toBeDisabled();
  });
});
```

### API Routes

Test the full request/response cycle including error handling.

```typescript
// Source: api/users/route.ts
export async function POST(request: Request): Promise<Response> { /* ... */ }

// Test strategy: construct real Request objects, assert Response shape
import { POST } from '@/api/users/route';

describe('POST /api/users', () => {
  test('creates user and returns 201', async () => {
    const request = new Request('http://localhost/api/users', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: 'Alice', email: 'alice@test.com' }),
    });

    const response = await POST(request);

    expect(response.status).toBe(201);
    const body = await response.json();
    expect(body).toMatchObject({ name: 'Alice', email: 'alice@test.com' });
    expect(body.id).toBeDefined();
  });
});
```

### State Management

Test state transitions: what dispatch produces what state.

```typescript
// Source: store/cartSlice.ts
export function cartReducer(state: CartState, action: CartAction): CartState { /* ... */ }

// Test strategy: given state + action → expect new state
describe('cartReducer', () => {
  test('addItem appends item to empty cart', () => {
    const initialState: CartState = { items: [], total: 0 };
    const action = { type: 'addItem', payload: { id: '1', name: 'Widget', price: 9.99 } };

    const result = cartReducer(initialState, action);

    expect(result.items).toHaveLength(1);
    expect(result.items[0]).toEqual(action.payload);
    expect(result.total).toBe(9.99);
  });

  test('removeItem returns unchanged state for missing item', () => {
    const state: CartState = { items: [{ id: '1', name: 'Widget', price: 9.99 }], total: 9.99 };
    const action = { type: 'removeItem', payload: { id: '99' } };

    expect(cartReducer(state, action)).toEqual(state);
  });
});
```

### Async Operations

Test promise resolution, rejection, and cancellation with proper timer control.

```typescript
// Source: services/fetchData.ts
export async function fetchUserData(userId: string): Promise<UserData> { /* ... */ }

// Test strategy: mock async boundary, test all promise states
describe('fetchUserData', () => {
  test('returns user data on success', async () => {
    const mockData = { id: '1', name: 'Alice' };
    vi.mocked(globalThis.fetch).mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(mockData),
    } as Response);

    const result = await fetchUserData('1');

    expect(result).toEqual(mockData);
    expect(globalThis.fetch).toHaveBeenCalledWith('/api/users/1');
  });

  test('throws on network error', async () => {
    vi.mocked(globalThis.fetch).mockRejectedValueOnce(new Error('Network failure'));

    await expect(fetchUserData('1')).rejects.toThrow('Network failure');
  });

  test('throws on non-ok response', async () => {
    vi.mocked(globalThis.fetch).mockResolvedValueOnce({
      ok: false,
      status: 404,
      statusText: 'Not Found',
    } as Response);

    await expect(fetchUserData('missing')).rejects.toThrow(/not found/i);
  });
});
```

---

## Phase 3: Data Generation

### Equivalence Class Partitioning

Divide the input space into equivalence classes. One test per class is sufficient — additional tests in the same class provide diminishing returns.

```typescript
// For a function that processes ages (0-150):
// Class 1: Negative (invalid) → -1
// Class 2: Zero (boundary) → 0
// Class 3: Valid range (1-17, minor) → 12
// Class 4: Valid range (18-64, adult) → 35
// Class 5: Valid range (65-150, senior) → 75
// Class 6: Over maximum (invalid) → 200

test.each([
  { age: -1, expectError: true },
  { age: 0, expectError: false },
  { age: 12, expectError: false, category: 'minor' },
  { age: 35, expectError: false, category: 'adult' },
  { age: 75, expectError: false, category: 'senior' },
  { age: 200, expectError: true },
])('processAge($age)', ({ age, expectError, category }) => { /* ... */ });
```

### Boundary Value Analysis

Test at the boundaries of each equivalence class. For numeric ranges `[a, b]`, test `a-1`, `a`, `a+1`, `b-1`, `b`, `b+1`.

```typescript
// For a function accepting 1-100 inclusive:
test.each([
  { value: 0, description: 'just below minimum' },
  { value: 1, description: 'minimum boundary' },
  { value: 2, description: 'just above minimum' },
  { value: 99, description: 'just below maximum' },
  { value: 100, description: 'maximum boundary' },
  { value: 101, description: 'just above maximum' },
])('validates range at $description', ({ value }) => { /* ... */ });
```

### Factory Functions

Always use factory functions for test data. Never hardcode objects inline in multiple tests.

```typescript
// Factory pattern — generates valid data with sensible defaults
function createUser(overrides?: Partial<User>): User {
  return {
    id: 'user-1',
    name: 'Test User',
    email: 'test@example.com',
    role: 'viewer',
    createdAt: '2024-01-15T00:00:00Z',
    ...overrides,
  };
}

// Usage — each test specifies only what it needs
test('admin can delete resources', () => {
  const admin = createUser({ role: 'admin' });
  expect(canDelete(admin)).toBe(true);
});

test('viewer cannot delete resources', () => {
  const viewer = createUser({ role: 'viewer' });
  expect(canDelete(viewer)).toBe(false);
});

// Array factory — generates multiple distinct items
function createUserList(count: number, overrides?: Partial<User>): User[] {
  return Array.from({ length: count }, (_, i) =>
    createUser({ id: `user-${i + 1}`, ...overrides })
  );
}
```

### Property-Based Testing Hints

For complex logic where enumerating cases is impractical, use property-based patterns:

```typescript
import { describe, test, expect } from 'vitest';
import fc from 'fast-check';

describe('sort', () => {
  test('output length equals input length', () => {
    fc.assert(fc.property(fc.array(fc.integer()), (arr) => {
      expect(sort(arr)).toHaveLength(arr.length);
    }));
  });

  test('output is ordered', () => {
    fc.assert(fc.property(fc.array(fc.integer()), (arr) => {
      const result = sort(arr);
      for (let i = 1; i < result.length; i++) {
        expect(result[i]).toBeGreaterThanOrEqual(result[i - 1]);
      }
    }));
  });
});
```

---

## Phase 4: Test Writing

### Naming Convention

Test names must describe the specific scenario and expected outcome. Follow the pattern: `[unit] does [behavior] when [condition]`.

```typescript
// BAD — vague
test('works')
test('handles error')

// GOOD — specific
test('calculateDiscount returns 0 when price is 0')
test('fetchUser throws NetworkError when fetch returns 503')
test('Cart component shows empty state when items array is empty')
```

### Arrange-Act-Assert Structure

Every test body must follow this three-part structure. Separate each section with a blank line.

```typescript
test('calculateTotal applies bulk discount for 10+ items', () => {
  // Arrange
  const items = createItemList(12, { price: 10 });

  // Act
  const total = calculateTotal(items);

  // Assert
  expect(total).toBe(108); // 12 * 10 * 0.9
});
```

### Single Assertion Per Concept

Each test should verify one logical concept. Multiple `expect` calls that verify different aspects of the same concept are fine. Multiple unrelated assertions belong in separate tests.

```typescript
// GOOD — multiple expects, one concept (response shape)
test('createUser returns user with generated id', () => {
  const user = createUser({ name: 'Alice' });
  expect(user.id).toBeDefined();
  expect(user.name).toBe('Alice');
});

// BAD — two unrelated concepts in one test
test('createUser works', () => {
  const user = createUser({ name: 'Alice' });
  expect(user.name).toBe('Alice');        // Concept 1: name
  expect(sendWelcomeEmail).toHaveBeenCalled(); // Concept 2: side effect
});
```

### Mocking Guidelines

**Rule 1: Mock at boundaries, not internals.** Mock external services (API, database, filesystem), never internal functions within the same module.

```typescript
// BAD — mocking internal helper
vi.mock('./helpers', () => ({
  validateInput: vi.fn().mockReturnValue(true), // Testing through a fake
}));

// GOOD — mocking external dependency
vi.mock('axios', () => ({
  default: { get: vi.fn().mockResolvedValue({ data: mockResponse }) },
}));
```

**Rule 2: Reset mocks between tests.** Use `beforeEach` or `afterEach` to prevent state leakage.

```typescript
beforeEach(() => {
  vi.clearAllMocks();
});
```

**Rule 3: Assert on mock calls only when testing collaboration.** If the test's purpose is to verify a side effect (e.g., "sends analytics event"), asserting on mock calls is appropriate. If the test's purpose is to verify output, assert on the return value instead.

### Framework-Specific Patterns

Vitest and Jest share most APIs, but differ in mocking syntax:

| Concern | Vitest | Jest |
|---------|--------|------|
| Module mock | `vi.mock('./module')` | `jest.mock('./module')` |
| Function mock | `vi.fn()` | `jest.fn()` |
| Fake timers | `vi.useFakeTimers()` | `jest.useFakeTimers()` |
| Spy | `vi.spyOn(obj, 'method')` | `jest.spyOn(obj, 'method')` |
| Mock reset | `vi.clearAllMocks()` | `jest.clearAllMocks()` |
| Mock restore | `vi.restoreAllMocks()` | `jest.restoreAllMocks()` |

Always use the Vitest API (`vi.*`) unless the project is confirmed to use Jest exclusively.

---

## Phase 5: Verification Loop

The verification loop iterates: compile → run → coverage → mutation. Each step has a specific failure mode and fix protocol.

### Step 1: Compilation

Run the TypeScript compiler on generated test files:

```bash
npx tsc --noEmit --pretty path/to/test.test.ts
```

**Failure protocol:**
- Import error → Fix the import path; check if the source file exists and exports the symbol
- Type error → Fix the test's types; do not change source types to accommodate the test
- Missing dependency → Install the missing package; add to devDependencies
- Syntax error → Fix the test code structure

**Maximum iterations:** 3. After 3 compilation failures on the same test, present to the user for manual resolution.

### Step 2: Execution

Run the generated tests:

```bash
npx vitest run path/to/test.test.ts
```

**Failure protocol:**
- Test assertion fails → Analyze the failure message. Determine if the test expectation is wrong or the source has a bug. Fix the test, never the source.
- Timeout → Check for unmocked async operations. Add proper awaits or fake timers.
- Unhandled rejection → Check for missing `await` or uncaught promise chains.
- Segfault/crash → Usually indicates a real bug in source or a misconfigured mock. Escalate.

**Critical rule:** Never modify source code to make a test pass. If the source has a genuine bug discovered during test generation, note it in the test file as a comment and create a passing test that documents the current (possibly buggy) behavior.

```typescript
// NOTE: Source returns -1 for empty arrays, which may be a bug.
// This test documents current behavior for regression detection.
test('findMax returns -1 for empty array', () => {
  expect(findMax([])).toBe(-1);
});
```

**Maximum iterations:** 3 fix attempts per test. After 3 failures, skip the test and report it for manual resolution.

### Step 3: Coverage Analysis

Measure coverage contribution of the new tests:

```bash
npx vitest run --coverage path/to/test.test.ts
```

**Coverage thresholds:**
- Below 50% branch coverage → Add tests for uncovered branches
- Below 70% function coverage → Add tests for untested exports
- Below 60% line coverage → Add tests for uncovered logic paths

**Anti-pattern to avoid:** Do not add tests solely to inflate coverage numbers. Each test must verify meaningful behavior. A test that calls a function without asserting anything is worse than no test at all.

### Step 4: Mutation Testing (Optional)

If mutation testing is configured (e.g., Stryker), run it on the new tests to measure assertion strength:

```bash
npx stryker run
```

**Mutation survivors → strengthen assertions:**
- Surviving mutation on a conditional → Add a test that exercises the opposite branch
- Surviving mutation on a return value → Make the assertion more specific (exact value, not `toBeTruthy`)
- Surviving mutation on a boundary → Add a boundary value test

---

## Phase 6: Quality Audit

Every generated test is scored on a 0-100 scale across five dimensions. The minimum acceptable score is 70.

### Assertion Quality (0-30 points)

Measures whether assertions actually verify meaningful behavior.

| Score Range | Characteristics |
|-------------|-----------------|
| **25-30** | Specific values with `toBe`/`toEqual`; edge cases covered; error paths tested; no `toBeTruthy` on non-booleans |
| **18-24** | Mostly specific assertions; may miss some edge cases; 1-2 broad matchers on non-critical paths |
| **10-17** | Mix of specific and broad; missing edge cases; some `toBeDefined` where exact value is knowable |
| **0-9** | Predominantly `toBeTruthy`/`toBeFalsy`; `expect.any()` as sole assertion; missing error assertions |

**Scoring adjustments:**
- +3 per distinct edge case assertion
- +2 per error path assertion
- -5 per `toBeTruthy` on a non-boolean value
- -8 per `expect.anything()` as the only assertion
- -10 per tautological assertion (comparing value to itself)

### Test Structure (0-20 points)

Measures adherence to arrange-act-assert and naming conventions.

| Score Range | Characteristics |
|-------------|-----------------|
| **16-20** | Clear AAA separation; descriptive names; single concept per test; no copy-paste structure |
| **11-15** | AAA mostly present; names are adequate; may test 2 concepts in one test |
| **6-10** | AAA inconsistent; vague names; multiple unrelated assertions; significant duplication |
| **0-5** | No structure; test names are generic (`'works'`, `'test1'`); large copy-pasted blocks |

**Scoring adjustments:**
- +2 per test with descriptive name following the `[unit] [behavior] when [condition]` pattern
- -3 per test with a name like `'works'`, `'test'`, or `'handles edge case'`
- -5 per test with no AAA separation at all

### Independence (0-20 points)

Measures whether tests can run in any order, in isolation, without shared mutable state.

| Score Range | Characteristics |
|-------------|-----------------|
| **16-20** | All tests self-contained; `beforeEach` resets all state; no shared mutable variables; proper mock cleanup |
| **11-15** | Mostly independent; may share a read-only fixture; minor cleanup gaps |
| **6-10** | Some tests depend on shared state; cleanup present but incomplete; one test may affect another |
| **0-5** | Tests must run in order; shared mutable state across tests; no cleanup; `test.only` left in code |

**Scoring adjustments:**
- +3 per factory function used instead of hardcoded objects
- -5 per shared `let` variable mutated across tests without `beforeEach` reset
- -10 per test that only passes when run after another specific test
- -15 per `.only` or `.skip` left in committed code

### Coverage Value (0-15 points)

Measures whether tests cover meaningful paths, not just the happy path.

| Score Range | Characteristics |
|-------------|-----------------|
| **12-15** | Happy path + error paths + boundary values; tests meaningful branches; no coverage-only tests |
| **8-11** | Happy path + some error paths; may miss boundary values |
| **4-7** | Mostly happy path; error paths untested; tests only the obvious cases |
| **0-3** | Only happy path; tests that call code without asserting; coverage theater |

**Scoring adjustments:**
- +3 per error path test (testing that the function throws or returns an error)
- +2 per boundary value test
- -5 per test that calls a function but has no assertion on the result
- -8 per test that exists only to inflate line coverage

### Maintainability (0-15 points)

Measures how easy tests are to understand, modify, and extend.

| Score Range | Characteristics |
|-------------|-----------------|
| **12-15** | Factory functions for all data; clear intent; no magic numbers; no hardcoded IDs/dates; follows project conventions |
| **8-11** | Some hardcoded data; mostly clear intent; may have a few magic numbers |
| **4-7** | Significant hardcoded data; unclear test purpose; inconsistent patterns |
| **0-3** | All data hardcoded; copy-pasted across tests; no factories; magic numbers everywhere |

**Scoring adjustments:**
- +3 per factory function with sensible defaults and override support
- -2 per hardcoded date string that should use a factory
- -3 per magic number without an explanatory comment or named constant
- -5 per block of data copy-pasted between tests

### Score Examples

**90+ test (exemplary):**

```typescript
test('calculateDiscount returns reduced price when percentage is within valid range', () => {
  const cart = createCart({ items: [createItem({ price: 100 })] });

  const result = calculateDiscount(cart, 20);

  expect(result).toBe(80);
});
```
- Assertion: 28/30 — specific value, meaningful scenario
- Structure: 18/20 — clear AAA, descriptive name
- Independence: 18/20 — factory functions, no shared state
- Coverage: 14/15 — tests core calculation logic
- Maintainability: 14/15 — factories, no magic numbers

**50 test (mediocre):**

```typescript
test('discount works', () => {
  const cart = { items: [{ price: 100, id: 'item-1', name: 'Widget' }], total: 100 };
  const result = calculateDiscount(cart, 20);
  expect(result).toBeTruthy();
});
```
- Assertion: 8/30 — `toBeTruthy` on a number, no edge cases
- Structure: 10/20 — vague name, no clear AAA
- Independence: 15/20 — no shared state but hardcoded data
- Coverage: 8/15 — only happy path
- Maintainability: 9/15 — hardcoded object

**<30 test (poor):**

```typescript
test('test1', () => {
  expect(calculateDiscount({ items: [], total: 0 }, 20)).toBeTruthy();
});
```
- Assertion: 3/30 — `toBeTruthy` on what should be 0
- Structure: 2/20 — generic name, no AAA
- Independence: 10/20 — no shared state but inline data
- Coverage: 5/15 — empty input only
- Maintainability: 5/15 — inline object, no factory

### Auto-Commit Thresholds

| Score | Action |
|-------|--------|
| **≥ 85** | Auto-commit. High quality, no review needed. |
| **70-84** | Auto-commit with summary comment listing the quality score. |
| **50-69** | Present to user for review before committing. Flag specific low-scoring dimensions. |
| **< 50** | Do not commit. Regenerate or present for manual writing. |

---

## Phase 7: HITL Gate

Present a structured summary to the user before committing. The summary must include all of the following sections.

### Test Summary

```
Generated: 12 tests across 3 files
  - src/utils/calculate.test.ts: 5 tests (score: 88)
  - src/components/SearchBar.test.tsx: 4 tests (score: 76)
  - src/api/users/route.test.ts: 3 tests (score: 82)
```

### Coverage Delta

```
Coverage change (before → after):
  - src/utils/calculate.ts: 0% → 92% branch, 100% function
  - src/components/SearchBar.tsx: 45% → 78% branch, 100% function
  - src/api/users/route.ts: 0% → 85% branch, 100% function
```

### Quality Scores

```
Average quality score: 82/100
  - Highest: calculate.test.ts (88) — strong assertions, good edge case coverage
  - Lowest: SearchBar.test.tsx (76) — missing loading error state test
```

### Flagged Items

Items requiring manual review:

```
⚠️  src/components/SearchBar.test.tsx: No test for error state when fetch fails
⚠️  src/api/users/route.test.ts: Test skipped after 3 failed fix attempts (timeout issue)
```

### Auto-Commit Decision

Based on scores:
- All tests ≥ 70: **Auto-commit.** Summary displayed for awareness.
- Any test 50-69: **Auto-commit with flag.** User can review and request regeneration.
- Any test < 50: **Hold for review.** User must approve before commit.

---

## Quality Audit Checklist

This checklist maps to the 20 anti-pattern categories defined in `references/anti-patterns.md`. The generate spoke must verify generated tests pass all checks before presenting them to the user.

### Critical Checks (must pass — zero tolerance)

- [ ] **No tautological assertions** — No test compares a value to itself
- [ ] **No hardcoded secrets** — No real-looking passwords, API keys, or tokens
- [ ] **No missing assertions** — Every `test()`/`it()` block contains at least one `expect()`

### High Checks (should pass — flag if present)

- [ ] **No sleep-based waits** — No arbitrary `setTimeout`/`sleep` delays
- [ ] **No test interdependencies** — No shared mutable state without `beforeEach` reset
- [ ] **No empty catch blocks** — Every `catch` asserts on or re-throws the error
- [ ] **No flaky indicators** — `Date.now()`, `Math.random()`, and network calls are properly mocked

### Medium Checks (should minimize — acceptable in limited cases)

- [ ] **No overly broad matchers** — No `toBeTruthy()` on non-booleans, no bare `expect.anything()`
- [ ] **No implementation coupling** — No accessing private properties, no `(obj as any).internal`
- [ ] **No snapshot drift** — Inline snapshots under 50 lines; no dynamic data in snapshots

### Low Checks (style — address when convenient)

- [ ] **No test-only code in source** — No `if (process.env.NODE_ENV === 'test')` blocks added to source
- [ ] **No duplicate test logic** — No near-identical test blocks; use `test.each` for parameterized cases
- [ ] **Meaningful test names** — No `'works'`, `'test1'`, or `'handles edge case'` names
- [ ] **Factory functions for data** — No hardcoded objects repeated across tests
- [ ] **Proper cleanup** — `afterEach` restores faked timers, cleared mocks, reset state

---

## Cross-Reference

This guide is consumed by:
- **Generate spoke** (`references/spoke-generate.md`) — Phase 4 (test writing patterns) and Phase 6 (quality audit scoring)
- **Anti-pattern catalog** (`references/anti-patterns.md`) — Quality audit checklist maps to the 12+ anti-pattern categories; the generate spoke must ensure generated tests are free of all critical and high severity anti-patterns
- **Config schema** (`references/config-schema.md`) — Coverage thresholds and framework settings from project configuration
