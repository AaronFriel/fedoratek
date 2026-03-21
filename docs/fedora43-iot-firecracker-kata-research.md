# Fedora 43 / Fedora IoT research: Firecracker, containerd, Kata Containers, and native lightweight Kubernetes

This note captures what was actually proved on the Fedora IoT host at `10.133.183.26`, plus the remaining packaging and support questions for the less repo-native paths.

The original question was whether these paths are repo-native on Fedora 43, or whether we would need to build RPMs ourselves.

## Short answer

For Fedora 43 and Fedora IoT, the paths are not equal.

- `kata-containers` is repo-native and proven on the host. We did not need a custom kernel module or a custom RPM to run a Kata-backed workload.
- `firecracker` itself is repo-native enough for lab work and is now proven on the host with a real guest boot.
- `k3s` is the current preferred lightweight Kubernetes path for this host. It is not Fedora-repo-native, but it is now proven on the host and is a better long-lived fit than the earlier `kind` smoke cluster.
- `firecracker-containerd` is still the packaging outlier. It is not present in the Fedora 43 repos checked on the host, but we now have a working repo-local RPM path for Fedora 43 `x86_64` and proved it on the host through `rpm-ostree` layering.

## What the current host already has

On `10.133.183.26`:

- Fedora release: `43`
- Kernel: `6.17.1-300.fc43.x86_64`
- CPU virtualization flag visible in the guest: `svm`
- KVM device present: `/dev/kvm`
- Secure Boot remains enabled on the host

This means the important prerequisite for Firecracker, Kata, and nested virtual machines is already present: in-tree KVM support exposed as `/dev/kvm`. I do not currently expect an out-of-tree kernel module requirement for any of these compute-host paths.

## Fedora 43 package availability checked on the host

The following package names were checked with `dnf repoquery --available` on `10.133.183.26`.

Available directly in Fedora 43:

- `firecracker`
- `containerd`
- `cri-o`
- `cri-tools`
- `runc`
- `crun`
- `containernetworking-plugins`
- `kata-containers`
- `helm`

Not found in the default Fedora 43 repos checked on the host:

- `firecracker-containerd`
- `firecracker-go-sdk`
- `nerdctl`
- `kubernetes-client`
- `minikube`
- `kubernetes-kubelet`

## Proven host results

The following paths are no longer just researched. They were exercised on the live Fedora IoT host.

### K3s on Fedora 43 / IoT

This is now the preferred lightweight Kubernetes path on the host.

The final working model was:

- keep SELinux enforcing on the host
- keep `firewalld` enabled
- open the K3s API port and trust the default pod and service CIDRs:
  - `6443/tcp`
  - `10.42.0.0/16`
  - `10.43.0.0/16`
- install upstream K3s as a single-node server

The successful K3s config on the host is:

    write-kubeconfig-mode: "0644"
    tls-san:
      - 10.133.183.26

The host uses:

- K3s version: `v1.34.5+k3s1`
- container runtime inside K3s: `containerd://2.1.5-k3s1`

Important Fedora IoT discoveries from the live install:

- the installer's attempt to add `k3s-selinux` through `rpm-ostree` failed on this host with:

    failed to add subkeys for /var/cache/rpm-ostree/repomd/rancher-k3s-common-stable-43-x86_64/public.key to rpmdb

- the K3s binary installed under `/usr/local/bin/k3s`, but it was mislabeled as `user_tmp_t`
- systemd then failed to start `k3s.service` with an SELinux execute denial until the file was relabeled with `restorecon`
- after the host reboot, `chronyd` stepped the clock backward by about 25,199 seconds during early boot, which caused the first round of K3s addon pods to fail with service-account tokens that were “not valid yet”
- restarting `k3s` after time synchronization completed fixed those addon failures cleanly

What was proved:

