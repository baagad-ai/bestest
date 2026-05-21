# Reference Index

All reference files are relative to `./`.

## Detection (9)
| File | Description |
|------|-------------|
| `./references/stack-profile-schema.md` | StackProfile JSON schema with field descriptions, confidence score semantics, and 6 example outputs |
| `./references/detection-signals.md` | Complete catalog of 80+ detection signals across 12 categories with strength ratings |
| `./references/detection-engine.md` | Full detection engine specification with 7-phase detection order |
| `./references/js-ts-decision-tree.md` | 7-step JS/TS framework selection decision tree with ADR template |
| `./references/python-decision-tree.md` | 7-step Python framework selection decision tree with ADR template |
| `./references/java-decision-tree.md` | 7-step Java/JVM framework selection decision tree with ADR template |
| `./references/go-decision-tree.md` | 7-step Go framework selection decision tree with ADR template |
| `./references/framework-decisions.md` | Framework decision tree summaries for all supported languages |
| `./references/context7-helper.md` | Context7 integration pattern and library ID mappings |

## Principles (3)
| File | Description |
|------|-------------|
| `./references/anti-patterns.md` | 20+ test smells with detection methods and fixes |
| `./references/ci-patterns.md` | CI pipeline design patterns |
| `./references/ai-generation-guide.md` | 7-phase AI test generation pipeline (JS/TS) |

## Spokes (19)
| File | Command |
|------|---------|
| `./references/spoke-init.md` | `/bestest init` |
| `./references/spoke-config.md` | `/bestest config` |
| `./references/spoke-scan.md` | `/bestest scan` |
| `./references/spoke-generate.md` | `/bestest generate` (JS/TS) |
| `./references/spoke-generate-python.md` | `/bestest generate` (Python) |
| `./references/spoke-generate-java.md` | `/bestest generate` (Java) |
| `./references/spoke-generate-go.md` | `/bestest generate` (Go) |
| `./references/spoke-run.md` | `/bestest run` |
| `./references/spoke-fix.md` | `/bestest fix` |
| `./references/spoke-coverage.md` | `/bestest coverage` |
| `./references/spoke-report.md` | `/bestest report` |
| `./references/spoke-doctor.md` | `/bestest doctor` |
| `./references/spoke-expand.md` | `/bestest expand` |
| `./references/spoke-migrate.md` | `/bestest migrate` |
| `./references/spoke-ci.md` | `/bestest ci` |
| `./references/spoke-help.md` | `/bestest help` |
| `./references/spoke-explain.md` | `/bestest explain` |
| `./references/spoke-status.md` | `/bestest status` |
| `./references/spoke-version.md` | `/bestest version` |

## Schemas (5)
| File | Description |
|------|-------------|
| `./references/config-schema.md` | Complete schema for `.bestest/config.yaml` — single source of truth for all spoke commands |
| `./references/scan-report-schema.md` | JSON schema for scan reports written to `.bestest/reports/scan-<timestamp>.json` |
| `./references/schema-contract.md` | Versioning policy for all bestest schema artifacts with `schemaVersion` field validation |
| `./references/metrics-schema.md` | Complete reference for `.bestest/state/metrics.json` — cross-spoke metrics store with update protocols and spoke responsibility matrix |
| `./references/error-codes.md` | Error code catalog (E001–E017+) used by validate-skill.sh for structured diagnostic reporting |

## Generation Guides (3)
| File | Description |
|------|-------------|
| `./references/ai-generation-guide.md` | 7-phase AI test generation pipeline (JS/TS) — shared generation principles |
| `./references/python-generation-guide.md` | Python-specific generation guide: pytest quality standards, scoring rubrics, and design patterns |
| `./references/go-generation-guide.md` | Go-specific generation guide: testing package quality standards, testify patterns, and scoring rubrics |

## Generation Sub-Files — JS/TS (6)
| File | Description |
|------|-------------|
| `./references/generate/phase1-target-detail.md` | Detailed targeting heuristics and path validation rules for JS/TS |
| `./references/generate/phase4-generation-detail.md` | Complex test generation patterns and advanced mocking for JS/TS |
| `./references/generate/phase5-compilation.md` | Compilation verification with auto-fix patterns and retry loop (JS/TS) |
| `./references/generate/phase6-execution.md` | Execution verification, failure analysis, and fix-and-rerun loop (JS/TS) |
| `./references/generate/phase7-quality-audit.md` | Quality scoring rubric, anti-pattern detection, and flakiness testing (JS/TS) |
| `./references/generate/error-handling.md` | Error scenarios with trigger conditions and prescribed responses (JS/TS) |

## Generation Sub-Files — Python (6)
| File | Description |
|------|-------------|
| `./references/generate/python/phase1-target-detail.md` | Path validation, targeting modes, virtualenv detection, and pytest plugin detection |
| `./references/generate/python/phase4-generation-detail.md` | Mocking patterns, factory functions, parametrize examples, and full test file example |
| `./references/generate/python/phase5-compilation.md` | Compilation verification logic for generated Python tests |
| `./references/generate/python/phase6-execution.md` | Execution verification, failure analysis, fix-and-rerun loop, and coverage delta |
| `./references/generate/python/phase7-quality-audit.md` | Assertion quality scoring, anti-pattern detection, and flakiness testing (Python) |
| `./references/generate/python/error-handling.md` | All error handling scenarios for the Python generate spoke |

