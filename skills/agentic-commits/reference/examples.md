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

### How to Split (hash-object technique)

The working tree has both changes. AI generates an intermediate file with ONLY the fix:

```bash
AGENTIC_TMP=$(mktemp -d /tmp/agentic-XXXXXX)

# Step 1: Write file with only the fix applied (no refreshSession yet)
cat > "$AGENTIC_TMP/intermediate.ts" << 'EOF'
// ... original file content ...
function createSession() {
  if (!user.id) throw new Error();  // ← fix included
  // ...
}

function validateSession() {
  // ...                             // ← NO refreshSession here
}
EOF

# Step 2: Stage intermediate state via plumbing (working tree untouched)
BLOB=$(git hash-object -w "$AGENTIC_TMP/intermediate.ts")
git update-index --cacheinfo 100644,"$BLOB",SessionManager.ts
git commit -m "fix(SessionManager): validate user ID (silent auth failures)"
rm -rf "$AGENTIC_TMP"

# Step 3: Stage remaining changes (the feature) from working tree
git add SessionManager.ts
git commit -m "feat(SessionManager): add refresh capability (seamless re-auth)"
```

**Key insight:** The AI generates the intermediate file content — this is natural for LLMs.
The working tree is never modified, so there's no risk of data loss.

---

## Exception: True Compile-Time Dependency → One Commit

**Changes:**
- `utils/format.ts` — new function (would be dead code alone)
- `UserController.ts` — calls the new function

**Commit:**

```
feat(UserController): display formatted balance (better UX)
```

Note: New function + its direct caller are the ONLY valid multi-file commit.
This is the exception to "One File Per Commit." Most "related" changes do NOT qualify.

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

## Test Granularity

### ✅ Good: Same purpose → one commit
```
# All tests cover the same behavior (hunk re-indexing edge cases)
test(git-commit-plan-hunks): add re-indexing and non-contiguous split tests (hunk-shift coverage)
```

### ✅ Good: Different purposes → separate commits
```
# Same test file, but tests cover different behaviors
test(SessionManager.test): add token expiry tests (expiry coverage)
test(SessionManager.test): add refresh error tests (error path coverage)
```

### ❌ Bad: One commit per test when all serve the same purpose
```
# Unnecessary noise — all 7 tests exist for hunk-shift coverage
test(git-commit-plan-hunks): add re-indexing test 1 (hunk-shift coverage)
test(git-commit-plan-hunks): add re-indexing test 2 (hunk-shift coverage)
```

**Rule**: Group tests by purpose, not by count. Ask: "Do these tests exist for the same reason?" If yes → one commit.

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
