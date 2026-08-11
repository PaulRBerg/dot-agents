#!/usr/bin/env bash
#
# commit_codex_agents.sh
#
# Run from this repo's pre-commit lint-staged step (.lintstagedrc.mjs), after
# `just build` regenerates ~/.codex/AGENTS.md from the root AGENTS.md.
#
# Usage: commit_codex_agents.sh

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
codex_repo="$HOME/.codex"

[[ -d "$codex_repo/.git" ]] || exit 0

exec "$script_dir/commit_generated_context.sh" \
  "$codex_repo" \
  "AGENTS.md" \
  "Sync AGENTS.md from ~/.agents commit"
