# OmaTokens

[![Build](https://github.com/FabianJ-L/omatokens/actions/workflows/build.yml/badge.svg)](https://github.com/FabianJ-L/omatokens/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/FabianJ-L/omatokens)](https://github.com/FabianJ-L/omatokens/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

A small desktop app for [Omarchy](https://omarchy.org) that shows how many
tokens your AI coding agents used, today, this week, this month, and in
total, and when. It reads the logs the agents already write, every agent and
subagent included, and updates every 15 seconds while it's open. Nothing is
sent anywhere.

| Agent | Logs |
| --- | --- |
| Claude Code | `~/.claude/projects` |
| Codex | `~/.codex/sessions` |
| Gemini CLI | `~/.gemini/tmp/*/chats` |
| Qwen Code | `~/.qwen/tmp/*/chats`, `~/.qwen/projects/*/chats` |
| OpenCode | `~/.local/share/opencode/opencode.db` (and the older `storage/message`) |

- Totals for today, this week, this month, and all time
- A stacked chart of the selected period (by hour, day, or week) split into
  output, input, cache writes, and cache reads
- Breakdowns by model, project, and agent
- A weekday × hour heatmap of when you use it
- Follows the Omarchy accent, window rounding, and language (English, German)

- With Claude Desktop installed, how much of your Claude plan's 5-hour and
  weekly limits is used

Chats in Claude Desktop, on claude.ai, in ChatGPT, or in Gemini on the web
keep no token counts on your computer, so they can't be counted as tokens.
Claude Desktop does record the plan limits, which cover its chats too;
OmaTokens shows those.

## Install

On Omarchy (or any Arch Linux), paste this into a terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/FabianJ-L/omatokens/master/install.sh | bash
```

It installs Qt 6 and the build tools with pacman, builds OmaTokens, and
installs it as a package. Then open **OmaTokens** from the app launcher
(`Super` + `Space`) or run `omatokens`.

**Prebuilt package (x86_64):** download `omatokens-*.pkg.tar.zst` from the
[latest release](https://github.com/FabianJ-L/omatokens/releases/latest), then

```sh
sudo pacman -U omatokens-*.pkg.tar.zst
```

**By hand:**

```sh
git clone https://github.com/FabianJ-L/omatokens
cd omatokens
bin/install
```

**Uninstall:** `sudo pacman -R omatokens`

OmaTokens used to be called Token Tally (`tokentally`); `oma-update` swaps
the old package for the new one.

**Update:** run `oma-update`. Every [Oma app](https://github.com/FabianJ-L/oma) (Omasql, OmaTask, OmaTokens)
installs it; it updates all of them at once, from GitHub.

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
omatokens summary          # today, week, month, all time
omatokens summary --json
```

## Build

Needs `qt6-base`, `qt6-declarative`, and `qt6-wayland`.

```sh
bin/build      # build/omatokens
bin/test       # tests, offscreen
bin/install    # package and install, so it shows up in the launcher
```

`packaging/aur/PKGBUILD` builds a tagged release from GitHub, ready for the AUR.

## License

MIT
