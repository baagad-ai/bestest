Part of **/bestest init** (see references/spoke-init.md). Load on-demand when reaching Phase 5.

## Phase 5 — Install Dependencies

Build the dependency list from the framework recommendation and present it to the user before installing.

### Dependency Lists by Framework

#### Vitest (any variant)

Core:
```
vitest @vitest/coverage-v8
```

Frontend additions (based on detected stack):
- React: `@vitejs/plugin-react jsdom`
- Vue: `@vitejs/plugin-vue jsdom`
- Svelte: `@sveltejs/vite-plugin-svelte`
- SolidJS: `vite-plugin-solid jsdom`

E2E (if enabled):
```
@playwright/test
```

#### Jest

Core:
```
jest @swc/core @swc/jest
```

Frontend additions:
- React: `@testing-library/react @testing-library/jest-dom jsdom`
- Vue: `@vue/test-utils jsdom`

E2E (if enabled):
```
@playwright/test
```

#### pytest (Python)

Core:
```
pytest pytest-cov
```

Framework-specific additions:
- FastAPI: `httpx pytest-asyncio`
- Flask: `pytest-flask` (or plain Flask test client)
- Django: `pytest-django`

Common plugins (add based on detection):
- Async detected: `pytest-asyncio`
- Mocking needed: `pytest-mock`
- E2E/browser testing: `pytest-playwright`
- Environment variables: `pytest-env`
- Parallel execution: `pytest-xdist`

E2E (if enabled):
```
pytest-playwright
```

#### JUnit 5 (Java)

Core (Gradle — `build.gradle`):
```
testImplementation 'org.junit.jupiter:junit-jupiter:5.10.2'
testImplementation 'org.mockito:mockito-core:5.11.0'
testImplementation 'org.assertj:assertj-core:3.25.3'
testRuntimeOnly 'org.junit.platform:junit-platform-launcher'
```

Core (Maven — `pom.xml`):
```xml
<dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter</artifactId>
    <version>5.10.2</version>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.mockito</groupId>
    <artifactId>mockito-core</artifactId>
    <version>5.11.0</version>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.assertj</groupId>
    <artifactId>assertj-core</artifactId>
    <version>3.25.3</version>
    <scope>test</scope>
</dependency>
```

Spring Boot additions (Gradle):
```
testImplementation 'org.springframework.boot:spring-boot-starter-test'
testImplementation 'org.testcontainers:junit-jupiter:1.19.7'
```

Spring Boot additions (Maven):
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>junit-jupiter</artifactId>
    <version>1.19.7</version>
    <scope>test</scope>
</dependency>
```

JaCoCo coverage plugin:

Gradle (`build.gradle`):
```groovy
plugins {
    id 'jacoco'
}
jacoco {
    toolVersion = "0.8.11"
}
test {
    finalizedBy jacocoTestReport
}
jacocoTestReport {
    dependsOn test
    reports {
        xml.required = true
        html.required = true
    }
}
```

Maven (`pom.xml`):
```xml
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
        <execution>
            <goals><goal>prepare-agent</goal></goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>test</phase>
            <goals><goal>report</goal></goals>
        </execution>
    </executions>
</plugin>
```

Additional libraries (add based on detection):
- Kotlin detected: `testImplementation 'io.mockk:mockk:1.13.10'` (MockK for Kotlin)
- Database integration: `testImplementation 'org.testcontainers:mysql:1.19.7'` (or postgresql, etc.)
- Spring WebFlux: `testImplementation 'org.springframework.boot:spring-boot-starter-webflux'` (WebTestClient)
- JSON testing: `testImplementation 'com.jayway.jsonpath:json-path:2.9.0'`

#### Go Testing (Go modules)

Core:
```
go get github.com/stretchr/testify
```

Framework-specific additions (detected from go.mod):
- Gin: no additional test dependency (uses net/http/httptest from stdlib)
- Echo: no additional test dependency (uses net/http/httptest from stdlib)
- Chi: no additional test dependency (uses net/http/httptest from stdlib)
- gRPC: `go get google.golang.org/grpc/test/bufconn`

Mocking additions (based on detection):
- Generated mocks: `go get go.uber.org/mock/mockgen` (add `//go:generate mockgen` directives)
- testify mock: already included in testify (no separate dependency)
- Interface fakes: no dependency needed (manual implementations)

