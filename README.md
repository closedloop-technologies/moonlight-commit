# moonlight-commit

**Protect your right to hack after hours.**

`moonlight-commit` is a Git hook system that blocks commits during configurable working hours and days (default 9am–5pm Monday–Friday), with exceptions for hotfix and vacation branches, override commit message flags, and whitelisted GitHub organizations.

## Features

- Configurable block window via Git config
- Day-of-week filtering (defaults to Mon–Fri)
- Hotfix and vacation branch exemptions
- Override flag `[override]` in commit messages
- GitHub organization whitelist

## Installation

Run the installer for global setup:

```bash
./install.sh
```

This copies hooks to `~/.git-hooks` and sets `core.hooksPath` globally. If you already
have a global hooks directory configured, the installer will prompt to back it up
before overriding. To remove the hooks and restore the previous configuration, run
`./install.sh --uninstall`.

## Uninstall

To remove moonlight-commit and restore your previous `core.hooksPath` value, run:

```bash
./install.sh --uninstall
```

## Configuration

Customize timings, days, and org whitelist:

```bash
# Set block hours (inclusive start, exclusive end)
git config moonlight-commit.blockStart 10
git config moonlight-commit.blockEnd 16

# Set block days (1=Monday, 7=Sunday)
git config moonlight-commit.blockDays 1,2,3,4,5

# Whitelist GitHub orgs (comma-separated)
git config moonlight-commit.whitelistOrgs your-org,another-org
```

## Branch Exceptions

Branches containing `hotfix` or `vacation` bypass blocking.

## Testing

Automated tests run inside Docker with time and day simulation.

```bash
docker build -t moonlight-commit-test tests
docker run --rm moonlight-commit-test
```

## Website

A minimal static landing page is available at [moonlightcommit.com](https://moonlightcommit.com). The same HTML file (`index.html`) is included in this repo for GitHub Pages hosting. The GitHub link on the page is populated by a small script. If you host the page on a custom domain, edit the `data-repo-owner` attribute in the script tag to point to your GitHub username so the link resolves correctly.

## License

MIT License

## Credits

Built by indie devs, for indie devs. Inspired by late nights, side hustles, and the eternal right to moonlight.
