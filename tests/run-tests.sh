#!/usr/bin/env bash
set -euo pipefail

# helper function to run commit at a given faketime and branch with message
# outputs result

test_commit() {
  local faketime="$1"
  local msg="$2"
  local branch="$3"
  echo -n "→ Testing at $faketime on branch '$branch' with message \"$msg\" ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  echo "# $$" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git checkout -b "$branch"
  echo "change" >> README.md
  git add README.md

  if faketime -f "$faketime" git commit -q -m "$msg"; then
    echo "✅"
    return 0
  else
    echo "❌"
    return 1
  fi
}

test_installer() {
  local label="$1"
  local installer_cmd="$2"
  echo -n "→ Testing installer via $label ... "
  rm -rf /tmp/install-repo && mkdir -p /tmp/install-repo
  cd /tmp/install-repo
  git init -q
  eval "$installer_cmd" >/tmp/moonlight-install.log

  test -x .git/hooks/pre-commit.moonlight
  test -x .git/hooks/commit-msg.moonlight
  test -L .git/hooks/pre-commit
  test -L .git/hooks/commit-msg

  echo "# installer" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git checkout -q -b feature/installer
  echo "change" >> README.md
  git add README.md

  if faketime -f "2025-04-30 10:15:00" git commit -q -m "feature during hours"; then
    echo "❌"
    echo "Installed hooks should have blocked the commit"; exit 1
  fi

  echo "✅"
}

test_installer_rejects_unknown_args() {
  echo -n "→ Testing installer rejects unknown arguments ... "
  rm -rf /tmp/install-repo && mkdir -p /tmp/install-repo
  cd /tmp/install-repo
  git init -q

  if /usr/src/app/install.sh --force >/tmp/moonlight-install-unknown.log 2>&1; then
    echo "❌"
    echo "Installer should reject unknown arguments"; exit 1
  fi

  grep -q "Usage: ./install.sh \\[--dry-run\\]" /tmp/moonlight-install-unknown.log
  test ! -e .git/hooks/pre-commit.moonlight
  test ! -e .git/hooks/commit-msg.moonlight

  echo "✅"
}

test_installer_rejects_extra_args() {
  echo -n "→ Testing installer rejects extra arguments ... "
  rm -rf /tmp/install-repo && mkdir -p /tmp/install-repo
  cd /tmp/install-repo
  git init -q

  if /usr/src/app/install.sh --dry-run --force >/tmp/moonlight-install-extra.log 2>&1; then
    echo "❌"
    echo "Installer should reject extra arguments"; exit 1
  fi

  grep -q "Usage: ./install.sh \\[--dry-run\\]" /tmp/moonlight-install-extra.log
  test ! -e .git/hooks/pre-commit.moonlight
  test ! -e .git/hooks/commit-msg.moonlight

  echo "✅"
}

test_installer_respects_relative_hooks_path_from_subdir() {
  echo -n "→ Testing installer resolves relative hooksPath from subdirectory ... "
  rm -rf /tmp/install-repo && mkdir -p /tmp/install-repo/src
  cd /tmp/install-repo
  git init -q
  git config core.hooksPath .githooks
  cd src

  /usr/src/app/install.sh >/tmp/moonlight-install-relative-hookspath.log

  test -x /tmp/install-repo/.githooks/pre-commit.moonlight
  test -x /tmp/install-repo/.githooks/commit-msg.moonlight
  test -L /tmp/install-repo/.githooks/pre-commit
  test -L /tmp/install-repo/.githooks/commit-msg
  test ! -e /tmp/install-repo/src/.githooks/pre-commit.moonlight
  test ! -e /tmp/install-repo/src/.githooks/commit-msg.moonlight

  echo "✅"
}

test_installer_cleans_downloaded_hooks_from_custom_tmpdir() {
  echo -n "→ Testing installer cleans downloaded hooks from custom TMPDIR ... "
  rm -rf /tmp/install-repo /tmp/moonlight-custom-tmp
  mkdir -p /tmp/install-repo /tmp/moonlight-custom-tmp
  cd /tmp/install-repo
  git init -q

  TMPDIR=/tmp/moonlight-custom-tmp MOONLIGHT_COMMIT_RAW_BASE=file:///usr/src/app sh < /usr/src/app/install.sh >/tmp/moonlight-install-custom-tmp.log

  test -x .git/hooks/pre-commit.moonlight
  test -x .git/hooks/commit-msg.moonlight
  test -z "$(find /tmp/moonlight-custom-tmp -type f -name 'moonlight-commit-*' -print -quit)"

  echo "✅"
}

