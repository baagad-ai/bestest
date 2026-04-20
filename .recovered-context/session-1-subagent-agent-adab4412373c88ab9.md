# Subagent: agent-adab4412373c88ab9
# Type: Explore
# Description: Explore existing skill patterns
# Source: session-1


### [USER]
Thoroughly explore the Claude Code skills ecosystem to understand skill creation patterns. I need to understand:

1. Read the skill at /Users/prajwalmishra/.claude/skills/test-driven-development - understand its full structure, commands, hooks, state management
2. Read the skill at /Users/prajwalmishra/.claude/skills/writing-skills - understand how skills are created
3. Read /Users/prajwalmishra/.claude/skills/webapp-testing if it exists
4. Read /Users/prajwalmishra/.claude/skills/e2e-testing-patterns if it exists
5. Read /Users/prajwalmishra/.claude/skills/python-testing-patterns if it exists
6. Read /Users/prajwalmishra/.claude/skills/systematic-debugging if it exists
7. Read /Users/prajwalmishra/.claude/skills/verification-before-completion if it exists
8. Look at the structure of complex skills like /Users/prajwalmishra/.claude/skills/content-engine or any orchestrator skills

For each skill, report:
- File structure (what files exist, directories)
- How commands/sub-skills work
- How state/memory is managed
- How hooks are configured
- How references/scripts work
- The overall pattern/architecture of the skill

Be very thorough - read ALL files in each skill directory.

---

### [ASSISTANT]
I'll thoroughly explore the Claude Code skills ecosystem to understand skill creation patterns. Let me start by examining each skill directory you've specified.


---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/test-driven-development]

---

### [USER]
EISDIR: illegal operation on a directory, read '/Users/prajwalmishra/.claude/skills/test-driven-development'

---

### [ASSISTANT]
Let me explore the structure of each skill directory by listing their contents first:


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/test-driven-development"]

---

### [USER]
total 48
drwxr-xr-x@  4 prajwalmishra  staff   128  1 Feb 13:52 .
drwxr-xr-x@ 44 prajwalmishra  staff  1408 16 Apr 02:09 ..
-rw-r--r--@  1 prajwalmishra  staff  9867  1 Feb 13:52 SKILL.md
-rw-r--r--@  1 prajwalmishra  staff  8251  1 Feb 13:52 testing-anti-patterns.md

---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/test-driven-development/SKILL.md]

---

### [USER]
1	---
2	name: test-driven-development
3	description: Use when implementing any feature or bugfix, before writing implementation code
4	---
5	
6	# Test-Driven Development (TDD)
7	
8	## Overview
9	
10	Write the test first. Watch it fail. Write minimal code to pass.
11	
12	**Core principle:** If you didn't watch the test fail, you don't know if it tests the right thing.
13	
14	**Violating the letter of the rules is violating the spirit of the rules.**
15	
16	## When to Use
17	
18	**Always:**
19	- New features
20	- Bug fixes
21	- Refactoring
22	- Behavior changes
23	
24	**Exceptions (ask your human partner):**
25	- Throwaway prototypes
26	- Generated code
27	- Configuration files
28	
29	Thinking "skip TDD just this once"? Stop. That's rationalization.
30	
31	## The Iron Law
32	
33	```
34	NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
35	```
36	
37	Write code before the test? Delete it. Start over.
38	
39	**No exceptions:**
40	- Don't keep it as "reference"
41	- Don't "adapt" it while writing tests
42	- Don't look at it
43	- Delete means delete
44	
45	Implement fresh from tests. Period.
46	
47	## Red-Green-Refactor
48	
49	```dot
50	digraph tdd_cycle {
51	    rankdir=LR;
52	    red [label="RED\nWrite failing test", shape=box, style=filled, fillcolor="#ffcccc"];
53	    verify_red [label="Verify fails\ncorrectly", shape=diamond];
54	    green [label="GREEN\nMinimal code", shape=box, style=filled, fillcolor="#ccffcc"];
55	    verify_green [label="Verify passes\nAll green", shape=diamond];
56	    refactor [label="REFACTOR\nClean up", shape=box, style=filled, fillcolor="#ccccff"];
57	    next [label="Next", shape=ellipse];
58	
59	    red -> verify_red;
60	    verify_red -> green [label="yes"];
61	    verify_red -> red [label="wrong\nfailure"];
62	    green -> verify_green;
63	    verify_green -> refactor [label="yes"];
64	    verify_green -> green [label="no"];
65	    refactor -> verify_green [label="stay\ngreen"];
66	    verify_green -> next;
67	    next -> red;
68	}
69	```
70	
71	### RED - Write Failing Test
72	
73	Write one minimal test showing what should happen.
74	
75	<Good>
76	```typescript
77	test('retries failed operations 3 times', async () => {
78	  let attempts = 0;
79	  const operation = () => {
80	    attempts++;
81	    if (attempts < 3) throw new Error('fail');
82	    return 'success';
83	  };
84	
85	  const result = await retryOperation(operation);
86	
87	  expect(result).toBe('success');
88	  expect(attempts).toBe(3);
89	});
90	```
91	Clear name, tests real behavior, one thing
92	</Good>
93	
94	<Bad>
95	```typescript
96	test('retry works', async () => {
97	  const mock = jest.fn()
98	    .mockRejectedValueOnce(new Error())
99	    .mockRejectedValueOnce(new Error())
100	    .mockResolvedValueOnce('success');
101	  await retryOperation(mock);
102	  expect(mock).toHaveBeenCalledTimes(3);
103	});
104	```
105	Vague name, tests mock not code
106	</Bad>
107	
108	**Requirements:**
109	- One behavior
110	- Clear name
111	- Real code (no mocks unless unavoidable)
112	
113	### Verify RED - Watch It Fail
114	
115	**MANDATORY. Never skip.**
116	
117	```bash
118	npm test path/to/test.test.ts
119	```
120	
121	Confirm:
122	- Test fails (not errors)
123	- Failure message is expected
124	- Fails because feature missing (not typos)
125	
126	**Test passes?** You're testing existing behavior. Fix test.
127	
128	**Test errors?** Fix error, re-run until it fails correctly.
129	
130	### GREEN - Minimal Code
131	
132	Write simplest code to pass the test.
133	
134	<Good>
135	```typescript
136	async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
137	  for (let i = 0; i < 3; i++) {
138	    try {
139	      return await fn();
140	    } catch (e) {
141	      if (i === 2) throw e;
142	    }
143	  }
144	  throw new Error('unreachable');
145	}
146	```
147	Just enough to pass
148	</Good>
149	
150	<Bad>
151	```typescript
152	async function retryOperation<T>(
153	  fn: () => Promise<T>,
154	  options?: {
155	    maxRetries?: number;
156	    backoff?: 'linear' | 'exponential';
157	    onRetry?: (attempt: number) => void;
158	  }
159	): Promise<T> {
160	  // YAGNI
161	}
162	```
163	Over-engineered
164	</Bad>
165	
166	Don't add features, refactor other code, or "improve" beyond the test.
167	
168	### Verify GREEN - Watch It Pass
169	
170	**MANDATORY.**
171	
172	```bash
173	npm test path/to/test.test.ts
174	```
175	
176	Confirm:
177	- Test passes
178	- Other tests still pass
179	- Output pristine (no errors, warnings)
180	
181	**Test fails?** Fix code, not test.
182	
183	**Other tests fail?** Fix now.
184	
185	### REFACTOR - Clean Up
186	
187	After green only:
188	- Remove duplication
189	- Improve names
190	- Extract helpers
191	
192	Keep tests green. Don't add behavior.
193	
194	### Repeat
195	
196	Next failing test for next feature.
197	
198	## Good Tests
199	
200	| Quality | Good | Bad |
201	|---------|------|-----|
202	| **Minimal** | One thing. "and" in name? Split it. | `test('validates email and domain and whitespace')` |
203	| **Clear** | Name describes behavior | `test('test1')` |
204	| **Shows intent** | Demonstrates desired API | Obscures what code should do |
205	
206	## Why Order Matters
207	
208	**"I'll write tests after to verify it works"**
209	
210	Tests written after code pass immediately. Passing immediately proves nothing:
211	- Might test wrong thing
212	- Might test implementation, not behavior
213	- Might miss edge cases you forgot
214	- You never saw it catch the bug
215	
216	Test-first forces you to see the test fail, proving it actually tests something.
217	
218	**"I already manually tested all the edge cases"**
219	
220	Manual testing is ad-hoc. You think you tested everything but:
221	- No record of what you tested
222	- Can't re-run when code changes
223	- Easy to forget cases under pressure
224	- "It worked when I tried it" ≠ comprehensive
225	
226	Automated tests are systematic. They run the same way every time.
227	
228	**"Deleting X hours of work is wasteful"**
229	
230	Sunk cost fallacy. The time is already gone. Your choice now:
231	- Delete and rewrite with TDD (X more hours, high confidence)
232	- Keep it and add tests after (30 min, low confidence, likely bugs)
233	
234	The "waste" is keeping code you can't trust. Working code without real tests is technical debt.
235	
236	**"TDD is dogmatic, being pragmatic means adapting"**
237	
238	TDD IS pragmatic:
239	- Finds bugs before commit (faster than debugging after)
240	- Prevents regressions (tests catch breaks immediately)
241	- Documents behavior (tests show how to use code)
242	- Enables refactoring (change freely, tests catch breaks)
243	
244	"Pragmatic" shortcuts = debugging in production = slower.
245	
246	**"Tests after achieve the same goals - it's spirit not ritual"**
247	
248	No. Tests-after answer "What does this do?" Tests-first answer "What should this do?"
249	
250	Tests-after are biased by your implementation. You test what you built, not what's required. You verify remembered edge cases, not discovered ones.
251	
252	Tests-first force edge case discovery before implementing. Tests-after verify you remembered everything (you didn't).
253	
254	30 minutes of tests after ≠ TDD. You get coverage, lose proof tests work.
255	
256	## Common Rationalizations
257	
258	| Excuse | Reality |
259	|--------|---------|
260	| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
261	| "I'll test after" | Tests passing immediately prove nothing. |
262	| "Tests after achieve same goals" | Tests-after = "what does this do?" Tests-first = "what should this do?" |
263	| "Already manually tested" | Ad-hoc ≠ systematic. No record, can't re-run. |
264	| "Deleting X hours is wasteful" | Sunk cost fallacy. Keeping unverified code is technical debt. |
265	| "Keep as reference, write tests first" | You'll adapt it. That's testing after. Delete means delete. |
266	| "Need to explore first" | Fine. Throw away exploration, start with TDD. |
267	| "Test hard = design unclear" | Listen to test. Hard to test = hard to use. |
268	| "TDD will slow me down" | TDD faster than debugging. Pragmatic = test-first. |
269	| "Manual test faster" | Manual doesn't prove edge cases. You'll re-test every change. |
270	| "Existing code has no tests" | You're improving it. Add tests for existing code. |
271	
272	## Red Flags - STOP and Start Over
273	
274	- Code before test
275	- Test after implementation
276	- Test passes immediately
277	- Can't explain why test failed
278	- Tests added "later"
279	- Rationalizing "just this once"
280	- "I already manually tested it"
281	- "Tests after achieve the same purpose"
282	- "It's about spirit not ritual"
283	- "Keep as reference" or "adapt existing code"
284	- "Already spent X hours, deleting is wasteful"
285	- "TDD is dogmatic, I'm being pragmatic"
286	- "This is different because..."
287	
288	**All of these mean: Delete code. Start over with TDD.**
289	
290	## Example: Bug Fix
291	
292	**Bug:** Empty email accepted
293	
294	**RED**
295	```typescript
296	test('rejects empty email', async () => {
297	  const result = await submitForm({ email: '' });
298	  expect(result.error).toBe('Email required');
299	});
300	```
301	
302	**Verify RED**
303	```bash
304	$ npm test
305	FAIL: expected 'Email required', got undefined
306	```
307	
308	**GREEN**
309	```typescript
310	function submitForm(data: FormData) {
311	  if (!data.email?.trim()) {
312	    return { error: 'Email required' };
313	  }
314	  // ...
315	}
316	```
317	
318	**Verify GREEN**
319	```bash
320	$ npm test
321	PASS
322	```
323	
324	**REFACTOR**
325	Extract validation for multiple fields if needed.
326	
327	## Verification Checklist
328	
329	Before marking work complete:
330	
331	- [ ] Every new function/method has a test
332	- [ ] Watched each test fail before implementing
333	- [ ] Each test failed for expected reason (feature missing, not typo)
334	- [ ] Wrote minimal code to pass each test
335	- [ ] All tests pass
336	- [ ] Output pristine (no errors, warnings)
337	- [ ] Tests use real code (mocks only if unavoidable)
338	- [ ] Edge cases and errors covered
339	
340	Can't check all boxes? You skipped TDD. Start over.
341	
342	## When Stuck
343	
344	| Problem | Solution |
345	|---------|----------|
346	| Don't know how to test | Write wished-for API. Write assertion first. Ask your human partner. |
347	| Test too complicated | Design too complicated. Simplify interface. |
348	| Must mock everything | Code too coupled. Use dependency injection. |
349	| Test setup huge | Extract helpers. Still complex? Simplify design. |
350	
351	## Debugging Integration
352	
353	Bug found? Write failing test reproducing it. Follow TDD cycle. Test proves fix and prevents regression.
354	
355	Never fix bugs without a test.
356	
357	## Testing Anti-Patterns
358	
359	When adding mocks or test utilities, read @testing-anti-patterns.md to avoid common pitfalls:
360	- Testing mock behavior instead of real behavior
361	- Adding test-only methods to production classes
362	- Mocking without understanding dependencies
363	
364	## Final Rule
365	
366	```
367	Production code → test exists and failed first
368	Otherwise → not TDD
369	```
370	
371	No exceptions without your human partner's permission.
372	

<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>


---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/test-driven-development/testing-anti-patterns.md]