- `k3s.service` is active on the host and survives reboot
- the node returns `Ready` after reboot without reinstalling anything
- `kubectl` works for the unprivileged `friel` user with `KUBECONFIG=/etc/rancher/k3s/k3s.yaml`
- a test workload was scheduled successfully:

    namespace `smoke`
    deployment `echo`
    image `docker.io/library/nginx:stable`

Observed running state:

- node:

    localhost.localdomain   Ready   control-plane   ...   v1.34.5+k3s1   ...   containerd://2.1.5-k3s1

- workload pod:

    echo-...   1/1   Running   ...   10.42.0.9   localhost.localdomain

Conclusion for K3s:

- K3s is the right “more native” Kubernetes path on this Fedora IoT host
- it required less host plumbing than `kubeadm`
- it is a better persistent fit than `kind` here
- it is still an upstream-installed component rather than a Fedora-repo-native package

### Kata Containers on Fedora 43 / IoT

This path is repo-native and proven.

Installed on the host through `rpm-ostree` layering:

- `kata-containers`
- `qemu-kvm-core`
- `virtiofsd`
- `containerd`
- `runc`
- `dbus-daemon`

What was needed beyond the first package install:

- Fedora's packaged Kata runtime expects guest artifacts under `/var/cache/kata-containers/`
- `kata-runtime check` initially failed because `vmlinuz.container` did not exist yet
- the packaged osbuilder helper at `/usr/libexec/kata-containers/osbuilder/kata-osbuilder.sh -c` generated:
  - `/var/cache/kata-containers/vmlinuz.container`
  - `/var/cache/kata-containers/kata-containers-initrd.img`
- `dbus-daemon` had to be layered so the osbuilder path could complete cleanly enough to generate those artifacts

What was proved:

- `sudo kata-runtime check` succeeded and reported the system is capable of running Kata Containers
- `containerd` was started successfully on the host
- a real Kata-backed workload ran through the packaged Kata shim:

    sudo ctr run --rm --runtime io.containerd.kata.v2 \
      docker.io/library/busybox:latest kata-smoke \
      /bin/sh -c "echo kata-ok && uname -a"

Observed output included:

- `kata-ok`
- `Linux localhost 6.17.1-300.fc43.x86_64 ...`

Conclusion for Kata:

- no custom RPM build is needed to get Kata working on Fedora 43 / IoT
- no out-of-tree kernel module is needed
- the packaged default config is QEMU-backed, not Firecracker-backed

### Kata Containers on K3s on Fedora 43 / IoT

This path is now also proven on the host, but the final working route was not the initial Fedora-packaged guest-artifact path.

What failed first:

- manually wiring K3s to Fedora's packaged Kata artifacts reached the runtime, but Kubernetes sandbox creation failed
- the key runtime log from the failed packaged-artifact path was:

    createContainer failed ... Establishing a D-Bus connection ... No such file or directory

- unpacking the generated guest initrd showed `dbus.socket` and `dbus-daemon`, but not the service-side `dbus.service` wiring that the guest needed for the Kubernetes sandbox path

That was enough to conclude that the repo-native Fedora guest-artifact path was not the clean K3s integration path on this host, even though plain `ctr` and standalone Kata checks worked.

The working K3s integration used upstream `kata-deploy` instead.

What was required on the host before `kata-deploy` could succeed:

- K3s had to use a containerd template that imports the K3s drop-in directory
- the required line in `/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.tmpl` was:

    imports = ["/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/*.toml"]

- after adding that import, `k3s` had to be restarted so the rendered `config.toml` picked it up

Important deployment discovery:

- applying the upstream Helm chart output directly with `kubectl apply` is wrong if the rendered manifest still contains Helm hook resources
- doing that caused the chart's cleanup hook job to run immediately and delete the `kata-deploy` service account and RBAC
- the clean approaches are either:
  - a real `helm install`, or
  - rendering the chart and filtering out all documents that contain `helm.sh/hook` before applying them with `kubectl`

What was proved on `10.133.183.26` after the K3s template import fix and the upstream `kata-deploy` install:

