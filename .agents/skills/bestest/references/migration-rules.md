# Migration Rules Reference

Complete transformation rule catalog for bestest's `migrate` command. Covers three supported migration paths with AST-aware transformation rules, config field mapping, known incompatibilities, and general migration principles.

This reference is consumed by `references/spoke-migrate.md` during Phase 3 (Context7 Fetch) and Phase 4 (Transform). Static rules here are merged with live Context7 documentation, with live docs overriding for version-specific API changes.

---

## Jest → Vitest: Import Replacements

| Jest Import | Vitest Replacement | Notes |
|-------------|-------------------|-------|
| `import { jest } from '@jest/globals'` | (remove — `vi` is global) | Vitest provides `vi` as a global in config |
| `jest` (global) | `vi` | All `jest.*` calls become `vi.*` |
| `@jest/globals` | `vitest` | Only if explicit imports are used |
| `import { describe, it, expect, beforeEach } from '@jest/globals'` | `import { describe, it, expect, beforeEach } from 'vitest'` | Test lifecycle imports change source |
| `require('@jest/globals')` | `import { ... } from 'vitest'` | CJS → ESM conversion recommended |

**Transformation rule:** Scan for `from '@jest/globals'` and `from 'jest'` imports. Replace source with `'vitest'`. Convert `jest` global references to `vi`.

## Jest → Vitest: Mock API Mapping

| Jest API | Vitest Equivalent | Behavioral Differences |
|----------|-------------------|----------------------|
| `jest.fn()` | `vi.fn()` | Identical API |
| `jest.fn(impl)` | `vi.fn(impl)` | Identical API |
| `jest.spyOn(obj, method)` | `vi.spyOn(obj, method)` | Identical API |
| `jest.mock('module')` | `vi.mock('module')` | Factory signature identical |
| `jest.mock('module', factory)` | `vi.mock('module', factory)` | Identical API |
| `jest.doMock('module')` | `vi.mock('module')` | Vitest hoists all mocks — `doMock` distinction unnecessary |
| `jest.unmock('module')` | `vi.unmock('module')` | Identical API |
| `jest.createMockFromModule('module')` | `vi.mock('module')` or manual mock | Vitest auto-hoists; complex cases need manual factory |
| `jest.setMock('module', value)` | `vi.mock('module', () => value)` | Use factory form instead |
| `jest.useFakeTimers()` | `vi.useFakeTimers()` | Identical API |
| `jest.useRealTimers()` | `vi.useRealTimers()` | Identical API |
| `jest.advanceTimersByTime(ms)` | `vi.advanceTimersByTime(ms)` | Identical API |
| `jest.runAllTimers()` | `vi.runAllTimers()` | Identical API |
| `jest.runOnlyPendingTimers()` | `vi.runOnlyPendingTimers()` | Identical API |
| `jest.clearAllMocks()` | `vi.clearAllMocks()` | Identical API |
| `jest.resetAllMocks()` | `vi.resetAllMocks()` | Identical API |
| `jest.restoreAllMocks()` | `vi.restoreAllMocks()` | Identical API |
| `jest.clearAllTimers()` | `vi.clearAllTimers()` | Identical API |
| `jest.mocked(fn)` | `vi.mocked(fn)` | Identical API |
| `jest.replaceProperty(obj, key, value)` | `vi.spyOn(obj, key, 'get').mockReturnValue(value)` | No direct equivalent — use spy approach |
| `jest.setTimeout(ms)` | `vitest.setConfig({ testTimeout: ms })` | Config-level change |

## Jest → Vitest: Config Field Mapping

| Jest Config Field | Vitest Config Field | Transformation Notes |
|-------------------|--------------------|--------------------|
| `module.exports = { ... }` (jest.config.js) | `export default defineConfig({ test: { ... } })` (vitest.config.ts) | Wrap all fields inside `test: {}` block |
| `transform: { '^.+\\.tsx?$': 'ts-jest' }` | (remove — Vitest transforms TypeScript natively) | Delete entire `transform` field |
| `moduleNameMapper: { '^@/(.*)$': '<rootDir>/src/$1' }` | `resolve: { alias: { '@/': './src/' } }` | Move inside `resolve.alias`; adjust path format (trailing slash) |
| `testEnvironment: 'jsdom'` | `environment: 'jsdom'` | Field name change only |
| `testEnvironment: 'node'` | `environment: 'node'` | Field name change only |
| `setupFiles: ['./jest.setup.ts']` | `setupFiles: ['./vitest.setup.ts']` | Rename file; field name same |
| `setupFilesAfterFramework: [...]` | `setupFiles: [...]` | Merge into `setupFiles` |
| `testMatch: ['**/*.test.ts']` | `include: ['**/*.test.ts']` | Field name change |
| `testPathIgnorePatterns: ['/node_modules/']` | `exclude: ['**/node_modules/**']` | Field name change; use glob patterns |
| `collectCoverageFrom: ['src/**/*.ts']` | `coverage: { include: ['src/**/*.ts'] }` | Nest inside `coverage` block |
| `coverageDirectory: './coverage'` | `coverage: { reportsDirectory: './coverage' }` | Nest inside `coverage` block |
| `coveragePathIgnorePatterns: ['/node_modules/']` | `coverage: { exclude: ['**/node_modules/**'] }` | Nest inside `coverage` block |
| `coverageReporters: ['text', 'html']` | `coverage: { reporter: ['text', 'html'] }` | Nest inside `coverage` block |
| `coverageThreshold: { global: { branches: 80 } }` | `coverage: { thresholds: { branches: 80 } }` | Nest inside `coverage.thresholds` |
| `transformIgnorePatterns: ['node_modules/(?!(some-pkg)/)']` | (remove — Vitest handles ESM/CJS interop natively) | Delete entire field |
| `globals: { 'ts-jest': { ... } }` | (remove — not needed with Vitest) | Delete entire field |
| `verbose: true` | `reporters: ['verbose']` | Use reporter configuration |
| `testTimeout: 5000` | `testTimeout: 5000` | Same field name inside `test` block |
| `bail: 1` | `bail: 1` | Same field name inside `test` block |
| `maxWorkers: 4` | `pool: 'threads', poolOptions: { threads: { maxThreads: 4 } }` | Restructured worker config |

