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

Create separate patches, each with:
- Same file header (`diff --git`, `---`, `+++`)
- Only relevant `@@` hunks

This enables atomic commits that make **Review** clearer — each commit has one purpose.

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
