# Make akmod-zfs work on Fedora IoT host 10.133.183.26

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository does not contain a `PLANS.md` file. Maintain this document in accordance with the fallback rules from `/home/friel/.codex/skills/execplan/references/PLANS.md`.

## Purpose / Big Picture

The goal is to make `akmod-zfs` work on the Fedora IoT 43 x86_64 host at `10.133.183.26` under Secure Boot. After this work, a novice should be able to build or install the corrected `akmod-zfs` RPM, let the host build and sign its own kernel-specific ZFS module with `akmods`, enroll the host key once through MOK, and then load both `zfs` and `bcachefs` successfully after reboot. The final user-visible proof is not only that `modprobe` works, but also that the host can create and use `zfs`, `bcachefs`, and `btrfs` loopback-backed filesystems.

## Progress

- [x] (2026-03-15 09:40Z) Confirmed Fedora IoT plus DKMS is the wrong model for this host and added parallel akmod-oriented packaging in the repo.
- [x] (2026-03-15 09:40Z) Proved that `packaging/zfs-kmod` can build successfully in COPR and emit `zfs-kmod` artifacts, but the embedded akmod SRPM was not consumable by `akmodsbuild` on the host.
- [x] (2026-03-15 09:40Z) Added repo changes so the outer `akmod-zfs` package rewrites the inner spec toward host-side `akmods` consumption instead of producing only central-build artifacts.
- [x] (2026-03-16 05:57Z) Fixed the `zfs-kmod` inner-SRPM path so the host can rebuild a kernel-specific `kmod-zfs-$(uname -r)` package, then installed it on `10.133.183.26` and confirmed `zfs.ko` is signed by the host akmods key.
- [x] (2026-03-16 05:57Z) Installed `bcachefs-tools` and `akmod-bcachefs` on `10.133.183.26` and aligned both `zfs.ko` and `bcachefs.ko` to the same host akmods key.
- [x] (2026-03-16 08:20Z) Enrolled the host akmods key `localhost_1773642889_6b6811d2` in MOK and confirmed `modprobe zfs` plus `modprobe bcachefs` succeed under Secure Boot.
- [x] (2026-03-16 08:30Z) Installed matching OpenZFS userspace packages on the host so `zpool` and `zfs` are available alongside the module.
- [x] (2026-03-16 08:35Z) Created writable loopback-backed `bcachefs`, `btrfs`, and `zfs` filesystems on the host.
- [x] (2026-03-16 08:45Z) Rebooted the host, reconnected over SSH, reloaded both out-of-tree modules, and reattached all three loopback-backed filesystems successfully.

## Surprises & Discoveries

- Observation: The original `packaging/zfs-kmod` work was genuinely akmod-oriented, but the successful COPR outputs still did not prove host usability because the embedded SRPM inside `akmod-zfs` was the critical artifact for `akmodsbuild`.
  Evidence: The host could install `akmod-zfs`, but `akmods --force --akmod zfs` initially rebuilt the wrong shape of package.

- Observation: OpenZFS `srpm-common` stages sources through a temporary `rpmbuild/SOURCES` directory created by the generated `Makefile`, not directly from the repository root.
  Evidence: Local Fedora 43 build failure before the fix: `Bad file: /tmp/zfs-build-root-.../SOURCES/prepare-akmod-spec.sh: No such file or directory`.

- Observation: Once `zfs.ko` and `bcachefs.ko` are both signed by the same host akmods key, Secure Boot rejection collapses to a single firmware-trust problem instead of separate packaging problems.
  Evidence: Before MOK enrollment, `modinfo -F signer zfs` and `modinfo -F signer bcachefs` both reported `localhost_1773642889_6b6811d2`, while `modprobe` still failed with `Key was rejected by service`.

- Observation: Matching ZFS userspace was required to make the host actually useful for filesystem operations.
  Evidence: The host could load `zfs.ko`, but `zpool` was absent until matching `zfs`, `libzfs7`, `libzpool7`, and `libnvpair3` packages from the same OpenZFS source line were installed.

- Observation: Reboot reliability for the proof workload depends on durable backing file paths, not stable `/dev/loopN` numbering.
  Evidence: After reboot the loop device numbers changed, but `/var/tmp/btrfs-loop.img`, `/var/tmp/bcachefs-loop.img`, and `/var/tmp/zfs-loop.img` could still be reattached successfully.

## Decision Log

- Decision: Keep the fix focused on `packaging/zfs-kmod` and host validation instead of broadening the support matrix first.
  Rationale: The user explicitly wanted `akmod-zfs` working on Fedora IoT host `10.133.183.26`, not more COPR plumbing.
  Date/Author: 2026-03-15 / Codex

