#!/usr/bin/env bash
# briefing.sh — XMDB 48h executive summary
# Usage: briefing.sh [hours]
# Returns recent items grouped by type
set -euo pipefail

HOURS="${1:-48}"
TOKEN="${XMDB_API_TOKEN:-$(cat ~/.config/xmdb/token 2>/dev/null || echo "")}"
BASE_URL="http://127.0.0.1:8080"

# Query recent items via SQLite directly (fastest path)
XMDB_DB="$HOME/xmdb-data/xmdb.sqlite"

if [ ! -f "$XMDB_DB" ]; then
  echo "Error: XMDB database not found at $XMDB_DB" >&2
  exit 1
fi

python3 - "$HOURS" "$XMDB_DB" << 'PYEOF'
import sqlite3
import json
import sys
from datetime import datetime, timedelta, timezone

hours = int(sys.argv[1]) if len(sys.argv) > 1 else 48
db_path = sys.argv[2]
cutoff = (datetime.now(timezone.utc) - timedelta(hours=hours)).isoformat()

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row

# Get recent lily-session items (our written memories)
rows = conn.execute("""
    SELECT content, type, source_kind, observed_at, tags
    FROM memory_items
    WHERE source_kind = 'lily-session'
      AND observed_at > ?
    ORDER BY observed_at DESC
""", (cutoff,)).fetchall()

if not rows:
    print(f"No XMDB entries in the last {hours} hours.")
    sys.exit(0)

# Group by type
by_type = {}
for r in rows:
    t = r["type"] or "note"
    if t not in by_type:
        by_type[t] = []
    content = r["content"]
    # Strip type prefix if present
    for prefix in ["[note]", "[decision]", "[task]", "[event]", "[insight]"]:
        if content.lower().startswith(prefix):
            content = content[len(prefix):].strip()
            break
    observed = r["observed_at"] or ""
    if observed:
        try:
            dt = datetime.fromisoformat(observed.replace("Z", "+00:00"))
            observed = dt.strftime("%m/%d %H:%M")
        except:
            observed = observed[:16]
    by_type[t].append({"content": content, "time": observed})

# Display order
type_order = ["decision", "task", "insight", "event", "note"]
type_emoji = {
    "decision": "⚡", "task": "📋", "insight": "💡",
    "event": "📅", "note": "📝"
}

print(f"═══ XMDB Briefing ({hours}h) — {len(rows)} entries ═══\n")

for t in type_order:
    if t not in by_type:
        continue
    items = by_type[t]
    emoji = type_emoji.get(t, "•")
    print(f"{emoji} {t.upper()}S ({len(items)})")
    for item in items[:10]:  # Cap at 10 per type
        time_str = f" [{item['time']}]" if item["time"] else ""
        snippet = item["content"][:200]
        print(f"  • {snippet}{time_str}")
    if len(items) > 10:
        print(f"  ... and {len(items) - 10} more")
    print()

# Also show any other types not in the standard list
for t, items in by_type.items():
    if t not in type_order:
        print(f"• {t.upper()} ({len(items)})")
        for item in items[:5]:
            print(f"  • {item['content'][:200]}")
        print()

conn.close()
PYEOF
