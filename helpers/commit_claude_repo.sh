#!/usr/bin/env bash
#
# commit_claude_repo.sh
#
# Run from this repo's pre-commit lint-staged step (.lintstagedrc.js), after
# the root AGENTS.md changes. Flattens it into ~/.claude/CLAUDE.md (the file
# ~/.claude loads as user-level context) and commits it in the ~/.claude repo
# when it changed. The commit is constructed with an isolated index so
# concurrent work in that repository is untouched.
#
# Usage: commit_claude_repo.sh

set -euo pipefail

claude_repo="$HOME/.claude"

[[ -d "$claude_repo/.git" ]] || exit 0

uv run python "$HOME/.codex/helpers/flatten.py" --dry-run AGENTS.md >"$claude_repo/CLAUDE.md"

# Hooks inherit repository-local variables from the calling Git process, and
# `git -C` does not replace values such as GIT_INDEX_FILE for a foreign repo.
git_env_vars=$(git rev-parse --local-env-vars)
while IFS= read -r git_env_var; do
  [[ -n "$git_env_var" ]] && unset "$git_env_var"
done <<<"$git_env_vars"
unset git_env_var git_env_vars

if git -C "$claude_repo" diff --quiet HEAD -- CLAUDE.md; then
  exit 0
fi

temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/commit-claude-repo.XXXXXX")
isolated_index="$temp_dir/index"

cleanup() {
  rm -f "$isolated_index" "$isolated_index.lock"
  rmdir "$temp_dir" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

head_commit=$(git -C "$claude_repo" rev-parse --verify 'HEAD^{commit}')
branch_ref=$(git -C "$claude_repo" symbolic-ref -q HEAD)

GIT_INDEX_FILE="$isolated_index" git -C "$claude_repo" read-tree "$head_commit"
GIT_INDEX_FILE="$isolated_index" git -C "$claude_repo" add -- CLAUDE.md
tree=$(GIT_INDEX_FILE="$isolated_index" git -C "$claude_repo" write-tree)
commit=$(printf '%s\n' "Sync CLAUDE.md from ~/.agents commit" |
  git -C "$claude_repo" commit-tree "$tree" -p "$head_commit")
git -C "$claude_repo" update-ref "$branch_ref" "$commit" "$head_commit"
