#!/usr/bin/env bash
#
# Fetch all unresolved Sentry issues for sablier-labs/portal
#
# Usage: ./fetch-issues.sh [--stats-period=14d] [--limit=100]
#
# Requires SENTRY_AUTH_TOKEN environment variable (from portal/.env.local)

set -euo pipefail

# Default values
STATS_PERIOD="${STATS_PERIOD:-14d}"
LIMIT="${LIMIT:-100}"

# Parse arguments
for arg in "$@"; do
  case $arg in
    --stats-period=*)
      STATS_PERIOD="${arg#*=}"
      ;;
    --limit=*)
      LIMIT="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

# Check for auth token
if [[ -z "${SENTRY_AUTH_TOKEN:-}" ]]; then
  echo "Error: SENTRY_AUTH_TOKEN not set" >&2
  echo "Run: source <(grep SENTRY_AUTH_TOKEN portal/.env.local)" >&2
  exit 1
fi

# Fetch issues
curl -s -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/projects/sablier-labs/portal/issues/?query=is:unresolved&statsPeriod=${STATS_PERIOD}&limit=${LIMIT}"
