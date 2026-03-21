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
	  "$(REPO_ROOT)"/packaging/bcachefs-kmod|\
	  "$(REPO_ROOT)"/packaging/bcachefs-kmod/*|\
	  packaging/bcachefs-kmod|\
	  packaging/bcachefs-kmod/*) \
	    target_makefile="$(REPO_ROOT)/packaging/bcachefs-kmod/.copr/Makefile" ;; \
	  "$(REPO_ROOT)"/packaging/zfs|\
	  "$(REPO_ROOT)"/packaging/zfs/*|\
	  packaging/zfs|\
	  packaging/zfs/*) \
	    target_makefile="$(REPO_ROOT)/packaging/zfs/.copr/Makefile" ;; \
	  "$(REPO_ROOT)"/packaging/zfs-kmod|\
	  "$(REPO_ROOT)"/packaging/zfs-kmod/*|\
	  packaging/zfs-kmod|\
	  packaging/zfs-kmod/*) \
	    target_makefile="$(REPO_ROOT)/packaging/zfs-kmod/.copr/Makefile" ;; \
	  "$(REPO_ROOT)"/packaging/firecracker-containerd|\
	  "$(REPO_ROOT)"/packaging/firecracker-containerd/*|\
	  packaging/firecracker-containerd|\
	  packaging/firecracker-containerd/*) \
	    target_makefile="$(REPO_ROOT)/packaging/firecracker-containerd/.copr/Makefile" ;; \
	  "$(REPO_ROOT)"/packaging/nerdctl|\
	  "$(REPO_ROOT)"/packaging/nerdctl/*|\
	  packaging/nerdctl|\
	  packaging/nerdctl/*) \
	    target_makefile="$(REPO_ROOT)/packaging/nerdctl/.copr/Makefile" ;; \
	  *) \
	    echo "Unsupported spec/subdirectory '$$subdir'." >&2; \
	    echo "Expected packaging/bcachefs, packaging/bcachefs-kmod, packaging/zfs, packaging/zfs-kmod, packaging/firecracker-containerd, or packaging/nerdctl." >&2; \
	    exit 2 ;; \
	esac; \
	exec $(MAKE) -f "$$target_makefile" srpm outdir="$(outdir)" spec="$(spec)"
