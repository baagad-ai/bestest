Part of **/bestest init** (see references/spoke-init.md). Load on-demand when reaching Phase 3.

## Phase 3 — HITL Gate: Framework Selection

This is the critical human-in-the-loop gate. Present the detection results and recommendation clearly, then wait for the user's decision before creating any files.

### What to Present

Display the following summary to the user:

```
## Detected Stack
- **Languages**: [from StackProfile.languages, with confidence scores]
- **Build Tool**: [from StackProfile.buildTool]
- **Frameworks**: [from StackProfile.frameworks]
- **Package Manager**: [from StackProfile.packageManager]
- **Existing Test Framework**: [from StackProfile.testFrameworks.existing — if array, list all detected frameworks]
- **Monorepo**: [from StackProfile.monorepo.detected — if true, include tool]

## Conflict Detected ⚠️
[Show this section ONLY when StackProfile.testFrameworks.conflicts is non-null]
- **Conflict Type**: [conflicts.type — e.g., "vitest-vs-jest" or "junit4-vs-junit5"]
- **Both Detected**: [conflicts.frameworks — e.g., "Vitest AND Jest"]
- **Recommendation**: Use **[conflicts.recommendation]** as primary framework.
- **Rationale**: [conflicts.rationale]
- **Migration Path**: [If vitest-vs-jest: "Vitest's Jest-compatible API allows running existing Jest tests during migration. Move tests incrementally."]
  [If junit4-vs-junit5: "JUnit Vintage Engine runs JUnit 4 tests under JUnit 5. Add vintage-engine dependency and migrate incrementally."]
- **Action Required**: The user must explicitly choose to accept the recommendation, keep both, or select an alternative during this HITL gate.

## Recommendation
- **Test Framework**: [testFrameworks.recommended]
- **Coverage Provider**: [coverage.recommended]
- **E2E Framework**: [e2eFramework.recommended or "not applicable (API-only)"]
- **Rationale**: [1-2 sentence summary from the decision tree path]

## Alternative Considered
- **[Alternative framework]**: [Why it was not chosen — 1 sentence]

## Estimated Effort
- **Fresh install**: [if no existing test framework] "New installation — no migration needed."
- **Migration**: [if existing framework differs from recommendation] "Migration from [existing] to [recommended]. Estimated effort: [low/medium/high] based on test file count and config complexity."
- **Dual-framework migration**: [if conflict detected] "Migration from [both frameworks] to [recommended] as primary. Estimated effort: [low/medium/high] based on test file count and dual-config complexity."
```

### User Prompt

After presenting the summary, prompt:

```
"Approve this recommendation? (yes / modify / cancel)"
```

### Response Handling

- **yes**: Proceed to Phase 4 (Scaffold). Use the recommended values as-is.

#### Checkpoint: Framework Approval

After the user approves the framework recommendation, write the approved choices to a checkpoint file:

```
Write to .bestest/.init-checkpoint:
{
  "phase": "framework-approved",
  "timestamp": "<current ISO 8601>",
  "framework": "<approved framework>",
  "coverage": "<approved coverage provider>",
  "e2e": "<approved e2e framework or null>"
}
```

This checkpoint enables resuming init if the user cancels at a later phase.

- **modify**: Allow the user to override specific values:
  - `--framework <vitest|jest>` — override the test framework
  - `--coverage <v8|istanbul>` — override the coverage provider
  - `--environment <node|jsdom|happy-dom>` — override the default test environment
  - `--e2e <playwright|cypress|none>` — override or skip E2E framework
  After any override, re-run Phase 2 logic with the modified inputs to update the ADR and StackProfile, then re-present the updated recommendation for confirmation.
- **cancel**: Exit cleanly. Do not create any files or directories. Print: "Init cancelled. No files were created. Run /bestest init again when ready."

### Cleanup on Cancel

If the user cancels, ensure no artifacts remain:
- Delete `.bestest/` if it was created during an earlier phase (it should not be — scaffolding happens in Phase 4)
- Do not modify `package.json` or any existing files

---

