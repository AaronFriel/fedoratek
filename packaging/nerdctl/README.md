# nerdctl packaging

This package provides the upstream `nerdctl` CLI as a repo-tracked RPM for
Fedora-based immutable hosts.

Validated scope:
- Fedora 43 `x86_64`
- layered onto Fedora IoT with `rpm-ostree install ./nerdctl-*.rpm`
- Fedora-specific CNI path baked into `/etc/nerdctl/nerdctl.toml`:
  - `cni_path = "/usr/libexec/cni"`
- proven on `10.133.183.26` against the stock `containerd` socket with a normal
  `nerdctl run` workflow
- proven against the dedicated `firecracker-containerd` socket for image
  operations such as `nerdctl images` and `nerdctl pull`

Current compatibility boundary:
- `nerdctl --address /run/containerd/containerd.sock run ...` works as expected
  on the host after the packaged Fedora CNI-path override
- `nerdctl --address /run/firecracker-containerd/containerd.sock run --runtime aws.firecracker ...`
  still fails on this host because `firecracker-containerd`'s jailer/runtime path
  does not currently accept nerdctl's generated `/var/lib/nerdctl/.../resolv.conf`
  bind mount
- continue using `firecracker-ctr` for Firecracker-backed task execution until
  that runtime mismatch is solved

Current intent:
- give the host a normal containerd client UX without mutable `/usr/local`
  installs
- keep the package source-built from upstream release tags
- document the current Firecracker runtime limitation instead of overclaiming
  direct `nerdctl run` support there
