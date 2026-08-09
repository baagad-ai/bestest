# Test Anti-Pattern Catalog

Comprehensive catalog of 20 test anti-pattern categories used by the scan engine to evaluate test quality. Each pattern includes a detection method (grep pattern or evaluation criteria), severity level, and example. The scan spoke uses these definitions to populate the `antiPatterns` array in the scan report. Categories 1–12 are the original catalog; categories 13–20 extend coverage for AI-generated test quality auditing.

## Severity Definitions

| Severity | Meaning | Action |
|----------|---------|--------|
| **critical** | Test provides zero confidence or introduces security risk | Must fix before merge |
| **high** | Test is unreliable or masks real failures | Fix in current sprint |
| **medium** | Test quality is degraded but still provides some value | Schedule improvement |
| **low** | Style or maintainability concern | Address when convenient |

---

## 1. Tautological Assertions

Tests that always pass regardless of the code under test. The assertion compares a value to itself, or the test has no meaningful assertion at all.

**Detection method:** Grep for assertion patterns where both sides are identical expressions, or where a variable is compared to itself.

| Field | Value |
|-------|-------|
| **Severity** | critical |
| **Grep patterns** | `expect\(([^)]+)\)\.(toBe\|toEqual\|toStrictEqual)\(\1\)` |
| **Evaluation criteria** | Assertion compares identical references; `expect(true).toBe(true)`; test body contains no `expect` calls despite testing a function with return values |

**Example:**

```typescript
// BAD — always passes
test('sum works', () => {
  const result = add(2, 3);
  expect(result).toBe(result);
});

// GOOD — validates actual behavior
test('sum works', () => {
  expect(add(2, 3)).toBe(5);
});
```

---

## 2. Sleep-Based Waits

Tests that use fixed timeouts (`setTimeout`, `sleep`, `delay`) to wait for async operations instead of proper async primitives. These are inherently flaky — they fail on slow machines and waste time on fast ones.

**Detection method:** Grep for sleep/timeout calls inside test files that are not wrapped in retry or polling logic.

| Field | Value |
|-------|-------|
| **Severity** | high |
| **Grep patterns** | `(await\s+)?sleep\(`, `(await\s+)?new\s+Promise.*setTimeout`, `(await\s+)?setTimeout\([^,]+,\s*\d{3,}\)`, `waitFor\s*\(\s*\(\)\s*=>\s*.*,\s*\{\s*timeout:\s*\d{4,}` |
| **Evaluation criteria** | Any `sleep()` or `setTimeout` call inside a test body or helper that introduces an arbitrary delay. Excludes legitimate retry patterns with backoff and `waitFor` with reasonable timeouts (<1s). |

**Example:**

```typescript
// BAD — arbitrary delay
test('data loads', async () => {
  fetchData();
  await sleep(2000);
  expect(data).toBeDefined();
});

// GOOD — wait for condition
test('data loads', async () => {
  await waitFor(() => expect(screen.getByText('Loaded')).toBeInTheDocument());
});
```

---

## 3. Hardcoded Secrets

Tests containing hardcoded passwords, API keys, tokens, or other credentials. These are security risks even in test files, especially if the repository is public or CI logs are visible.

**Detection method:** Grep for common secret patterns in test files, excluding mock values and known-safe fixtures.

| Field | Value |
|-------|-------|
| **Severity** | critical |
| **Grep patterns** | `password\s*[:=]\s*['"][^'"]{8,}['"]`, `api[_-]?key\s*[:=]\s*['"][^'"]+['"]`, `secret\s*[:=]\s*['"][^'"]+['"]`, `token\s*[:=]\s*['"](?:sk\|pk\|ghp\|glpat\|xox[bp])[_-][^'"]+['"]`, `Bearer\s+[A-Za-z0-9\-._~+/]+=*` |
| **Evaluation criteria** | Matches real-looking credentials (not `mock-password`, `test-secret`, `fake-key`, `***`, `xxx`, or fixture placeholders). Flags high-entropy strings assigned to credential-like variable names. |

**Example:**

```typescript
// BAD — real-looking secret
test('auth works', () => {
  const apiKey = 'sk-live-abc123def456ghi789';
  authenticate(apiKey);
});

// GOOD — obviously fake test value
test('auth works', () => {
  const apiKey = 'test-api-key-123';
  authenticate(apiKey);
});
```

