# zfs akmod COPR source package

This directory provides COPR SCM `make_srpm` logic for an akmod-capable ZFS
kernel module package.

Entry point used by COPR:

- `.copr/Makefile` target `srpm`

Current implementation:

- clones upstream OpenZFS
- runs upstream `srpm-kmod` generation
- patches the generated `zfs-kmod.spec` to use `buildforkernels akmod`

Validation status:

- Fedora 43 container SRPM generation is proven.

This is kept separate from `packaging/zfs`, which still builds the DKMS SRPM.
