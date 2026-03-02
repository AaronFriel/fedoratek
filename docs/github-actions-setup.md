# GitHub Actions Setup for COPR Automation

## Repository Variables

Set these in GitHub -> Settings -> Secrets and variables -> Actions -> Variables.

- `COPR_OWNER` (example: `friel`)
- `COPR_PROJECT_TESTING` (default expected: `storage-modules-testing`)
- `COPR_PROJECT_STABLE` (default expected: `storage-modules-stable`)
- `COPR_TARGET_CHROOTS` (comma-separated, example: `fedora-43-x86_64,fedora-43-aarch64`)
- `COPR_SCHEDULE_TARGET` (`testing`, `stable`, or `both`; recommended: `both`)
- `COPR_SCM_BRANCH` (default `main`)
- `COPR_REPO_URL` (default `https://github.com/aaronfriel/fedoratek.git`)

## Repository Secrets

Set these in GitHub -> Settings -> Secrets and variables -> Actions -> Secrets.

- `COPR_LOGIN`
- `COPR_USERNAME`
- `COPR_TOKEN`

Get token material from COPR API page:

- https://copr.fedorainfracloud.org/api/

## Workflow behavior

- `copr-builds.yml`
  - Push to `main` touching packaging/scripts/workflow files: triggers testing builds.
  - Daily cron: triggers `COPR_SCHEDULE_TARGET` (default `both`).
  - Manual dispatch: choose testing/stable/both.