---

## 4. Test Interdependencies

Tests that share mutable state, depend on execution order, or rely on side effects from previous tests. Each test should be independently runnable.

**Detection method:** Detect shared mutable variables modified across tests, `beforeAll`/`beforeEach` mutations that aren't reset, and tests that reference state set by other test cases.

| Field | Value |
|-------|-------|
| **Severity** | high |
| **Grep patterns** | Shared `let`/`var` variables modified in test bodies without `beforeEach` reset; `test.only` left in code; `describe.only` left in code |
| **Evaluation criteria** | A `let` or `var` variable declared in `describe` scope is mutated in one test and read in another without being reset in `beforeEach`. Tests that assert on a global store (e.g., database, file system) without cleaning up. Use of `.only` or `.skip` that would block other tests. |

**Example:**

```typescript
// BAD — shared mutable state
describe('cart', () => {
  let items: Item[] = [];
  
  test('adds item', () => {
    items.push({ id: 1, name: 'Widget' });
    expect(items).toHaveLength(1); // Passes only if this runs first
  });
  
  test('calculates total', () => {
    expect(calculateTotal(items)).toBe(9.99); // Depends on 'adds item'
  });
});

// GOOD — isolated state
describe('cart', () => {
  let items: Item[];
  
  beforeEach(() => {
    items = [];
  });
  
  test('adds item', () => {
    items.push({ id: 1, name: 'Widget' });
    expect(items).toHaveLength(1);
  });
  
  test('calculates total', () => {
    items.push({ id: 1, name: 'Widget', price: 9.99 });
    expect(calculateTotal(items)).toBe(9.99);
  });
});
```

---

## 5. Missing Assertions

Tests that execute code but never assert the result. They provide false confidence — the test passes even if the code is broken.

**Detection method:** Identify test blocks that contain no `expect`, `assert`, `should`, or `assertThat` calls.

| Field | Value |
|-------|-------|
| **Severity** | critical |
| **Grep patterns** | Test blocks (`test(`, `it(`) with no `expect(`, `assert(`, `should`, or `assertThat(` between the opening and closing brace |
| **Evaluation criteria** | A `test()` or `it()` block whose body contains zero assertion calls. Excludes `test.skip`, `test.todo`, and tests that only verify no-throw via `expect(() => fn()).not.toThrow()`. Also excludes tests where the only assertion is a `expect.hasAssertions()` or `expect.assertions(N)` guard (these are valid). |

**Example:**

```typescript
// BAD — no assertion
test('processes data', () => {
  const result = processData(input);
  // Forgets to assert anything
});

// GOOD — validates result
test('processes data', () => {
  const result = processData(input);
  expect(result.status).toBe('success');
  expect(result.items).toHaveLength(3);
});
```

---

## 6. Empty Catch Blocks

Tests that catch errors but silently swallow them. This hides failures and makes debugging difficult.

**Detection method:** Grep for `catch` blocks with empty or pass-through bodies in test files.

| Field | Value |
|-------|-------|
| **Severity** | high |
| **Grep patterns** | `catch\s*\([^)]*\)\s*\{\s*\}`, `catch\s*\([^)]*\)\s*\{\s*//\s*(noop\|ignore\|pass\|intentional\|TODO)\s*\}` |
| **Evaluation criteria** | A `catch` block whose body is empty, contains only a comment, or only logs without re-throwing or asserting. Excludes `catch` blocks that assert on the error (e.g., `catch (e) { expect(e.message).toContain('...') }`). |

**Example:**

```typescript
// BAD — silently swallows errors
test('handles invalid input', () => {
  try {
    processData('invalid');
  } catch (e) {
    // Should fail the test but doesn't
  }
});

// GOOD — asserts on the error
test('handles invalid input', () => {
  expect(() => processData('invalid')).toThrow('Invalid input format');
});
```

---

## 7. Overly Broad Matchers

Assertions so permissive they would pass with nearly any value. Common examples include `toBeDefined()` on a value that should be a specific type, `toBeTruthy()` when testing non-boolean results, or `any()`/`anything()` matchers.

**Detection method:** Grep for permissive matcher patterns and evaluate whether they match the intended test scope.

