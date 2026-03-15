SHELL := /bin/bash

PACKAGE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
SPEC_TEMPLATE := $(PACKAGE_DIR)/bcachefs-kmod.spec.in

DISTGIT_URL ?= https://src.fedoraproject.org/rpms/bcachefs-tools.git
DISTGIT_REF ?= f43
SOURCE_BASE_URL ?= https://evilpiepirate.org/bcachefs-tools

.PHONY: srpm
srpm:
	set -euo pipefail; \
	out="$${outdir:-$$(pwd)}"; \
	work="$$(mktemp -d)"; \
	trap 'rm -rf "$$work"' EXIT; \
	dnf -y install curl git kmodtool rpm-build rpmdevtools tar zstd >/dev/null; \
	git clone --depth 1 --branch "$(DISTGIT_REF)" "$(DISTGIT_URL)" "$$work/distgit"; \
	cd "$$work/distgit"; \
	version="$$(rpmspec -q --srpm --qf '%{VERSION}' bcachefs-tools.spec)"; \
	source_name="bcachefs-tools-vendored-$$version.tar.zst"; \
	source_path="$$work/$$source_name"; \
	curl -fsSL "$(SOURCE_BASE_URL)/$$source_name" -o "$$source_path"; \
	tar --zstd -tf "$$source_path" > "$$work/tar.list"; \
	topdir="$$(awk -F/ 'NR==1 { print $$1; exit }' "$$work/tar.list")"; \
	spec_template="$(SPEC_TEMPLATE)"; \
	spec="$$work/bcachefs-kmod.spec"; \
	sed \
	  -e "s|@VERSION@|$$version|g" \
	  -e "s|@SOURCE0@|$$source_name|g" \
	  -e "s|@TOPDIR@|$$topdir|g" \
	  "$$spec_template" > "$$spec"; \
	mkdir -p "$$work/out"; \
	rpmbuild -bs "$$spec" \
	  --define "_sourcedir $$work" \
	  --define "_srcrpmdir $$work/out"; \
	mkdir -p "$$out"; \
	cp -v "$$work"/out/*.src.rpm "$$out"/
