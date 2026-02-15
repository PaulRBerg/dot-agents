# dot-agents

Central repository for AI agent skills built around the [Skills ecosystem](https://skills.sh/) by Vercel.

## Overview

This repository follows the file structure used by the [`skills`](https://www.npmjs.com/package/skills) CLI.

See the [official announcement](https://vercel.com/changelog/introducing-skills-the-open-agent-skills-ecosystem) for more details.

## Structure

```
~/.agents/
├── skills/     # Active skills (loaded by agents)
└── shelf/      # Inactive skills (move to skills/ to activate)
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
npx skills add owner/repo
```

> [!NOTE]
> The GitHub repository must contain a `skills/` directory with skill definitions.
> See [skill discovery](https://github.com/vercel-labs/add-skill?tab=readme-ov-file#skill-discovery) for supported directory structures.

**Activate/deactivate skills:**

```bash
# Deactivate a skill
mv skills/some-skill shelf/

# Activate a skill
mv shelf/some-skill skills/
```

## 📦 Skill Sources

Skills are installed from these repositories:

| Source | Description |
| --- | --- |
| [PaulRBerg/agent-skills](https://github.com/PaulRBerg/agent-skills) | General-purpose skills (commit, code-review, yeet, cli-gh, etc.) |
| [sablier-labs/agent-skills](https://github.com/sablier-labs/agent-skills) | Sablier & Web3 skills (web3-foundry, effect-ts, vitest, etc.) |
| [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) | Vercel/React skills (composition-patterns, react-best-practices, etc.) |
| [supabase/agent-skills](https://github.com/supabase/agent-skills) | Supabase & Postgres skills (supabase-postgres-best-practices, etc.) |
| [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | Official Claude Code plugins (frontend-design, playground, etc.) |

Install all skills from a source:

```bash
npx skills add PaulRBerg/agent-skills
```

All skills are externally installed and managed via `.skill-lock.json`. **Do not modify, refactor, or include these skills in any task.** When skills are added or removed, cross-check this table to keep it in sync.

## License

MIT
