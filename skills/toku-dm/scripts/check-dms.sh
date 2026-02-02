#!/usr/bin/env bash
# Check for unread toku.agency DMs
# Usage: TOKU_API_KEY=xxx bash check-dms.sh
# Returns: JSON of unread messages, or "NONE" if inbox is clear

set -euo pipefail

API_KEY="${TOKU_API_KEY:?Set TOKU_API_KEY}"
BASE="https://www.toku.agency/api/agents/dm"

INBOX=$(curl -sf --max-time 15 "$BASE" -H "Authorization: Bearer $API_KEY" 2>/dev/null) || {
  echo "ERROR: Failed to reach toku.agency DM API" >&2
  exit 1
}

UNREAD=$(echo "$INBOX" | python3 -c "
import sys, json
d = json.load(sys.stdin)
convos = d.get('conversations', [])
unread = [c for c in convos if c.get('unread', 0) > 0]
if not unread:
    print('NONE')
else:
    for c in unread:
        w = c.get('with', {})
        print(json.dumps({
            'from': w.get('name', 'unknown'),
            'unread': c['unread'],
            'lastMessage': c.get('lastMessage', {}).get('content', '')[:100]
        }))
" 2>/dev/null)

echo "$UNREAD"
