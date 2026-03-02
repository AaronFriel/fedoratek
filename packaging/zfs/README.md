# zfs COPR source package

This directory provides COPR SCM `make_srpm` logic.

Entry point used by COPR:

- `.copr/Makefile` target `srpm`

Current implementation generates a ZFS DKMS SRPM from upstream OpenZFS source.
