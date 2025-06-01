#!/bin/sh
# moonlight-commit installer
# Installs the pre-commit hook into the current repo's hooks directory.
# Usage: ./install.sh [--dry-run]

set -e

dry_run=0
if [ "${1:-}" = "--dry-run" ]; then
  dry_run=1
fi

repo_root=$(git rev-parse --git-dir 2>/dev/null)
if [ -z "$repo_root" ]; then
  echo "Not inside a git repository" >&2
  exit 1
fi

hooks_path=$(git config core.hooksPath || true)
if [ -z "$hooks_path" ]; then
  hooks_path="$repo_root/hooks"
fi

mkdir_cmd="mkdir -p $hooks_path"
copy_cmd="cp hooks/pre-commit $hooks_path/pre-commit.moonlight"
chmod_cmd="chmod +x $hooks_path/pre-commit.moonlight"
link_cmd="ln -s pre-commit.moonlight $hooks_path/pre-commit"

if [ "$dry_run" -eq 1 ]; then
  echo "Would run: $mkdir_cmd"
  echo "Would run: $copy_cmd"
  echo "Would run: $chmod_cmd"
  if [ ! -e "$hooks_path/pre-commit" ]; then
    echo "Would create symlink: $link_cmd"
  else
    echo "Pre-commit hook already exists at $hooks_path/pre-commit"
  fi
  exit 0
fi

$mkdir_cmd
$copy_cmd
$chmod_cmd
if [ ! -e "$hooks_path/pre-commit" ]; then
  (cd "$hooks_path" && ln -s pre-commit.moonlight pre-commit)
fi

echo "✅ moonlight-commit installed to $hooks_path"
