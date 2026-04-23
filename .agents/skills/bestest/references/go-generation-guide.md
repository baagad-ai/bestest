# AI Test Generation Guide — Go

Authoritative reference for the 7-phase test generation pipeline used by `/bestest generate` for Go projects. This guide defines quality standards, scoring rubrics, and design patterns that every generated Go test must satisfy. The Go generation spoke (`references/spoke-generate-go.md`) consumes this guide during Phase 3 (strategy selection) and Phase 7 (quality audit).

**Scope:** Go projects using the standard `testing` package with testify assertions (primary), with notes for plain `testing.T` scenarios. All examples use testify-first syntax (`assert`/`require`) with standard library equivalents noted where relevant.

**Audience:** AI agents generating tests. This is not a human-facing tutorial — it is a machine-consumable specification for producing high-quality Go test suites.

---

## Phase 1: Code Analysis

Before writing any test, analyze the target source file across five dimensions. Each dimension determines a different aspect of the test strategy.

### Exports

Identify every exported function, type, method, interface, and constant. Each exported symbol is a testable unit. Classify by type:

| Symbol Type | Test Priority | Analysis Focus |
|-------------|---------------|----------------|
| Function | High | Input/output contract, edge cases, error returns |
| Method (on type) | High | Receiver state transitions, method behavior |
| Interface | High | Contract compliance, mock/fake implementations |
| Struct (with methods) | High | Constructor/factory, public methods, field access |
| Struct (data-only) | Medium | Validation, zero-value behavior, JSON serialization |
| Constant / enum (iota) | Low | Value correctness |
| Unexported symbol | Low | Test indirectly via exported API |

**Decision rule:** If a symbol has runtime behavior (functions, methods, interface implementations), it needs tests. If it is purely declarative (type aliases, constants), skip it. Unexported symbols are tested indirectly through their exported callers unless they contain complex logic warranting direct testing via `internal_test.go` (same-package test files).

### Type Signatures

Extract the full function signature for every function and method. Go's explicit type system defines the input space and output contract:

```go
// Source
func ParseConfig(raw string, defaults *Config) (*Config, error)

// Analysis
// - Input space: any string + optional Config override pointer (nil allowed)
// - Output contract: *Config pointer (nil on error) + error (nil on success)
// - Edge cases: empty string, malformed YAML/JSON, nil defaults, nil input
// - Error returns: likely returns error on invalid input (verify from source)
// - Pointer semantics: caller must check error before using *Config
```

Go's explicit error return means every function has at least two test cases: the happy path (nil error) and the error path (non-nil error). The type signature tells you exactly which cases to generate.

**Go-specific analysis:** Pay attention to:
- **Value vs pointer receivers:** `func (s MyStruct)` vs `func (s *MyStruct)` — pointer receivers mutate state; value receivers don't.
- **Variadic functions:** `func Join(sep string, elems ...string)` — test with zero, one, and many variadic args.
- **Multiple return values:** Every `(result, error)` pair needs both success and failure tests.
- **Context parameter:** `func (s *Service) DoWork(ctx context.Context, ...) error` — test context cancellation and timeout.
- **Interface parameters:** `func Process(repo DataRepository)` — needs a mock or fake implementation.

### Dependencies

Map every import to determine what needs mocking:

1. **Pure logic imports** (standard library `strings`, `strconv`, `math`) — No mock needed; test with real implementation.
2. **Side-effect imports** (database drivers, HTTP clients, filesystem `os`) — Mock at the package boundary using interfaces and dependency injection.
3. **Framework imports** (Gin, Echo, gRPC) — Use framework-specific test utilities (`httptest.NewRecorder`, `httptest.NewServer`).
4. **Internal package imports** (other project packages) — Mock only if the dependency has side effects or complex setup. Use interfaces for testability.

**Decision rule:** Mock at architectural boundaries (network, filesystem, database, external services), never at internal function boundaries. Go's implicit interface satisfaction makes boundary mocking natural — define small interfaces and inject them.

**Go import analysis patterns:**

```go
// These imports indicate side effects that need mocking:
import (
    "database/sql"           // → Mock via interface or sqlmock
    "net/http"               // → Use httptest.NewServer/NewRecorder
    "os"                     // → Use t.TempDir() for filesystem tests
    "time"                   // → Mock via interface or inject clock
    "context"                // → Test cancellation directly (no mock needed)
)

// These imports are pure logic (no mock needed):
import (
    "strings"
    "strconv"
    "encoding/json"
    "math"
)
```

### Side Effects

Identify all side effects in the package:

- **Network calls:** `http.Get/Post`, `grpc.Dial`, custom HTTP clients
- **Filesystem:** `os.Open/Create`, `os.ReadFile/WriteFile`, `filepath.Walk`
- **Timers:** `time.Now()`, `time.Sleep()`, `time.After()`, `time.NewTicker()`
- **Global state:** `os.Getenv`, package-level `var` with mutation, `sync.Once`
- **Database:** `database/sql`, ORM queries, migration operations
- **External services:** Redis, message queues, S3, gRPC services
- **Goroutines:** `go func()`, channels with external I/O, unbuffered channel sends

Each side effect must be controlled in tests. Go's primary control mechanism is **interface-based dependency injection**. See Phase 4 for mocking patterns.

### Complexity

Estimate cyclomatic complexity to determine test count:

| Complexity | Minimum Tests | Strategy |
|------------|---------------|----------|
| 1-3 (simple) | 2-3 | Happy path + 1-2 error cases |
| 4-8 (moderate) | 4-6 | Each branch via table-driven tests |
| 9-15 (complex) | 6-10 | Full branch coverage + error paths + edge cases |
| 16+ (very complex) | 10+ | Consider splitting the function |

**Go complexity indicator:** Functions with many `if err != nil` branches may appear complex but often follow a linear error-checking pattern. Count only branching logic (if/else, switch), not linear error guards.

### Prioritization

When generating tests for multiple targets, sort by:

1. **Criticality:** Entry points (main, HTTP handlers), auth, data handling, payment logic first
2. **Risk:** High-complexity functions with many branches
3. **Coverage gap:** Packages with zero existing `_test.go` files
4. **Stability:** Prefer stable exported APIs over experimental packages

---

## Phase 2: Test Strategy Selection

Match each exported symbol to a test strategy based on its type and dependencies. The decision matrix below maps Go code types to strategies.

### Decision Matrix

| Code Type | Strategy | Test Focus | Framework Utilities |
|-----------|----------|------------|---------------------|
| Pure function | Table-driven input/output assertions | Transform correctness, edge cases | Anonymous struct test cases |
| Method on struct | State transition tests | Receiver mutations, method interactions | Fresh instance per test case |
| Interface implementation | Contract compliance tests | Every interface method behavior | Mock/fake implementations |
| HTTP handler | httptest request/response | Status codes, response body, headers | `httptest.NewRecorder`, `httptest.NewServer` |
| gRPC service | In-process gRPC with bufconn | Request/response, error codes, streaming | `bufconn` listener, `grpc.DialContext` |
| Database operation | sqlmock or interface mock | Query correctness, transaction handling | `DATA-DOG/go-sqlmock`, test transactions |
| Goroutine/concurrent | Race detector + channel assertions | Concurrency safety, channel behavior | `go test -race`, `sync.WaitGroup` |
| Middleware (HTTP) | Handler chain testing | Request mutation, response modification | `httptest.NewRecorder`, chained handlers |