test_installer_preserves_existing_dangling_hook_symlinks() {
  echo -n "→ Testing installer preserves existing dangling hook symlinks ... "
  rm -rf /tmp/install-repo && mkdir -p /tmp/install-repo
  cd /tmp/install-repo
  git init -q
  ln -s missing-pre-commit .git/hooks/pre-commit

  /usr/src/app/install.sh >/tmp/moonlight-install-dangling-hook.log

  test -x .git/hooks/pre-commit.moonlight
  test -x .git/hooks/commit-msg.moonlight
  test -L .git/hooks/pre-commit
  test "$(readlink .git/hooks/pre-commit)" = "missing-pre-commit"
  test -L .git/hooks/commit-msg

  echo "✅"
}

test_rejects_invalid_block_window_config() {
  echo -n "→ Testing hooks reject invalid block window config ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  echo "# invalid config" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git checkout -q -b feature/invalid-config
  echo "change" >> README.md
  git add README.md

  if MOONLIGHT_BLOCK_START=abc faketime -f "2025-04-30 10:15:00" git commit -q -m "invalid config" >/tmp/moonlight-invalid-config.log 2>&1; then
    echo "❌"
    echo "Invalid blockStart should have failed"; exit 1
  fi

  grep -q "moonlight-commit.blockStart must be an integer from 0 to 23" /tmp/moonlight-invalid-config.log

  if MOONLIGHT_BLOCK_START=10 MOONLIGHT_BLOCK_END=10 faketime -f "2025-04-30 10:15:00" git commit -q -m "equal config" >/tmp/moonlight-equal-config.log 2>&1; then
    echo "❌"
    echo "Equal blockStart and blockEnd should have failed"; exit 1
  fi

  grep -q "moonlight-commit.blockStart must not equal blockEnd" /tmp/moonlight-equal-config.log

  echo "✅"
}

test_commit_msg_rejects_invalid_day_config() {
  echo -n "→ Testing commit-msg rejects invalid day config ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  echo "message" > /tmp/moonlight-commit-message

  if MOONLIGHT_BLOCK_DAYS=1,8 /usr/src/app/hooks/commit-msg /tmp/moonlight-commit-message >/tmp/moonlight-invalid-days.log 2>&1; then
    echo "❌"
    echo "Invalid blockDays should have failed"; exit 1
  fi

  grep -q "moonlight-commit.blockDays must contain comma-separated integers from 1 to 7" /tmp/moonlight-invalid-days.log

  echo "✅"
}

test_hooks_reject_empty_day_entries() {
  echo -n "→ Testing hooks reject empty block day entries ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  echo "# empty day entries" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git checkout -q -b feature/empty-days
  echo "change" >> README.md
  git add README.md

  if MOONLIGHT_BLOCK_DAYS=1,,2 faketime -f "2025-04-30 10:15:00" git commit -q -m "empty day config" >/tmp/moonlight-empty-days.log 2>&1; then
    echo "❌"
    echo "Empty blockDays entries should have failed"; exit 1
  fi

  grep -q "moonlight-commit.blockDays must not contain empty entries" /tmp/moonlight-empty-days.log

  echo "✅"
}

assert_padded_block_days_still_block() {
  local log_path="$1"
  local message="$2"
  shift 2

  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  "$@"
  echo "# padded block day entries" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git checkout -q -b feature/padded-days
  echo "change" >> README.md
  git add README.md

  if faketime -f "2025-04-30 10:15:00" git commit -q -m "$message" >"$log_path" 2>&1; then
    echo "❌"
    echo "Padded blockDays entries should still block Wednesday commits"; exit 1
  fi

  grep -q "blocked between 9:00 and 17:00" "$log_path"
}

