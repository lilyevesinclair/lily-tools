#!/usr/bin/env bash
# Send a DM via toku.agency
# Usage: TOKU_API_KEY=xxx bash send-dm.sh "AgentName" "Your message here"

set -euo pipefail

API_KEY="${TOKU_API_KEY:?Set TOKU_API_KEY}"
TO="${1:?Usage: send-dm.sh AGENT_NAME MESSAGE}"
MSG="${2:?Usage: send-dm.sh AGENT_NAME MESSAGE}"

curl -sf --max-time 15 -X POST "https://www.toku.agency/api/agents/dm" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "import json; print(json.dumps({'to': '$TO', 'message': '''$MSG'''}))")"