### Pure Functions

Test every pure function with table-driven tests. This is the Go idiom for parameterized testing.

```go
// Source: calc/discount.go
func CalculateDiscount(price float64, percent float64, mode string) (float64, error) {
    if price < 0 {
        return 0, fmt.Errorf("price cannot be negative: %f", price)
    }
    switch mode {
    case "percentage":
        return price * (1 - percent/100), nil
    case "flat":
        return price - percent, nil
    default:
        return 0, fmt.Errorf("unknown mode: %s", mode)
    }
}

// Test: table-driven with testify assertions
func TestCalculateDiscount(t *testing.T) {
    tests := []struct {
        name     string
        price    float64
        percent  float64
        mode     string
        expected float64
        wantErr  bool
    }{
        {"percentage discount", 100, 10, "percentage", 90, false},
        {"flat discount", 100, 5, "flat", 95, false},
        {"zero price", 0, 10, "percentage", 0, false},
        {"zero percent", 50, 0, "percentage", 50, false},
        {"negative price", -10, 10, "percentage", 0, true},
        {"unknown mode", 100, 10, "unknown", 0, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result, err := CalculateDiscount(tt.price, tt.percent, tt.mode)
            if tt.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.Equal(t, tt.expected, result)
        })
    }
}
```

### Methods on Structs

Test constructor/factory, public methods, and state transitions. Create a fresh instance per test case.

```go
// Source: cart/cart.go
type ShoppingCart struct {
    items []Item
}

func NewShoppingCart() *ShoppingCart {
    return &ShoppingCart{items: []Item{}}
}

func (c *ShoppingCart) AddItem(item Item) {
    c.items = append(c.items, item)
}

func (c *ShoppingCart) Total() float64 {
    total := 0.0
    for _, item := range c.items {
        total += item.Price
    }
    return total
}

// Test: fresh cart per test
func TestShoppingCart_AddItem(t *testing.T) {
    cart := NewShoppingCart()
    item := Item{Name: "Widget", Price: 9.99}

    cart.AddItem(item)

    assert.Len(t, cart.items, 1)
    assert.Equal(t, item, cart.items[0])
}

func TestShoppingCart_Total(t *testing.T) {
    cart := NewShoppingCart()
    cart.AddItem(Item{Name: "A", Price: 10.00})
    cart.AddItem(Item{Name: "B", Price: 5.50})

    assert.Equal(t, 15.50, cart.Total())
}

func TestShoppingCart_TotalEmptyCart(t *testing.T) {
    cart := NewShoppingCart()

    assert.Equal(t, 0.0, cart.Total())
}
```

### HTTP Handlers (stdlib net/http)

Test handler functions using `httptest.NewRecorder`.

```go
// Source: handlers/users.go
func GetUserHandler(store UserStore) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        id := r.URL.Query().Get("id")
        if id == "" {
            http.Error(w, "missing id", http.StatusBadRequest)
            return
        }
        user, err := store.GetByID(r.Context(), id)
        if err != nil {
            http.Error(w, "not found", http.StatusNotFound)
            return
        }
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(user)
    }
}

// Test: httptest.NewRecorder
func TestGetUserHandler_ReturnsUser(t *testing.T) {
    mockStore := &MockUserStore{
        GetByIDFunc: func(ctx context.Context, id string) (*User, error) {
            return &User{ID: "1", Name: "Alice"}, nil
        },
    }
    handler := GetUserHandler(mockStore)

    req := httptest.NewRequest(http.MethodGet, "/users?id=1", nil)
    rec := httptest.NewRecorder()

    handler.ServeHTTP(rec, req)

    assert.Equal(t, http.StatusOK, rec.Code)
    var user User
    require.NoError(t, json.NewDecoder(rec.Body).Decode(&user))
    assert.Equal(t, "Alice", user.Name)
}

func TestGetUserHandler_Returns400ForMissingID(t *testing.T) {
    handler := GetUserHandler(&MockUserStore{})

    req := httptest.NewRequest(http.MethodGet, "/users", nil)
    rec := httptest.NewRecorder()

    handler.ServeHTTP(rec, req)

    assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestGetUserHandler_Returns404ForMissingUser(t *testing.T) {
    mockStore := &MockUserStore{
        GetByIDFunc: func(ctx context.Context, id string) (*User, error) {
            return nil, fmt.Errorf("not found")
        },
    }
    handler := GetUserHandler(mockStore)

    req := httptest.NewRequest(http.MethodGet, "/users?id=999", nil)
    rec := httptest.NewRecorder()

    handler.ServeHTTP(rec, req)

    assert.Equal(t, http.StatusNotFound, rec.Code)
}
```

### Interface Implementations

Test that implementations satisfy their interface contract. Use compile-time interface checks and behavioral tests.

```go
// Source: store/user.go
type UserStore interface {
    GetByID(ctx context.Context, id string) (*User, error)
    Create(ctx context.Context, user *User) error
    Delete(ctx context.Context, id string) error
}

// Test: compile-time interface check
func TestMemoryUserStore_ImplementsUserStore(t *testing.T) {
    var _ UserStore = (*MemoryUserStore)(nil)
}

func TestMemoryUserStore_CreateAndRetrieve(t *testing.T) {
    store := NewMemoryUserStore()
    ctx := context.Background()

    user := &User{Name: "Alice", Email: "alice@test.com"}
    require.NoError(t, store.Create(ctx, user))

    found, err := store.GetByID(ctx, user.ID)
    require.NoError(t, err)
    assert.Equal(t, "Alice", found.Name)
}

func TestMemoryUserStore_GetByID_NotFound(t *testing.T) {
    store := NewMemoryUserStore()
    ctx := context.Background()

    _, err := store.GetByID(ctx, "nonexistent")
    assert.Error(t, err)
}

func TestMemoryUserStore_Delete(t *testing.T) {
    store := NewMemoryUserStore()
    ctx := context.Background()

    user := &User{Name: "Alice"}
    require.NoError(t, store.Create(ctx, user))
    require.NoError(t, store.Delete(ctx, user.ID))

    _, err := store.GetByID(ctx, user.ID)
    assert.Error(t, err)
}
```

### Concurrent Code

Test goroutine safety with the race detector enabled.

```go
// Source: cache/safe_cache.go
type SafeCache struct {
    mu    sync.RWMutex
    items map[string]interface{}
}

func (c *SafeCache) Get(key string) (interface{}, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    val, ok := c.items[key]
    return val, ok
}

func (c *SafeCache) Set(key string, value interface{}) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = value
}

// Test: concurrent access with race detection (run with -race)
func TestSafeCache_ConcurrentAccess(t *testing.T) {
    cache := &SafeCache{items: make(map[string]interface{})}
    var wg sync.WaitGroup

    for i := 0; i < 100; i++ {
        wg.Add(2)
        go func(i int) {
            defer wg.Done()
            cache.Set(fmt.Sprintf("key-%d", i), i)
        }(i)
        go func(i int) {
            defer wg.Done()
            cache.Get(fmt.Sprintf("key-%d", i))
        }(i)
    }

    wg.Wait()
    // No assertions needed — the race detector will flag data races
    // This test passes if no race condition is detected
}
```

