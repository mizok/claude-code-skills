#!/bin/bash
# Test suite for claude-code-auto-update updater.sh
# Covers: native install (update available), native (up-to-date), homebrew (update available)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATER="$ROOT_DIR/updater.sh"
TMP_DIR="$(mktemp -d)"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

pass() { printf "${GREEN:-}✓ %s${RESET:-}\n" "$1"; }
fail() { printf "${RED:-}✗ %s${RESET:-}\n" "$1" >&2; exit 1; }

# ── Test 1: Native install — update available ─────────────────────────────────
{
  TEST_HOME="$TMP_DIR/native-update"
  VERSION_DIR="$TEST_HOME/.local/share/claude/versions"
  LOG="$TEST_HOME/.claude/autoupdate.log"
  OLD_VERSION="2.1.80"
  NEW_VERSION="2.1.81"
  STATE_FILE="$TMP_DIR/native-version"

  mkdir -p "$TEST_HOME/.claude" "$VERSION_DIR" "$TEST_HOME/.local/bin"
  printf '%s\n' "$OLD_VERSION" > "$STATE_FILE"

  FAKE_CLAUDE="$TMP_DIR/fake-claude-1"
  cat > "$FAKE_CLAUDE" << EOF
#!/bin/bash
STATE_FILE="$STATE_FILE"
NEW_VERSION="$NEW_VERSION"
case "\${1:-}" in
  --version) printf '%s (Claude Code)\n' "\$(cat "\$STATE_FILE")" ;;
  update)    printf '%s\n' "\$NEW_VERSION" > "\$STATE_FILE"; printf 'Updated to %s\n' "\$NEW_VERSION" ;;
  *)         exit 1 ;;
esac
EOF
  chmod +x "$FAKE_CLAUDE"
  ln -sf "$FAKE_CLAUDE" "$TEST_HOME/.local/bin/claude"

  HOME="$TEST_HOME" CLAUDE_BIN_OVERRIDE="$FAKE_CLAUDE" "$UPDATER"

  grep -q "Install mode: native" "$LOG" || fail "Test 1: missing install mode log"
  grep -q "Successfully updated: $OLD_VERSION → $NEW_VERSION" "$LOG" || fail "Test 1: update not recorded"
  pass "Native install: update available ($OLD_VERSION → $NEW_VERSION)"
}

# ── Test 2: Native install — already up-to-date ───────────────────────────────
{
  TEST_HOME="$TMP_DIR/native-uptodate"
  VERSION_DIR="$TEST_HOME/.local/share/claude/versions"
  LOG="$TEST_HOME/.claude/autoupdate.log"
  CURRENT="2.1.92"
  STATE_FILE="$TMP_DIR/native-version2"

  mkdir -p "$TEST_HOME/.claude" "$VERSION_DIR" "$TEST_HOME/.local/bin"
  printf '%s\n' "$CURRENT" > "$STATE_FILE"

  FAKE_CLAUDE="$TMP_DIR/fake-claude-2"
  cat > "$FAKE_CLAUDE" << EOF
#!/bin/bash
STATE_FILE="$STATE_FILE"
case "\${1:-}" in
  --version) printf '%s (Claude Code)\n' "\$(cat "\$STATE_FILE")" ;;
  update)    printf 'Already up to date.\n' ;;
  *)         exit 1 ;;
esac
EOF
  chmod +x "$FAKE_CLAUDE"
  ln -sf "$FAKE_CLAUDE" "$TEST_HOME/.local/bin/claude"

  HOME="$TEST_HOME" CLAUDE_BIN_OVERRIDE="$FAKE_CLAUDE" "$UPDATER"

  grep -q "Up-to-date: $CURRENT" "$LOG" || fail "Test 2: up-to-date not logged"
  pass "Native install: already up-to-date ($CURRENT)"
}

# ── Test 3: Homebrew install — update available (legacy fallback) ─────────────
{
  TEST_HOME="$TMP_DIR/brew-update"
  FAKE_PREFIX="$TMP_DIR/fake-prefix-brew"
  LOG="$TEST_HOME/.claude/autoupdate.log"
  STATE_FILE="$TMP_DIR/brew-version"
  OLD_VERSION="2.1.70"
  NEW_VERSION="2.1.71"

  mkdir -p "$TEST_HOME/.claude" "$FAKE_PREFIX/bin"
  printf '%s\n' "$OLD_VERSION" > "$STATE_FILE"

  FAKE_BREW="$TMP_DIR/fake-brew"
  cat > "$FAKE_BREW" << EOF
#!/bin/bash
STATE_FILE="$STATE_FILE"
FAKE_PREFIX="$FAKE_PREFIX"
NEW_VERSION="$NEW_VERSION"
case "\${1:-}" in
  --prefix)  printf '%s\n' "$FAKE_PREFIX" ;;
  update)    exit 0 ;;
  outdated)  printf 'claude-code\n' ;;
  list)      printf 'claude-code %s\n' "\$(cat "\$STATE_FILE")" ;;
  upgrade)   printf '%s\n' "\$NEW_VERSION" > "\$STATE_FILE" ;;
  *)         printf 'unexpected: %s\n' "\$*" >&2; exit 1 ;;
esac
EOF
  chmod +x "$FAKE_BREW"

  cat > "$FAKE_PREFIX/bin/grrr" << 'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$FAKE_PREFIX/bin/grrr"

  HOME="$TEST_HOME" BREW_BIN_OVERRIDE="$FAKE_BREW" "$UPDATER"

  grep -q "Install mode: homebrew" "$LOG" || fail "Test 3: missing homebrew mode log"
  grep -q "Successfully updated: $OLD_VERSION → $NEW_VERSION" "$LOG" || fail "Test 3: brew update not recorded"
  pass "Homebrew install: update available ($OLD_VERSION → $NEW_VERSION)"
}

# ── Test 4: No Claude Code found ──────────────────────────────────────────────
{
  TEST_HOME="$TMP_DIR/no-install"
  LOG="$TEST_HOME/.claude/autoupdate.log"
  mkdir -p "$TEST_HOME/.claude"

  HOME="$TEST_HOME" "$UPDATER" && fail "Test 4: should have exited non-zero" || true
  grep -q "ERROR" "$LOG" || fail "Test 4: error not logged"
  pass "No install detected: error logged and exit non-zero"
}

printf '\nAll tests passed.\n'