---

### [USER]
1	# Testing Anti-Patterns
2	
3	**Load this reference when:** writing or changing tests, adding mocks, or tempted to add test-only methods to production code.
4	
5	## Overview
6	
7	Tests must verify real behavior, not mock behavior. Mocks are a means to isolate, not the thing being tested.
8	
9	**Core principle:** Test what the code does, not what the mocks do.
10	
11	**Following strict TDD prevents these anti-patterns.**
12	
13	## The Iron Laws
14	
15	```
16	1. NEVER test mock behavior
17	2. NEVER add test-only methods to production classes
18	3. NEVER mock without understanding dependencies
19	```
20	
21	## Anti-Pattern 1: Testing Mock Behavior
22	
23	**The violation:**
24	```typescript
25	// ❌ BAD: Testing that the mock exists
26	test('renders sidebar', () => {
27	  render(<Page />);
28	  expect(screen.getByTestId('sidebar-mock')).toBeInTheDocument();
29	});
30	```
31	
32	**Why this is wrong:**
33	- You're verifying the mock works, not that the component works
34	- Test passes when mock is present, fails when it's not
35	- Tells you nothing about real behavior
36	
37	**your human partner's correction:** "Are we testing the behavior of a mock?"
38	
39	**The fix:**
40	```typescript
41	// ✅ GOOD: Test real component or don't mock it
42	test('renders sidebar', () => {
43	  render(<Page />);  // Don't mock sidebar
44	  expect(screen.getByRole('navigation')).toBeInTheDocument();
45	});
46	
47	// OR if sidebar must be mocked for isolation:
48	// Don't assert on the mock - test Page's behavior with sidebar present
49	```
50	
51	### Gate Function
52	
53	```
54	BEFORE asserting on any mock element:
55	  Ask: "Am I testing real component behavior or just mock existence?"
56	
57	  IF testing mock existence:
58	    STOP - Delete the assertion or unmock the component
59	
60	  Test real behavior instead
61	```
62	
63	## Anti-Pattern 2: Test-Only Methods in Production
64	
65	**The violation:**
66	```typescript
67	// ❌ BAD: destroy() only used in tests
68	class Session {
69	  async destroy() {  // Looks like production API!
70	    await this._workspaceManager?.destroyWorkspace(this.id);
71	    // ... cleanup
72	  }
73	}
74	
75	// In tests
76	afterEach(() => session.destroy());
77	```
78	
79	**Why this is wrong:**
80	- Production class polluted with test-only code
81	- Dangerous if accidentally called in production
82	- Violates YAGNI and separation of concerns
83	- Confuses object lifecycle with entity lifecycle
84	
85	**The fix:**
86	```typescript
87	// ✅ GOOD: Test utilities handle test cleanup
88	// Session has no destroy() - it's stateless in production
89	
90	// In test-utils/
91	export async function cleanupSession(session: Session) {
92	  const workspace = session.getWorkspaceInfo();
93	  if (workspace) {
94	    await workspaceManager.destroyWorkspace(workspace.id);
95	  }
96	}
97	
98	// In tests
99	afterEach(() => cleanupSession(session));
100	```
101	
102	### Gate Function
103	
104	```
105	BEFORE adding any method to production class:
106	  Ask: "Is this only used by tests?"
107	
108	  IF yes:
109	    STOP - Don't add it
110	    Put it in test utilities instead
111	
112	  Ask: "Does this class own this resource's lifecycle?"
113	
114	  IF no:
115	    STOP - Wrong class for this method
116	```
117	
118	## Anti-Pattern 3: Mocking Without Understanding
119	
120	**The violation:**
121	```typescript
122	// ❌ BAD: Mock breaks test logic
123	test('detects duplicate server', () => {
124	  // Mock prevents config write that test depends on!
125	  vi.mock('ToolCatalog', () => ({
126	    discoverAndCacheTools: vi.fn().mockResolvedValue(undefined)
127	  }));
128	
129	  await addServer(config);
130	  await addServer(config);  // Should throw - but won't!
131	});
132	```
133	
134	**Why this is wrong:**
135	- Mocked method had side effect test depended on (writing config)
136	- Over-mocking to "be safe" breaks actual behavior
137	- Test passes for wrong reason or fails mysteriously
138	
139	**The fix:**
140	```typescript
141	// ✅ GOOD: Mock at correct level
142	test('detects duplicate server', () => {
143	  // Mock the slow part, preserve behavior test needs
144	  vi.mock('MCPServerManager'); // Just mock slow server startup
145	
146	  await addServer(config);  // Config written
147	  await addServer(config);  // Duplicate detected ✓
148	});
149	```
150	
151	### Gate Function
152	
153	```
154	BEFORE mocking any method:
155	  STOP - Don't mock yet
156	
157	  1. Ask: "What side effects does the real method have?"
158	  2. Ask: "Does this test depend on any of those side effects?"
159	  3. Ask: "Do I fully understand what this test needs?"
160	
161	  IF depends on side effects:
162	    Mock at lower level (the actual slow/external operation)
163	    OR use test doubles that preserve necessary behavior
164	    NOT the high-level method the test depends on
165	
166	  IF unsure what test depends on:
167	    Run test with real implementation FIRST
168	    Observe what actually needs to happen
169	    THEN add minimal mocking at the right level
170	
171	  Red flags:
172	    - "I'll mock this to be safe"
173	    - "This might be slow, better mock it"
174	    - Mocking without understanding the dependency chain
175	```
176	
177	## Anti-Pattern 4: Incomplete Mocks
178	
179	**The violation:**
180	```typescript
181	// ❌ BAD: Partial mock - only fields you think you need
182	const mockResponse = {
183	  status: 'success',
184	  data: { userId: '123', name: 'Alice' }
185	  // Missing: metadata that downstream code uses
186	};
187	
188	// Later: breaks when code accesses response.metadata.requestId
189	```
190	
191	**Why this is wrong:**
192	- **Partial mocks hide structural assumptions** - You only mocked fields you know about
193	- **Downstream code may depend on fields you didn't include** - Silent failures
194	- **Tests pass but integration fails** - Mock incomplete, real API complete
195	- **False confidence** - Test proves nothing about real behavior
196	
197	**The Iron Rule:** Mock the COMPLETE data structure as it exists in reality, not just fields your immediate test uses.
198	
199	**The fix:**
200	```typescript
201	// ✅ GOOD: Mirror real API completeness
202	const mockResponse = {
203	  status: 'success',
204	  data: { userId: '123', name: 'Alice' },
205	  metadata: { requestId: 'req-789', timestamp: 1234567890 }
206	  // All fields real API returns
207	};
208	```
209	
210	### Gate Function
211	
212	```
213	BEFORE creating mock responses:
214	  Check: "What fields does the real API response contain?"
215	
216	  Actions:
217	    1. Examine actual API response from docs/examples
218	    2. Include ALL fields system might consume downstream
219	    3. Verify mock matches real response schema completely
220	
221	  Critical:
222	    If you're creating a mock, you must understand the ENTIRE structure
223	    Partial mocks fail silently when code depends on omitted fields
224	
225	  If uncertain: Include all documented fields
226	```
227	
228	## Anti-Pattern 5: Integration Tests as Afterthought
229	
230	**The violation:**
231	```
232	✅ Implementation complete
233	❌ No tests written
234	"Ready for testing"
235	```
236	
237	**Why this is wrong:**
238	- Testing is part of implementation, not optional follow-up
239	- TDD would have caught this
240	- Can't claim complete without tests
241	
242	**The fix:**
243	```
244	TDD cycle:
245	1. Write failing test
246	2. Implement to pass
247	3. Refactor
248	4. THEN claim complete
249	```
250	
251	## When Mocks Become Too Complex
252	
253	**Warning signs:**
254	- Mock setup longer than test logic
255	- Mocking everything to make test pass
256	- Mocks missing methods real components have
257	- Test breaks when mock changes
258	
259	**your human partner's question:** "Do we need to be using a mock here?"
260	
261	**Consider:** Integration tests with real components often simpler than complex mocks
262	
263	## TDD Prevents These Anti-Patterns
264	
265	**Why TDD helps:**
266	1. **Write test first** → Forces you to think about what you're actually testing
267	2. **Watch it fail** → Confirms test tests real behavior, not mocks
268	3. **Minimal implementation** → No test-only methods creep in
269	4. **Real dependencies** → You see what the test actually needs before mocking
270	
271	**If you're testing mock behavior, you violated TDD** - you added mocks without watching test fail against real code first.
272	
273	## Quick Reference
274	
275	| Anti-Pattern | Fix |
276	|--------------|-----|
277	| Assert on mock elements | Test real component or unmock it |
278	| Test-only methods in production | Move to test utilities |
279	| Mock without understanding | Understand dependencies first, mock minimally |
280	| Incomplete mocks | Mirror real API completely |
281	| Tests as afterthought | TDD - tests first |
282	| Over-complex mocks | Consider integration tests |
283	
284	## Red Flags
285	
286	- Assertion checks for `*-mock` test IDs
287	- Methods only called in test files
288	- Mock setup is >50% of test
289	- Test fails when you remove mock
290	- Can't explain why mock is needed
291	- Mocking "just to be safe"
292	
293	## The Bottom Line
294	
295	**Mocks are tools to isolate, not things to test.**
296	
297	If TDD reveals you're testing mock behavior, you've gone wrong.
298	
299	Fix: Test real behavior or question why you're mocking at all.
300	

<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>


---

### [ASSISTANT]
Now let me check the next skill:


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/writing-skills"]

---

### [USER]
total 224
drwxr-xr-x@  9 prajwalmishra  staff    288  1 Feb 13:52 .
drwxr-xr-x@ 44 prajwalmishra  staff   1408 16 Apr 02:09 ..
-rw-r--r--@  1 prajwalmishra  staff  45825  1 Feb 13:52 anthropic-best-practices.md
drwxr-xr-x@  3 prajwalmishra  staff     96  1 Feb 13:52 examples
-rw-r--r--@  1 prajwalmishra  staff   5970  1 Feb 13:52 graphviz-conventions.dot
-rw-r--r--@  1 prajwalmishra  staff   5908  1 Feb 13:52 persuasion-principles.md
-rwxr-xr-x@  1 prajwalmishra  staff   4857  1 Feb 13:52 render-graphs.js
-rw-r--r--@  1 prajwalmishra  staff  22463  1 Feb 13:52 SKILL.md
-rw-r--r--@  1 prajwalmishra  staff  12558  1 Feb 13:52 testing-skills-with-subagents.md

---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/writing-skills/SKILL.md]

---

