#!/bin/sh
# moonlight-commit installer
# Installs the hooks into the current repo's hooks directory.
# Usage: ./install.sh [--dry-run]

set -e

RAW_BASE="${MOONLIGHT_COMMIT_RAW_BASE:-https://raw.githubusercontent.com/closedloop-technologies/moonlight-commit/main}"

dry_run=0
if [ "$#" -gt 1 ]; then
  echo "Usage: ./install.sh [--dry-run]" >&2
  exit 2
fi

case "${1:-}" in
  "")
    ;;
  "--dry-run")
    dry_run=1
    ;;
  *)
    echo "Usage: ./install.sh [--dry-run]" >&2
    exit 2
    ;;
esac

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Not inside a git repository" >&2
  exit 1
fi

hooks_path=$(git rev-parse --path-format=absolute --git-path hooks)

script_dir=
case "$0" in
  */*) script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) ;;
esac

hook_source() {
  hook_name="$1"
  if [ -n "$script_dir" ] && [ -f "$script_dir/hooks/$hook_name" ]; then
    printf '%s\n' "$script_dir/hooks/$hook_name"
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    tmp_file=$(mktemp "${TMPDIR:-/tmp}/moonlight-commit-${hook_name}.XXXXXX")
    if curl -fsSL "$RAW_BASE/hooks/$hook_name" -o "$tmp_file"; then
      printf '%s\n' "$tmp_file"
      return 0
    fi
    rm -f "$tmp_file"
    exit 1
  fi

  echo "Cannot find hooks/$hook_name locally and curl is not installed." >&2
  exit 1
}

install_hook() {
  hook_name="$1"
  source_file="$2"
  target_file="$hooks_path/$hook_name.moonlight"

  cp "$source_file" "$target_file"
  chmod +x "$target_file"
  if [ ! -e "$hooks_path/$hook_name" ] && [ ! -L "$hooks_path/$hook_name" ]; then
    (cd "$hooks_path" && ln -s "$hook_name.moonlight" "$hook_name")
  fi
}

cleanup_hook_source() {
  source_file="$1"
  case "$source_file" in
    "$script_dir"/hooks/*)
      return 0
      ;;
  esac
  case "$source_file" in
    "${TMPDIR:-/tmp}"/moonlight-commit-*)
      rm -f "$source_file"
      ;;
  esac
}

cleanup_hook_sources() {
  [ -n "${pre_commit_source:-}" ] && cleanup_hook_source "$pre_commit_source"
  [ -n "${commit_msg_source:-}" ] && cleanup_hook_source "$commit_msg_source"
}

if [ "$dry_run" -eq 1 ]; then
  echo "Would create hooks directory: $hooks_path"
  for hook_name in pre-commit commit-msg; do
    echo "Would install: $hooks_path/$hook_name.moonlight"
    if [ ! -e "$hooks_path/$hook_name" ] && [ ! -L "$hooks_path/$hook_name" ]; then
      echo "Would create symlink: $hooks_path/$hook_name -> $hook_name.moonlight"
    else
      echo "Hook already exists at $hooks_path/$hook_name"
    fi
  done
  exit 0
fi

mkdir -p "$hooks_path"

pre_commit_source=
commit_msg_source=
trap cleanup_hook_sources EXIT HUP INT TERM

pre_commit_source=$(hook_source pre-commit)
commit_msg_source=$(hook_source commit-msg)

install_hook pre-commit "$pre_commit_source"
install_hook commit-msg "$commit_msg_source"

cleanup_hook_source "$pre_commit_source"
cleanup_hook_source "$commit_msg_source"
pre_commit_source=
commit_msg_source=
trap - EXIT HUP INT TERM

echo "✅ moonlight-commit installed to $hooks_path"