## Generation Sub-Files — Java (6)
| File | Description |
|------|-------------|
| `./references/generate/java/phase1-target-detail.md` | Targeting heuristics, path validation, and preflight environment checks for Java |
| `./references/generate/java/phase4-generation-detail.md` | Mocking patterns, @ParameterizedTest, @Nested classes, and test data builders |
| `./references/generate/java/phase5-compilation.md` | 3-stage compilation pipeline with cascade error deduplication (Java) |
| `./references/generate/java/phase6-execution.md` | Execution verification, failure analysis, and fix-and-rerun loop (Java) |
| `./references/generate/java/phase7-quality-audit.md` | Assertion quality rubric, anti-pattern detection, and stability testing (Java) |
| `./references/generate/java/error-handling.md` | Error scenarios for the Java generate spoke with trigger conditions |

## Generation Sub-Files — Go (6)
| File | Description |
|------|-------------|
| `./references/generate/go/phase1-target-detail.md` | Targeting modes, path validation, Go naming conventions, and shared test helpers |
| `./references/generate/go/phase4-generation-detail.md` | Mocking patterns, table-driven test patterns, and full generation example (Go) |
| `./references/generate/go/phase5-compilation.md` | 3-stage verification pipeline: go vet, go build, and test compilation |
| `./references/generate/go/phase6-execution.md` | Execution verification, failure analysis, and fix-and-rerun loop (Go) |
| `./references/generate/go/phase7-quality-audit.md` | Quality scoring against Go generation guide rubric and stability testing |
| `./references/generate/go/error-handling.md` | All error scenarios for the Go generate spoke |

## Templates (17)
| File | Description |
|------|-------------|
| `./references/templates/vitest-config-ts.md` | Complete vitest.config.ts templates for 4 stack variants |
| `./references/templates/jest-config-ts.md` | Standard Jest configuration for existing Jest projects |
| `./references/templates/playwright-config-ts.md` | Playwright config templates for 3 project variants |
| `./references/templates/stryker-conf.md` | Stryker mutation testing configs for 2 test runner variants |
| `./references/templates/supertest-helpers.md` | Reusable API test helper patterns for supertest |
| `./references/templates/testing-md.md` | TESTING.md template with project documentation structure |
| `./references/templates/config-vitest.yaml` | Vitest config.yaml template for JS/TS projects |
| `./references/templates/config-jest.yaml` | Jest config.yaml template for existing Jest projects |
| `./references/templates/config-pytest.yaml` | pytest config.yaml template for Python projects |
| `./references/templates/config-junit5.yaml` | JUnit 5 config.yaml template for Java projects |
| `./references/templates/config-go.yaml` | Go testing config.yaml template for Go projects |
| `./references/templates/config-monorepo.yaml` | Monorepo config.yaml template for workspace projects |
| `./references/templates/ci/github-actions-test.yml` | GitHub Actions CI pipeline template |
| `./references/templates/ci/gitlab-ci-test.yml` | GitLab CI pipeline template |
| `./references/templates/ci/jenkinsfile-test.groovy` | Jenkins pipeline template |
| `./references/templates/dashboard.html` | Self-contained HTML dashboard for metrics visualization |
| `./references/templates/bestest-gitignore` | .gitignore template for .bestest/ directory |

## Migration (1)
| File | Description |
|------|-------------|
| `./references/migration-rules.md` | Transformation rule catalog for jest→vitest, junit4→junit5, cypress→playwright |

## Init Sub-Files (5)
| File | Description |
|------|-------------|
| `./references/init/phase3-hitl-gate.md` | Phase 3 HITL Gate: framework selection presentation, user prompt, response handling, checkpoint |
| `./references/init/phase4-scaffold.md` | Phase 4 Scaffold: directory structure, template resolution, Context7 integration |
| `./references/init/phase5-install.md` | Phase 5 Install Dependencies: dependency lists by framework, install processes, failure recovery |
| `./references/init/phase6-validation.md` | Phase 6 Validation: state file corruption handling, file existence checks, config validation |
| `./references/init/output-and-metrics.md` | Output tables, Metrics Update protocol, activity log, graceful degradation, downstream commands |

## Data Source Discovery (1)
| File | Description |
|------|-------------|
| `./references/data-source-discovery.md` | Shared discovery pattern for run/scan result lookup used by fix, coverage, report, doctor, and status spokes |

## Reference Infrastructure (5)
| File | Description |
|------|-------------|
| `./references/quick_reference.md` | On-demand quick reference extracted from SKILL.md for reduced token loading *(created by T02)* |
| `./references/pre-flight-protocol.md` | Shared validation pattern referenced by all generate spokes *(created by T03)* |
| `./references/dot-bestest-schema.md` | Full `.bestest/` directory tree documentation *(created by T04)* |
| `./references/parallel-dispatch.md` | Agent-agnostic parallel dispatch protocol for generate with 5+ targets *(created by S01)* |
| `./references/generate/pipeline-shared.md` | Shared generation pipeline sections (parallel dispatch, priority scoring, HITL gate, error handling, downstream reference) referenced by all 4 generate spokes |
