# dot-agents

Central repository for AI agent skills built around the [Skills ecosystem](https://skills.sh/) by Vercel.

## Overview

This repository follows the file structure used by the [`skills`](https://www.npmjs.com/package/skills) CLI.

See the [official announcement](https://vercel.com/changelog/introducing-skills-the-open-agent-skills-ecosystem) for
more details.

## Structure

```
~/.agents/
└── skills/      # Skills loaded by agents
```

## How It Works

AI agents (Claude Code, Cursor, GitHub Copilot, etc.) look for skills in their config directories. This repository acts
as a central location that agents can reference via symlink. For Claude Code, the `agent-skills` publish workflow
installs each skill here and then creates a per-skill relative symlink:

```bash
# Example for a single skill
ln -s ../../.agents/skills/<name> ~/.claude/skills/<name>
```

Claude-only skills (`metadata.install-targets: claude-code`, e.g. `claude-handoff`) are installed as real directories
under `~/.claude/skills` instead of symlinks. This way, all your agents share the same skill library.

### Managing Skills

**Install a skill:**

```bash
bunx skills add owner/repo
```

> [!NOTE] The GitHub repository must contain a `skills/` directory with skill definitions. See
> [skill discovery](https://github.com/vercel-labs/skills#skill-discovery) for supported directory structures.

## 📦 Skill Sources

Skills are installed from these repositories:

| Source                                                              | Managed skills    | Description                                         |
| ------------------------------------------------------------------- | ----------------- | --------------------------------------------------- |
| [PaulRBerg/agent-skills](https://github.com/PaulRBerg/agent-skills) | Catalog portfolio | General-purpose skills (commit, yeet, cli-gh, etc.) |
| [vercel-labs/skills](https://github.com/vercel-labs/skills)         | `find-skills`     | Skills ecosystem discovery                          |

For bootstrap or recovery, install the catalog directly from its remote source; this does not require a local
`agent-skills` checkout:

```bash
just install-catalog
```

Use `just install-catalog <repo>` to bootstrap from another compatible catalog. It is an installer for a remote
snapshot, not the catalog publication workflow.

To change or reconcile the PaulRBerg catalog, work in the `agent-skills` source repository and follow its guarded
`publish-skills` workflow after source changes. That owner workflow commits and pushes the source, coordinates target
updates, checks the expected `HEAD` and process lock, and verifies source-owned installation and CLI-lock drift.

The PaulRBerg row is catalog-owned. Every other row is an intentionally external source: its files are tracked here as
global installation snapshots, while canonical ownership remains upstream. They are valid dependencies even though they
do not belong in the `agent-skills` catalog.

Use `just install-external` to install or refresh the declared external skills for Codex and Claude Code. **Do not
modify, refactor, or include externally sourced skills in catalog tasks.** When skills are added or removed, update this
table and the sync recipe together.

## Instructions

`AGENTS.md` is the canonical source for PRB's global agent instructions. On commit, a Husky + lint-staged pre-commit
hook (`.lintstagedrc.mjs`) copies it unchanged and auto-commits synced copies in sibling repos. `ai-commit` is the local
deterministic commit engine; install it at `~/.local/bin/ai-commit` so these helpers can preserve concurrent work there:

- `~/.codex/AGENTS.md` — copied and committed by `helpers/commit_codex_agents.sh`.
- `~/.claude/CLAUDE.md` — copied and committed by `helpers/commit_claude_repo.sh`.

Edit `AGENTS.md` here; never hand-edit the generated copies in `~/.codex` or `~/.claude`.

## License

MIT