## Jest → Vitest: Snapshot Compatibility

- **Vitest reads Jest snapshots natively** — no snapshot migration required
- Snapshot format is compatible; `toMatchSnapshot()` works identically
- `toMatchInlineSnapshot()` has minor formatting differences — review automatically
- Property matchers syntax (`toMatchSnapshot({}, 'name')`) is compatible
- Custom snapshot serializers from Jest need Vitest equivalents (flag for manual review)

## Jest → Vitest: Known Incompatibilities & Manual Review

Flag these patterns for manual review — they cannot be safely auto-transformed:

| Pattern | Why Manual Review Needed | Suggested Resolution |
|---------|------------------------|---------------------|
| `__mocks__/` directory auto-loading | Vitest does not auto-load `__mocks__` directories | Convert to `vi.mock()` calls or use `vitest.config.ts` `alias` + manual mock setup |
| Custom Jest transformers (babel-jest, ts-jest custom config) | Vitest uses Vite transform pipeline | Replace with Vite plugins or remove if native TS support suffices |
| Jasmine globals (`jasmine.DEFAULT_TIMEOUT_INTERVAL`, `jasmine.createSpy`) | Not available in Vitest | Replace with `vi` equivalents; set timeout via config |
| `jest-community` plugins (`jest-extended`, `jest-dom`) | May have Vitest equivalents or need adapter | Check for Vitest-compatible versions; install `@vitest/expect` for extensions |
| `jest.retryTimes(n)` | Different API in Vitest | Use `vitest.setConfig({ retry: n })` or `test('name', { retry: n }, fn)` |
| `jest.each` / `describe.each` with template literals | Syntax differences possible | Verify `it.each` and `describe.each` work identically — usually do |
| `jest.setTimeout` at test level | Vitest uses `test('name', { timeout: ms }, fn)` | Convert to per-test or config-level timeout |
| Custom jest reporters | Vitest reporter API differs | Rewrite using Vitest reporter interface |
| `jest.inTest` / `jest.isolateModules` | Partial Vitest support | Check Vitest version; `vi.resetModules()` covers most cases |
| `expect.extends` custom matchers | Different registration API | Use `expect.extend()` from Vitest — same API but check compatibility |
| `jest.requireActual` inside `jest.mock` factory | Hoisting differences | Use `vi.importActual` — works but verify factory execution order |
| Global setup/teardown (`globalSetup`, `globalTeardown`) | Vitest uses `globalSetup`/`globalTeardown` with different export signature | Convert to named exports: `export default function setup() {}` → `export function setup() {}` |

## Jest → Vitest: Complexity Classification

| Complexity | Criteria | Risk |
|-----------|----------|------|
| **Simple** | Basic assertions only (`expect`, `toBe`, `toEqual`), no mocks, no lifecycle hooks, no config changes | Low — straightforward `jest` → `vi` replacement |
| **Moderate** | Mocks (`jest.fn`, `jest.spyOn`, `jest.mock`), `beforeEach`/`afterEach` hooks, timers, snapshot assertions | Medium — import + mock API changes, config migration needed |
| **Complex** | Custom matchers, `__mocks__` directories, custom transformers, Jasmine globals, custom reporters, `jest.each` with complex templates, plugin dependencies | High — requires manual review for each incompatible pattern |

---

## JUnit 4 → JUnit 5: Annotation Mapping

