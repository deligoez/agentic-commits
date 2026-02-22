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

## One File Per Commit (STRICT)

**Each file MUST be committed separately.** This is the most important rule.

- Even for the same issue/task, each file gets its own commit
- Grouping files as "same problem" or "related changes" is **NOT allowed**
- Only exception: New function + code that DIRECTLY calls it (true compile-time dependency)

See [Hunk Grouping](#one-file-per-commit-strict) for detailed examples.

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
git status --short
git diff --no-ext-diff
git diff --no-ext-diff --staged
```

**Note**: `--no-ext-diff` ensures standard unified diff format, bypassing custom diff tools (diff-so-fancy, delta, etc.).

No changes → stop.

## 2. Group Changes by File (MANDATORY)

**FIRST, separate changes by file.** Each file = separate commit (with rare exceptions).

```
| File | Hunks | Commit? |
|------|-------|---------|
| AuthService.php | 2 | YES - separate commit |
| UserController.php | 1 | YES - separate commit |
| Config.php | 3 | YES - separate commit |
```

**Only after file separation**, analyze hunks within each file.

## 3. Analyze Hunks Within Each File

Parse unified diff output. Hunk = `@@ ... @@` block.

**For EACH hunk in a single file, ask:**

| Question | Purpose |
|----------|---------|
| What TYPE is this? (feat/fix/refactor/...) | Determines commit type |
| What PROBLEM does this solve? | Determines (why) |
| Can this be REVERTED independently? | Determines if same-file split needed |

**Create a hunk table (per file):**

```
| Hunk | Line | Type | Purpose | Independent? |
|------|------|------|---------|--------------|
| 1    | 12   | fix  | typo    | yes          |
| 2    | 45   | feat | new opt | yes          |
```

If hunks in the same file have different purposes → multiple commits for that file.

## 4. Group by Type + Purpose (Within Same File)

**Grouping rules (strict order):**

1. **Same type?** No → separate commits
2. **Same specific problem?** No → separate commits
3. **Direct dependency?** No → separate commits
4. All yes → same commit

**Type mapping:**
- `feat` — new functionality
- `fix` — bug fix
- `refactor` — restructure without behavior change
- `test` / `docs` / `chore`

**What is NOT "same problem":**
- ❌ "Both are in Config file" — same file ≠ same problem
- ❌ "Both improve auth" — same area ≠ same problem
- ❌ "Both are fixes" — same type ≠ same problem
- ✅ "Both fix the null user crash" — same specific bug

## 5. Commit Each Group

Order: fixes → refactors → features

```bash
# Option A: Stage entire file (when all changes in file are same purpose)
git add <file>
git commit -m "type(Scope): what (why)"

# Option B: Intermediate file via hash-object (RECOMMENDED for AI agents)
# AI generates a file containing ONLY the changes for this commit
# Working tree is NEVER touched — safe, deterministic, no side effects
AGENTIC_TMP=$(mktemp -d /tmp/agentic-XXXXXX)
# Write intermediate file with only the first logical change applied
cat > "$AGENTIC_TMP/intermediate.ext" << 'INTERMEDIATE'
... file content with only first set of changes ...
INTERMEDIATE
BLOB=$(git hash-object -w "$AGENTIC_TMP/intermediate.ext")
git update-index --cacheinfo 100644,"$BLOB",<file>
git commit -m "type(Scope): what (why)"
rm -rf "$AGENTIC_TMP"
# Remaining changes are still in working tree — git add for next commit

# Option C: Zero-context diff (good for line-level hunk separation)
AGENTIC_TMP=$(mktemp -d /tmp/agentic-XXXXXX)
git diff --no-ext-diff -U0 <file> > "$AGENTIC_TMP/full.patch"
# Extract specific @@ hunks into separate patch files
# Keep diff header (first 4 lines) + desired @@ blocks
git apply --cached --unidiff-zero "$AGENTIC_TMP/hunk1.patch"
git commit -m "type(Scope): what (why)"
# IMPORTANT: Regenerate diff after each apply (index hash changed)
git diff --no-ext-diff -U0 <file> > "$AGENTIC_TMP/remaining.patch"
git apply --cached --unidiff-zero "$AGENTIC_TMP/remaining.patch"
git commit -m "type(Scope): what (why)"
rm -rf "$AGENTIC_TMP"
```

### Choosing a Staging Technique

| Technique | When to Use | Working Tree Safe? |
|-----------|-------------|:--:|
| **Option A**: `git add <file>` | All changes in file are same purpose | N/A |
| **Option B**: `hash-object` | Same file, multiple semantic concerns (AI agents) | ✅ |
| **Option C**: `-U0` diff | Same file, hunks map cleanly to concerns | ✅ |

**Why Option B is best for AI agents:**
- AI naturally generates full file content (not diffs)
- Working tree is never modified — no risk of data loss
- Pre-commit hooks see only the staged changes
- Supports semantic grouping (changes that span multiple hunks but share one purpose)

**Error recovery:** If any step fails mid-workflow, run `git reset HEAD` to unstage
and `rm -rf "$AGENTIC_TMP"` to clean up, then retry.

**Binary files:** The hash-object technique requires generating file content.
For binary files, use `git add <file>` (Option A) only.

### Option D: Commit Plan Script (MOST TOKEN-EFFICIENT)

Instead of executing git commands manually, output a JSON commit plan and let
the `git-commit-plan` script handle all staging and committing:

```bash
# AI outputs the plan (minimal tokens) and script executes it (zero tokens)
cat > /tmp/plan.json << 'EOF'
{
  "commits": [
    {
      "message": "fix(Service): add validation (crash prevention)",
      "files": [{"path": "Service.php", "hunks": [0]}]
    },
    {
      "message": "feat(Service): add sanitize method (XSS protection)",
      "files": [{"path": "Service.php"}]
    }
  ]
}
EOF
git-commit-plan /tmp/plan.json
```

**File strategies** (auto-detected from fields):
- No extra fields → `git add` (full file)
- `"hunks": [0, 2]` → extract specific hunks from `-U0` diff
- `"intermediate": "/tmp/v1.ext"` → `git hash-object` + `git update-index`

The script is at `scripts/git-commit-plan`. Install it on PATH or invoke with full path.

## 6. Verify (IMPORTANT)

```bash
git log --oneline -<N>
git status --short

# CRITICAL: Verify only ONE file was changed per commit
git show --stat HEAD | grep '|' | wc -l
# Expected: 1 (one file per commit)
# If > 1: git reset --soft HEAD~1 and split into separate commits
```

Remaining changes → go back to step 2 and continue analysis.

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

## One File Per Commit (STRICT)

**Each file MUST be committed separately.** This rule is strictly enforced.

- Even for the same issue/task, each file gets its own commit
- Grouping files as "same problem" or "related changes" is **NOT allowed**
- Only exception: New function + code that DIRECTLY calls it (true compile-time dependency)

### ❌ Bad: Combining multiple files
```bash
# Wrong - multiple files in one commit
fix(AuthService,UserController): add input validation (prevent errors)

# Wrong - grouping "related" changes
refactor(SalesChannel): remove promoted sales channels (no longer used)
# ^ Contains changes to SalesChannel.php, RetailerComputedAttributes.php, Controller.php
```

### ✅ Good: One file per commit
```bash
fix(AuthService): add input validation (prevent empty credentials)
fix(UserController): add input validation (prevent invalid IDs)

# Each file is a separate commit even if fixing the same issue:
refactor(SalesChannel): remove PROMOTED_SALES_CHANNELS constant
refactor(RetailerComputedAttributes): remove promoted union
refactor(RetailerActionController): remove promoted filter
```

**Exception**: Only combine files when one directly depends on the other (e.g., new function + its caller in same commit).

## Over-Grouping Anti-Patterns

**Common mistakes that lead to non-atomic commits:**

### ❌ "Same File" Fallacy
```bash
# BAD: Grouped because same file
fix(nginx.conf): improve config (CORS + security + maintenance)
```
Same file ≠ same commit. Split by purpose:
```bash
fix(nginx.conf): restore origin fallback map (empty Origin handling)
fix(nginx.conf): add security headers to maintenance (XSS protection)
feat(nginx.conf): add tracing headers (observability)
```

### ❌ "Same Area" Fallacy
```bash
# BAD: Grouped because "all auth related"
fix(AuthService): improve authentication (validation + logging + caching)
```
Same area ≠ same commit. Split by purpose:
```bash
fix(AuthService): validate token expiry (session hijack prevention)
feat(AuthService): add auth logging (audit trail)
refactor(AuthService): extract token cache (performance)
```

### ❌ "Related Improvements" Fallacy
```bash
# BAD: Grouped because "all improvements"
refactor(Config): various improvements (cleanup)
```
"Improvements" is not a purpose. Split:
```bash
fix(Config): remove deprecated keys (compatibility)
refactor(Config): rename ambiguous options (clarity)
feat(Config): add validation schema (type safety)
```

### ✅ Valid Grouping: True Dependency
```bash
# GOOD: Function + its caller in same commit (would break if separate)
feat(UserService): add formatBalance with currency display
```

---

## Edge Case: Interleaved Changes

If hunks can't be separated (too close together, lines interleaved):
- Commit together
- Explain both in (why)

```bash
refactor(AuthService): extract validation and add caching (interleaved - dedup + perf)
```

**Note**: This is rare. Most "interleaved" cases can actually be split using the `hash-object` technique (see [Splitting Hunks](#splitting-hunks)).

---

# Quick Reference

| Command | Purpose |
|---------|---------|
| `git diff --no-ext-diff` | Standard unified diff (bypasses custom tools) |
| `git diff --no-ext-diff --staged` | Staged changes in unified format |
| `git diff --no-ext-diff -U0 <file>` | Zero-context diff (maximizes hunk separation) |
| `git hash-object -w <file>` | Store file as blob, return SHA (for index staging) |
| `git update-index --cacheinfo 100644,<SHA>,<path>` | Point index at a blob (stage without touching worktree) |
| `git apply --cached --unidiff-zero <patch>` | Apply zero-context patch to index only |
| `git add -p` | Interactive hunk staging (human use) |
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

---

# Troubleshooting

## Custom Diff Tools

If `git diff` shows side-by-side or custom formatting instead of unified diff:

```bash
# Always use --no-ext-diff to bypass external diff tools
git diff --no-ext-diff

# Or temporarily disable in current shell
export GIT_EXTERNAL_DIFF=""
```

**Common tools that change diff format:**
- `diff-so-fancy`
- `delta`
- `difftastic`
- Custom `core.pager` settings

## Splitting Hunks

When a single file has multiple concerns that need separate commits:

1. **Intermediate file via hash-object (Option B — RECOMMENDED for AI agents):**
   ```bash
   # AI generates the file as it should look after ONLY the first commit's changes
   AGENTIC_TMP=$(mktemp -d /tmp/agentic-XXXXXX)
   # Write file with only the first logical change (e.g., bug fix, not the new feature)
   cat > "$AGENTIC_TMP/intermediate.ext" << 'EOF'
   ... file content with only first set of changes applied ...
   EOF
   BLOB=$(git hash-object -w "$AGENTIC_TMP/intermediate.ext")
   git update-index --cacheinfo 100644,"$BLOB",file.ext
   git commit -m "fix(File): first concern (reason)"
   rm -rf "$AGENTIC_TMP"
   # Working tree still has ALL changes — remaining changes for next commit:
   git add file.ext
   git commit -m "feat(File): second concern (reason)"
   ```
   **Why this works:** `hash-object -w` stores the intermediate file as a blob in git's
   object database. `update-index --cacheinfo` points the index at that blob. The working
   tree is never touched — it still contains all original changes. After the first commit,
   `git add` stages the diff between the intermediate state and the full working tree.

2. **Zero-context diff extraction (Option C):**
   ```bash
   AGENTIC_TMP=$(mktemp -d /tmp/agentic-XXXXXX)
   git diff --no-ext-diff -U0 file.ext > "$AGENTIC_TMP/full.patch"
   # -U0 maximizes hunk separation (no context overlap)
   # Extract desired @@ blocks into a partial patch
   # MUST keep diff header (first 4 lines: diff --git, index, ---, +++)
   git apply --cached --unidiff-zero "$AGENTIC_TMP/partial.patch"
   git commit -m "fix(File): first concern (reason)"
   # Regenerate diff (index hash changed after commit)
   git diff --no-ext-diff -U0 file.ext > "$AGENTIC_TMP/remaining.patch"
   git apply --cached --unidiff-zero "$AGENTIC_TMP/remaining.patch"
   git commit -m "feat(File): second concern (reason)"
   rm -rf "$AGENTIC_TMP"
   ```
   **Note:** `--unidiff-zero` is MANDATORY when applying `-U0` patches. Always regenerate
   the diff after each apply because the index hash changes.

### Technique Comparison

| Technique | Working Tree Safe | Semantic Grouping | AI-Natural |
|-----------|:-:|:-:|:-:|
| hash-object + update-index | ✅ | ✅ | ✅ |
| -U0 diff + apply --cached | ✅ | ❌ | ❌ |
| git add -p (interactive) | ✅ | ❌ | ❌ |

**Semantic Grouping** = ability to combine non-adjacent hunks that share one logical purpose.
AI agents should prefer `hash-object` because they naturally generate file content, not diffs.

## Verifying Atomic Commits

After committing, verify each commit is atomic:

```bash
git log --oneline -5
git show --stat HEAD    # Check files changed

# CRITICAL: Verify only ONE file per commit
git show --stat HEAD | grep '|' | wc -l
# Expected output: 1
# If output > 1: You violated "One File Per Commit" rule!

git show HEAD           # Review actual changes
```

If a commit has multiple files:
```bash
git reset --soft HEAD~1    # Undo commit, keep changes staged
git reset HEAD             # Unstage all
# Now commit each file separately
```
