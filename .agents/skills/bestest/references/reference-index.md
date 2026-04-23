# Reference Index

All reference files are relative to `~/.agents/skills/bestest/`.

## Detection (9)
| File | Description |
|------|-------------|
| `references/stack-profile-schema.md` | StackProfile JSON schema with field descriptions, confidence score semantics, and 6 example outputs |
| `references/detection-signals.md` | Complete catalog of 80+ detection signals across 12 categories with strength ratings |
| `references/detection-engine.md` | Full detection engine specification with 7-phase detection order |
| `references/js-ts-decision-tree.md` | 7-step JS/TS framework selection decision tree with ADR template |
| `references/python-decision-tree.md` | 7-step Python framework selection decision tree with ADR template |
| `references/java-decision-tree.md` | 7-step Java/JVM framework selection decision tree with ADR template |
| `references/go-decision-tree.md` | 7-step Go framework selection decision tree with ADR template |
| `references/framework-decisions.md` | Framework decision tree summaries for all supported languages |
| `references/context7-helper.md` | Context7 integration pattern and library ID mappings |

## Principles (3)
| File | Description |
|------|-------------|
| `references/anti-patterns.md` | 20+ test smells with detection methods and fixes |
| `references/ci-patterns.md` | CI pipeline design patterns |
| `references/ai-generation-guide.md` | 7-phase AI test generation pipeline (JS/TS) |

## Spokes (15)
| File | Command |
|------|---------|
| `references/spoke-init.md` | `/bestest init` |
| `references/spoke-config.md` | `/bestest config` |
| `references/spoke-scan.md` | `/bestest scan` |
| `references/spoke-generate.md` | `/bestest generate` (JS/TS) |
| `references/spoke-generate-python.md` | `/bestest generate` (Python) |
| `references/spoke-generate-java.md` | `/bestest generate` (Java) |
| `references/spoke-generate-go.md` | `/bestest generate` (Go) |
| `references/spoke-run.md` | `/bestest run` |
| `references/spoke-fix.md` | `/bestest fix` |
| `references/spoke-coverage.md` | `/bestest coverage` |
| `references/spoke-report.md` | `/bestest report` |
| `references/spoke-doctor.md` | `/bestest doctor` |
| `references/spoke-expand.md` | `/bestest expand` |
| `references/spoke-migrate.md` | `/bestest migrate` |
| `references/spoke-ci.md` | `/bestest ci` |

## Schemas (4)
| File | Description |
|------|-------------|
| `references/config-schema.md` | Complete schema for `.bestest/config.yaml` — single source of truth for all spoke commands |
| `references/scan-report-schema.md` | JSON schema for scan reports written to `.bestest/reports/scan-<timestamp>.json` |
| `references/schema-contract.md` | Versioning policy for all bestest schema artifacts with `schemaVersion` field validation |
| `references/metrics-schema.md` | Canonical schema for `.bestest/state/metrics.json` — continuously-updated metrics store aggregated from every state-changing spoke |

## Generation Guides (3)
| File | Description |
|------|-------------|
| `references/ai-generation-guide.md` | 7-phase AI test generation pipeline (JS/TS) — shared generation principles |
| `references/python-generation-guide.md` | Python-specific generation guide: pytest quality standards, scoring rubrics, and design patterns |
| `references/go-generation-guide.md` | Go-specific generation guide: testing package quality standards, testify patterns, and scoring rubrics |

## Generation Sub-Files — JS/TS (6)
| File | Description |
|------|-------------|
| `references/generate/phase1-target-detail.md` | Detailed targeting heuristics and path validation rules for JS/TS |
| `references/generate/phase4-generation-detail.md` | Complex test generation patterns and advanced mocking for JS/TS |
| `references/generate/phase5-compilation.md` | Compilation verification with auto-fix patterns and retry loop (JS/TS) |
| `references/generate/phase6-execution.md` | Execution verification, failure analysis, and fix-and-rerun loop (JS/TS) |
| `references/generate/phase7-quality-audit.md` | Quality scoring rubric, anti-pattern detection, and flakiness testing (JS/TS) |
| `references/generate/error-handling.md` | Error scenarios with trigger conditions and prescribed responses (JS/TS) |