| JUnit 4 Annotation | JUnit 5 Equivalent | Transformation Notes |
|---------------------|-------------------|---------------------|
| `@org.junit.Test` | `@org.junit.jupiter.api.Test` | Package change — critical to get right |
| `@org.junit.Before` | `@org.junit.jupiter.api.BeforeEach` | Rename + package change |
| `@org.junit.After` | `@org.junit.jupiter.api.AfterEach` | Rename + package change |
| `@org.junit.BeforeClass` | `@org.junit.jupiter.api.BeforeAll` | Rename + package change; method must be `static` (already was in JUnit 4, but verify) |
| `@org.junit.AfterClass` | `@org.junit.jupiter.api.AfterAll` | Rename + package change; method must be `static` |
| `@org.junit.Ignore` | `@org.junit.jupiter.api.Disabled` | Rename + package change |
| `@org.junit.Ignore("reason")` | `@org.junit.jupiter.api.Disabled("reason")` | Parameter preserved |
| `@org.junit.runner.RunWith(CustomRunner.class)` | `@org.junit.jupiter.api.extension.ExtendWith(CustomExtension.class)` | Runner → Extension pattern; may require custom extension adapter |
| `@org.junit.rules.Rule` | `@org.junit.jupiter.api.extension.ExtendWith(...)` or `@org.junit.jupiter.api.io.TempDir` | Rules require individual migration strategies (see below) |
| `@org.junit.rules.ClassRule` | `@org.junit.jupiter.api.extension.ExtendWith(...)` or static field with `@RegisterExtension` | Same as `@Rule` but for class-level |
| `@org.junit.runners.Parameterized` (class-level) | `@org.junit.jupiter.params.ParameterizedTest` + `@org.junit.jupiter.params.provider.MethodSource` | Structural transformation — see Section 2.5 |
| `@org.junit.runners.Parameterized.Parameters` | `@org.junit.jupiter.params.provider.MethodSource("methodName")` | Method returns `Stream<Arguments>` or `Collection` |
| `@org.junit.experimental.theories.Theory` | `@org.junit.jupiter.params.ParameterizedTest` + `@org.junit.jupiter.params.provider.MethodSource` or `@CsvSource` | Theories → parameterized tests |
| `@org.junit.experimental.theories.DataPoint` | `@org.junit.jupiter.params.provider.MethodSource` source method | Consolidate data points into provider method |

## JUnit 4 → JUnit 5: Assertion Parameter Reordering

JUnit 4 assertions use `(message, expected, actual)` parameter order. JUnit 5 swaps message to last position: `(expected, actual, message)`.

| JUnit 4 Signature | JUnit 5 Signature | Transformation Rule |
|-------------------|-------------------|-------------------|
| `assertEquals(message, expected, actual)` | `assertEquals(expected, actual, message)` | Swap first and last parameters |
| `assertEquals(expected, actual)` | `assertEquals(expected, actual)` | No change needed |
| `assertNull(message, object)` | `assertNull(object, message)` | Swap parameters |
| `assertNull(object)` | `assertNull(object)` | No change needed |
| `assertNotNull(message, object)` | `assertNotNull(object, message)` | Swap parameters |
| `assertTrue(message, condition)` | `assertTrue(condition, message)` | Swap parameters |
| `assertTrue(condition)` | `assertTrue(condition)` | No change needed |
| `assertFalse(message, condition)` | `assertFalse(condition, message)` | Swap parameters |
| `assertSame(message, expected, actual)` | `assertSame(expected, actual, message)` | Swap first and last |
| `assertArrayEquals(message, expected, actual)` | `assertArrayEquals(expected, actual, message)` | Swap first and last |
| `assertThat(message, actual, matcher)` | Use AssertJ: `assertThat(actual).is(matcher)` or `assertThat(actual, matcher)` | Consider AssertJ migration |
| `fail(message)` | `fail(message)` | No change needed |

**Detection heuristic for 3-arg vs 2-arg:**
- If first argument is a `String` literal and not assignable to the expected type → it's a message parameter (3-arg form)
- If first argument type matches expected type → it's the 2-arg form (no message)
- For `assertEquals(String, String, String)` — ambiguous; analyze whether test uses `assertEquals(msg, expected, actual)` pattern (common in JUnit 4) vs `assertEquals(expected, actual, msg)` pattern (JUnit 5)
- Default assumption: JUnit 4 pattern `(message, expected, actual)` when 3 string args present

## JUnit 4 → JUnit 5: Exception & Timeout Transformation

| JUnit 4 Pattern | JUnit 5 Pattern | Transformation |
|-----------------|----------------|---------------|
| `@Test(expected = SomeException.class)` | `assertThrows(SomeException.class, () -> { /* body */ })` | Wrap test body in lambda for `assertThrows`; remove `expected` from `@Test` |
| `@Test(expected = SomeException.class)` with single-line body | `assertThrows(SomeException.class, () -> obj.method())` | Direct lambda wrapping |
| `@Rule ExpectedException` | `assertThrows(SomeException.class, () -> { ... })` | Replace `ExpectedException.expect()` chain with `assertThrows` lambda |
| Try-catch with `fail()` | `assertThrows(SomeException.class, () -> { ... })` | Remove manual try-catch-fail pattern |

### 2.4 Timeout Transformation

| JUnit 4 Pattern | JUnit 5 Pattern | Transformation |
|-----------------|----------------|---------------|
| `@Test(timeout = 1000)` | `assertTimeout(Duration.ofMillis(1000), () -> { /* body */ })` | Remove `timeout` from `@Test`; wrap body in `assertTimeout` |
| `@Test(timeout = 5000)` | `assertTimeout(Duration.ofMillis(5000), () -> { ... })` | Convert ms to `Duration` |
| `@Test(timeout = 1000, expected = X.class)` | `assertTimeout(Duration.ofMillis(1000), () -> assertThrows(X.class, () -> { ... }))` | Nest both wrappers |