test_hooks_handle_padded_env_block_days() {
  echo -n "→ Testing hooks handle padded env block day entries ... "

  MOONLIGHT_BLOCK_DAYS='1, 2, 3,4,5 ' assert_padded_block_days_still_block \
    /tmp/moonlight-padded-days.log \
    "padded env day config" \
    true

  echo "✅"
}

test_hooks_handle_padded_git_config_block_days() {
  echo -n "→ Testing hooks handle padded git config block day entries ... "

  assert_padded_block_days_still_block \
    /tmp/moonlight-padded-config-days.log \
    "padded git day config" \
    git config moonlight-commit.blockDays '1, 2, 3,4,5 '

  echo "✅"
}

test_hooks_reject_empty_whitelist_org_entries() {
  echo -n "→ Testing hooks reject empty whitelist org entries ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  echo "# empty whitelist entries" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git checkout -q -b feature/empty-whitelist
  echo "change" >> README.md
  git add README.md

  if MOONLIGHT_WHITELIST_ORGS='myorg,,other' faketime -f "2025-04-30 10:15:00" git commit -q -m "empty whitelist config" >/tmp/moonlight-empty-whitelist.log 2>&1; then
    echo "❌"
    echo "Empty whitelist org entries should have failed"; exit 1
  fi

  grep -q "moonlight-commit.whitelistOrgs must not contain empty entries" /tmp/moonlight-empty-whitelist.log

  echo "✅"
}

test_hooks_reject_invalid_whitelist_org_entries() {
  echo -n "→ Testing hooks reject invalid whitelist org entries ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  echo "# invalid whitelist entries" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git checkout -q -b feature/invalid-whitelist
  echo "change" >> README.md
  git add README.md

  if MOONLIGHT_WHITELIST_ORGS='myorg,../other' \
    faketime -f "2025-04-30 10:15:00" git commit -q -m "invalid whitelist config" \
    >/tmp/moonlight-invalid-whitelist.log 2>&1; then
    echo "❌"
    echo "Invalid whitelist org entries should have failed"; exit 1
  fi

  grep -q "moonlight-commit.whitelistOrgs entries must be GitHub org names" \
    /tmp/moonlight-invalid-whitelist.log

  echo "✅"
}

test_whitelist_requires_github_origin() {
  echo -n "→ Testing whitelist only applies to GitHub origins ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  git config moonlight-commit.whitelistOrgs "myorg"
  echo "# non-github whitelist" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git remote add origin git@gitlab.com:myorg/repo.git
  git checkout -q -b feature/non-github-origin
  echo "change" >> README.md
  git add README.md

  if faketime -f "2025-04-30 10:00:00" git commit -q -m "non github origin" \
    >/tmp/moonlight-non-github-whitelist.log 2>&1; then
    echo "❌"
    echo "Non-GitHub origin should not match GitHub org whitelist"; exit 1
  fi

  grep -q "blocked between 9:00 and 17:00" /tmp/moonlight-non-github-whitelist.log

  echo "✅"
}

test_whitelist_rejects_plain_http_github_origin() {
  echo -n "→ Testing whitelist rejects plain HTTP GitHub origins ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  git config moonlight-commit.whitelistOrgs "myorg"
  echo "# insecure github whitelist" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git remote add origin http://github.com/myorg/repo.git
  git checkout -q -b feature/http-github-origin
  echo "change" >> README.md
  git add README.md

  if faketime -f "2025-04-30 10:00:00" git commit -q -m "http github origin" \
    >/tmp/moonlight-http-github-whitelist.log 2>&1; then
    echo "❌"
    echo "Plain HTTP GitHub origin should not match GitHub org whitelist"; exit 1
  fi

  grep -q "blocked between 9:00 and 17:00" /tmp/moonlight-http-github-whitelist.log

  echo "✅"
}

test_whitelist_requires_github_repo_path() {
  echo -n "→ Testing whitelist requires GitHub owner/repo origins ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  git config moonlight-commit.whitelistOrgs "myorg"
  echo "# missing github repo" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git remote add origin https://github.com/myorg
  git checkout -q -b feature/missing-github-repo
  echo "change" >> README.md
  git add README.md

  if faketime -f "2025-04-30 10:00:00" git commit -q -m "missing github repo" \
    >/tmp/moonlight-missing-github-repo.log 2>&1; then
    echo "❌"
    echo "GitHub origin without owner/repo should not match org whitelist"; exit 1
  fi

  grep -q "blocked between 9:00 and 17:00" /tmp/moonlight-missing-github-repo.log

  echo "✅"
}

