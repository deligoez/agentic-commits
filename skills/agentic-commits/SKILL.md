---
name: agentic-commits
description: |
  Commit format that AI agents can act on. Splits changes into atomic hunks, commits with structured format enabling Resume, Review, and Handoff. Never pushes.
allowed-tools:
  - Bash(git:*)
  - Bash(rm:*)
  - Read
  - Write
---

# Agentic Commits

Commit format that AI agents can read, understand, and act on.

| Mode | Triggers | Action |
|------|----------|--------|
| COMMIT | "commit", "commit changes" | Split hunks → atomic commits |
| CONTEXT | "where did I leave off", "resume", "review", "handoff" | Recover state from history |

**Purpose:** Enable agents to:
- **Resume** — Continue after context loss
- **Review** — Understand past decisions
- **Handoff** — Transfer work to another agent

Execute autonomously. Never push.

---

# The Format

```
type(Scope): what (why) → next
```

| Element | Purpose | Required |
|---------|---------|----------|
| **type** | Categorize: feat, fix, wip, refactor, test, docs, chore | Always |
| **Scope** | Locate: file name or component | Always |
| **what** | Describe: imperative action | Always |
| **(why)** | Explain: motivation — enables Review | Always |
| **→ next** | Continue: tasks — enables Resume | WIP only |

## Examples

```bash
feat(AuthService): add JWT validation (token expiry protection)
wip(AuthController): add logout (security) → token blacklist, rate limiting
fix(SessionManager): validate user ID (silent auth failures)
refactor(UserService): extract validation utils (code dedup)
```

---

# Critical Rules

## WIP Decision Rule

**Only use `wip` if you can write specific `→ next` tasks.**

| Situation | Type | Rationale |
|-----------|------|-----------|
| Work complete | `feat` / `fix` / `refactor` | Done = no → next needed |
| Work incomplete, know what's next | `wip` | → next enables Resume |
| Work incomplete, don't know what's next | `feat` | If you can't specify next, it's effectively done |

**Never guess `→ next`.** If you don't have implementation context (e.g., you're only committing code written by another agent), don't invent next steps. Use `feat` instead. Guessed `→ next` is worse than no `→ next`.

❌ **Bad**: Vague next
```bash
wip(AuthController): add logout → continue later
```

✅ **Good**: Specific next
```bash
wip(AuthController): add logout (security) → token blacklist, rate limiting
```

**Rule**: Vague "→ next" = not WIP. Use `feat` instead.

## Commit Finality

**Commits are final. Never amend past commits to add `→ next`.**

| Rule | Rationale |
|------|-----------|
| `→ next` must be known at commit time | If you don't know, use `feat` not `wip` |
| Never amend pushed commits | Avoids force push problems |
| Resuming work = new commits | Don't modify history, create new commits |

If the previous session ended with `feat` and you're continuing work, just create new commits. Don't try to add `→ next` to old commits.

## Type Separation Rule

**Different purposes = Different commits. Always.**

Even with the SAME type, different problems = different commits:

| If you have... | Then create... |
|----------------|----------------|
| 1 fix + 1 feat | 2 commits (different types) |
| 2 fixes (different bugs) | 2 commits (same type, different problems) |
| 1 refactor + 1 fix | 2 commits (different types) |
| 3 features (different features) | 3 commits (same type, different purposes) |

**The rule is about PURPOSE, not just TYPE.**

### ❌ Bad: Mixing types
```bash
fix(Config): fix typo and add new option (cleanup + feature)
```

### ❌ Bad: Same type, different problems
```bash
fix(Config): fix typo and handle null case (two unrelated fixes)
```

### ✅ Good: Separate by purpose
```bash
fix(Config): fix typo in timeout key (silent failures)
fix(Config): handle null config gracefully (crash prevention)
feat(Config): add retry option (resilience)
```

**Rule**: One commit = One purpose. Type is secondary.

---

## Completion Signals

How agents determine work status from last commit:

| Last commit type | Status | Agent action |
|------------------|--------|--------------|
| `feat` | Complete | Ask for new work |
| `fix` | Complete | Ask for new work |
| `refactor` | Complete | Ask for new work |
| `wip` with `→ next` | Incomplete | Continue with → next tasks |
| `wip` without `→ next` | ❌ Invalid | Should never happen |

## Session Lifecycle

### Starting a Session
1. Run MODE 2: CONTEXT to understand current state
2. Look for `wip` commits with `→ next`
3. If found → those are your next tasks
4. If not found → ask user what to work on

### During a Session
1. Work on tasks
2. Create atomic commits with MODE 1
3. Use `wip` + `→ next` if work incomplete AND you know next steps
4. Use `feat`/`fix`/`refactor` if work is complete

