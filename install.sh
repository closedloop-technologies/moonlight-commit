#!/usr/bin/env bash
# moonlight-commit installer - installs hooks globally with executable permissions
# Passing --uninstall restores the previous hooksPath if recorded

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$HOME/.git-hooks"
BACKUP_FILE="$HOOKS_DIR.previous"

if [[ "${1:-}" == "--uninstall" ]]; then
  if [ -f "$BACKUP_FILE" ]; then
    PREV=$(cat "$BACKUP_FILE")
    if [ -n "$PREV" ]; then
      git config --global core.hooksPath "$PREV"
      echo "Restored core.hooksPath to $PREV"
    else
      git config --global --unset core.hooksPath
      echo "Removed core.hooksPath setting"
    fi
    rm -f "$BACKUP_FILE"
    echo "moonlight-commit uninstalled."
  else
    echo "moonlight-commit was not installed." >&2
  fi
  exit 0
fi

echo "Installing moonlight-commit hooks globally..."

EXISTING=$(git config --global --get core.hooksPath || true)
if [ -n "$EXISTING" ] && [ "$EXISTING" != "$HOOKS_DIR" ]; then
  echo "Existing global hooks found at '$EXISTING'."
  read -r -p "Back up and override with moonlight-commit? [y/N] " resp
  if [[ "$resp" =~ ^[Yy]$ ]]; then
    BACKUP_DIR="$EXISTING.backup.$(date +%s)"
    mkdir -p "$BACKUP_DIR"
    cp -r "$EXISTING"/* "$BACKUP_DIR" 2>/dev/null || true
    echo "Backed up existing hooks to $BACKUP_DIR"
    echo "$EXISTING" > "$BACKUP_FILE"
  else
    echo "Aborting installation."
    exit 1
  fi
else
  : > "$BACKUP_FILE"
fi

mkdir -p "$HOOKS_DIR"

cp "$DIR/hooks/pre-commit" "$HOOKS_DIR/pre-commit"
cp "$DIR/hooks/commit-msg" "$HOOKS_DIR/commit-msg"

chmod +x "$HOOKS_DIR/pre-commit" "$HOOKS_DIR/commit-msg"

git config --global core.hooksPath "$HOOKS_DIR"

echo "✅ moonlight-commit installed globally!"
echo "Run './install.sh --uninstall' to restore previous settings."
