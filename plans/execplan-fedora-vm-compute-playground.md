# Turn Fedora IoT host 10.133.183.26 into a compute playground

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository does not contain a `PLANS.md` file. Maintain this document in accordance with the fallback rules from `/home/friel/.codex/skills/execplan/references/PLANS.md`.

## Purpose / Big Picture

The goal is to turn the Fedora VM at `10.133.183.26` into a flexible test host that can run several kinds of compute services: nested KVM virtual machines, remotely controlled libvirt guests through Cockpit, ordinary OCI containers through Podman, Firecracker microVM experiments, Kata-based VM-isolated containers, and a lightweight Kubernetes environment for local cluster experiments. After this work, a novice should be able to log into the host, see `/dev/kvm`, use Cockpit to create or inspect virtual machines, run Podman containers, run a Kata-backed container, boot a Firecracker guest, and interact with a persistent K3s control plane without guessing package names or host prerequisites.

## Progress

- [x] (2026-03-20 17:15Z) Captured the current host baseline on `10.133.183.26`: Fedora IoT 43, kernel `6.17.1-300.fc43.x86_64`, CPU virtualization flag `svm`, and `/dev/kvm` present.
- [x] (2026-03-20 17:20Z) Confirmed Fedora 43 package availability for the first-class host stack: `cockpit`, `cockpit-machines`, `cockpit-podman`, `cockpit-networkmanager`, `cockpit-storaged`, `libvirt-daemon-kvm`, `libvirt-client`, `libvirt-daemon-config-network`, `virt-install`, `qemu-kvm`, `firecracker`, `containerd`, `cri-o`, `helm`, and `kind` are available in Fedora repos; `firecracker-containerd`, `kubernetes-client`, and `minikube` are not available from the default Fedora 43 repos checked on the host.
- [x] (2026-03-20 18:15Z) Layered the base virtualization and management stack on the host with `rpm-ostree`, including Cockpit, libvirt, QEMU/KVM, Firecracker, CRI-O, `kind`, and `helm`, then rebooted into the new deployment successfully.
- [x] (2026-03-20 18:25Z) Enabled and validated the management services: `cockpit.socket`, `containerd`, `crio`, and `libvirtd` are active; Cockpit is listening on port `9090`.
- [x] (2026-03-20 18:35Z) Validated nested KVM hosting well enough for lab use: `/dev/kvm` is present, `virt-host-validate` passes the core KVM checks, `virsh -c qemu:///system` works under `sudo`, the default libvirt network is active, and a throwaway guest (`smokekata`) can be defined and started with `virt-install`.
- [x] (2026-03-20 18:45Z) Validated the plain container path: `podman run --rm quay.io/podman/hello` succeeds on the host.
- [x] (2026-03-20 19:05Z) Proved the Kata path using Fedora-packaged components. `kata-runtime check` succeeds after generating the packaged guest artifacts, and a real Kata-backed `busybox` workload ran successfully through `containerd-shim-kata-v2`.
- [x] (2026-03-20 19:35Z) Proved the plain Firecracker path on the host. Fedora-packaged `firecracker` booted a guest to a serial login prompt using upstream guest assets and `/dev/kvm`.
- [x] (2026-03-20 19:50Z) Proved an initial lightweight Kubernetes path with `kind` on rootless Podman, then removed that temporary cluster after a more native K3s path was validated.
- [x] (2026-03-20 23:55Z) Installed and validated K3s as the preferred lightweight Kubernetes path. The host now runs a single-node `k3s` server that survives reboot, returns `Ready`, and schedules a test deployment in namespace `smoke`.
- [ ] Decide whether `firecracker-containerd` is worth pursuing via upstream binaries or our own packaging.
- [ ] Decide whether to wire Kata into K3s through a custom containerd runtime and `RuntimeClass`, or keep Kata as a separate proven host capability for now.

## Surprises & Discoveries