---

## Phase 3: Data Generation

### Table-Driven Test Data

Go's table-driven test pattern uses anonymous structs to define test cases. This is the idiomatic approach for parameterized testing in Go.

```go
// Standard table-driven test structure
func TestValidateAge(t *testing.T) {
    tests := []struct {
        name    string
        age     int
        wantErr bool
        errMsg  string
    }{
        {"negative age is invalid", -1, true, "age must be positive"},
        {"zero age is valid", 0, false, ""},
        {"minor age is valid", 12, false, ""},
        {"adult age is valid", 35, false, ""},
        {"senior age is valid", 75, false, ""},
        {"extreme age is invalid", 200, true, "age exceeds maximum"},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateAge(tt.age)
            if tt.wantErr {
                require.Error(t, err)
                assert.Contains(t, err.Error(), tt.errMsg)
                return
            }
            require.NoError(t, err)
        })
    }
}
```

### Equivalence Class Partitioning

Divide the input space into equivalence classes. One test per class is sufficient.

```go
// For a function that processes ages (0-150):
// Class 1: Negative (invalid) → -1
// Class 2: Zero (boundary) → 0
// Class 3: Valid range (1-17, minor) → 12
// Class 4: Valid range (18-64, adult) → 35
// Class 5: Valid range (65-150, senior) → 75
// Class 6: Over maximum (invalid) → 200

func TestProcessAge_EquivalenceClasses(t *testing.T) {
    tests := []struct {
        name    string
        age     int
        wantErr bool
    }{
        {"negative age", -1, true},
        {"boundary zero", 0, false},
        {"minor", 12, false},
        {"adult", 35, false},
        {"senior", 75, false},
        {"over maximum", 200, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result, err := ProcessAge(tt.age)
            if tt.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.NotNil(t, result)
        })
    }
}
```

### Boundary Value Analysis

Test at the boundaries of each equivalence class. For numeric ranges `[a, b]`, test `a-1`, `a`, `a+1`, `b-1`, `b`, `b+1`.

```go
// For a function accepting 1-100 inclusive:
func TestValidateRange_BoundaryValues(t *testing.T) {
    tests := []struct {
        name    string
        value   int
        wantErr bool
    }{
        {"just below minimum", 0, true},
        {"minimum boundary", 1, false},
        {"just above minimum", 2, false},
        {"just below maximum", 99, false},
        {"maximum boundary", 100, false},
        {"just above maximum", 101, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ok, err := ValidateRange(tt.value)
            if tt.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.True(t, ok)
        })
    }
}
```

### Test Helper Functions

Always use helper functions for test data construction. Never hardcode struct literals in multiple tests.

```go
// Helper function pattern — generates valid data with sensible defaults
func newUser(overrides ...func(*User)) *User {
    u := &User{
        ID:        "user-1",
        Name:      "Test User",
        Email:     "test@example.com",
        Role:      "viewer",
        CreatedAt: time.Date(2024, 1, 15, 0, 0, 0, 0, time.UTC),
    }
    for _, o := range overrides {
        o(u)
    }
    return u
}

// Usage — each test specifies only what it needs
func TestAdminCanDeleteResources(t *testing.T) {
    admin := newUser(func(u *User) { u.Role = "admin" })
    assert.True(t, CanDelete(admin))
}

func TestViewerCannotDeleteResources(t *testing.T) {
    viewer := newUser(func(u *User) { u.Role = "viewer" })
    assert.False(t, CanDelete(viewer))
}

// List helper — generates multiple distinct items
func newUserList(count int, overrides ...func(*User)) []*User {
    users := make([]*User, count)
    for i := 0; i < count; i++ {
        idx := i
        users[i] = newUser(append(overrides, func(u *User) {
            u.ID = fmt.Sprintf("user-%d", idx+1)
        })...)
    }
    return users
}
```

### Fuzz Testing (Go 1.18+)

For functions with complex input spaces, use Go's built-in fuzz testing:

```go
func FuzzParseInt(f *testing.F) {
    // Seed corpus
    f.Add("42")
    f.Add("-1")
    f.Add("0")
    f.Add("99999999999")

    f.Fuzz(func(t *testing.T, input string) {
        result, err := ParseInt(input)
        if err != nil {
            return // Error is acceptable for invalid input
        }
        // Round-trip: converting back should match
        assert.Equal(t, input, fmt.Sprintf("%d", result))
    })
}
```

---

## Phase 4: Test Writing

### Naming Convention

Test names must describe the specific scenario and expected outcome. In Go, use `Test` prefixed function names with descriptive sub-test names in table-driven tests. Follow the pattern: `Test{Unit}_{Behavior}_when_{Condition}` or use descriptive `t.Run` names.

```go
// BAD — vague
func TestWorks(t *testing.T) {}
func TestHandlesError(t *testing.T) {}

// GOOD — specific
func TestCalculateDiscount_ReturnsZero_WhenPriceIsZero(t *testing.T) {}
func TestFetchUser_ReturnsNetworkError_WhenFetchFails(t *testing.T) {}
func TestCart_ShowsEmptyState_WhenItemsListIsEmpty(t *testing.T) {}
```

**File naming:** Test files must end in `_test.go`. Go's test runner only discovers files with this suffix. Place test files in the same package (white-box testing) or a separate `*_test` package (black-box testing).

```
# White-box (same package — can test unexported symbols)
cart/
├── cart.go
└── cart_test.go       # package cart

# Black-box (different package — only exported symbols)
cart/
├── cart.go
└── cart_test/         # package cart_test
    └── cart_test.go
```

**Decision rule:** Default to white-box testing (same package). Use black-box testing only when explicitly testing the public API surface. The generation spoke should generate white-box tests unless the config specifies black-box.

### Arrange-Act-Assert Structure

Every test body must follow this three-part structure. Separate each section with a blank line.

```go
func TestCalculateTotal_AppliesBulkDiscount(t *testing.T) {
    // Arrange
    items := createItemList(12, 10.0)

    // Act
    total := CalculateTotal(items)

    // Assert
    assert.Equal(t, 108.0, total) // 12 * 10 * 0.9
}
```

### Single Assertion Per Concept

Each test should verify one logical concept. Multiple `assert` calls that verify different aspects of the same concept are fine. Multiple unrelated assertions belong in separate tests.

```go
// GOOD — multiple asserts, one concept (response shape)
func TestCreateUser_ReturnsUserWithGeneratedID(t *testing.T) {
    user := CreateUser("Alice")

    assert.NotEmpty(t, user.ID)
    assert.Equal(t, "Alice", user.Name)
}

// BAD — two unrelated concepts in one test
func TestCreateUser_Works(t *testing.T) {
    user := CreateUser("Alice")
    assert.Equal(t, "Alice", user.Name)           // Concept 1: name
    assert.True(t, emailService.WasCalled())       // Concept 2: side effect
}
```

