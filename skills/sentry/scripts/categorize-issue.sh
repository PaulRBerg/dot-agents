#!/usr/bin/env bash
#
# Fetch a single Sentry issue and suggest a category based on stack trace analysis
#
# Usage: ./categorize-issue.sh <issue_id>
#
# Categories:
#   - VALID: Application error requiring investigation
#   - FALSE_POSITIVE: Expected error, network issue, or bot traffic
#   - ALREADY_RESOLVED: No recent occurrences
#   - THIRD_PARTY: Browser extension or external script error
#
# Requires SENTRY_AUTH_TOKEN environment variable (from portal/.env.local)

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <issue_id>" >&2
  exit 1
fi

ISSUE_ID="$1"

# Check for auth token
if [[ -z "${SENTRY_AUTH_TOKEN:-}" ]]; then
  echo "Error: SENTRY_AUTH_TOKEN not set" >&2
  echo "Run: source <(grep SENTRY_AUTH_TOKEN portal/.env.local)" >&2
  exit 1
fi

echo "Fetching issue $ISSUE_ID..."
echo

# Fetch issue details
ISSUE=$(curl -s -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/issues/${ISSUE_ID}/")

# Fetch latest event
EVENT=$(curl -s -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/issues/${ISSUE_ID}/events/latest/")

echo "=== Issue Details ==="
echo "$ISSUE" | jq -r '{
  shortId: .shortId,
  title: .title,
  culprit: .culprit,
  level: .level,
  count: .count,
  userCount: .userCount,
  firstSeen: .firstSeen,
  lastSeen: .lastSeen,
  permalink: .permalink
}'

echo
echo "=== Stack Trace Analysis ==="

# Extract stack trace frames
FRAMES=$(echo "$EVENT" | jq -r '.exception.values[0].stacktrace.frames // []')

# Check for extension patterns
EXTENSION_PATTERNS="chrome-extension://|moz-extension://|safari-extension://|inpage\.js|content\.js|inject\.js|contentscript"

if echo "$FRAMES" | jq -r '.[].filename // empty' | grep -qE "$EXTENSION_PATTERNS"; then
  echo "CATEGORY: THIRD_PARTY"
  echo "Reason: Stack trace contains browser extension code"
  echo
  echo "Extension frames detected:"
  echo "$FRAMES" | jq -r '.[] | select(.filename | test("'"$EXTENSION_PATTERNS"'"; "i")) | "  - \(.filename):\(.lineno)"'
  exit 0
fi

# Check for app code
APP_PATTERNS="portal/|@/|src/|webpack://portal"

if echo "$FRAMES" | jq -r '.[].filename // empty' | grep -qE "$APP_PATTERNS"; then
  echo "CATEGORY: VALID"
  echo "Reason: Stack trace points to application code"
  echo
  echo "App frames detected:"
  echo "$FRAMES" | jq -r '.[] | select(.filename | test("'"$APP_PATTERNS"'"; "i")) | select(.inApp == true) | "  - \(.filename):\(.lineno) in \(.function // "anonymous")"'
  exit 0
fi

# Check last seen date
LAST_SEEN=$(echo "$ISSUE" | jq -r '.lastSeen')
DAYS_AGO=$(( ($(date +%s) - $(date -d "$LAST_SEEN" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_SEEN%.*}" +%s 2>/dev/null || echo 0)) / 86400 ))

if [[ $DAYS_AGO -gt 14 ]]; then
  echo "CATEGORY: ALREADY_RESOLVED"
  echo "Reason: Last seen $DAYS_AGO days ago"
  exit 0
fi

echo "CATEGORY: NEEDS_MANUAL_REVIEW"
echo "Reason: Could not automatically categorize"
echo
echo "Error message:"
echo "$EVENT" | jq -r '.exception.values[0].value // .message // "N/A"'
