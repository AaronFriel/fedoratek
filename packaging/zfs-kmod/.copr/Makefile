SHELL := /bin/bash

OPENZFS_REPO ?= https://github.com/openzfs/zfs.git
OPENZFS_REF ?= master

.PHONY: srpm
srpm:
	set -euo pipefail; \
	out="$${outdir:-$$(pwd)}"; \
	work="$$(mktemp -d)"; \
	trap 'rm -rf "$$work"' EXIT; \
	dnf -y install git make autoconf automake libtool rpm-build rpmdevtools >/dev/null; \
	git clone --depth 1 --branch "$(OPENZFS_REF)" "$(OPENZFS_REPO)" "$$work/zfs"; \
	cp prepare-akmod-spec.sh akmod_install_override.specfrag patch-openzfs-makefile.py patch-zfs-kmod-spec.py "$$work/zfs/"; \
	chmod +x "$$work/zfs/prepare-akmod-spec.sh"; \
	cd "$$work/zfs"; \
	./autogen.sh; \
	./configure --with-config=srpm; \
	python3 ./patch-openzfs-makefile.py; \
	python3 ./patch-zfs-kmod-spec.py rpm/generic/zfs-kmod.spec akmod_install_override.specfrag; \
	make -j"$$(nproc)" srpm-kmod; \
	mkdir -p "$$out"; \
	cp -v ./*src.rpm "$$out"/
