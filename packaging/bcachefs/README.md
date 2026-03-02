# bcachefs COPR source package

This directory provides COPR SCM `make_srpm` logic.

Entry point used by COPR:

- `.copr/Makefile` target `srpm`

Current implementation builds SRPM from Fedora dist-git `rpms/bcachefs-tools` (configurable via env).