- Decision: Treat the embedded inner SRPM as the acceptance-critical artifact for ZFS.
  Rationale: Fedora IoT should install the outer `akmod-zfs` RPM, then `akmods` must rebuild a kernel-specific `kmod-zfs` locally and sign it with the host key.
  Date/Author: 2026-03-15 / Codex

- Decision: Re-sign the existing `bcachefs.ko` with the host akmods key instead of introducing a second trust root.
  Rationale: A single MOK enrollment step is cleaner than managing separate trust chains for ZFS and bcachefs.
  Date/Author: 2026-03-16 / Codex

- Decision: Build and install matching OpenZFS userspace from the same source line as the module instead of mixing in a mismatched external userspace package.
  Rationale: `zpool` and `zfs` userspace should track the module ABI and feature line to avoid avoidable ioctl and feature mismatches.
  Date/Author: 2026-03-16 / Codex

## Outcomes & Retrospective

Completed outcome: the Fedora IoT host now loads both `zfs` and `bcachefs` under Secure Boot using the host-local akmods signing flow. `akmod-zfs` was corrected so the host can produce its own kernel-specific ZFS module, the host MOK key `localhost_1773642889_6b6811d2` was enrolled, matching ZFS userspace was installed, and loopback-backed `zfs`, `bcachefs`, and `btrfs` filesystems were created and used successfully. A reboot and SSH reconnection proved the machine still comes back cleanly, both modules still load, and the filesystem proof can be reattached from the durable backing files.

The remaining gap is not functional breakage but productization: the matching ZFS userspace packages should be published through the normal repo/COPR path instead of relying on an ad hoc local install, and the bcachefs akmods path could still be tightened so the running-kernel `kmod-bcachefs-$(uname -r)` package is as explicit as the ZFS path.

## Context and Orientation

The repo path under active development for ZFS is `packaging/zfs-kmod`. Its `.copr/Makefile` is the COPR SCM `make_srpm` entrypoint. That file clones OpenZFS, runs `./configure --with-config=srpm`, patches the generated `rpm/generic/zfs-kmod.spec`, and emits an SRPM suitable for an outer `akmod-zfs` package. The file `packaging/zfs-kmod/akmod_install_override.specfrag` overrides the `%global akmod_install` macro so the outer package embeds a rewritten inner SRPM under `/usr/src/akmods/`. The helper `packaging/zfs-kmod/prepare-akmod-spec.sh` and its companion patch scripts shape the inner spec so host-side `akmodsbuild` can consume it.

The target host is `friel@10.133.183.26`. It is Fedora IoT 43 x86_64 with Secure Boot enabled. Its current proven state is: `akmod-zfs`, `akmod-bcachefs`, `bcachefs-tools`, and matching OpenZFS userspace are installed; `/dev/kvm` exists; `modprobe zfs` and `modprobe bcachefs` both succeed; and the host can create loopback-backed filesystems for `zfs`, `bcachefs`, and `btrfs`.

## Plan of Work

First, keep the outer SRPM generation deterministic. `packaging/zfs-kmod/.copr/Makefile` must continue to patch the generated OpenZFS `Makefile` so helper files are copied into the temporary `rpmbuild/SOURCES` directory used by `srpm-common`. Without that, the outer build fails before the inner akmod rewrite can happen.

Second, preserve the wildcard-spec handling in `packaging/zfs-kmod/akmod_install_override.specfrag` so host-side `akmodsbuild` can cope with the temporary spec filename it unpacks under `/tmp/akmodsbuild.*`.

Third, when validating host behavior, treat packaging, trust enrollment, and userspace as separate layers. The packaging layer is proven by building and installing `akmod-zfs`; the trust layer is proven by MOK enrollment and successful `modprobe`; and the userspace layer is proven by `zpool`/`zfs` commands creating a pool and dataset.

Fourth, keep reboot validation explicit. The out-of-tree modules must still load after reboot, and the loopback-backed proof filesystems must be recoverable from their backing image files even if loop device numbers change.

## Concrete Steps

From `/home/friel/c/aaronfriel/fedoratek`, build the akmod package with the local COPR simulator:

    ./scripts/local_copr_build.sh --release 43 packaging/zfs-kmod

Install the resulting RPMs on the host and let the host build and sign the running-kernel module:

    scp /tmp/.../akmod-zfs-*.rpm /tmp/.../kmod-zfs-*.rpm /tmp/.../zfs-kmod-common-*.rpm friel@10.133.183.26:/var/tmp/
    ssh friel@10.133.183.26 'sudo rpm -Uvh --replacepkgs /var/tmp/akmod-zfs-*.rpm /var/tmp/kmod-zfs-*.rpm /var/tmp/zfs-kmod-common-*.rpm'
    ssh friel@10.133.183.26 'sudo rm -f /var/cache/akmods/zfs/*; sudo akmods --force --kernels $(uname -r) --akmod zfs'

