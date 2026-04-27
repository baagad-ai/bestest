# Go Framework Decision Tree

Complete framework selection decision tree for Go repositories. The detection engine uses this tree to populate the `testFrameworks` and `e2eFramework` recommendations in the StackProfile when the primary language is Go.

## Decision Flow

### Step 1: Check for Existing Go Testing with testify

```
Has "github.com/stretchr/testify" in go.mod require directives?
├─ YES → Check customization depth
│         ├─ Has testify suite usage (suite.Suite embedding)? → Keep testify (full feature set)
│         ├─ Has testify mock usage (mock.Mock embedding)? → Keep testify (mocking in use)
│         ├─ Has testify http handlers (httptest.TestServer patterns)? → Keep testify
│         ├─ Has >50 test files already? → Keep testify (migration cost high)
│         └─ Simple setup with <20 test files? → Keep testify (already optimal)
│
│         Rationale: testify is the de facto standard assertion library for Go. It provides
│         readable assertions (assert.Equal, require.NoError) that are strictly superior to
│         the standard library's t.Errorf/t.Fatalf for test clarity and maintainability.
│         There is no reason to migrate away from testify.
│
│         Coverage: go test -coverprofile (built-in, no external tool needed)
│         Config file: go.mod (dependency management)
│
└─ NO → Proceed to Step 2
```

### Step 2: Check for Plain Go Testing Usage

```
Has *_test.go files using only testing.T (no testify imports)?
├─ YES → Evaluate migration feasibility
│         ├─ Heavy use of t.Run subtests with t.Errorf patterns? → Add testify alongside
│         │   (testify and stdlib testing coexist; no rewrite needed)
│         ├─ Complex table-driven tests with manual error checking? → Add testify
│         │   (assert.Equal reduces boilerplate in table-driven tests significantly)
│         └─ Simple test files with few assertions? → Add testify
│             (assert/require provide better failure messages for free)
│
│         Rationale: testify is a purely additive dependency. It does not replace the
│         testing package — it supplements it. Existing tests continue to work unchanged.
│         New tests can use testify assertions for better failure diagnostics.
│         Migration path: import testify in new tests, leave existing tests as-is.
│
│         Coverage: go test -coverprofile (built-in)
│
└─ NO → Proceed to Step 3
```

### Step 3: Default Recommendation

```
No existing test framework detected.
├─ Any Go project → Go testing package + testify (assert/require)
└─ Reasoning: Go's testing package provides the test runner, but testify's assert and
    require packages provide the assertion vocabulary. The combination is the universal
    choice for Go testing. testify does not replace testing.T — it wraps it with
    readable assertions like assert.Equal(t, expected, actual) and require.NoError(t, err).

    Install:
      go get github.com/stretchr/testify

    Table-driven test pattern (Go idiom):
      func TestAdd(t *testing.T) {
          tests := []struct {
              name     string
              a, b     int
              expected int
          }{
              {"positive numbers", 2, 3, 5},
              {"negative numbers", -1, -1, -2},
              {"zero", 0, 0, 0},
          }
          for _, tt := range tests {
              t.Run(tt.name, func(t *testing.T) {
                  result := Add(tt.a, tt.b)
                  assert.Equal(t, tt.expected, result)
              })
          }
      }
```

### Step 4: HTTP Framework Specialization

```
Which HTTP framework is detected in go.mod?
├─ Gin (gin-gonic/gin) → testify + httptest + gin test mode
│         Test mode: gin.SetMode(gin.TestMode)
│         Test client: httptest.NewServer or httptest.NewRecorder
│         Pattern: create gin.Engine, inject routes, use httptest to call handlers
│         Example:
│           w := httptest.NewRecorder()
│           req, _ := http.NewRequest("GET", "/ping", nil)
│           router.ServeHTTP(w, req)
│           assert.Equal(t, 200, w.Code)
│
├─ Echo (labstack/echo) → testify + httptest + echo.New()
│         Test client: echo.New() + e.ServeHTTP(httptest.NewRecorder(), req)
│         Pattern: create Echo instance, register handlers, use httptest
│         Example:
│           e := echo.New()
│           req := httptest.NewRequest(http.MethodGet, "/", nil)
│           rec := httptest.NewRecorder()
│           e.ServeHTTP(rec, req)
│           assert.Equal(t, http.StatusOK, rec.Code)
│
├─ Chi (go-chi/chi) → testify + httptest + chi routing
│         Test client: httptest.NewServer + chi router
│         Pattern: create chi.Mux, mount routes, httptest.NewServer
│
├─ Standard library net/http → testify + httptest
│         Test client: httptest.NewServer or httptest.NewRecorder
│         Pattern: handler tests via httptest, no framework overhead
│
├─ gRPC (google.golang.org/grpc) → testify + grpc/test + bufconn
│         Test client: bufconn listener for in-process gRPC testing
│         Pattern: create bufconn listener, dial with grpc.DialContext + WithInsecure
│
└─ Non-HTTP (CLI, library, data processing) → testify (no HTTP test utilities)
    Pattern: standard unit tests with table-driven approach
    No HTTP client needed
```

