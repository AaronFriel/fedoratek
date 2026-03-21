SHELL := /bin/bash

PACKAGE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
SPEC_TEMPLATE := $(PACKAGE_DIR)/nerdctl.spec.in

NERDCTL_REPO ?= https://github.com/containerd/nerdctl.git
NERDCTL_REF ?= v2.2.1
NERDCTL_RELEASE ?= 2

.PHONY: srpm
srpm:
	set -euo pipefail; \
	out="$${outdir:-$$(pwd)}"; \
	work="$$(mktemp -d)"; \
	trap 'rm -rf "$$work"' EXIT; \
	dnf -y install git golang make rpm-build rpmdevtools tar gzip >/dev/null; \
	git clone --depth 1 --branch "$(NERDCTL_REF)" "$(NERDCTL_REPO)" "$$work/upstream"; \
	cd "$$work/upstream"; \
	full_commit="$$(git rev-parse HEAD)"; \
	version="$(NERDCTL_REF)"; \
	version="$${version#v}"; \
	release="$(NERDCTL_RELEASE)"; \
	source_dir="nerdctl-$${version}"; \
	source_tar="$${source_dir}.tar.gz"; \
	mkdir -p "$$work/SOURCES" "$$work/out"; \
	git archive --format=tar.gz --prefix="$${source_dir}/" -o "$$work/SOURCES/$${source_tar}" HEAD; \
	cp "$(PACKAGE_DIR)/nerdctl.toml" "$$work/SOURCES/nerdctl.toml"; \
	spec="$$work/nerdctl.spec"; \
	sed \
	  -e "s|@VERSION@|$${version}|g" \
	  -e "s|@RELEASE@|$${release}|g" \
	  -e "s|@COMMIT@|$${full_commit}|g" \
	  -e "s|@SOURCE_DIR@|$${source_dir}|g" \
	  -e "s|@SOURCE_TARBALL@|$${source_tar}|g" \
	  "$(SPEC_TEMPLATE)" > "$$spec"; \
	rpmbuild -bs "$$spec" \
	  --define "_sourcedir $$work/SOURCES" \
	  --define "_srcrpmdir $$work/out"; \
	mkdir -p "$$out"; \
	cp -v "$$work"/out/*.src.rpm "$$out"/