| Field | Value |
|-------|-------|
| **Severity** | medium |
| **Grep patterns** | `\.toBeTruthy\(\)`, `\.toBeFalsy\(\)`, `expectAnything\(\)`, `expect\.anything\(\)`, `\.toContainEqual\(expect\.anything\(\)\)`, `\.toEqual\(expect\.any\(` |
| **Evaluation criteria** | Flag `toBeTruthy`/`toBeFalsy` when applied to non-boolean values (e.g., `expect(result).toBeTruthy()` where `result` is an object). Flag `expect.anything()` and `expect.any(Type)` used as the sole assertion target. Excludes legitimate uses like `expect(mock).toHaveBeenCalledWith(expect.any(String))` where the type constraint is meaningful. |

**Example:**

```typescript
// BAD — too permissive for a numeric return
test('calculates price', () => {
  const price = calculatePrice(cart);
  expect(price).toBeTruthy(); // Passes with any non-zero value
});

// GOOD — specific assertion
test('calculates price', () => {
  const price = calculatePrice(cart);
  expect(price).toBe(29.99);
});
```

---

## 8. Implementation Coupling

Tests that assert on internal implementation details (private methods, internal state, specific variable names) rather than observable behavior. These tests break during legitimate refactors.

**Detection method:** Detect assertions on private/internal members, direct access to closure variables, and assertions on mock call counts that test "how" rather than "what."

| Field | Value |
|-------|-------|
| **Severity** | medium |
| **Grep patterns** | Accessing `_`-prefixed properties: `\._[a-zA-Z]`; asserting on private fields: `#`; testing mock call order: `toHaveBeenNthCalledWith`; asserting internal state via `(instance as any).privateField` |
| **Evaluation criteria** | Test accesses private properties (prefixed with `_` or `#`), casts to `any` to reach internal state, asserts on the order/number of internal function calls rather than the final output, or directly tests helper functions that are not part of the public API. Excludes testing internal utility functions that are explicitly exported for reuse. |

**Example:**

```typescript
// BAD — tests private implementation
test('formats correctly', () => {
  const formatter = new Formatter();
  expect((formatter as any)._internalBuffer).toEqual(['a', 'b']);
  expect((formatter as any)._stepCount).toBe(2);
});

// GOOD — tests public behavior
test('formats correctly', () => {
  const formatter = new Formatter();
  expect(formatter.format('a b')).toBe('A | B');
});
```

---

## 9. Snapshot Drift

Snapshot tests that have been updated many times without review, or snapshots so large they provide no meaningful regression detection. Large snapshots become cargo-culted — developers update them blindly.

**Detection method:** Analyze snapshot file sizes, update frequency in git history, and snapshot content complexity.

| Field | Value |
|-------|-------|
| **Severity** | medium |
| **Grep patterns** | Large inline snapshots: `toMatchInlineSnapshot\(\`[^\`]{500,}\``; `.snap` files exceeding reasonable size |
| **Evaluation criteria** | Inline snapshots longer than ~50 lines. Snapshot files that have been updated more than 5 times without manual review indicators (no `// REVIEW:` comment). Snapshots containing dynamic data (timestamps, IDs) that would require frequent updates. |

**Example:**

```typescript
// BAD — giant snapshot, no one reviews this
expect(component.html()).toMatchInlineSnapshot(`
  <div class="container" id="root-abc123">
    <header class="header" data-testid="header-xyz789">
      ... (200 more lines) ...
    </header>
  </div>
`);

// GOOD — targeted assertion on specific output
expect(component.html()).toContain('Welcome, Alice');
expect(component.find('[data-testid="user-name"]').text()).toBe('Alice');
```

---

## 10. Test-Only Code in Source

Production source files containing code that exists solely to support tests — such as methods exported only for testing, `__test__` hooks, or conditional logic gated by environment variables for test access.

**Detection method:** Scan source files (non-test) for patterns that expose internals for testing purposes.

| Field | Value |
|-------|-------|
| **Severity** | low |
| **Grep patterns** | `if\s*\(\s*process\.env\.NODE_ENV\s*===\s*['"]test['"]\)`, `/*\s*for\s+testing\s*/`, `//\s*@testonly`, `export\s+.*\s*for\s+testing`, `_test`, `__testAccess`, `_internal.*export` |
| **Evaluation criteria** | Source code with conditional blocks that only execute in test environment, exported internal functions annotated as test-only, or factory functions that bypass normal construction purely for test convenience. Excludes debug endpoints behind feature flags and development-only tools. |

