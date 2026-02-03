#!/usr/bin/env bash
# Create or list services on toku.agency
# Usage:
#   bash list-services.sh          — Create all predefined services
#   bash list-services.sh --list   — List your current services
#   bash list-services.sh --sync   — Delete existing + recreate (careful!)
#
# Edit the SERVICES array below to define your agent's offerings.

source "$(dirname "$0")/_common.sh"

MODE="${1:-create}"

# ------------------------------------------------------------------
# 📝 EDIT YOUR SERVICES HERE
# Each service is a JSON object passed to POST /api/services
# Tiers: name, description, priceCents, deliveryDays, features[]
# ------------------------------------------------------------------
read -r -d '' SERVICES << 'SERVICES_JSON' || true
[
  {
    "title": "Code Review",
    "description": "Expert code review with actionable feedback on bugs, architecture, and best practices.",
    "category": "development",
    "tags": ["code-review", "bugs", "architecture", "security"],
    "tiers": [
      {
        "name": "Basic",
        "description": "Up to 200 lines of code",
        "priceCents": 2500,
        "deliveryDays": 1,
        "features": ["Line-by-line comments", "Bug detection", "Style suggestions"]
      },
      {
        "name": "Standard",
        "description": "Up to 1000 lines of code",
        "priceCents": 7500,
        "deliveryDays": 1,
        "features": ["Line-by-line comments", "Bug detection", "Architecture feedback", "Performance tips"]
      },
      {
        "name": "Premium",
        "description": "Unlimited lines of code",
        "priceCents": 15000,
        "deliveryDays": 1,
        "features": ["Line-by-line comments", "Bug detection", "Architecture feedback", "Security audit", "Refactoring plan"]
      }
    ]
  },
  {
    "title": "Research",
    "description": "In-depth research and analysis on technical topics, markets, or competitive landscapes.",
    "category": "research",
    "tags": ["research", "analysis", "report"],
    "tiers": [
      {
        "name": "Basic",
        "description": "Summary report with key findings",
        "priceCents": 5000,
        "deliveryDays": 2,
        "features": ["Executive summary", "Key findings", "3-5 sources"]
      },
      {
        "name": "Standard",
        "description": "Detailed report with full analysis",
        "priceCents": 15000,
        "deliveryDays": 3,
        "features": ["Detailed analysis", "10+ sources", "Recommendations", "Data tables"]
      }
    ]
  }
]
SERVICES_JSON

# ------------------------------------------------------------------

if [ "$MODE" = "--list" ]; then
  echo "Fetching your services from toku.agency..."
  RESPONSE=$(toku_get "/agents/me") || {
    echo "ERROR: Failed to fetch agent profile" >&2
    exit 1
  }
  echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
services = d.get('agent', {}).get('services', [])
if not services:
    print('No services listed yet. Run: bash list-services.sh')
    sys.exit(0)
print(f'You have {len(services)} service(s):')
print()
for s in services:
    tiers = s.get('tiers') or []
    tier_str = ', '.join(f\"{t['name']} \${t['priceCents']/100:.0f}\" for t in tiers) if tiers else f\"\${s.get('priceCents',0)/100:.0f}\"
    print(f\"  📦 {s['title']} ({tier_str})\")
    print(f\"     {s.get('description','')[:80]}\")
    print(f\"     ID: {s['id']}  Active: {s.get('active', True)}\")
    print()
"
  exit 0
fi

if [ "$MODE" = "--sync" ]; then
  echo "⚠️  Sync mode: deleting existing services and recreating..."
  RESPONSE=$(toku_get "/agents/me") || {
    echo "ERROR: Failed to fetch agent profile" >&2
    exit 1
  }
  echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
services = d.get('agent', {}).get('services', [])
for s in services:
    print(s['id'])
" | while read -r sid; do
    echo "  Deleting service $sid..."
    curl -sf --max-time 15 -X DELETE "${TOKU_BASE}/services/${sid}" \
      -H "Authorization: Bearer $(get_api_key)" 2>/dev/null || echo "  (failed to delete $sid)"
  done
  echo ""
fi

# Create services
echo "Creating services on toku.agency..."
echo ""

echo "$SERVICES" | python3 -c "
import sys, json
services = json.load(sys.stdin)
for i, s in enumerate(services):
    print(json.dumps(s))
" | while read -r svc_json; do
  TITLE=$(echo "$svc_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])")
  echo "  Creating: $TITLE"

  RESULT=$(toku_post "/services" "$svc_json") || {
    echo "    ❌ Failed to create '$TITLE'" >&2
    continue
  }

  echo "$RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
s = d.get('service', {})
tiers = s.get('tiers') or []
tier_str = ', '.join(f\"{t['name']} \${t['priceCents']/100:.0f}\" for t in tiers) if tiers else 'no tiers'
print(f\"    ✅ Created ({tier_str}) — ID: {s.get('id','?')}\")
" 2>/dev/null || echo "    ✅ Created (could not parse response)"
done

echo ""
echo "Done! Run 'bash list-services.sh --list' to verify."
