#!/usr/bin/env bash
# usage-check.sh — Fetch Claude + Codex usage, log to ~/.claude/usage-log.json, print summary.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/.claude/usage-log.json"
SCRAPER="$SCRIPT_DIR/codex-usage-scrape.py"

mkdir -p "$(dirname "$LOG_FILE")"

get_claude_token() {
    local token
    token=$(security find-generic-password \
        -s "Claude Code-credentials" \
        -a "$(whoami)" \
        -w 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['claudeAiOauth']['accessToken'])" \
    2>/dev/null) || true

    if [[ -n "$token" ]]; then
        echo "$token"
        return
    fi

    python3 - <<'PY' 2>/dev/null
import json, os
path = os.path.expanduser('~/.claude/.credentials.json')
with open(path) as f:
    print(json.load(f)['claudeAiOauth']['accessToken'])
PY
}

fetch_claude_usage() {
    local token
    token=$(get_claude_token) || { echo '{"error":"keychain_unavailable"}'; return; }

    curl -sf "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "User-Agent: claude-code/2.1.74" \
        -H "anthropic-beta: oauth-2025-04-20" \
    || echo '{"error":"api_request_failed"}'
}

fetch_codex_usage() {
    if [[ -f "$SCRAPER" ]]; then
        python3 "$SCRAPER" 2>/dev/null || echo '{"error":"scraper_failed","ok":false}'
    else
        echo '{"error":"scraper_not_found","ok":false}'
    fi
}

compute_budget() {
    local weekly_pct=$1
    local weekly_resets_at=$2

    python3 - <<PYEOF
import json
from datetime import datetime, timezone

weekly_pct = $weekly_pct
weekly_resets_at = "$weekly_resets_at"
now = datetime.now(timezone.utc)
day_name = now.strftime('%A')

targets = {
    'Monday': 15, 'Tuesday': 15, 'Wednesday': 15,
    'Thursday': 15, 'Friday': 15, 'Saturday': 15, 'Sunday': 10
}
daily_target = targets.get(day_name, 15)

days_until_reset = 1
try:
    reset_dt = datetime.fromisoformat(weekly_resets_at.replace('Z', '+00:00'))
    delta = reset_dt - now
    days_until_reset = max(1, round(delta.total_seconds() / 86400))
except Exception:
    pass

days_elapsed = max(1, 7 - days_until_reset)
expected_pct = daily_target * days_elapsed
remaining_budget = 100 - weekly_pct
status = 'ok'
if weekly_pct > expected_pct + 20:
    status = 'over'
elif weekly_pct > expected_pct + 5:
    status = 'warning'

print(json.dumps({
    'day_of_week': day_name,
    'days_until_reset': days_until_reset,
    'claude_daily_target_pct': daily_target,
    'claude_remaining_budget_pct': remaining_budget,
    'claude_status': status,
}))
PYEOF
}

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; BOLD='\033[1m'; NC='\033[0m'
status_color() {
    case "$1" in
        over) echo -e "${RED}" ;;
        warning) echo -e "${YELLOW}" ;;
        *) echo -e "${GREEN}" ;;
    esac
}