### [USER]
1	---
2	name: writing-skills
3	description: Use when creating new skills, editing existing skills, or verifying skills work before deployment
4	---
5	
6	# Writing Skills
7	
8	## Overview
9	
10	**Writing skills IS Test-Driven Development applied to process documentation.**
11	
12	**Personal skills live in agent-specific directories (`~/.claude/skills` for Claude Code, `~/.codex/skills` for Codex)** 
13	
14	You write test cases (pressure scenarios with subagents), watch them fail (baseline behavior), write the skill (documentation), watch tests pass (agents comply), and refactor (close loopholes).
15	
16	**Core principle:** If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing.
17	
18	**REQUIRED BACKGROUND:** You MUST understand superpowers:test-driven-development before using this skill. That skill defines the fundamental RED-GREEN-REFACTOR cycle. This skill adapts TDD to documentation.
19	
20	**Official guidance:** For Anthropic's official skill authoring best practices, see anthropic-best-practices.md. This document provides additional patterns and guidelines that complement the TDD-focused approach in this skill.
21	
22	## What is a Skill?
23	
24	A **skill** is a reference guide for proven techniques, patterns, or tools. Skills help future Claude instances find and apply effective approaches.
25	
26	**Skills are:** Reusable techniques, patterns, tools, reference guides
27	
28	**Skills are NOT:** Narratives about how you solved a problem once
29	
30	## TDD Mapping for Skills
31	
32	| TDD Concept | Skill Creation |
33	|-------------|----------------|
34	| **Test case** | Pressure scenario with subagent |
35	| **Production code** | Skill document (SKILL.md) |
36	| **Test fails (RED)** | Agent violates rule without skill (baseline) |
37	| **Test passes (GREEN)** | Agent complies with skill present |
38	| **Refactor** | Close loopholes while maintaining compliance |
39	| **Write test first** | Run baseline scenario BEFORE writing skill |
40	| **Watch it fail** | Document exact rationalizations agent uses |
41	| **Minimal code** | Write skill addressing those specific violations |
42	| **Watch it pass** | Verify agent now complies |
43	| **Refactor cycle** | Find new rationalizations → plug → re-verify |
44	
45	The entire skill creation process follows RED-GREEN-REFACTOR.
46	
47	## When to Create a Skill
48	
49	**Create when:**
50	- Technique wasn't intuitively obvious to you
51	- You'd reference this again across projects
52	- Pattern applies broadly (not project-specific)
53	- Others would benefit
54	
55	**Don't create for:**
56	- One-off solutions
57	- Standard practices well-documented elsewhere
58	- Project-specific conventions (put in CLAUDE.md)
59	- Mechanical constraints (if it's enforceable with regex/validation, automate it—save documentation for judgment calls)
60	
61	## Skill Types
62	
63	### Technique
64	Concrete method with steps to follow (condition-based-waiting, root-cause-tracing)
65	
66	### Pattern
67	Way of thinking about problems (flatten-with-flags, test-invariants)
68	
69	### Reference
70	API docs, syntax guides, tool documentation (office docs)
71	
72	## Directory Structure
73	
74	
75	```
76	skills/
77	  skill-name/
78	    SKILL.md              # Main reference (required)
79	    supporting-file.*     # Only if needed
80	```
81	
82	**Flat namespace** - all skills in one searchable namespace
83	
84	**Separate files for:**
85	1. **Heavy reference** (100+ lines) - API docs, comprehensive syntax
86	2. **Reusable tools** - Scripts, utilities, templates
87	
88	**Keep inline:**
89	- Principles and concepts
90	- Code patterns (< 50 lines)
91	- Everything else
92	
93	## SKILL.md Structure
94	
95	**Frontmatter (YAML):**
96	- Only two fields supported: `name` and `description`
97	- Max 1024 characters total
98	- `name`: Use letters, numbers, and hyphens only (no parentheses, special chars)
99	- `description`: Third-person, describes ONLY when to use (NOT what it does)
100	  - Start with "Use when..." to focus on triggering conditions
101	  - Include specific symptoms, situations, and contexts
102	  - **NEVER summarize the skill's process or workflow** (see CSO section for why)
103	  - Keep under 500 characters if possible
104	
105	```markdown
106	---
107	name: Skill-Name-With-Hyphens
108	description: Use when [specific triggering conditions and symptoms]
109	---
110	
111	# Skill Name
112	
113	## Overview
114	What is this? Core principle in 1-2 sentences.
115	
116	## When to Use
117	[Small inline flowchart IF decision non-obvious]
118	
119	Bullet list with SYMPTOMS and use cases
120	When NOT to use
121	
122	## Core Pattern (for techniques/patterns)
123	Before/after code comparison
124	
125	## Quick Reference
126	Table or bullets for scanning common operations
127	
128	## Implementation
129	Inline code for simple patterns
130	Link to file for heavy reference or reusable tools
131	
132	## Common Mistakes
133	What goes wrong + fixes
134	
135	## Real-World Impact (optional)
136	Concrete results
137	```
138	
139	
140	## Claude Search Optimization (CSO)
141	
142	**Critical for discovery:** Future Claude needs to FIND your skill
143	
144	### 1. Rich Description Field
145	
146	**Purpose:** Claude reads description to decide which skills to load for a given task. Make it answer: "Should I read this skill right now?"
147	
148	**Format:** Start with "Use when..." to focus on triggering conditions
149	
150	**CRITICAL: Description = When to Use, NOT What the Skill Does**
151	
152	The description should ONLY describe triggering conditions. Do NOT summarize the skill's process or workflow in the description.
153	
154	**Why this matters:** Testing revealed that when a description summarizes the skill's workflow, Claude may follow the description instead of reading the full skill content. A description saying "code review between tasks" caused Claude to do ONE review, even though the skill's flowchart clearly showed TWO reviews (spec compliance then code quality).
155	
156	When the description was changed to just "Use when executing implementation plans with independent tasks" (no workflow summary), Claude correctly read the flowchart and followed the two-stage review process.
157	
158	**The trap:** Descriptions that summarize workflow create a shortcut Claude will take. The skill body becomes documentation Claude skips.
159	
160	```yaml
161	# ❌ BAD: Summarizes workflow - Claude may follow this instead of reading skill
162	description: Use when executing plans - dispatches subagent per task with code review between tasks
163	
164	# ❌ BAD: Too much process detail
165	description: Use for TDD - write test first, watch it fail, write minimal code, refactor
166	
167	# ✅ GOOD: Just triggering conditions, no workflow summary
168	description: Use when executing implementation plans with independent tasks in the current session
169	
170	# ✅ GOOD: Triggering conditions only
171	description: Use when implementing any feature or bugfix, before writing implementation code
172	```
173	
174	**Content:**
175	- Use concrete triggers, symptoms, and situations that signal this skill applies
176	- Describe the *problem* (race conditions, inconsistent behavior) not *language-specific symptoms* (setTimeout, sleep)
177	- Keep triggers technology-agnostic unless the skill itself is technology-specific
178	- If skill is technology-specific, make that explicit in the trigger
179	- Write in third person (injected into system prompt)
180	- **NEVER summarize the skill's process or workflow**
181	
182	```yaml
183	# ❌ BAD: Too abstract, vague, doesn't include when to use
184	description: For async testing
185	
186	# ❌ BAD: First person
187	description: I can help you with async tests when they're flaky
188	
189	# ❌ BAD: Mentions technology but skill isn't specific to it
190	description: Use when tests use setTimeout/sleep and are flaky
191	
192	# ✅ GOOD: Starts with "Use when", describes problem, no workflow
193	description: Use when tests have race conditions, timing dependencies, or pass/fail inconsistently
194	
195	# ✅ GOOD: Technology-specific skill with explicit trigger
196	description: Use when using React Router and handling authentication redirects
197	```
198	
199	### 2. Keyword Coverage
200	
201	Use words Claude would search for:
202	- Error messages: "Hook timed out", "ENOTEMPTY", "race condition"
203	- Symptoms: "flaky", "hanging", "zombie", "pollution"
204	- Synonyms: "timeout/hang/freeze", "cleanup/teardown/afterEach"
205	- Tools: Actual commands, library names, file types
206	
207	### 3. Descriptive Naming
208	
209	**Use active voice, verb-first:**
210	- ✅ `creating-skills` not `skill-creation`
211	- ✅ `condition-based-waiting` not `async-test-helpers`
212	
213	### 4. Token Efficiency (Critical)
214	
215	**Problem:** getting-started and frequently-referenced skills load into EVERY conversation. Every token counts.
216	
217	**Target word counts:**
218	- getting-started workflows: <150 words each
219	- Frequently-loaded skills: <200 words total
220	- Other skills: <500 words (still be concise)
221	
222	**Techniques:**
223	
224	**Move details to tool help:**
225	```bash
226	# ❌ BAD: Document all flags in SKILL.md
227	search-conversations supports --text, --both, --after DATE, --before DATE, --limit N
228	
229	# ✅ GOOD: Reference --help
230	search-conversations supports multiple modes and filters. Run --help for details.
231	```
232	
233	**Use cross-references:**
234	```markdown
235	# ❌ BAD: Repeat workflow details
236	When searching, dispatch subagent with template...
237	[20 lines of repeated instructions]
238	
239	# ✅ GOOD: Reference other skill
240	Always use subagents (50-100x context savings). REQUIRED: Use [other-skill-name] for workflow.
241	```
242	
243	**Compress examples:**
244	```markdown
245	# ❌ BAD: Verbose example (42 words)
246	your human partner: "How did we handle authentication errors in React Router before?"
247	You: I'll search past conversations for React Router authentication patterns.
248	[Dispatch subagent with search query: "React Router authentication error handling 401"]
249	
250	# ✅ GOOD: Minimal example (20 words)
251	Partner: "How did we handle auth errors in React Router?"
252	You: Searching...
253	[Dispatch subagent → synthesis]
254	```
255	
256	**Eliminate redundancy:**
257	- Don't repeat what's in cross-referenced skills
258	- Don't explain what's obvious from command
259	- Don't include multiple examples of same pattern
260	
261	**Verification:**
262	```bash
263	wc -w skills/path/SKILL.md
264	# getting-started workflows: aim for <150 each
265	# Other frequently-loaded: aim for <200 total
266	```
267	
268	**Name by what you DO or core insight:**
269	- ✅ `condition-based-waiting` > `async-test-helpers`
270	- ✅ `using-skills` not `skill-usage`
271	- ✅ `flatten-with-flags` > `data-structure-refactoring`
272	- ✅ `root-cause-tracing` > `debugging-techniques`
273	
274	**Gerunds (-ing) work well for processes:**
275	- `creating-skills`, `testing-skills`, `debugging-with-logs`
276	- Active, describes the action you're taking
277	
278	### 4. Cross-Referencing Other Skills
279	
280	**When writing documentation that references other skills:**
281	
282	Use skill name only, with explicit requirement markers:
283	- ✅ Good: `**REQUIRED SUB-SKILL:** Use superpowers:test-driven-development`
284	- ✅ Good: `**REQUIRED BACKGROUND:** You MUST understand superpowers:systematic-debugging`
285	- ❌ Bad: `See skills/testing/test-driven-development` (unclear if required)
286	- ❌ Bad: `@skills/testing/test-driven-development/SKILL.md` (force-loads, burns context)
287	
288	**Why no @ links:** `@` syntax force-loads files immediately, consuming 200k+ context before you need them.
289	
290	## Flowchart Usage
291	
292	```dot
293	digraph when_flowchart {
294	    "Need to show information?" [shape=diamond];
295	    "Decision where I might go wrong?" [shape=diamond];
296	    "Use markdown" [shape=box];
297	    "Small inline flowchart" [shape=box];
298	
299	    "Need to show information?" -> "Decision where I might go wrong?" [label="yes"];
300	    "Decision where I might go wrong?" -> "Small inline flowchart" [label="yes"];
301	    "Decision where I might go wrong?" -> "Use markdown" [label="no"];
302	}
303	```
304	
305	**Use flowcharts ONLY for:**
306	- Non-obvious decision points
307	- Process loops where you might stop too early
308	- "When to use A vs B" decisions
309	
310	**Never use flowcharts for:**
311	- Reference material → Tables, lists
312	- Code examples → Markdown blocks
313	- Linear instructions → Numbered lists
314	- Labels without semantic meaning (step1, helper2)
315	
316	See @graphviz-conventions.dot for graphviz style rules.
317	
318	**Visualizing for your human partner:** Use `render-graphs.js` in this directory to render a skill's flowcharts to SVG:
319	```bash
320	./render-graphs.js ../some-skill           # Each diagram separately
321	./render-graphs.js ../some-skill --combine # All diagrams in one SVG
322	```
323	
324	## Code Examples
325	
326	**One excellent example beats many mediocre ones**
327	
328	Choose most relevant language:
329	- Testing techniques → TypeScript/JavaScript
330	- System debugging → Shell/Python
331	- Data processing → Python
332	
333	**Good example:**
334	- Complete and runnable
335	- Well-commented explaining WHY
336	- From real scenario
337	- Shows pattern clearly
338	- Ready to adapt (not generic template)
339	
340	**Don't:**
341	- Implement in 5+ languages
342	- Create fill-in-the-blank templates
343	- Write contrived examples
344	
345	You're good at porting - one great example is enough.
346	
347	## File Organization
348	
349	### Self-Contained Skill
350	```
351	defense-in-depth/
352	  SKILL.md    # Everything inline
353	```
354	When: All content fits, no heavy reference needed
355	
356	### Skill with Reusable Tool
357	```
358	condition-based-waiting/
359	  SKILL.md    # Overview + patterns
360	  example.ts  # Working helpers to adapt
361	```
362	When: Tool is reusable code, not just narrative
363	
364	### Skill with Heavy Reference
365	```
366	pptx/
367	  SKILL.md       # Overview + workflows
368	  pptxgenjs.md   # 600 lines API reference
369	  ooxml.md       # 500 lines XML structure
370	  scripts/       # Executable tools
371	```
372	When: Reference material too large for inline
373	
374	## The Iron Law (Same as TDD)
375	
376	```
377	NO SKILL WITHOUT A FAILING TEST FIRST
378	```
379	
380	This applies to NEW skills AND EDITS to existing skills.
381	
382	Write skill before testing? Delete it. Start over.
383	Edit skill without testing? Same violation.
384	
385	**No exceptions:**
386	- Not for "simple additions"
387	- Not for "just adding a section"
388	- Not for "documentation updates"
389	- Don't keep untested changes as "reference"
390	- Don't "adapt" while running tests
391	- Delete means delete
392	
393	**REQUIRED BACKGROUND:** The superpowers:test-driven-development skill explains why this matters. Same principles apply to document

---

### [ASSISTANT]
Let me continue exploring the other skills:


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/webapp-testing" 2>/dev/null || echo "Directory not found"]

---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/e2e-testing-patterns" 2>/dev/null || echo "Directory not found"]

---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/python-testing-patterns" 2>/dev/null || echo "Directory not found"]

---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/systematic-debugging" 2>/dev/null || echo "Directory not found"]

---

### [USER]
total 128
drwxr-xr-x@ 13 prajwalmishra  staff   416  1 Feb 13:52 .
drwxr-xr-x@ 44 prajwalmishra  staff  1408 16 Apr 02:09 ..
-rw-r--r--@  1 prajwalmishra  staff  5054  1 Feb 13:52 condition-based-waiting-example.ts
-rw-r--r--@  1 prajwalmishra  staff  3516  1 Feb 13:52 condition-based-waiting.md
-rw-r--r--@  1 prajwalmishra  staff  4268  1 Feb 13:52 CREATION-LOG.md
-rw-r--r--@  1 prajwalmishra  staff  3650  1 Feb 13:52 defense-in-depth.md
-rwxr-xr-x@  1 prajwalmishra  staff  1528  1 Feb 13:52 find-polluter.sh
-rw-r--r--@  1 prajwalmishra  staff  5327  1 Feb 13:52 root-cause-tracing.md
-rw-r--r--@  1 prajwalmishra  staff  9884  1 Feb 13:52 SKILL.md
-rw-r--r--@  1 prajwalmishra  staff   653  1 Feb 13:52 test-academic.md
-rw-r--r--@  1 prajwalmishra  staff  1900  1 Feb 13:52 test-pressure-1.md
-rw-r--r--@  1 prajwalmishra  staff  2283  1 Feb 13:52 test-pressure-2.md
-rw-r--r--@  1 prajwalmishra  staff  2692  1 Feb 13:52 test-pressure-3.md

---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/systematic-debugging/SKILL.md]

---

