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

## Release and update workflow
After changing the repo and pushing to `main`, publish a new GitHub release/tag so `skills` users can pick up the new version cleanly.

### Recommended workflow
```bash
git add .
git commit -m "Describe the change"
git push origin main

git tag v0.1.1
git push origin v0.1.1
gh release create v0.1.1 --title "v0.1.1" --notes "Describe the changes"
```

Then update installed copies on machines using the skills CLI:

```bash
npx skills update
```

If you only want to verify availability first:

```bash
npx skills check
```

## Notes
- Keep machine-specific automation and policy logic out of the public skill unless it is portable.
- If installed skill content seems stale after pushing to `main`, cut a new release/tag and then run `npx skills update`.
