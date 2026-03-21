# ExecPlan: Fedora VM compute playground on the Hyper-V-backed Fedora IoT host

This ExecPlan is a living document. Keep it current as work progresses. It should let a novice continue the effort from the repo and from the Fedora IoT host alone.

## Goal

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
- [x] (2026-03-21 01:38Z) Wired Kata into K3s using upstream `kata-deploy` for `k3s`, fixed the required K3s containerd drop-in import, and proved RuntimeClass-backed pods on the live host. The node is labeled `katacontainers.io/kata-runtime=true`, `smoke/kata-verify-qemu` completed successfully, and a normal `smoke/kata-normal` pod also completed with a projected service-account mount and regular pod networking.
- [x] (2026-03-21 18:05Z) Proved Kata on Firecracker inside K3s on the live host. Enabled the `kata-deploy` `fc` shim, configured the K3s containerd `devmapper` snapshotter under `/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/10-devmapper.toml`, and ran `smoke/kata-fc-normal` successfully through `RuntimeClass` `kata-fc`.
- [x] (2026-03-21 20:00Z) Proved `firecracker-containerd` on the live Fedora IoT host using an immutable-host-compatible RPM path. Layered a locally built `firecracker-containerd` RPM with `rpm-ostree`, fixed the guest rootfs packaging to use a static in-guest `agent` plus static `_submodules/runc/runc`, enabled automatic devmapper pool setup through the systemd unit, and revalidated a Firecracker-backed `busybox` workload before and after reboot.
- [x] (2026-03-21 23:28Z) Fixed the direct `nerdctl` plus Cloud Hypervisor path on the live host by scoping `KATA_CONF_FILE=/opt/kata/share/defaults/kata-containers/runtimes/clh/configuration-clh.toml` to the stock `containerd` systemd unit. A direct `nerdctl --address /run/containerd/containerd.sock run --rm --net host --runtime io.containerd.run.kata.v2 ...` workload now survives reboot and launches `cloud-hypervisor` instead of falling back to QEMU.
- [x] (2026-03-21 23:40Z) Added an immutable-host `runwasi-wasmtime` RPM path, layered it with `rpm-ostree`, wired K3s to `io.containerd.wasmtime.v1` through `/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/20-runwasi-wasmtime.toml`, and proved the official `ghcr.io/containerd/runwasi/wasi-demo-app:latest` deployment through RuntimeClass `wasmtime`.
- [x] (2026-03-21 23:43Z) Started the dedicated `docs/compute-host/` tree so the canonical host wiring and proofs live under a stable path instead of being spread only across the older research note and chat transcripts.

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

- Observation: Manually wiring K3s to Fedora's packaged Kata guest artifacts was not sufficient for regular Kubernetes pod sandboxes.
  Evidence: direct `ctr run --runtime io.containerd.kata.v2 ...` worked, but K3s pod creation stalled in `ContainerCreating`, and Kata logs showed guest-side D-Bus failures during sandbox setup.

- Observation: Upstream `kata-deploy` on K3s depends on K3s rendering containerd config with an imports line for the drop-in directory.
  Evidence: the installer pod failed until `/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.tmpl` started with `imports = ["/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/*.toml"]` and `k3s` was restarted.

- Observation: Applying raw Helm-rendered hook resources with `kubectl apply` is wrong for `kata-deploy`.
  Evidence: the chart's cleanup hook immediately removed the service account and RBAC objects when the unfiltered manifest was applied; removing hook documents from the rendered YAML fixed that.

- Observation: The upstream `kata-deploy` verification job has a shell bug, but the actual runtime verification pod result is still trustworthy.
  Evidence: the verification job later hit `arithmetic syntax error`, but `smoke/kata-verify-qemu` still completed successfully and a separate normal `smoke/kata-normal` pod also completed successfully.