- the upstream installer DaemonSet came up successfully:

    kube-system/kata-deploy-vtdsn   1/1   Running

- the node was labeled by the installer:

    katacontainers.io/kata-runtime=true

- the upstream verification pod completed successfully:

    smoke/kata-verify-qemu   Completed

- a stronger normal-pod proof also succeeded with regular pod networking and the projected service-account volume still mounted:

    smoke/kata-normal   1/1 Running

Observed output from that normal pod:

- `kata-normal-ok`
- `Linux kata-normal 6.18.15 ...`
- `smoke`

That final proof is important because it shows the working K3s+Kata path is not limited to the earlier stripped-down `hostNetwork` plus `automountServiceAccountToken: false` workaround pod.

One upstream chart bug was still observed:

- the chart's verification job script tripped over a shell arithmetic bug while parsing event counts
- even with that bug, the actual `kata-verify-qemu` pod still completed successfully, so the host-level K3s + Kata capability is proven

Conclusion for K3s + Kata:

- K3s on Fedora IoT 43 can run Kata-backed pods on this host
- the reliable path today uses upstream `kata-deploy`, not just the Fedora-packaged Kata guest artifacts
- the host-side K3s containerd template must import `config-v3.toml.d/*.toml`
- if we document or automate this path later, we should treat the upstream Helm chart as the source of truth and avoid raw `kubectl apply` of unfiltered hook resources

### Plain Firecracker on Fedora 43

This path is repo-native enough for lab work and is proven.

Fedora 43 ships `firecracker` itself. The package installs the main `firecracker` binary plus helper tools such as:

- `/usr/bin/firecracker`
- `/usr/bin/cpu-template-helper`
- `/usr/bin/rebase-snap`
- `/usr/bin/seccompiler-bin`
- `/usr/bin/snapshot-editor`

Important warning from the Fedora package metadata:

- the Fedora package explicitly says it does not include all of the security features of an official release and is not production-ready without additional sandboxing

That warning does not block lab work. It only means the packaged binary should be treated as an experimentation path first, not as a finished production-hardening story.

What was needed to prove the path:

- packaged `firecracker`
- `/dev/kvm`
- an upstream Firecracker test kernel and root filesystem
- a small local config file pointing Firecracker at that kernel and rootfs

The Kata-generated `vmlinuz.container` was not sufficient, because Firecracker expects an uncompressed ELF `vmlinux`. The working assets came from the Firecracker upstream CI bucket instead:

- `vmlinux-6.1.155`
- `ubuntu-24.04.squashfs`, converted locally into `ubuntu-24.04.ext4`

What was proved:

- `firecracker --version` reported `Firecracker v1.13.1`
- a real guest booted under the packaged Fedora `firecracker` binary
- the guest reached a serial login prompt, with the boot log ending at:

    Ubuntu 24.04.3 LTS ubuntu-fc-uvm ttyS0
    ubuntu-fc-uvm login: root (automatic login)

Conclusion for plain Firecracker:

- we do not need to build our own RPM to start testing plain Firecracker on Fedora 43 / IoT
- we do need guest assets that match Firecracker's expectations
- this is a good lab milestone because it isolates Firecracker itself from the `containerd` integration problem

## Firecracker with containerd on Fedora 43

This remains the least repo-native path.

The host repo check showed:

- `containerd` is available in Fedora 43
- `firecracker-containerd` is not available in Fedora 43
- `nerdctl` is also not available in the default Fedora 43 repos we checked

Upstream `firecracker-containerd` documentation matters here. The upstream README says the project works by providing multiple pieces around `containerd`, including a control plugin, a shim runtime, an in-guest agent, and a root filesystem builder. The most important packaging detail is that the control plugin is compiled into `containerd`, which requires a specialized `containerd` binary for `firecracker-containerd`.

That means this is not just “install stock Fedora `containerd` plus one extra plugin package.” The integration model itself expects a custom `containerd` build.

The upstream project page we checked also shows:

