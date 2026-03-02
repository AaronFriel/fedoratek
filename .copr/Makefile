SHELL := /bin/bash

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)

.PHONY: srpm
srpm:
	set -euo pipefail; \
	subdir="$${spec:-$$PWD}"; \
	case "$$subdir" in \
	  "$(REPO_ROOT)"/packaging/bcachefs|\
	  "$(REPO_ROOT)"/packaging/bcachefs/*|\
	  packaging/bcachefs|\
	  packaging/bcachefs/*) \
	    target_makefile="$(REPO_ROOT)/packaging/bcachefs/.copr/Makefile" ;; \
	  "$(REPO_ROOT)"/packaging/zfs|\
	  "$(REPO_ROOT)"/packaging/zfs/*|\
	  packaging/zfs|\
	  packaging/zfs/*) \
	    target_makefile="$(REPO_ROOT)/packaging/zfs/.copr/Makefile" ;; \
	  *) \
	    echo "Unsupported spec/subdirectory '$$subdir'." >&2; \
	    echo "Expected packaging/bcachefs or packaging/zfs." >&2; \
	    exit 2 ;; \
	esac; \
	exec $(MAKE) -f "$$target_makefile" srpm outdir="$(outdir)" spec="$(spec)"
