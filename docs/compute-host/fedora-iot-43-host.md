# Fedora IoT 43 Compute Host

This document records the host-level compute paths that are actually proven on
`10.133.183.26` as of 2026-03-21.

## Host Baseline

- OS: Fedora IoT 43
- Hostname: `localhost.localdomain`
- Address: `10.133.183.26`
- Kernel: `6.17.1-300.fc43.x86_64`
- Virtualization: nested KVM available through `/dev/kvm`

## Proven Surfaces

### Management

- `cockpit.socket` is active
- enabled Cockpit modules include:
  - `cockpit-machines`
  - `cockpit-networkmanager`
  - `cockpit-ostree`
  - `cockpit-packagekit`
  - `cockpit-podman`
  - `cockpit-storaged`
  - `cockpit-system`

### VM and Container Stacks

- libvirt/KVM on the host
- Podman / Buildah / Skopeo
- stock `containerd` with `nerdctl`
- K3s as the persistent Kubernetes path
- Kata on QEMU through RuntimeClass `kata-qemu`
- Kata on Firecracker through RuntimeClass `kata-fc`
- Kata on Cloud Hypervisor through RuntimeClass `kata-clh`
- plain Firecracker
- `firecracker-containerd`
- `runwasi` Wasmtime through RuntimeClass `wasmtime`

## Direct Cloud Hypervisor Containers With nerdctl

The stock `containerd` service is wired so direct Kata containers use the Cloud
Hypervisor configuration by default.

The key host file is:

- `/etc/systemd/system/containerd.service.d/10-kata-clh.conf`

Its effective environment is:

    KATA_CONF_FILE=/opt/kata/share/defaults/kata-containers/runtimes/clh/configuration-clh.toml

This means the direct containerd runtime invocation:

    sudo nerdctl --address /run/containerd/containerd.sock run --rm --net host --runtime io.containerd.run.kata.v2 docker.io/library/busybox:latest /bin/sh -c 'echo nerdctl-kata-clh-ok && uname -a'

boots a Cloud Hypervisor-backed Kata sandbox. A live proof on the host showed a
running `cloud-hypervisor` process and returned:

    nerdctl-kata-clh-ok
    Linux localhost.localdomain 6.18.15 ...

The `--net host` flag is intentional. The earlier failure mode was not Cloud
Hypervisor itself; it was direct Kata networking on stock `containerd`, which
stalled waiting for a guest network interface uevent.

## Cloud Hypervisor Pod Isolation In K3s

K3s uses `kata-deploy` output under:

- `/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/kata-deploy.toml`

The host has these proven RuntimeClasses:

- `kata-qemu`
- `kata-fc`
- `kata-clh`

A real pod proof for Cloud Hypervisor used `runtimeClassName: kata-clh` and
returned:

    kata-clh-ok
    Linux kata-clh-smoke 6.18.15 ...
    smoke

## runwasi On K3s

The `runwasi` Wasmtime shim is delivered as a local RPM layered with
`rpm-ostree`:

- package: `runwasi-wasmtime-0.6.0-1.fc43.x86_64`
- binary: `/usr/bin/containerd-shim-wasmtime-v1`

K3s is wired to it through:

- `/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/20-runwasi-wasmtime.toml`

with contents:

    [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.wasmtime]
    runtime_type = "io.containerd.wasmtime.v1"
    runtime_path = "/usr/bin/containerd-shim-wasmtime-v1"

The host already had a `RuntimeClass` named `wasmtime`, so after the drop-in and
`systemctl restart k3s`, the official `runwasi` demo image worked unchanged.

Proof workload:

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: wasi-demo
      namespace: smoke
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: wasi-demo
      template:
        metadata:
          labels:
            app: wasi-demo
        spec:
          runtimeClassName: wasmtime
          containers:
          - name: demo
            image: ghcr.io/containerd/runwasi/wasi-demo-app:latest

Observed result:

- deployment rolled out successfully
- pod `wasi-demo-...` reached `Running`
- logs matched the upstream demo output:

    This is a song that never ends.
    Yes, it goes on and on my friends.
    Some people started singing it not knowing what it was,
    So they'll continue singing it forever just because...

## Firecracker-Backed Container Runtime

`firecracker-containerd` is also proven on this host, but it remains a separate
stack from `runwasi` and from stock `containerd`.

Useful interface split:

- stock `containerd` + `nerdctl` for regular OCI containers and direct Kata/CLH
- K3s `containerd` + RuntimeClass for pod isolation and `runwasi`
- `firecracker-containerd` + `firecracker-ctr` for Firecracker-backed tasks

## Current Boundaries

- direct `nerdctl` plus Cloud Hypervisor is working through stock `containerd`
- direct `nerdctl` against the K3s socket is not the right interface for the
  K3s `kata-clh` RuntimeClass wiring
- `runwasi` is proven for Wasmtime only; the extra runtime classes visible on
  the host (`spin`, `slight`, `wasmedge`, `wasmer`, `lunatic`, `wws`) should be
  treated as unproven until their matching shim binaries are installed and
  validated

## Packages and Repo Paths

Repo-tracked RPM packaging added for this host work:

- `packaging/firecracker-containerd`
- `packaging/nerdctl`
- `packaging/runwasi-wasmtime`

The host currently layers local RPMs for:

- `firecracker-containerd`
- `nerdctl`
- `runwasi-wasmtime`