Verify the signed module and userspace layer:

    ssh friel@10.133.183.26 'rpm -q akmod-zfs kmod-zfs-$(uname -r); modinfo -F signer zfs; command -v zpool; command -v zfs'

Verify the Secure Boot runtime behavior and loopback-backed filesystem proof:

    ssh friel@10.133.183.26 'sudo modprobe zfs; sudo modprobe bcachefs; lsmod | grep -E "^(zfs|bcachefs)"'
    ssh friel@10.133.183.26 'sudo zpool create -f loopzfs /var/tmp/zfs-loop.img && sudo zfs create -o mountpoint=/var/mnt/zfs-loop loopzfs/test'
    ssh friel@10.133.183.26 'sudo bcachefs format --force /dev/loopX && sudo mount -t bcachefs /dev/loopX /var/mnt/bcachefs-loop'
    ssh friel@10.133.183.26 'sudo mkfs.btrfs -f /var/tmp/btrfs-loop.img && sudo mount -o loop /var/tmp/btrfs-loop.img /var/mnt/btrfs-loop'

After a reboot, reattach from the same backing image paths if needed:

    ssh friel@10.133.183.26 'sudo modprobe zfs; sudo modprobe bcachefs'
    ssh friel@10.133.183.26 'sudo zpool import -d /var/tmp loopzfs || true'
    ssh friel@10.133.183.26 'sudo mount -o loop /var/tmp/btrfs-loop.img /var/mnt/btrfs-loop || true'

## Validation and Acceptance

This work is successful when all of the following are true on `10.133.183.26`:

1. `rpm -q akmod-zfs kmod-zfs-$(uname -r)` reports the outer akmod and the running-kernel ZFS package.
2. `modinfo -F signer zfs` and `modinfo -F signer bcachefs` both report the host key `localhost_1773642889_6b6811d2`.
3. `sudo modprobe zfs` and `sudo modprobe bcachefs` succeed under Secure Boot.
4. `command -v zpool`, `command -v zfs`, `command -v bcachefs`, and `command -v mkfs.btrfs` all succeed.
5. The host can create or reattach writable loopback-backed `zfs`, `bcachefs`, and `btrfs` filesystems.
6. After reboot, the host still comes back cleanly over SSH, both out-of-tree modules still load, and the proof filesystems can be reattached from the durable backing image paths.

## Idempotence and Recovery

The local build is safe to rerun because `scripts/local_copr_build.sh` uses disposable containers and temporary output directories. The host install step uses `rpm -Uvh --replacepkgs`, which is safe for iterative packaging fixes. Before rerunning `akmods`, clear `/var/cache/akmods/zfs/*` so stale failed state does not hide a packaging fix. When testing the filesystems repeatedly, keep the backing image files in `/var/tmp` and recreate the transient loop devices as needed after reboot. Do not touch the unrelated untracked file `docs/ostree-fde-remote-unlock-redundant-root.md`.

## Artifacts and Notes

Critical proof snippets from the completed work:

    $ modinfo -F signer zfs
    localhost_1773642889_6b6811d2

    $ modinfo -F signer bcachefs
    localhost_1773642889_6b6811d2

    $ lsmod | grep -E '^(zfs|bcachefs)'
    bcachefs ...
    zfs ...

    $ zpool status -x
    all pools are healthy

    $ mount | grep -E 'btrfs|bcachefs|zfs'
    /var/mnt/btrfs-loop ... btrfs
    /var/mnt/bcachefs-loop ... bcachefs
    loopzfs/test ... zfs

## Interfaces and Dependencies

This work depends on Podman or Docker being available locally for `scripts/local_copr_build.sh`, on GitHub/OpenZFS network access to fetch sources, and on SSH access to `10.133.183.26`. The key repository files are `packaging/zfs-kmod/.copr/Makefile`, `packaging/zfs-kmod/akmod_install_override.specfrag`, `packaging/zfs-kmod/prepare-akmod-spec.sh`, `packaging/zfs-kmod/patch-openzfs-makefile.py`, and `packaging/zfs-kmod/patch-zfs-kmod-spec.py`.

Change note: Updated after full host validation to record successful MOK enrollment, successful Secure Boot module loading for both ZFS and bcachefs, matching ZFS userspace installation, and reboot-tested loopback filesystem proofs for ZFS, bcachefs, and btrfs.
