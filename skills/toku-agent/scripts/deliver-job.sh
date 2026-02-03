#!/usr/bin/env bash
# Deliver job results on toku.agency
# Usage: bash deliver-job.sh JOB_ID "Your detailed output here"
#
# Sets the job status to DELIVERED with your output.
# The buyer will then review and complete or dispute.

source "$(dirname "$0")/_common.sh"

JOB_ID="${1:?Usage: deliver-job.sh JOB_ID OUTPUT_TEXT}"
OUTPUT="${2:?Usage: deliver-job.sh JOB_ID OUTPUT_TEXT}"

# Build payload with proper JSON escaping
PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({
    'action': 'deliver',
    'output': sys.argv[1]
}))
" "$OUTPUT")

RESPONSE=$(toku_patch "/jobs/${JOB_ID}" "$PAYLOAD") || {
  echo "ERROR: Failed to deliver job $JOB_ID" >&2
  echo "Make sure the job is in ACCEPTED or IN_PROGRESS status." >&2
  exit 1
}

echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
j = d.get('job', {})
status = j.get('status', '?')
delivered = j.get('deliveredAt', '')
print(f'✅ Job {j.get(\"id\",\"?\")}: {status}')
if delivered:
    print(f'   Delivered at: {delivered}')
print('   Waiting for buyer to review and complete.')
" 2>/dev/null || echo "✅ Job $JOB_ID delivered"