- no releases published
- no GitHub packages published
- setup guidance centered on source builds and custom binaries

Conclusion for this path:

- Fedora 43 does not currently give us a repo-native `firecracker-containerd` install
- upstream's architecture suggests this is inherently more than a thin add-on RPM
- if we want this path, we should currently assume one of two models:
  - accept upstream-built binaries or a source build outside Fedora packaging, or
  - build and maintain our own RPM packaging for the specialized `containerd` and `firecracker-containerd` pieces

So this is the one path where “we may need to build the RPM ourselves” is still a real possibility.

## Current recommendation order

If the goal is to keep growing this Fedora IoT host into a compute playground without immediately falling into unnecessary packaging work, the sensible order is now:

1. keep Kata as the repo-native VM-isolated container path
2. keep plain Firecracker as the repo-native microVM path
3. keep K3s as the current lightweight Kubernetes path
4. treat `firecracker-containerd` as a later packaging/integration project

## Commands used for the proved results

Representative host checks used for the current conclusions:

    ssh friel@10.133.183.26 'dnf -q repoquery --available firecracker containerd cri-o cri-tools runc crun containernetworking-plugins kata-containers firecracker-containerd nerdctl helm'

    ssh friel@10.133.183.26 'sudo kata-runtime check'

    ssh friel@10.133.183.26 'sudo ctr run --rm --runtime io.containerd.kata.v2 docker.io/library/busybox:latest kata-smoke /bin/sh -c "echo kata-ok && uname -a"'

    ssh friel@10.133.183.26 'firecracker --version'

    ssh friel@10.133.183.26 'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" INSTALL_K3S_SKIP_SELINUX_RPM=true INSTALL_K3S_SELINUX_WARN=true sh -'

    ssh friel@10.133.183.26 'sudo restorecon -v /usr/local/bin/k3s /usr/local/bin/kubectl /usr/local/bin/k3s-killall.sh /usr/local/bin/k3s-uninstall.sh'

    ssh friel@10.133.183.26 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide'

    ssh friel@10.133.183.26 'sudo k3s kubectl -n smoke get pods -o wide'

## Sources

- Firecracker containerd upstream README and project page: https://github.com/firecracker-microvm/firecracker-containerd
- Kata Containers upstream repository: https://github.com/kata-containers/kata-containers
- Firecracker upstream getting started documentation: https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md
- Host-local Fedora 43 package metadata and live host validation gathered from `dnf repoquery` and direct runtime checks on `10.133.183.26`

## Kata on Firecracker on K3s on Fedora 43 / IoT

This path is now proven on the live host.

After the earlier `kata-qemu` RuntimeClass path was working, the remaining question was whether the same K3s host could run Kata with the Firecracker hypervisor rather than QEMU.

What changed on the host:

- upstream `kata-deploy` was re-rendered with the `fc` shim enabled for `k3s`
- K3s still needed the existing containerd template import:

    imports = ["/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/*.toml"]

- K3s containerd also needed a working `devmapper` snapshotter configured in its own drop-in directory, not in a separate standalone `containerd` config:

    /var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/10-devmapper.toml

with host-local contents:

    [plugins."io.containerd.snapshotter.v1.devmapper"]
      pool_name = "k3s-devpool"
      root_path = "/var/lib/rancher/k3s/agent/containerd/devmapper"
      base_image_size = "2GB"
      discard_blocks = true

- the backing thin-pool was created on the host as `k3s-devpool`
- after restarting `k3s`, `sudo k3s ctr plugins ls -d` showed the `devmapper` plugin active rather than skipped

One important practical discovery is that `kata-deploy` had already laid down the Firecracker-specific Kata artifacts under `/opt/kata/`, including:

- `/opt/kata/bin/firecracker`
- `/opt/kata/bin/jailer`
- `/opt/kata/share/defaults/kata-containers/configuration-fc.toml`

That meant the missing piece was not “find Firecracker binaries.” It was “make K3s containerd provide the snapshotter and runtime wiring that the `fc` shim expects.”

