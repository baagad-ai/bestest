# jest.config.ts Template

Standard Jest configuration for existing Jest projects. Choose the transform option that matches your project's TypeScript compilation strategy.

---

## Complete jest.config.ts

```typescript
import type { Config } from 'jest'

const config: Config = {
  // Test file discovery
  testEnvironment: 'jsdom',
  roots: ['<rootDir>/src'],
  testMatch: ['**/*.{test,spec}.{ts,tsx,js,jsx}'],

  // Module resolution
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json'],
  // Path aliases — uncomment and adjust to match your tsconfig.json paths
  // moduleNameMapper: {
  //   '^@/(.*)$': '<rootDir>/src/$1',
  // },

  // Setup files
  // setupFilesAfterEnv: ['<rootDir>/src/test/setup.ts'],

  // Coverage collection
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.{test,spec}.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/test/**',
  ],
  coverageReporters: ['text', 'html', 'json-summary'],
  coverageThreshold: {
    global: {
      statements: 80,
      branches: 80,
      functions: 80,
      lines: 80,
    },
  },

  // =========================================================
  // Transform: Choose ONE of the three options below.
  // Delete or comment out the options you are not using.
  // =========================================================

  // --- Option A: SWC (Recommended — fastest) ---
  // Requires: @swc/core @swc/jest
  transform: {
    '^.+\\.(ts|tsx)$': [
      '@swc/jest',
      {
        jsc: {
          transform: {
            react: {
              runtime: 'automatic',
            },
          },
        },
      },
    ],
  },

  // --- Option B: Babel ---
  // Requires: babel-jest @babel/core @babel/preset-env @babel/preset-typescript @babel/preset-react
  // transform: {
  //   '^.+\\.(ts|tsx)$': 'babel-jest',
  // },

  // --- Option C: ts-jest ---
  // Requires: ts-jest
  // transform: {
  //   '^.+\\.(ts|tsx)$': [
  //     'ts-jest',
  //     {
  //       tsconfig: 'tsconfig.json',
  //     },
  //   ],
  // },
}

export default config
```

---

## Transform Option Details

### Option A: SWC (Recommended)

Fastest TypeScript compilation. Best for projects that want minimal test overhead.

**Install:**
```bash
npm install --save-dev @swc/core @swc/jest
```

**Best for:** Projects prioritizing test speed, teams already using SWC in their build.

### Option B: Babel

Most flexible transform. Supports custom Babel plugins and presets.

**Install:**
```bash
npm install --save-dev babel-jest @babel/core @babel/preset-env @babel/preset-typescript @babel/preset-react
```

**Requires `.babelrc` or `babel.config.js`:**
```javascript
module.exports = {
  presets: [
    ['@babel/preset-env', { targets: { node: 'current' } }],
    '@babel/preset-typescript',
    ['@babel/preset-react', { runtime: 'automatic' }],
  ],
}
```

**Best for:** Projects with existing Babel config, custom plugins, or complex transform needs.

### Option C: ts-jest

TypeScript-native Jest transform. Best type-checking integration.

**Install:**
```bash
npm install --save-dev ts-jest
```

**Best for:** Projects that want type-checking during tests, strict TypeScript compliance.

---

## Module Path Mapping

If your `tsconfig.json` uses path aliases, configure `moduleNameMapper` to match:

```typescript
// tsconfig.json:
// "paths": { "@/*": ["src/*"], "@components/*": ["src/components/*"] }

moduleNameMapper: {
  '^@/(.*)$': '<rootDir>/src/$1',
  '^@components/(.*)$': '<rootDir>/src/components/$1',
}
```

---

## Running Tests

```bash
# Run all tests
npx jest

# Run tests in watch mode
npx jest --watch

# Run tests with coverage
npx jest --coverage

# Run a specific test file
npx jest src/utils/example.test.ts
```
