# Fedora IoT Consumption Flow

This repo handles package build/rebuild orchestration. Fedora IoT work should
prefer the `*-kmod`/akmod-oriented package path over the DKMS packages.

Current validation boundary:

- `dkms-bcachefs` and `zfs-dkms` are not a sound Fedora IoT delivery path.
  `rpm-ostree` layering and later live DKMS installs both hit read-only
  filesystem constraints on Fedora IoT.
- `bcachefs-kmod` and `zfs-kmod` are currently proven only through SRPM
  generation. Treat first COPR binary builds and on-host `akmods` tests as the
  next validation step.
- COPR SCM `make_srpm` builds one SRPM per package build, not one SRPM per
  target chroot. If different Fedora releases need different packaging branches,
  split them into separate package definitions or projects rather than trying to
  auto-select a dist-git branch inside one package source.

After COPR publishes packages:

1. Compose custom IoT commit (`iot-commit`) with `--extra-repo` pointing to COPR results URL.
2. Publish/serve the OSTree repo.
3. Rebase devices once to your custom ref.
4. Continue with normal `rpm-ostree upgrade` / `rollback` lifecycle.

See prior runbook details in local research notes (gitignored): `research/fedora-iot-zfs-bcachefs-runbook.md`.
