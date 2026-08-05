---
name: claude-code-auto-update
description: Use when the user wants to set up automatic daily Claude Code version checking and updating on macOS, or wants to check status or uninstall the auto-updater.
---

# Claude Code Auto-Update

## Overview

Sets up a macOS LaunchAgent that checks for new Claude Code versions daily and upgrades automatically. Supports the **native install** (current default) and falls back to Homebrew Cask for legacy setups.

> **Requirements:** macOS, Claude Code installed (native install at `~/.local/share/claude` **or** via `brew install --cask claude-code`)

> **Security note:** This enables automatic remote upgrades. Native installs use `claude update` (Anthropic's official updater). Homebrew installs use `brew upgrade --cask --greedy`. Auto-upgrades are a supply-chain trust decision — users who prefer to upgrade manually can skip the scheduler and use `--now` on demand.

---

## Install modes

| Mode | Detection | Update command |
|------|-----------|----------------|
| **Native** (recommended) | `~/.local/share/claude/versions/` exists | `claude update` |
| **Homebrew** (legacy) | `brew list --cask claude-code` succeeds | `brew upgrade --cask --greedy claude-code` |

---

## Usage

Locate `install.sh` in the same directory as this skill, then run:

```bash
# First time setup (interactive — asks for preferred time)
./install.sh

# Check status + last log
./install.sh --status

# Trigger an immediate update check right now
./install.sh --now

# Remove everything
./install.sh --uninstall
```

---

## What the script does

| Command | Action |
|---------|--------|
| `./install.sh` | Preflight checks → detects install mode → asks for daily time → writes `~/.local/bin/claude-code-updater`, removes legacy script, registers LaunchAgent |
| `--status` | Shows LaunchAgent state, install mode, current version, last 20 log lines |
| `--now` | Kicks off an immediate check via `launchctl kickstart` (same env as scheduled job) |
| `--uninstall` | Unregisters LaunchAgent, removes plist and script; keeps log files |

Logs are written to `~/.claude/autoupdate.log`.

---

## How to run install.sh as an AI agent

When the user asks you to set up auto-update, run the script directly:

```bash
bash /path/to/skills/claude-code-auto-update/install.sh
```

If you need to pass a time non-interactively (e.g. user said "every day at 8am"), the script is interactive — just run it and answer the prompt with the user's chosen time.

To reinstall (e.g. after switching from Homebrew to native install):

```bash
bash /path/to/skills/claude-code-auto-update/install.sh --uninstall
bash /path/to/skills/claude-code-auto-update/install.sh
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `claude` not found | Native install may not be in PATH for LaunchAgent — the script adds `~/.local/bin` automatically |
| LaunchAgent not registered after install | Run `./install.sh --uninstall` then reinstall |
| `--now` hangs or produces no log | Check `~/.claude/autoupdate-error.log` |
| Lock dir stuck after crash | `rm -rf ~/.claude/autoupdate.lock` |
| Native: `claude` shows old version after update | Check symlink: `ls -la ~/.local/bin/claude` — should point to new version |
| Homebrew: cask skips upgrade | Script uses `--greedy` to force-check casks with `auto_updates true` |
| Legacy updater still running | Run `./install.sh --uninstall` then `./install.sh` to migrate to new version |
