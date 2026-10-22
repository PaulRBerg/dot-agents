#!/usr/bin/env bash
set -eu

# Start the shared agent Chromium when its debugging endpoint is down.
# Use the same port as chrome-devtools-mcp.sh and the fixed shared profile.
port="${PRB_AGENT_CHROMIUM_PORT:-9222}"
endpoint="http://127.0.0.1:$port/json/version"
profile="$HOME/Library/Application Support/prb-agent-chromium"

endpoint_up() {
  curl -fsS --max-time 2 "$endpoint" >/dev/null 2>&1
}

if endpoint_up; then
  printf '%s\n' "Chromium is already listening on port $port."
  exit 0
fi

if ! open -na Chromium --args \
  "--remote-debugging-port=$port" \
  "--user-data-dir=$profile" \
  --no-first-run \
  --no-default-browser-check \
  about:blank; then
  printf '%s\n' "Could not launch Chromium.app." >&2
  exit 1
fi

# Chromium opens the debugging port shortly after launch.
attempts=0
while [[ "$attempts" -lt 40 ]]; do
  if endpoint_up; then
    printf '%s\n' "Launched Chromium on port $port."
    exit 0
  fi
  attempts=$((attempts + 1))
  sleep 0.5
done

printf '%s\n' "Chromium did not open port $port within 20 seconds. A running Chromium may hold the shared profile without remote debugging." >&2
exit 1
