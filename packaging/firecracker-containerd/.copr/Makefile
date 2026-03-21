SHELL := /bin/bash

PACKAGE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
SPEC_TEMPLATE := $(PACKAGE_DIR)/firecracker-containerd.spec.in

FICD_REPO ?= https://github.com/firecracker-microvm/firecracker-containerd.git
FICD_REF ?= main

.PHONY: srpm
srpm:
	set -euo pipefail; \
	out="$${outdir:-$$(pwd)}"; \
	work="$$(mktemp -d)"; \
	trap 'rm -rf "$$work"' EXIT; \
	dnf -y install bc curl debootstrap findutils gcc git glibc-static golang libseccomp-devel libseccomp-static make pkgconf-pkg-config rpm-build rpmdevtools squashfs-tools tar gzip >/dev/null; \
	git clone --depth 1 --branch "$(FICD_REF)" "$(FICD_REPO)" "$$work/upstream"; \
	cd "$$work/upstream"; \
	full_commit="$$(git rev-parse HEAD)"; \
	short_commit="$$(git rev-parse --short=12 HEAD)"; \
	commit_date="$$(git show -s --format=%cd --date=format:%Y%m%d HEAD)"; \
	version="0"; \
	release="0.3.git$${commit_date}.$${short_commit}"; \
	source_dir="firecracker-containerd-$${short_commit}"; \
	source_tar="$${source_dir}.tar.gz"; \
	mkdir -p "$$work/SOURCES" "$$work/out"; \
	git archive --format=tar.gz --prefix="$${source_dir}/" -o "$$work/SOURCES/$${source_tar}" HEAD; \
	git submodule update --init --recursive _submodules/runc; \
	make clean -C agent; \
	GOFLAGS=-buildvcs=false make STATIC_AGENT=on -C agent agent; \
	make -C _submodules/runc static; \
	mkdir -p tools/image-builder/tmp tools/image-builder/files_ephemeral/usr/local/bin; \
	install -D -m 0755 agent/agent tools/image-builder/files_ephemeral/usr/local/bin/agent; \
	install -D -m 0755 _submodules/runc/runc tools/image-builder/files_ephemeral/usr/local/bin/runc; \
	make -C tools/image-builder rootfs.img rootfs-debug.img; \
	make default-vmlinux; \
	cp -v tools/image-builder/rootfs.img "$$work/SOURCES/default-rootfs.img"; \
	cp -v tools/image-builder/rootfs-debug.img "$$work/SOURCES/rootfs-debug.img"; \
	cp -v default-vmlinux.bin "$$work/SOURCES/default-vmlinux.bin"; \
	cp -v "$(PACKAGE_DIR)/firecracker-containerd.service" "$$work/SOURCES/"; \
	cp -v "$(PACKAGE_DIR)/firecracker-containerd-config.toml" "$$work/SOURCES/"; \
	cp -v "$(PACKAGE_DIR)/firecracker-runtime.json" "$$work/SOURCES/"; \
	cp -v "$(PACKAGE_DIR)/firecracker-containerd-setup-devmapper" "$$work/SOURCES/"; \
	spec="$$work/firecracker-containerd.spec"; \
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