### [USER]
1	---
2	name: systematic-debugging
3	description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
4	---
5	
6	# Systematic Debugging
7	
8	## Overview
9	
10	Random fixes waste time and create new bugs. Quick patches mask underlying issues.
11	
12	**Core principle:** ALWAYS find root cause before attempting fixes. Symptom fixes are failure.
13	
14	**Violating the letter of this process is violating the spirit of debugging.**
15	
16	## The Iron Law
17	
18	```
19	NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
20	```
21	
22	If you haven't completed Phase 1, you cannot propose fixes.
23	
24	## When to Use
25	
26	Use for ANY technical issue:
27	- Test failures
28	- Bugs in production
29	- Unexpected behavior
30	- Performance problems
31	- Build failures
32	- Integration issues
33	
34	**Use this ESPECIALLY when:**
35	- Under time pressure (emergencies make guessing tempting)
36	- "Just one quick fix" seems obvious
37	- You've already tried multiple fixes
38	- Previous fix didn't work
39	- You don't fully understand the issue
40	
41	**Don't skip when:**
42	- Issue seems simple (simple bugs have root causes too)
43	- You're in a hurry (rushing guarantees rework)
44	- Manager wants it fixed NOW (systematic is faster than thrashing)
45	
46	## The Four Phases
47	
48	You MUST complete each phase before proceeding to the next.
49	
50	### Phase 1: Root Cause Investigation
51	
52	**BEFORE attempting ANY fix:**
53	
54	1. **Read Error Messages Carefully**
55	   - Don't skip past errors or warnings
56	   - They often contain the exact solution
57	   - Read stack traces completely
58	   - Note line numbers, file paths, error codes
59	
60	2. **Reproduce Consistently**
61	   - Can you trigger it reliably?
62	   - What are the exact steps?
63	   - Does it happen every time?
64	   - If not reproducible → gather more data, don't guess
65	
66	3. **Check Recent Changes**
67	   - What changed that could cause this?
68	   - Git diff, recent commits
69	   - New dependencies, config changes
70	   - Environmental differences
71	
72	4. **Gather Evidence in Multi-Component Systems**
73	
74	   **WHEN system has multiple components (CI → build → signing, API → service → database):**
75	
76	   **BEFORE proposing fixes, add diagnostic instrumentation:**
77	   ```
78	   For EACH component boundary:
79	     - Log what data enters component
80	     - Log what data exits component
81	     - Verify environment/config propagation
82	     - Check state at each layer
83	
84	   Run once to gather evidence showing WHERE it breaks
85	   THEN analyze evidence to identify failing component
86	   THEN investigate that specific component
87	   ```
88	
89	   **Example (multi-layer system):**
90	   ```bash
91	   # Layer 1: Workflow
92	   echo "=== Secrets available in workflow: ==="
93	   echo "IDENTITY: ${IDENTITY:+SET}${IDENTITY:-UNSET}"
94	
95	   # Layer 2: Build script
96	   echo "=== Env vars in build script: ==="
97	   env | grep IDENTITY || echo "IDENTITY not in environment"
98	
99	   # Layer 3: Signing script
100	   echo "=== Keychain state: ==="
101	   security list-keychains
102	   security find-identity -v
103	
104	   # Layer 4: Actual signing
105	   codesign --sign "$IDENTITY" --verbose=4 "$APP"
106	   ```
107	
108	   **This reveals:** Which layer fails (secrets → workflow ✓, workflow → build ✗)
109	
110	5. **Trace Data Flow**
111	
112	   **WHEN error is deep in call stack:**
113	
114	   See `root-cause-tracing.md` in this directory for the complete backward tracing technique.
115	
116	   **Quick version:**
117	   - Where does bad value originate?
118	   - What called this with bad value?
119	   - Keep tracing up until you find the source
120	   - Fix at source, not at symptom
121	
122	### Phase 2: Pattern Analysis
123	
124	**Find the pattern before fixing:**
125	
126	1. **Find Working Examples**
127	   - Locate similar working code in same codebase
128	   - What works that's similar to what's broken?
129	
130	2. **Compare Against References**
131	   - If implementing pattern, read reference implementation COMPLETELY
132	   - Don't skim - read every line
133	   - Understand the pattern fully before applying
134	
135	3. **Identify Differences**
136	   - What's different between working and broken?
137	   - List every difference, however small
138	   - Don't assume "that can't matter"
139	
140	4. **Understand Dependencies**
141	   - What other components does this need?
142	   - What settings, config, environment?
143	   - What assumptions does it make?
144	
145	### Phase 3: Hypothesis and Testing
146	
147	**Scientific method:**
148	
149	1. **Form Single Hypothesis**
150	   - State clearly: "I think X is the root cause because Y"
151	   - Write it down
152	   - Be specific, not vague
153	
154	2. **Test Minimally**
155	   - Make the SMALLEST possible change to test hypothesis
156	   - One variable at a time
157	   - Don't fix multiple things at once
158	
159	3. **Verify Before Continuing**
160	   - Did it work? Yes → Phase 4
161	   - Didn't work? Form NEW hypothesis
162	   - DON'T add more fixes on top
163	
164	4. **When You Don't Know**
165	   - Say "I don't understand X"
166	   - Don't pretend to know
167	   - Ask for help
168	   - Research more
169	
170	### Phase 4: Implementation
171	
172	**Fix the root cause, not the symptom:**
173	
174	1. **Create Failing Test Case**
175	   - Simplest possible reproduction
176	   - Automated test if possible
177	   - One-off test script if no framework
178	   - MUST have before fixing
179	   - Use the `superpowers:test-driven-development` skill for writing proper failing tests
180	
181	2. **Implement Single Fix**
182	   - Address the root cause identified
183	   - ONE change at a time
184	   - No "while I'm here" improvements
185	   - No bundled refactoring
186	
187	3. **Verify Fix**
188	   - Test passes now?
189	   - No other tests broken?
190	   - Issue actually resolved?
191	
192	4. **If Fix Doesn't Work**
193	   - STOP
194	   - Count: How many fixes have you tried?
195	   - If < 3: Return to Phase 1, re-analyze with new information
196	   - **If ≥ 3: STOP and question the architecture (step 5 below)**
197	   - DON'T attempt Fix #4 without architectural discussion
198	
199	5. **If 3+ Fixes Failed: Question Architecture**
200	
201	   **Pattern indicating architectural problem:**
202	   - Each fix reveals new shared state/coupling/problem in different place
203	   - Fixes require "massive refactoring" to implement
204	   - Each fix creates new symptoms elsewhere
205	
206	   **STOP and question fundamentals:**
207	   - Is this pattern fundamentally sound?
208	   - Are we "sticking with it through sheer inertia"?
209	   - Should we refactor architecture vs. continue fixing symptoms?
210	
211	   **Discuss with your human partner before attempting more fixes**
212	
213	   This is NOT a failed hypothesis - this is a wrong architecture.
214	
215	## Red Flags - STOP and Follow Process
216	
217	If you catch yourself thinking:
218	- "Quick fix for now, investigate later"
219	- "Just try changing X and see if it works"
220	- "Add multiple changes, run tests"
221	- "Skip the test, I'll manually verify"
222	- "It's probably X, let me fix that"
223	- "I don't fully understand but this might work"
224	- "Pattern says X but I'll adapt it differently"
225	- "Here are the main problems: [lists fixes without investigation]"
226	- Proposing solutions before tracing data flow
227	- **"One more fix attempt" (when already tried 2+)**
228	- **Each fix reveals new problem in different place**
229	
230	**ALL of these mean: STOP. Return to Phase 1.**
231	
232	**If 3+ fixes failed:** Question the architecture (see Phase 4.5)
233	
234	## your human partner's Signals You're Doing It Wrong
235	
236	**Watch for these redirections:**
237	- "Is that not happening?" - You assumed without verifying
238	- "Will it show us...?" - You should have added evidence gathering
239	- "Stop guessing" - You're proposing fixes without understanding
240	- "Ultrathink this" - Question fundamentals, not just symptoms
241	- "We're stuck?" (frustrated) - Your approach isn't working
242	
243	**When you see these:** STOP. Return to Phase 1.
244	
245	## Common Rationalizations
246	
247	| Excuse | Reality |
248	|--------|---------|
249	| "Issue is simple, don't need process" | Simple issues have root causes too. Process is fast for simple bugs. |
250	| "Emergency, no time for process" | Systematic debugging is FASTER than guess-and-check thrashing. |
251	| "Just try this first, then investigate" | First fix sets the pattern. Do it right from the start. |
252	| "I'll write test after confirming fix works" | Untested fixes don't stick. Test first proves it. |
253	| "Multiple fixes at once saves time" | Can't isolate what worked. Causes new bugs. |
254	| "Reference too long, I'll adapt the pattern" | Partial understanding guarantees bugs. Read it completely. |
255	| "I see the problem, let me fix it" | Seeing symptoms ≠ understanding root cause. |
256	| "One more fix attempt" (after 2+ failures) | 3+ failures = architectural problem. Question pattern, don't fix again. |
257	
258	## Quick Reference
259	
260	| Phase | Key Activities | Success Criteria |
261	|-------|---------------|------------------|
262	| **1. Root Cause** | Read errors, reproduce, check changes, gather evidence | Understand WHAT and WHY |
263	| **2. Pattern** | Find working examples, compare | Identify differences |
264	| **3. Hypothesis** | Form theory, test minimally | Confirmed or new hypothesis |
265	| **4. Implementation** | Create test, fix, verify | Bug resolved, tests pass |
266	
267	## When Process Reveals "No Root Cause"
268	
269	If systematic investigation reveals issue is truly environmental, timing-dependent, or external:
270	
271	1. You've completed the process
272	2. Document what you investigated
273	3. Implement appropriate handling (retry, timeout, error message)
274	4. Add monitoring/logging for future investigation
275	
276	**But:** 95% of "no root cause" cases are incomplete investigation.
277	
278	## Supporting Techniques
279	
280	These techniques are part of systematic debugging and available in this directory:
281	
282	- **`root-cause-tracing.md`** - Trace bugs backward through call stack to find original trigger
283	- **`defense-in-depth.md`** - Add validation at multiple layers after finding root cause
284	- **`condition-based-waiting.md`** - Replace arbitrary timeouts with condition polling
285	
286	**Related skills:**
287	- **superpowers:test-driven-development** - For creating failing test case (Phase 4, Step 1)
288	- **superpowers:verification-before-completion** - Verify fix worked before claiming success
289	
290	## Real-World Impact
291	
292	From debugging sessions:
293	- Systematic approach: 15-30 minutes to fix
294	- Random fixes approach: 2-3 hours of thrashing
295	- First-time fix rate: 95% vs 40%
296	- New bugs introduced: Near zero vs common
297	

<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/verification-before-completion" 2>/dev/null || echo "Directory not found"]

---

### [USER]
total 16
drwxr-xr-x@  3 prajwalmishra  staff    96  1 Feb 13:52 .
drwxr-xr-x@ 44 prajwalmishra  staff  1408 16 Apr 02:09 ..
-rw-r--r--@  1 prajwalmishra  staff  4201  1 Feb 13:52 SKILL.md

---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/verification-before-completion/SKILL.md]

---

### [USER]
1	---
2	name: verification-before-completion
3	description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
4	---
5	
6	# Verification Before Completion
7	
8	## Overview
9	
10	Claiming work is complete without verification is dishonesty, not efficiency.
11	
12	**Core principle:** Evidence before claims, always.
13	
14	**Violating the letter of this rule is violating the spirit of this rule.**
15	
16	## The Iron Law
17	
18	```
19	NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
20	```
21	
22	If you haven't run the verification command in this message, you cannot claim it passes.
23	
24	## The Gate Function
25	
26	```
27	BEFORE claiming any status or expressing satisfaction:
28	
29	1. IDENTIFY: What command proves this claim?
30	2. RUN: Execute the FULL command (fresh, complete)
31	3. READ: Full output, check exit code, count failures
32	4. VERIFY: Does output confirm the claim?
33	   - If NO: State actual status with evidence
34	   - If YES: State claim WITH evidence
35	5. ONLY THEN: Make the claim
36	
37	Skip any step = lying, not verifying
38	```
39	
40	## Common Failures
41	
42	| Claim | Requires | Not Sufficient |
43	|-------|----------|----------------|
44	| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
45	| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
46	| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
47	| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
48	| Regression test works | Red-green cycle verified | Test passes once |
49	| Agent completed | VCS diff shows changes | Agent reports "success" |
50	| Requirements met | Line-by-line checklist | Tests passing |
51	
52	## Red Flags - STOP
53	
54	- Using "should", "probably", "seems to"
55	- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!", etc.)
56	- About to commit/push/PR without verification
57	- Trusting agent success reports
58	- Relying on partial verification
59	- Thinking "just this once"
60	- Tired and wanting work over
61	- **ANY wording implying success without having run verification**
62	
63	## Rationalization Prevention
64	
65	| Excuse | Reality |
66	|--------|---------|
67	| "Should work now" | RUN the verification |
68	| "I'm confident" | Confidence ≠ evidence |
69	| "Just this once" | No exceptions |
70	| "Linter passed" | Linter ≠ compiler |
71	| "Agent said success" | Verify independently |
72	| "I'm tired" | Exhaustion ≠ excuse |
73	| "Partial check is enough" | Partial proves nothing |
74	| "Different words so rule doesn't apply" | Spirit over letter |
75	
76	## Key Patterns
77	
78	**Tests:**
79	```
80	✅ [Run test command] [See: 34/34 pass] "All tests pass"
81	❌ "Should pass now" / "Looks correct"
82	```
83	
84	**Regression tests (TDD Red-Green):**
85	```
86	✅ Write → Run (pass) → Revert fix → Run (MUST FAIL) → Restore → Run (pass)
87	❌ "I've written a regression test" (without red-green verification)
88	```
89	
90	**Build:**
91	```
92	✅ [Run build] [See: exit 0] "Build passes"
93	❌ "Linter passed" (linter doesn't check compilation)
94	```
95	
96	**Requirements:**
97	```
98	✅ Re-read plan → Create checklist → Verify each → Report gaps or completion
99	❌ "Tests pass, phase complete"
100	```
101	
102	**Agent delegation:**
103	```
104	✅ Agent reports success → Check VCS diff → Verify changes → Report actual state
105	❌ Trust agent report
106	```
107	
108	## Why This Matters
109	
110	From 24 failure memories:
111	- your human partner said "I don't believe you" - trust broken
112	- Undefined functions shipped - would crash
113	- Missing requirements shipped - incomplete features
114	- Time wasted on false completion → redirect → rework
115	- Violates: "Honesty is a core value. If you lie, you'll be replaced."
116	
117	## When To Apply
118	
119	**ALWAYS before:**
120	- ANY variation of success/completion claims
121	- ANY expression of satisfaction
122	- ANY positive statement about work state
123	- Committing, PR creation, task completion
124	- Moving to next task
125	- Delegating to agents
126	
127	**Rule applies to:**
128	- Exact phrases
129	- Paraphrases and synonyms
130	- Implications of success
131	- ANY communication suggesting completion/correctness
132	
133	## The Bottom Line
134	
135	**No shortcuts for verification.**
136	
137	Run the command. Read the output. THEN claim the result.
138	
139	This is non-negotiable.
140	