test_whitelist_rejects_overlong_github_repo_names() {
  echo -n "→ Testing whitelist rejects overlong GitHub repo names ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  git config moonlight-commit.whitelistOrgs "myorg"
  echo "# overlong github repo" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  long_repo=$(printf 'a%.0s' $(seq 1 101))
  git remote add origin "git@github.com:myorg/${long_repo}.git"
  git checkout -q -b feature/overlong-github-repo
  echo "change" >> README.md
  git add README.md

  if faketime -f "2025-04-30 10:00:00" git commit -q -m "overlong github repo" \
    >/tmp/moonlight-overlong-github-repo.log 2>&1; then
    echo "❌"
    echo "GitHub origin with overlong repo name should not match org whitelist"; exit 1
  fi

  grep -q "blocked between 9:00 and 17:00" /tmp/moonlight-overlong-github-repo.log

  echo "✅"
}

test_hooks_block_midnight_window() {
  echo -n "→ Testing hooks block midnight window ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  echo "# midnight block" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git checkout -q -b feature/midnight
  echo "change" >> README.md
  git add README.md

  if MOONLIGHT_BLOCK_START=0 MOONLIGHT_BLOCK_END=1 faketime -f "2025-04-30 00:15:00" git commit -q -m "midnight commit" >/tmp/moonlight-midnight.log 2>&1; then
    echo "❌"
    echo "Midnight block window should have failed"; exit 1
  fi

  grep -q "Commit message 'midnight commit' blocked between 0:00 and 1:00" /tmp/moonlight-midnight.log

  echo "✅"
}

test_hooks_block_overnight_window() {
  echo -n "→ Testing hooks block overnight windows ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks
  echo "# overnight block" > README.md
  git add README.md
  git commit --no-verify -q -m "init"

  git checkout -q -b feature/overnight-late
  echo "late" >> README.md
  git add README.md
  if MOONLIGHT_BLOCK_START=22 MOONLIGHT_BLOCK_END=6 faketime -f "2025-04-30 23:15:00" git commit -q -m "late commit" >/tmp/moonlight-overnight-late.log 2>&1; then
    echo "❌"
    echo "Late overnight block window should have failed"; exit 1
  fi
  git reset -q --hard HEAD
  grep -q "Commit message 'late commit' blocked between 22:00 and 6:00" /tmp/moonlight-overnight-late.log

  git checkout -q -b feature/overnight-early
  echo "early" >> README.md
  git add README.md
  if MOONLIGHT_BLOCK_START=22 MOONLIGHT_BLOCK_END=6 faketime -f "2025-05-01 02:15:00" git commit -q -m "early commit" >/tmp/moonlight-overnight-early.log 2>&1; then
    echo "❌"
    echo "Early overnight block window should have failed"; exit 1
  fi
  git reset -q --hard HEAD
  grep -q "Commit message 'early commit' blocked between 22:00 and 6:00" /tmp/moonlight-overnight-early.log

  git checkout -q -b feature/overnight-midday
  echo "midday" >> README.md
  git add README.md
  if ! MOONLIGHT_BLOCK_START=22 MOONLIGHT_BLOCK_END=6 faketime -f "2025-04-30 12:15:00" git commit -q -m "midday commit" >/tmp/moonlight-overnight-midday.log 2>&1; then
    echo "❌"
    echo "Midday outside overnight block window should have been allowed"; exit 1
  fi

  echo "✅"
}

test_pre_commit_rejects_unknown_args() {
  echo -n "→ Testing pre-commit rejects unknown arguments ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks

  if /usr/src/app/hooks/pre-commit --force >/tmp/moonlight-pre-commit-unknown.log 2>&1; then
    echo "❌"
    echo "pre-commit should reject unknown arguments"; exit 1
  fi

  grep -q "Usage: pre-commit \\[--dry-run\\]" /tmp/moonlight-pre-commit-unknown.log

  echo "✅"
}

