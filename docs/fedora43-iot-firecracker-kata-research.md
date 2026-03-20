# Fedora 43 / Fedora IoT research: Firecracker, containerd, Kata Containers, and native lightweight Kubernetes

This note captures what was actually proved on the Fedora IoT host at `10.133.183.26`, plus the remaining packaging and support questions for the less repo-native paths.

The original question was whether these paths are repo-native on Fedora 43, or whether we would need to build RPMs ourselves.

## Short answer

For Fedora 43 and Fedora IoT, the paths are not equal.

- `kata-containers` is repo-native and proven on the host. We did not need a custom kernel module or a custom RPM to run a Kata-backed workload.
- `firecracker` itself is repo-native enough for lab work and is now proven on the host with a real guest boot.
- `k3s` is the current preferred lightweight Kubernetes path for this host. It is not Fedora-repo-native, but it is now proven on the host and is a better long-lived fit than the earlier `kind` smoke cluster.
- `firecracker-containerd` is the outlier. It is not present in the Fedora 43 repos checked on the host, and upstream documents that it needs a specialized `containerd` build. That is the one path where we should currently assume upstream binaries or our own packaging work.

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