## JUnit 4 → JUnit 5: Parameterized & Rule Migration

JUnit 4's `@RunWith(Parameterized.class)` + `@Parameters` pattern transforms to JUnit 5's `@ParameterizedTest` + `@MethodSource`:

```java
// JUnit 4
@RunWith(Parameterized.class)
public class CsvParserTest {
    @Parameterized.Parameters(name = "{index}: {0}")
    public static Collection<Object[]> data() {
        return Arrays.asList(new Object[][] {
            { "input1", "expected1" },
            { "input2", "expected2" }
        });
    }

    private String input;
    private String expected;

    public CsvParserTest(String input, String expected) {
        this.input = input;
        this.expected = expected;
    }

    @Test
    public void testParse() {
        assertEquals(expected, parse(input));
    }
}

// JUnit 5
class CsvParserTest {
    @ParameterizedTest(name = "{index}: {0}")
    @MethodSource("data")
    void testParse(String input, String expected) {
        assertEquals(expected, parse(input));
    }

    static Stream<Arguments> data() {
        return Stream.of(
            arguments("input1", "expected1"),
            arguments("input2", "expected2")
        );
    }
}
```

**Key changes:**
1. Remove `@RunWith(Parameterized.class)` from class
2. Change `@Test` to `@ParameterizedTest` on the test method
3. Add `@MethodSource("methodName")` pointing to the data method
4. Convert `@Parameters` method return type from `Collection<Object[]>` to `Stream<Arguments>`
5. Replace constructor parameter injection with method parameters
6. Remove constructor and instance fields used for parameter injection
7. Import `org.junit.jupiter.params.ParameterizedTest`, `org.junit.jupiter.params.provider.MethodSource`, `org.junit.jupiter.params.provider.Arguments`

## JUnit 4 → JUnit 5: Rule Migration Strategies

JUnit 4 `@Rule` and `@ClassRule` require individual migration based on the rule type:

| JUnit 4 Rule | JUnit 5 Migration Strategy |
|---------------|---------------------------|
| `TemporaryFolder` | `@TempDir` annotation from `org.junit.jupiter.api.io` |
| `ExpectedException` | `assertThrows()` as described in Section 2.3 |
| `ExternalResource` | `@BeforeEach`/`@AfterEach` or `@ExtendWith` custom extension |
| `Verifier` | `@AfterEach` assertion or custom extension |
| `TestWatcher` | `@ExtendWith(TestWatcherExtension.class)` custom extension |
| `ErrorCollector` | `assertAll()` or custom extension with `checkAndThrow()` |
| `Timeout` | `assertTimeout()` as described in Section 2.4 |
| Custom rules | `@ExtendWith` with custom `BeforeTestExecutionCallback`/`AfterTestExecutionCallback` |

## JUnit 4 → JUnit 5: Visibility, Vintage Engine & Build Config

JUnit 5 allows package-private test methods (no `public` required):
- `public void testMethod()` → `void testMethod()` (optional — `public` still works)
- `public class TestClass` → `class TestClass` (optional)
- **Never remove `public` from `@BeforeAll`/`@AfterAll` methods** — they must remain `public` or be package-private with `static`

**Recommendation:** Flag `public` removal as optional cleanup. Do not force it — it's cosmetic and risks breaking code that uses reflection-based tools.

### Gradual Migration with JUnit Vintage Engine

For large codebases, the JUnit Vintage Engine allows JUnit 4 and JUnit 5 tests to coexist:

```xml
<!-- Maven -->
<dependency>
    <groupId>org.junit.vintage</groupId>
    <artifactId>junit-vintage-engine</artifactId>
    <scope>test</scope>
</dependency>
```

```groovy
// Gradle
testImplementation("org.junit.vintage:junit-vintage-engine")
```

**Strategy:**
1. Add JUnit Vintage Engine dependency (allows running JUnit 4 tests on JUnit 5 platform)
2. Add JUnit Jupiter dependencies
3. Migrate files incrementally — JUnit 4 and JUnit 5 tests run side-by-side
4. Remove Vintage Engine once all tests are migrated

### Build Configuration Changes

**Gradle:**
```groovy
// Before (JUnit 4)
testImplementation("junit:junit:4.13.2")

// After (JUnit 5)
testImplementation("org.junit.jupiter:junit-jupiter-api:5.10.2")
testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:5.10.2")
testImplementation("org.junit.jupiter:junit-jupiter-params:5.10.2") // for @ParameterizedTest
test {
    useJUnitPlatform() // REQUIRED — enables JUnit 5 test discovery
}
```

**Maven:**
```xml
<!-- Before (JUnit 4) -->
<dependency>
    <groupId>junit</groupId>
    <artifactId>junit</artifactId>
    <version>4.13.2</version>
    <scope>test</scope>
</dependency>

<!-- After (JUnit 5) -->
<dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter-api</artifactId>
    <version>5.10.2</version>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter-engine</artifactId>
    <version>5.10.2</version>
    <scope>test</scope>
</dependency>
<!-- Surefire plugin MUST use JUnit Platform -->
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-surefire-plugin</artifactId>
    <version>3.2.5</version>
</plugin>
```

