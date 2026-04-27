# API Test Helper Templates

Reusable helper patterns for API testing with supertest. These patterns create a shared `api-helper.ts` utility that standardizes request building, authentication, assertions, and cleanup across all API test files.

---

## Pattern 1: Express App Setup with Supertest

Create a shared test client that imports your Express app and wraps it with supertest. This avoids repeating setup in every test file.

```typescript
// src/test/helpers/api-helper.ts
import request from 'supertest'
import { app } from '../../app' // Adjust import path to your Express app

// Typed API client wrapping supertest
export function apiClient() {
  return request(app)
}

// Shorthand methods for common HTTP verbs
export const api = {
  get: (path: string) => apiClient().get(path),
  post: (path: string) => apiClient().post(path),
  put: (path: string) => apiClient().put(path),
  patch: (path: string) => apiClient().patch(path),
  delete: (path: string) => apiClient().delete(path),
}
```

Usage in a test file:
```typescript
import { describe, it, expect } from 'vitest'
import { api } from './helpers/api-helper'

describe('GET /api/users', () => {
  it('returns 200 with user list', async () => {
    const res = await api.get('/api/users')
    expect(res.status).toBe(200)
    expect(res.body).toBeInstanceOf(Array)
  })
})
```

---

## Pattern 2: Auth Header Helpers

Standardized authentication header builders for bearer tokens and cookie-based sessions.

```typescript
// src/test/helpers/auth-helper.ts
import type { Request } from 'supertest'
import { api } from './api-helper'

// Bearer token auth — attach to any request
export function withBearerToken(req: Request, token: string): Request {
  return req.set('Authorization', `Bearer ${token}`)
}

// Cookie auth — attach session cookie to any request
export function withCookie(req: Request, name: string, value: string): Request {
  return req.set('Cookie', `${name}=${value}`)
}

// Get a valid test token — adjust to match your auth system
export async function getTestToken(
  role: 'admin' | 'user' = 'user'
): Promise<string> {
  const credentials = {
    admin: { email: 'admin@test.com', password: 'admin-password' },
    user: { email: 'user@test.com', password: 'user-password' },
  }

  const res = await api.post('/api/auth/login').send(credentials[role])

  if (res.status !== 200) {
    throw new Error(`Failed to get test token for role "${role}": ${res.status}`)
  }

  return res.body.token // Adjust to match your response shape
}

// Convenience: authenticated GET request
export async function authGet(
  path: string,
  role: 'admin' | 'user' = 'user'
) {
  const token = await getTestToken(role)
  return withBearerToken(api.get(path), token)
}

// Convenience: authenticated POST request
export async function authPost(
  path: string,
  body: unknown,
  role: 'admin' | 'user' = 'user'
) {
  const token = await getTestToken(role)
  return withBearerToken(api.post(path).send(body), token)
}
```

---

## Pattern 3: Request/Response Assertion Patterns

Common assertion helpers to reduce boilerplate in API tests.

```typescript
// src/test/helpers/assertions.ts
import { expect } from 'vitest'
import type { Response } from 'supertest'

// Assert a successful response with JSON body
export function expectSuccess(res: Response, status = 200) {
  expect(res.status).toBe(status)
  expect(res.headers['content-type']).toMatch(/json/)
}

// Assert an error response with a specific message
export function expectError(res: Response, status: number, message?: string) {
  expect(res.status).toBe(status)
  expect(res.body).toHaveProperty('error')
  if (message) {
    expect(res.body.error).toContain(message)
  }
}

// Assert paginated response shape
export function expectPaginated(
  res: Response,
  options: { minItems?: number; maxItems?: number } = {}
) {
  expect(res.status).toBe(200)
  expect(res.body).toHaveProperty('data')
  expect(res.body).toHaveProperty('total')
  expect(Array.isArray(res.body.data)).toBe(true)
  if (options.minItems !== undefined) {
    expect(res.body.data.length).toBeGreaterThanOrEqual(options.minItems)
  }
  if (options.maxItems !== undefined) {
    expect(res.body.data.length).toBeLessThanOrEqual(options.maxItems)
  }
}

// Assert response contains a specific field value
export function expectField(res: Response, field: string, value: unknown) {
  expect(res.body).toHaveProperty(field, value)
}

// Assert validation error response (422 or 400)
export function expectValidationError(
  res: Response,
  field?: string
) {
  expect(res.status).toBeOneOf([400, 422])
  expect(res.body).toHaveProperty('error')
  if (field) {
    expect(res.body.error).toMatch(
      new RegExp(field, 'i')
    )
  }
}
```

---

## Pattern 4: Database Cleanup Helpers

Setup and teardown helpers for ensuring a clean database state between tests.

```typescript
// src/test/helpers/db-helper.ts
import { beforeAll, afterAll, afterEach } from 'vitest'
// Adjust imports to match your ORM/database library
// import { prisma } from '../../lib/prisma'
// import { db } from '../../lib/db'

// Truncate all tables before running the test suite
export async function cleanDatabase() {
  // Prisma example:
  // const tablenames = await prisma.$queryRaw<
  //   Array<{ tablename: string }>
  // >`SELECT tablename FROM pg_tables WHERE schemaname='public'`
  //
  // for (const { tablename } of tablenames) {
  //   if (tablename !== '_prisma_migrations') {
  //     await prisma.$executeRawUnsafe(
  //       `TRUNCATE TABLE "public"."${tablename}" CASCADE;`
  //     )
  //   }
  // }
}

// Seed the database with test fixtures
export async function seedFixtures() {
  // Create test users, posts, etc.
  // await prisma.user.create({ data: { email: 'user@test.com', name: 'Test User' } })
}

// Standard setup: clean DB before suite, seed fixtures, clean after each test
export function setupTestDb() {
  beforeAll(async () => {
    await cleanDatabase()
    await seedFixtures()
  })

  afterEach(async () => {
    // Clean up data created during individual tests
    // Keep seeded fixtures intact or re-seed
    await cleanDatabase()
    await seedFixtures()
  })

  afterAll(async () => {
    await cleanDatabase()
    // Close database connection
    // await prisma.$disconnect()
  })
}

// Create a specific test entity with sensible defaults
export function createTestUser(overrides = {}) {
  return {
    email: `test-${Date.now()}@example.com`,
    name: 'Test User',
    ...overrides,
  }
}

export function createTestPost(overrides = {}) {
  return {
    title: 'Test Post',
    content: 'This is test content for the post.',
    ...overrides,
  }
}
```

---

## Complete Example: API Test Suite

Putting all helpers together in a real test file:

```typescript
// src/api/users/users.test.ts
import { describe, it, expect } from 'vitest'
import { api } from '../../test/helpers/api-helper'
import { authGet, authPost } from '../../test/helpers/auth-helper'
import { expectSuccess, expectError, expectPaginated } from '../../test/helpers/assertions'
import { setupTestDb, createTestUser } from '../../test/helpers/db-helper'

describe('Users API', () => {
  setupTestDb()

  describe('GET /api/users', () => {
    it('returns paginated user list', async () => {
      const res = await authGet('/api/users')
      expectPaginated(res)
    })

    it('requires authentication', async () => {
      const res = await api.get('/api/users')
      expectError(res, 401)
    })
  })

  describe('POST /api/users', () => {
    it('creates a new user', async () => {
      const userData = createTestUser()
      const res = await authPost('/api/users', userData, 'admin')
      expectSuccess(res, 201)
      expect(res.body.email).toBe(userData.email)
    })
  })
})
```