- Observation: The host already exposed hardware virtualization to the Fedora guest.
  Evidence: `/proc/cpuinfo` shows `svm`, and `/dev/kvm` exists on `10.133.183.26`.

- Observation: Fedora 43 packages nearly the entire base compute-host stack directly.
  Evidence: `dnf repoquery --available` on the host returned package candidates for `cockpit`, `cockpit-machines`, `libvirt-daemon-kvm`, `virt-install`, `qemu-kvm`, `firecracker`, `containerd`, `cri-o`, `helm`, `kind`, and `kata-containers`.

- Observation: `firecracker-containerd` is the clear packaging outlier.
  Evidence: `dnf repoquery --available firecracker-containerd` returned no results, and upstream documents that its control plugin is compiled into a specialized `containerd` binary.

- Observation: Fedora's packaged Kata path is usable, but it is not turn-key immediately after package install.
  Evidence: `kata-runtime check` initially failed until the host generated `/var/cache/kata-containers/vmlinuz.container` and `/var/cache/kata-containers/kata-containers-initrd.img` through the packaged osbuilder flow.

- Observation: Fedora's packaged Kata default configuration is QEMU-backed rather than Firecracker-backed.
  Evidence: `/usr/share/kata-containers/defaults/configuration.toml` contains a `[hypervisor.qemu]` section and does not expose a Firecracker stanza in the default config we checked.

- Observation: A working Firecracker smoke test needed a real upstream `vmlinux`, not the packaged Kata `vmlinuz.container`.
  Evidence: Firecracker rejected the Kata kernel path with `Invalid Elf magic number`, but booted successfully with upstream `vmlinux-6.1.155` and a converted Ubuntu root filesystem.

- Observation: The K3s install path on Fedora IoT was blocked twice by host-specific policy behavior rather than by K3s itself.
  Evidence: the installer's automatic `k3s-selinux` path failed with `failed to add subkeys ... public.key to rpmdb`, then `k3s.service` failed because `/usr/local/bin/k3s` was mislabeled `user_tmp_t` until `restorecon` changed it back to `bin_t`.

- Observation: The first post-reboot K3s addon failures were caused by time synchronization, not by a broken K3s install.
  Evidence: `chronyd` logged `System clock was stepped by -25198.995738 seconds`, while the initial addon pods failed with `service account token is not valid yet`; restarting `k3s` after the clock stabilized brought all addons up cleanly.

## Decision Log

- Decision: Treat nested KVM and Cockpit/libvirt as the first milestone.
  Rationale: The host already had `/dev/kvm`, and remote VM lifecycle control is the clearest general-purpose capability to unlock first.
  Date/Author: 2026-03-20 / Codex

- Decision: Treat Podman as part of the baseline host capability rather than a separate experimental path.
  Rationale: Podman was already installed and is also the working base for the earlier `kind` smoke test.
  Date/Author: 2026-03-20 / Codex

- Decision: Use Fedora-packaged Kata rather than assuming immediate custom packaging work.
  Rationale: The Fedora package includes `containerd-shim-kata-v2`, works after generating the guest artifacts, and is already sufficient for a real Kata-backed workload.
  Date/Author: 2026-03-20 / Codex

- Decision: Keep Firecracker as a standalone microVM milestone before entertaining `firecracker-containerd`.
  Rationale: Plain Firecracker is repo-native enough for the host and is now proven, while `firecracker-containerd` still implies specialized packaging or upstream binaries.
  Date/Author: 2026-03-20 / Codex

- Decision: Replace the temporary `kind` smoke cluster with K3s as the preferred Kubernetes path on this host.
  Rationale: `kind` proved the host could run Kubernetes, but K3s is a better long-lived single-node control plane for a homelab Fedora IoT box and remains lighter-weight than a full `kubeadm` setup.
  Date/Author: 2026-03-20 / Codex

