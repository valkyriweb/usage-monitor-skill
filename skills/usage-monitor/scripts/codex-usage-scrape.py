#!/usr/bin/env python3
"""
Codex usage reader.

Primary source:
- Call the local Codex app-server JSON-RPC method `account/rateLimits/read`
  using the user's existing ChatGPT/Codex auth.

Fallback source:
- Parse recent ~/.codex/sessions rollout JSONL files for the last usable
  token_count/rate_limits snapshot.

Returns JSON to stdout.
"""
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def unix_to_iso(ts):
    try:
        return datetime.fromtimestamp(int(ts), tz=timezone.utc).isoformat()
    except Exception:
        return ""


def age_description(recorded_at_iso):
    try:
        recorded = datetime.fromisoformat(recorded_at_iso.replace("Z", "+00:00"))
        delta = datetime.now(timezone.utc) - recorded
        hours = int(delta.total_seconds() // 3600)
        if hours < 1:
            return "just now"
        if hours < 24:
            return f"{hours}h ago"
        days = hours // 24
        return f"{days}d ago"
    except Exception:
        return ""


def normalize_rate_limits(rate_limits, source, recorded_at=""):
    primary = rate_limits.get("primary") or {}
    secondary = rate_limits.get("secondary") or {}
    credits = rate_limits.get("credits") or {}
    return {
        "ok": True,
        "source": source,
        "limit_id": rate_limits.get("limitId") or rate_limits.get("limit_id") or "",
        "limit_name": rate_limits.get("limitName") or rate_limits.get("limit_name") or "",
        "plan_type": rate_limits.get("planType") or rate_limits.get("plan_type") or "",
        "five_hour_pct": round(primary.get("usedPercent", primary.get("used_percent", 0)) or 0),
        "weekly_pct": round(secondary.get("usedPercent", secondary.get("used_percent", 0)) or 0),
        "five_hour_window_mins": primary.get("windowDurationMins", primary.get("window_minutes", 0)) or 0,
        "weekly_window_mins": secondary.get("windowDurationMins", secondary.get("window_minutes", 0)) or 0,
        "five_hour_resets_at": unix_to_iso(primary.get("resetsAt", primary.get("resets_at", 0)) or 0),
        "weekly_resets_at": unix_to_iso(secondary.get("resetsAt", secondary.get("resets_at", 0)) or 0),
        "credits": {
            "has_credits": bool(credits.get("hasCredits", credits.get("has_credits", False))),
            "unlimited": bool(credits.get("unlimited", False)),
            "balance": str(credits.get("balance", "0")),
        },
        "recorded_at": recorded_at or datetime.now(timezone.utc).isoformat(),
        "recorded_age": age_description(recorded_at) if recorded_at else "just now",
    }


def fetch_from_app_server():
    script = r'''
import json, subprocess, selectors, time, sys
p=subprocess.Popen(['codex','app-server','--listen','stdio://'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
sel=selectors.DefaultSelector()
sel.register(p.stdout, selectors.EVENT_READ)

def send(obj):
    p.stdin.write(json.dumps(obj)+'\n')
    p.stdin.flush()

def wait_for_id(target_id, timeout=10):
    end=time.time()+timeout
    while time.time()<end:
        events=sel.select(timeout=0.5)
        for key,_ in events:
            line=key.fileobj.readline()
            if not line:
                continue
            try:
                obj=json.loads(line)
            except Exception:
                continue
            if obj.get('id') == target_id:
                print(json.dumps(obj))
                return 0
    return 1

send({'jsonrpc':'2.0','id':1,'method':'initialize','params':{'clientInfo':{'name':'usage-probe','version':'0.1'},'capabilities':{},'profile':'default'}})
if wait_for_id(1, timeout=5) != 0:
    p.terminate()
    sys.exit(10)
send({'jsonrpc':'2.0','id':2,'method':'account/rateLimits/read','params':{}})
rc = wait_for_id(2, timeout=10)
p.terminate()
sys.exit(rc)
'''
    proc = subprocess.run(["python3", "-c", script], capture_output=True, text=True, timeout=20)
    if proc.returncode != 0:
        return None, f"app-server rpc failed (exit {proc.returncode})"
    out = (proc.stdout or "").strip().splitlines()
    if not out:
        return None, "app-server rpc returned no output"
    try:
        response = json.loads(out[-1])
    except Exception as exc:
        return None, f"failed to parse app-server rpc response: {exc}"
    result = response.get("result") or {}
    rate_limits = result.get("rateLimits") or {}
    if not isinstance(rate_limits, dict) or not rate_limits:
        return None, "app-server returned empty rateLimits"
    return normalize_rate_limits(rate_limits, source="codex-app-server"), None


def find_latest_token_count():
    base = Path.home() / ".codex" / "sessions"
    if not base.exists():
        return None, None, "~/.codex/sessions not found"

    candidates = list(base.rglob("rollout-*.jsonl"))
    if not candidates:
        return None, None, "no rollout-*.jsonl files found"

    candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    newest_timestamp = None
    saw_token_count = False

    for path in candidates:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                for line in fh:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                    except json.JSONDecodeError:
                        continue

                    payload = obj.get("payload", {})
                    if payload.get("type") != "token_count":
                        continue

                    saw_token_count = True
                    newest_timestamp = newest_timestamp or obj.get("timestamp")
                    rl = payload.get("rate_limits")
                    if not isinstance(rl, dict):
                        continue

                    primary = rl.get("primary")
                    secondary = rl.get("secondary")
                    if isinstance(primary, dict) and isinstance(secondary, dict):
                        return rl, obj.get("timestamp"), None
        except OSError:
            continue

    if saw_token_count:
        return None, newest_timestamp, "token_count records found but Codex did not include usable rate limit data"

    return None, None, "no token_count records found in recent session files"


def fetch_from_jsonl_fallback():
    rate_limits, recorded_at, err = find_latest_token_count()
    if rate_limits is None:
        return None, err, recorded_at or ""
    return normalize_rate_limits(rate_limits, source="codex-jsonl-fallback", recorded_at=recorded_at or ""), None, recorded_at or ""


def main():
    app_result, app_err = fetch_from_app_server()
    if app_result is not None:
        print(json.dumps(app_result))
        return

    fallback_result, fallback_err, recorded_at = fetch_from_jsonl_fallback()
    if fallback_result is not None:
        fallback_result["warning"] = f"app-server unavailable: {app_err}"
        print(json.dumps(fallback_result))
        return

    print(json.dumps({
        "ok": False,
        "source": "none",
        "error": app_err or fallback_err or "unknown error",
        "fallback_error": fallback_err or "",
        "recorded_at": recorded_at,
        "recorded_age": age_description(recorded_at) if recorded_at else "",
    }))
    sys.exit(0)


if __name__ == "__main__":
    main()
