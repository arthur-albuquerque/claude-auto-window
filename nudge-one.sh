#!/bin/zsh
# Nudge a single limit-stalled session: $1=mode(live|idle) $2=session_id $3=cwd
# Invoked detached by watch.sh so it survives the launchd job exiting
# (plist sets AbandonProcessGroup=true).
set -u
CLAUDE="$HOME/.local/bin/claude"
mode="$1" sid="$2" cwd="$3"
cd "$cwd" || cd "$HOME"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] $mode nudge start in $PWD"
if [[ "$mode" == live ]]; then
  # Deliver "continue" into the still-running session via SendMessage.
  "$CLAUDE" -p --model sonnet --effort low \
    "Use the SendMessage tool to send exactly the message 'continue' to the local session with id $sid (use ListAgents to find its address if needed). Do nothing else, change no files."
else
  # Resume the dead session with its own saved model/effort.
  "$CLAUDE" -p --resume "$sid" --permission-mode acceptEdits "continue"
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] done rc=$?"
