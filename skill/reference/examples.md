# Examples

## Same File, Two Concerns → Two Commits

**Diff:**
```diff
@@ -12,6 +12,9 @@ createSession()
+  if (!user.id) throw new Error();     ← fix

@@ -45,6 +48,8 @@ validateSession()
+export function refreshSession() {      ← feat
+}
```

**Commits:**

```
fix(SessionManager): validate user ID (silent auth failures)
```

```
feat(SessionManager): add refresh capability (seamless re-auth)
```

---

## Related Hunks Across Files → One Commit

**Changes:**
- `utils/format.ts` — new function
- `UserController.ts` — uses it

**Commit:**

```
feat(UserController): display formatted balance (better UX)
```

Note: Related utility added in same commit since they're semantically linked.

---

## Resume Example

Agent crashed mid-task. New session:

```bash
$ git log --oneline -3
a1b2c3d wip(AuthController): add logout (security) → token blacklist, rate limiting
d4e5f6g feat(SessionManager): add refresh capability (seamless re-auth)
8c7d6e5 fix(SessionManager): validate user ID (silent auth failures)
```

Agent reads `→ token blacklist, rate limiting` and knows what to do next.

---

## Review Example

Asked "why was refresh capability added?":

```bash
$ git log --oneline --grep="refresh"
d4e5f6g feat(SessionManager): add refresh capability (seamless re-auth)
```

Agent extracts `(seamless re-auth)` → explains the motivation.

---

## Handoff Example

New agent takes over:

```bash
$ git log --oneline -5
```

Agent extracts:
- **Done**: SessionManager validation, refresh capability
- **In Progress**: AuthController logout
- **Next**: token blacklist, rate limiting

---

## Atomic vs Non-Atomic

### ❌ Bad: Mixed concerns
```
fix: various auth improvements
```

### ✅ Good: Single purpose
```
fix(SessionManager): validate user ID (silent auth failures)
feat(SessionManager): add refresh capability (seamless re-auth)
```

---

## WIP with Clear Next Steps

### ❌ Bad: Vague next
```
wip(AuthController): add logout → continue later
```

### ✅ Good: Specific next
```
wip(AuthController): add logout (security) → token blacklist, rate limiting
```

---

## Session Continuation

### Previous session ended with `feat` (complete):
```bash
$ git log --oneline -1
d4e5f6g feat(SessionManager): add refresh capability (seamless re-auth)
```

New work = new commits. Don't amend the old commit.

### Previous session ended with `wip` (incomplete):
```bash
$ git log --oneline -1
a1b2c3d wip(AuthController): add logout (security) → token blacklist, rate limiting
```

Agent continues with `→ token blacklist, rate limiting` tasks.

**Rule**: Never amend past commits. If you didn't know what's next when you committed, it was effectively complete.

---

## Scope Usage

### Single file
```
feat(AuthService): add JWT validation (token expiry protection)
```

### Disambiguated path
```
feat(Admin/UserController): add bulk delete (admin needs)
feat(Mobile/UserController): add quick login (UX improvement)
```

### Component spanning files
```
feat(AuthSystem): implement OAuth flow (third-party login)
```
