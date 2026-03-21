SHELL := /bin/bash

PACKAGE_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
SPEC_TEMPLATE := $(PACKAGE_DIR)/runwasi-wasmtime.spec.in

RUNWASI_WASMTIME_VERSION ?= 0.6.0
RUNWASI_WASMTIME_RELEASE ?= 1
RUNWASI_WASMTIME_SOURCE_URL ?= https://github.com/containerd/runwasi/releases/download/containerd-shim-wasmtime/v$(RUNWASI_WASMTIME_VERSION)/containerd-shim-wasmtime-x86_64-linux-musl.tar.gz

.PHONY: srpm
srpm:
	set -euo pipefail; \
	out="$${outdir:-$$(pwd)}"; \
	work="$$(mktemp -d)"; \
	trap 'rm -rf "$$work"' EXIT; \
	dnf -y install curl rpm-build rpmdevtools tar gzip >/dev/null; \
	mkdir -p "$$work/SOURCES" "$$work/out"; \
	curl -L --fail --output "$$work/SOURCES/containerd-shim-wasmtime-v$(RUNWASI_WASMTIME_VERSION)-x86_64-linux-musl.tar.gz" "$(RUNWASI_WASMTIME_SOURCE_URL)"; \
	spec="$$work/runwasi-wasmtime.spec"; \
	sed \
	  -e "s|@VERSION@|$(RUNWASI_WASMTIME_VERSION)|g" \
	  -e "s|@RELEASE@|$(RUNWASI_WASMTIME_RELEASE)|g" \
	  -e "s|@SOURCE_URL@|$(RUNWASI_WASMTIME_SOURCE_URL)|g" \
	  "$(SPEC_TEMPLATE)" > "$$spec"; \
	rpmbuild -bs "$$spec" \
	  --define "_sourcedir $$work/SOURCES" \
	  --define "_srcrpmdir $$work/out"; \
	mkdir -p "$$out"; \
	cp -v "$$work"/out/*.src.rpm "$$out"/
