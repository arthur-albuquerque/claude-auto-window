# claude-auto-window

Keeps Claude Code's 5-hour usage windows working for you around the clock on macOS.

Every 10 minutes (whenever the Mac is on), a launchd job runs `watch.sh`, which:

1. **Starts the window** — sends a tiny `claude -p "Hi" --model sonnet --effort low` ping.
   If a fresh 5-hour window is available, this starts it immediately (even overnight),
   instead of waiting for you to sit down and type something.
2. **Revives stalled sessions** — when it sees the limit lift (limited → ok), it finds
   sessions that stopped mid-work on a "You've hit your session limit" error and tells
   them to `continue`:
   - live sessions get the message delivered in place (same model/effort, via SendMessage),
   - dead sessions are resumed headlessly with `claude -p --resume <id> "continue"`.

## Files

| File | What it is |
|---|---|
| `watch.sh` | The watcher (ping + nudge logic; `LIMIT_RE` at the top matches the limit message) |
| `com.arthur.claude-auto-window.plist` | launchd schedule (every 600 s, runs at load) |
| `install.sh` | Copies the plist into `~/Library/LaunchAgents` and loads it |

Runtime state (`state`, `nudged.log`, `logs/`, `pingcwd/`) lives beside the scripts and is gitignored.

## Install

Clone to `~/.claude/auto-window`, then:

```sh
~/.claude/auto-window/install.sh
```

## Operate

```sh
tail -f ~/.claude/auto-window/logs/watch.log            # watch it work
launchctl bootout gui/$(id -u)/com.arthur.claude-auto-window     # pause
~/.claude/auto-window/install.sh                        # (re)enable
```

Notes: each ping costs a few tokens (negligible on Sonnet low); a session is nudged at
most once per 6 h; headless-resumed sessions can't answer permission prompts, so work
needing approval will pause again there.