### Step 5: Mocking Strategy

```
Determine mocking approach based on Go idioms and existing dependencies.
├─ Go project (any)
│         ├─ Has "github.com/golang/mock" or "go.uber.org/mock" in go.mod? → Keep gomock
│         │   Pattern: mockgen generates mock implementations from interfaces
│         │   Usage: mockgen -source=interface.go -destination=mock/interface_mock.go
│         │   Generated mocks provide type-safe method expectations
│         │
│         ├─ Has "github.com/stretchr/testify/mock" usage? → Keep testify/mock
│         │   Pattern: embed mock.Mock in test struct, use On/Return
│         │   Usage: mock.On("MethodName", arg1, arg2).Return(result, nil)
│         │   Lighter weight than gomock, no code generation step
│         │
│         └─ No existing mocking → Interface-based mocking (Go idiom)
│             Primary strategy: define interfaces for external dependencies,
│             create test implementations (manual fakes/stubs)
│             Fallback: testify/mock for complex interaction testing
│             Go philosophy: prefer small interfaces + simple fakes over heavy mocking
│
│         Rationale: Go's implicit interface satisfaction makes it easy to create
│         lightweight fakes without a mocking framework. For simple cases, a struct
│         that implements the interface is clearer than a mock. For complex interaction
│         testing (verifying call order, multiple return values), testify/mock or
│         gomock add value.
│
│         Interface mocking pattern:
│           type UserRepository interface {
│               GetByID(ctx context.Context, id string) (*User, error)
│           }
│
│           // Fake for simple tests
│           type FakeUserRepository struct {
│               users map[string]*User
│           }
│           func (f *FakeUserRepository) GetByID(ctx context.Context, id string) (*User, error) {
│               return f.users[id], nil
│           }
│
│           // testify/mock for interaction tests
│           type MockUserRepository struct {
│               mock.Mock
│           }
│           func (m *MockUserRepository) GetByID(ctx context.Context, id string) (*User, error) {
│               args := m.Called(ctx, id)
│               return args.Get(0).(*User), args.Error(1)
│           }
```

### Step 6: Integration and E2E Testing

```
Does the project expose HTTP endpoints or external services?
├─ YES → Check for integration testing approach
│         ├─ Has Docker compose or testcontainers? → Integration tests with real services
│         │   Database: use testcontainers-go for PostgreSQL/MySQL/Redis containers
│         │   Pattern: create container in TestMain, connect, run tests, cleanup
│         │   Example:
│         │     ctx := context.Background()
│         │     pgContainer, _ := postgres.RunContainer(ctx,
│         │         testcontainers.WithImage("postgres:16-alpine"),
│         │         postgres.WithDatabase("testdb"),
│         │     )
│         │     defer pgContainer.Terminate(ctx)
│         │
│         ├─ Has Makefile with integration targets? → Respect existing integration setup
│         │   Check for tags: //go:build integration
│         │   Run separately: go test -tags=integration ./...
│         │
│         ├─ HTTP endpoints only → httptest-based integration tests
│         │   No browser automation needed — test via HTTP client
│         │   Use httptest.NewServer for full server integration
│         │
│         └─ gRPC services → grpc reflection + in-process testing
│             Use bufconn for in-process gRPC connections
│             Test service endpoints directly without network
│
├─ NO → Skip E2E framework recommendation
│         Non-HTTP Go projects (CLI, libraries, data pipelines) do not
│         need browser or HTTP-level E2E testing.
│
└─ Unknown → Present options, default to httptest integration tests
```

### Step 7: Coverage Provider

```
Determine coverage approach:
├─ Go built-in coverage (always available, no external dependency)
│         Run: go test -coverprofile=coverage.out ./...
│         Report: go tool cover -func=coverage.out (per-function breakdown)
│         HTML: go tool cover -html=coverage.out (visual report)
│         Branch coverage: -covermode=atomic for race-safe coverage
│         Total coverage: go tool cover -func=coverage.out | grep total | awk '{print $3}'
│
│         Configuration (go.mod or Makefile):
│           test:
│             go test -coverprofile=coverage.out -covermode=atomic ./...
│             go tool cover -func=coverage.out
│
│         CI integration:
│           go test -coverprofile=coverage.out -covermode=atomic ./...
│           go tool cover -func=coverage.out | grep total | awk '{print $3}'
│
│         Coverage enforcement:
│           Parse total percentage from go tool cover output
│           Compare against coverage target in .bestest/config.yaml
│
└─ Default → Go built-in coverage (covers 100% of Go testing scenarios)
    Go's coverage tooling is built into the toolchain — no external dependency
    needed. It supports statement coverage, mode selection (set, count, atomic),
    and per-function and per-block reporting. The only external tool needed is
    for coverage visualization (gocov, goveralls) in CI, which is optional.
```