What was proved on `10.133.183.26`:

- the `kata-fc` RuntimeClass exists:

    kata-fc   kata-fc

- a normal Kubernetes pod using `runtimeClassName: kata-fc` was scheduled successfully:

    smoke/kata-fc-normal

- the pod reached `Running`, received a normal pod IP, kept the projected service-account volume mounted, and then completed successfully

Observed pod logs:

- `kata-fc-normal-ok`
- `Linux kata-fc-normal 6.18.15 ...`
- `smoke`

Observed K3s log evidence also showed the Firecracker subsystem being used during sandbox setup.

Conclusion for Kata on Firecracker:

- Kata on Firecracker works on this Fedora IoT 43 host under K3s
- the critical requirement was K3s-local `devmapper` snapshotter configuration plus the upstream `kata-deploy` `fc` shim
- this is not a pure Fedora-package-only path, but it is also not an ad hoc manual binary-copy path on the host

## Firecracker with containerd on Fedora 43: immutable-host delivery note

Fedora 43 still does not provide a repo-native `firecracker-containerd` package, and upstream still requires a specialized `containerd` build. That part of the earlier conclusion remains true.

What changed is the delivery answer.

We now have a working repo-local RPM path for Fedora 43 `x86_64`, and that path was exercised on the live Fedora IoT host at `10.133.183.26` rather than only off-host.

What the proven package path does:

- builds the specialized `firecracker-containerd` binaries from upstream source
- rebuilds the guest rootfs with a statically linked in-guest `agent`
- rebuilds the guest `runc` as a static binary from `_submodules/runc`
- ships those guest assets under `/usr/lib/firecracker-containerd/runtime`
- layers the resulting RPM with `rpm-ostree`
- starts a dedicated `firecracker-containerd` service on the host
- recreates or reattaches the `fc-dev-thinpool` automatically on service start via `ExecStartPre=/usr/bin/firecracker-containerd-setup-devmapper`

Why the static guest binaries mattered:

The first packaged guest image failed even though the host-side service, Firecracker VMM, and snapshotter plumbing were otherwise correct. The decisive journal evidence from the host was:

- `/usr/local/bin/agent: /lib/x86_64-linux-gnu/libc.so.6: version "GLIBC_2.32" not found`
- `/usr/local/bin/agent: /lib/x86_64-linux-gnu/libc.so.6: version "GLIBC_2.34" not found`

That proved the earlier guest image had the wrong linkage model for the packaged Debian rootfs. Rebuilding the guest image with a static `agent` and static `runc` fixed the in-guest startup path.

What is now proven on the live Fedora IoT host:

- `firecracker-containerd` was installed through `rpm-ostree` from a locally built RPM
- `systemctl is-active firecracker-containerd` reports `active`
- `firecracker-ctr --address /run/firecracker-containerd/containerd.sock plugins ls` shows the `devmapper` snapshotter `ok`
- `firecracker-ctr ... images pull --snapshotter devmapper docker.io/library/busybox:latest` succeeds
- `firecracker-ctr ... run --snapshotter devmapper --runtime aws.firecracker --rm --net-host docker.io/library/busybox:latest ...` succeeds and prints:
  - `firecracker-final-ok`
  - `Linux microvm 4.14.174 ...`
- the same workflow still succeeds after reboot because the service now recreates or reattaches the loop-backed thinpool on startup

So the current answer is:

- Fedora 43 still does not give us a stock `firecracker-containerd` package
- but we do not need to fall back to mutable `/usr/local` host installs either
- a repo-tracked RPM path works and fits the immutable-host model better than ad hoc binary copying

What remains open is not basic viability. The remaining work is packaging hardening:

- clean up the repo packaging so COPR can build it reproducibly
- decide whether to keep it as a layered RPM path only or also add image-based delivery later
- broaden beyond Fedora 43 `x86_64` only after more host proofs exist
