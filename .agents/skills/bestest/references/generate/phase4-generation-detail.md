# Phase 4 — Test Generation Detail

> **On-demand load:** When generating complex test files or needing complete examples and advanced mocking patterns, read this file. The hub file contains framework syntax headers, naming conventions, and generation rules.

---

## Complete Example: Well-Generated Test File

This is the target quality level for every generated file:

```typescript
import { describe, test, expect, vi, beforeEach } from 'vitest';
import { calculateDiscount, applyBulkDiscount } from './pricing';
import { createCart, createItem } from '../test-utils/factories';

describe('calculateDiscount', () => {
  test('returns reduced price when percentage is within valid range', () => {
    const cart = createCart({ items: [createItem({ price: 100 })] });
    expect(calculateDiscount(cart, 20)).toBe(80);
  });

  test('returns full price when discount is 0', () => {
    const cart = createCart({ items: [createItem({ price: 50 })] });
    expect(calculateDiscount(cart, 0)).toBe(50);
  });

  test('throws when discount percentage exceeds 100', () => {
    const cart = createCart({ items: [createItem({ price: 100 })] });
    expect(() => calculateDiscount(cart, 150)).toThrow('Discount cannot exceed 100%');
  });

  test('returns 0 when cart total is 0', () => {
    const cart = createCart({ items: [] });
    expect(calculateDiscount(cart, 20)).toBe(0);
  });
});

describe('applyBulkDiscount', () => {
  test('applies 10% discount when cart has 10+ items', () => {
    const items = Array.from({ length: 12 }, (_, i) => ({ id: `item-${i}`, name: `Item ${i}`, price: 10 }));
    expect(applyBulkDiscount(items)).toBe(108);
  });

  test('returns full total when cart has fewer than 10 items', () => {
    const items = Array.from({ length: 5 }, (_, i) => ({ id: `item-${i}`, name: `Item ${i}`, price: 10 }));
    expect(applyBulkDiscount(items)).toBe(50);
  });
});
```

---

## Advanced Mocking Patterns

### Vitest Mocking

```typescript
vi.mock('./database', () => ({
  getRecords: vi.fn().mockResolvedValue([{ id: 1, name: 'Test' }]),
}));
const spy = vi.spyOn(console, 'log').mockImplementation(() => {});
vi.useFakeTimers();
vi.setSystemTime(new Date('2024-01-15T12:00:00Z'));
beforeEach(() => { vi.clearAllMocks(); });
```

### Jest Equivalents

Replace `vi.` with `jest.`, `vi.mock` → `jest.mock`, `vi.fn()` → `jest.fn()`, `vi.spyOn` → `jest.spyOn`, `vi.useFakeTimers` → `jest.useFakeTimers`, `vi.clearAllMocks` → `jest.clearAllMocks`.

### Factory Functions

Always generate factory functions for test data. Never hardcode objects inline in multiple tests.

```typescript
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

function createItemList(count: number, overrides?: Partial<Item>): Item[] {
  return Array.from({ length: count }, (_, i) =>
    ({ id: `item-${i + 1}`, name: `Item ${i + 1}`, price: 10, ...overrides })
  );
}
```

### Dependency Mocking Reference

For each side-effect dependency:
- Network calls → `vi.mock('axios')` or mock global fetch
- Filesystem → `vi.mock('fs')` or `vi.mock('fs/promises')`
- Database → `vi.mock` at the client module
- Timers → `vi.useFakeTimers()`
- Random → `vi.spyOn(Math, 'random')`
- Environment → set in `beforeEach`, restore in `afterEach`
- Internal modules with side effects → `vi.mock('./dependency')`
