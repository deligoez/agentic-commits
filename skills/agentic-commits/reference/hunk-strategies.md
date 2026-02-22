# Hunk Grouping Strategies

## What's a Hunk?

```diff
@@ -12,6 +12,9 @@ function name()
 context line
-removed line
+added line
```

One file can have multiple hunks. Each `@@` = one hunk.

## Grouping Rules

### Rule 1: Dependency
> "Would this break without the other?"

Yes → same group

### Rule 2: Semantic Unity
> "Same problem being solved?"

Yes → same group

### Rule 3: Independence
> "Can stand alone?"

Yes → can be separate

## Common Patterns

| Scenario | Grouping |
|----------|----------|
| Feature + its tests | Same |
| Rename + all usages | Same |
| Two unrelated fixes | Separate |
| Config + code using it | Same |

## Same File, Multiple Concerns

### Technique 1: Intermediate File via hash-object (Option B — RECOMMENDED for AI agents)

AI generates a file containing ONLY the changes for one commit. Working tree is never touched.

```bash
AGENTIC_TMP=$(mktemp -d /tmp/agentic-XXXXXX)
# Write file as it should look after ONLY the first commit's changes
cat > "$AGENTIC_TMP/intermediate.ext" << 'EOF'
... file with only first logical change applied ...
EOF
BLOB=$(git hash-object -w "$AGENTIC_TMP/intermediate.ext")
git update-index --cacheinfo 100644,"$BLOB",file.ext
git commit -m "fix(File): first concern (reason)"
rm -rf "$AGENTIC_TMP"
# Working tree still has ALL changes — stage remaining:
git add file.ext
git commit -m "feat(File): second concern (reason)"
```

**Why this is best for AI agents:**
- AI naturally generates file content (not diffs)
- Working tree is never modified — no data loss risk
- Supports semantic grouping (non-adjacent hunks with same purpose)

### Technique 2: Zero-context diff extraction (Option C)

Extract specific `@@` hunks from a `-U0` diff:

```bash
AGENTIC_TMP=$(mktemp -d /tmp/agentic-XXXXXX)
git diff --no-ext-diff -U0 file.ext > "$AGENTIC_TMP/full.patch"
# Keep diff header (4 lines) + desired @@ blocks only
git apply --cached --unidiff-zero "$AGENTIC_TMP/partial.patch"
git commit -m "fix(File): first concern (reason)"
# Regenerate diff (index hash changed after commit)
git diff --no-ext-diff -U0 file.ext > "$AGENTIC_TMP/remaining.patch"
git apply --cached --unidiff-zero "$AGENTIC_TMP/remaining.patch"
git commit -m "feat(File): second concern (reason)"
rm -rf "$AGENTIC_TMP"
```

**Note:** `--unidiff-zero` is mandatory with `-U0` patches. Always regenerate diff after each apply because the index hash changes.

Both techniques enable atomic commits that make **Review** clearer — each commit has one purpose.

## Commit Order

1. **Fixes** — often cherry-picked
2. **Refactors** — foundation
3. **Features** — new functionality
4. **Chore/Docs** — non-functional

This order helps **Handoff** — new agents see stable foundation before new features.

## Edge Case: Interleaved Changes

If hunks can't be separated (changes too close):
- Commit together
- Explain both in (why)

```bash
refactor(AuthService): extract validation and add caching (dedup + perf)
```

Note: Changes interleaved in same function, committed together.
