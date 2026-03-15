# bcachefs akmod COPR source package

This directory provides COPR SCM `make_srpm` logic for an akmod-capable bcachefs
kernel module package.

Entry point used by COPR:

- `.copr/Makefile` target `srpm`

Current implementation:

- clones Fedora dist-git `rpms/bcachefs-tools`
- downloads the vendored source tarball directly from the upstream source URL
- generates a `bcachefs-kmod` SRPM that emits `akmod-bcachefs`

Validation status:

- Fedora 43 container SRPM generation is proven.

This is kept separate from `packaging/bcachefs`, which still builds the
userspace tools package and `dkms-bcachefs`.
