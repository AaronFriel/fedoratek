#!/usr/bin/env bash
set -euo pipefail

COPR_OWNER="${COPR_OWNER:-friel}"
COPR_PROJECT_TESTING="${COPR_PROJECT_TESTING:-fedoratek-testing}"
COPR_PROJECT_STABLE="${COPR_PROJECT_STABLE:-fedoratek-stable}"
COPR_TARGET_PROJECTS="${COPR_TARGET_PROJECTS:-stable}"
COPR_TARGET_CHROOTS="${COPR_TARGET_CHROOTS:-}"
COPR_CHROOTS_BCACHEFS_TOOLS="${COPR_CHROOTS_BCACHEFS_TOOLS:-fedora-43-x86_64,fedora-43-aarch64}"
COPR_CHROOTS_BCACHEFS_KMOD="${COPR_CHROOTS_BCACHEFS_KMOD:-fedora-43-x86_64,fedora-43-aarch64}"
COPR_CHROOTS_ZFS_DKMS="${COPR_CHROOTS_ZFS_DKMS:-}"
COPR_CHROOTS_ZFS_KMOD="${COPR_CHROOTS_ZFS_KMOD:-fedora-43-x86_64,fedora-43-aarch64,fedora-44-x86_64}"
COPR_CHROOTS_FIRECRACKER_CONTAINERD="${COPR_CHROOTS_FIRECRACKER_CONTAINERD:-fedora-43-x86_64}"

PROJECTS=()
case "${COPR_TARGET_PROJECTS}" in
  testing) PROJECTS+=("${COPR_OWNER}/${COPR_PROJECT_TESTING}") ;;
  stable) PROJECTS+=("${COPR_OWNER}/${COPR_PROJECT_STABLE}") ;;
  both)
    PROJECTS+=("${COPR_OWNER}/${COPR_PROJECT_TESTING}")
    PROJECTS+=("${COPR_OWNER}/${COPR_PROJECT_STABLE}")
    ;;
  *)
    echo "Unsupported COPR_TARGET_PROJECTS=${COPR_TARGET_PROJECTS} (expected testing|stable|both)" >&2
    exit 2
    ;;
esac

package_chroots() {
  local pkg="$1"
  case "${pkg}" in
    bcachefs-tools) printf '%s\n' "${COPR_CHROOTS_BCACHEFS_TOOLS}" ;;
    bcachefs-kmod) printf '%s\n' "${COPR_CHROOTS_BCACHEFS_KMOD}" ;;
    zfs-dkms) printf '%s\n' "${COPR_CHROOTS_ZFS_DKMS}" ;;
    zfs-kmod) printf '%s\n' "${COPR_CHROOTS_ZFS_KMOD}" ;;
    firecracker-containerd) printf '%s\n' "${COPR_CHROOTS_FIRECRACKER_CONTAINERD}" ;;
    *)
      echo "Unknown package ${pkg}" >&2
      exit 2
      ;;
  esac
}

PACKAGES=(bcachefs-tools bcachefs-kmod zfs-dkms zfs-kmod firecracker-containerd)

for project in "${PROJECTS[@]}"; do
  for pkg in "${PACKAGES[@]}"; do
    echo "Triggering build-package ${project}:${pkg}"
    target_chroots="${COPR_TARGET_CHROOTS}"
    if [[ -z "${target_chroots}" ]]; then
      target_chroots="$(package_chroots "${pkg}")"
    fi

    if [[ -n "${target_chroots}" ]]; then
      IFS=',' read -r -a CHROOTS <<< "${target_chroots}"
      args=()
      for ch in "${CHROOTS[@]}"; do
        [[ -n "${ch}" ]] && args+=(-r "${ch}")
      done
      copr-cli build-package "${project}" --name "${pkg}" --nowait "${args[@]}"
    else
      copr-cli build-package "${project}" --name "${pkg}" --nowait
    fi
  done
done