### Mocking Guidelines

**Rule 1: Mock at boundaries via interfaces.** Go's implicit interface satisfaction makes this natural. Define interfaces for external dependencies and inject them.

```go
// BAD — calling concrete dependency directly
func NewService() *Service {
    return &Service{db: postgres.Connect()} // Hard to test
}

// GOOD — accept interface for testability
type Database interface {
    GetUser(ctx context.Context, id string) (*User, error)
}

func NewService(db Database) *Service {
    return &Service{db: db} // Inject interface
}
```

**Rule 2: Prefer simple fakes over complex mocks.** Go culture favors small interfaces with hand-written test implementations.

```go
// Fake — simple, clear, no framework needed
type FakeUserRepository struct {
    users map[string]*User
    err   error
}

func (f *FakeUserRepository) GetByID(ctx context.Context, id string) (*User, error) {
    if f.err != nil {
        return nil, f.err
    }
    return f.users[id], nil
}

// Usage in test
func TestGetUser_ReturnsUser(t *testing.T) {
    repo := &FakeUserRepository{
        users: map[string]*User{"1": {ID: "1", Name: "Alice"}},
    }
    service := NewUserService(repo)

    user, err := service.GetUser(context.Background(), "1")

    require.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
}
```

**Rule 3: Use testify/mock for interaction testing.** When you need to verify call order, arguments, or return specific errors:

```go
// testify/mock — for verifying interactions
type MockUserRepository struct {
    mock.Mock
}

func (m *MockUserRepository) GetByID(ctx context.Context, id string) (*User, error) {
    args := m.Called(ctx, id)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).(*User), args.Error(1)
}

// Usage in test
func TestGetUser_CallsRepository(t *testing.T) {
    repo := new(MockUserRepository)
    repo.On("GetByID", mock.Anything, "1").Return(&User{ID: "1", Name: "Alice"}, nil)
    service := NewUserService(repo)

    user, err := service.GetUser(context.Background(), "1")

    require.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
    repo.AssertExpectations(t)
}
```

**Rule 4: Use gomock for generated, type-safe mocks.** When the interface is complex or shared across many tests:

```go
//go:generate mockgen -source=user.go -destination=mock/user_mock.go -package=mock

// Usage in test (generated mock)
func TestUserService_Create(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()

    mockRepo := mock.NewMockUserRepository(ctrl)
    mockRepo.EXPECT().
        Create(gomock.Any(), gomock.Eq(&User{Name: "Alice"})).
        Return(nil)

    service := NewUserService(mockRepo)
    err := service.Create(context.Background(), &User{Name: "Alice"})

    require.NoError(t, err)
}
```

### Mocking Patterns Reference

| Concern | Pattern | Example |
|---------|---------|---------|
| Interface fake | Hand-written struct implementing interface | `type FakeDB struct{ users map[string]*User }` |
| testify/mock | Embed `mock.Mock`, use `On/Return` | `mockRepo.On("Get", "1").Return(user, nil)` |
| gomock | Generated mock via `mockgen` | `mockRepo.EXPECT().Get(gomock.Any(), "1")` |
| HTTP server mock | `httptest.NewServer` with custom handler | `httptest.NewServer(http.HandlerFunc(func(w,r){...}))` |
| Database mock | `go-sqlmock` for `database/sql` | `sqlmock.NewRows([]string{"id"}).AddRow("1")` |
| Time mock | Inject clock interface | `type Clock interface{ Now() time.Time }` |
| Environment | `t.Setenv` (Go 1.17+) | `t.Setenv("API_KEY", "test-key")` |
| Filesystem | `t.TempDir()` | `dir := t.TempDir()` (auto-cleaned) |
| Context cancellation | `context.WithCancel` / `context.WithTimeout` | `ctx, cancel := context.WithCancel(ctx)` |

### Test Helpers and Sub-Tests

Use `t.Run` for sub-tests (especially in table-driven patterns) and `t.Helper` for assertion helpers.

```go
// t.Helper marks the function as a test helper for better error reporting
func assertUserEqual(t *testing.T, expected, actual *User) {
    t.Helper()
    assert.Equal(t, expected.ID, actual.ID)
    assert.Equal(t, expected.Name, actual.Name)
    assert.Equal(t, expected.Email, actual.Email)
}

// t.Cleanup for resource cleanup (Go 1.14+)
func TestWithDatabase(t *testing.T) {
    db, err := sql.Open("sqlite3", ":memory:")
    require.NoError(t, err)
    t.Cleanup(func() { db.Close() })

    // db is available for all sub-tests
    t.Run("insert user", func(t *testing.T) {
        _, err := db.Exec("INSERT INTO users (name) VALUES (?)", "Alice")
        require.NoError(t, err)
    })
}
```

### Test File Organization

- **Same-package tests (`package math`):** Can access unexported symbols. Use for most unit tests.
- **External-package tests (`package math_test`):** Only exported symbols visible. Use for black-box API testing.
- **Test helpers (`testing` + `testify`):** Shared helpers can live in a `testutil` or `testhelpers` package.

```
service/
├── user.go              # Implementation
├── user_test.go         # package service (white-box)
├── handler.go           # HTTP handler
├── handler_test.go      # package service (white-box)
└── user_integration_test.go  # package service_test (black-box, //go:build integration)
```

---

## Phase 5: Verification Loop

The verification loop iterates: compile → run → coverage. Each step has a specific failure mode and fix protocol.

### Step 1: Compilation Verification

Run Go's compiler and vet tool on generated test files:

```bash
go vet ./...                              # Static analysis
go build ./...                            # Compilation check
go test -run='^$' ./...                   # Compile tests without running
```

**Failure protocol:**
- **Unused import** → Remove the import or add a blank identifier: `_ = "package"`
- **Import cycle** → Move the test to an external test package (`package xxx_test`)
- **Undefined symbol** → Fix the import path; verify the source file exports the symbol; check module path in `go.mod`
- **Type mismatch** → Fix the test's types; do not change source types to accommodate the test
- **Syntax error** → Fix the test code structure (missing braces, incorrect slice syntax, wrong var declaration)

**Maximum iterations:** 3. After 3 compilation failures on the same test, present to the user for manual resolution.

### Step 2: Execution

Run the generated tests:

```bash
go test -v -race ./path/to/package/
```

**Failure protocol:**
- **Test assertion fails** → Analyze the failure message. Determine if the test expectation is wrong or the source has a bug. Fix the test, never the source.
- **Race condition detected** → Add proper synchronization (mutex, channel) or use race-safe patterns in the test. If the race is in the source, note it.
- **Panic in test** → Check for nil pointer dereference, index out of range, or type assertion failure in test setup.
- **Timeout** → Check for unmocked blocking operations (network, channels, locks). Add proper context cancellation or mock slow dependencies.
- **Build error in test file** → Check for incorrect import paths, wrong module path, or missing test dependencies.

**Critical rule:** Never modify source code to make a test pass. If the source has a genuine bug discovered during test generation, note it in the test file as a comment and create a passing test that documents the current (possibly buggy) behavior.