## Confidence Thresholds for Recommendations

| Scenario | Confidence | Explanation |
|----------|------------|-------------|
| Existing testify detected → Keep testify | 0.95+ | testify is already optimal for Go |
| Existing plain testing.T → Add testify | 0.85+ | Purely additive, no migration risk |
| No existing framework → Go testing + testify | 0.95+ | Industry standard for Go testing |
| Gin detected → httptest + Gin test mode | 0.90+ | Standard Gin testing pattern |
| Echo detected → httptest + echo.New() | 0.90+ | Standard Echo testing pattern |
| Chi detected → httptest + chi.Mux | 0.90+ | Standard Chi testing pattern |
| gRPC detected → bufconn in-process | 0.85+ | Best practice for gRPC testing |
| gomock detected → Keep gomock | 0.90+ | Type-safe generated mocks |
| testify/mock detected → Keep testify/mock | 0.90+ | Lightweight, no code generation |
| No mocking detected → Interface fakes | 0.85+ | Go idiom, preferred for simple cases |
| testcontainers detected → Integration infra | 0.85+ | Best practice for service integration |
| Non-HTTP project → No E2E needed | 0.90+ | CLI/library projects don't need E2E |

## Decision Summary Table

| Detected Stack | Test Runner | Assertions | Mocking | Coverage | Integration | Config File |
|----------------|-------------|------------|---------|----------|-------------|-------------|
| Gin + testify | go test | testify assert/require | Interface fakes or testify/mock | go test -cover | httptest + Gin test mode | `go.mod` |
| Gin + gomock | go test | testify assert/require | gomock | go test -cover | httptest + Gin test mode | `go.mod` |
| Echo + testify | go test | testify assert/require | Interface fakes or testify/mock | go test -cover | httptest + echo.New() | `go.mod` |
| Chi + testify | go test | testify assert/require | Interface fakes or testify/mock | go test -cover | httptest + chi.Mux | `go.mod` |
| gRPC + testify | go test | testify assert/require | gomock or testify/mock | go test -cover | bufconn in-process | `go.mod` |
| stdlib HTTP + testify | go test | testify assert/require | Interface fakes | go test -cover | httptest | `go.mod` |
| CLI / Library | go test | testify assert/require | Interface fakes | go test -cover | Not applicable | `go.mod` |
| Existing testify (simple) | go test (keep) | testify (keep) | As-is | go test -cover | As-is | Existing config |
| Existing testify (complex) | go test (keep) | testify + suite/mock (keep) | As-is | go test -cover | As-is | Existing config |
| Existing plain testing.T | go test | Add testify | Add interface fakes | go test -cover | Depends on project type | `go.mod` |
| Monorepo (Go) | go test per module | testify per module | Per-module approach | go test -cover per module | Per-module approach | Root `go.mod` + per-module |

## ADR Template

When the detection engine makes a framework recommendation, document it as an Architecture Decision Record in `.bestest/adrs/`:

```markdown
# ADR-NNN: [Test Framework Selection]

## Status: Proposed

## Context
- **Languages detected**: [from StackProfile.languages]
- **Go version**: [from StackProfile.runtime.go or "unknown"]
- **HTTP framework**: [from StackProfile.frameworks or "none"]
- **Package management**: [Go modules, from StackProfile.packageManager]
- **Existing test framework**: [from StackProfile.testFrameworks.existing or "none"]
- **Mocking in use**: [detected or "none"]

## Decision
Adopt **Go testing package + testify** for [unit/integration] testing with [interface fakes / gomock / testify/mock] for mocking.

## Rationale
[Auto-populated from the decision tree path taken. Example:]
"Go's testing package provides the test runner. testify assert/require supplements it
with readable assertions. Gin detected → httptest.NewRecorder + gin.SetMode(gin.TestMode)
provides the standard Gin testing pattern. Interface-based fakes preferred for simple
mocking; testify/mock available for complex interaction testing. Coverage via go test
-coverprofile (built-in, no external dependency)."

## Consequences
- [Specific benefit from the recommendation]
- [Any trade-off or limitation]
- [Migration effort if changing from existing framework]

## Alternatives Considered
- **Plain testing.T**: [Standard library, no dependency, but verbose assertions and poor failure messages]
- **gocheck**: [Legacy, less active development, fewer ecosystem integrations]
- **ginkgo/gomega**: [BDD-style, powerful but adds cognitive overhead and diverges from Go idioms]
```