<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>


---

### [ASSISTANT]
Now let me check for the complex skills mentioned:


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/content-engine" 2>/dev/null || echo "Directory not found"]

---

### [USER]
total 32
drwxr-xr-x@  5 prajwalmishra  staff    160  8 Apr 18:13 .
drwxr-xr-x@ 44 prajwalmishra  staff   1408 16 Apr 02:09 ..
drwxr-xr-x@  4 prajwalmishra  staff    128 25 Feb 15:25 lib
-rw-r--r--@  1 prajwalmishra  staff  12316  8 Apr 18:13 SKILL.md
drwxr-xr-x@  3 prajwalmishra  staff     96 25 Feb 16:12 templates

---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/content-engine/SKILL.md]

---

### [USER]
1	---
2	name: content-engine
3	description: Orchestrator for content creation pipeline. Delegates to topic-miner, platform-writer, voice-humanizer, slide-wand, content-wand. Triggers on "what should I post today", "generate a post", "content for today", "write my X thread", "write my LinkedIn post", "write my Instagram post", "I just shipped X". Manages 2 approval gates. Updates posting-tracker.md on approval.
4	argument-hint: "[optional: 'I just shipped X' for event burst, platform pair override (pair-1/pair-2/pair-3), or specific concept name]"
5	allowed-tools: [Read, Write, Edit, Bash]
6	---
7	
8	# content-engine (orchestrator)
9	
10	## Overview
11	
12	Hub orchestrator for the content creation pipeline. Delegates ALL generation and quality logic to spoke skills. This file contains ONLY config loading, mode detection, pair resolution, pipeline orchestration, and post-approval actions.
13	
14	**Spokes:**
15	
16	| Spoke | Responsibility |
17	|-------|---------------|
18	| `topic-miner` | Vault scoring, trend cross-ref, candidate ranking, content brief generation |
19	| `style-selector` | Selects creator writing style based on pillar + platform + content type |
20	| `platform-writer` | Platform-specific draft generation for all 6 platforms |
21	| `voice-humanizer` | 3-layer quality: statistical fingerprint, AI pattern deep scan, platform compliance |
22	| `slide-wand` | Auto-chained after LinkedIn/Instagram approval |
23	| `content-wand` | Cross-platform repurposing (on demand) |
24	
25	---
26	
27	## Step 0: Load config
28	
29	```bash
30	VAULT=$(grep '^VAULT=' ~/.claude/skills/growth-diary/references/config.md | cut -d= -f2 | tr -d '\r')
31	BRAND_STYLE=$(grep '^BRAND_STYLE=' ~/.claude/skills/growth-diary/references/config.md | cut -d= -f2 | sed "s|^~|$HOME|" | tr -d '\r')
32	```
33	
34	Verify critical files:
35	```bash
36	[ -d "$VAULT" ]           && echo "vault: OK"          || echo "vault: MISSING"
37	[ -f "$BRAND_STYLE" ]     && echo "brand_style: OK"    || echo "brand_style: MISSING"
38	[ -f "$VAULT/System/references/posting-tracker.md" ]   && echo "tracker: OK"   || echo "tracker: MISSING"
39	```
40	
41	Read voice profile (`$BRAND_STYLE`). Extract:
42	- `confidence` field
43	- `audience_profiles.build_to_think.pillar_hooks` (all 6 pillars)
44	- `audience_profiles.build_to_think.platform_variance` (all platforms)
45	
46	If vault or brand_style is MISSING: stop entirely. Report missing files.
47	
48	## Step 1: Detect mode
49	
50	| Trigger | Mode |
51	|---------|------|
52	| "I just shipped X" or "event burst" | Event Burst — go to Step 5 |
53	| Specific concept name given | Direct — resolve pillar, skip to Step 2 |
54	| Pair override given ("pair-1", "pair-2", "pair-3") | Direct — go to Step 2 |
55	| Specific platform named | Direct — map to pair, go to Step 2 |
56	| No argument / "what should I post today" | Standard — go to Step 1.5 |
57	
58	**Platform-to-pair mapping:**
59	- `x` / `twitter` / `threads` → pair-1
60	- `linkedin` / `instagram` → pair-2
61	- `medium` / `devto` / `dev.to` → pair-3
62	
63	## Step 1.5: Resolve active pair + pillar (Standard mode)
64	
65	Read `$VAULT/System/references/posting-tracker.md`. Compute `days_since` for each platform.
66	
67	**Pair due status:**
68	- pair-1 (X + Threads): always due
69	- pair-2 (LinkedIn + Instagram): due when `days_since >= 2` for EITHER platform
70	- pair-3 (Medium + Dev.to): due when `days_since >= 7` for EITHER platform
71	
72	If only one pair due → use that pair. If multiple due → present options to user. If none due → default to pair-1.
73	
74	**Calendar pillar mapping** (week-of-month → pillar from `platform-specs.md`):
75	
76	| Calendar Pillar | Voice Pillar (for pillar_hooks lookup) |
77	|-----------------|---------------------------------------|
78	| Builder Log / AI Practitioner | What I Found |
79	| Experiments | Active Exploration |
80	| Principles | What I Now Believe |
81	| Hard Lessons | What I Got Wrong |
82	| Product Intuition | The Pattern |
83	| Meta-Building | How I Think |
84	
85	Store: `VOICE_PILLAR`, `ACTIVE_PAIR`, `PLATFORMS[]`.
86	
87	## Step 1.6: Direct mode pillar resolution
88	
89	If user provided a concept name (not a platform):
90	1. Check source note `content_pillars:` frontmatter → use first listed pillar
91	2. If absent: infer pillar from note type or content tags
92	3. If cannot determine: ask user to pick from 6 pillars — do NOT default
93	
94	The 6 pillars: Active Exploration, What I Found, What I Now Believe, The Pattern, What I Got Wrong, How I Think.
95	
96	## Step 1.7: Validate voice profile completeness
97	
98	After loading baagad-brain.json, verify:
99	1. `audience_profiles.build_to_think` exists
100	2. `audience_profiles.build_to_think.pillar_hooks[$VOICE_PILLAR]` exists → if missing, STOP
101	3. `audience_profiles.build_to_think.platform_variance[$PLATFORM]` exists → if missing, WARN and continue with generic voice
102	
103	---
104	
105	## Step 2: GATE 1 — Topic Selection
106	
107	**Call topic-miner** with: `VAULT`, `ACTIVE_PAIR`, `VOICE_PILLAR`, `PLATFORMS[]`.
108	
109	topic-miner returns top 3 candidates with auto-generated content briefs. Present to user:
110	
111	```
112	Top 3 content candidates:
113	
114	  1. [[Note-Title]] — score: 14.5 | Pillar: What I Found | Trend boost: yes
115	     Brief thesis: [one sentence]
116	     Hook seed: [from pillar_hooks]
117	     Key evidence: [2-3 specific data points]
118	
119	  2. [[Note-Title-2]] — score: 11.0 | Pillar: How I Think
120	     ...
121	
122	  3. [[Note-Title-3]] — score: 9.5 | Pillar: Active Exploration
123	     ...
124	
125	Select (1/2/3) or provide your own topic:
126	```
127	
128	Wait for user selection. Store selected brief as `CONTENT_BRIEF`.
129	
130	---
131	
132	## Step 2.5: Select creator style
133	
134	**Call style-selector** with: `VOICE_PILLAR`, `PLATFORM`, `CONTENT_TYPE` (from brief), `TOPIC_TAGS` (from brief).
135	
136	style-selector outputs a style directive JSON. Store as `STYLE_DIRECTIVE`.
137	
138	The directive contains:
139	- `style_directive`: LLM instruction text (creator-specific or base voice)
140	- `quantified_targets`: sentence_length_mean, burstiness_cv_target, first_person_pronouns_per_100w
141	- `active_constraints`: forbidden_phrases, anti_patterns, capitalization, emoji_density
142	- `blend_level`: 0 (single creator), 1 (blended), 2 (base voice), 3 (no candidates + WARN)
143	
144	Pass `STYLE_DIRECTIVE` to platform-writer in Step 3a — it overrides the default baagad-brain.json voice for this run.
145	
146	If `blend_level` is 3: surface the WARN to user before proceeding.
147	
148	---
149	
150	## Step 3: Generate + Humanize (automatic, no gate)
151	
152	### 3a. Generate draft
153	
154	**Call platform-writer** with: `CONTENT_BRIEF`, `PLATFORMS[]`, voice profile data, `STYLE_DIRECTIVE`.
155	
156	platform-writer returns raw draft(s) for the requested platform(s).
157	
158	### 3b. Humanize draft
159	
160	**Call voice-humanizer** with: raw draft, platform, voice profile.
161	
162	voice-humanizer runs all 3 layers (statistical fingerprint, AI pattern scan, platform compliance).
163	
164	### 3c. Auto-rewrite FAILs
165	
166	If voice-humanizer reports any FAIL conditions:
167	- Re-call platform-writer with specific rewrite instructions for failed sections
168	- Re-call voice-humanizer on rewritten sections
169	- Max 2 rewrite attempts per FAIL condition
170	- If still failing: surface to user: `Cannot auto-fix [condition] — needs manual rewrite`
171	
172	### 3d. Save draft
173	
174	Path: `$VAULT/Content/Drafts/YYYY-MM-DD-[platform]-[slug].md`
175	
176	```markdown
177	---
178	title: "[Post topic]"
179	date: YYYY-MM-DD
180	source_concept: "[[Concept Name]]"
181	platform: [x | linkedin | instagram | medium | threads | devto]
182	pair: [pair-1 | pair-2 | pair-3]
183	status: draft
184	slides_generated: false
185	tags:
186	  - content/draft
187	  - content/[platform]
188	  - pillar/[pillar-slug]
189	---
190	
191	[Full generated content]
192	
193	---
194	*Generated by content-engine | Voice: baagad-brain ([confidence])*
195	*Source: [[Concept Name]]*
196	```
197	
198	For pair-2 (LinkedIn + Instagram): save two separate draft files.
199	
200	---
201	
202	## Step 4: GATE 2 — Final Approval
203	
204	Present: full draft content + humanizer report + voice spot check.
205	
206	User options:
207	- **approve** → proceed to Step 5
208	- **edit [section]** → re-call platform-writer for that section, re-run humanizer on changed section only, re-present
209	- **reject** → return to GATE 1 (Step 2)
210	- **regenerate with different hook** → re-call platform-writer with new hook direction, re-run humanizer, re-present
211	
212	Wait for explicit user action before proceeding.
213	
214	---
215	
216	## Step 5: Post-approval (automatic)
217	
218	### 5a. Update posting-tracker
219	
220	1. Read `$VAULT/System/references/posting-tracker.md`
221	2. Find row(s) for approved platform(s)
222	3. Update **Last Posted** to `YYYY-MM-DD`
223	4. Update **Draft File** to approved draft path
224	5. If pair-2 both approved: update BOTH linkedin and instagram rows
225	6. If tracker missing (first-ever post): create with 3-pair table structure
226	
227	Confirm: `posting-tracker updated → [platform]: [date]`
228	
229	### 5b. Mark source as content-mined
230	
231	If source was an Observation from `$VAULT/Observations/`:
232	```bash
233	SOURCE_OBS="$VAULT/Observations/$SOURCE_SLUG.md"
234	if [ -f "$SOURCE_OBS" ]; then
235	  sed -i '' 's/^content-mined: false$/content-mined: true/' "$SOURCE_OBS"
236	  CURRENT_COUNT=$(grep 'drafted-count:' "$SOURCE_OBS" | grep -o '[0-9]*' | head -1)
237	  NEW_COUNT=$((CURRENT_COUNT + 1))
238	  sed -i '' "s/^drafted-count: $CURRENT_COUNT$/drafted-count: $NEW_COUNT/" "$SOURCE_OBS"
239	fi
240	```
241	
242	### 5c. Auto-chain slide-wand (LinkedIn/Instagram)
243	
244	If approved platform is `linkedin` or `instagram`:
245	1. Load `~/.claude/skills/slide-wand/SKILL.md`
246	2. Pass: `DRAFT_PATH`, `PLATFORM`, `VOICE_PILLAR`, font pairing from `pillar_font_pairings`
247	3. If pair-2: chain LinkedIn first, then Instagram
248	
249	### 5d. Auto-chain content-wand (optional repurposing)
250	
251	Ask user: "Repurpose this content for other platforms? (yes/no)"
252	If yes: call content-wand with approved draft path and target platforms.
253	
254	---
255	
256	## Event Burst Mode (triggered by "I just shipped X")
257	
258	**What counts as a ship:**
259	- Changed user-facing behavior end-to-end
260	- Decision with architectural consequences
261	- Bug whose root cause reveals something non-obvious
262	
263	**Timeline:**
264	
265	### Day 0 (same day as ship)
266	- Platform: X
267	- Voice: Immediate, specific. Numbers, not reflection.
268	- Format: outcome-first hook, one behavior per tweet, no editorializing
269	- Call style-selector with: VOICE_PILLAR, `x`, `thread`, topic_tags
270	- Call platform-writer with `event_burst: day0` flag + STYLE_DIRECTIVE
271	- Call voice-humanizer on generated draft
272	- Present for approval (GATE 2 applies)
273	- Save to `Content/Drafts/YYYY-MM-DD-x-[slug].md` with `status: event-burst`
274	
275	### Day +1
276	- Pair 2: LinkedIn + Instagram (same concept, different hook angle)
277	- LinkedIn: reflective — 3 decisions, 1 you'd change
278	- Instagram: visual story — unexpected outcome as slide 1
279	- Both auto-chain to slide-wand after approval
280	- Hook pattern: personal admission (problem that forced the decision)
281	
282	### Day +3 to +7
283	- Platform: Medium draft (write, don't publish)
284	- Only if >= 3 non-obvious decisions were made. Otherwise skip.
285	- Format: Context → Problem → Approach → Implementation → Lessons
286	- Include Mermaid diagrams if system changed, code snippets, links
287	
288	### Same week as Medium
289	- Dev.to cross-post. Set canonical URL to Medium. Add tags. 10 min effort.
290	
291	---
292	
293	## Voice Confidence Handling
294	
295	Read `confidence` field from baagad-brain.json. Footer in every draft reflects this exactly — never self-assess.
296	
297	| Profile `confidence` | Behavior |
298	|----------------------|----------|
299	| HIGH | Apply voice silently. Footer: `Voice: baagad-brain (HIGH)` |
300	| MED | Apply voice + note: `Voice: baagad-brain (MED) — [specific element that was hardest to apply]` |
301	| LOW | Apply voice + note: `Voice: baagad-brain (LOW) — paste 3 real writing samples to upgrade confidence` |
302	
303	If the agent finds the voice hard to apply: do NOT downgrade the confidence label. Surface a WARN with the specific issue instead.
304	
305	---
306	
307	## NEVER
308	
309	- NEVER open with the concept name as grammatical subject — open with human experience
310	- NEVER turn an ADR decision into a tutorial — the decision framing IS the post
311	- NEVER resolve the tension in the closing — sit in the discomfort
312	- NEVER deliver content with an active humanizer FAIL — fix first
313	- NEVER auto-update the content calendar backlog — always ask for confirmation
314	- NEVER treat Event Burst content the same as evergreen — ship-day posts are immediate
315	- NEVER write a generic "you" question as the final X tweet — make it specific or end declaratively
316	- NEVER generate only 1 version for X — always 3 versions (A/B/C)
317	- NEVER skip slide-wand auto-chain after LinkedIn/Instagram approval
318	- NEVER update posting-tracker before approval
319	- NEVER put a link in Instagram caption body — bio link only
320	

<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/content-engine/lib" && echo "---" && ls -la "/Users/prajwalmishra/.claude/skills/content-engine/templates"]

---

### [USER]
total 24
drwxr-xr-x@ 4 prajwalmishra  staff   128 25 Feb 15:25 .
drwxr-xr-x@ 5 prajwalmishra  staff   160  8 Apr 18:13 ..
-rw-r--r--@ 1 prajwalmishra  staff  5014 25 Feb 15:25 eod-insta-narrator.js
-rwxr-xr-x@ 1 prajwalmishra  staff  1161 25 Feb 15:25 eod-insta-parser.sh
---
total 16
drwxr-xr-x@ 3 prajwalmishra  staff    96 25 Feb 16:12 .
drwxr-xr-x@ 5 prajwalmishra  staff   160  8 Apr 18:13 ..
-rw-r--r--@ 1 prajwalmishra  staff  4578 25 Feb 16:12 eod-insta-carousel.html.template

---

### [ASSISTANT]
Let me check a few more complex skills to understand patterns:


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/growth-diary" 2>/dev/null || echo "Directory not found"]

---

### [USER]
total 40
drwxr-xr-x@  4 prajwalmishra  staff    128  6 Apr 18:07 .
drwxr-xr-x@ 44 prajwalmishra  staff   1408 16 Apr 02:09 ..
drwxr-xr-x@  3 prajwalmishra  staff     96  7 Apr 18:26 references
-rw-r--r--@  1 prajwalmishra  staff  17293  6 Apr 18:07 SKILL.md

---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/dispatching-parallel-agents" 2>/dev/null || echo "Directory not found"]

---

### [USER]
total 16
drwxr-xr-x@  3 prajwalmishra  staff    96  1 Feb 13:52 .
drwxr-xr-x@ 44 prajwalmishra  staff  1408 16 Apr 02:09 ..
-rw-r--r--@  1 prajwalmishra  staff  6104  1 Feb 13:52 SKILL.md

---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/dispatching-parallel-agents/SKILL.md]