```go
// NOTE: Source returns -1 for empty arrays, which may be a bug.
// This test documents current behavior for regression detection.
func TestFindMax_ReturnsNegativeOneForEmptyArray(t *testing.T) {
    result := FindMax([]int{})
    assert.Equal(t, -1, result)
}
```

**Maximum iterations:** 3 fix attempts per test. After 3 failures, skip the test and report it for manual resolution.

### Step 3: Coverage Analysis

Measure coverage contribution of the new tests:

```bash
go test -coverprofile=coverage.out -covermode=atomic ./path/to/package/
go tool cover -func=coverage.out
```

**Coverage thresholds:**
- Below 50% coverage → Add tests for uncovered functions
- Below 70% function coverage → Add tests for untested functions
- Below 60% statement coverage → Add tests for uncovered logic paths

**Coverage mode selection:**
- `set` (default): Did this statement run? Fast, but misses nuances.
- `count`: How many times did this statement run? Better for hot-path analysis.
- `atomic`: Thread-safe counting. Required when using `-race`.

**Anti-pattern to avoid:** Do not add tests solely to inflate coverage numbers. Each test must verify meaningful behavior. A test that calls a function without asserting anything is worse than no test at all.

### Step 4: Race Detection

Run tests with the race detector to catch data races:

```bash
go test -race ./path/to/package/
```

**Race detection protocol:**
- **Data race found** → Identify the shared variable and add proper synchronization. Common fixes: `sync.Mutex`, `sync.RWMutex`, channel-based communication, or `sync/atomic` operations.
- **Race in test setup** → Use `t.Parallel()` only when the test is truly independent and has no shared mutable state.
- **False positive (rare)** → Verify the race is real by examining the stack trace. If the race is in a read-only path, it may be benign but should still be fixed for correctness.

---

## Phase 6: Quality Audit

Every generated test is scored on a 0-100 scale across five dimensions. The minimum acceptable score is 70.

### Assertion Quality (0-30 points)

Measures whether assertions actually verify meaningful behavior.

| Score Range | Characteristics |
|-------------|-----------------|
| **25-30** | Specific values with `assert.Equal`, `require.NoError`, `assert.Contains`; edge cases covered; error paths tested with `require.Error` + `assert.Contains`; no bare `assert.True(t, ok)` when exact value is knowable |
| **18-24** | Mostly specific assertions; may miss some edge cases; 1-2 broad assertions on non-critical paths |
| **10-17** | Mix of specific and broad; missing edge cases; some `assert.NotNil` where exact value is knowable |
| **0-9** | Predominantly `assert.True(t, result)`, `assert.NoError` without checking error type, or `assert.NotNil`; missing error assertions |

**Scoring adjustments:**
- +3 per distinct edge case assertion
- +2 per error path assertion (using `require.Error` + `assert.Contains` or `assert.ErrorIs`)
- -5 per bare `assert.True(t, ok)` on a non-boolean value
- -8 per `assert.True(t, true)` or tautological assertion
- -10 per assertion comparing a value to itself

**Go assertion model note:** Testify's `assert` package provides rich comparison with detailed failure messages. Use `assert.Equal` for value comparison, `require.NoError` for error handling (stops test on failure), and `assert.Contains` for substring/collection checks. Prefer `require` for critical setup assertions (test cannot continue if they fail) and `assert` for behavioral assertions (test can continue to report more failures).

```go
// GOOD — testify assertion style
func TestDiscountAppliesPercentage(t *testing.T) {
    result, err := CalculateDiscount(100, 20)
    require.NoError(t, err)
    assert.Equal(t, 80.0, result)
}

// ACCEPTABLE but less idiomatic (stdlib only)
func TestDiscountAppliesPercentage(t *testing.T) {
    result, err := CalculateDiscount(100, 20)
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if result != 80.0 {
        t.Errorf("expected 80.0, got %f", result)
    }
}
```

### Test Structure (0-20 points)

Measures adherence to arrange-act-assert and naming conventions.

| Score Range | Characteristics |
|-------------|-----------------|
| **16-20** | Clear AAA separation; descriptive `Test` prefixed names; table-driven pattern for parameterized cases; single concept per test; no copy-paste structure |
| **11-15** | AAA mostly present; names are adequate; may test 2 concepts in one test |
| **6-10** | AAA inconsistent; vague names; multiple unrelated assertions; significant duplication |
| **0-5** | No structure; test names are generic (`Test1`, `TestIt`); large copy-pasted blocks |

**Scoring adjustments:**
- +2 per test with descriptive name following the `Test{Unit}_{Behavior}_when_{Condition}` pattern
- -3 per test with a name like `TestWorks`, `Test1`, or `TestFunction`
- -5 per test with no AAA separation at all
- +3 per properly structured table-driven test with named cases

### Independence (0-20 points)

Measures whether tests can run in any order, in isolation, without shared mutable state.

| Score Range | Characteristics |
|-------------|-----------------|
| **16-20** | All tests self-contained; fresh instances per test; no shared package-level mutable variables; proper cleanup via `t.Cleanup` |
| **11-15** | Mostly independent; may share read-only data; minor cleanup gaps |
| **6-10** | Some tests depend on shared state; cleanup present but incomplete; one test may affect another |
| **0-5** | Tests must run in order; shared mutable state across tests; no cleanup; package-level mutations |

**Scoring adjustments:**
- +3 per test helper function used instead of hardcoded struct literals
- -5 per package-level mutable variable modified across tests without `t.Cleanup` reset
- -10 per test that only passes when run after another specific test
- -15 per `t.Skip` left in committed code without a linked issue comment

**Go-specific independence note:** Go tests within a package share the same process. Package-level variables initialized in `TestMain` or `init()` persist across all tests in the package. Use `t.Cleanup()` to restore state, or construct fresh instances in each test.

### Coverage Value (0-15 points)

Measures whether tests cover meaningful paths, not just the happy path.

| Score Range | Characteristics |
|-------------|-----------------|
| **12-15** | Happy path + error paths + boundary values; tests meaningful branches; no coverage-only tests |
| **8-11** | Happy path + some error paths; may miss boundary values |
| **4-7** | Mostly happy path; error paths untested; tests only the obvious cases |
| **0-3** | Only happy path; tests that call code without asserting; coverage theater |

**Scoring adjustments:**
- +3 per error path test (using `require.Error` + error message assertion)
- +2 per boundary value test (using table-driven cases at equivalence class edges)
- -5 per test that calls a function but has no assertion on the result
- -8 per test that exists only to inflate line coverage

### Maintainability (0-15 points)

Measures how easy tests are to understand, modify, and extend.

| Score Range | Characteristics |
|-------------|-----------------|
| **12-15** | Helper functions for all data construction; clear intent; no magic numbers; no hardcoded IDs/dates; follows Go conventions |
| **8-11** | Some hardcoded data; mostly clear intent; may have a few magic numbers |
| **4-7** | Significant hardcoded data; unclear test purpose; inconsistent patterns |
| **0-3** | All data hardcoded; copy-pasted across tests; no helpers; magic numbers everywhere |