- Observation: `kata-fc` on K3s requires containerd `devmapper` to be configured in K3s's own containerd tree, not in a standalone host `/etc/containerd/config.toml`.
  Evidence: the `fc` shim only became viable after `/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/10-devmapper.toml` defined `[plugins."io.containerd.snapshotter.v1.devmapper"]`, the thin pool `k3s-devpool` was created, `sudo k3s ctr plugins ls -d` showed `devmapper` with an exported root, and `smoke/kata-fc-normal` completed with `kata-fc-normal-ok`.

- Observation: the first packaged `firecracker-containerd` guest image failed even though the host-side service and Firecracker boot path were fine.
  Evidence: `journalctl -u firecracker-containerd` showed `/usr/local/bin/agent: /lib/x86_64-linux-gnu/libc.so.6: version "GLIBC_2.32" not found` and `GLIBC_2.34 not found` inside the Debian guest rootfs, which disappeared only after rebuilding the guest image with a static `agent` and static `runc`.

- Observation: the dedicated `devmapper` thinpool must be recreated or reattached after reboot unless the service does it automatically.
  Evidence: after reboot, `firecracker-ctr ... run` failed with `snapshotter not loaded: devmapper: invalid argument` until `firecracker-containerd-setup-devmapper` was rerun; adding `ExecStartPre=/usr/bin/firecracker-containerd-setup-devmapper` to the unit fixed the reboot path.

- Observation: direct `nerdctl` plus Kata initially failed for the wrong reason: guest networking on stock `containerd`, not Cloud Hypervisor itself.
  Evidence: the first direct `nerdctl --runtime io.containerd.run.kata.v2` attempt timed out waiting for `NetPciMatcher` uevents in the Kata agent; rerunning with `--net host` succeeded once `KATA_CONF_FILE` pointed stock `containerd` at the CLH config, and `ps -ef` then showed `/var/opt/kata/bin/cloud-hypervisor`.

- Observation: the host already had `wasmtime`, `spin`, `slight`, `wasmedge`, `wasmer`, `lunatic`, and `wws` RuntimeClasses from the existing K3s manifests, but they were not meaningful proofs by themselves.
  Evidence: before the `runwasi` work, `/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/` contained no Wasm runtime mapping and no Wasm shim binary existed on the host; only after layering `runwasi-wasmtime` and adding `20-runwasi-wasmtime.toml` did the official `wasi-demo-app` deployment roll out.

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

- Decision: Use upstream `kata-deploy` for the K3s+Kata integration instead of trying to keep K3s on the Fedora-generated Kata guest image path alone.
  Rationale: the Fedora-packaged Kata runtime was already good enough for standalone `ctr` usage, but the clean Kubernetes RuntimeClass integration on this host came from upstream `kata-deploy` once K3s was taught to import the `config-v3.toml.d` drop-in directory.
  Date/Author: 2026-03-21 / Codex

- Decision: Treat `firecracker-containerd` as an immutable-host packaging problem and prove it through a layered RPM before considering any image embedding.
  Rationale: the software needs a specialized `containerd` plus companion artifacts, but those pieces can still be delivered in an rpm-ostree-tracked way. That gives us a reproducible host proof without falling back to mutable `/usr/local` installs.
  Date/Author: 2026-03-21 / Codex

- Decision: Package the working guest assets directly into the RPM instead of keeping a long-term `/var/lib` rootfs override.
  Rationale: the host proof initially used a mutable runtime override only to isolate the rootfs defect. Once the defect was understood, the correct fix was to rebuild the packaged `default-rootfs.img` with a static in-guest `agent` and static `runc` so the immutable package itself contains the working guest image.
  Date/Author: 2026-03-21 / Codex

- Decision: Scope Cloud Hypervisor as the default direct Kata hypervisor only for the stock `containerd` service, not for K3s.
  Rationale: the user wanted direct `nerdctl` plus CLH, while K3s already had separate `kata-qemu`, `kata-fc`, and `kata-clh` RuntimeClasses. A `containerd.service` drop-in with `KATA_CONF_FILE=.../configuration-clh.toml` gives direct CLH containers without disturbing the K3s runtime-handler matrix.
  Date/Author: 2026-03-21 / Codex