## JUnit 4 → JUnit 5: Complexity Classification

| Complexity | Criteria | Risk |
|-----------|----------|------|
| **Simple** | Basic `@Test` methods with `assertEquals`/`assertTrue`, no `@Rule`, no parameterized tests, no `expected`/`timeout` attributes | Low — annotation import changes + optional assertion reorder |
| **Moderate** | `@Before`/`@After` lifecycle hooks, `@Ignore`, `assertThat` with Hamcrest, `@RunWith` with standard runners (`Suite`, `Parameterized`), `@Test(expected=...)` | Medium — annotation rename + exception test restructuring + assertion reorder |
| **Complex** | `@Rule`/`@ClassRule` (especially custom rules), `@RunWith` with custom runners, `ExpectedException`, `ErrorCollector`, custom test watchers, `Assume` usage, Theories | High — requires individual rule migration strategy; may need custom extension authoring |

---

## Cypress → Playwright: Command Mapping

| Cypress Command | Playwright Equivalent | Transformation Notes |
|----------------|---------------------|---------------------|
| `cy.visit(url)` | `await page.goto(url)` | `await` required; returns response |
| `cy.get(selector)` | `page.locator(selector)` | Returns locator (lazy) — chain `.first()` if needed |
| `cy.get('.item').first()` | `page.locator('.item').first()` | Identical chain pattern |
| `cy.get('.item').eq(n)` | `page.locator('.item').nth(n)` | `.eq()` → `.nth()` |
| `cy.contains('text')` | `page.getByText('text')` | Direct mapping |
| `cy.contains('selector', 'text')` | `page.locator('selector').filter({ hasText: 'text' })` | Split into locator + filter |
| `cy.get('[data-testid="x"]')` | `page.getByTestId('x')` | Use semantic locator — more readable |
| `cy.get('[data-cy="x"]')` | `page.getByTestId('x')` | Requires `data-testid` attribute config in Playwright |
| `cy.get('input').click()` | `await page.locator('input').click()` | `await` required on action |
| `cy.get('input').type('text')` | `await page.locator('input').fill('text')` | `type` → `fill` (clears first); use `pressSequentially()` for character-by-character |
| `cy.get('input').clear()` | `await page.locator('input').clear()` | Identical chain pattern |
| `cy.get('input').check()` | `await page.locator('input').check()` | Identical chain pattern |
| `cy.get('input').uncheck()` | `await page.locator('input').uncheck()` | Identical chain pattern |
| `cy.get('select').select('value')` | `await page.locator('select').selectOption('value')` | Method name change |
| `cy.get('form').submit()` | `await page.locator('form').evaluate('el => el.submit()')` | No direct `submit()` — use evaluate |
| `cy.url()` | `page.url()` | Property access, not method call |
| `cy.title()` | `await page.title()` | `await` required |
| `cy.go('back')` | `await page.goBack()` | Named method |
| `cy.go('forward')` | `await page.goForward()` | Named method |
| `cy.reload()` | `await page.reload()` | Identical chain pattern |
| `cy.wait(ms)` | `await page.waitForTimeout(ms)` | Same concept but prefer `waitForSelector`/`waitForResponse` instead |
| `cy.waitFor(selector)` | `await page.locator(selector).waitFor()` | Structural change |
| `cy.intercept(method, url, handler)` | `await page.route(url, handler)` | Different API — see mocking section |
| `cy.request(method, url, body)` | `await page.request[method](url, { data: body })` | Use Playwright's API request context |
| `cy.fixture('data')` | Read file via `fs` or use Playwright's `test fixture` pattern | No direct equivalent — use different fixture strategy |
| `cy.readFile(path)` | `await page.evaluate(() => fetch(path))` or `fs.readFileSync` | Use Node.js `fs` in Playwright tests |
| `cy.writeFile(path, content)` | `fs.writeFileSync(path, content)` | Use Node.js `fs` directly |
| `cy.screenshot()` | `await page.screenshot()` | Identical concept |
| `cy.scrollTo(position)` | `await page.evaluate(() => window.scrollTo(x, y))` | Use evaluate or locator scroll methods |
| `cy.trigger('event')` | `await page.locator('el').dispatchEvent('event')` | Method name change |
| `cy.invoke('method')` | `await page.locator('el').evaluate((el) => el.method())` | Use evaluate for DOM method calls |
| `cy.wrap(subject)` | (remove — Playwright uses different chaining) | Not needed in Playwright's model |
| `cy.log('message')` | `console.log('message')` or `test.info().annotations.push()` | Simple replacement |
| `cy.exec('command')` | `await exec('command')` via Node.js `child_process` | Use Node.js APIs directly |
| `cy.task('name', arg)` | `test.use({ fixture })` pattern or Node.js function call | No task/plugin system in Playwright |
| `cy.window()` | `await page.evaluate(() => window)` | Access via evaluate |

## Cypress → Playwright: Assertion Mapping

Cypress assertions use `.should()` chaining. Playwright uses `expect(locator).toBeX()` or `expect(page).toHaveX()`.