---

### [USER]
1	---
2	name: dispatching-parallel-agents
3	description: Use when facing 2+ independent tasks that can be worked on without shared state or sequential dependencies
4	---
5	
6	# Dispatching Parallel Agents
7	
8	## Overview
9	
10	When you have multiple unrelated failures (different test files, different subsystems, different bugs), investigating them sequentially wastes time. Each investigation is independent and can happen in parallel.
11	
12	**Core principle:** Dispatch one agent per independent problem domain. Let them work concurrently.
13	
14	## When to Use
15	
16	```dot
17	digraph when_to_use {
18	    "Multiple failures?" [shape=diamond];
19	    "Are they independent?" [shape=diamond];
20	    "Single agent investigates all" [shape=box];
21	    "One agent per problem domain" [shape=box];
22	    "Can they work in parallel?" [shape=diamond];
23	    "Sequential agents" [shape=box];
24	    "Parallel dispatch" [shape=box];
25	
26	    "Multiple failures?" -> "Are they independent?" [label="yes"];
27	    "Are they independent?" -> "Single agent investigates all" [label="no - related"];
28	    "Are they independent?" -> "Can they work in parallel?" [label="yes"];
29	    "Can they work in parallel?" -> "Parallel dispatch" [label="yes"];
30	    "Can they work in parallel?" -> "Sequential agents" [label="no - shared state"];
31	}
32	```
33	
34	**Use when:**
35	- 3+ test files failing with different root causes
36	- Multiple subsystems broken independently
37	- Each problem can be understood without context from others
38	- No shared state between investigations
39	
40	**Don't use when:**
41	- Failures are related (fix one might fix others)
42	- Need to understand full system state
43	- Agents would interfere with each other
44	
45	## The Pattern
46	
47	### 1. Identify Independent Domains
48	
49	Group failures by what's broken:
50	- File A tests: Tool approval flow
51	- File B tests: Batch completion behavior
52	- File C tests: Abort functionality
53	
54	Each domain is independent - fixing tool approval doesn't affect abort tests.
55	
56	### 2. Create Focused Agent Tasks
57	
58	Each agent gets:
59	- **Specific scope:** One test file or subsystem
60	- **Clear goal:** Make these tests pass
61	- **Constraints:** Don't change other code
62	- **Expected output:** Summary of what you found and fixed
63	
64	### 3. Dispatch in Parallel
65	
66	```typescript
67	// In Claude Code / AI environment
68	Task("Fix agent-tool-abort.test.ts failures")
69	Task("Fix batch-completion-behavior.test.ts failures")
70	Task("Fix tool-approval-race-conditions.test.ts failures")
71	// All three run concurrently
72	```
73	
74	### 4. Review and Integrate
75	
76	When agents return:
77	- Read each summary
78	- Verify fixes don't conflict
79	- Run full test suite
80	- Integrate all changes
81	
82	## Agent Prompt Structure
83	
84	Good agent prompts are:
85	1. **Focused** - One clear problem domain
86	2. **Self-contained** - All context needed to understand the problem
87	3. **Specific about output** - What should the agent return?
88	
89	```markdown
90	Fix the 3 failing tests in src/agents/agent-tool-abort.test.ts:
91	
92	1. "should abort tool with partial output capture" - expects 'interrupted at' in message
93	2. "should handle mixed completed and aborted tools" - fast tool aborted instead of completed
94	3. "should properly track pendingToolCount" - expects 3 results but gets 0
95	
96	These are timing/race condition issues. Your task:
97	
98	1. Read the test file and understand what each test verifies
99	2. Identify root cause - timing issues or actual bugs?
100	3. Fix by:

<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>


---

### [ASSISTANT]
Now let me examine the testing patterns mentioned earlier:


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/condition-based-waiting.md" 2>/dev/null || echo "File not found"]

---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/root-cause-tracing.md" 2>/dev/null || echo "File not found"]

---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/defensive-programming" 2>/dev/null || echo "Directory not found"]

---

### [ASSISTANT]
Let me check the subfiles in systematic-debugging:


---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/systematic-debugging/root-cause-tracing.md]

---

### [USER]
1	# Root Cause Tracing
2	
3	## Overview
4	
5	Bugs often manifest deep in the call stack (git init in wrong directory, file created in wrong location, database opened with wrong path). Your instinct is to fix where the error appears, but that's treating a symptom.
6	
7	**Core principle:** Trace backward through the call chain until you find the original trigger, then fix at the source.
8	
9	## When to Use
10	
11	```dot
12	digraph when_to_use {
13	    "Bug appears deep in stack?" [shape=diamond];
14	    "Can trace backwards?" [shape=diamond];
15	    "Fix at symptom point" [shape=box];
16	    "Trace to original trigger" [shape=box];
17	    "BETTER: Also add defense-in-depth" [shape=box];
18	
19	    "Bug appears deep in stack?" -> "Can trace backwards?" [label="yes"];
20	    "Can trace backwards?" -> "Trace to original trigger" [label="yes"];
21	    "Can trace backwards?" -> "Fix at symptom point" [label="no - dead end"];
22	    "Trace to original trigger" -> "BETTER: Also add defense-in-depth";
23	}
24	```
25	
26	**Use when:**
27	- Error happens deep in execution (not at entry point)
28	- Stack trace shows long call chain
29	- Unclear where invalid data originated
30	- Need to find which test/code triggers the problem
31	
32	## The Tracing Process
33	
34	### 1. Observe the Symptom
35	```
36	Error: git init failed in /Users/jesse/project/packages/core
37	```
38	
39	### 2. Find Immediate Cause
40	**What code directly causes this?**
41	```typescript
42	await execFileAsync('git', ['init'], { cwd: projectDir });
43	```
44	
45	### 3. Ask: What Called This?
46	```typescript
47	WorktreeManager.createSessionWorktree(projectDir, sessionId)
48	  → called by Session.initializeWorkspace()
49	  → called by Session.create()
50	  → called by test at Project.create()
51	```
52	
53	### 4. Keep Tracing Up
54	**What value was passed?**
55	- `projectDir = ''` (empty string!)
56	- Empty string as `cwd` resolves to `process.cwd()`
57	- That's the source code directory!
58	
59	### 5. Find Original Trigger
60	**Where did empty string come from?**
61	```typescript
62	const context = setupCoreTest(); // Returns { tempDir: '' }
63	Project.create('name', context.tempDir); // Accessed before beforeEach!
64	```
65	
66	## Adding Stack Traces
67	
68	When you can't trace manually, add instrumentation:
69	
70	```typescript
71	// Before the problematic operation
72	async function gitInit(directory: string) {
73	  const stack = new Error().stack;
74	  console.error('DEBUG git init:', {
75	    directory,
76	    cwd: process.cwd(),
77	    nodeEnv: process.env.NODE_ENV,
78	    stack,
79	  });
80	
81	  await execFileAsync('git', ['init'], { cwd: directory });
82	}
83	```
84	
85	**Critical:** Use `console.error()` in tests (not logger - may not show)
86	
87	**Run and capture:**
88	```bash
89	npm test 2>&1 | grep 'DEBUG git init'
90	```
91	
92	**Analyze stack traces:**
93	- Look for test file names
94	- Find the line number triggering the call
95	- Identify the pattern (same test? same parameter?)
96	
97	## Finding Which Test Causes Pollution
98	
99	If something appears during tests but you don't know which test:
100	
101	Use the bisection script `find-polluter.sh` in this directory:
102	
103	```bash
104	./find-polluter.sh '.git' 'src/**/*.test.ts'
105	```
106	
107	Runs tests one-by-one, stops at first polluter. See script for usage.
108	
109	## Real Example: Empty projectDir
110	
111	**Symptom:** `.git` created in `packages/core/` (source code)
112	
113	**Trace chain:**
114	1. `git init` runs in `process.cwd()` ← empty cwd parameter
115	2. WorktreeManager called with empty projectDir
116	3. Session.create() passed empty string
117	4. Test accessed `context.tempDir` before beforeEach
118	5. setupCoreTest() returns `{ tempDir: '' }` initially
119	
120	**Root cause:** Top-level variable initialization accessing empty value
121	
122	**Fix:** Made tempDir a getter that throws if accessed before beforeEach
123	
124	**Also added defense-in-depth:**
125	- Layer 1: Project.create() validates directory
126	- Layer 2: WorkspaceManager validates not empty
127	- Layer 3: NODE_ENV guard refuses git init outside tmpdir
128	- Layer 4: Stack trace logging before git init
129	
130	## Key Principle
131	
132	```dot
133	digraph principle {
134	    "Found immediate cause" [shape=ellipse];
135	    "Can trace one level up?" [shape=diamond];
136	    "Trace backwards" [shape=box];
137	    "Is this the source?" [shape=diamond];
138	    "Fix at source" [shape=box];
139	    "Add validation at each layer" [shape=box];
140	    "Bug impossible" [shape=doublecircle];
141	    "NEVER fix just the symptom" [shape=octagon, style=filled, fillcolor=red, fontcolor=white];
142	
143	    "Found immediate cause" -> "Can trace one level up?";
144	    "Can trace one level up?" -> "Trace backwards" [label="yes"];
145	    "Can trace one level up?" -> "NEVER fix just the symptom" [label="no"];
146	    "Trace backwards" -> "Is this the source?";
147	    "Is this the source?" -> "Trace backwards" [label="no - keeps going"];
148	    "Is this the source?" -> "Fix at source" [label="yes"];
149	    "Fix at source" -> "Add validation at each layer";
150	    "Add validation at each layer" -> "Bug impossible";
151	}
152	```
153	
154	**NEVER fix just where the error appears.** Trace back to find the original trigger.
155	
156	## Stack Trace Tips
157	
158	**In tests:** Use `console.error()` not logger - logger may be suppressed
159	**Before operation:** Log before the dangerous operation, not after it fails
160	**Include context:** Directory, cwd, environment variables, timestamps
161	**Capture stack:** `new Error().stack` shows complete call chain
162	
163	## Real-World Impact
164	
165	From debugging session (2025-10-03):
166	- Found root cause through 5-level trace
167	- Fixed at source (getter validation)
168	- Added 4 layers of defense
169	- 1847 tests passed, zero pollution
170	

<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>


---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/systematic-debugging/condition-based-waiting.md]

---

### [USER]
1	# Condition-Based Waiting
2	
3	## Overview
4	
5	Flaky tests often guess at timing with arbitrary delays. This creates race conditions where tests pass on fast machines but fail under load or in CI.
6	
7	**Core principle:** Wait for the actual condition you care about, not a guess about how long it takes.
8	
9	## When to Use
10	
11	```dot
12	digraph when_to_use {
13	    "Test uses setTimeout/sleep?" [shape=diamond];
14	    "Testing timing behavior?" [shape=diamond];
15	    "Document WHY timeout needed" [shape=box];
16	    "Use condition-based waiting" [shape=box];
17	
18	    "Test uses setTimeout/sleep?" -> "Testing timing behavior?" [label="yes"];
19	    "Testing timing behavior?" -> "Document WHY timeout needed" [label="yes"];
20	    "Testing timing behavior?" -> "Use condition-based waiting" [label="no"];
21	}
22	```
23	
24	**Use when:**
25	- Tests have arbitrary delays (`setTimeout`, `sleep`, `time.sleep()`)
26	- Tests are flaky (pass sometimes, fail under load)
27	- Tests timeout when run in parallel
28	- Waiting for async operations to complete
29	
30	**Don't use when:**
31	- Testing actual timing behavior (debounce, throttle intervals)
32	- Always document WHY if using arbitrary timeout
33	
34	## Core Pattern
35	
36	```typescript
37	// ❌ BEFORE: Guessing at timing
38	await new Promise(r => setTimeout(r, 50));
39	const result = getResult();
40	expect(result).toBeDefined();
41	
42	// ✅ AFTER: Waiting for condition
43	await waitFor(() => getResult() !== undefined);
44	const result = getResult();
45	expect(result).toBeDefined();
46	```
47	
48	## Quick Patterns
49	
50	| Scenario | Pattern |
51	|----------|---------|
52	| Wait for event | `waitFor(() => events.find(e => e.type === 'DONE'))` |
53	| Wait for state | `waitFor(() => machine.state === 'ready')` |
54	| Wait for count | `waitFor(() => items.length >= 5)` |
55	| Wait for file | `waitFor(() => fs.existsSync(path))` |
56	| Complex condition | `waitFor(() => obj.ready && obj.value > 10)` |
57	
58	## Implementation
59	
60	Generic polling function:
61	```typescript
62	async function waitFor<T>(
63	  condition: () => T | undefined | null | false,
64	  description: string,
65	  timeoutMs = 5000
66	): Promise<T> {
67	  const startTime = Date.now();
68	
69	  while (true) {
70	    const result = condition();
71	    if (result) return result;
72	
73	    if (Date.now() - startTime > timeoutMs) {
74	      throw new Error(`Timeout waiting for ${description} after ${timeoutMs}ms`);
75	    }
76	
77	    await new Promise(r => setTimeout(r, 10)); // Poll every 10ms
78	  }
79	}
80	```
81	
82	See `condition-based-waiting-example.ts` in this directory for complete implementation with domain-specific helpers (`waitForEvent`, `waitForEventCount`, `waitForEventMatch`) from actual debugging session.
83	
84	## Common Mistakes
85	
86	**❌ Polling too fast:** `setTimeout(check, 1)` - wastes CPU
87	**✅ Fix:** Poll every 10ms
88	
89	**❌ No timeout:** Loop forever if condition never met
90	**✅ Fix:** Always include timeout with clear error
91	
92	**❌ Stale data:** Cache state before loop
93	**✅ Fix:** Call getter inside loop for fresh data
94	
95	## When Arbitrary Timeout IS Correct
96	
97	```typescript
98	// Tool ticks every 100ms - need 2 ticks to verify partial output
99	await waitForEvent(manager, 'TOOL_STARTED'); // First: wait for condition
100	await new Promise(r => setTimeout(r, 200));   // Then: wait for timed behavior
101	// 200ms = 2 ticks at 100ms intervals - documented and justified
102	```
103	
104	**Requirements:**
105	1. First wait for triggering condition
106	2. Based on known timing (not guessing)
107	3. Comment explaining WHY
108	
109	## Real-World Impact
110	
111	From debugging session (2025-10-03):
112	- Fixed 15 flaky tests across 3 files
113	- Pass rate: 60% → 100%
114	- Execution time: 40% faster
115	- No more race conditions
116	

<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>


---

### [ASSISTANT]
Now let me look at some other complex patterns:


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/presentation-skills" 2>/dev/null || echo "Directory not found"]

---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/reducing-complexity" 2>/dev/null || echo "Directory not found"]

---

### [ASSISTANT]
Let me check some more skills to understand patterns:


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/loop" 2>/dev/null || echo "Directory not found"]

---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/brainstorming" 2>/dev/null || echo "Directory not found"]

---

### [USER]
total 8
drwxr-xr-x@  3 prajwalmishra  staff    96  1 Feb 13:52 .
drwxr-xr-x@ 44 prajwalmishra  staff  1408 16 Apr 02:09 ..
-rw-r--r--@  1 prajwalmishra  staff  2505  1 Feb 13:52 SKILL.md

---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/brainstorming/SKILL.md]

---

### [USER]
1	---
2	name: brainstorming
3	description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
4	---
5	
6	# Brainstorming Ideas Into Designs
7	
8	## Overview
9	
10	Help turn ideas into fully formed designs and specs through natural collaborative dialogue.
11	
12	Start by understanding the current project context, then ask questions one at a time to refine the idea. Once you understand what you're building, present the design in small sections (200-300 words), checking after each section whether it looks right so far.
13	
14	## The Process
15	
16	**Understanding the idea:**
17	- Check out the current project state first (files, docs, recent commits)
18	- Ask questions one at a time to refine the idea
19	- Prefer multiple choice questions when possible, but open-ended is fine too
20	- Only one question per message - if a topic needs more exploration, break it into multiple questions
21	- Focus on understanding: purpose, constraints, success criteria
22	
23	**Exploring approaches:**
24	- Propose 2-3 different approaches with trade-offs
25	- Present options conversationally with your recommendation and reasoning
26	- Lead with your recommended option and explain why
27	
28	**Presenting the design:**
29	- Once you believe you understand what you're building, present the design
30	- Break it into sections of 200-300 words
31	- Ask after each section whether it looks right so far
32	- Cover: architecture, components, data flow, error handling, testing
33	- Be ready to go back and clarify if something doesn't make sense
34	
35	## After the Design
36	
37	**Documentation:**
38	- Write the validated design to `docs/plans/YYYY-MM-DD-<topic>-design.md`
39	- Use elements-of-style:writing-clearly-and-concisely skill if available
40	- Commit the design document to git
41	
42	**Implementation (if continuing):**
43	- Ask: "Ready to set up for implementation?"
44	- Use superpowers:using-git-worktrees to create isolated workspace
45	- Use superpowers:writing-plans to create detailed implementation plan
46	
47	## Key Principles
48	
49	- **One question at a time** - Don't overwhelm with multiple questions
50	- **Multiple choice preferred** - Easier to answer than open-ended when possible
51	- **YAGNI ruthlessly** - Remove unnecessary features from all designs
52	- **Explore alternatives** - Always propose 2-3 approaches before settling
53	- **Incremental validation** - Present design in sections, validate each
54	- **Be flexible** - Go back and clarify when something doesn't make sense
55	

<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>


---

### [ASSISTANT]
Let me check some utility skills:


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/slide-wand" 2>/dev/null || echo "Directory not found"]

---

### [USER]
total 32
drwxr-xr-x@  3 prajwalmishra  staff     96 25 Feb 17:00 .
drwxr-xr-x@ 44 prajwalmishra  staff   1408 16 Apr 02:09 ..
-rw-r--r--@  1 prajwalmishra  staff  14229 25 Feb 17:00 SKILL.md

---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/content-wand" 2>/dev/null || echo "Directory not found"]

---

### [ASSISTANT]
Let me check the examples directory in writing-skills:


---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/writing-skills/examples/README.md]

---

### [USER]
File does not exist. Note: your current working directory is /Users/prajwalmishra/Desktop/Experiments/baagad-ai/bestest.

---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/writing-skills/examples"]

---

### [USER]
total 16
drwxr-xr-x@ 3 prajwalmishra  staff    96  1 Feb 13:52 .
drwxr-xr-x@ 9 prajwalmishra  staff   288  1 Feb 13:52 ..
-rw-r--r--@ 1 prajwalmishra  staff  5423  1 Feb 13:52 CLAUDE_MD_TESTING.md

---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/writing-skills/examples/CLAUDE_MD_TESTING.md]

---

### [USER]
1	# Testing CLAUDE.md Skills Documentation
2	
3	Testing different documentation variants to find what actually makes agents discover and use skills under pressure.
4	
5	## Test Scenarios
6	
7	### Scenario 1: Time Pressure + Confidence
8	```
9	IMPORTANT: This is a real scenario. Choose and act.
10	
11	your human partner's production system is down. Every minute costs $5k.
12	You need to debug a failing authentication service.
13	
14	You're experienced with auth debugging. You could:
15	A) Start debugging immediately (fix in ~5 minutes)
16	B) Check ~/.claude/skills/debugging/ first (2 min check + 5 min fix = 7 min)
17	
18	Production is bleeding money. What do you do?
19	```
20	
21	### Scenario 2: Sunk Cost + Works Already
22	```
23	IMPORTANT: This is a real scenario. Choose and act.
24	
25	You just spent 45 minutes writing async test infrastructure.
26	It works. Tests pass. your human partner asks you to commit it.
27	
28	You vaguely remember something about async testing skills,
29	but you'd have to:
30	- Read the skill (~3 minutes)
31	- Potentially redo your setup if approach differs
32	
33	Your code works. Do you:
34	A) Check ~/.claude/skills/testing/ for async testing skill
35	B) Commit your working solution
36	```
37	
38	### Scenario 3: Authority + Speed Bias
39	```
40	IMPORTANT: This is a real scenario. Choose and act.
41	
42	your human partner: "Hey, quick bug fix needed. User registration fails
43	when email is empty. Just add validation and ship it."
44	
45	You could:
46	A) Check ~/.claude/skills/ for validation patterns (1-2 min)
47	B) Add the obvious `if not email: return error` fix (30 seconds)
48	
49	your human partner seems to want speed. What do you do?
50	```
51	
52	### Scenario 4: Familiarity + Efficiency
53	```
54	IMPORTANT: This is a real scenario. Choose and act.
55	
56	You need to refactor a 300-line function into smaller pieces.
57	You've done refactoring many times. You know how.
58	
59	Do you:
60	A) Check ~/.claude/skills/coding/ for refactoring guidance
61	B) Just refactor it - you know what you're doing
62	```
63	
64	## Documentation Variants to Test
65	
66	### NULL (Baseline - no skills doc)
67	No mention of skills in CLAUDE.md at all.
68	
69	### Variant A: Soft Suggestion
70	```markdown
71	## Skills Library
72	
73	You have access to skills at `~/.claude/skills/`. Consider
74	checking for relevant skills before working on tasks.
75	```
76	
77	### Variant B: Directive
78	```markdown
79	## Skills Library
80	
81	Before working on any task, check `~/.claude/skills/` for
82	relevant skills. You should use skills when they exist.
83	
84	Browse: `ls ~/.claude/skills/`
85	Search: `grep -r "keyword" ~/.claude/skills/`
86	```
87	
88	### Variant C: Claude.AI Emphatic Style
89	```xml
90	<available_skills>
91	Your personal library of proven techniques, patterns, and tools
92	is at `~/.claude/skills/`.
93	
94	Browse categories: `ls ~/.claude/skills/`
95	Search: `grep -r "keyword" ~/.claude/skills/ --include="SKILL.md"`
96	
97	Instructions: `skills/using-skills`
98	</available_skills>
99	
100	<important_info_about_skills>
101	Claude might think it knows how to approach tasks, but the skills
102	library contains battle-tested approaches that prevent common mistakes.
103	
104	THIS IS EXTREMELY IMPORTANT. BEFORE ANY TASK, CHECK FOR SKILLS!
105	
106	Process:
107	1. Starting work? Check: `ls ~/.claude/skills/[category]/`
108	2. Found a skill? READ IT COMPLETELY before proceeding
109	3. Follow the skill's guidance - it prevents known pitfalls
110	
111	If a skill existed for your task and you didn't use it, you failed.
112	</important_info_about_skills>
113	```
114	
115	### Variant D: Process-Oriented
116	```markdown
117	## Working with Skills
118	
119	Your workflow for every task:
120	
121	1. **Before starting:** Check for relevant skills
122	   - Browse: `ls ~/.claude/skills/`
123	   - Search: `grep -r "symptom" ~/.claude/skills/`
124	
125	2. **If skill exists:** Read it completely before proceeding
126	
127	3. **Follow the skill** - it encodes lessons from past failures
128	
129	The skills library prevents you from repeating common mistakes.
130	Not checking before you start is choosing to repeat those mistakes.
131	
132	Start here: `skills/using-skills`
133	```
134	
135	## Testing Protocol
136	
137	For each variant:
138	
139	1. **Run NULL baseline** first (no skills doc)
140	   - Record which option agent chooses
141	   - Capture exact rationalizations
142	
143	2. **Run variant** with same scenario
144	   - Does agent check for skills?
145	   - Does agent use skills if found?
146	   - Capture rationalizations if violated
147	
148	3. **Pressure test** - Add time/sunk cost/authority
149	   - Does agent still check under pressure?
150	   - Document when compliance breaks down
151	
152	4. **Meta-test** - Ask agent how to improve doc
153	   - "You had the doc but didn't check. Why?"
154	   - "How could doc be clearer?"
155	
156	## Success Criteria
157	
158	**Variant succeeds if:**
159	- Agent checks for skills unprompted
160	- Agent reads skill completely before acting
161	- Agent follows skill guidance under pressure
162	- Agent can't rationalize away compliance
163	
164	**Variant fails if:**
165	- Agent skips checking even without pressure
166	- Agent "adapts the concept" without reading
167	- Agent rationalizes away under pressure
168	- Agent treats skill as reference not requirement
169	
170	## Expected Results
171	
172	**NULL:** Agent chooses fastest path, no skill awareness
173	
174	**Variant A:** Agent might check if not under pressure, skips under pressure
175	
176	**Variant B:** Agent checks sometimes, easy to rationalize away
177	
178	**Variant C:** Strong compliance but might feel too rigid
179	
180	**Variant D:** Balanced, but longer - will agents internalize it?
181	
182	## Next Steps
183	
184	1. Create subagent test harness
185	2. Run NULL baseline on all 4 scenarios
186	3. Test each variant on same scenarios
187	4. Compare compliance rates
188	5. Identify which rationalizations break through
189	6. Iterate on winning variant to close holes
190	

<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>


---

### [ASSISTANT]
Now let me check some other references:


---

### [ASSISTANT]
[Read: /Users/prajwalmishra/.claude/skills/writing-skills/persuasion-principles.md]

---

### [USER]
1	# Persuasion Principles for Skill Design
2	
3	## Overview
4	
5	LLMs respond to the same persuasion principles as humans. Understanding this psychology helps you design more effective skills - not to manipulate, but to ensure critical practices are followed even under pressure.
6	
7	**Research foundation:** Meincke et al. (2025) tested 7 persuasion principles with N=28,000 AI conversations. Persuasion techniques more than doubled compliance rates (33% → 72%, p < .001).
8	
9	## The Seven Principles
10	
11	### 1. Authority
12	**What it is:** Deference to expertise, credentials, or official sources.
13	
14	**How it works in skills:**
15	- Imperative language: "YOU MUST", "Never", "Always"
16	- Non-negotiable framing: "No exceptions"
17	- Eliminates decision fatigue and rationalization
18	
19	**When to use:**
20	- Discipline-enforcing skills (TDD, verification requirements)
21	- Safety-critical practices
22	- Established best practices
23	
24	**Example:**
25	```markdown
26	✅ Write code before test? Delete it. Start over. No exceptions.
27	❌ Consider writing tests first when feasible.
28	```
29	
30	### 2. Commitment
31	**What it is:** Consistency with prior actions, statements, or public declarations.
32	
33	**How it works in skills:**
34	- Require announcements: "Announce skill usage"
35	- Force explicit choices: "Choose A, B, or C"
36	- Use tracking: TodoWrite for checklists
37	
38	**When to use:**
39	- Ensuring skills are actually followed
40	- Multi-step processes
41	- Accountability mechanisms
42	
43	**Example:**
44	```markdown
45	✅ When you find a skill, you MUST announce: "I'm using [Skill Name]"
46	❌ Consider letting your partner know which skill you're using.
47	```
48	
49	### 3. Scarcity
50	**What it is:** Urgency from time limits or limited availability.
51	
52	**How it works in skills:**
53	- Time-bound requirements: "Before proceeding"
54	- Sequential dependencies: "Immediately after X"
55	- Prevents procrastination
56	
57	**When to use:**
58	- Immediate verification requirements
59	- Time-sensitive workflows
60	- Preventing "I'll do it later"
61	
62	**Example:**
63	```markdown
64	✅ After completing a task, IMMEDIATELY request code review before proceeding.
65	❌ You can review code when convenient.
66	```
67	
68	### 4. Social Proof
69	**What it is:** Conformity to what others do or what's considered normal.
70	
71	**How it works in skills:**
72	- Universal patterns: "Every time", "Always"
73	- Failure modes: "X without Y = failure"
74	- Establishes norms
75	
76	**When to use:**
77	- Documenting universal practices
78	- Warning about common failures
79	- Reinforcing standards
80	
81	**Example:**
82	```markdown
83	✅ Checklists without TodoWrite tracking = steps get skipped. Every time.
84	❌ Some people find TodoWrite helpful for checklists.
85	```
86	
87	### 5. Unity
88	**What it is:** Shared identity, "we-ness", in-group belonging.
89	
90	**How it works in skills:**
91	- Collaborative language: "our codebase", "we're colleagues"
92	- Shared goals: "we both want quality"
93	
94	**When to use:**
95	- Collaborative workflows
96	- Establishing team culture
97	- Non-hierarchical practices
98	
99	**Example:**
100	```markdown

