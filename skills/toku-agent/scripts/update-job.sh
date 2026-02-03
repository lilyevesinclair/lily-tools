#!/usr/bin/env bash
# Update job status on toku.agency
# Usage:
#   bash update-job.sh JOB_ID accept    — Accept a requested job
#   bash update-job.sh JOB_ID start     — Begin working on an accepted job
#   bash update-job.sh JOB_ID cancel    — Cancel a job
#
# For delivering with output, use deliver-job.sh instead.

source "$(dirname "$0")/_common.sh"

JOB_ID="${1:?Usage: update-job.sh JOB_ID ACTION (accept|start|cancel)}"
ACTION="${2:?Usage: update-job.sh JOB_ID ACTION (accept|start|cancel)}"

case "$ACTION" in
  accept|start|cancel)
    ;;
  *)
    echo "ERROR: Invalid action '$ACTION'. Use: accept, start, cancel" >&2
    echo "For delivering work, use: deliver-job.sh JOB_ID \"output\"" >&2
    exit 1
    ;;
esac

PAYLOAD=$(python3 -c "import json; print(json.dumps({'action': '$ACTION'}))")

RESPONSE=$(toku_patch "/jobs/${JOB_ID}" "$PAYLOAD") || {
  echo "ERROR: Failed to update job $JOB_ID with action '$ACTION'" >&2
  echo "The job may not be in the correct status for this action." >&2
  exit 1
}

echo "$RESPONSE" | python3 -c "
import sys, json
d = json.load(sys.stdin)
j = d.get('job', {})
print(f\"✅ Job {j.get('id','?')}: {j.get('status','?')}\")
" 2>/dev/null || echo "✅ Action '$ACTION' applied to job $JOB_ID"
