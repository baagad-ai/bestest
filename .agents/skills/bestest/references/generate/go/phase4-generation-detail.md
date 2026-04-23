# Phase 4 Generation Detail — Go

Complete mocking patterns, test helper functions, table-driven test patterns, and full example for Go test generation. This file is loaded on-demand when Phase 4 generation needs detailed patterns.

## Mocking Patterns

### Interface fake (preferred — Go idiomatic)

```go
// Fake implementation — simple, clear, no framework needed
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

func newFakeUserRepository(overrides ...func(*FakeUserRepository)) *FakeUserRepository {
    f := &FakeUserRepository{
        users: make(map[string]*User),
    }
    for _, o := range overrides {
        o(f)
    }
    return f
}
```

### testify/mock (for interaction testing)

```go
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

### gomock (for generated, type-safe mocks)

```go
//go:generate mockgen -source=user.go -destination=mock/user_mock.go -package=mock

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

### HTTP server mock

```go
func TestHTTPClient_HandlesResponse(t *testing.T) {
    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        fmt.Fprintln(w, `{"id":"1","name":"Alice"}`)
    }))
    defer server.Close()

    client := NewClient(server.URL)
    user, err := client.GetUser(context.Background(), "1")

    require.NoError(t, err)
    assert.Equal(t, "Alice", user.Name)
}
```

### Environment mocking

```go
func TestConfig_ReadsAPIKey(t *testing.T) {
    t.Setenv("API_KEY", "test-key-123")

    config := LoadConfig()

    assert.Equal(t, "test-key-123", config.APIKey)
}
```

### Filesystem testing

```go
func TestWritesOutput(t *testing.T) {
    dir := t.TempDir()
    outputPath := filepath.Join(dir, "result.json")

    err := WriteResults(outputPath, data)

    require.NoError(t, err)
    contents, err := os.ReadFile(outputPath)
    require.NoError(t, err)
    assert.Contains(t, string(contents), `"expected_field"`)
}
```

## Test Helper Functions

Always generate helper functions for test data construction. Never hardcode struct literals in multiple tests.

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

## Table-Driven Test Pattern

Use table-driven tests for parameterized testing of the same behavior with different inputs. This is the Go idiom — always prefer this over separate test functions for each input case.

```go
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
        {"negative price returns error", -10, 10, "percentage", 0, true},
        {"unknown mode returns error", 100, 10, "unknown", 0, true},
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

For error-testing with table-driven tests:
```go
func TestParseInput_RejectsInvalidInput(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        wantErr bool
    }{
        {"empty string", "", true},
        {"whitespace only", "   ", true},
        {"negative number", "-5", true},
        {"overflow", "99999999999999999999", true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            _, err := ParseInput(tt.input)
            require.Error(t, err)
        })
    }
}
```

## Complete Example: Well-Generated Test File

This is the target quality level for every generated file:

```go
package pricing

import (
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func newCart(items ...Item) *Cart {
    return &Cart{Items: items}
}

func newItem(overrides ...func(*Item)) Item {
    item := Item{ID: "item-1", Name: "Widget", Price: 10.0}
    for _, o := range overrides {
        o(&item)
    }
    return item
}

func TestCalculateDiscount_ReturnsReducedPrice_WhenPercentageIsValid(t *testing.T) {
    cart := newCart(newItem(withPrice(100)))

    result, err := CalculateDiscount(cart, 20)

    require.NoError(t, err)
    assert.Equal(t, 80.0, result)
}

func TestCalculateDiscount_ReturnsFullPrice_WhenDiscountIsZero(t *testing.T) {
    cart := newCart(newItem(withPrice(50)))

    result, err := CalculateDiscount(cart, 0)

    require.NoError(t, err)
    assert.Equal(t, 50.0, result)
}

func TestCalculateDiscount_ReturnsError_WhenDiscountExceeds100(t *testing.T) {
    cart := newCart(newItem(withPrice(100)))

    _, err := CalculateDiscount(cart, 150)

    require.Error(t, err)
    assert.Contains(t, err.Error(), "cannot exceed 100")
}

func TestCalculateDiscount_ReturnsZero_WhenCartTotalIsZero(t *testing.T) {
    cart := newCart()

    result, err := CalculateDiscount(cart, 20)

    require.NoError(t, err)
    assert.Equal(t, 0.0, result)
}

func TestApplyBulkDiscount_Applies10Percent_For10PlusItems(t *testing.T) {
    items := make([]Item, 12)
    for i := range items {
        items[i] = newItem(func(it *Item) { it.Price = 10.0 })
    }

    result := ApplyBulkDiscount(items)

    assert.Equal(t, 108.0, result) // 12 * 10 * 0.9
}

func TestApplyBulkDiscount_ReturnsFullTotal_ForFewerThan10Items(t *testing.T) {
    items := make([]Item, 5)
    for i := range items {
        items[i] = newItem(func(it *Item) { it.Price = 10.0 })
    }

    result := ApplyBulkDiscount(items)

    assert.Equal(t, 50.0, result) // 5 * 10 * 1.0
}
```
