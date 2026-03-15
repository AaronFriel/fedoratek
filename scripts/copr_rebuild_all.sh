#!/usr/bin/env bash
set -euo pipefail

COPR_OWNER="${COPR_OWNER:-friel}"
COPR_PROJECT_TESTING="${COPR_PROJECT_TESTING:-fedoratek-testing}"
COPR_PROJECT_STABLE="${COPR_PROJECT_STABLE:-fedoratek-stable}"
COPR_TARGET_PROJECTS="${COPR_TARGET_PROJECTS:-stable}"
COPR_TARGET_CHROOTS="${COPR_TARGET_CHROOTS:-}"

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

IFS=',' read -r -a CHROOTS <<< "${COPR_TARGET_CHROOTS}"
PACKAGES=(bcachefs-tools bcachefs-kmod zfs-dkms zfs-kmod)

for project in "${PROJECTS[@]}"; do
  for pkg in "${PACKAGES[@]}"; do
    echo "Triggering build-package ${project}:${pkg}"
    if [[ -n "${COPR_TARGET_CHROOTS}" ]]; then
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
