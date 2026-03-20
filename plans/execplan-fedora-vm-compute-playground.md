# Turn Fedora IoT host 10.133.183.26 into a compute playground

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository does not contain a `PLANS.md` file. Maintain this document in accordance with the fallback rules from `/home/friel/.codex/skills/execplan/references/PLANS.md`.

## Purpose / Big Picture

The goal is to turn the Fedora VM at `10.133.183.26` into a flexible test host that can run several kinds of compute services: nested KVM virtual machines, remotely controlled libvirt guests through Cockpit, ordinary OCI containers through Podman, Firecracker microVM experiments, and a lightweight Kubernetes environment for local cluster experiments. After this work, a novice should be able to log into the host, see `/dev/kvm`, use Cockpit to create or inspect virtual machines, run Podman containers, and follow a documented path for Firecracker and Kubernetes experiments without guessing package names or host prerequisites.

## Progress

- [x] (2026-03-20 17:15Z) Captured the current host baseline on `10.133.183.26`: Fedora IoT 43, kernel `6.17.1-300.fc43.x86_64`, CPU virtualization flag `svm`, and `/dev/kvm` present.
- [x] (2026-03-20 17:15Z) Confirmed current installed packages relevant to this plan: `podman` is present; `cockpit`, `cockpit-machines`, `libvirt-daemon-kvm`, `virt-install`, `qemu-kvm`, `firecracker`, `containerd`, and Kubernetes tooling are not yet installed.
- [x] (2026-03-20 17:20Z) Confirmed Fedora 43 package availability for the first-class host stack: `cockpit`, `cockpit-machines`, `cockpit-podman`, `cockpit-networkmanager`, `cockpit-storaged`, `libvirt-daemon-kvm`, `libvirt-client`, `libvirt-daemon-config-network`, `virt-install`, `qemu-kvm`, `firecracker`, `containerd`, `cri-o`, `helm`, and `kind` are available in Fedora repos; `firecracker-containerd`, `kubernetes-client`, and `minikube` are not available from the default Fedora 43 repos checked on the host.
- [ ] Install and validate the base virtualization management stack: Cockpit, libvirt, QEMU/KVM, and their required services and networking.
- [ ] Install and validate the container stack: Podman tooling already exists, but Cockpit integration and supporting tools should be installed and verified.
- [ ] Decide whether Firecracker experiments should use plain `firecracker` first or add `firecracker-containerd` from upstream releases outside Fedora packaging.
- [ ] Decide whether lightweight Kubernetes should start with `kind` on Podman, `cri-o` plus kube components, or an upstream-installed `k3s` path.
- [ ] Add repeatable validation notes for nested virtualization, VM lifecycle control, containers, Firecracker, and Kubernetes.

## Surprises & Discoveries

- Observation: The host already exposes hardware virtualization to the guest.
  Evidence: `/proc/cpuinfo` shows `svm`, and `/dev/kvm` exists on `10.133.183.26`.

- Observation: Podman is already installed, so the host already has a usable container runtime for plain OCI containers.
  Evidence: `rpm -q podman` returned `podman-5.6.2-1.fc43.x86_64`.

- Observation: Fedora 43 packages most of the base virtualization stack directly, which lowers the cost of the first milestone.
  Evidence: `dnf repoquery --available` on the host returned package candidates for `cockpit`, `cockpit-machines`, `libvirt-daemon-kvm`, `virt-install`, `qemu-kvm`, `firecracker`, `containerd`, `cri-o`, `helm`, and `kind`.

- Observation: `firecracker-containerd` is not present in the Fedora 43 repos checked on the host.
  Evidence: `dnf repoquery --available firecracker-containerd` returned no results.

- Observation: There is no installed remote-management stack yet.
  Evidence: `rpm -q cockpit cockpit-machines libvirt-daemon-kvm libvirt-client virt-install qemu-kvm` all reported not installed, and `systemctl is-enabled cockpit.socket` returned `not-found`.

## Decision Log

- Decision: Treat nested KVM and Cockpit/libvirt as the first milestone.
  Rationale: The host already has `/dev/kvm`, and remote VM lifecycle control is the clearest next capability to unlock.
  Date/Author: 2026-03-20 / Codex

- Decision: Treat Podman as part of the baseline host capability rather than a separate experimental path.
  Rationale: Podman is already installed and is the default Fedora-friendly container runtime for plain containers and for a likely `kind` path.
  Date/Author: 2026-03-20 / Codex

