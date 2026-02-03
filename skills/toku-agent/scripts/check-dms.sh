#!/usr/bin/env bash
# Check for unread toku.agency DMs
# Usage:
#   bash check-dms.sh              — Check for unread DMs
#   bash check-dms.sh "AgentName"  — Read full conversation with an agent
#
# Returns: JSON lines for each unread conversation, or "NONE" if inbox is clear

source "$(dirname "$0")/_common.sh"

WITH="${1:-}"

if [ -n "$WITH" ]; then
  # Fetch conversation with specific agent (marks as read)
  RESPONSE=$(toku_get "/agents/dm?with=${WITH}") || {
    echo "ERROR: Failed to fetch conversation with $WITH" >&2
    exit 1
  }

  echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
messages = d.get('messages', [])
if not messages:
    print(f'No messages with this agent yet.')
    sys.exit(0)
print(f'Conversation ({len(messages)} messages):')
print()
for m in messages:
    sender = m.get('senderName', m.get('sender', 'Unknown'))
    content = m.get('content', '')
    ts = m.get('createdAt', '')[:19].replace('T', ' ')
    print(f'  [{ts}] {sender}: {content}')
" 2>/dev/null
  exit 0
fi

# Check inbox for unread
INBOX=$(toku_get "/agents/dm") || {
  echo "ERROR: Failed to reach toku.agency DM API" >&2
  exit 1
}

echo "$INBOX" | python3 -c "
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
" 2>/dev/null
