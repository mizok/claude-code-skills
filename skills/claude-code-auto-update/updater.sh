#!/bin/bash
# Claude Code Auto-Updater
# Supports: native install (~/.local/share/claude) and Homebrew Cask (legacy fallback)

set -euo pipefail

LOG="$HOME/.claude/autoupdate.log"
LOCKDIR="$HOME/.claude/autoupdate.lock"

ts() { date "+%Y-%m-%d %H:%M:%S"; }

# ── Locate binaries ───────────────────────────────────────────────────────────
find_claude_bin() {
  if [ -n "${CLAUDE_BIN_OVERRIDE:-}" ]; then
    [ -x "$CLAUDE_BIN_OVERRIDE" ] && printf '%s\n' "$CLAUDE_BIN_OVERRIDE" && return 0
    return 1
  fi
  for p in "$HOME/.local/bin/claude" /usr/local/bin/claude; do
    [ -x "$p" ] && printf '%s\n' "$p" && return 0
  done
  command -v claude 2>/dev/null && return 0
  return 1
}

find_brew_bin() {
  if [ -n "${BREW_BIN_OVERRIDE:-}" ]; then
    [ -x "$BREW_BIN_OVERRIDE" ] && printf '%s\n' "$BREW_BIN_OVERRIDE" && return 0
    return 1
  fi
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$p" ] && printf '%s\n' "$p" && return 0
  done
  return 1
}

# ── Extend PATH (LaunchAgent runs with minimal PATH) ──────────────────────────
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
BREW_BIN="$(find_brew_bin 2>/dev/null || true)"
[ -n "$BREW_BIN" ] && export PATH="$("$BREW_BIN" --prefix 2>/dev/null)/bin:$PATH"

# ── Lock ──────────────────────────────────────────────────────────────────────
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  echo "[$(ts)] Skipping — another instance is already running" >> "$LOG"
  exit 0
fi
trap 'rm -rf "$LOCKDIR"' EXIT INT TERM

# ── Detect install mode ───────────────────────────────────────────────────────
CLAUDE_BIN="$(find_claude_bin 2>/dev/null || true)"
NATIVE_INSTALL=0
BREW_INSTALL=0

if [ -d "$HOME/.local/share/claude/versions" ] && [ -n "$CLAUDE_BIN" ]; then
  NATIVE_INSTALL=1
elif [ -n "$BREW_BIN" ] && "$BREW_BIN" list --cask claude-code >/dev/null 2>&1; then
  BREW_INSTALL=1
fi

if [ "$NATIVE_INSTALL" -eq 0 ] && [ "$BREW_INSTALL" -eq 0 ]; then
  echo "[$(ts)] ERROR: Claude Code not found (native install at ~/.local/share/claude not detected, Homebrew cask not found)" >> "$LOG"
  exit 1
fi

echo "[$(ts)] Checking for Claude Code updates..." >> "$LOG"

# ── Native install: use `claude update` ───────────────────────────────────────
if [ "$NATIVE_INSTALL" -eq 1 ]; then
  CURRENT_VERSION="$("$CLAUDE_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo 'unknown')"
  echo "[$(ts)] Install mode: native | Current: $CURRENT_VERSION" >> "$LOG"

  UPDATE_OUTPUT="$("$CLAUDE_BIN" update 2>&1 || true)"
  echo "$UPDATE_OUTPUT" >> "$LOG"

  NEW_VERSION="$("$CLAUDE_BIN" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo 'unknown')"

  if [ "$NEW_VERSION" != "$CURRENT_VERSION" ]; then
    echo "[$(ts)] Successfully updated: $CURRENT_VERSION → $NEW_VERSION" >> "$LOG"
    if command -v grrr >/dev/null 2>&1; then
      grrr --appId Claude-Code --title "Claude Code Updated" \
        "Updated $CURRENT_VERSION → $NEW_VERSION" 2>/dev/null || true
    fi
  else
    echo "[$(ts)] Up-to-date: $CURRENT_VERSION" >> "$LOG"
  fi
  exit 0
fi

# ── Homebrew install: legacy fallback ─────────────────────────────────────────
brew_current_version() {
  "$BREW_BIN" list --cask --versions claude-code 2>/dev/null \
    | awk 'NR == 1 { print $2; exit }'
}

CURRENT_VERSION="$(brew_current_version)"
CURRENT_VERSION="${CURRENT_VERSION:-unknown}"
echo "[$(ts)] Install mode: homebrew | Current: $CURRENT_VERSION" >> "$LOG"

if ! "$BREW_BIN" update --quiet 2>> "$LOG"; then
  echo "[$(ts)] WARNING: brew update failed, continuing with cached index" >> "$LOG"
fi

OUTDATED="$("$BREW_BIN" outdated --cask --greedy 2>/dev/null | awk '$1 == "claude-code" { print; exit }')"
if [ -z "$OUTDATED" ]; then
  echo "[$(ts)] Up-to-date: $CURRENT_VERSION" >> "$LOG"
  exit 0
fi

echo "[$(ts)] Update available: $CURRENT_VERSION" >> "$LOG"
if "$BREW_BIN" upgrade --cask --greedy claude-code >> "$LOG" 2>&1; then
  UPDATED_VERSION="$(brew_current_version)"
  UPDATED_VERSION="${UPDATED_VERSION:-unknown}"
  echo "[$(ts)] Successfully updated: $CURRENT_VERSION → $UPDATED_VERSION" >> "$LOG"
  if command -v grrr >/dev/null 2>&1; then
    grrr --appId Claude-Code --title "Claude Code Updated" \
      "Updated $CURRENT_VERSION → $UPDATED_VERSION" 2>/dev/null || true
  fi
else
  echo "[$(ts)] Update FAILED — see log for details" >> "$LOG"
  exit 1
fi