main() {
    echo -e "${BOLD}Fetching usage data...${NC}"

    local claude_json codex_json
    claude_json=$(fetch_claude_usage)
    codex_json=$(fetch_codex_usage)

    local session_pct weekly_pct weekly_sonnet_pct weekly_resets_at
    session_pct=$(echo "$claude_json" | jq -r '.five_hour.utilization // 0' | python3 -c "import sys; print(round(float(sys.stdin.read().strip())))")
    weekly_pct=$(echo "$claude_json" | jq -r '.seven_day.utilization // 0' | python3 -c "import sys; print(round(float(sys.stdin.read().strip())))")
    weekly_sonnet_pct=$(echo "$claude_json" | jq -r '.seven_day_sonnet.utilization // 0' | python3 -c "import sys; print(round(float(sys.stdin.read().strip())))")
    weekly_resets_at=$(echo "$claude_json" | jq -r '.seven_day.resets_at // ""')

    local codex_5h_pct codex_weekly_pct codex_5h_resets codex_weekly_resets codex_age codex_source codex_plan codex_warning
    codex_5h_pct=$(echo "$codex_json" | jq -r '.five_hour_pct // 0')
    codex_weekly_pct=$(echo "$codex_json" | jq -r '.weekly_pct // 0')
    codex_5h_resets=$(echo "$codex_json" | jq -r '.five_hour_resets_at // ""')
    codex_weekly_resets=$(echo "$codex_json" | jq -r '.weekly_resets_at // ""')
    codex_age=$(echo "$codex_json" | jq -r '.recorded_age // ""')
    codex_source=$(echo "$codex_json" | jq -r '.source // "unknown"')
    codex_plan=$(echo "$codex_json" | jq -r '.plan_type // ""')
    codex_warning=$(echo "$codex_json" | jq -r '.warning // empty')

    local budget_json
    budget_json=$(compute_budget "$weekly_pct" "$weekly_resets_at")
    local day_name days_until daily_target remaining_budget claude_status
    day_name=$(echo "$budget_json" | jq -r '.day_of_week')
    days_until=$(echo "$budget_json" | jq -r '.days_until_reset')
    daily_target=$(echo "$budget_json" | jq -r '.claude_daily_target_pct')
    remaining_budget=$(echo "$budget_json" | jq -r '.claude_remaining_budget_pct')
    claude_status=$(echo "$budget_json" | jq -r '.claude_status')

    local codex_status="ok"
    if [[ "$codex_weekly_pct" -gt 80 ]]; then codex_status="over"
    elif [[ "$codex_weekly_pct" -gt 60 ]]; then codex_status="warning"
    fi
    local codex_remaining=$((100 - codex_weekly_pct))

    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD} Usage Report — $day_name, $ts${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BOLD}Claude:${NC}"
    echo -e "  5-hour session:   ${session_pct}%"
    echo -e "  Weekly (all):     $(status_color "$claude_status")${weekly_pct}%${NC}  (resets in ${days_until}d, limit reset: $weekly_resets_at)"
    echo -e "  Weekly (Sonnet):  ${weekly_sonnet_pct}%"
    echo -e "  Daily target:     ${daily_target}%/day  |  Remaining budget: ${remaining_budget}%"
    echo -e "  Status:           $(status_color "$claude_status")$(echo "$claude_status" | tr '[:lower:]' '[:upper:]')${NC}"
    echo ""

    local codex_header="${BOLD}Codex:${NC}"
    [[ -n "$codex_plan" ]] && codex_header="${BOLD}Codex${NC} ${GREEN}($codex_plan)${NC}${BOLD}:${NC}"
    if [[ "$codex_source" != "codex-app-server" && -n "$codex_age" ]]; then
        codex_header="${BOLD}Codex${NC} ${YELLOW}(fallback, as of $codex_age)${NC}${BOLD}:${NC}"
    fi
    echo -e "$codex_header"
    if echo "$codex_json" | jq -e '.ok == false' >/dev/null 2>&1; then
        local codex_err
        codex_err=$(echo "$codex_json" | jq -r '.error // "unknown error"')
        echo -e "  ${YELLOW}Unavailable: $codex_err${NC}"
    else
        echo -e "  Source:           $codex_source"
        echo -e "  5-hour session:   ${codex_5h_pct}%  (resets: $codex_5h_resets)"
        echo -e "  Weekly:           $(status_color "$codex_status")${codex_weekly_pct}%${NC}  (resets: $codex_weekly_resets)"
        echo -e "  Remaining budget: ${codex_remaining}%"
        echo -e "  Status:           $(status_color "$codex_status")$(echo "$codex_status" | tr '[:lower:]' '[:upper:]')${NC}"
        [[ -n "$codex_warning" ]] && echo -e "  Note:             ${YELLOW}$codex_warning${NC}"
    fi
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local log_entry
    log_entry=$(python3 - <<PYEOF
import json, datetime

ts = datetime.datetime.now(datetime.timezone.utc).astimezone().isoformat()
entry = {
    'timestamp': ts,
    'claude': {
        'session_pct': $session_pct,
        'weekly_pct': $weekly_pct,
        'weekly_sonnet_pct': $weekly_sonnet_pct,
        'weekly_resets_at': '$weekly_resets_at'
    },
    'codex': {
        'source': '$codex_source',
        'plan_type': '$codex_plan',
        'warning': '$codex_warning',
        'five_hour_pct': $codex_5h_pct,
        'weekly_pct': $codex_weekly_pct,
        'five_hour_resets_at': '$codex_5h_resets',
        'weekly_resets_at': '$codex_weekly_resets'
    },
    'budget': {
        'day_of_week': '$day_name',
        'days_until_reset': $days_until,
        'claude_daily_target_pct': $daily_target,
        'claude_remaining_budget_pct': $remaining_budget,
        'claude_status': '$claude_status',
        'codex_daily_target_pct': $daily_target,
        'codex_remaining_budget_pct': $codex_remaining,
        'codex_status': '$codex_status'
    }
}
print(json.dumps(entry))
PYEOF
)

    echo "$log_entry" >> "$LOG_FILE"
    echo -e "  Logged to: $LOG_FILE"
    echo ""
}

main "$@"
