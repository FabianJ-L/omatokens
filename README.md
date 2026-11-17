# Token Tally

How many tokens Claude Code and Codex used, today, this week, this month, and
in total, and when. It reads the logs the agents already write
(`~/.claude/projects`, `~/.codex/sessions`), every agent and subagent
included, and updates every 15 seconds while it's open. Nothing is sent
anywhere.

- Totals for today, this week, this month, and all time
- A stacked chart of the selected period (by hour, day, or week) split into
  output, input, cache writes, and cache reads
- Breakdowns by model, project, and agent
- A weekday × hour heatmap of when you use it
- Follows the Omarchy accent, window rounding, and language (English, German)

Usage in claude.ai chats in the browser isn't in these logs and isn't counted.

## Shortcuts

| Key | Action |
| --- | --- |
| `1`–`4` | Today, week, month, all time |
| `←` `→` | Previous or next period |
| `0` | Back to the current period |
| `A` | Switch agent |
| `C` | Show or hide cache reads in the chart |
| `Space` | Read the logs again |
| `?` | Show or hide help |
| `Q` | Quit |

## Command line

```sh
tokentally summary          # today, week, month, all time
tokentally summary --json
```

## Build

```sh
bin/build      # build/tokentally
bin/test       # tests, offscreen
bin/install    # package and install, so it shows up in the launcher
```