- Decision: Keep SELinux enforcing on the host while skipping the failed automatic `k3s-selinux` RPM installation.
  Rationale: The host-specific Rancher SELinux RPM path failed under `rpm-ostree`, but K3s itself runs after correcting the binary file context and documenting the limitation.
  Date/Author: 2026-03-20 / Codex

## Outcomes & Retrospective

Current outcome: the Fedora IoT host at `10.133.183.26` is now a proven compute playground across several surfaces, not just a package wishlist.

Validated capabilities on the live host:

- nested KVM/libvirt guest hosting works well enough for lab use
- Cockpit is installed and listening on port `9090`
- plain Podman containers work
- Kata Containers work with the Fedora-packaged runtime stack
- Firecracker works with the Fedora-packaged VMM plus upstream guest assets
- K3s now serves as the host's active lightweight Kubernetes control plane and can run a test workload

The most important remaining unresolved item is not host capability. It is integration scope: `firecracker-containerd` still looks likely to require upstream binaries or our own RPM work, and K3s plus Kata has not yet been wired together with a custom runtime configuration.

## Concrete Steps

Capture the host baseline before changes:

    ssh friel@10.133.183.26 'egrep -o "vmx|svm" /proc/cpuinfo | head -n1; ls -l /dev/kvm; rpm -q podman cockpit cockpit-machines libvirt-daemon-kvm qemu-kvm virt-install firecracker containerd kind || true'

Install the base virtualization and management stack on the host:

    ssh friel@10.133.183.26 'sudo rpm-ostree install --allow-inactive cockpit cockpit-machines cockpit-networkmanager cockpit-storaged cockpit-podman libvirt-daemon-kvm libvirt-client libvirt-daemon-config-network qemu-kvm virt-install firecracker containerd cri-o cri-tools kind helm kata-containers qemu-kvm-core virtiofsd runc dbus-daemon'

After any `rpm-ostree` layering change, reboot and reconnect:

    ssh friel@10.133.183.26 'sudo systemctl reboot'

Validate KVM and libvirt on the host:

    ssh friel@10.133.183.26 'ls -l /dev/kvm; sudo virt-host-validate; sudo virsh -c qemu:///system list --all'

Validate Cockpit and base services:

    ssh friel@10.133.183.26 'sudo systemctl enable --now cockpit.socket containerd crio libvirtd; sudo ss -ltnp | grep :9090'

Validate Podman:

    ssh friel@10.133.183.26 'podman run --rm quay.io/podman/hello'

Validate Kata:

    ssh friel@10.133.183.26 'sudo /usr/libexec/kata-containers/osbuilder/kata-osbuilder.sh -c'
    ssh friel@10.133.183.26 'sudo kata-runtime check'
    ssh friel@10.133.183.26 'sudo ctr run --rm --runtime io.containerd.kata.v2 docker.io/library/busybox:latest kata-smoke /bin/sh -c "echo kata-ok && uname -a"'

Validate Firecracker:

    ssh friel@10.133.183.26 'firecracker --version'

    # guest assets needed; packaged Kata kernel is not sufficient because Firecracker requires an ELF vmlinux

Install and validate K3s:

    ssh friel@10.133.183.26 'sudo firewall-cmd --permanent --add-port=6443/tcp; sudo firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16; sudo firewall-cmd --permanent --zone=trusted --add-source=10.43.0.0/16; sudo firewall-cmd --reload'

    ssh friel@10.133.183.26 'sudo mkdir -p /etc/rancher/k3s && cat <<"EOF" | sudo tee /etc/rancher/k3s/config.yaml >/dev/null
    write-kubeconfig-mode: "0644"
    tls-san:
      - 10.133.183.26
    EOF'

    ssh friel@10.133.183.26 'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" INSTALL_K3S_SKIP_SELINUX_RPM=true INSTALL_K3S_SELINUX_WARN=true sh -'

    ssh friel@10.133.183.26 'sudo restorecon -v /usr/local/bin/k3s /usr/local/bin/kubectl /usr/local/bin/k3s-killall.sh /usr/local/bin/k3s-uninstall.sh'

    ssh friel@10.133.183.26 'sudo systemctl enable --now k3s'

    # if addon pods fail immediately after a reboot and `chronyd` logged a large clock step, restart K3s once the clock is synchronized

    ssh friel@10.133.183.26 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide'
    ssh friel@10.133.183.26 'sudo k3s kubectl -n smoke get pods -o wide'

