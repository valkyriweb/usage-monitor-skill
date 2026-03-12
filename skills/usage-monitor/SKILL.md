---
name: usage-monitor
description: Monitor Claude Code and Codex subscription usage, compare weekly burn against expected pace, and recommend provider routing or workload bias. Use when checking Claude or Codex limits, weekly budget pacing, reset windows, provider headroom, underused ChatGPT/Codex capacity, whether to switch work from Claude to Codex, or whether automations/research/background tasks should favor the less-used provider.
---

# Usage Monitor

Use the bundled scripts to fetch live Claude Code and Codex rate-limit data, log snapshots, and report whether usage is healthy, ahead of pace, or approaching a cap.

## Run the monitor

From the skill directory, run:

```bash
scripts/usage-check.sh 2>&1 | sed 's/\x1b\[[0-9;]*m//g'
```

The script:
- fetches **Claude Code** usage from Anthropic OAuth usage API using the locally authenticated Claude Code session
- fetches **Codex** usage from Codex app-server `account/rateLimits/read` using the locally authenticated ChatGPT/Codex session
- falls back to recent Codex JSONL session snapshots only if the app-server rate-limit RPC fails
- appends a JSONL snapshot to `~/.claude/usage-log.json`

## Reporting

When reporting, cover:
- Claude short-window usage
- Claude weekly usage
- Codex short-window usage
- Codex weekly usage
- weekly reset times
- whether weekly usage is ahead of, on, or behind pace
- whether one provider has enough spare headroom to bias more work there
- whether short-window pressure is only a temporary operational issue or part of a larger weekly budget problem

For trends, inspect recent entries:

```bash
tail -10 ~/.claude/usage-log.json | jq -s '.'
```

If history is sparse, say so plainly instead of pretending there is a reliable trend.

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
- If short-window usage is high but weekly budget is healthy, fallback chains or brief waiting may be enough.
- If weekly usage is also high, recommend switching more work to the provider with more headroom.

### Codex underuse bias
If Codex weekly usage is very low, stale, or clearly underused while Claude is running hot, recommend routing appropriate extra work to Codex:
- research
- summaries
- background analysis
- low-risk automations
- recurring monitoring tasks
- exploratory or one-shot work

Treat this as a **bias**, not a universal forced switch.

## Source of truth and fallback order
- **Claude:** Anthropic OAuth usage API
- **Codex primary:** Codex app-server RPC
- **Codex fallback:** recent local JSONL session snapshots

Do not treat Codex JSONL as the canonical source when app-server data is available.

## Failure handling
If one provider cannot be read:
- report that clearly
- keep the last-known or fallback data separate from live data
- do not overstate confidence
- continue reporting the other provider if it is available

## Privacy and security
This skill must not contain embedded credentials, account ids, email addresses, tokens, refresh tokens, or machine-specific secrets.

Allowed behavior:
- read the user's existing local Claude/Codex login state at runtime
- call the Anthropic OAuth usage endpoint for the locally authenticated user
- call the local Codex app-server RPC for the locally authenticated user
- read local Codex session JSONL only as fallback
- append usage snapshots to the user's local log file

Do not:
- print tokens
- copy auth files into the repo
- send usage data to third-party services
- hardcode private absolute user paths into the published skill
- broaden scope into generic shell/network automation unrelated to usage monitoring

## Portability
Keep the skill portable across machines by using `$HOME`, relative script paths, and runtime discovery instead of hardcoded machine-specific paths.

## Notes
- Prefer the bundled scripts over ad-hoc scraping.
- Keep output structured and explicit enough that a separate policy layer can consume it later.
- If the user asks for automatic switching or policy decisions, use this skill as the telemetry layer rather than mixing policy logic into fragile ad-hoc commands.