- Decision: Leave `firecracker-containerd` as a later milestone pending an explicit packaging decision.
  Rationale: `firecracker` itself is available from Fedora repos, but `firecracker-containerd` is not, so the initial plan should not assume a repo-native install path.
  Date/Author: 2026-03-20 / Codex

- Decision: Treat lightweight Kubernetes as a choice point rather than locking in `k3s` immediately.
  Rationale: `kind` is available from Fedora repos and aligns naturally with the existing Podman footprint, while `k3s` would require an upstream install path that has not yet been validated on this host.
  Date/Author: 2026-03-20 / Codex

## Outcomes & Retrospective

Current outcome: this plan is now grounded in the real Fedora IoT 43 host instead of generic assumptions. The host already exposes `/dev/kvm` and has Podman installed, but it does not yet have Cockpit, libvirt, or the virtualization management tools installed. Fedora 43 packaging is sufficient for the first two milestones: remote VM control through Cockpit/libvirt and plain container hosting through Podman plus Cockpit integration. Firecracker and lightweight Kubernetes are still open design choices, mainly because `firecracker-containerd` and some Kubernetes distributions are not directly available from the default repos.

## Context and Orientation

The target machine is the Fedora IoT VM reachable at `friel@10.133.183.26`. The host currently runs Fedora 43 with kernel `6.17.1-300.fc43.x86_64`. Nested virtualization appears available because the guest sees the AMD virtualization flag `svm` and exposes `/dev/kvm`. This plan assumes the root hypervisor is Hyper-V and the Fedora guest has already been configured to receive virtualization extensions.

The repository does not yet contain host automation for these services. This plan is therefore documentation-first: capture exact package names, service names, and validation commands before any future automation is added. The services in scope are the libvirt stack for virtual machines, Cockpit for browser-based remote management, Podman for ordinary containers, Firecracker for microVM experiments, and one lightweight Kubernetes path that should be practical on Fedora IoT.

## Plan of Work

First, install the base virtualization stack on the host. That means layering `cockpit`, `cockpit-machines`, `cockpit-networkmanager`, `cockpit-storaged`, `cockpit-podman`, `libvirt-daemon-kvm`, `libvirt-client`, `libvirt-daemon-config-network`, `qemu-kvm`, and `virt-install` with `rpm-ostree`. Then enable `cockpit.socket` and the appropriate libvirt service or socket activation path. The first acceptance proof is that Cockpit is reachable on TCP 9090 and the `Machines` page can see libvirt.

Second, validate nested KVM from inside the Fedora guest. That means confirming `/dev/kvm` still exists after the virtualization stack is installed, `virt-host-validate` reports the important checks as passing, and a small test guest can be created with `virt-install`. The exact image choice can remain lightweight, but the validation must prove that the Fedora guest can itself host virtual machines.

Third, formalize the container management stack. Podman already exists, but the host should also have `cockpit-podman`, `podman-remote`, and `skopeo` installed so both local CLI and Cockpit workflows are covered. Acceptance for this milestone is that `podman run` works and the running container is visible in Cockpit.

Fourth, stage Firecracker deliberately. Start with the Fedora-packaged `firecracker` binary and verify that KVM is usable for a microVM process on this host. Do not assume `firecracker-containerd` until there is a documented binary-install or package-install story. If later work chooses to add it, that should become a separate milestone with explicit provenance and rollback notes.

Fifth, choose one lightweight Kubernetes path and document it tightly. The lowest-friction current candidate is `kind`, because it is packaged in Fedora 43 and can ride on the container runtime already present. If a later run decides `k3s` or another distribution is a better fit, that should replace this milestone with concrete install and validation steps instead of vague aspiration.

## Concrete Steps

Capture the host baseline before changes:

    ssh friel@10.133.183.26 'egrep -o "vmx|svm" /proc/cpuinfo | head -n1; ls -l /dev/kvm; rpm -q podman cockpit cockpit-machines libvirt-daemon-kvm qemu-kvm virt-install firecracker containerd kind || true'

Install the base virtualization and management stack on the host:

    ssh friel@10.133.183.26 'sudo rpm-ostree install --allow-inactive cockpit cockpit-machines cockpit-networkmanager cockpit-storaged cockpit-podman libvirt-daemon-kvm libvirt-client libvirt-daemon-config-network qemu-kvm virt-install podman-remote skopeo firecracker containerd kind helm'
    ssh friel@10.133.183.26 'sudo systemctl enable --now cockpit.socket'
    ssh friel@10.133.183.26 'sudo systemctl enable --now libvirtd || sudo systemctl enable --now virtqemud.socket virtnetworkd.socket virtstoraged.socket'