**Example:**

```typescript
// BAD — test-only export in source
export function _resetInternalState() { // Only used by tests
  cache.clear();
  connectionPool.drain();
}

if (process.env.NODE_ENV === 'test') {
  module.exports.__getDB = () => db; // Exposes internal for testing
}

// GOOD — use dependency injection for testability
export function createService(db = createDB()) {
  return { process: (data) => db.save(data) };
}
// Tests inject a mock DB without modifying the source
```

---

## 11. Duplicate Test Logic

Multiple test cases that test the same scenario with slightly different syntax, or copy-pasted test blocks with minimal variation. This inflates test counts without increasing coverage.

**Detection method:** Compare test bodies within the same file for structural similarity, and check for overlapping test descriptions.

| Field | Value |
|-------|-------|
| **Severity** | low |
| **Grep patterns** | Near-identical `test()` or `it()` blocks detected via AST comparison; test descriptions that differ only in casing or punctuation |
| **Evaluation criteria** | Two or more test blocks in the same file with >80% structural similarity (same function calls, same assertions, same values) but different descriptions. Also flags parameterized tests with duplicate input rows. Excludes legitimately different edge cases that happen to share structure. |

**Example:**

```typescript
// BAD — duplicate tests
test('returns empty array when no items', () => {
  const result = filter([], x => x > 0);
  expect(result).toEqual([]);
});

test('handles empty list', () => {
  expect(filter([], x => x > 0)).toEqual([]);
});

// GOOD — one clear test, or parameterized
test.each([
  [[], []],
  [[1, -1, 2], [1, 2]],
  [[-1, -2], []],
])('filter(%p, positive) returns %p', (input, expected) => {
  expect(filter(input, x => x > 0)).toEqual(expected);
});
```

---

## 12. Flaky Indicators

Tests that use non-deterministic primitives: `Date.now()`, `Math.random()`, direct network calls in unit tests, file system operations without isolation, or reliance on system timezone/locale. These tests pass or fail unpredictably.

**Detection method:** Grep for non-deterministic API calls in unit test files and evaluate whether they are properly controlled (mocked, seeded, or isolated).

| Field | Value |
|-------|-------|
| **Severity** | high |
| **Grep patterns** | `Date\.now\(\)`, `new Date\(\)` (without mock), `Math\.random\(\)`, `fetch\(` in unit tests, `axios\.` in unit tests, `fs\.(readFile\|writeFile\|readdir)`, `process\.env\.[A-Z_]+` (without setup), `setTimeout\([^,]+,\s*\d{3,}\)` |
| **Evaluation criteria** | Flag in unit test files: unmocked `Date.now()` or `new Date()`, unmocked `Math.random()`, direct `fetch()`/`axios` calls (not mocked), filesystem reads/writes that depend on actual file state, `process.env` reads without `beforeEach` reset. Excludes E2E test files where real network calls are intentional and integration tests where filesystem operations are scoped to temp directories. |

**Example:**

```typescript
// BAD — uncontrolled time and randomness
test('generates unique ID', () => {
  const id = generateId(); // Uses Date.now() + Math.random()
  expect(id).toBeTruthy();
  // Different value each run, can't assert format
});

// GOOD — deterministic with mocks
test('generates unique ID', () => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2024-01-15'));
  const mockRandom = vi.spyOn(Math, 'random').mockReturnValue(0.5);
  
  expect(generateId()).toBe('20240115-0.5');
  
  vi.useRealTimers();
  mockRandom.mockRestore();
});
```

---

## Detection Strategy

The scan engine should apply these patterns in order of severity:

1. **critical** patterns first — these represent tests that provide zero or negative value
2. **high** patterns next — unreliable or misleading tests
3. **medium** patterns — quality degradation
4. **low** patterns last — style and maintainability

### Grep vs. Semantic Detection

| Detection Type | When to Use | Accuracy |
|----------------|-------------|----------|
| **Grep patterns** | Simple syntactic patterns (hardcoded secrets, sleep calls, empty catches) | High — low false-positive rate |
| **AST analysis** | Structural patterns (missing assertions, duplicate logic, tautological assertions) | Very high — parses code structure |
| **Semantic evaluation** | Context-dependent patterns (overly broad matchers, implementation coupling, snapshot drift) | Medium — requires understanding intent |

### Multi-Pattern Correlation

