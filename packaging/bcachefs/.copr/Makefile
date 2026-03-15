SHELL := /bin/bash

DISTGIT_URL ?= https://src.fedoraproject.org/rpms/bcachefs-tools.git
DISTGIT_REF ?= f43
BCACHEFS_UPSTREAM_VERSION ?= 1.37.0
BCACHEFS_RPMBUILD_FLAGS ?= --with dkms
BCACHEFS_FORCE_DKMS ?= 1

.PHONY: srpm
srpm:
	set -euo pipefail; \
	out="$${outdir:-$$(pwd)}"; \
	work="$$(mktemp -d)"; \
	trap 'rm -rf "$$work"' EXIT; \
	if ! command -v rpmspec >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then \
	  dnf -y install curl git rpm-build rpmdevtools >/dev/null; \
	fi; \
	git clone --depth 1 --branch "$(DISTGIT_REF)" "$(DISTGIT_URL)" "$$work/src"; \
	cd "$$work/src"; \
	sed -i -E 's/^(Version:[[:space:]]+).*/\1$(BCACHEFS_UPSTREAM_VERSION)/' bcachefs-tools.spec; \
	if [[ "$(BCACHEFS_FORCE_DKMS)" == "1" ]]; then \
	  sed -i -E 's/^%bcond[[:space:]]+dkms[[:space:]]+0/%bcond dkms 1/' bcachefs-tools.spec; \
	fi; \
	if ! grep -Fq '%{_datadir}/bash-completion/completions/bcachefs' bcachefs-tools.spec; then \
	  awk '1; $$0=="%{_udevrulesdir}/64-bcachefs.rules"{print "%{_datadir}/bash-completion/completions/bcachefs"}' \
	    bcachefs-tools.spec > bcachefs-tools.spec.new; \
	  mv bcachefs-tools.spec.new bcachefs-tools.spec; \
	fi; \
	rpmspec -P bcachefs-tools.spec > "$$work/expanded.spec"; \
	for source_idx in 0 1 2; do \
	  url="$$(awk '/^Source'"$$source_idx"':/ { print $$2; exit }' "$$work/expanded.spec")"; \
	  curl -fsSLO "$$url"; \
	done; \
	rpmbuild -bs bcachefs-tools.spec \
	  $(BCACHEFS_RPMBUILD_FLAGS) \
	  --define "_sourcedir $$PWD" \
	  --define "_srcrpmdir $$work/out"; \
	mkdir -p "$$out"; \
	cp -v "$$work"/out/*.src.rpm "$$out"/