| Cypress Assertion | Playwright Assertion | Notes |
|-------------------|---------------------|-------|
| `.should('exist')` | `await expect(locator).toBeAttached()` | Different terminology |
| `.should('not.exist')` | `await expect(locator).not.toBeAttached()` | `not` prefix |
| `.should('be.visible')` | `await expect(locator).toBeVisible()` | Direct mapping |
| `.should('not.be.visible')` | `await expect(locator).not.toBeVisible()` | `not` prefix |
| `.should('have.text', 'Hello')` | `await expect(locator).toHaveText('Hello')` | Direct mapping |
| `.should('have.text', /regex/)` | `await expect(locator).toHaveText(/regex/)` | Regex supported |
| `.should('contain.text', 'Hello')` | `await expect(locator).toContainText('Hello')` | Direct mapping |
| `.should('have.value', 'val')` | `await expect(locator).toHaveValue('val')` | Direct mapping |
| `.should('have.attr', 'href', '/path')` | `await expect(locator).toHaveAttribute('href', '/path')` | Direct mapping |
| `.should('have.class', 'active')` | `await expect(locator).toHaveClass('active')` | Direct mapping |
| `.should('have.css', 'color', 'red')` | `await expect(locator).toHaveCSS('color', 'red')` | Direct mapping |
| `.should('be.checked')` | `await expect(locator).toBeChecked()` | Direct mapping |
| `.should('be.disabled')` | `await expect(locator).toBeDisabled()` | Direct mapping |
| `.should('be.enabled')` | `await expect(locator).toBeEnabled()` | Direct mapping |
| `.should('have.length', n)` | `await expect(locator).toHaveCount(n)` | `length` → `count` for locators |
| `.should('have.focus')` | `await expect(locator).toBeFocused()` | Direct mapping |
| `.should('have.prop', 'checked', true)` | `await expect(locator).toBeChecked()` | Use specific assertion |
| `.should('satisfy', fn)` | `await expect(locator).toBeTruthy()` or custom | No direct `satisfy`; use evaluate + expect |

## Cypress → Playwright: Hook & Config Mapping

| Cypress Hook | Playwright Equivalent | Notes |
|-------------|---------------------|-------|
| `before(() => { ... })` | `test.beforeAll(async () => { ... })` | Must be async; `beforeAll` on `test` object |
| `beforeEach(() => { ... })` | `test.beforeEach(async ({ page }) => { ... })` | Receives `page` fixture |
| `afterEach(() => { ... })` | `test.afterEach(async ({ page }) => { ... })` | Receives `page` fixture |
| `after(() => { ... })` | `test.afterAll(async () => { ... })` | Must be async |
| `describe('name', () => { ... })` | `test.describe('name', async () => { ... })` | Must be async |
| `describe.only('name', () => { ... })` | `test.describe.only('name', async () => { ... })` | Direct mapping |
| `describe.skip('name', () => { ... })` | `test.describe.skip('name', async () => { ... })` | Direct mapping |
| `context('name', () => { ... })` | `test.describe('name', async () => { ... })` | `context` → `test.describe` |
| `it('name', () => { ... })` | `test('name', async ({ page }) => { ... })` | `it` → `test`; async required |
| `it.only('name', () => { ... })` | `test.only('name', async ({ page }) => { ... })` | Direct mapping |
| `it.skip('name', () => { ... })` | `test.skip('name', async ({ page }) => { ... })` | Direct mapping |
| `xit('name', () => { ... })` | `test.skip('name', async ({ page }) => { ... })` | `xit` → `test.skip` |
| `cy.task('dbClean')` in `beforeEach` | Database helper function in `test.beforeEach` | No plugin system — call Node.js functions directly |

### Config Mapping

| Cypress Config | Playwright Config | Transformation Notes |
|---------------|------------------|---------------------|
| `baseUrl: 'http://localhost:3000'` | `use: { baseURL: 'http://localhost:3000' }` | Move into `use` block; note casing |
| `viewportWidth: 1280` | `use: { viewport: { width: 1280, height: 720 } }` | Must provide both width + height |
| `viewportHeight: 720` | (merged into `viewport` above) | Combine with `viewportWidth` |
| `defaultCommandTimeout: 10000` | `use: { actionTimeout: 10000 }` | Different name |
| `requestTimeout: 5000` | `use: { navigationTimeout: 30000 }` | Different scope; adjust timeout value |
| `video: true` | `use: { video: 'on' }` | Boolean → string enum (`'on'`, `'off'`, `'retain-on-failure'`, `'on-first-retry'`) |
| `screenshotOnRunFailure: true` | `use: { screenshot: 'only-on-failure' }` | Boolean → string enum |
| `screenshotsFolder: 'cypress/screenshots'` | `use: { screenshot: { ... } }` + outputDir | Restructured config |
| `videosFolder: 'cypress/videos'` | `use: { video: 'on' }` | Playwright manages video paths |
| `supportFile: 'cypress/support/e2e.ts'` | `import './fixtures';` in test files or global setup | No direct equivalent — use imports or `globalSetup` |
| `specPattern: 'cypress/e2e/**/*.cy.{js,ts}'` | `testDir: './tests'` or `testMatch: '**/*.spec.{js,ts}'` | Different field names |
| `env: { ... }` | `use: { ... }` or `env` property in `defineConfig` | Restructured config |
| `retries: { runMode: 2 }` | `retries: 2` | Simplified; Playwright retries all failures |
| `e2e: { specPattern, supportFile, ... }` | (top-level or `use` block) | No `e2e` nesting in Playwright |
| `component: { ... }` | Not directly applicable | Playwright component testing uses different setup |