Some anti-patterns are more confidently detected when multiple signals are present. For example:
- A test with `Date.now()` AND no `vi.useFakeTimers()` or `jest.useFakeTimers()` is a stronger flaky signal than either alone
- A test with `expect(x).toBeTruthy()` where `x` is typed as `number` is a stronger broad-matcher signal than the matcher alone
- A test with `sleep()` AND no assertion after the sleep is both a sleep-based-wait AND potentially a missing-assertion

The scan report's `antiPatterns` array should include the primary pattern and optionally note correlated patterns in the `description` field.

---

## 13. Mystery Guest

Tests that depend on external state not set up within the test — database records, files on disk, API responses from external services. The test passes in one environment but fails in another because it relies on pre-existing data that may not exist elsewhere.

**Detection method:** Identify tests that reference specific database IDs, file paths without corresponding setup, or external URLs without mocking. These tests assume a particular environment state.

| Field | Value |
|-------|-------|
| **Severity** | high |
| **Grep patterns** | Hardcoded database IDs: `id:\s*\d{2,}`, `user_id:\s*\d+`; file paths without setup: `fs\.readFileSync\(['"]/(?!tmp|var|__tests__|mock)`, external URLs without mock: `fetch\(['"]https?://(?!mock|localhost)` |
| **Evaluation criteria** | A test that queries or references a specific record ID (e.g., `user.id === 42`), reads a file without creating it in `beforeEach`, or calls an external API without intercepting the request. Excludes tests that create their own fixtures in `beforeEach`/`beforeAll` and tests using mock service workers or similar tools. |

**Example:**

```typescript
// BAD — relies on database record that may not exist
test('fetches user profile', async () => {
  const user = await getUserById(42); // Assumes user 42 exists in DB
  expect(user.name).toBe('Alice');
});

// GOOD — sets up required data within the test
test('fetches user profile', async () => {
  const created = await createUser({ name: 'Alice', email: 'alice@test.com' });
  const user = await getUserById(created.id);
  expect(user.name).toBe('Alice');
});
```

---

## 14. Hardcoded Test Data

Test data scattered inline throughout tests instead of centralized in factories or fixtures. When the schema changes, developers must update the same literal values across dozens of test files.

**Detection method:** Detect repeated inline object literals with the same property structure across tests, and tests that use literal values without referencing a shared factory or fixture.

| Field | Value |
|-------|
| **Severity** | medium |
| **Grep patterns** | Repeated literal objects: `const\s+\w+\s*=\s*\{[^}]*name:\s*['"]`, `age:\s*\d+,\s*email:\s*['"]`; same literal values appearing in 3+ test blocks within a file |
| **Evaluation criteria** | Three or more test blocks in the same file contain inline object literals with overlapping property sets (same keys, different or same values). The test file has no factory functions, fixture imports, or `build()` helpers for the repeated type. Excludes parameterized tests where each row represents a distinct edge case. |

**Example:**

```typescript
// BAD — inline data repeated in every test
test('validates user name', () => {
  const user = { name: 'Alice', age: 30, email: 'alice@test.com', role: 'admin' };
  expect(validateName(user)).toBe(true);
});

test('validates user email', () => {
  const user = { name: 'Alice', age: 30, email: 'alice@test.com', role: 'admin' };
  expect(validateEmail(user)).toBe(true);
});

test('formats user display', () => {
  const user = { name: 'Alice', age: 30, email: 'alice@test.com', role: 'admin' };
  expect(formatDisplay(user)).toBe('Alice (admin)');
});

// GOOD — centralized factory
function createUser(overrides: Partial<User> = {}): User {
  return { name: 'Alice', age: 30, email: 'alice@test.com', role: 'admin', ...overrides };
}

test('validates user name', () => {
  expect(validateName(createUser())).toBe(true);
});

test('rejects empty name', () => {
  expect(validateName(createUser({ name: '' }))).toBe(false);
});

test('formats user display', () => {
  expect(formatDisplay(createUser())).toBe('Alice (admin)');
});
```

---

## 15. Mock Overuse

Tests that mock so extensively — including the module under test — that they verify mock configuration rather than actual behavior. If you remove the real code entirely, the tests still pass. These tests provide false confidence because they never exercise the production code path.

**Detection method:** Count mock declarations relative to assertions and detect when the file being tested is itself mocked.

