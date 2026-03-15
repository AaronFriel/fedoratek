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
	sed -i \
	  -e 's/^%define buildforkernels newest/#define buildforkernels newest/' \
	  -e 's/^#define buildforkernels akmod/%define buildforkernels akmod/' \
	  -e '/^%define buildforkernels akmod/a %global debug_package %{nil}' \
	  -e '/^%global debug_package %{nil}/a %global _debugsource_packages 0' \
	  -e 's/%{?kernels:--for-kernels "%{?kernels}"} //g' \
	  -e 's#^chmod u+x .*#if ls ${RPM_BUILD_ROOT}%{kmodinstdir_prefix}/*/extra/*/* >/dev/null 2>\\&1; then chmod u+x ${RPM_BUILD_ROOT}%{kmodinstdir_prefix}/*/extra/*/*; fi#' \
	  rpm/generic/zfs-kmod.spec; \
	make -j"$$(nproc)" srpm-kmod; \
	mkdir -p "$$out"; \
	cp -v ./*src.rpm "$$out"/
