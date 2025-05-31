#!/bin/bash
# moonlight-commit installer - installs hooks globally with executable permissions and configures core.hooksPath

set -e

echo "Installing moonlight-commit hooks globally..."

mkdir -p ~/.git-hooks

cp hooks/pre-commit ~/.git-hooks/pre-commit
cp hooks/commit-msg ~/.git-hooks/commit-msg

chmod +x ~/.git-hooks/pre-commit
chmod +x ~/.git-hooks/commit-msg

git config --global core.hooksPath ~/.git-hooks

echo "✅ moonlight-commit installed globally!"
echo "🌙 Hack freely after hours."
