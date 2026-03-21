---
name: usage-monitor
description: Monitor Claude Code and Codex subscription usage, compare weekly burn against expected pace, and recommend provider routing or workload bias. Use when checking Claude or Codex limits, weekly budget pacing, reset windows, provider headroom, underused ChatGPT/Codex capacity, whether to switch work from Claude to Codex, or whether automations/research/background tasks should favor the less-used provider.
---

# Usage Monitor

Fetch live Claude Code and Codex rate-limit data via CodexBar and report whether usage is healthy, ahead of pace, or approaching a cap.

## Dependency

[CodexBar](https://codexbar.app/) CLI: `brew install --cask steipete/tap/codexbar`

## Fetch usage

```bash
codexbar --provider all --format json --pretty
```

Single provider:
```bash
codexbar --provider claude --format json --pretty
codexbar --provider codex --format json --pretty
```

CodexBar handles auth internally (browser cookies, CLI sessions, OAuth). No tokens or credentials needed.

## JSON field reference

**Claude** (`.[] | select(.provider == "claude")`):
- `.usage.primary.usedPercent` → 5-hour session %
- `.usage.secondary.usedPercent` → weekly %
- `.usage.tertiary.usedPercent` → weekly Sonnet % (null when N/A)
- `.usage.primary.resetsAt` → session reset ISO timestamp
- `.usage.secondary.resetsAt` → weekly reset ISO timestamp
- `.usage.identity.loginMethod` → plan name (e.g. "Claude Max")
- `.usage.providerCost.used` / `.usage.providerCost.limit` → monthly cost

**Codex** (`.[] | select(.provider == "codex")`):
- `.openaiDashboard.primaryLimit.usedPercent` → 5-hour session %
- `.openaiDashboard.secondaryLimit.usedPercent` → weekly %
- `.openaiDashboard.secondaryLimit.resetsAt` → weekly reset ISO timestamp
- `.openaiDashboard.accountPlan` → plan name (e.g. "Plus")
- `.credits.remaining` → credits remaining

## Reporting

When reporting, cover:
- Claude and Codex short-window usage
- Claude and Codex weekly usage
- Weekly reset times
- Whether weekly usage is ahead of, on, or behind pace
- Whether one provider has enough spare headroom to bias more work there
- Whether short-window pressure is temporary or part of a larger weekly budget problem

## Weekly pacing

Calculate expected usage as `(elapsed_hours / 168) * 100` using the actual reset timestamp.

- **ok**: within ~5% of expected pace
- **warning**: 5–20% ahead of expected pace
- **over**: >20% ahead of expected pace
- **under**: >10% behind expected pace

## Short-window usage

Treat 5-hour pressure as operational, not strategic.
- High session + healthy weekly → wait or use fallback
- High session + high weekly → switch work to the provider with more headroom

## Codex underuse bias

If Codex weekly is low while Claude is running hot, recommend routing appropriate work to Codex:
- Research, summaries, background analysis
- Low-risk automations, recurring monitoring
- Exploratory or one-shot work

This is a **bias**, not a universal forced switch.

## Trends

For historical trends, inspect the usage log:
```bash
tail -10 ~/.claude/usage-log.json | jq -s '.'
```

If history is sparse, say so plainly.

## Privacy

- CodexBar reuses existing browser cookies — no passwords stored
- Do not print tokens or copy auth files
- Do not send usage data to third-party services