### Ending a Session
- Work complete → last commit is `feat`/`fix`/`refactor` (no → next)
- Work incomplete → last commit is `wip` with specific `→ next`
- **Never leave ambiguity** — commit history tells next agent exactly what to do

---

# MODE 1: COMMIT

## 1. Gather Changes

```bash
git status --short && git diff && git diff --staged
```

No changes → stop.

## 2. Parse & Group Hunks

Parse `git diff` output. Hunk = `@@ ... @@` block.

**Group by purpose:**
- `feat` — new functionality
- `fix` — bug fix
- `refactor` — restructure without behavior change
- `test` / `docs` / `chore`

**Grouping rules:**
- Related hunks → same group (dependency, semantic unity)
- Unrelated hunks in same file → separate groups
- Feature + its tests → same group

## 3. Commit Each Group

Order: fixes → refactors → features

```bash
# Option A: Interactive staging
git add -p
git commit -m "type(Scope): what (why)"

# Option B: Patch files for precise control
# Write patch to /tmp/agentic-<n>.patch
git apply --cached /tmp/agentic-<n>.patch
git commit -m "type(Scope): what (why)"
rm /tmp/agentic-<n>.patch
```

## 4. Verify

```bash
git log --oneline -<N>
git status --short
```

Remaining changes → continue grouping or `git add -A && git commit -m "chore(Misc): remaining changes (cleanup)"`

---

# MODE 2: CONTEXT

Recover state for Resume, Review, or Handoff.

## 1. Detect Base

```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
```

Fallback: `main`

## 2. Gather History

```bash
git log --oneline <base>..HEAD
git log <base>..HEAD --format="%h %s" | head -20
git status --short
```

## 3. Analyze & Report

**For Resume:**
- Find `wip` commits
- Extract `→ next` tasks
- Report what to do next

**For Review:**
- Extract `(why)` from commits
- Explain past decisions

**For Handoff:**
- List completed work (`feat`, `fix`)
- List in-progress work (`wip`)
- Summarize next steps

---

# Atomic Commits

## Why Atomic?

Each commit should have one logical purpose:
- Easier to review
- Easier to revert
- Enables `git bisect`
- Cleaner history for agents to parse

## Same File, Multiple Concerns

```diff
@@ -12,6 +12,9 @@ createSession()
+  if (!user.id) throw new Error();     ← fix

@@ -45,6 +48,8 @@ validateSession()
+export function refreshSession() {      ← feat
+}
```

**Split into two commits:**
```bash
fix(SessionManager): validate user ID (silent auth failures)
feat(SessionManager): add refresh capability (seamless re-auth)
```

## Commit Order

1. **Fixes** — Often cherry-picked
2. **Refactors** — Foundation for features
3. **Features** — New functionality
4. **Chore/Docs** — Non-functional

---

# Hunk Grouping

## Rules

| Rule | Question | If Yes |
|------|----------|--------|
| Dependency | Would this break without the other? | Same group |
| Semantic Unity | Same problem being solved? | Same group |
| Independence | Can stand alone? | Can be separate |

## Common Patterns

| Scenario | Grouping |
|----------|----------|
| Feature + its tests | Same |
| Rename + all usages | Same |
| Two unrelated fixes | **Separate** |
| Config + code using it | Same |
| Same fix type in different files | **Separate** |

## Critical Rule: One File Per Commit (Default)

Different files should be in **separate commits** unless there's a direct dependency.

❌ **Bad**: Combining validation fixes across files
```bash
fix(AuthService,UserController): add input validation (prevent errors)
```

✅ **Good**: Separate commits per file
```bash
fix(AuthService): add input validation (prevent empty credentials)
fix(UserController): add input validation (prevent invalid IDs)
```

**Exception**: Only combine files when one directly depends on the other (e.g., new function + its usage).

## Edge Case: Interleaved Changes

If hunks can't be separated (too close together):
- Commit together
- Explain both in (why)

```bash
refactor(AuthService): extract validation and add caching (dedup + perf)
```

---

# Quick Reference

| Command | Purpose |
|---------|---------|
| `git add -p` | Interactive hunk staging |
| `git apply --cached <patch>` | Apply patch to staging |
| `git apply --check <patch>` | Dry run |
| `git reset HEAD` | Unstage all |
| `git reset --soft HEAD~1` | Undo last commit |
| `git log --oneline -10` | Recent commits |

---

# Scope Guidelines

| Situation | Scope |
|-----------|-------|
| Single file | `FileName` |
| Multiple same-name files | `Dir/FileName` |
| Multiple files, one primary | Primary file |
| Multiple files, shared component | Component name |

Examples:
```bash
feat(AuthService): ...           # Single file
feat(Admin/UserController): ...  # Disambiguated
feat(AuthSystem): ...            # Component spanning files
```
