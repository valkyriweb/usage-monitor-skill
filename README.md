# usage-monitor-skill

Portable `usage-monitor` skill for Claude Code, Codex, and OpenClaw.

## What it does
- Reads live Claude Code usage from Anthropic OAuth usage API
- Reads live Codex usage from Codex app-server `account/rateLimits/read`
- Falls back to recent Codex session JSONL only if app-server rate-limit RPC fails
- Logs snapshots to `~/.claude/usage-log.json`
- Helps agents decide when to bias work toward Claude vs Codex

## Install with skills CLI

### Claude Code / Codex global install
```bash
npx skills add <owner>/usage-monitor-skill -g -a claude-code -a codex -s usage-monitor
```

### OpenClaw project install
Run inside the OpenClaw workspace:
```bash
npx skills add <owner>/usage-monitor-skill -a openclaw -s usage-monitor
```

By default the skills CLI prefers symlinks, which is the recommended mode.
Use `--copy` only if symlinks are not supported.

## Structure
- `skills/usage-monitor/SKILL.md`
- `skills/usage-monitor/scripts/usage-check.sh`
- `skills/usage-monitor/scripts/codex-usage-scrape.py`

## Privacy
This repo contains no embedded tokens, credentials, account ids, email addresses, or machine-specific secrets.
It reads the local authenticated Claude/Codex session state at runtime from standard user locations.
