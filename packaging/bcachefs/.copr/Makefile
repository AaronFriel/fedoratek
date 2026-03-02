SHELL := /bin/bash

DISTGIT_URL ?= https://src.fedoraproject.org/rpms/bcachefs-tools.git
DISTGIT_REF ?= rawhide
BCACHEFS_RPMBUILD_FLAGS ?= --with dkms

.PHONY: srpm
srpm:
	set -euo pipefail; \
	out="$${outdir:-$$(pwd)}"; \
	work="$$(mktemp -d)"; \
	trap 'rm -rf "$$work"' EXIT; \
	if ! command -v spectool >/dev/null 2>&1; then \
	  dnf -y install git rpm-build rpmdevtools >/dev/null; \
	fi; \
	git clone --depth 1 --branch "$(DISTGIT_REF)" "$(DISTGIT_URL)" "$$work/src"; \
	cd "$$work/src"; \
	spectool -g -R bcachefs-tools.spec; \
	rpmbuild -bs bcachefs-tools.spec \
	  $(BCACHEFS_RPMBUILD_FLAGS) \
	  --define "_sourcedir $$PWD" \
	  --define "_srcrpmdir $$work/out"; \
	mkdir -p "$$out"; \
	cp -v "$$work"/out/*.src.rpm "$$out"/
