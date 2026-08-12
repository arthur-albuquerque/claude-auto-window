#!/bin/zsh
# Install the auto-window watcher: link the launchd plist and load it.
# Assumes this repo is checked out at ~/.claude/auto-window.
set -eu
DIR="$HOME/.claude/auto-window"
PLIST_SRC="$DIR/com.arthur.claude-auto-window.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.arthur.claude-auto-window.plist"

mkdir -p "$DIR/pingcwd" "$DIR/logs" "$HOME/Library/LaunchAgents"
chmod +x "$DIR/watch.sh"
cp "$PLIST_SRC" "$PLIST_DST"
launchctl bootout "gui/$(id -u)/com.arthur.claude-auto-window" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
echo "Installed. Check: launchctl list | grep claude-auto-window; tail -f $DIR/logs/watch.log"
