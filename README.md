# usage-monitor-skill

Portable `usage-monitor` skill for Claude Code, Codex, and OpenClaw.

## What it does
- Reads live Claude Code usage from the Anthropic OAuth usage API
- Reads live Codex usage from Codex app-server `account/rateLimits/read`
- Falls back to recent Codex session JSONL only if the Codex app-server rate-limit RPC fails
- Logs usage snapshots locally for trend analysis
- Helps agents compare weekly burn, reset windows, provider headroom, and underused capacity

## Install with skills CLI

### Global install for Claude Code and Codex
```bash
npx skills add <owner>/usage-monitor-skill -g -a claude-code -a codex -s usage-monitor
```

### Project install for OpenClaw
Run inside the target OpenClaw workspace:
```bash
npx skills add <owner>/usage-monitor-skill -a openclaw -s usage-monitor
```

By default the skills CLI prefers symlinks, which is the recommended mode.
Use `--copy` only if symlinks are not supported in your environment.

## Structure
- `skills/usage-monitor/SKILL.md`
- `skills/usage-monitor/scripts/usage-check.sh`
- `skills/usage-monitor/scripts/codex-usage-scrape.py`

## Privacy
This repo contains no embedded tokens, credentials, account ids, email addresses, or machine-specific secrets.
It reads the user's existing local Claude/Codex authentication state at runtime from standard local locations.

## Release and update workflow
After changing the repo and pushing to `main`, publish a new GitHub release/tag so `skills` users can pick up the new version cleanly.

### Recommended workflow
```bash
git add .
git commit -m "Describe the change"
git push origin main

git tag v0.1.2
git push origin v0.1.2
gh release create v0.1.2 --title "v0.1.2" --notes "Describe the changes"
```

Then refresh installed copies with the skills CLI:

```bash
npx skills update
```

If you want to check first:

```bash
npx skills check
```

If installed skill content still appears stale after a new release, remove and reinstall the skill from source:

```bash
npx skills remove usage-monitor --all -y
npx skills add <owner>/usage-monitor-skill --all
```

Adjust agent/scope flags as needed for your environment.

## Notes
- Keep environment-specific automation and policy logic out of the public skill unless it is portable.
- Prefer the Codex app-server RPC as the canonical Codex source; treat JSONL as fallback only.
- If you maintain multiple agent environments, verify symlinks and installed content after updates.
