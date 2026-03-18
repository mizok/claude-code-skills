# claude-code-notifications

A [Claude Code](https://claude.ai/code) skill that sets up macOS notifications with custom sound and icon for Claude Code hooks.

By default, Claude Code hook notifications on macOS have no sound and use a generic icon. This skill installs [growlrrr](https://github.com/moltenbits/growlrrr) and configures everything interactively — you choose the icon and sound.

> **macOS only.** Requires Claude Code (not compatible with Codex or other AI tools).

## Demo

When Claude Code needs your attention, you'll get a native macOS notification with your custom icon and sound of choice.

## Installation

```bash
git clone https://github.com/mizok/claude-code-notifications.git \
  ~/.claude/skills/claude-code-notifications
```

## Usage

In any Claude Code session:

```
/claude-code-notifications
```

Claude will guide you through:
1. Choosing a notification icon (URL or local file path)
2. Choosing a notification sound
3. Installing growlrrr
4. Configuring `~/.claude/settings.json`

## Requirements

- macOS 13 (Ventura) or later
- [Claude Code](https://claude.ai/code)
- [Homebrew](https://brew.sh)

## License

MIT
