# firecracker-containerd packaging

This package stages `firecracker-containerd` as a parallel runtime stack for
Fedora-based immutable hosts.

Design points:
- do not replace Fedora's stock `containerd`
- install dedicated binaries and configs for `/run/firecracker-containerd`
- ship the working guest assets under `/usr/lib/firecracker-containerd/runtime`
- keep mutable state under `/var/lib/firecracker-containerd`
- create or reattach the loop-backed `fc-dev-thinpool` automatically on service start

Current validated scope:
- Fedora 43 `x86_64`
- layered onto Fedora IoT with `rpm-ostree install ./firecracker-containerd-*.rpm`
- service-managed devmapper startup via `ExecStartPre=/usr/bin/firecracker-containerd-setup-devmapper`
- smoke-tested with:
  - `firecracker-ctr --address /run/firecracker-containerd/containerd.sock images pull --snapshotter devmapper docker.io/library/busybox:latest`
  - `firecracker-ctr --address /run/firecracker-containerd/containerd.sock run --snapshotter devmapper --runtime aws.firecracker --rm --net-host docker.io/library/busybox:latest fc-smoke /bin/sh -c "echo firecracker-containerd-ok && uname -a"`
- reboot-validated on `10.133.183.26`

Important packaging detail:
- the guest rootfs must contain a statically linked in-guest `agent` and a static `runc`
- the earlier dynamically linked guest binaries failed inside the packaged Debian guest with missing `GLIBC_2.32` / `GLIBC_2.34`
- the `.copr/Makefile` therefore builds:
  - `agent` with `STATIC_AGENT=on`
  - `_submodules/runc/runc` with `make -C _submodules/runc static`

Current intent:
- local and repo-tracked RPM path first
- later COPR hardening after the Fedora 43 `x86_64` install path is fully stable
