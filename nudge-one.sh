#!/bin/zsh
# Nudge a single limit-stalled session:
#   $1=mode(live|idle) $2=session_id $3=cwd $4=agent_name (live only)
# Invoked detached by watch.sh so it survives the launchd job exiting
# (plist sets AbandonProcessGroup=true).
set -u
CLAUDE="$HOME/.local/bin/claude"
mode="$1" sid="$2" cwd="$3" name="${4:-}"
cd "$cwd" || cd "$HOME"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $mode nudge start in $PWD (name=$name)"
if [[ "$mode" == live ]]; then
  # Deliver "continue" into the still-running session via SendMessage.
  # SendMessage addresses by agent name (as shown by ListAgents), never by
  # session UUID.
  "$CLAUDE" -p --model sonnet --effort low \
    "Call ListAgents, find the agent named '$name', then use the SendMessage tool to send it exactly the message 'continue'. Do nothing else, change no files."
else
  # Resume the dead session as a BACKGROUND AGENT (its own saved model/
  # effort). A plain -p resume works but is invisible: UI hosts like t3
  # render their own store, so appended transcript work never surfaces.
  # --bg forks into a named agent that shows in agent view (incl. mobile),
  # can be attached to, and is live-nudgeable next window.
  "$CLAUDE" --bg --resume "$sid" -n "auto-continue-${sid%%-*}" \
    --permission-mode acceptEdits "continue"
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] done rc=$?"
