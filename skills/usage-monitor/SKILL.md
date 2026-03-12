---
name: usage-monitor
description: Monitor Claude Code and Codex usage, compare weekly burn against ideal pace, and recommend provider routing. Use when checking subscription limits, weekly budget pacing, reset windows, provider headroom, or whether to shift work between Claude and Codex.
---

# Usage Monitor

Use the bundled script to fetch live Claude Code and Codex rate-limit data, log snapshots, and print a clean summary.

## Run the monitor

From the skill directory, run:

```bash
scripts/usage-check.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
```

The script:
- fetches **Claude Code** usage from Anthropic OAuth usage API using the locally authenticated Claude Code session
- fetches **Codex** usage from Codex app-server `account/rateLimits/read` using the locally authenticated ChatGPT/Codex session
- falls back to recent Codex JSONL session snapshots only if app-server rate-limit RPC fails
- appends a JSONL snapshot to `~/.claude/usage-log.json`

## Trend analysis

For trends, inspect recent entries:

```bash
tail -10 ~/.claude/usage-log.json | jq -s '.'
```

When reporting, cover:
- current short-window usage for Claude and Codex
- weekly usage for Claude and Codex
- weekly reset times
- whether weekly usage is ahead of, on, or behind pace
- whether one provider has enough spare headroom to bias more work there

## Interpretation rules

### Weekly pacing
Treat the weekly window as the main budget constraint.

Default guidance:
- **ok**: within roughly 5% of expected pace
- **warning**: around 5–20% ahead of expected pace
- **over**: more than 20% ahead of expected pace

Use actual reset timestamps when available instead of assuming neat calendar boundaries.

### Short-window usage
Treat short-window / 5-hour pressure as an operational signal, not the primary strategic one.
- If short-window usage is high but weekly budget is healthy, fallback chains may be enough.
- If weekly usage is high, recommend switching more work to the provider with more headroom.

### Codex underuse bias
If Codex weekly usage is very low, stale, or clearly underused while Claude is running hot, recommend routing extra work to Codex:
- research
- summaries
- background analysis
- low-risk automations
- recurring monitoring tasks

## Privacy / safety
This skill must not contain embedded credentials, account ids, email addresses, tokens, or machine-specific secrets.
It should only read auth material from the user's normal local Claude/Codex login state at runtime.

## Notes
- Prefer the bundled scripts over ad-hoc scraping.
- Codex app-server RPC is the canonical Codex source; JSONL is fallback only.
- Keep the skill portable across machines by using `$HOME` and runtime discovery instead of hardcoded absolute user paths.