- Decision: Treat `runwasi` as an immutable-host binary-delivery problem and package the upstream Wasmtime shim as its own RPM before wiring K3s.
  Rationale: Fedora 43 did not package `runwasi`, but the upstream release artifact is a small self-contained shim. Packaging it as `runwasi-wasmtime` preserves the rpm-ostree discipline while keeping the K3s runtime mapping explicit on the host.
  Date/Author: 2026-03-21 / Codex

- Decision: Start `docs/compute-host/` as the canonical home for host-level compute wiring and proofs.
  Rationale: the existing `docs/fedora43-iot-firecracker-kata-research.md` is useful background, but the host now has enough proven paths that we need a stable runbook directory for exact files, commands, and observed outputs.
  Date/Author: 2026-03-21 / Codex

## Outcomes & Retrospective

Current outcome: the Fedora IoT host at `10.133.183.26` is now a proven compute playground across several surfaces, not just a package wishlist.

Validated capabilities on the live host:

- nested KVM/libvirt guest hosting works well enough for lab use
- Cockpit is installed and listening on port `9090`
- plain Podman containers work
- Kata Containers work with the Fedora-packaged runtime stack
- Firecracker works with the Fedora-packaged VMM plus upstream guest assets
- K3s now serves as the host's active lightweight Kubernetes control plane and can run a test workload
- K3s plus Kata also works through `RuntimeClass`, using upstream `kata-deploy`, the K3s containerd drop-in import path, and a K3s-local `devmapper` snapshotter for `kata-fc`

The host now covers the full intended surface: nested KVM/libvirt, Cockpit, Podman, standalone Kata, standalone Firecracker, direct `nerdctl` plus Cloud Hypervisor on stock `containerd`, K3s, K3s plus Kata on QEMU, Firecracker, and Cloud Hypervisor, a dedicated Firecracker-backed `containerd` stack delivered through `rpm-ostree`, and a proven `runwasi` Wasmtime path on K3s. The remaining work in this area is breadth, not viability: more Wasm shims, broader packaging/COPR automation, and deeper performance or density comparisons between `kata-qemu`, `kata-clh`, `kata-fc`, and Wasm runtimes.

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

Validate standalone Kata:

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

Wire Kata into K3s using upstream `kata-deploy`:

    ssh friel@10.133.183.26 'sudo mkdir -p /var/lib/rancher/k3s/agent/etc/containerd && sudo grep -q "config-v3.toml.d" /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.tmpl || { printf "%s\n\n" "imports = [\"/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/*.toml\"]" | sudo cat - /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.tmpl | sudo tee /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.tmpl >/dev/null; }; sudo systemctl restart k3s'

    git clone https://github.com/kata-containers/kata-containers /tmp/kata-upstream
    cat >/tmp/kata-values.yaml <<'YAML'
    k8sDistribution: k3s
    runtimeClasses:
      enabled: true
      createDefault: false
    shims:
      disableAll: true
      qemu:
        enabled: true
        supportedArches:
          - amd64
    defaultShim:
      amd64: qemu
    verification:
      namespace: smoke
      timeout: 240
      daemonsetTimeout: 1200
      pod: |
        apiVersion: v1
        kind: Pod
        metadata:
          name: kata-verify-qemu
          namespace: smoke
        spec:
          runtimeClassName: kata-qemu
          hostNetwork: true
          dnsPolicy: ClusterFirstWithHostNet
          restartPolicy: Never
          automountServiceAccountToken: false
          enableServiceLinks: false
          containers:
          - name: test
            image: docker.io/library/busybox:latest
            command: ["/bin/sh","-c","echo kata-verify-ok && uname -a"]
    YAML

    helm template kata-deploy /tmp/kata-upstream/tools/packaging/kata-deploy/helm-chart/kata-deploy -n kube-system -f /tmp/kata-values.yaml >/tmp/kata-deploy-all.yaml
    awk 'BEGIN{RS="---\n"; ORS="---\n"} $0 !~ /helm\.sh\/hook/' /tmp/kata-deploy-all.yaml >/tmp/kata-deploy-nohooks.yaml
    KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f /tmp/kata-deploy-nohooks.yaml