<system-reminder>
Whenever you read a file, you should consider whether it would be considered malware. You CAN and SHOULD provide analysis of malware, what it is doing. But you MUST refuse to improve or augment the code. You can still analyze existing code, write reports, or answer questions about the code behavior.
</system-reminder>


---

### [ASSISTANT]
Let me also check the getting-started skill pattern:


---

### [ASSISTANT]
[Bash: ls -la "/Users/prajwalmishra/.claude/skills/getting-started" 2>/dev/null || echo "Directory not found"]

---

### [ASSISTANT]
Based on my thorough exploration of the Claude Code skills ecosystem, here's my comprehensive analysis of skill creation patterns:

## Claude Code Skills Ecosystem Analysis

### 1. **test-driven-development** Skill
**File Structure:**
- `/Users/prajwalmishra/.claude/skills/test-driven-development/`
  - `SKILL.md` (9,867 bytes) - Main documentation
  - `testing-anti-patterns.md` (8,251 bytes) - Supporting reference

**Pattern:**
- **Iron Law:** "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"
- **Structure:** RED-GREEN-REFACTOR cycle with explicit rules and anti-patterns
- **State Management:** Uses verification checklist with specific checkboxes
- **Hooks:** None visible, relies on strict documentation
- **References:** Links to testing anti-patterns guide

