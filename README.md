# dot-agents

Central repository for AI agent skills built around the [Skills ecosystem](https://skills.sh/) by Vercel.

## Overview

This repository follows the file structure used by the [`skills`](https://www.npmjs.com/package/skills) CLI.

See the [official announcement](https://vercel.com/changelog/introducing-skills-the-open-agent-skills-ecosystem) for more details.

## Structure

```
~/.agents/
└── skills/      # Skills loaded by agents
```

> [!NOTE]
> `skills/.system` contains Claude Code's official skills. There is an open issue in the Claude Code repo to relocate it: `https://github.com/anthropics/claude-code/issues/20820`.

## How It Works

AI agents (Claude Code, Cursor, GitHub Copilot, etc.) look for skills in their config directories. This repository acts as a central location that agents can reference via symlink:

```bash
# Example for Claude Code
ln -s ~/.agents/skills ~/.claude/skills
```

This way, all your agents share the same skill library.

### Managing Skills

**Install a skill:**

```bash
bunx skills add owner/repo
```

> [!NOTE]
> The GitHub repository must contain a `skills/` directory with skill definitions.
> See [skill discovery](https://github.com/vercel-labs/add-skill?tab=readme-ov-file#skill-discovery) for supported directory structures.

## 📦 Skill Sources

Skills are installed from these repositories:

| Source                                                                                      | Description                                                            |
| ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| [PaulRBerg/agent-skills](https://github.com/PaulRBerg/agent-skills)                         | General-purpose skills (commit, code-review, yeet, cli-gh, etc.)       |
| [sablier-labs/agent-skills](https://github.com/sablier-labs/agent-skills)                   | Sablier & Web3 skills                                                  |
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills)                     | Vercel/React skills (composition-patterns, react-best-practices, etc.) |
| [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | Official Claude Code plugins (frontend-design, playground, etc.)       |
| [ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) | `chrome-devtools` skill (companion to the Chrome DevTools MCP server)  |

Install all skills from a source:

```bash
bunx skills add PaulRBerg/agent-skills
```

Most skills are installed from these repositories via `bunx skills add`; a few are first-party (authored directly in this repo). **Do not modify, refactor, or include externally-sourced skills in any task.** When skills are added or removed, cross-check this table to keep it in sync.

## Instructions

`AGENTS.md` is the canonical source for PRB's global agent instructions (`CLAUDE.md` in this repo is a symlink
to it). On commit, a Husky + lint-staged pre-commit hook (`.lintstagedrc.js`) regenerates and auto-commits
synced copies in sibling repos — each using an isolated git index so it doesn't disturb concurrent work there:

- `~/.codex/AGENTS.md` — flattened via `just build` in `~/.codex` (which flattens `AGENTS_symlink.md`, a
  symlink to this repo's `AGENTS.md`, then appends Codex-specific `context/AGENTS_EXTRA.md`), committed by
  `helpers/commit_codex_agents.sh`.
- `~/.claude/CLAUDE.md` — a flattened copy with no extra content, committed by
  `helpers/commit_claude_repo.sh`.

Edit `AGENTS.md` here; never hand-edit the generated copies in `~/.codex` or `~/.claude`.

## License

MIT