Validate K3s plus Kata:

    ssh friel@10.133.183.26 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get node --show-labels | grep katacontainers.io/kata-runtime=true'
    ssh friel@10.133.183.26 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n smoke get pod kata-verify-qemu'
    ssh friel@10.133.183.26 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n smoke logs kata-verify-qemu'

    ssh friel@10.133.183.26 'cat <<"EOF" | KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f -
    apiVersion: v1
    kind: Pod
    metadata:
      name: kata-normal
      namespace: smoke
    spec:
      runtimeClassName: kata-qemu
      restartPolicy: Never
      containers:
      - name: test
        image: docker.io/library/busybox:latest
        command: ["/bin/sh", "-c", "echo kata-normal-ok && uname -a && cat /var/run/secrets/kubernetes.io/serviceaccount/namespace && sleep 1"]

Validate Kata on Firecracker on K3s:

    ssh friel@10.133.183.26 'sudo tee /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/10-devmapper.toml >/dev/null <<"EOF"
    [plugins."io.containerd.snapshotter.v1.devmapper"]
      pool_name = "k3s-devpool"
      root_path = "/var/lib/rancher/k3s/agent/containerd/devmapper"
      base_image_size = "2GB"
      discard_blocks = true
    EOF'

    ssh friel@10.133.183.26 'sudo dmsetup info k3s-devpool || true; sudo k3s ctr plugins ls -d | sed -n "/devmapper/,+8p"'

    # render kata-deploy with the `fc` shim enabled and `fc:devmapper` mapping
    # then apply the hook-filtered manifest, as above

    ssh friel@10.133.183.26 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get runtimeclass | grep kata-fc'
    ssh friel@10.133.183.26 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n smoke logs kata-fc-normal'

Build and validate the dedicated `firecracker-containerd` RPM locally:

    cd /home/friel/c/aaronfriel/fedoratek
    scripts/local_copr_build.sh --release 43 packaging/firecracker-containerd

    # expected artifacts include an RPM named like:
    # firecracker-containerd-0-0.3.gitYYYYMMDD.<commit>.fc43.x86_64.rpm

Layer the resulting RPM onto the IoT host in an rpm-ostree-tracked deployment:

    scp .scratch/firecracker-containerd-validate-*/firecracker-containerd-*.x86_64.rpm friel@10.133.183.26:/var/tmp/
    ssh friel@10.133.183.26 "sudo rpm-ostree install /var/tmp/firecracker-containerd-*.rpm"
    ssh friel@10.133.183.26 "sudo systemctl reboot"

If a previously enabled third-party repo breaks the layering transaction because rpm-ostree cannot import its key on the live root, disable that repo before retrying. On this host the problematic repo was `/etc/yum.repos.d/rancher-k3s-common.repo`, which was temporarily set to `enabled=0`.

Validate the dedicated service and snapshotter after reboot:

    ssh friel@10.133.183.26 "systemctl is-active firecracker-containerd"
    ssh friel@10.133.183.26 "sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock plugins ls | grep devmapper"
    ssh friel@10.133.183.26 "sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock images pull --snapshotter devmapper docker.io/library/busybox:latest"
    ssh friel@10.133.183.26 "sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock run --snapshotter devmapper --runtime aws.firecracker --rm --net-host docker.io/library/busybox:latest fc-smoke /bin/sh -c 'echo firecracker-containerd-ok && uname -a'"