## Validation and Acceptance

This plan is complete when all of the following are true on `10.133.183.26`:

1. `/dev/kvm` is present and `virt-host-validate` shows KVM/libvirt checks passing well enough to host guests.
2. Cockpit is installed, `cockpit.socket` is enabled, and the web UI is reachable on port `9090`.
3. Libvirt can enumerate a system connection with `sudo virsh -c qemu:///system list --all`.
4. A small nested guest can be defined or booted on the host using `virt-install`.
5. `podman run` works.
6. A Kata-backed container can run successfully.
7. A Firecracker guest can boot successfully on the host.
8. K3s comes up after reboot, reports a `Ready` control-plane node, and can run a user workload.

## Idempotence and Recovery

The baseline inspection commands are safe to rerun. `rpm-ostree install --allow-inactive` is safe for iterative host layering, but each successful layering transaction requires a reboot before runtime validation. If `libvirtd` is not the active service name on Fedora IoT, fall back to enabling the split libvirt sockets (`virtqemud.socket`, `virtnetworkd.socket`, and `virtstoraged.socket`) rather than forcing a non-existent unit. Firecracker smoke tests are easiest to keep disposable by storing guest assets and logs under `/var/tmp`. K3s installation is idempotent enough to rerun through the installer, but on this host the SELinux file context correction with `restorecon` is also required. If the first boot after enabling K3s experiences a large `chronyd` clock step, restart `k3s` once time is stable before diagnosing addon failures further.

## Artifacts and Notes

Representative validated runtime facts from the host:

    $ sudo kata-runtime check
    System is capable of running Kata Containers
    System can currently create Kata Containers

    $ sudo ctr run --rm --runtime io.containerd.kata.v2 docker.io/library/busybox:latest kata-smoke /bin/sh -c 'echo kata-ok && uname -a'
    kata-ok
    Linux localhost 6.17.1-300.fc43.x86_64 ...

    $ firecracker --version
    Firecracker v1.13.1

    $ KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide
    localhost.localdomain   Ready   control-plane   ...   v1.34.5+k3s1   ...   containerd://2.1.5-k3s1

    $ sudo k3s kubectl -n smoke get pods -o wide
    echo-...   1/1   Running   0   ...   10.42.0.9   localhost.localdomain

Repo-query gaps that still require a later decision if they become mandatory:

    firecracker-containerd
    kubernetes-client
    minikube

## Interfaces and Dependencies

This work depends on SSH access to `10.133.183.26`, working `rpm-ostree` layering on the host, and the Hyper-V outer VM being configured to expose virtualization extensions to the Fedora guest. The first-class host interfaces now validated are `cockpit.socket` for remote management, libvirt's `qemu:///system` connection for nested virtual machines, the `podman` CLI for plain containers, the Fedora-packaged Kata runtime stack through `containerd-shim-kata-v2`, the `firecracker` binary for microVM experiments, and the K3s API plus kubeconfig at `/etc/rancher/k3s/k3s.yaml` for the native lightweight Kubernetes path. The main open dependency is whether future `firecracker-containerd` work should accept upstream binaries or invest in packaging, and whether Kata should later become a K3s runtime instead of remaining a separate proven host capability.

Change note: This plan started from a baseline package survey, graduated through package and runtime proofs, and now records K3s as the preferred Kubernetes baseline after removing the temporary `kind` smoke cluster.
