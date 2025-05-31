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
  git commit -q -m "init"
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

echo
echo "🧪 moonlight-commit automated tests"
echo "-----------------------------------"

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
mkdir -p /tmp/repo && cd /tmp/repo
git init -q
git config core.hooksPath /usr/src/app/hooks
git config moonlight-commit.whitelistOrgs "myorg"
# prepare repo
echo "# test" > README.md
git add README.md
git commit -q -m "init"
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

echo
echo "🎉 All tests passed!"