| Field | Value |
|-------|-------|
| **Severity** | high |
| **Grep patterns** | High mock-to-assertion ratio: more `vi.mock()`/`jest.mock()` calls than `expect()` calls; mocking the file under test: `vi\.mock\(['"].*utils['"]\)` where the test file is `utils.test.ts`; `vi\.spyOn` on functions defined in the same file |
| **Evaluation criteria** | The test file contains more `vi.mock`/`jest.mock`/`mock()` declarations than `expect()` assertions. Or the test mocks the very module it is meant to test. Or every dependency is mocked, leaving no real code executing. Excludes legitimate mocking of external APIs, databases, or file system where the mock substitutes for unavailable infrastructure. |

**Example:**

```typescript
// BAD — mocks the function under test, test always passes
vi.mock('./pricing', () => ({
  calculatePrice: vi.fn().mockReturnValue(29.99),
}));

test('calculatePrice returns correct value', () => {
  expect(calculatePrice(cart)).toBe(29.99); // This tests the mock, not the code
});

// GOOD — mock only external dependencies, test real code
vi.mock('./database', () => ({
  getProducts: vi.fn().mockResolvedValue([{ id: 1, price: 19.99 }, { id: 2, price: 10.00 }]),
}));

test('calculatePrice sums product prices', async () => {
  const cart = await buildCart('user-1'); // Uses mocked DB
  expect(calculatePrice(cart)).toBe(29.99); // Tests real calculation logic
});
```

---

## 16. Assertion Roulette

Multiple assertions in a test without clear indication of which one failed. This is not about having multiple assertions per test (which is perfectly valid) — the problem is assertions that fail with unhelpful error messages like "expected 2 received 3" with no context about which business rule was violated.

**Detection method:** Detect long chains of `expect` calls where none use the custom message parameter, and where the test name is too generic to identify the failure point.

| Field | Value |
|-------|-------|
| **Severity** | medium |
| **Grep patterns** | Five or more consecutive `expect()` calls in a test block without custom message parameters; `expect\([^)]+\)\.toBe\([^)]+\)` chains with no `describe` context separating concerns |
| **Evaluation criteria** | A single test block with 5+ assertions where none use the custom message parameter (e.g., `expect(a, 'price should match').toBe(10)`). Or a `describe` block with a single test containing unrelated assertions that could be split into named tests. Excludes assertions on different properties of the same returned object where the test name clearly describes what is being validated. |

**Example:**

```typescript
// BAD — which assertion failed? Good luck finding out
test('user profile is correct', () => {
  const profile = getProfile('user-1');
  expect(profile.name).toBe('Alice');
  expect(profile.age).toBe(30);
  expect(profile.email).toBe('alice@test.com');
  expect(profile.role).toBe('admin');
  expect(profile.active).toBe(true);
  // Error: "expected 'editor' to be 'admin'" — no clue which field or why
});

// GOOD — descriptive messages or separate tests
test('user profile has correct name and role', () => {
  const profile = getProfile('user-1');
  expect(profile.name, 'profile name should match user input').toBe('Alice');
  expect(profile.role, 'default role for new users should be admin').toBe('admin');
});

test('user profile has correct contact info', () => {
  const profile = getProfile('user-1');
  expect(profile.email).toBe('alice@test.com');
  expect(profile.age).toBe(30);
});
```

---

## 17. Happy Path Only

Tests that exclusively verify the successful execution path and never test error handling, edge cases, or invalid inputs. This gives false confidence — the code works for perfect inputs but may catastrophically fail on anything unexpected.

**Detection method:** Scan test names and assertion patterns to identify suites where every test describes a positive outcome and none test failure modes, boundary conditions, or invalid inputs.

| Field | Value |
|-------|-------|
| **Severity** | high |
| **Grep patterns** | Test names with only positive words: `test\(['"](?:works|succeeds|returns|valid|correct|passes|creates|updates|deletes)` and no test names with negative/error words: `error|fail|invalid|empty|null|undefined|throws|reject|missing|boundary|edge|limit|overflow|malformed` |
| **Evaluation criteria** | A test file where 100% of test names describe positive/success scenarios. No tests for: error responses, null/undefined inputs, empty strings, out-of-range values, duplicate entries, unauthorized access, or network failures. Excludes utility function tests where the function is explicitly designed to only handle valid inputs and throw on invalid ones (but only if the throw behavior itself is tested). |

