# GitHub Actions Setup for COPR Automation

## Repository Variables

Set these in GitHub -> Settings -> Secrets and variables -> Actions -> Variables.

- `COPR_OWNER` (example: `friel`)
- `COPR_PROJECT_TESTING` (default expected: `fedoratek-testing`)
- `COPR_PROJECT_STABLE` (default expected: `fedoratek-stable`)
- `COPR_TARGET_CHROOTS`
  - optional global override for all package rebuilds
  - leave unset if you want the repo's per-package default matrix
- `COPR_CHROOTS_BCACHEFS_TOOLS`
  - optional override
  - default in repo script: `fedora-43-x86_64,fedora-43-aarch64`
- `COPR_CHROOTS_BCACHEFS_KMOD`
  - optional override
  - default in repo script: `fedora-43-x86_64,fedora-43-aarch64`
- `COPR_CHROOTS_ZFS_DKMS`
  - optional override
  - default in repo script: all enabled project chroots
- `COPR_CHROOTS_ZFS_KMOD`
  - optional override
  - default in repo script: `fedora-43-x86_64,fedora-43-aarch64,fedora-44-x86_64`
- `COPR_PUSH_TARGET` (`testing`, `stable`, or `both`; default is `stable`)
- `COPR_SCHEDULE_TARGET` (`testing`, `stable`, or `both`; recommended: `both`)
- `COPR_SCM_BRANCH` (default `main`)
- `COPR_REPO_URL` (default `https://github.com/aaronfriel/fedoratek.git`)

## Repository Secrets

Set these in GitHub -> Settings -> Secrets and variables -> Actions -> Secrets.

- `COPR_LOGIN`
- `COPR_TOKEN`

`COPR_OWNER` is used as the `username` field in `~/.config/copr`, so it should match your Copr account/project owner (for example `friel`).

Get token material from COPR API page:

- https://copr.fedorainfracloud.org/api/

## Workflow behavior

- `copr-builds.yml`
  - Ensures COPR project/package SCM config matches this repo before triggering rebuilds.
  - Uses package-specific default chroot lists unless `COPR_TARGET_CHROOTS` or
    one of the package-specific `COPR_CHROOTS_*` variables overrides them.
  - Push to `main` touching packaging/scripts/workflow files: triggers `COPR_PUSH_TARGET` (default `stable`).
  - Daily cron: triggers `COPR_SCHEDULE_TARGET` (default `both`).
  - Manual dispatch: choose testing/stable/both.

## Stable-only profile (your current plan)

Set:

- `COPR_OWNER=friel`
- `COPR_PROJECT_STABLE=fedoratek-stable`
- `COPR_PUSH_TARGET=stable`
- `COPR_SCHEDULE_TARGET=stable`

Then bootstrap locally with:

```bash
make bootstrap
```
