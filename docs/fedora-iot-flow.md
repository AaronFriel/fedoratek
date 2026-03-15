# Fedora IoT Consumption Flow

This repo handles package build/rebuild orchestration. Fedora IoT work should
prefer the `*-kmod`/akmod-oriented package path over the DKMS packages.

Current validation boundary:

- `dkms-bcachefs` and `zfs-dkms` are not a sound Fedora IoT delivery path.
  `rpm-ostree` layering and later live DKMS installs both hit read-only
  filesystem constraints on Fedora IoT.
- `bcachefs-kmod` is now proven by live COPR builds on
  `fedora-43-x86_64` and `fedora-43-aarch64`.
- `zfs-kmod` is now proven by live COPR builds on
  `fedora-43-x86_64`, `fedora-43-aarch64`, and `fedora-44-x86_64`.
- `bcachefs-tools` is currently Fedora-43-only in practice; Fedora 44 and
  rawhide chroots fail with the current Fedora dist-git/package state.
- `zfs-kmod` currently fails on Fedora 44 aarch64 and rawhide chroots, so treat
  those as unsupported until upstream OpenZFS support changes or packaging
  workarounds are added.
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