**Scoring adjustments:**
- +3 per helper function with sensible defaults and override support
- -2 per hardcoded date string that should use a helper or fixture
- -3 per magic number without an explanatory comment or named constant
- -5 per block of data copy-pasted between tests

### Score Examples

**90+ test (exemplary):**

```go
func TestCalculateDiscount_ReturnsReducedPrice_WhenPercentageIsValid(t *testing.T) {
    cart := newCart(withItems(newItem(withPrice(100))))

    result, err := CalculateDiscount(cart, 20)

    require.NoError(t, err)
    assert.Equal(t, 80.0, result)
}
```
- Assertion: 28/30 — specific value, error checked, meaningful scenario
- Structure: 18/20 — clear AAA, descriptive name, table-driven eligible
- Independence: 18/20 — fresh instance via helper, no shared state
- Coverage: 14/15 — tests core calculation logic
- Maintainability: 14/15 — helper functions, no magic numbers

**50 test (mediocre):**

```go
func TestDiscount_Works(t *testing.T) {
    cart := &Cart{Items: []Item{{Price: 100, ID: "item-1", Name: "Widget"}}, Total: 100}
    result, _ := CalculateDiscount(cart, 20)
    assert.True(t, result > 0)
}
```
- Assertion: 8/30 — bare `assert.True(t, result > 0)`, no edge cases, ignores error
- Structure: 10/20 — vague name, no clear AAA separation
- Independence: 15/20 — no shared state but hardcoded data
- Coverage: 8/15 — only happy path
- Maintainability: 9/15 — hardcoded struct literal

**<30 test (poor):**

```go
func Test1(t *testing.T) {
    result, _ := CalculateDiscount(&Cart{}, 20)
    assert.True(t, true)
}
```
- Assertion: 3/30 — tautological `assert.True(t, true)`, ignores error
- Structure: 2/20 — generic name, no AAA
- Independence: 10/20 — no shared state but inline data
- Coverage: 5/15 — empty input only
- Maintainability: 5/15 — inline struct, no helper

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
  - calc/discount_test.go: 5 tests (score: 88)
  - handlers/users_test.go: 4 tests (score: 76)
  - models/user_test.go: 3 tests (score: 82)
```

### Coverage Delta

```
Coverage change (before → after):
  - calc/discount.go: 0% → 92% statements, 100% functions
  - handlers/users.go: 45% → 78% statements, 100% functions
  - models/user.go: 0% → 85% statements, 100% functions
```

### Quality Scores

```
Average quality score: 82/100
  - Highest: discount_test.go (88) — strong assertions, good edge case coverage
  - Lowest: users_test.go (76) — missing error state test for 500 response
```

### Flagged Items

Items requiring manual review:

```
⚠️  handlers/users_test.go: No test for 500 internal server error response
⚠️  models/user_test.go: Test skipped after 3 failed fix attempts (import cycle)
```

### Auto-Commit Decision

Based on scores:
- All tests ≥ 70: **Auto-commit.** Summary displayed for awareness.
- Any test 50-69: **Auto-commit with flag.** User can review and request regeneration.
- Any test < 50: **Hold for review.** User must approve before commit.

---

## Go-Specific Anti-Patterns

These anti-patterns complement the general catalog in `references/anti-patterns.md` with Go/testing-specific guidance. The generation spoke must verify generated tests are free of these patterns.

### Critical (must fix)

- **Missing `_test.go` suffix** — Go's test runner only discovers files ending in `_test.go`. Files without this suffix are silently ignored during `go test`.
- **Incorrect package declaration** — Test files must declare either the same package (white-box) or `xxx_test` (black-box). Wrong package names cause compilation errors.
- **Race condition in test** — Tests that modify shared state without synchronization. Always run with `-race` flag. Data races in tests indicate data races in production code.
- **Unused import** — Go does not allow unused imports. Every import in a test file must be used. Run `goimports` to fix automatically.
- **Ignoring error return values** — Every `(result, error)` return must check the error. Using `_` for error returns in tests hides real bugs.

### High (should fix)

- **`time.Sleep` in tests** — Using `time.Sleep` to wait for async operations. Use channels with `select` + timeout, or `sync.WaitGroup`, or `require.Eventually`:
  ```go
  // BAD
  time.Sleep(2 * time.Second)
  assert.Equal(t, "done", state)

  // GOOD
  require.Eventually(t, func() bool {
      return state == "done"
  }, 5*time.Second, 100*time.Millisecond)
  ```
- **Unbounded goroutine leaks** — Tests that start goroutines without ensuring they complete. Use `runtime.NumGoroutine()` before and after, or use `goleak`:
  ```go
  func TestMain(m *testing.M) {
      goleak.VerifyTestMain(m)
  }
  ```
- **Missing `t.Helper()` on assertion helpers** — Custom test helpers that don't call `t.Helper()` report wrong line numbers on failure. Always mark helpers:
  ```go
  func assertStatusOK(t *testing.T, resp *http.Response) {
      t.Helper()
      assert.Equal(t, http.StatusOK, resp.StatusCode)
  }
  ```
- **Test interdependence via package state** — Tests that modify package-level variables (`var cache = ...`) without resetting between tests. Use `t.Cleanup()` or fresh instances.
- **Bare `t.Error` / `t.Fatal` without structured assertions** — Using `t.Error("expected X")` instead of `assert.Equal(t, expected, actual)`. Testify assertions provide better failure diagnostics with diffs.

### Medium (should minimize)

- **Table-driven tests without named cases** — Using integer indices instead of descriptive `name` fields in test case structs. Named cases produce readable `=== RUN TestFoo/my_descriptive_case` output.
- **Overly broad `mock.Anything`** — Using `mock.Anything` for all arguments instead of specific expected values. This makes the mock assertion meaningless.
- **Testing unexported functions via `internal_test.go`** — Creating a same-package test file solely to test an unexported function. Prefer testing through the exported API surface. Only test unexported functions directly when they contain complex logic.
- **Missing `t.Parallel()` for independent tests** — Long-running independent tests that could run in parallel. Add `t.Parallel()` at the start of the test function. Never use `t.Parallel()` with shared mutable state.

### Low (style)

- **Using `fmt.Sprintf` in test names** — Table-driven test names should be static strings, not formatted. Use a `name` field in the test case struct:
  ```go
  // BAD
  t.Run(fmt.Sprintf("test_%d", i), ...)

  // GOOD
  tests := []struct{
      name string
      // ...
  }{
      {"handles positive input", ...},
      {"handles negative input", ...},
  }
  ```
- **Hardcoded file paths** — Using `/tmp/test-*` or absolute paths. Use `t.TempDir()` for temporary files:
  ```go
  func TestWritesFile(t *testing.T) {
      dir := t.TempDir()
      outputPath := filepath.Join(dir, "result.json")
      WriteResults(outputPath)
      _, err := os.Stat(outputPath)
      assert.NoError(t, err)
  }
  ```
- **Missing `t.Helper()` on test setup functions** — Setup functions that call `t.Fatal` or `t.Error` without `t.Helper()` produce confusing stack traces.
- **Using `log` instead of `t.Log` in tests** — `log.Printf` output goes to stderr, not the test output. Use `t.Log` / `t.Logf` for test-visible output.

---

## Framework-Specific Patterns

### Gin Test Client (Complete Example)

```go
package handlers_test

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/gin-gonic/gin"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func setupGinRouter(store UserStore) *gin.Engine {
    gin.SetMode(gin.TestMode)
    r := gin.New()
    r.GET("/users/:id", GetUserHandler(store))
    r.POST("/users", CreateUserHandler(store))
    return r
}

