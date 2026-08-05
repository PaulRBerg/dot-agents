#!/usr/bin/env bash
#
# Shared deterministic commit adapter for generated global agent context.

set -euo pipefail

clear_caller_git_env() {
  local git_env_var
  local git_env_vars

  git_env_vars=$(git rev-parse --local-env-vars)
  while IFS= read -r git_env_var; do
    [[ -n "$git_env_var" ]] && unset "$git_env_var"
  done <<<"$git_env_vars"
}

commit_generated_context() {
  local target_repo=$1
  local generated_path=$2
  local message=$3
  local prepare_output
  local transaction_id

  command -v ai-commit >/dev/null 2>&1 || {
    echo "ai-commit is required to commit generated context" >&2
    return 1
  }

  clear_caller_git_env
  cd "$target_repo"

  if git diff --quiet HEAD -- "$generated_path"; then
    return 0
  fi

  prepare_output=$(ai-commit prepare --porcelain -- "$generated_path") || {
    echo "ai-commit prepare failed for $generated_path" >&2
    return 1
  }
  transaction_id=$(printf '%s\n' "$prepare_output" | awk -F '\t' '
    $1 == "PREPARED" {
      if (NF != 2 || seen++) {
        exit 1
      }
      print $2
    }
    END {
      if (!seen) {
        exit 1
      }
    }
  ') || {
    echo "ai-commit prepare emitted malformed porcelain for $generated_path" >&2
    return 1
  }
  case "$transaction_id" in
    ????????????????) ;;
    *)
      echo "ai-commit prepare emitted malformed transaction ID for $generated_path" >&2
      return 1
      ;;
  esac
  if [[ "$transaction_id" == *[!0123456789abcdef]* ]]; then
    echo "ai-commit prepare emitted malformed transaction ID for $generated_path" >&2
    return 1
  fi

  ai-commit commit "$transaction_id" --no-verify --no-gpg-sign -m "$message"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [[ $# -ne 3 ]]; then
    echo "usage: $0 <target-repo> <generated-path> <message>" >&2
    exit 2
  fi
  commit_generated_context "$1" "$2" "$3"
fi
