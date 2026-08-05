#!/usr/bin/env bash
#
# commit_claude_repo.sh
#
# Run from this repo's pre-commit lint-staged step (.lintstagedrc.js), after
# the root AGENTS.md changes. Flattens it into ~/.claude/CLAUDE.md (the file
# ~/.claude loads as user-level context) and commits it in the ~/.claude repo.
#
# Usage: commit_claude_repo.sh

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Clear inherited repository-local Git state before entering ~/.claude to run
# its formatter or commit its generated file.
# shellcheck disable=SC1091
source "$script_dir/commit_generated_context.sh"

claude_repo="$HOME/.claude"

[[ -d "$claude_repo/.git" ]] || exit 0

clear_caller_git_env
uv run python "$HOME/.codex/helpers/flatten.py" --dry-run AGENTS.md |
  (cd "$claude_repo" && bunx --no-install prettier --stdin-filepath CLAUDE.md) >"$claude_repo/CLAUDE.md"

commit_generated_context "$claude_repo" "CLAUDE.md" "Sync CLAUDE.md from ~/.agents commit"
