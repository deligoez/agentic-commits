# Agentic Commits

Commit format that AI agents can read, understand, and act on.

## The Format

```
type(Scope): what (why) → next
```

### Elements

| Element | Purpose | Required |
|---------|---------|----------|
| **type** | Categorize: feat, fix, wip, refactor, test, docs, chore | Always |
| **Scope** | Locate: file name or component | Always |
| **what** | Describe: imperative action | Always |
| **(why)** | Explain: motivation — enables Review | Always |
| **→ next** | Continue: tasks — enables Resume | WIP only |

### Types

| Type | Use | Requires NEXT? |
|------|-----|----------------|
| `feat` | Completed feature | No |
| `fix` | Bug fix | No |
| `wip` | Work in progress | **Yes** |
| `refactor` | Code restructure | No |
| `test` | Tests | No |
| `docs` | Documentation | No |
| `chore` | Config, dependencies | No |

## Examples

```bash
# Completed feature
feat(AuthService): add JWT validation (token expiry protection)

# Work in progress - NEXT is critical
wip(AuthController): add logout endpoint (security) → token blacklist, rate limiting

# Bug fix
fix(SessionManager): validate user ID (silent auth failures)

# Refactor
refactor(UserService): extract validation utils (code dedup)
```

## Atomic Commits

Split changes into atomic, single-purpose commits:

1. **One logical change per commit** — Don't mix unrelated changes
2. **Hunk-level splitting** — Same file can have multiple commits if changes are independent
3. **One file per commit (default)** — Different files should be separate commits unless directly dependent
4. **Commit order** — fixes → refactors → features

### ❌ Bad: Combining files
```bash
fix(AuthService,UserController): add validation (prevent errors)
```

### ✅ Good: Separate commits
```bash
fix(AuthService): add validation (prevent empty credentials)
fix(UserController): add validation (prevent invalid IDs)
```

### Same File, Multiple Concerns

```diff
# File has two unrelated changes:
@@ -12,6 +12,9 @@ createSession()
+  if (!user.id) throw new Error();     ← This is a fix

@@ -45,6 +48,8 @@ validateSession()
+export function refreshSession() {      ← This is a feature
+}
```

**Create two commits:**
```bash
fix(SessionManager): validate user ID (silent auth failures)
feat(SessionManager): add refresh capability (seamless re-auth)
```

## Agent Capabilities

### Resume
Agent reads `→ next` from recent commits to continue work after context loss.

```bash
$ git log -1 --format="%s"
wip(AuthController): add logout (security) → token blacklist, rate limiting

# Agent knows: Next task is token blacklist and rate limiting
```

### Review
Agent reads `(why)` to understand past decisions.

```bash
$ git log --oneline --grep="JWT"
a1b2c3d feat(AuthService): add JWT validation (token expiry protection)

# Agent knows: JWT was added to handle token expiry
```

### Handoff
Agent reads history to summarize for another agent.

```bash
$ git log --oneline -5
# Agent extracts: what's done, what's in progress, what's next
```

## Workflow

### Step 1: Gather
```bash
git status --short
git diff
git diff --staged
```

### Step 2: Group Changes
- Parse hunks (`@@ ... @@` blocks)
- Group related changes together
- Separate unrelated changes

### Step 3: Commit Each Group
```bash
git add -p  # or use patch files for precise control
git commit -m "type(Scope): what (why) [→ next]"
```

### Step 4: Verify
```bash
git log --oneline -5
git status --short
```

## Key Rules

1. **Always include WHY** — Motivation enables Review
2. **Always include NEXT for WIP** — Continuation enables Resume
3. **Always include Scope** — File name enables fast scanning
4. **One purpose per commit** — Atomic commits enable clean history
5. **Be specific** — "security" not "improvements"

## WIP Decision Rule

**Only use `wip` if you can write specific `→ next` tasks.**

| Situation | Type |
|-----------|------|
| Work complete | `feat` / `fix` / `refactor` |
| Work incomplete, know what's next | `wip` with `→ next` |
| Work incomplete, don't know what's next | `feat` (effectively done) |

❌ `wip(X): add logout → continue later` — Vague
✅ `wip(X): add logout (security) → token blacklist, rate limiting` — Specific

**Never guess `→ next`.** If you don't have implementation context, use `feat`. Guessed `→ next` is worse than none.

## Commit Finality

**Commits are final. Never amend past commits to add `→ next`.**

- `→ next` must be known at commit time
- Never amend pushed commits (avoids force push)
- Resuming work = new commits (don't modify history)

## Completion Signals

| Last commit | Status | Agent action |
|-------------|--------|--------------|
| `feat` / `fix` / `refactor` | Complete | Ask for new work |
| `wip` with `→ next` | Incomplete | Continue with → next |
| `wip` without `→ next` | ❌ Invalid | Should never happen |
