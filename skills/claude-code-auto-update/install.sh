#!/bin/bash
# Claude Code Auto-Update Installer
# Usage:
#   ./install.sh            — interactive install
#   ./install.sh --now      — run update check immediately (no schedule)
#   ./install.sh --status   — show status + recent log
#   ./install.sh --uninstall — remove everything

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
LABEL="com.claude-code.autoupdate"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT="$HOME/.local/bin/claude-code-updater"
LEGACY_SCRIPT="$HOME/.local/bin/claude-code-autoupdate.sh"
LOG="$HOME/.claude/autoupdate.log"
ERR_LOG="$HOME/.claude/autoupdate-error.log"
LOCKDIR="$HOME/.claude/autoupdate.lock"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATER_SOURCE="$SCRIPT_DIR/updater.sh"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BOLD}→ $*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✗ $*${RESET}" >&2; }
die()     { error "$*"; exit 1; }

# ── Install mode detection ────────────────────────────────────────────────────
detect_install_mode() {
  # Native install: ~/.local/share/claude/versions exists
  if [ -d "$HOME/.local/share/claude/versions" ]; then
    echo "native"
    return 0
  fi
  # Homebrew Cask fallback
  local brew_bin=""
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$brew_bin" ] && "$brew_bin" list --cask claude-code >/dev/null 2>&1; then
      echo "homebrew"
      return 0
    fi
  done
  echo "none"
}

find_claude_bin() {
  for p in "$HOME/.local/bin/claude" /usr/local/bin/claude; do
    [ -x "$p" ] && printf '%s\n' "$p" && return 0
  done
  command -v claude 2>/dev/null || true
}

# ── Preflight checks ─────────────────────────────────────────────────────────
preflight() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This script only works on macOS."
  [[ "$(id -u)" -ne 0 ]] || die "Do not run as root."

  local mode
  mode="$(detect_install_mode)"

  case "$mode" in
    native)
      success "Detected native Claude Code install (~/.local/share/claude)"
      ;;
    homebrew)
      warn "Detected Homebrew Cask install (legacy). Native install is recommended."
      warn "To switch: claude install (or reinstall via https://claude.ai/download)"
      ;;
    none)
      die "Claude Code not found.\nNative install: https://claude.ai/download\nHomebrew: brew install --cask claude-code"
      ;;
  esac
}

# ── Write the updater script ──────────────────────────────────────────────────
write_updater_script() {
  mkdir -p "$(dirname "$SCRIPT")"
  [[ -f "$UPDATER_SOURCE" ]] || die "Updater source not found: $UPDATER_SOURCE"
  cp "$UPDATER_SOURCE" "$SCRIPT"
  chmod +x "$SCRIPT"
}

remove_legacy_script() {
  [[ -f "$LEGACY_SCRIPT" ]] || return 0
  info "Removing legacy updater script..."
  rm -f "$LEGACY_SCRIPT"
  success "Legacy updater script removed"
}

# ── Write the LaunchAgent plist ───────────────────────────────────────────────
write_plist() {
  local hour=$1 minute=$2
  mkdir -p "$(dirname "$PLIST")"
  cat > "$PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>Program</key>
  <string>$SCRIPT</string>
  <key>ProgramArguments</key>
  <array>
    <string>claude-code-updater</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>$hour</integer>
    <key>Minute</key>
    <integer>$minute</integer>
  </dict>
  <key>RunAtLoad</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$LOG</string>
  <key>StandardErrorPath</key>
  <string>$ERR_LOG</string>
</dict>
</plist>
EOF
}

# ── launchd helpers ───────────────────────────────────────────────────────────
agent_registered() {
  launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1
}

bootstrap_agent() {
  plutil -lint "$PLIST" >/dev/null 2>&1 || die "Plist syntax error: $PLIST"
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
}

bootout_agent() {
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
}