## Cypress → Playwright: Custom Commands & Manual Review

Cypress `Cypress.Commands.add()` patterns map to Playwright Page Object Models or custom fixtures:

```typescript
// Cypress custom command
Cypress.Commands.add('login', (email, password) => {
  cy.visit('/login');
  cy.get('[data-testid="email"]').type(email);
  cy.get('[data-testid="password"]').type(password);
  cy.get('[data-testid="submit"]').click();
});

// Playwright: Page Object Model
class LoginPage {
  constructor(private page: Page) {}

  async login(email: string, password: string) {
    await this.page.goto('/login');
    await this.page.getByTestId('email').fill(email);
    await this.page.getByTestId('password').fill(password);
    await this.page.getByTestId('submit').click();
  }
}

// Or Playwright: custom fixture
import { test as base } from '@playwright/test';

const test = base.extend<{ loginPage: LoginPage }>({
  loginPage: async ({ page }, use) => {
    await use(new LoginPage(page));
  },
});
```

**Strategy:**
1. Extract each Cypress custom command into a Page Object Model method
2. Create Page Object classes organized by feature/page
3. Use Playwright fixtures for common setup (auth state, test data)
4. Commands that modify global state become `test.beforeAll`/`test.beforeEach` hooks

### Files Requiring Manual Review

| Pattern | Why Manual Review Needed | Suggested Resolution |
|---------|------------------------|---------------------|
| Conditional testing (`if (Cypress.$('.modal').length)`) | Playwright auto-waits and doesn't need conditional DOM checks | Restructure as separate test cases or use `locator.isVisible()` checks |
| `cy.session()` | Playwright has `storageState` for auth persistence but different API | Rewrite using `storageState` save/restore pattern |
| `cy.origin()` | Playwright handles cross-origin by default with proper config | Remove `cy.origin()` wrappers; ensure `baseURL` configured |
| Cypress plugins (`cypress/plugins/index.js`) | No plugin system in Playwright | Convert to Playwright `globalSetup`/`globalTeardown` or fixtures |
| `cy.task()` calls | No task/plugin system | Convert to direct Node.js function calls or fixture-based helpers |
| Custom Cypress reporters | Playwright has its own reporter system | Rewrite using Playwright reporter API |
| `Cypress.env()` | Use `process.env` or Playwright `config.env` | Replace with direct environment access |
| `Cypress.dom.isHidden()` | Use `locator.isVisible()` | Different API but simpler |
| `cy.stub()` | Use `vi.fn()` (Vitest) or `jest.fn()` in Playwright tests | Playwright tests run in Node — use standard JS mocking |
| `cy.clock()` | Use `page.clock.install()` (Playwright 1.45+) | Relatively new API — verify Playwright version |
| Third-party Cypress plugins (`cypress-axe`, `cypress-image-snapshot`) | Need Playwright equivalents | Search for Playwright-specific alternatives |

## Cypress → Playwright: Complexity Classification

| Complexity | Criteria | Risk |
|-----------|----------|------|
| **Simple** | Basic page navigation, clicks, fills, assertions, no custom commands, no `cy.intercept` | Low — command-for-command mapping with `await` additions |
| **Moderate** | Custom commands, `cy.intercept`/`cy.route` mocking, `cy.fixture`, `beforeEach` with page setup, screenshot/video config, multi-page flows | Medium — requires Page Object extraction, config restructuring, async conversion |
| **Complex** | Conditional testing, `cy.session`/`cy.origin`, custom plugins (`cypress/plugins/`), `cy.task`, `cy.clock`, third-party plugin dependencies, iframe interactions | High — requires architectural restructuring; some patterns have no direct equivalent |

---

## General Migration Principles: Safety & Classification

These principles govern ALL migration paths and MUST be followed:

1. **Always backup before transformation** — Create git stash of all test files before any modifications. Record stash ref in `.bestest/state/migration-backup.json`. If git is not initialized, BLOCK with a clear message — do not proceed without version control.

2. **Verify after migration** — Run the target framework's test suite after transformation. If tests fail, attempt auto-fix (up to 3 iterations). If still failing, rollback and report.

3. **Flag complex patterns for manual review** — Any file classified as "complex" or containing patterns in the "manual review" tables above must be flagged. Auto-transformation is limited to simple and moderate files.

4. **Never silently drop test coverage** — Every test that existed before migration must exist after migration. If a test cannot be auto-transformed, it is preserved in its original form with a TODO comment, not deleted.

5. **Preserve test intent** — Transformation rules must preserve the behavioral intent of the test, not just the syntax. A `jest.fn()` → `vi.fn()` replacement is safe because the API is identical. A `@RunWith` → `@ExtendWith` transformation requires verifying the extension provides equivalent behavior.

6. **Atomic per-file transformation** — Each test file is transformed independently. A failure in one file does not block transformation of other files. Track per-file status in the migration report.

