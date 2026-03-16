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
	cp prepare-akmod-spec.sh akmod_install_override.specfrag "$$work/zfs/"; \
	chmod +x "$$work/zfs/prepare-akmod-spec.sh"; \
	cd "$$work/zfs"; \
	./autogen.sh; \
	./configure --with-config=srpm; \
	sed -i \
	  -e '/^Source10:[[:space:]]*kmodtool/a Source11:       prepare-akmod-spec.sh' \
	  -e '/^%define buildforkernels akmod/a %global debug_package %{nil}' \
	  -e '/^%global debug_package %{nil}/a %global _debugsource_packages 0' \
	  -e 's#^chmod u+x .*#if ls ${RPM_BUILD_ROOT}%{kmodinstdir_prefix}/*/extra/*/* >/dev/null 2>\\&1; then chmod u+x ${RPM_BUILD_ROOT}%{kmodinstdir_prefix}/*/extra/*/*; fi#' \
	  -e '/^%description/i %package -n zfs-kmod-common\nSummary: Common metadata for ZFS akmod packaging\nBuildArch: noarch\nProvides: zfs-kmod-common = %{?epoch:%{epoch}:}%{version}-%{release}\n\n%description -n zfs-kmod-common\nCompatibility package for ZFS akmod packaging.\n' \
	  -e '/^%{?akmod_install}/a install -Dpm0644 /dev/null ${RPM_BUILD_ROOT}%{_datadir}/doc/zfs-kmod-common/README' \
	  -e '/^%clean/i %files -n zfs-kmod-common\n%{_datadir}/doc/zfs-kmod-common/README\n' \
	  rpm/generic/zfs-kmod.spec; \
	awk 'BEGIN { while ((getline line < "akmod_install_override.specfrag") > 0) override = override line ORS } /^%install$$/ { printf "%s", override } { print }' rpm/generic/zfs-kmod.spec > rpm/generic/zfs-kmod.spec.new; \
	mv rpm/generic/zfs-kmod.spec.new rpm/generic/zfs-kmod.spec; \
	make -j"$$(nproc)" srpm-kmod; \
	mkdir -p "$$out"; \
	cp -v ./*src.rpm "$$out"/
