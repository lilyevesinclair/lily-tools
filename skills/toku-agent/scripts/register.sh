#!/usr/bin/env bash
# Register an agent on toku.agency and save the API key
# Usage: bash register.sh "AgentName" "owner@email.com" "Description of your agent"
#
# Saves API key to ~/.config/toku/api_key

source "$(dirname "$0")/_common.sh"

NAME="${1:?Usage: register.sh AGENT_NAME OWNER_EMAIL [DESCRIPTION]}"
EMAIL="${2:?Usage: register.sh AGENT_NAME OWNER_EMAIL [DESCRIPTION]}"
DESC="${3:-An AI agent on toku.agency}"

# Check if already registered
if [ -f "$TOKU_KEY_FILE" ]; then
  echo "⚠️  API key already exists at $TOKU_KEY_FILE"
  echo "To re-register, delete the file first: rm $TOKU_KEY_FILE"
  echo ""
  echo "Current agent info:"
  toku_get "/agents/me" | python3 -m json.tool 2>/dev/null || echo "(Could not fetch — key may be invalid)"
  exit 0
fi

echo "Registering agent '$NAME' on toku.agency..."

PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'name': '''$NAME''',
    'ownerEmail': '''$EMAIL''',
    'description': '''$DESC''',
    'ref': 'toku-agent-skill'
}))
")

RESPONSE=$(toku_post_noauth "/agents/register" "$PAYLOAD") || {
  echo "ERROR: Registration failed. Check your network and try again." >&2
  exit 1
}

# Extract API key
API_KEY=$(echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
agent = d.get('agent', {})
key = agent.get('apiKey', '')
if not key:
    print('ERROR: No API key in response', file=sys.stderr)
    print(json.dumps(d, indent=2), file=sys.stderr)
    sys.exit(1)
print(key)
") || exit 1

# Save it
save_api_key "$API_KEY"

echo "✅ Agent registered successfully!"
echo ""
echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
a = d.get('agent', {})
print(f\"  Name:   {a.get('name')}\")
print(f\"  ID:     {a.get('id')}\")
print(f\"  Status: {a.get('status')}\")
claim = a.get('claimUrl')
if claim:
    print(f\"  Claim:  {claim}\")
    print()
    print('⚠️  Visit the claim URL to activate your agent.')
"
echo ""
echo "API key saved to $TOKU_KEY_FILE"
echo ""
if echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('important') else 1)" 2>/dev/null; then
  echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('important',''))"
fi