# ── Commands ──────────────────────────────────────────────────────────────────
cmd_install() {
  preflight

  echo ""
  echo -e "${BOLD}Claude Code Auto-Update Setup${RESET}"
  echo "────────────────────────────────"

  # Warn if active claude binary path looks unexpected
  local claude_bin
  claude_bin="$(find_claude_bin)"
  if [ -n "$claude_bin" ]; then
    info "Using claude at: $claude_bin"
  fi

  # Ask for time
  local time_input hour minute
  read -rp "$(echo -e "Daily update time ${BOLD}[HH:MM, default 09:00]${RESET}: ")" time_input
  time_input="${time_input:-09:00}"

  if ! [[ "$time_input" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
    die "Invalid time format. Use HH:MM (e.g. 09:00)"
  fi
  hour="${BASH_REMATCH[1]#0}"
  minute="${BASH_REMATCH[2]#0}"
  hour="${hour:-0}"
  minute="${minute:-0}"

  [[ "$hour" -ge 0 && "$hour" -le 23 ]] || die "Hour must be 0–23."
  [[ "$minute" -ge 0 && "$minute" -le 59 ]] || die "Minute must be 0–59."

  # Create dirs
  info "Creating directories..."
  mkdir -p "$HOME/.claude" "$HOME/.local/bin" "$HOME/Library/LaunchAgents"
  success "Directories ready"

  # Write updater script
  info "Writing updater script to $SCRIPT..."
  write_updater_script
  success "Updater script written"
  remove_legacy_script

  # Write plist
  info "Writing LaunchAgent plist..."
  write_plist "$hour" "$minute"
  success "Plist created"

  # Bootstrap
  info "Registering LaunchAgent..."
  bootstrap_agent
  success "LaunchAgent registered"

  # Verify
  if agent_registered; then
    success "Verified: LaunchAgent is active"
  else
    die "LaunchAgent registration failed. Check $PLIST"
  fi

  local display_hour display_minute
  display_hour=$(printf "%02d" "$hour")
  display_minute=$(printf "%02d" "$minute")

  echo ""
  echo -e "${GREEN}${BOLD}Done!${RESET}"
  echo -e "Claude Code will be checked for updates every day at ${BOLD}${display_hour}:${display_minute}${RESET}."
  echo -e "Logs: ${BOLD}$LOG${RESET}"
  echo ""
  echo -e "Run ${BOLD}$(basename "$0") --now${RESET} to trigger an immediate check."
}

cmd_status() {
  echo ""
  echo -e "${BOLD}Claude Code Auto-Update Status${RESET}"
  echo "────────────────────────────────"

  if agent_registered; then
    local state
    state=$(launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null \
      | grep -E 'state|last exit' || true)
    success "LaunchAgent registered"
    echo "$state" | sed 's/^/  /'
  else
    warn "LaunchAgent is NOT registered (not installed or failed to load)"
  fi

  echo ""
  echo -e "${BOLD}Install mode & version:${RESET}"
  local mode
  mode="$(detect_install_mode)"
  case "$mode" in
    native)
      local claude_bin current
      claude_bin="$(find_claude_bin)"
      current="$("$claude_bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo 'unknown')"
      success "Native install | Current: $current"
      info "Binary: $claude_bin"
      ;;
    homebrew)
      local brew_bin current
      for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        [ -x "$brew_bin" ] && break
      done
      current="$("$brew_bin" list --cask --versions claude-code 2>/dev/null \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo 'unknown')"
      if "$brew_bin" outdated --cask --greedy 2>/dev/null | grep -q "^claude-code"; then
        warn "Homebrew install | Update available! Run: brew upgrade --cask --greedy claude-code"
      else
        success "Homebrew install | Up-to-date: $current"
      fi
      ;;
    none)
      warn "Claude Code not detected"
      ;;
  esac

  echo ""
  echo -e "${BOLD}Last 20 log lines:${RESET}"
  if [[ -f "$LOG" ]]; then
    tail -20 "$LOG"
  else
    echo "  (no log yet)"
  fi
  echo ""
}

cmd_now() {
  preflight

  if ! agent_registered; then
    die "Auto-updater is not installed. Run $(basename "$0") first."
  fi

  info "Running update check now (this may take ~30s while checking online)..."
  echo ""
  # Run the updater script directly so output is visible in real-time.
  # launchctl kickstart runs in the background and the check can take ~30s.
  "$SCRIPT" && echo "" || true

  echo -e "${BOLD}Last 10 log lines:${RESET}"
  tail -10 "$LOG" 2>/dev/null || echo "  (log not found — check $ERR_LOG)"
}

cmd_uninstall() {
  echo ""
  echo -e "${BOLD}Uninstalling Claude Code Auto-Update${RESET}"
  echo "──────────────────────────────────────"

  info "Unregistering LaunchAgent..."
  bootout_agent
  success "LaunchAgent unregistered"

  info "Removing plist..."
  rm -f "$PLIST"
  success "Plist removed"

  info "Removing updater script..."
  rm -f "$SCRIPT"
  rm -f "$LEGACY_SCRIPT"
  rm -rf "$LOCKDIR" 2>/dev/null || true
  success "Script removed"

  echo ""
  echo -e "${GREEN}${BOLD}Done.${RESET} Log files kept at:"
  echo "  $LOG"
  echo "  $ERR_LOG"
  echo ""
}

# ── Entry point ───────────────────────────────────────────────────────────────
case "${1:-}" in
  --now)       cmd_now       ;;
  --status)    cmd_status    ;;
  --uninstall) cmd_uninstall ;;
  "")          cmd_install   ;;
  *)
    echo "Usage: $(basename "$0") [--now | --status | --uninstall]"
    exit 1
    ;;
esac
