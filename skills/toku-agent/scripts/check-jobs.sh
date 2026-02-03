#!/usr/bin/env bash
# Poll for pending jobs on toku.agency
# Usage:
#   bash check-jobs.sh              — Check for REQUESTED jobs (new work)
#   bash check-jobs.sh --all        — List all your jobs
#   bash check-jobs.sh --active     — List in-progress jobs
#   bash check-jobs.sh JOB_ID       — Get details for a specific job
#
# Returns: JSON lines for each job, or "NONE" if queue is empty

source "$(dirname "$0")/_common.sh"

MODE="${1:-pending}"

# Single job detail
if [[ "$MODE" =~ ^cl[a-z0-9] ]] || [[ "$MODE" =~ ^[a-f0-9-]{20,} ]]; then
  JOB_ID="$MODE"
  RESPONSE=$(toku_get "/jobs/${JOB_ID}") || {
    echo "ERROR: Failed to fetch job $JOB_ID" >&2
    exit 1
  }
  echo "$RESPONSE" | python3 -m json.tool
  exit 0
fi

# Build query params
case "$MODE" in
  --all)
    QUERY="?role=worker"
    ;;
  --active)
    QUERY="?role=worker&status=IN_PROGRESS"
    ;;
  --accepted)
    QUERY="?role=worker&status=ACCEPTED"
    ;;
  --delivered)
    QUERY="?role=worker&status=DELIVERED"
    ;;
  *)
    QUERY="?role=worker&status=REQUESTED"
    ;;
esac

RESPONSE=$(toku_get "/jobs${QUERY}") || {
  echo "ERROR: Failed to reach toku.agency jobs API" >&2
  exit 1
}

echo "$RESPONSE" | python3 -c "
import sys, json

d = json.load(sys.stdin)
jobs = d.get('jobs', [])

if not jobs:
    print('NONE')
    sys.exit(0)

for j in jobs:
    svc = j.get('service') or {}
    buyer = j.get('buyer') or {}
    tier_name = None

    # Try to figure out the tier from price + service tiers
    tiers = svc.get('tiers') or []
    price = j.get('priceCents', 0)
    for t in tiers:
        if t.get('priceCents') == price:
            tier_name = t.get('name')
            break

    print(json.dumps({
        'id': j.get('id'),
        'status': j.get('status'),
        'service': svc.get('title', 'Unknown'),
        'tier': tier_name,
        'priceCents': price,
        'price': f'\${price/100:.2f}',
        'input': (j.get('input') or '')[:200],
        'buyer': buyer.get('name') or buyer.get('email', 'Unknown'),
        'createdAt': j.get('createdAt'),
    }))
"
