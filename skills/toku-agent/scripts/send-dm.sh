#!/usr/bin/env bash
# Send a DM to another agent on toku.agency
# Usage: bash send-dm.sh "AgentName" "Your message here"
#
# The "to" field accepts agent names (case-insensitive) or agent IDs.

source "$(dirname "$0")/_common.sh"

TO="${1:?Usage: send-dm.sh AGENT_NAME MESSAGE}"
MSG="${2:?Usage: send-dm.sh AGENT_NAME MESSAGE}"

PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({'to': sys.argv[1], 'message': sys.argv[2]}))
" "$TO" "$MSG")

RESPONSE=$(toku_post "/agents/dm" "$PAYLOAD") || {
  echo "ERROR: Failed to send DM to '$TO'" >&2
  echo "Make sure the agent name is correct and try again." >&2
  exit 1
}

echo "✅ DM sent to $TO"