Testcontainers for integration tests:
```
go get github.com/testcontainers/testcontainers-go
```

Database-specific testcontainers:
```
go get github.com/testcontainers/testcontainers-go/modules/postgres
go get github.com/testcontainers/testcontainers-go/modules/mysql
```

Race detection is built-in (`go test -race`) — no additional dependency needed.
Coverage is built-in (`go test -cover`) — no additional dependency needed.

### Install Process

1. Detect the package manager and ecosystem from the StackProfile.

#### JS/TS Install

For JS/TS projects, detect the package manager (`npm`, `yarn`, `pnpm`, or `bun`):
   - npm: `npm install --save-dev <packages>`
   - yarn: `yarn add --dev <packages>`
   - pnpm: `pnpm add --save-dev <packages>`
   - bun: `bun add --dev <packages>`

#### Python Install

For Python projects, detect the package manager (`pip`, `poetry`, `uv`, or `pipenv`):
   - pip: `pip install <packages>` (add to requirements-dev.txt or requirements.txt)
   - poetry: `poetry add --group dev <packages>`
   - uv: `uv add --dev <packages>`
   - pipenv: `pipenv install --dev <packages>`

If no package manager lock file is detected, default to `pip` and suggest adding to `requirements-dev.txt` or the `[project.optional-dependencies]` dev section in `pyproject.toml`.

#### Java Install

For Java projects, dependencies are added to the build file. The agent edits `build.gradle` or `pom.xml` directly — there is no separate "install" command like npm/pip.

**Gradle**: Add `testImplementation` and `testRuntimeOnly` entries to the `dependencies { }` block in `build.gradle` (or `build.gradle.kts`). If JaCoCo is needed, add the plugin to the `plugins { }` block. After editing, run `./gradlew dependencies` to verify resolution.

**Maven**: Add `<dependency>` entries with `<scope>test</scope>` to `pom.xml`. If JaCoCo is needed, add the plugin to the `<build><plugins>` section. After editing, run `./mvnw dependency:resolve` to verify resolution.

#### Go Install

For Go projects, dependencies are added via `go get` which updates `go.mod` and `go.sum`:

```
go get github.com/stretchr/testify
```

For generated mocks (if gomock strategy selected):
```
go get go.uber.org/mock/mockgen
```

For testcontainers (if integration testing detected):
```
go get github.com/testcontainers/testcontainers-go
```

After adding dependencies, run `go mod tidy` to clean up and verify resolution. Then run `go build ./...` to verify everything compiles.

Present the dependency additions as a HITL gate:
```
"The following dependencies will be added to go.mod:"
"[dependency list]"
"Install command: go get [packages] && go mod tidy"
"Proceed with adding dependencies? (yes / skip / cancel)"
```

Present the dependency additions as a HITL gate:
```
"The following dependencies will be added to {build.gradle/pom.xml}:"
"[dependency list]"
"Proceed with adding dependencies? (yes / skip / cancel)"
```

2. Present the command as a second HITL gate:
   ```
   "The following dependencies will be installed:"
   "[package list]"
   "Install command: [command]"
   "Proceed with installation? (yes / skip / cancel)"
   ```
4. **yes**: Run the install command. If it succeeds, continue to Phase 6. If it fails, fall back to manual instructions (see Error Handling below).
5. **skip**: Skip installation. Print manual instructions and continue to Phase 6. Files are still created.
6. **cancel**: Exit cleanly. Remove `.bestest/` directory and `TESTING.md` if already created. Print: "Init cancelled. All generated files have been removed."

### Install Failure Recovery

If the install command fails:
1. Print the error output.
2. Print manual instructions:
   ```
   "Automatic installation failed. Install manually with:"
   "[install command]"
   "After installing, run /bestest doctor to verify your setup."
   ```
3. Do NOT delete the generated files — they are still valid once dependencies are installed.
4. Continue to Phase 6 (Validation) but note the missing dependencies.

---

