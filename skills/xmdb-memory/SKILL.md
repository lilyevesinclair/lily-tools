---
name: xmdb-memory
description: XMDB memory system — recall, write, briefing, and daily log. Use for all memory operations including remembering things, searching past context, daily briefings, and writing decisions/insights/tasks.
---

# XMDB Memory

XMDB is your primary memory system. Use it for all recall, writing, briefings, and daily logs.

## Tools

### Recall (search memory)
```bash
~/bin/recall "query" [limit]
```
Hybrid FTS + vector search. Returns JSON with snippets, sources, scores.

Options:
- `~/bin/recall --explain "query"` — show scoring breakdown
- `~/bin/recall --fallback=file "query"` — also search markdown files

### Write (store memory)
```bash
~/bin/xmdb-write "text" [--type TYPE] [--tag TAG]...
```
Types: `note` (default), `decision`, `task`, `event`, `insight`

Examples:
```bash
~/bin/xmdb-write "Will prefers direct communication, no fluff" --type insight
~/bin/xmdb-write "Decided to use Gemini 2.5 Pro for escalation" --type decision --tag xmdb --tag benchmark
~/bin/xmdb-write "Need to build XMDB product page" --type task --tag toku
```

### Briefing (48h executive summary)
```bash
~/clawd/skills/xmdb-memory/scripts/briefing.sh [hours]
```
Returns recent items grouped by type from the last N hours (default: 48).

### Today (daily log view)
```bash
~/clawd/skills/xmdb-memory/scripts/today.sh
```
Returns all items written today, chronologically.

## Session Startup

At session start, run briefing instead of reading MEMORY.md:
```bash
~/clawd/skills/xmdb-memory/scripts/briefing.sh 48
```

## Writing Guidelines

- **Every significant decision** → `xmdb-write "..." --type decision`
- **Every new task** → `xmdb-write "..." --type task`
- **Lessons learned** → `xmdb-write "..." --type insight`
- **Notable events** → `xmdb-write "..." --type event`
- **General context** → `xmdb-write "..." --type note`
- Include relevant tags for easier retrieval later
- Write in natural language — the embedding model handles semantics

## Flywheel

Weekly: `cd ~/xmdb && make eval` — gate: ≥80% Recall@3, ≤500ms.
After eval, record result: `xmdb-write "Eval: X% Recall@3, Yms" --type event --tag flywheel`
