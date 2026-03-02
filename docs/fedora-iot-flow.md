# Fedora IoT Consumption Flow

This repo handles package build/rebuild orchestration. After COPR publishes packages:

1. Compose custom IoT commit (`iot-commit`) with `--extra-repo` pointing to COPR results URL.
2. Publish/serve the OSTree repo.
3. Rebase devices once to your custom ref.
4. Continue with normal `rpm-ostree upgrade` / `rollback` lifecycle.

See prior runbook details in local research notes (gitignored): `research/fedora-iot-zfs-bcachefs-runbook.md`.