**Example:**

```typescript
// BAD — only tests success cases
describe('createUser', () => {
  test('works with valid input', () => { /* ... */ });
  test('returns the created user', () => { /* ... */ });
  test('sends welcome email', () => { /* ... */ });
  // What about duplicate email? Empty name? Null fields? Too long name?
});

// GOOD — covers error paths and edge cases
describe('createUser', () => {
  test('creates user with valid input', () => { /* ... */ });
  test('throws on duplicate email', () => { /* ... */ });
  test('throws on empty name', () => { /* ... */ });
  test('truncates name exceeding 255 chars', () => { /* ... */ });
  test('handles null fields by applying defaults', () => { /* ... */ });
  test('handles database connection failure', () => { /* ... */ });
});
```

---

## 18. Fragile Selectors

Tests that depend on CSS selectors, DOM structure, or implementation-specific query patterns that break on any UI change. A designer changing a class name or restructuring HTML causes tests to fail even though user behavior is unchanged.

**Detection method:** Detect DOM queries that use fragile selectors (CSS classes, tag structure, text content) instead of resilient selectors (`data-testid`, ARIA roles, accessible names).

| Field | Value |
|-------|-------|
| **Severity** | medium |
| **Grep patterns** | `querySelector\(['"][.#]`, `getElementsByClassName`, `document\.getElementById` in test files; `screen\.getByText\(['"][^']{20,}` (long exact text matches); absence of `data-testid` or `getByRole` in component test files |
| **Evaluation criteria** | Component or E2E tests that query the DOM using CSS class selectors (`.btn-primary`), tag structure (`div > span > button`), or exact text content that is likely to change. No usage of `data-testid`, `getByRole`, `getByLabelText`, or `getByPlaceholderText` in the test file. Excludes tests for CSS-specific behavior where class names are the actual test target. |

**Example:**

```typescript
// BAD — breaks when button text or class changes
test('submits form', () => {
  render(<ContactForm />);
  fireEvent.click(screen.getByText('Submit Your Request'));
  // Also fragile:
  // container.querySelector('.btn-primary.btn-lg.submit-action')
});

// GOOD — resilient selectors
test('submits form', () => {
  render(<ContactForm />);
  fireEvent.click(screen.getByRole('button', { name: /submit/i }));
  // Or with data-testid:
  fireEvent.click(screen.getByTestId('submit-button'));
});
```

---

## 19. Complex Test Logic

Tests that contain loops, conditionals, or complex computation within the test body. Tests should be simple and declarative — if you need iteration or branching, use parameterized tests (`test.each`/`it.each`). Complex logic in tests can itself contain bugs that mask failures in the code under test.

**Detection method:** Detect `for`/`while`/`if` statements inside test bodies, computed test arrays, and nested function calls within assertions.

| Field | Value |
|-------|-------|
| **Severity** | medium |
| **Grep patterns** | `for\s*\(`, `while\s*\(`, `if\s*\(` inside test/it blocks (not in helpers); `test\.each\(\[[\s\S]*?\+` (computed arrays); nested ternary or function calls in `expect()` arguments |
| **Evaluation criteria** | A test body containing `for`, `while`, or `if` statements (excluding those inside helper functions called by the test). Or a `test.each` with a computed array (e.g., generated from a range or filter operation) instead of a static literal array. Or assertions that compute expected values using the same logic as the code under test. Excludes simple `Array.forEach` used for setup/teardown and `test.each` with static inline data. |

**Example:**

```typescript
// BAD — loop with conditional in test body, logic could be buggy
test('filters active users', () => {
  const users = getAllUsers();
  for (const user of users) {
    if (user.active && user.role !== 'guest') {
      expect(isEligible(user)).toBe(true);
    } else {
      expect(isEligible(user)).toBe(false);
    }
  }
});

// GOOD — declarative parameterized tests
test.each([
  { active: true, role: 'admin', expected: true },
  { active: true, role: 'guest', expected: false },
  { active: false, role: 'admin', expected: false },
  { active: false, role: 'guest', expected: false },
])('isEligible($active, $role) = $expected', ({ active, role, expected }) => {
  expect(isEligible({ active, role })).toBe(expected);
});
```

---

## 20. Missing Cleanup