Reboot once more to prove persistence:

    ssh friel@10.133.183.26 "sudo systemctl reboot"
    ssh friel@10.133.183.26 "systemctl is-active firecracker-containerd"
    ssh friel@10.133.183.26 "sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock run --snapshotter devmapper --runtime aws.firecracker --rm --net-host docker.io/library/busybox:latest fc-final /bin/sh -c 'echo firecracker-final-ok && uname -a'"

    ssh friel@10.133.183.26 "KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n smoke wait --for=condition=Ready pod/kata-normal --timeout=180s || true; KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n smoke logs kata-normal"

## Validation and Acceptance

This plan is complete when all of the following are true on `10.133.183.26`:

1. `/dev/kvm` is present and `virt-host-validate` shows KVM/libvirt checks passing well enough to host guests.
2. Cockpit is installed, `cockpit.socket` is enabled, and the web UI is reachable on port `9090`.
3. Libvirt can enumerate a system connection with `sudo virsh -c qemu:///system list --all`.
4. A small nested guest can be defined or booted on the host using `virt-install`.
5. `podman run` works.
6. A Kata-backed container can run successfully outside Kubernetes.
7. A Firecracker guest can boot successfully on the host.
8. K3s comes up after reboot, reports a `Ready` control-plane node, and can run a user workload.
9. K3s plus Kata works through `RuntimeClass`, including a normal pod path rather than only a stripped-down verification pod.
10. `firecracker-containerd` is installed via `rpm-ostree`, its dedicated service comes up after reboot with the `devmapper` snapshotter active, and `firecracker-ctr ... run` prints `firecracker-final-ok` from a Firecracker-backed container.

## Idempotence and Recovery

The baseline inspection commands are safe to rerun. `rpm-ostree install --allow-inactive` is safe for iterative host layering, but each successful layering transaction requires a reboot before runtime validation. If `libvirtd` is not the active service name on Fedora IoT, fall back to enabling the split libvirt sockets (`virtqemud.socket`, `virtnetworkd.socket`, and `virtstoraged.socket`) rather than forcing a non-existent unit. Firecracker smoke tests are easiest to keep disposable by storing guest assets and logs under `/var/tmp`. K3s installation is idempotent enough to rerun through the installer, but on this host the SELinux file context correction with `restorecon` is also required. If the first boot after enabling K3s experiences a large `chronyd` clock step, restart `k3s` once time is stable before diagnosing addon failures further. For `kata-deploy`, do not apply raw Helm-rendered hook resources with `kubectl apply`; render the chart, drop documents that contain `helm.sh/hook`, and then apply the remaining manifest so the cleanup hook does not delete the RBAC objects you still need. For `firecracker-containerd`, the dedicated service can safely rerun `firecracker-containerd-setup-devmapper` on every start; that is the recovery path that made the `devmapper` snapshotter survive reboot. If rpm-ostree layering fails because a third-party repo key cannot be imported on the live root, disable that repo and retry the transaction rather than force-writing keys into the immutable deployment.

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

    $ KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get node --show-labels | grep katacontainers.io/kata-runtime=true
    localhost.localdomain ... katacontainers.io/kata-runtime=true ...

    $ KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n smoke logs kata-verify-qemu
    kata-verify-ok
    Linux 7a7325d5d804 6.18.15 ...

    $ KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl -n smoke logs kata-normal
    kata-normal-ok
    Linux kata-normal 6.18.15 ...
    smoke

    $ systemctl is-active firecracker-containerd
    active

    $ sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock plugins ls | grep devmapper
    io.containerd.snapshotter.v1 devmapper linux/amd64 ok

    $ sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock run --snapshotter devmapper --runtime aws.firecracker --rm --net-host docker.io/library/busybox:latest fc-final /bin/sh -c "echo firecracker-final-ok && uname -a"
    firecracker-final-ok
    Linux microvm 4.14.174 #2 SMP Wed Jul 14 11:47:24 UTC 2021 x86_64 GNU/Linux

Repo-query gaps that still require a later decision if they become mandatory:

    firecracker-containerd
    kubernetes-client
    minikube