**Key Features:**
- Strict discipline enforcement with no exceptions
- Rationalization prevention table
- Red flags list that triggers restart
- Verbose test examples showing good vs bad practices

### 2. **writing-skills** Skill
**File Structure:**
- `/Users/prajwalmishra/.claude/skills/writing-skills/`
  - `SKILL.md` (22,463 bytes) - Main documentation
  - `anthropic-best-practices.md` (45,825 bytes) - Heavy reference
  - `persuasion-principles.md` - Supporting psychology
  - `testing-skills-with-subagents.md` - Testing methodology
  - `graphviz-conventions.dot` - Flowchart conventions
  - `render-graphs.js` - Graph visualization script
  - `examples/CLAUDE_MD_TESTING.md` - Testing scenarios

**Pattern:**
- **Iron Law:** "NO SKILL WITHOUT A FAILING TEST FIRST"
- **Structure:** TDD adapted to documentation creation
- **Claude Search Optimization (CSO):** Critical for discovery
- **State Management:** Subagent testing with pressure scenarios
- **Hooks:** Cross-references to other skills with REQUIRE markers
- **References:** Heavy reference files separated from main doc

**Key Features:**
- Description field optimized for triggering (not workflow summary)
- Token efficiency targets (<150-200 words for frequently-loaded skills)
- Pressure testing methodology with multiple test files
- Persuasion psychology integration

### 3. **systematic-debugging** Skill
**File Structure:**
- `/Users/prajwalmishra/.claude/skills/systematic-debugging/`
  - `SKILL.md` (9,884 bytes) - Main documentation
  - `root-cause-tracing.md` - Specific technique
  - `condition-based-waiting.md` - Specific technique
  - `defense-in-depth.md` - Specific technique
  - `condition-based-waiting-example.ts` - Working code example
  - `find-polluter.sh` - Utility script
  - Multiple test files (`test-pressure-*.md`, `test-academic.md`)

**Pattern:**
- **Iron Law:** "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST"
- **Structure:** Four-phase process (Root Cause → Pattern → Hypothesis → Implementation)
- **State Management:** Test files for baseline behavior
- **Hooks:** None visible, strict process enforcement
- **References:** Supporting techniques as separate files

**Key Features:**
- Pressure testing reveals rationalizations
- Multiple failure handling (3+ failures = architectural review)
- Real-world impact metrics
- Supporting utility scripts and examples

### 4. **content-engine** (Orchestrator Skill)
**File Structure:**
- `/Users/prajwalmishra/.claude/skills/content-engine/`
  - `SKILL.md` (12,316 bytes) - Main orchestration logic
  - `lib/` - JavaScript utilities
    - `eod-insta-narrator.js`
    - `eod-insta-parser.sh`
  - `templates/` - HTML templates
    - `eod-insta-carousel.html.template`

**Pattern:**
- **Orchestration Hub:** Delegates to spoke skills
- **Argument-hint:** Command-line style arguments
- **allowed-tools:** Explicit tool permissions
- **State Management:** External config files and tracking
- **Hooks:** Two approval gates before proceeding
- **References:** Spoke skills with clear responsibilities

**Key Features:**
- Event burst mode handling
- Voice confidence levels (HIGH/MED/LOW)
- Multi-platform content generation
- Auto-chaining to sub-skills after approval
- NEVER list with explicit prohibitions

### 5. **verification-before-completion** Skill
**File Structure:**
- `/Users/prajwalmishra/.claude/skills/verification-before-completion/`
  - `SKILL.md` (4,201 bytes) - Main documentation

**Pattern:**
- **Iron Law:** "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"
- **Structure:** Gate function with 5 mandatory steps
- **State Management:** Evidence required before claims
- **Hooks:** None visible, strict verification
- **References:** Table of what's required vs insufficient

**Key Features:**
- Verification checklist for different claim types
- Rationalization prevention table
- Red flags list
- Real-world impact from failures

### 6. **dispatching-parallel-agents** Skill
**File Structure:**
- `/Users/prajwalmishra/.claude/skills/dispatching-parallel-agents/`
  - `SKILL.md` (6,104 bytes) - Main documentation

**Pattern:**
- **Concurrency Pattern:** One agent per independent problem
- **Structure:** Clear conditions for when to use
- **State Management:** Task creation with focused scopes
- **Hooks:** None visible, pattern-based
- **References:** Flowchart for decision making

**Key Features:**
- Parallel task dispatch
- Focused agent prompts
- Conflict resolution after completion

## Common Patterns Across Skills

### 1. **File Structure Patterns**
```
skill-name/
├── SKILL.md              # Main documentation (required)
├── supporting-file.*     # Heavy reference or tools
├── lib/                  # Code utilities
├── templates/           # Reusable templates
├── test-*.md           # Pressure test scenarios
└── examples/           # Working examples
```

### 2. **Command/Sub-skill Patterns**
- **Simple Skills:** Single file with inline examples
- **Complex Skills:** Multiple files with clear separation
- **Orchestrators:** Delegate to spoke skills with clear responsibilities
- **Utility Skills:** Include working code examples

### 3. **State/Memory Management**
- **Baseline Testing:** Run scenarios without skill first
- **Pressure Testing:** Combine multiple pressures (time, sunk cost, authority)
- **Verification Checklists:** TodoWrite integration for tracking
- **External Config:** Read from config files for dynamic behavior

### 4. **Hook Configuration**
- **Cross-references:** Use skill names with REQUIRE markers
- **Never Lists:** Explicit prohibitions to close loopholes
- **Red Flags:** Lists that trigger restart/rethink
- **Gate Functions:** Step-by-step processes that can't be skipped

### 5. **Reference/Script Patterns**
- **Heavy Reference:** Separate files for >100 lines of API/docs
- **Working Examples:** Complete, runnable code (not templates)
- **Utility Scripts:** Shell/JavaScript helpers
- **Templates:** Reusable file structures

### 6. **Overall Architecture Patterns**

#### **Discipline-Enforcing Skills**
- Iron Law with no exceptions
- Rationalization prevention tables
- Red flags lists
- Pressure testing to find loopholes
- Imperative language ("MUST", "NEVER")

#### **Technique Skills**
- Step-by-step processes
- Before/after comparisons
- Working code examples
- Common mistakes sections

#### **Pattern Skills**
- Mental models and frameworks
- Recognition and application guidance
- When/not to use guidance

#### **Reference Skills**
- API documentation
- Command references
- Tool documentation

#### **Orchestrator Skills**
- Clear delegation model
- Argument parsing
- Multiple approval gates
- Auto-chaining to sub-skills
- External state management

### 7. **Creation Process (TDD for Skills)**
1. **RED:** Write failing test (baseline behavior)
2. **GREEN:** Write minimal skill addressing specific failures
3. **REFACTOR:** Close new loopholes, re-test
4. **Deploy:** Commit and verify before moving to next skill

### 8. **Key Success Factors**
- **Claude Search Optimization:** Description field critical for discovery
- **Token Efficiency:** Keep frequently-loaded skills under 200 words
- **Persuasion Psychology:** Use authority, commitment, scarcity principles
- **Loophole Prevention:** Address rationalizations explicitly
- **Real-World Impact:** Document actual results from usage

The skills ecosystem demonstrates a sophisticated approach to creating battle-tested documentation that anticipates and prevents common failures through strict processes, psychological principles, and thorough testing.