After any `rpm-ostree` layering change, reboot and reconnect:

    ssh friel@10.133.183.26 'sudo systemctl reboot'

Validate KVM and libvirt on the host:

    ssh friel@10.133.183.26 'ls -l /dev/kvm; virt-host-validate; virsh -c qemu:///system list --all'

Create a lightweight test guest once a bootable image is available on the host:

    ssh friel@10.133.183.26 'sudo virt-install --name smokevm --memory 2048 --vcpus 2 --disk size=12 --os-variant fedora-unknown --network network=default --graphics none --import --noautoconsole'

Validate Podman and Cockpit container management:

    ssh friel@10.133.183.26 'podman run --rm quay.io/podman/hello'
    ssh friel@10.133.183.26 'systemctl status cockpit.socket --no-pager'

Validate Firecracker availability:

    ssh friel@10.133.183.26 'command -v firecracker; firecracker --version'

Validate the lightweight Kubernetes path if `kind` is chosen:

    ssh friel@10.133.183.26 'kind --version'

## Validation and Acceptance

This plan is complete when all of the following are true on `10.133.183.26`:

1. `/dev/kvm` is present and `virt-host-validate` shows KVM/libvirt checks passing well enough to host guests.
2. Cockpit is installed, `cockpit.socket` is enabled, and the web UI on port 9090 exposes the machine-management capabilities expected for the installed Cockpit modules.
3. Libvirt can enumerate a system connection with `virsh -c qemu:///system list --all`.
4. A small nested guest can be defined or booted on the host using `virt-install`.
5. `podman run` works, and Cockpit can see container state if `cockpit-podman` is installed.
6. `firecracker --version` works and a documented path exists for microVM experiments on the host.
7. A documented lightweight Kubernetes path exists and is validated at least to the point of creating a local development cluster or proving why that chosen path is blocked.

## Idempotence and Recovery

The baseline inspection commands are safe to rerun. `rpm-ostree install --allow-inactive` is safe for iterative host layering, but each successful layering transaction requires a reboot before runtime validation. If `libvirtd` is not the active service name on Fedora IoT, fall back to enabling the split libvirt sockets (`virtqemud.socket`, `virtnetworkd.socket`, and `virtstoraged.socket`) rather than forcing a non-existent unit. If a milestone turns out to be too heavy for the host, leave the packages installed but disable the service and record the reason in this plan instead of deleting evidence.

## Artifacts and Notes

Current baseline proof captured on the host before this plan starts:

    $ egrep -o 'vmx|svm' /proc/cpuinfo | head -n1
    svm

    $ ls -l /dev/kvm
    crw-rw-rw-. 1 root kvm 10, 232 ... /dev/kvm

    $ rpm -q podman
    podman-5.6.2-1.fc43.x86_64

    $ rpm -q cockpit cockpit-machines libvirt-daemon-kvm qemu-kvm virt-install firecracker containerd kind || true
    package cockpit is not installed
    ...

Repo-query proof that Fedora 43 can supply the base stack directly:

    cockpit
    cockpit-machines
    cockpit-podman
    libvirt-daemon-kvm
    libvirt-client
    libvirt-daemon-config-network
    qemu-kvm
    virt-install
    firecracker
    containerd
    cri-o
    helm
    kind

Repo-query gaps that require a later decision if they become mandatory:

    firecracker-containerd
    kubernetes-client
    minikube

## Interfaces and Dependencies

This work depends on SSH access to `10.133.183.26`, working `rpm-ostree` layering on the host, and the Hyper-V outer VM being configured to expose virtualization extensions to the Fedora guest. The first-class host interfaces to validate are `cockpit.socket` for remote management, libvirt’s `qemu:///system` connection for nested virtual machines, the `podman` CLI and Cockpit Podman integration for containers, the `firecracker` binary for microVM experiments, and the chosen lightweight Kubernetes interface (`kind` unless later evidence changes the choice).

Change note: Created this plan from the current host baseline so future work can add nested VMs, Cockpit management, Podman workflows, Firecracker experiments, and a lightweight Kubernetes path without guessing package names or prerequisites.