## Interfaces and Dependencies

This work depends on SSH access to `10.133.183.26`, working `rpm-ostree` layering on the host, and the Hyper-V outer VM being configured to expose virtualization extensions to the Fedora guest. The first-class host interfaces now validated are `cockpit.socket` for remote management, libvirt's `qemu:///system` connection for nested virtual machines, the `podman` CLI for plain containers, the Fedora-packaged Kata runtime stack through `containerd-shim-kata-v2`, the `firecracker` binary for microVM experiments, the K3s API plus kubeconfig at `/etc/rancher/k3s/k3s.yaml` for the native lightweight Kubernetes path, and the dedicated `firecracker-containerd` service plus `/run/firecracker-containerd/containerd.sock` for Firecracker-backed containers. Kata is now also proven inside K3s through `RuntimeClass` and upstream `kata-deploy`, with K3s configured to import runtime drop-ins from `config-v3.toml.d` and to activate a K3s-local `devmapper` snapshotter for `kata-fc`. The `firecracker-containerd` dependency story is now concrete rather than hypothetical: Fedora 43 still lacks a repo-native package, so this repository carries its own packaging and constrains the default build target to Fedora 43 `x86_64` until more host proofs exist.

Change note: This plan started from a baseline package survey, graduated through package and runtime proofs, moved from a temporary `kind` smoke cluster to K3s, then recorded the exact K3s+Kata RuntimeClass paths that worked on the host for both `kata-qemu` and `kata-fc`. It now also records the completed `firecracker-containerd` host proof: layered RPM delivery, static guest asset packaging, automatic `devmapper` setup on service start, and successful post-reboot Firecracker-backed container execution.

## nerdctl follow-on proof

This plan now also includes a proven immutable-host client path for stock
`containerd` on `10.133.183.26`.

What was layered:

- repo-local RPM: `nerdctl-2.2.1-2.fc43.x86_64`

What the package adds:

- `/usr/bin/nerdctl`
- `/usr/bin/containerd-rootless.sh`
- `/usr/bin/containerd-rootless-setuptool.sh`
- `/etc/nerdctl/nerdctl.toml`

The Fedora-specific config shipped in the RPM is:

    cni_path = "/usr/libexec/cni"

That override is required because Fedora's CNI plugin path differs from the
upstream nerdctl default. With the packaged config in place, the default stock
containerd smoke test succeeds:

    ssh friel@10.133.183.26 'sudo nerdctl --address /run/containerd/containerd.sock run --rm docker.io/library/busybox:latest /bin/sh -c "echo nerdctl-containerd-default-ok && uname -a"'

Observed output:

    nerdctl-containerd-default-ok
    Linux ... 6.17.1-300.fc43.x86_64 ...

The same client can talk to the dedicated Firecracker socket for image
operations:

    ssh friel@10.133.183.26 'sudo nerdctl --address /run/firecracker-containerd/containerd.sock images'
    ssh friel@10.133.183.26 'sudo nerdctl --address /run/firecracker-containerd/containerd.sock --snapshotter devmapper pull docker.io/library/alpine:latest'

But the current runtime boundary is important:

- `nerdctl ... run --runtime aws.firecracker ...` still fails on this host with
  a `resolv.conf` bind-mount error under `/var/lib/nerdctl/...`
- actual Firecracker-backed task execution remains proven through:

    ssh friel@10.133.183.26 'sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock run --snapshotter devmapper --runtime aws.firecracker --rm --net-host docker.io/library/busybox:latest fc-final /bin/sh -c "echo firecracker-final-ok && uname -a"'

Change note (2026-03-21 / Codex): Updated the plan after proving direct `nerdctl` plus Cloud Hypervisor on stock `containerd`, adding the `runwasi-wasmtime` RPM path and K3s `wasmtime` RuntimeClass proof, and starting the dedicated `docs/compute-host/` tree as the canonical host runbook location.
