# runwasi-wasmtime

This package builds an SRPM that repackages the upstream `containerd-shim-wasmtime-v1`
release artifact from `containerd/runwasi` for immutable Fedora hosts.

The package purpose is narrow:

- install the official Wasmtime shim under `/usr/bin/containerd-shim-wasmtime-v1`
- keep the binary delivery repo-tracked and layerable with `rpm-ostree`
- leave the host-specific `containerd` or K3s runtime wiring explicit in host docs

Expected integration points:

- stock `containerd`: runtime type `io.containerd.wasmtime.v1`
- K3s `containerd`: runtime handler `wasmtime`

The package does not modify `containerd` configuration by itself.
