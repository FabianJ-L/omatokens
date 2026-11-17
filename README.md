# Token Tally

[![Build](https://github.com/FabianJ-L/tokentally/actions/workflows/build.yml/badge.svg)](https://github.com/FabianJ-L/tokentally/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/FabianJ-L/tokentally)](https://github.com/FabianJ-L/tokentally/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

A small desktop app for [Omarchy](https://omarchy.org) that shows how many
tokens Claude Code and Codex used, today, this week, this month, and in total,
and when. It reads the logs the agents already write
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

## Install

On Omarchy (or any Arch Linux), paste this into a terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/FabianJ-L/tokentally/master/install.sh | bash
```

It installs Qt 6 and the build tools with pacman, builds Token Tally, and
installs it as a package. Then open **Token Tally** from the app launcher
(`Super` + `Space`) or run `tokentally`.

**Prebuilt package (x86_64):** download `tokentally-*.pkg.tar.zst` from the
[latest release](https://github.com/FabianJ-L/tokentally/releases/latest), then

```sh
sudo pacman -U tokentally-*.pkg.tar.zst
```

**By hand:**

```sh
git clone https://github.com/FabianJ-L/tokentally
cd tokentally
bin/install
```

**Uninstall:** `sudo pacman -R tokentally`

**Update:** run the install command again.

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

Needs `qt6-base`, `qt6-declarative`, and `qt6-wayland`.

```sh
bin/build      # build/tokentally
bin/test       # tests, offscreen
bin/install    # package and install, so it shows up in the launcher
```

`packaging/aur/PKGBUILD` builds a tagged release from GitHub, ready for the AUR.

## License

MIT
