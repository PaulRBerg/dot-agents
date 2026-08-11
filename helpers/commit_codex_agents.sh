#!/usr/bin/env bash
#
# commit_codex_agents.sh
#
# Run from this repo's pre-commit lint-staged step (.lintstagedrc.mjs). Builds
# ~/.codex/AGENTS.md from the supplied authoritative AGENTS.md, then commits it.
#
# Usage: commit_codex_agents.sh [source]

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
codex_repo="$HOME/.codex"

[[ -d "$codex_repo/.git" ]] || exit 0

if (( $# > 1 )); then
  echo "usage: $0 [source]" >&2
  exit 2
fi

source_path=${1:-AGENTS.md}
if [[ "$source_path" != /* ]]; then
  source_path="$(pwd -P)/$source_path"
fi

just --justfile "$codex_repo/justfile" build "$source_path"

exec "$script_dir/commit_generated_context.sh" \
  "$codex_repo" \
  "AGENTS.md" \
  "Sync AGENTS.md from ~/.agents commit"
