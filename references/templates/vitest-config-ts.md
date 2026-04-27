# vitest.config.ts Templates

Complete, syntactically valid vitest.config.ts templates for four common stack variants. Each variant is a standalone config — copy the one that matches your project type.

---

## Variant 1: Vite + React

For projects using Vite as the build tool with React as the frontend framework. Uses jsdom environment for DOM testing and includes the React plugin.

```typescript
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    // DOM environment for React component testing
    environment: 'jsdom',
    // Global APIs (describe, it, expect) available without imports
    globals: true,
    // Setup files run before each test suite
    setupFiles: ['./src/test/setup.ts'],
    // Test file discovery patterns
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    // Coverage configuration
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'json-summary'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: [
        'src/**/*.{test,spec}.{ts,tsx}',
        'src/**/*.d.ts',
        'src/test/**',
        'src/main.tsx',
      ],
    },
  },
})
```

Required devDependencies:
```
vitest @vitest/coverage-v8 @vitejs/plugin-react jsdom
```

---

## Variant 2: Next.js

For Next.js projects. Similar to Vite+React but handles Next.js-specific module resolution and App Router Server Components.

```typescript
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    include: ['src/**/*.{test,spec}.{ts,tsx}', 'app/**/*.{test,spec}.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'json-summary'],
      include: ['src/**/*.{ts,tsx}', 'app/**/*.{ts,tsx}'],
      exclude: [
        'src/**/*.{test,spec}.{ts,tsx}',
        'app/**/*.{test,spec}.{ts,tsx}',
        'src/**/*.d.ts',
        'src/test/**',
        'next.config.*',
      ],
    },
  },
  resolve: {
    alias: {
      // Next.js module aliases — adjust to match your tsconfig paths
      '@': new URL('./src', import.meta.url).pathname,
    },
  },
})
```

Required devDependencies:
```
vitest @vitest/coverage-v8 @vitejs/plugin-react jsdom
```

Next.js-specific setup file (`src/test/setup.ts`):
```typescript
// Mock Next.js navigation and image components as needed
// These are commonly needed for Next.js App Router testing
```

---

## Variant 3: Express / API-Only

For backend projects using Express, Fastify, or other Node.js frameworks. Uses node environment — no DOM globals.

```typescript
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    // Node environment — no DOM globals available
    environment: 'node',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    include: ['src/**/*.{test,spec}.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'json-summary'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: [
        'src/**/*.{test,spec}.{ts,tsx}',
        'src/**/*.d.ts',
        'src/test/**',
        'src/index.ts',
        'src/server.ts',
      ],
    },
  },
  resolve: {
    alias: {
      // Add path aliases matching your tsconfig.json paths
      '@': new URL('./src', import.meta.url).pathname,
    },
  },
})
```

Required devDependencies:
```
vitest @vitest/coverage-v8
```

API testing setup file (`src/test/setup.ts`):
```typescript
// Set test environment variables
process.env.NODE_ENV = 'test'

// Import shared test utilities (supertest, mock factories, etc.)
// import './test-helpers'
```

---

## Variant 4: Plain TypeScript

For vanilla TypeScript projects without a specific framework. Minimal configuration with node environment.

```typescript
import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'node',
    globals: true,
    include: ['src/**/*.{test,spec}.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'json-summary'],
      include: ['src/**/*.ts'],
      exclude: [
        'src/**/*.{test,spec}.ts',
        'src/**/*.d.ts',
        'src/index.ts',
      ],
    },
  },
})
```

Required devDependencies:
```
vitest @vitest/coverage-v8
```

---

## Shared Test Setup Pattern

All variants can use a setup file for shared configuration. Create at the path specified in `setupFiles`:

```typescript
// src/test/setup.ts
import { expect, afterEach } from 'vitest'

// Extend expect with custom matchers if needed
// expect.extend({ ... })

// Global cleanup after each test
afterEach(() => {
  // Reset mocks, clear timers, restore modules as needed
})
```

## Running Tests

```bash
# Run all tests
npx vitest

# Run tests in watch mode
npx vitest --watch

# Run tests with coverage
npx vitest --coverage

# Run a specific test file
npx vitest src/utils/example.test.ts
```
