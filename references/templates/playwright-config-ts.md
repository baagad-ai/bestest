# Playwright Configuration Templates

Complete, syntactically valid `playwright.config.ts` templates for three common project variants. Each variant is a standalone config — copy the one that matches your project type.

---

## Variant 1: React / Next.js App

For frontend-focused projects testing user flows, page navigation, and component interactions in a real browser.

```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  // Test directory — adjust to match your project structure
  testDir: './e2e',

  // Run tests in parallel for speed
  fullyParallel: true,

  // Fail the build on CI if you accidentally left test.only in source
  forbidOnly: !!process.env.CI,

  // Retry failed tests once on CI for flakiness resilience
  retries: process.env.CI ? 1 : 0,

  // Parallel workers (1 on CI for stability, local uses CPU count)
  workers: process.env.CI ? 1 : undefined,

  // HTML report for CI, console list locally
  reporter: process.env.CI
    ? [['html', { open: 'never' }], ['github']]
    : 'list',

  // Shared settings for all tests
  use: {
    // Base URL for page.goto('/') calls
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000',

    // Run headless on CI, headed locally for debugging
    headless: !!process.env.CI,

    // Capture screenshot only on failure
    screenshot: 'only-on-failure',

    // Collect trace on first retry for debugging
    trace: 'on-first-retry',
  },

  // Browser projects to test against
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    // Mobile emulation — uncomment if needed
    // {
    //   name: 'mobile-chrome',
    //   use: { ...devices['Pixel 5'] },
    // },
    // {
    //   name: 'mobile-safari',
    //   use: { ...devices['iPhone 13'] },
    // },
  ],

  // Auto-start dev server before tests
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
})
```

Required devDependencies:
```
@playwright/test
```

Install browsers after adding the dependency:
```bash
npx playwright install
```

---

## Variant 2: API-Only Testing

For projects that expose REST or GraphQL APIs and need to validate response schemas, status codes, and data correctness without a browser.

```typescript
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e/api',

  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 1 : undefined,

  reporter: process.env.CI
    ? [['html', { open: 'never' }], ['github']]
    : 'list',

  use: {
    // API base URL — all requests go here
    baseURL: process.env.API_BASE_URL || 'http://localhost:3000',

    // No browser needed for API tests
    headless: true,

    // Extra HTTP headers sent with every request
    extraHTTPHeaders: {
      'Content-Type': 'application/json',
    },
  },

  projects: [
    {
      name: 'api-tests',
      use: {
        // API test fixture — uses request context, no browser
        // Tests use `request` fixture from @playwright/test
      },
    },
  ],

  // Auto-start API server before tests
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000/health',
    reuseExistingServer: !process.env.CI,
    timeout: 60 * 1000,
  },
})
```

API test example (`e2e/api/users.spec.ts`):
```typescript
import { test, expect } from '@playwright/test'

test('GET /users returns list', async ({ request }) => {
  const response = await request.get('/api/users')
  expect(response.ok()).toBeTruthy()
  const body = await response.json()
  expect(Array.isArray(body)).toBeTruthy()
})
```

Required devDependencies:
```
@playwright/test
```

---

## Variant 3: Full-Stack (UI + API)

For projects that test both browser interactions and API endpoints in a single suite. Uses Playwright projects to separate UI and API concerns while sharing config.

```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',

  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 1 : undefined,

  reporter: process.env.CI
    ? [['html', { open: 'never' }], ['github']]
    : 'list',

  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000',
    headless: !!process.env.CI,
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',
  },

  projects: [
    // UI tests — full browser automation
    {
      name: 'ui-chromium',
      testDir: './e2e/ui',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'ui-firefox',
      testDir: './e2e/ui',
      use: { ...devices['Desktop Firefox'] },
    },

    // API tests — request context only, no browser
    {
      name: 'api-tests',
      testDir: './e2e/api',
      use: {
        // Request fixture tests run without launching a browser
        extraHTTPHeaders: {
          'Content-Type': 'application/json',
        },
      },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120 * 1000,
  },
})
```

Directory structure for full-stack tests:
```
e2e/
├── ui/
│   ├── login.spec.ts       # Browser-based UI tests
│   └── dashboard.spec.ts
├── api/
│   ├── users.spec.ts       # API request/response tests
│   └── auth.spec.ts
└── fixtures/
    └── test-data.ts         # Shared test data generators
```

Required devDependencies:
```
@playwright/test
```

---

## Monorepo Configuration Pattern

For monorepos where each app has its own Playwright config. Use a root-level config that references per-app configs:

```typescript
// apps/web/playwright.config.ts
import { defineConfig, devices } from '@playwright/test'
import baseConfig from '../../playwright.base.config'

export default defineConfig({
  ...baseConfig,
  testDir: './e2e',
  use: {
    ...baseConfig.use,
    baseURL: 'http://localhost:3001',
  },
  webServer: {
    command: 'npm run dev --workspace=apps/web',
    url: 'http://localhost:3001',
    reuseExistingServer: true,
  },
})
```

```typescript
// playwright.base.config.ts (root shared config)
import { defineConfig } from '@playwright/test'

export default defineConfig({
  fullyParallel: true,
  retries: process.env.CI ? 1 : 0,
  reporter: 'list',
  use: {
    headless: true,
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',
  },
})
```

---

## Running Tests

```bash
# Run all E2E tests
npx playwright test

# Run a specific project
npx playwright test --project=ui-chromium

# Run tests in headed mode for debugging
npx playwright test --headed

# Run a single test file
npx playwright test e2e/ui/login.spec.ts

# Generate HTML report
npx playwright show-report
```
