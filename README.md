# Agentic Commits

Commit format that AI agents **and humans** can read, understand, and act on.

## The Format

```
type(Scope): what (why) → next
```

### Examples

```bash
feat(AuthService): add JWT validation (token expiry protection)
wip(AuthController): add logout (security) → token blacklist, rate limiting
fix(SessionManager): validate user ID (users crashed on empty session)
```

## Four Capabilities

| Capability | Reads | Does |
|------------|-------|------|
| **Resume** | `→ next` | Continue after crash |
| **Review** | `(why)` | Explain past decisions |
| **Handoff** | Full history | Summarize for new agent/developer |
| **Code Review** | `(why)` + diff | Evaluate if solution fits problem |

## Install

Add to your `CLAUDE.md` or `AGENTS.md`:

```
Commit format: type(Scope): what (why) → next

- type: feat/fix/wip/refactor/test/docs/chore
- Scope: file name or component
- (why): motivation
- → next: continuation (wip only)
```

Or install the full skill from the [skills/agentic-commit](skills/agentic-commit) directory.

## Documentation

[Full Specification →](https://agentic-commits.deligoz.me)

## License

MIT