func TestGin_GetUser_Returns200(t *testing.T) {
    mockStore := &FakeUserStore{
        users: map[string]*User{"1": {ID: "1", Name: "Alice"}},
    }
    router := setupGinRouter(mockStore)

    w := httptest.NewRecorder()
    req, _ := http.NewRequest(http.MethodGet, "/users/1", nil)
    router.ServeHTTP(w, req)

    assert.Equal(t, http.StatusOK, w.Code)
    var user User
    require.NoError(t, json.NewDecoder(w.Body).Decode(&user))
    assert.Equal(t, "Alice", user.Name)
}

func TestGin_GetUser_Returns404(t *testing.T) {
    mockStore := &FakeUserStore{users: map[string]*User{}}
    router := setupGinRouter(mockStore)

    w := httptest.NewRecorder()
    req, _ := http.NewRequest(http.MethodGet, "/users/999", nil)
    router.ServeHTTP(w, req)

    assert.Equal(t, http.StatusNotFound, w.Code)
}

func TestGin_CreateUser_Returns201(t *testing.T) {
    mockStore := &FakeUserStore{users: map[string]*User{}}
    router := setupGinRouter(mockStore)

    body := `{"name": "Alice", "email": "alice@test.com"}`
    w := httptest.NewRecorder()
    req, _ := http.NewRequest(http.MethodPost, "/users", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    router.ServeHTTP(w, req)

    assert.Equal(t, http.StatusCreated, w.Code)
    var user User
    require.NoError(t, json.NewDecoder(w.Body).Decode(&user))
    assert.Equal(t, "Alice", user.Name)
}

func TestGin_CreateUser_RejectsInvalidJSON(t *testing.T) {
    mockStore := &FakeUserStore{}
    router := setupGinRouter(mockStore)

    w := httptest.NewRecorder()
    req, _ := http.NewRequest(http.MethodPost, "/users", strings.NewReader("not json"))
    req.Header.Set("Content-Type", "application/json")
    router.ServeHTTP(w, req)

    assert.Equal(t, http.StatusBadRequest, w.Code)
}
```

### Echo Test Client (Complete Example)

```go
package handlers_test

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"

    "github.com/labstack/echo/v4"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func setupEchoRouter(store UserStore) *echo.Echo {
    e := echo.New()
    e.GET("/users/:id", GetUserHandler(store))
    e.POST("/users", CreateUserHandler(store))
    return e
}

func TestEcho_GetUser_Returns200(t *testing.T) {
    mockStore := &FakeUserStore{
        users: map[string]*User{"1": {ID: "1", Name: "Alice"}},
    }
    e := setupEchoRouter(mockStore)

    req := httptest.NewRequest(http.MethodGet, "/users/1", nil)
    rec := httptest.NewRecorder()
    e.ServeHTTP(rec, req)

    assert.Equal(t, http.StatusOK, rec.Code)
    var user User
    require.NoError(t, json.NewDecoder(rec.Body).Decode(&user))
    assert.Equal(t, "Alice", user.Name)
}

func TestEcho_GetUser_Returns404(t *testing.T) {
    mockStore := &FakeUserStore{users: map[string]*User{}}
    e := setupEchoRouter(mockStore)

    req := httptest.NewRequest(http.MethodGet, "/users/999", nil)
    rec := httptest.NewRecorder()
    e.ServeHTTP(rec, req)

    assert.Equal(t, http.StatusNotFound, rec.Code)
}

func TestEcho_CreateUser_Returns201(t *testing.T) {
    mockStore := &FakeUserStore{users: map[string]*User{}}
    e := setupEchoRouter(mockStore)

    body := `{"name": "Alice", "email": "alice@test.com"}`
    req := httptest.NewRequest(http.MethodPost, "/users", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    rec := httptest.NewRecorder()
    e.ServeHTTP(rec, req)

    assert.Equal(t, http.StatusCreated, rec.Code)
    var user User
    require.NoError(t, json.NewDecoder(rec.Body).Decode(&user))
    assert.Equal(t, "Alice", user.Name)
}

func TestEcho_CreateUser_RejectsDuplicateEmail(t *testing.T) {
    mockStore := &FakeUserStore{
        emails: map[string]bool{"alice@test.com": true},
    }
    e := setupEchoRouter(mockStore)

    body := `{"name": "Bob", "email": "alice@test.com"}`
    req := httptest.NewRequest(http.MethodPost, "/users", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    rec := httptest.NewRecorder()
    e.ServeHTTP(rec, req)

    assert.Equal(t, http.StatusConflict, rec.Code)
}
```

### Stdlib net/http Handler (Complete Example)

```go
package handlers_test

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestStdlibHandler_GetUser_Returns200(t *testing.T) {
    mockStore := &FakeUserStore{
        users: map[string]*User{"1": {ID: "1", Name: "Alice"}},
    }
    handler := GetUserHandler(mockStore)

    req := httptest.NewRequest(http.MethodGet, "/users?id=1", nil)
    rec := httptest.NewRecorder()
    handler(rec, req)

    assert.Equal(t, http.StatusOK, rec.Code)
    var user User
    require.NoError(t, json.NewDecoder(rec.Body).Decode(&user))
    assert.Equal(t, "Alice", user.Name)
}

func TestStdlibHandler_GetUser_Returns400ForMissingID(t *testing.T) {
    handler := GetUserHandler(&FakeUserStore{})

    req := httptest.NewRequest(http.MethodGet, "/users", nil)
    rec := httptest.NewRecorder()
    handler(rec, req)

    assert.Equal(t, http.StatusBadRequest, rec.Code)
}

func TestStdlibHandler_GetUser_Returns404ForMissingUser(t *testing.T) {
    mockStore := &FakeUserStore{users: map[string]*User{}}
    handler := GetUserHandler(mockStore)

    req := httptest.NewRequest(http.MethodGet, "/users?id=999", nil)
    rec := httptest.NewRecorder()
    handler(rec, req)

    assert.Equal(t, http.StatusNotFound, rec.Code)
}

func TestStdlibHandler_CreateUser_Returns201(t *testing.T) {
    mockStore := &FakeUserStore{users: map[string]*User{}}
    handler := CreateUserHandler(mockStore)

    body := `{"name": "Alice", "email": "alice@test.com"}`
    req := httptest.NewRequest(http.MethodPost, "/users", strings.NewReader(body))
    req.Header.Set("Content-Type", "application/json")
    rec := httptest.NewRecorder()
    handler(rec, req)

    assert.Equal(t, http.StatusCreated, rec.Code)
    var user User
    require.NoError(t, json.NewDecoder(rec.Body).Decode(&user))
    assert.Equal(t, "Alice", user.Name)
    assert.NotEmpty(t, user.ID)
}
```

### httptest.NewServer (Integration-Style Test)

```go
package handlers_test

import (
    "encoding/json"
    "io"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestFullServer_GetUsers_EmptyList(t *testing.T) {
    store := NewMemoryUserStore()
    mux := http.NewServeMux()
    RegisterHandlers(mux, store)

    server := httptest.NewServer(mux)
    defer server.Close()

    resp, err := http.Get(server.URL + "/users")
    require.NoError(t, err)
    defer resp.Body.Close()

    assert.Equal(t, http.StatusOK, resp.StatusCode)
    body, _ := io.ReadAll(resp.Body)
    assert.Equal(t, "[]\n", string(body))
}

func TestFullServer_CreateAndGetUser(t *testing.T) {
    store := NewMemoryUserStore()
    mux := http.NewServeMux()
    RegisterHandlers(mux, store)

    server := httptest.NewServer(mux)
    defer server.Close()

    // Create user
    createBody := `{"name": "Alice", "email": "alice@test.com"}`
    resp, err := http.Post(
        server.URL+"/users",
        "application/json",
        strings.NewReader(createBody),
    )
    require.NoError(t, err)
    assert.Equal(t, http.StatusCreated, resp.StatusCode)

    var created User
    require.NoError(t, json.NewDecoder(resp.Body).Decode(&created))
    resp.Body.Close()

    // Retrieve user
    resp, err = http.Get(server.URL + "/users/" + created.ID)
    require.NoError(t, err)
    defer resp.Body.Close()
    assert.Equal(t, http.StatusOK, resp.StatusCode)

    var retrieved User
    require.NoError(t, json.NewDecoder(resp.Body).Decode(&retrieved))
    assert.Equal(t, "Alice", retrieved.Name)
}
```

### gRPC Service Test (Complete Example)

```go
package service_test

import (
    "context"
    "net"
    "testing"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials/insecure"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    "google.golang.org/grpc/test/bufconn"
)

func setupGRPCServer(t *testing.T) (pb.UserServiceClient, func()) {
    t.Helper()
    lis := bufconn.Listen(1024 * 1024)
    s := grpc.NewServer()
    pb.RegisterUserServiceServer(s, &UserServer{})

    go func() {
        if err := s.Serve(lis); err != nil {
            t.Logf("server error: %v", err)
        }
    }()

    conn, err := grpc.DialContext(context.Background(), "bufnet",
        grpc.WithContextDialer(func(ctx context.Context, _ string) (net.Conn, error) {
            return lis.Dial()
        }),
        grpc.WithTransportCredentials(insecure.NewCredentials()),
    )
    require.NoError(t, err)

    client := pb.NewUserServiceClient(conn)
    cleanup := func() {
        conn.Close()
        s.Stop()
    }
    return client, cleanup
}

func TestGRPC_GetUser_ReturnsUser(t *testing.T) {
    client, cleanup := setupGRPCServer(t)
    defer cleanup()

    resp, err := client.GetUser(context.Background(), &pb.GetUserRequest{Id: "1"})

    require.NoError(t, err)
    assert.Equal(t, "1", resp.Id)
    assert.NotEmpty(t, resp.Name)
}

func TestGRPC_GetUser_ReturnsNotFound(t *testing.T) {
    client, cleanup := setupGRPCServer(t)
    defer cleanup()

    _, err := client.GetUser(context.Background(), &pb.GetUserRequest{Id: "nonexistent"})

    require.Error(t, err)
    assert.Contains(t, err.Error(), "not found")
}
```

---

## Quality Audit Checklist

This checklist maps to the anti-pattern categories defined in `references/anti-patterns.md` plus the Go-specific anti-patterns above. The generate spoke must verify generated tests pass all checks before presenting them to the user.

### Critical Checks (must pass — zero tolerance)

- [ ] **No tautological assertions** — No test compares a value to itself; no `assert.True(t, true)`
- [ ] **No hardcoded secrets** — No real-looking passwords, API keys, or tokens
- [ ] **No missing assertions** — Every `Test` function contains at least one `assert.*` or `require.*` call
- [ ] **Error returns are checked** — Every `(result, error)` return has the error checked with `require.NoError`, `require.Error`, or equivalent
- [ ] **No unused imports** — All imports in the test file are used (run `goimports`)
- [ ] **Race-free** — No data races when run with `go test -race`

### High Checks (should pass — flag if present)

- [ ] **No time.Sleep waits** — No `time.Sleep` with arbitrary delays in tests; use `require.Eventually` or channel-based waiting
- [ ] **No test interdependencies** — No shared mutable package-level state without `t.Cleanup`
- [ ] **No goroutine leaks** — All started goroutines are tracked and complete; consider `goleak.VerifyTestMain`
- [ ] **No flaky indicators** — `time.Now()`, unmocked HTTP calls, and uncontrolled concurrency are properly handled
- [ ] **`t.Helper()` on custom helpers** — All custom test helper functions call `t.Helper()`

### Medium Checks (should minimize — acceptable in limited cases)

- [ ] **No overly broad assertions** — No bare `assert.True(t, ok)` on non-boolean values, no `assert.NotNil` when exact value is knowable
- [ ] **No implementation coupling** — No accessing unexported fields via reflection; test through exported API
- [ ] **Mock assertions are specific** — `mock.On` and `EXPECT` use specific arguments, not always `mock.Anything`
- [ ] **Table-driven tests have named cases** — Every `[]struct` test case has a descriptive `name` field

### Low Checks (style — address when convenient)

- [ ] **No duplicate test logic** — No near-identical test blocks; use table-driven tests for parameterized cases
- [ ] **Meaningful test names** — No `Test1`, `TestFunction`, or `TestItWorks` names
- [ ] **Helper functions for data** — No hardcoded struct literals repeated across tests
- [ ] **Proper cleanup** — `t.Cleanup()` for resources; `t.TempDir()` for temp files; `t.Setenv()` for env vars
- [ ] **Using testify assertions** — `assert.Equal(t, expected, actual)` not `if a != b { t.Error(...) }`
- [ ] **Test file naming** — Files end in `_test.go`; package declaration is correct (same package or `xxx_test`)

---

## Cross-Reference

This guide is consumed by:
- **Go generation spoke** (`references/spoke-generate-go.md`) — Phase 4 (test writing patterns) and Phase 7 (quality audit scoring)
- **Anti-pattern catalog** (`references/anti-patterns.md`) — Quality audit checklist maps to the 20 anti-pattern categories; the generate spoke must ensure generated tests are free of all critical and high severity anti-patterns
- **Config schema** (`references/config-schema.md`) — Coverage thresholds and framework settings from project configuration
- **Go decision tree** (`references/go-decision-tree.md`) — Framework selection for Go projects, which determines which patterns in this guide to apply
- **AI generation guide** (`references/ai-generation-guide.md`) — Language-agnostic generation pipeline (7 phases); this guide provides the Go-specific implementation of each phase