Tests that create persistent state — file system artifacts, database records, server listeners, fake timers — without cleaning up in `afterEach`/`afterAll`. Leaks compound across test runs, causing mysterious failures in unrelated tests that run later.

**Detection method:** Detect `beforeAll`/`beforeEach` blocks without corresponding `afterAll`/`afterEach`, unpaired fake timer activation, server listen without close, and file writes without cleanup.

| Field | Value |
|-------|-------|
| **Severity** | high |
| **Grep patterns** | `beforeAll\(` without matching `afterAll\(` in same describe; `beforeEach\(` without `afterEach\(`; `vi\.useFakeTimers\(\)` without `vi\.useRealTimers\(\)`; `\.listen\(` without `\.close\(`; `fs\.\w+Sync\(` in `beforeEach` without `fs\.unlinkSync\(` or `fs\.rmSync\(` in `afterEach` |
| **Evaluation criteria** | A `beforeAll` or `beforeEach` block that sets up state without a corresponding `afterAll`/`afterEach` that tears it down. Specifically: `vi.useFakeTimers()` without `vi.useRealTimers()`, server `.listen()` without `.close()`, file creation without deletion, temporary directory creation without removal, event listener addition without removal. Excludes `beforeEach` blocks that only reassign local variables (no persistent side effects). |

**Example:**

```typescript
// BAD — no cleanup, fake timers leak into other tests
describe('scheduler', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    server = createServer();
    server.listen(3000);
    fs.mkdirSync('/tmp/test-uploads');
  });
  // No afterEach — timers leak, port stays bound, directory persists
});

// GOOD — proper cleanup for every setup
describe('scheduler', () => {
  let server: Server;

  beforeEach(() => {
    vi.useFakeTimers();
    server = createServer();
    server.listen(3000);
    fs.mkdirSync('/tmp/test-uploads', { recursive: true });
  });

  afterEach(() => {
    vi.useRealTimers();
    server.close();
    fs.rmSync('/tmp/test-uploads', { recursive: true, force: true });
  });
});
```

---

## Detection Strategy

The scan engine should apply these patterns in order of severity:

1. **critical** patterns first — these represent tests that provide zero or negative value
2. **high** patterns next — unreliable or misleading tests
3. **medium** patterns — quality degradation
4. **low** patterns last — style and maintainability

Categories 1–12 are the original catalog. Categories 13–20 were added to provide comprehensive coverage of test smells required for AI-generated test quality auditing (per R012).

### Grep vs. Semantic Detection

| Detection Type | When to Use | Accuracy |
|----------------|-------------|----------|
| **Grep patterns** | Simple syntactic patterns (hardcoded secrets, sleep calls, empty catches) | High — low false-positive rate |
| **AST analysis** | Structural patterns (missing assertions, duplicate logic, tautological assertions) | Very high — parses code structure |
| **Semantic evaluation** | Context-dependent patterns (overly broad matchers, implementation coupling, snapshot drift) | Medium — requires understanding intent |

### Multi-Pattern Correlation

Some anti-patterns are more confidently detected when multiple signals are present. For example:
- A test with `Date.now()` AND no `vi.useFakeTimers()` or `jest.useFakeTimers()` is a stronger flaky signal than either alone
- A test with `expect(x).toBeTruthy()` where `x` is typed as `number` is a stronger broad-matcher signal than the matcher alone
- A test with `sleep()` AND no assertion after the sleep is both a sleep-based-wait AND potentially a missing-assertion
- A test with hardcoded IDs AND no setup in `beforeEach` is both a mystery-guest AND potentially a test-interdependency
- A test with `beforeEach` creating resources AND no `afterEach` cleanup is both missing-cleanup AND potentially causing flaky-indicators in downstream tests

The scan report's `antiPatterns` array should include the primary pattern and optionally note correlated patterns in the `description` field.

---

## Cross-Reference

These anti-pattern definitions are consumed by:
- **Scan report** (`references/scan-report-schema.md`) — `antiPatterns` array fields
- **Scan spoke** (`references/spoke-scan.md`) — Step 4 (Analyze Test Quality)
- **Generate spoke** (`references/spoke-generate.md`) — Phase 7 quality audit uses these categories to evaluate generated tests and ensure they score ≥ `quality_threshold × 100` (default 70) on the quality rubric
- **AI Generation Guide** (`references/ai-generation-guide.md`) — References anti-pattern categories in the quality scoring rubric