test_pre_commit_rejects_extra_args() {
  echo -n "→ Testing pre-commit rejects extra arguments ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  git config core.hooksPath /usr/src/app/hooks

  if /usr/src/app/hooks/pre-commit --dry-run --force >/tmp/moonlight-pre-commit-extra.log 2>&1; then
    echo "❌"
    echo "pre-commit should reject extra arguments"; exit 1
  fi

  grep -q "Usage: pre-commit \\[--dry-run\\]" /tmp/moonlight-pre-commit-extra.log

  echo "✅"
}

test_commit_msg_rejects_missing_args() {
  echo -n "→ Testing commit-msg rejects missing message file argument ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q

  if /usr/src/app/hooks/commit-msg >/tmp/moonlight-commit-msg-missing.log 2>&1; then
    echo "❌"
    echo "commit-msg should reject missing arguments"; exit 1
  fi

  grep -q "Usage: commit-msg <commit-msg-file>" /tmp/moonlight-commit-msg-missing.log

  echo "✅"
}

test_commit_msg_rejects_missing_message_file() {
  echo -n "→ Testing commit-msg rejects missing message file path ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q

  if /usr/src/app/hooks/commit-msg /tmp/moonlight-missing-message >/tmp/moonlight-commit-msg-missing-file.log 2>&1; then
    echo "❌"
    echo "commit-msg should reject missing message files"; exit 1
  fi

  grep -q "commit-msg file must exist: /tmp/moonlight-missing-message" /tmp/moonlight-commit-msg-missing-file.log

  echo "✅"
}

test_commit_msg_rejects_message_directory() {
  echo -n "→ Testing commit-msg rejects message directory paths ... "
  rm -rf /tmp/repo /tmp/moonlight-message-dir && mkdir -p /tmp/repo /tmp/moonlight-message-dir
  cd /tmp/repo
  git init -q

  if /usr/src/app/hooks/commit-msg /tmp/moonlight-message-dir >/tmp/moonlight-commit-msg-dir.log 2>&1; then
    echo "❌"
    echo "commit-msg should reject directory message paths"; exit 1
  fi

  grep -q "commit-msg file must exist: /tmp/moonlight-message-dir" /tmp/moonlight-commit-msg-dir.log

  echo "✅"
}

test_commit_msg_rejects_extra_args() {
  echo -n "→ Testing commit-msg rejects extra arguments ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo
  cd /tmp/repo
  git init -q
  echo "message" > /tmp/moonlight-commit-message

  if /usr/src/app/hooks/commit-msg /tmp/moonlight-commit-message extra >/tmp/moonlight-commit-msg-extra.log 2>&1; then
    echo "❌"
    echo "commit-msg should reject extra arguments"; exit 1
  fi

  grep -q "Usage: commit-msg <commit-msg-file>" /tmp/moonlight-commit-msg-extra.log

  echo "✅"
}

test_pre_commit_defers_to_relative_hooks_path_commit_msg_from_subdir() {
  echo -n "→ Testing pre-commit resolves relative hooksPath from subdirectory ... "
  rm -rf /tmp/repo && mkdir -p /tmp/repo/.githooks /tmp/repo/src
  cd /tmp/repo
  git init -q
  git config core.hooksPath .githooks
  cp /usr/src/app/hooks/pre-commit .githooks/pre-commit
  cp /usr/src/app/hooks/commit-msg .githooks/commit-msg
  chmod +x .githooks/pre-commit .githooks/commit-msg
  echo "# relative hooksPath" > README.md
  git add README.md
  git commit --no-verify -q -m "init"
  git checkout -q -b feature/relative-hooks
  cd src
  echo "change" > nested.txt
  git add nested.txt

  if faketime -f "2025-04-30 10:15:00" git commit -q -m "nested commit" >/tmp/moonlight-relative-hookspath.log 2>&1; then
    echo "❌"
    echo "Blocked-window commit without override should have failed"; exit 1
  fi

  grep -q "Commit message 'nested commit' blocked" /tmp/moonlight-relative-hookspath.log

  echo "✅"
}

