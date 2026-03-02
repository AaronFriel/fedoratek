# fedoratek

Control-plane repo for building and publishing Fedora storage module packages (bcachefs + ZFS) through COPR, then consuming them in Fedora IoT image builds.

## What This Repo Does

- Defines COPR package sources in this GitHub repo (SCM `make_srpm` mode).
- Provides scripts to bootstrap COPR projects/packages.
- Provides GitHub Actions to trigger COPR builds on:
  - push to `main`
  - manual dispatch
  - scheduled cron rebuilds (daily, configurable target project set)

## Quick Start

1. Configure GitHub repository variables/secrets (see [`docs/github-actions-setup.md`](docs/github-actions-setup.md)).
2. Bootstrap COPR projects + package sources:

```bash
scripts/copr_bootstrap_projects.sh
```

3. Trigger initial builds (manual):

```bash
scripts/copr_rebuild_all.sh
```

4. For Fedora IoT compose/deploy guidance, see [`docs/fedora-iot-flow.md`](docs/fedora-iot-flow.md).

## COPR Form Defaults (If Creating Manually)

Use the short checklist in [`docs/copr-form-values.md`](docs/copr-form-values.md).