## Generation Sub-Files — Python (6)
| File | Description |
|------|-------------|
| `references/generate/python/phase1-target-detail.md` | Path validation, targeting modes, virtualenv detection, and pytest plugin detection |
| `references/generate/python/phase4-generation-detail.md` | Mocking patterns, factory functions, parametrize examples, and full test file example |
| `references/generate/python/phase5-compilation.md` | Compilation verification logic for generated Python tests |
| `references/generate/python/phase6-execution.md` | Execution verification, failure analysis, fix-and-rerun loop, and coverage delta |
| `references/generate/python/phase7-quality-audit.md` | Assertion quality scoring, anti-pattern detection, and flakiness testing (Python) |
| `references/generate/python/error-handling.md` | All error handling scenarios for the Python generate spoke |

## Generation Sub-Files — Java (6)
| File | Description |
|------|-------------|
| `references/generate/java/phase1-target-detail.md` | Targeting heuristics, path validation, and preflight environment checks for Java |
| `references/generate/java/phase4-generation-detail.md` | Mocking patterns, @ParameterizedTest, @Nested classes, and test data builders |
| `references/generate/java/phase5-compilation.md` | 3-stage compilation pipeline with cascade error deduplication (Java) |
| `references/generate/java/phase6-execution.md` | Execution verification, failure analysis, and fix-and-rerun loop (Java) |
| `references/generate/java/phase7-quality-audit.md` | Assertion quality rubric, anti-pattern detection, and stability testing (Java) |
| `references/generate/java/error-handling.md` | Error scenarios for the Java generate spoke with trigger conditions |

## Generation Sub-Files — Go (6)
| File | Description |
|------|-------------|
| `references/generate/go/phase1-target-detail.md` | Targeting modes, path validation, Go naming conventions, and shared test helpers |
| `references/generate/go/phase4-generation-detail.md` | Mocking patterns, table-driven test patterns, and full generation example (Go) |
| `references/generate/go/phase5-compilation.md` | 3-stage verification pipeline: go vet, go build, and test compilation |
| `references/generate/go/phase6-execution.md` | Execution verification, failure analysis, and fix-and-rerun loop (Go) |
| `references/generate/go/phase7-quality-audit.md` | Quality scoring against Go generation guide rubric and stability testing |
| `references/generate/go/error-handling.md` | All error scenarios for the Go generate spoke |

## Templates (7)
| File | Description |
|------|-------------|
| `references/templates/vitest-config-ts.md` | Complete vitest.config.ts templates for 4 stack variants |
| `references/templates/jest-config-ts.md` | Standard Jest configuration for existing Jest projects |
| `references/templates/playwright-config-ts.md` | Playwright config templates for 3 project variants |
| `references/templates/stryker-conf.md` | Stryker mutation testing configs for 2 test runner variants |
| `references/templates/supertest-helpers.md` | Reusable API test helper patterns for supertest |
| `references/templates/testing-md.md` | TESTING.md template with project documentation structure |
| `references/templates/dashboard.html` | Self-contained HTML health dashboard with Lucide icons, 9 widgets, dark/light mode — reads `.bestest/state/metrics.json` at runtime |

## Migration (1)
| File | Description |
|------|-------------|
| `references/migration-rules.md` | Transformation rule catalog for jest→vitest, junit4→junit5, cypress→playwright |

## Reference Infrastructure (4)
| File | Description |
|------|-------------|
| `references/reference-index.md` | Complete catalog of all reference files across 12 categories |
| `references/quick_reference.md` | On-demand quick reference extracted from SKILL.md for reduced token loading *(created by T02)* |
| `references/pre-flight-protocol.md` | Shared validation pattern referenced by all spokes *(created by T03)* |
| `references/dot-bestest-schema.md` | Full `.bestest/` directory tree documentation *(created by T04)* |
