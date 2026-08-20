# claude-auto-window

Keeps Claude Code's 5-hour usage windows working for you around the clock on macOS.

Every 10 minutes (whenever the Mac is on), a launchd job runs `watch.sh`, which:

1. **Starts the window** — sends a tiny `claude -p "Hi" --model sonnet --effort low` ping.
   If a fresh 5-hour window is available, this starts it immediately (even overnight),
   instead of waiting for you to sit down and type something.
2. **Revives stalled sessions** — *currently off* (`NUDGE=0` in `watch.sh`). Claude Code
   2.1.234 added a built-in auto-continue for sessions stopped by the usage limit, so the
   watcher now only starts the window and leaves reviving to the CLI. Set `NUDGE=1` to turn
   ours back on; when on, after a limited → ok transition it finds sessions that stopped
   mid-work on a "You've hit your session limit" error and tells them to `continue`:
   - live sessions get the message delivered in place (same model/effort, via SendMessage),
   - dead sessions are resumed as visible background agents (`claude --bg --resume <id>`).

## Files

| File | What it is |
|---|---|
| `watch.sh` | The watcher (ping + nudge logic; `NUDGE` and `LIMIT_RE` at the top) |
| `nudge-one.sh` | Nudges one stalled session — dormant while `NUDGE=0` |
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

Notes: each ping costs a few tokens (negligible on Sonnet low). With `NUDGE=0` the watcher
does nothing but ping. With `NUDGE=1`: a session is nudged at most once per 45 min, and
resumed sessions can't answer permission prompts, so work needing approval pauses again there.
