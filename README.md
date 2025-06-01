# moonlight-commit

**Prevent accidental commits during work hours — even from coding agents.**

`moonlight-commit` is a Git hook system that blocks commits during configurable working hours and days (default 9am–5pm Monday–Friday), with exceptions for hotfix and vacation branches, override commit message flags, and whitelisted GitHub organizations.

## Features

- Configurable block window via Git config
- Day-of-week filtering (defaults to Mon–Fri)
- Hotfix and vacation branch exemptions
- Override flag `[override]` in commit messages
- GitHub organization whitelist

## Installation

Install locally in any repository:

```bash
curl -s https://moonlight-commit.com/install.sh | bash
```

Run the installer with `--dry-run` to preview actions.

## Uninstall

To remove moonlight-commit delete `.git/hooks/pre-commit.moonlight` and the
`pre-commit` symlink created by the installer.

## Configuration

Customize timings, days, and org whitelist via git config or environment vars:

```bash
# Set block hours (inclusive start, exclusive end)
git config moonlight-commit.blockStart 10
git config moonlight-commit.blockEnd 16
# Or use environment variables
export MOONLIGHT_BLOCK_START=10
export MOONLIGHT_BLOCK_END=16

# Set block days (1=Monday, 7=Sunday)
git config moonlight-commit.blockDays 1,2,3,4,5
export MOONLIGHT_BLOCK_DAYS="1,2,3,4,5"

# Whitelist GitHub orgs (comma-separated)
git config moonlight-commit.whitelistOrgs your-org,another-org
export MOONLIGHT_WHITELIST_ORGS="your-org,another-org"
```

## Branch Exceptions

Branches containing `hotfix` or `vacation` bypass blocking.

Use `[override]` in commit messages to force a commit during the block window.

## Testing

Automated tests run inside Docker with time and day simulation.

```bash
docker build -t moonlight-commit-test tests
docker run --rm moonlight-commit-test
```

Quick check in any repo:

```bash
.git/hooks/pre-commit --dry-run
```

## Website

A minimal static landing page is available at [moonlightcommit.com](https://moonlightcommit.com). The same HTML file (`index.html`) is included in this repo for GitHub Pages hosting. The GitHub link on the page is populated by a small script. If you host the page on a custom domain, edit the `data-repo-owner` attribute in the script tag to point to your GitHub username so the link resolves correctly.

## License

MIT License

## Credits

Built by indie devs, for indie devs. Inspired by late nights, side hustles, and the eternal right to moonlight.

⭐ **Star this repo** if you find it useful — and [buy me a coffee](https://buymeacoffee.com/moonlight).
