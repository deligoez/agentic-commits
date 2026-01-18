# Agentic Commits

> Your git history has all the information. But no one can use it.
> Agents can't resume after crashes. Reviewers can't evaluate approaches. New developers can't onboard.
> **What if your commits told everyone what to do?**

Commit format that AI agents **and humans** can read, understand, and act on.

## Four Capabilities

| Capability | When | Reads | Does |
|------------|------|-------|------|
| **Resume** | After crash or session loss | `→ next` | Continues interrupted work |
| **Review** | Understanding past decisions | `(why)` | Explains motivation |
| **Handoff** | New agent or developer | Full history | Summarizes state |
| **Code Review** | Evaluating a PR | `(why)` + diff | Evaluates if solution fits problem |

### Works for both agents and humans

| Capability | Agent benefit | Human benefit |
|------------|---------------|---------------|
| **Resume** | Continue after crash | Remember after vacation |
| **Review** | Explain past decisions | Understand why code exists |
| **Handoff** | New agent takes over | New developer onboarding |
| **Code Review** | AI reviewer evaluates approach | Human reviewer understands intent |

## The Format

```
type(Scope): what (why) → next
```

| Element | Purpose | Required |
|---------|---------|----------|
| **type** | Categorize: feat, fix, wip, refactor, test, docs, chore | Always |
| **Scope** | Locate: file name or component | Always |
| **what** | Describe: imperative action | Always |
| **(why)** | Explain: motivation — enables Review & Code Review | Always |
| **→ next** | Continue: tasks — enables Resume | WIP only |

### Examples

```bash
# Completed — reviewer knows it's done
feat(AuthService): add JWT validation (token expiry protection)

# Work in progress — agent knows what's next
wip(AuthController): add logout endpoint (security) → token blacklist, rate limiting

# Bug fix — reviewer can evaluate if solution fits problem
fix(SessionManager): validate user ID (users crashed on empty session)
```

## Why (why) matters for Code Review

```bash
# Without (why) — reviewer guesses the problem
fix(AuthService): add null check

# With (why) — reviewer can evaluate if solution fits
fix(AuthService): add null check (users crashed on empty forms)
```

Now reviewers can ask: "Is null check the best fix? Or should we validate earlier?"

## But why not just read the code?

| Information | In codebase? | In commits? |
|-------------|--------------|-------------|
| What code does | ✅ | ❌ |
| **Why it was written** | ❌ | ✅ `(why)` |
| **What's next** | ❌ | ✅ `→ next` |
| **Is it finished?** | ❌ | ✅ `wip` vs `feat` |

Commits are **metadata about your code**. They complement reading code, not replace it.

## Atomic Commits

- **One logical change per commit** — Don't mix unrelated changes
- **One file per commit** — Different files = separate commits (unless directly dependent)
- **Hunk-level splitting** — Same file can have multiple commits if changes are independent
- **Commit order** — fixes → refactors → features

## Benchmark

Tested across 5 AI models (Claude, Codex, GLM) on real codebases:

| Format | Agent Accuracy |
|--------|----------------|
| Plain commits | 38.7% |
| Conventional | 48.0% |
| + WHY | 51.5% |
| **+ WHY + NEXT + Scope** | **76.6%** |

[Full benchmark methodology →](benchmark/)

## Install

### Quick Start

Add to your CLAUDE.md, AGENTS.md, or system prompt:

```
Commit format: type(Scope): what (why) → next

Elements:
- type: feat/fix/wip/refactor/test/docs/chore
- Scope: file name or component
- (why): motivation — enables Review and Code Review
- → next: continuation — enables Resume (wip only)

Rules:
- One logical change per commit
- One file per commit (unless directly dependent)
- Order: fixes → refactors → features
```

### Full Skill

Copy [skill/agentic-commit.md](skill/agentic-commit.md) to your project for hunk-splitting workflow and detailed examples.

## Documentation

- [Full Specification](https://agenticcommits.deligoz.me)
- [Benchmark Results](benchmark/)
- [Skill Files](skill/)

## License

MIT
