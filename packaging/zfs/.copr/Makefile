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
	cd "$$work/zfs"; \
	./autogen.sh; \
	./configure --with-config=srpm; \
	make -j"$$(nproc)" srpm-dkms; \
	mkdir -p "$$out"; \
	cp -v ./*src.rpm "$$out"/