test_page_assets() {
  echo -n "→ Testing landing page local asset references ... "
  cd /usr/src/app

  while IFS= read -r url; do
    case "$url" in
      ""|"#"|http://*|https://*|mailto:*|tel:*)
        continue
        ;;
    esac
    if [ ! -e "pages/$url" ]; then
      echo "❌"
      echo "Missing page asset: $url"; exit 1
    fi
  done < <(grep -Eo '(src|href)="[^"]+"' pages/index.html | sed -E 's/^[^"]+"([^"]+)"/\1/')

  echo "✅"
}

echo
echo "🧪 moonlight-commit automated tests"
echo "-----------------------------------"

test_page_assets

# 1) During working hours Mon-Fri → should be blocked
# 2025-04-30 is Wednesday
if test_commit "2025-04-30 10:15:00" "feature during hours" "feature/main"; then
  echo "✗ Should have been blocked"; exit 1
else
  echo "✓ Blocked as expected"
fi

# 2) Override keyword during hours → allowed
if test_commit "2025-04-30 14:00:00" "hotfix-x [override]" "feature/main"; then
  echo "✓ Override works"
else
  echo "✗ Should have been allowed"; exit 1
fi

# 3) On hotfix branch during hours → allowed
if test_commit "2025-04-30 11:00:00" "fix bug" "hotfix/urgent"; then
  echo "✓ Hotfix branch pass-through"
else
  echo "✗ Hotfix branch should pass"; exit 1
fi

# 4) On vacation branch during hours → allowed
if test_commit "2025-04-30 11:00:00" "vacation day commit" "vacation/dayoff"; then
  echo "✓ Vacation branch pass-through"
else
  echo "✗ Vacation branch should pass"; exit 1
fi

# 5) Weekend commit during blocked hours → allowed (Sat=6)
if test_commit "2025-05-03 10:00:00" "weekend commit" "feature/weekend"; then
  echo "✓ Weekend commit allowed"
else
  echo "✗ Weekend commit should pass"; exit 1
fi

# 6) After hours commit → allowed
if test_commit "2025-04-30 20:30:00" "feature at night" "feature/main"; then
  echo "✓ After-hours commit allowed"
else
  echo "✗ Should have been allowed"; exit 1
fi

# 7) Whitelisted org bypass
rm -rf /tmp/repo && mkdir -p /tmp/repo && cd /tmp/repo
git init -q
git config core.hooksPath /usr/src/app/hooks
git config moonlight-commit.whitelistOrgs "other-org, myorg"
# prepare repo
echo "# test" > README.md
git add README.md
git commit --no-verify -q -m "init"
git remote add origin git@github.com:myorg/repo.git

# commit during working hours should succeed
git checkout -b feature/main
echo "change" >> README.md
git add README.md
if faketime -f "2025-04-30 10:00:00" git commit -q -m "commit during hours"; then
  echo "✓ Whitelisted org bypass works"
else
  echo "✗ Whitelisted org commit blocked"; exit 1
fi

test_installer "local script" "/usr/src/app/install.sh"
test_installer "download fallback" "MOONLIGHT_COMMIT_RAW_BASE=file:///usr/src/app sh < /usr/src/app/install.sh"
test_installer_rejects_unknown_args
test_installer_rejects_extra_args
test_installer_respects_relative_hooks_path_from_subdir
test_installer_cleans_downloaded_hooks_from_custom_tmpdir
test_installer_preserves_existing_dangling_hook_symlinks
test_rejects_invalid_block_window_config
test_commit_msg_rejects_invalid_day_config
test_hooks_reject_empty_day_entries
test_hooks_handle_padded_env_block_days
test_hooks_handle_padded_git_config_block_days
test_hooks_reject_empty_whitelist_org_entries
test_hooks_reject_invalid_whitelist_org_entries
test_whitelist_requires_github_origin
test_whitelist_rejects_plain_http_github_origin
test_whitelist_requires_github_repo_path
test_whitelist_rejects_overlong_github_repo_names
test_hooks_block_midnight_window
test_hooks_block_overnight_window
test_pre_commit_rejects_unknown_args
test_pre_commit_rejects_extra_args
test_commit_msg_rejects_missing_args
test_commit_msg_rejects_missing_message_file
test_commit_msg_rejects_message_directory
test_commit_msg_rejects_extra_args
test_pre_commit_defers_to_relative_hooks_path_commit_msg_from_subdir

echo
echo "🎉 All tests passed!"
