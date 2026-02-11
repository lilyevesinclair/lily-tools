#!/usr/bin/env bash
# today.sh — XMDB daily log view
# Shows all items written today, chronologically
set -euo pipefail

XMDB_DB="$HOME/xmdb-data/xmdb.sqlite"

if [ ! -f "$XMDB_DB" ]; then
  echo "Error: XMDB database not found at $XMDB_DB" >&2
  exit 1
fi

python3 - "$XMDB_DB" << 'PYEOF'
import sqlite3
import sys
from datetime import datetime, timezone

db_path = sys.argv[1] if len(sys.argv) > 1 else ""
today = datetime.now().strftime("%Y-%m-%d")

conn = sqlite3.connect(db_path or f"{__import__('os').environ['HOME']}/xmdb-data/xmdb.sqlite")
conn.row_factory = sqlite3.Row

rows = conn.execute("""
    SELECT content, type, source_kind, observed_at
    FROM memory_items
    WHERE source_kind = 'lily-session'
      AND observed_at LIKE ? || '%'
    ORDER BY observed_at ASC
""", (today,)).fetchall()

if not rows:
    print(f"No XMDB entries for {today}.")
    sys.exit(0)

type_emoji = {
    "decision": "⚡", "task": "📋", "insight": "💡",
    "event": "📅", "note": "📝"
}

print(f"═══ XMDB Daily Log — {today} — {len(rows)} entries ═══\n")

for r in rows:
    t = r["type"] or "note"
    emoji = type_emoji.get(t, "•")
    content = r["content"]
    # Strip type prefix
    for prefix in ["[note]", "[decision]", "[task]", "[event]", "[insight]"]:
        if content.lower().startswith(prefix):
            content = content[len(prefix):].strip()
            break
    observed = r["observed_at"] or ""
    time_str = ""
    if observed:
        try:
            dt = datetime.fromisoformat(observed.replace("Z", "+00:00"))
            time_str = dt.strftime("%H:%M")
        except:
            time_str = observed[11:16]
    print(f"  {time_str} {emoji} [{t}] {content[:300]}")

conn.close()
PYEOF
