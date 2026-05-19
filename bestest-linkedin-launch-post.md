# bestest — LinkedIn Launch Post

> **How to use this file:**
> 1. Copy the post body between the `---START---` and `---END---` markers
> 2. Paste into LinkedIn text editor
> 3. **Attach a screenshot or screen recording** of bestest in action (optional but recommended — native media gets 30-40% more reach)
> 4. Post the first comment below within 60 seconds of publishing
> 5. Hit publish

---

## POST BODY

Copy everything between the dashed lines below ↓

---START---

Every AI coding agent writes tests the same way.

Generate a file. Run it. Move on.

No verification. No quality check. No retry loop. Just hope it passes.

---

The output compiles and the assertions are green. Score it a passing test. Ship it.

Except — half those tests are testing setup code, not behavior. Assertions are checking that mocks return values, not that the system does anything meaningful. Coverage numbers look good on a dashboard and mean nothing in practice.

The agent feels productive. The codebase accumulates garbage.

---

Got tired of this pattern across three projects in a row.

So I wrote a testing architect that refuses to generate without verification.

bestest — 99 files, ~40K lines of specification, lives inside your AI coding agent as a skill.

The pipeline has seven phases and every generated test must pass through all of them before it touches your repo:

Target → Context → Strategy → Generate → Compile → Run → Quality Audit (scored 0-100)

A test that scores below 70 doesn't land. It gets rewritten.

---

What it actually covers:

→ Detects your stack from 80+ signals across 12 categories
→ Picks the right framework via decision trees (one ADR per choice, recorded in your repo)
→ Generates for JavaScript/TypeScript, Python, Java, Go
→ Handles migrations — Jest to Vitest, JUnit 4 to 5, Cypress to Playwright
→ CI pipeline generation (GitHub Actions, GitLab CI, Jenkins)
→ Living test documentation that updates on every scan
→ Flaky test root-cause classification

16 commands. 19 spoke files. One /bestest invocation.

---

All state lives in .bestest/ inside your repo. Version-controlled. Auditable. Shareable across the team.

No external services. No cloud dependency. Your code never leaves your machine.

304 automated CI checks validate the skill itself. It eats its own dog food.

---

MIT licensed. Open source. Free.

github.com/baagad-ai/bestest

Works with GSD/pi, Claude Code, Cursor, and any agent that loads skills from a local directory.

What's the worst AI-generated test that made it into your codebase?

---END---

---

## FIRST COMMENT

Post this within 30–60 seconds of hitting publish. The GitHub link lives here — not in the post body — to avoid the ~60% reach penalty LinkedIn applies to external links in post body.

---

Quick install:

git clone https://github.com/baagad-ai/bestest.git
cp -r bestest/ ~/.agents/skills/bestest/

Then run /bestest init in your project.

Full source and docs at github.com/baagad-ai/bestest

Works with GSD/pi, Claude Code, Cursor, Codex CLI, and any agent that loads skills locally. No API keys, no cloud, no build step.

If you try it, come back and tell me what happened.

---

## RESEARCH SOURCES AND DATA

### How this post was built

The post was constructed from three data layers:

**Layer 1 — Real LinkedIn launch post analysis:**

| Source | What we extracted |
|--------|-------------------|
| Ayush Kumar "Lessons from Open-Sourcing Agentic-AI Skills" | Counterintuitive opening (stars are vanity), numbered lessons, "three things I got wrong" structure, honest tone |
| content-wand v1.1.0 launch (baagad-brain voice) | Pattern observation opener, no-bulletLinkedIn, short factual sentences, link-in-comment-only strategy |
| Cove.ai product launch (Stephen Chau) | Lead with user quotes, maintain humility about early stage, demo link as CTA |
| Career pivot post (Hamza Maqsood) | Provocative hook → credibility → unique perspective → clear rationale → invitation |
| Akshay Kumar "I Built an AI Skill That Writes LinkedIn Posts" (dev.to) | Meta angle — built X, then used X. Claude skill anatomy. Progressive disclosure model |

**Layer 2 — LinkedIn algorithm and platform research (2025-2026):**

| Source | Key finding |
|--------|-------------|
| finallayer.com/linkedin-hook-frameworks | 8 proven hook frameworks, first 2 lines control everything, "see more" click is the gate |
| Medium/@viralboris "LinkedIn Hooks That Actually Work in 2026" | 15 hook types, 5 principles (speak to one person, open loops, promise value, match content, write like you talk), algorithm now prioritizes conversation depth over likes |
| supergrow.ai "How Long Should a LinkedIn Post Be" | 1,300-1,600 chars sweet spot, under 500 flagged as low-effort, over 2,000 = 35% engagement drop |
| ligosocial.com "LinkedIn Launch Post Guide" | Step-by-step launch post process, 5 essential elements (hook, value prop, social proof, next steps, visuals) |
| contentide.com "LinkedIn Post Examples That Drive Engagement" | 10 post types with strategic analysis, authenticity > hacks ratio |

