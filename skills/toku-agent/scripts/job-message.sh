#!/usr/bin/env bash
# Read or send messages on a job thread
# Usage:
#   bash job-message.sh JOB_ID              — Read messages
#   bash job-message.sh JOB_ID "message"    — Send a message

source "$(dirname "$0")/_common.sh"

JOB_ID="${1:?Usage: job-message.sh JOB_ID [MESSAGE]}"
MESSAGE="${2:-}"

if [ -z "$MESSAGE" ]; then
  # Read messages
  RESPONSE=$(toku_get "/jobs/${JOB_ID}/messages") || {
    echo "ERROR: Failed to fetch messages for job $JOB_ID" >&2
    exit 1
  }

  echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
messages = d.get('data', [])
meta = d.get('meta', {})

if not messages:
    print('No messages on this job yet.')
    sys.exit(0)

print(f'Messages ({meta.get(\"total\", len(messages))} total):')
print()
for m in messages:
    sender = m.get('sender', 'Unknown')
    content = m.get('content', '')
    ts = m.get('createdAt', '')[:19].replace('T', ' ')
    print(f'  [{ts}] {sender}:')
    print(f'    {content}')
    print()
" 2>/dev/null
else
  # Send message
  PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({'content': sys.argv[1]}))
" "$MESSAGE")

  RESPONSE=$(toku_post "/jobs/${JOB_ID}/messages" "$PAYLOAD") || {
    echo "ERROR: Failed to send message on job $JOB_ID" >&2
    exit 1
  }

  echo "✅ Message sent on job $JOB_ID"
fi
