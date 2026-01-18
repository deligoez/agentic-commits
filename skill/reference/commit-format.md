# Commit Format

## Structure

```
type(Scope): what (why) → next
```

## Elements

| Element | Purpose | Required |
|---------|---------|----------|
| **type** | Categorize: feat, fix, wip, refactor, test, docs, chore | Always |
| **Scope** | Locate: file name or component | Always |
| **what** | Describe: imperative action | Always |
| **(why)** | Explain: motivation — enables Review | Always |
| **→ next** | Continue: tasks — enables Resume | WIP only |

## Types

| Type | Use |
|------|-----|
| `feat` | Completed feature |
| `fix` | Bug fix |
| `wip` | Work in progress (NEXT required) |
| `refactor` | Restructure without behavior change |
| `test` | Tests |
| `docs` | Documentation |
| `chore` | Config, dependencies |

## Scope

File name for fast `git log` scanning.

| Situation | Scope |
|-----------|-------|
| Single file | `FileName` |
| Multiple same-name files | `Dir/FileName` |
| Multiple files, one primary | Primary file |
| Component spanning files | Component name |

## WHY — Enables Review

**Required.** Motivation, not implementation.

✅ `(users crashed on empty forms)`
❌ `(added null check)`

## NEXT — Enables Resume

**Required for WIP.** Specific next steps.

✅ `→ token blacklist, rate limiting`
❌ `→ continue work`

**WIP Decision Rule**: Only use `wip` if you can write specific `→ next` tasks. If you don't know what's next, use `feat` instead.

**Commit Finality**: Commits are final. Never amend past commits to add `→ next`. If resuming work, create new commits.

## Examples

### Completed Feature
```
feat(SessionManager): add refresh capability (seamless re-auth)
```

### Work in Progress
```
wip(AuthController): add logout endpoint (security) → token blacklist, rate limiting
```

### Bug Fix
```
fix(LoginForm): handle empty email submission (app crashed)
```

### Refactor
```
refactor(UserService): extract validation utils (code dedup)
```