### Per-File Complexity Classification

Classification happens during Phase 2 (Analysis & Planning) and determines the transformation strategy:

| Classification | Criteria | Transformation Strategy |
|---------------|----------|------------------------|
| **Simple** | Uses only basic assertions and standard test structure. No mocks, no custom lifecycle, no framework-specific plugins. | Full auto-transformation with high confidence. |
| **Moderate** | Uses mocks/spies, lifecycle hooks, config customization, parameterized tests, or non-trivial assertion patterns. | Auto-transformation with post-transform verification. Flag any assertion that changes parameter order. |
| **Complex** | Uses custom rules/runners/commands, conditional testing, third-party plugins, `__mocks__` auto-loading, or patterns listed in "manual review" tables. | Auto-transform what's possible, wrap remaining in TODO comments. Present for manual review at HITL gate. |

**Classification algorithm:**

```
For each file:
  complexity = "simple"
  flags = []

  Scan for patterns:
    If mock API usage detected (jest.fn/spyOn/mock, @Rule, cy.intercept):
      complexity = "moderate"

    If lifecycle hooks detected (beforeEach, @Before, before):
      complexity = max(complexity, "moderate")

    If custom patterns detected (Cypress.Commands.add, @RunWith(custom), __mocks__):
      complexity = "complex"
      flags.append("custom-pattern")

    If conditional testing detected (if (Cypress.$), dynamic skip):
      complexity = "complex"
      flags.append("conditional-testing")

    If plugin dependencies detected (cypress plugins, jest plugins, custom runners):
      complexity = "complex"
      flags.append("plugin-dependency")

    If config file transformation needed (jest.config, cypress.config, build.gradle):
      Add config file to migration plan with appropriate complexity
```

## General Migration Principles: Verification & Risk

| Risk Level | Criteria | Action |
|-----------|----------|--------|
| **Low** | All files classified "simple"; config migration is straightforward | Proceed with auto-transformation |
| **Medium** | Mix of "simple" and "moderate" files; config has custom fields | Proceed with auto-transformation + post-verification |
| **High** | Any "complex" files present; custom plugins or commands; large codebase (>50 test files) | Require explicit HITL approval; present detailed migration plan |

### Post-Migration Verification Protocol

After all transformations are applied:

1. **Syntax check** — Ensure transformed files parse without errors (TypeScript compiler, Java compiler, or Playwright validator)
2. **Test execution** — Run the target framework's test suite on all transformed files
3. **Coverage comparison** — Compare pre-migration and post-migration test counts. Coverage must not decrease
4. **Auto-fix loop** — For failing tests, attempt up to 3 fix iterations:
   - Iteration 1: Fix import/syntax issues
   - Iteration 2: Fix assertion/mock API mismatches
   - Iteration 3: Fix config-related failures
5. **Rollback threshold** — If more than 20% of files fail after auto-fix, rollback all changes and report

## General Migration Principles: Config, Paths & Report Schema

Config files are migrated alongside test files but with extra care:

| Priority | Config Type | Reason |
|----------|-------------|--------|
| **1** (first) | Framework config (jest.config, cypress.config) | Must be valid before test files can run |
| **2** | Build config (build.gradle, pom.xml, package.json) | Dependency changes needed for new framework |
| **3** | CI config (.github/workflows) | Update test commands after framework change |
| **4** (last) | .bestest/config.yaml | Update framework field after successful migration |

### Supported Migration Path Validation

Only these migration paths are supported. Any other combination is rejected in pre-flight:

| From | To | Status |
|------|----|--------|
| `jest` | `vitest` | ✅ Supported |
| `junit4` | `junit5` | ✅ Supported |
| `cypress` | `playwright` | ✅ Supported |

Aliases accepted:
- `jest` / `Jest` → `jest`
- `vitest` / `Vitest` → `vitest`
- `junit4` / `junit-4` / `JUnit4` / `junit` → `junit4`
- `junit5` / `junit-5` / `JUnit5` → `junit5`
- `cypress` / `Cypress` → `cypress`
- `playwright` / `Playwright` → `playwright`

### Migration Report Schema

The migration report at `.bestest/reports/migration-{timestamp}.json` follows this schema:

```json
{
  "timestamp": "2025-01-15T10:30:00Z",
  "from": "jest",
  "to": "vitest",
  "status": "completed | partial | failed | rolled_back",
  "files_total": 42,
  "files_migrated": 38,
  "files_skipped": 2,
  "files_manual_review": 2,
  "files_failed": 0,
  "tests_run": 156,
  "tests_passed": 154,
  "tests_failed": 2,
  "config_migrated": true,
  "dependencies_updated": true,
  "rollback_available": false,
  "auto_fixes_applied": 12,
  "duration_ms": 45230,
  "transformations": {
    "imports_changed": 38,
    "mocks_changed": 24,
    "assertions_changed": 15,
    "config_fields_mapped": 8,
    "lifecycle_hooks_changed": 6
  },
  "per_file_status": [
    {
      "file": "src/utils/format.test.ts",
      "status": "migrated",
      "complexity": "simple",
      "transformations": 5,
      "test_result": "passed"
    }
  ]
}
```