## Integration with Detection Engine

The Go decision tree is evaluated after the detection engine has populated all signal categories. The evaluation follows this sequence:

1. Build the StackProfile from all detected signals (including Go-specific signals)
2. Determine primary language → if Go, use this decision tree instead of js-ts-decision-tree, python-decision-tree, or java-decision-tree
3. Evaluate Step 1–7 in order (short-circuit on first match)
4. Populate `testFrameworks.recommended`, `e2eFramework.recommended`, and `coverage.recommended`
5. Generate ADR if the recommendation differs from existing setup
6. Route to the appropriate spoke command (init, generate, fix)

The decision tree is deterministic: the same StackProfile always produces the same recommendation. This ensures reproducibility and makes the recommendation auditable via the ADR.

## Common Dependency Recommendations by Use Case

| Use Case | Dependency | Why |
|----------|------------|-----|
| Assertions | github.com/stretchr/testify | Industry standard assertion library (assert/require/mock/suite) |
| HTTP testing | net/http/httptest (stdlib) | Built-in HTTP test server and recorder |
| Mocking (generated) | go.uber.org/mock | Type-safe mock generation via mockgen (successor to golang/mock) |
| Mocking (lightweight) | github.com/stretchr/testify/mock | No code generation, embed mock.Mock in test structs |
| Testcontainers | github.com/testcontainers/testcontainers-go | Docker-based integration testing |
| PostgreSQL testing | github.com/testcontainers/testcontainers-go + postgres module | Real PostgreSQL for integration tests |
| gRPC testing | google.golang.org/grpc/test/bufconn | In-process gRPC testing without network |
| Fuzz testing | go test -fuzz (Go 1.18+) | Built-in fuzz testing |
| Race detection | go test -race (built-in) | Race condition detection at test time |
| Coverage | go test -cover (built-in) | Statement coverage, no external dependency |
| Snapshot testing | github.com/bradleyjkemp/cupaloy | Snapshot-based assertions |
| Golden file testing | Standard library (os.ReadFile + compare) | Compare output against golden files |
| Parallel execution | t.Parallel() (built-in) | Run tests concurrently within a package |
| Benchmark | go test -bench (built-in) | Performance benchmarking |

## Go-Specific Testing Patterns

### Table-Driven Tests (Idiomatic Go)

```go
func TestParsePort(t *testing.T) {
    tests := []struct {
        name      string
        input     string
        expected  int
        wantError bool
    }{
        {"valid port", "8080", 8080, false},
        {"port zero", "0", 0, false},
        {"negative port", "-1", 0, true},
        {"too large", "65536", 0, true},
        {"not a number", "abc", 0, true},
        {"empty string", "", 0, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result, err := ParsePort(tt.input)
            if tt.wantError {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.Equal(t, tt.expected, result)
        })
    }
}
```

### Test Main Setup (Package-Level)

```go
func TestMain(m *testing.M) {
    // Setup: initialize test database, create temp directories, etc.
    db := setupTestDB()
    defer cleanupTestDB(db)

    // Run all tests
    code := m.Run()

    // Cleanup
    os.Exit(code)
}
```

### Subtests with t.Run

```go
func TestUserService(t *testing.T) {
    t.Run("Create", func(t *testing.T) {
        // Test user creation
    })
    t.Run("GetByID", func(t *testing.T) {
        // Test user retrieval
    })
    t.Run("Update", func(t *testing.T) {
        // Test user update
    })
    t.Run("Delete", func(t *testing.T) {
        // Test user deletion
    })
}
```

### HTTP Handler Testing

```go
func TestHealthHandler(t *testing.T) {
    req := httptest.NewRequest(http.MethodGet, "/health", nil)
    rec := httptest.NewRecorder()

    handler := http.HandlerFunc(HealthHandler)
    handler.ServeHTTP(rec, req)

    assert.Equal(t, http.StatusOK, rec.Code)

    var response map[string]string
    err := json.Unmarshal(rec.Body.Bytes(), &response)
    require.NoError(t, err)
    assert.Equal(t, "ok", response["status"])
}
```

### Interface Mocking (Go Idiom)

```go
// Production interface
type EmailSender interface {
    Send(to, subject, body string) error
}

// Simple fake for tests
type FakeEmailSender struct {
    SentEmails []string
}
func (f *FakeEmailSender) Send(to, subject, body string) error {
    f.SentEmails = append(f.SentEmails, to)
    return nil
}

// Usage in test
func TestWelcomeEmail(t *testing.T) {
    sender := &FakeEmailSender{}
    service := NewUserService(sender)

    err := service.Welcome("user@example.com")
    require.NoError(t, err)
    assert.Len(t, sender.SentEmails, 1)
    assert.Equal(t, "user@example.com", sender.SentEmails[0])
}
```
