#!/bin/zsh
# Claude 5-hour-window auto-starter + stalled-session nudger.
# Runs from launchd every 10 minutes (com.arthur.claude-auto-window).
#
# Step 1 (ping): send a tiny "Hi" on Sonnet low effort so a fresh 5-hour
#   usage window starts the moment one is available, even overnight.
# Step 2 (nudge): DISABLED as of 2026-08-20 (NUDGE=0 below). Claude Code
#   2.1.234 ships its own auto-continue after a usage limit; we are running on
#   that alone to see whether it covers every case this watcher used to.
#   The code and nudge-one.sh stay in place: set NUDGE=1 to bring it back.
#   When on: after a limited->ok transition it finds sessions whose transcript
#   ends on a usage-limit error and says "continue" to them (SendMessage for
#   live sessions, --bg --resume for dead ones).

set -u
CLAUDE="$HOME/.local/bin/claude"
DIR="$HOME/.claude/auto-window"
STATE="$DIR/state"            # last observed state: ok | limited
NUDGE=0                       # 1 = revive stalled sessions ourselves;
                              # 0 = leave it to Claude Code's built-in
                              #     auto-continue (2.1.234+)
NUDGED="$DIR/nudged.log"      # "session_id epoch" lines; never nudge twice within 6h
LOG="$DIR/logs/watch.log"
PROJECTS="$HOME/.claude/projects"
# Strings that mean "blocked by the usage limit". Adjust if the CLI wording
# changes (check the tail of a limited session's .jsonl). In transcripts the
# real event is an entry with "isApiErrorMessage":true carrying this text
# (observed form: "You've hit your session limit · resets 11:50pm").
LIMIT_RE='hit your session limit|usage limit reached|5-hour limit reached|out of usage'

ts() { date '+%Y-%m-%d %H:%M:%S' }
log() { echo "$(ts) $*" >> "$LOG" }
touch "$NUDGED"

# ---- Step 1: ping ---------------------------------------------------------
cd "$DIR/pingcwd"
PING_OUT=$("$CLAUDE" -p "Hi" --model sonnet --effort low 2>&1)
PING_RC=$?

if echo "$PING_OUT" | grep -qiE "$LIMIT_RE"; then
  echo limited > "$STATE"
  log "ping: LIMITED (window not reset yet)"
  exit 0
fi

if [[ $PING_RC -ne 0 ]]; then
  log "ping: error rc=$PING_RC: $(echo "$PING_OUT" | head -c 300)"
  exit 0
fi

PREV=$(cat "$STATE" 2>/dev/null || echo unknown)
echo ok > "$STATE"
log "ping: OK (prev=$PREV) — window active"

# ---- Step 2: nudge stalled sessions --------------------------------------
# Off by default: Claude Code 2.1.234+ auto-continues limit-stalled sessions
# itself, and two nudges racing on one session is worse than none.
if (( ! NUDGE )); then
  [[ "$PREV" == limited ]] && log "nudge: skipped (NUDGE=0; built-in auto-continue owns this)"
  exit 0
fi

# Only right after a limited→ok transition; otherwise nothing to revive.
[[ "$PREV" == limited ]] || exit 0
log "nudge: scanning for sessions stopped at the usage limit"

NOW=$(date +%s)
RUNNING_JSON=$("$CLAUDE" agents --json 2>/dev/null || echo '[]')

# Top-level session transcripts modified in the last 12h (not subagent files).
find "$PROJECTS" -maxdepth 2 -name '*.jsonl' -mmin -720 2>/dev/null | while read -r f; do
  sid="${${f:t}%.jsonl}"

  # Skip if nudged in the last 45 min. Short on purpose: a session nudged in
  # one window can stall again in the next, and a 5h window must never be
  # blanket-covered by a stale dedup entry.
  last=$(awk -v s="$sid" '$1==s {t=$2} END{print t+0}' "$NUDGED")
  (( NOW - last < 2700 )) && continue

  # Stalled = one of the final transcript entries is an API-error message
  # carrying the limit text. Requiring isApiErrorMessage on the same line
  # keeps mere conversational mentions of "usage limit" from triggering.
  # 25 lines because queued messages / system / task_reminder entries pile
  # up after the limit error while the session sits blocked.
  tail -n 25 "$f" | LC_ALL=C grep -a '"isApiErrorMessage":true' \
    | LC_ALL=C grep -qiE "$LIMIT_RE" || continue

  cwd=$(head -c 4000 "$f" | LC_ALL=C grep -ao '"cwd":"[^"]*"' | head -1 | sed 's/"cwd":"//;s/"$//')
  [[ -z "$cwd" ]] && cwd=$(tail -n 50 "$f" | LC_ALL=C grep -ao '"cwd":"[^"]*"' | tail -1 | sed 's/"cwd":"//;s/"$//')
  # The watcher's own "Hi" pings during a limited period also end on a limit
  # error — never nudge those.
  [[ "$cwd" == "$DIR/pingcwd" ]] && continue
  [[ -d "${cwd:-/nonexistent}" ]] || cwd="$HOME"
  echo "$sid $NOW" >> "$NUDGED"

  # SendMessage addresses live sessions by agent NAME, not session UUID —
  # resolve it from the agents listing.
  name=$(echo "$RUNNING_JSON" | /usr/bin/python3 -c "
import json,sys
try: rows=json.load(sys.stdin)
except Exception: rows=[]
m=[r.get('name','') for r in rows if r.get('sessionId')=='$sid']
print(m[0] if m else '')" 2>/dev/null)
  if [[ -n "$name" ]]; then
    mode=live
  else
    mode=idle
  fi
  log "nudge: $sid $mode name=${name:-none} -> nudge-one.sh in $cwd"
  # Detached (plist sets AbandonProcessGroup=true) so nudges survive this
  # launchd job exiting.
  nohup /bin/zsh "$DIR/nudge-one.sh" "$mode" "$sid" "$cwd" "$name" \
    >> "$DIR/logs/nudge-$sid.log" 2>&1 &
done
exit 0