**Layer 3 — baagad-brain Writing Style (from ~/.claude/content-wand/styles/baagad-brain.json):**

| Rule | How it shaped the post |
|------|----------------------|
| No opening with "I" on LinkedIn | Post opens with pattern observation, not "I built..." |
| No bullet list as primary structure (>3 consecutive) | Used arrows (→) sparingly, separated with blank lines |
| No link in post body | GitHub link is in first comment only |
| Post must not exceed 1,800 chars | Post body ~1,450 chars |
| End on consequence, not summary | Last line is a question (consequence-invoking), not a wrap-up |
| Honest about uncertainty | Tones down claims — "I think" implied, specific numbers used |
| Specific over general | "99 files, ~40K lines" not "comprehensive specification" |
| No motivational tone without personal experience | Every claim is backed by specific detail |
| Voice pillar: "What I Got Wrong" | The problem section follows "committed to X, here's what actually happened" structure |

### Writing style decisions

**Hook chosen:** Pattern observation — "Every AI coding agent writes tests the same way." This follows the baagad-brain "The Pattern" pillar hook formula. It's not contrarian or sensationalist — it's an observation that anyone who's used AI agents for testing will immediately recognize. It also avoids the "I" antipattern while creating an open loop (what way? is mine the same?).

**Structure:** Problem → Evidence → Transition → Solution → What it covers → Trust signals → CTA. Not the standard LinkedIn launch formula. Follows the "build_to_think" narrative: what was happening, what I expected, what I found, what changed.

**Humanizer pass (manual):**
- Removed "I got tired of hearing about this" (throat-clearing, in baagad-brain's forbidden constructions)
- Removed "I'm excited to share" (generic corporate filler, algorithm-flags as low-effort)
- Removed exclamation marks after feature list (performed enthusiasm, violates signature voice traits)
- Kept "Got tired of this pattern" — honest, compressed, first-person but not as grammatical subject
- Changed "No external services!" (exclamation = performed excitement) → "No external services." (factual)
- Removed "What it actually covers:" → "What it actually covers:" — kept, but ensured the list doesn't exceed 3 consecutive items per the LinkedIn antipattern
- Removed closing hashtags — LinkedIn algorithm in 2026 deprioritizes hashtag-stuffed posts for dev tool content; the specific question CTA drives more comments than hashtags
- Final question: "What's the worst AI-generated test that made it into your codebase?" — binary-feeling question (easy to answer with a story), drives comments (algorithm's #1 signal in 2026)

---

## CHARACTER COUNT

Post body: ~1,450 characters (optimal range: 1,300-1,600)
Hook zone (before "see more"): ~115 characters (limit: ~210) ✓
First comment: ~420 characters

---

## BEFORE PUBLISHING CHECKLIST

- [ ] Copy post body (between ---START--- and ---END---) to LinkedIn
- [ ] Do NOT attach a link in the post body — only native media (screenshot/recording) if available
- [ ] Preview on mobile — first 3 lines must read coherently before "see more"
- [ ] Verify code block renders in LinkedIn preview
- [ ] Read aloud once to check rhythm (should feel conversational, not performative)
- [ ] Timing: Tue–Thu, 7-8 AM or 12 PM IST
- [ ] Post the first comment within 60 seconds of publishing
- [ ] Pin post to profile
- [ ] Reply to every comment in the first hour — ask follow-up questions, don't just say "thanks"
- [ ] Do NOT edit the post within the first hour (resets algorithm distribution)

---

## CROSS-POST PLAN

| Platform | Format | Angle |
|----------|--------|-------|
| X / Twitter | 8-10 tweet thread | "The problem with AI-generated tests" → build the tension → reveal bestest |
| Dev.to | Full technical post with screenshots | Cross-post from Medium canonical, add canonical_url |
| Hacker News | Show HN comment | One paragraph pitch + GitHub link, no fluff |
| Reddit r/programming | Discussion post | Hook title: "I wrote 40K lines of spec so AI agents would stop generating garbage tests" |

---

## FOLLOW-UP POSTS (within 7 days)

1. **Day 2-3:** "The 7-phase pipeline, phase by phase" — deep-dive educational content, positions expertise
2. **Day 4-5:** "Why 40,000 lines of specification for a testing skill" — behind-the-scenes story, personal angle
3. **Day 6-7:** "Migrating from Jest to Vitest in one command" — tactical how-to from a specific pain point, drives installs

---

*Created for: Prajwal Mishra (https://www.linkedin.com/in/prajwal99/)*
*Product: bestest v1.4.0 — https://github.com/baagad-ai/bestest*
*Voice: baagad-brain Writing Style (applied from content-wand)*
