# claude-code-notifications

Sets up macOS notifications with custom sound and icon for Claude Code hooks.

By default, Claude Code hook notifications on macOS have no sound and use a generic icon. This skill installs [growlrrr](https://github.com/moltenbits/growlrrr) and configures everything interactively — you choose the icon and sound.

> **macOS only.** Requires Claude Code and Homebrew.

## Installation

```bash
npx skills add mizok/agent-skills --skill claude-code-notifications
```

## Usage

Once installed, just say:

```
/claude-code-notifications
```

Claude will guide you through:
1. Choosing a notification icon (URL or local file path)
2. Choosing a notification sound (`Glass`, `Ping`, `Tink`, `Sosumi`, `Basso`, or `none`)
3. Installing growlrrr
4. Configuring `~/.claude/settings.json`

## Notes

- After changing the icon, a **reboot is required** for macOS to pick up the new icon
- growlrrr is not yet signed by Apple — the skill handles the quarantine bypass automatically
