# fedoratek

Control-plane repo for building and publishing Fedora storage module packages (bcachefs + ZFS) through COPR, then consuming them in Fedora IoT image builds.

## What This Repo Does

- Defines COPR package sources in this GitHub repo (SCM `make_srpm` mode).
- Provides scripts to bootstrap COPR projects/packages.
- Provides GitHub Actions to trigger COPR builds on:
  - push to `main`
  - manual dispatch
  - scheduled cron rebuilds (daily, configurable target project set)
- Builds both legacy DKMS-oriented packages and parallel akmod-oriented kernel module packages.

## Quick Start

1. Configure GitHub repository variables/secrets (see [`docs/github-actions-setup.md`](docs/github-actions-setup.md)).
2. Bootstrap COPR package sources for `fedoratek-stable`:

```bash
scripts/copr_bootstrap_projects.sh
```

To bootstrap both testing+stable instead: `make bootstrap-both`

3. Trigger initial builds (manual):

```bash
scripts/copr_rebuild_all.sh
```

4. For Fedora IoT compose/deploy guidance, see [`docs/fedora-iot-flow.md`](docs/fedora-iot-flow.md).

## Fast Iteration

You do not need to wait on COPR for every packaging mistake.

Simulate a COPR package build locally in a Fedora container:

```bash
scripts/local_copr_build.sh packaging/bcachefs-kmod
scripts/local_copr_build.sh --srpm-only packaging/bcachefs
```

This runs the package's `.copr/Makefile` in a Fedora container, generates the
SRPM, and by default also rebuilds that SRPM locally to approximate COPR's
binary-RPM phase. Use `--arch aarch64` when your container runtime supports
multi-arch emulation.

Poll public COPR builds and fetch logs without `copr-cli`:

```bash
scripts/copr_public_watch.py friel/fedoratek-stable --package bcachefs-kmod
scripts/copr_public_watch.py friel/fedoratek-stable --build-id 10228721 --show-log build.log --chroot fedora-43-x86_64
scripts/copr_public_watch.py friel/fedoratek-stable --package zfs-kmod --download-dir .scratch/copr-logs
```

The watcher uses only public COPR APIs and result URLs, so it works for failed
public builds without any COPR credentials.

## Current COPR Package Sources

This repo currently registers four COPR SCM package definitions:

- `bcachefs-tools` from [`packaging/bcachefs`](packaging/bcachefs/README.md)
- `bcachefs-kmod` from [`packaging/bcachefs-kmod`](packaging/bcachefs-kmod/README.md)
- `zfs-dkms` from [`packaging/zfs`](packaging/zfs/README.md)
- `zfs-kmod` from [`packaging/zfs-kmod`](packaging/zfs-kmod/README.md)

The `*-kmod` source packages are intended to emit akmod-oriented outputs
alongside kmod metadata, while the original DKMS paths remain in place for
mutable Fedora systems and comparison work.

Current validation boundary:

- `bcachefs-kmod` and `zfs-kmod` both generate real Fedora 43 SRPMs.
- Fedora IoT layering of the DKMS packages is not a viable path; keep those for
  mutable Fedora systems and comparison work.
- COPR SCM `make_srpm` builds one SRPM per package build, so each package source
  should track one Fedora dist-git line at a time. The bcachefs package sources
  are currently pinned to Fedora 43 (`f43`), matching the default target
  chroots.

## COPR Form Defaults (If Creating Manually)

Use the short checklist in [`docs/copr-form-values.md`](docs/copr-form-values.md).
