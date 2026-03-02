#!/usr/bin/env bash
set -euo pipefail

COPR_OWNER="${COPR_OWNER:-friel}"
COPR_PROJECT_TESTING="${COPR_PROJECT_TESTING:-storage-modules-testing}"
COPR_PROJECT_STABLE="${COPR_PROJECT_STABLE:-storage-modules-stable}"
COPR_SCM_BRANCH="${COPR_SCM_BRANCH:-main}"
COPR_REPO_URL="${COPR_REPO_URL:-https://github.com/aaronfriel/fedoratek.git}"
COPR_TARGET_CHROOTS="${COPR_TARGET_CHROOTS:-fedora-43-x86_64,fedora-43-aarch64}"
COPR_ENABLE_NET="${COPR_ENABLE_NET:-on}"

case "${COPR_ENABLE_NET}" in
  on|off) ;;
  *)
    echo "Unsupported COPR_ENABLE_NET=${COPR_ENABLE_NET} (expected on|off)" >&2
    exit 2
    ;;
esac

IFS=',' read -r -a CHROOTS <<< "${COPR_TARGET_CHROOTS}"

create_project_if_needed() {
  local owner_project="$1"
  local project_name="$2"

  if curl -fsS "https://copr.fedorainfracloud.org/api_3/project?ownername=${COPR_OWNER}&projectname=${project_name}" >/dev/null 2>&1; then
    echo "Project exists: ${owner_project}"
    copr-cli modify "${owner_project}" --enable-net "${COPR_ENABLE_NET}" >/dev/null
    return
  fi

  local args=()
  for ch in "${CHROOTS[@]}"; do
    args+=(--chroot "${ch}")
  done

  echo "Creating project: ${owner_project}"
  copr-cli create "${project_name}" "${args[@]}" \
    --enable-net "${COPR_ENABLE_NET}" \
    --description "Fedora bcachefs + ZFS module builds (${project_name})" \
    --instructions "Enable with: dnf copr enable ${owner_project}" \
    --homepage "${COPR_REPO_URL}" \
    --contact "${COPR_REPO_URL}"
}

ensure_scm_package() {
  local owner_project="$1"
  local pkg_name="$2"
  local subdir="$3"
  local webhook="$4"

  if copr-cli get-package "${owner_project}" --name "${pkg_name}" >/dev/null 2>&1; then
    echo "Updating SCM package ${pkg_name} in ${owner_project}"
    copr-cli edit-package-scm "${owner_project}" \
      --name "${pkg_name}" \
      --clone-url "${COPR_REPO_URL}" \
      --commit "${COPR_SCM_BRANCH}" \
      --subdir "${subdir}" \
      --method make_srpm \
      --webhook-rebuild "${webhook}"
  else
    echo "Adding SCM package ${pkg_name} to ${owner_project}"
    copr-cli add-package-scm "${owner_project}" \
      --name "${pkg_name}" \
      --clone-url "${COPR_REPO_URL}" \
      --commit "${COPR_SCM_BRANCH}" \
      --subdir "${subdir}" \
      --method make_srpm \
      --webhook-rebuild "${webhook}"
  fi
}

TESTING_REF="${COPR_OWNER}/${COPR_PROJECT_TESTING}"
STABLE_REF="${COPR_OWNER}/${COPR_PROJECT_STABLE}"

create_project_if_needed "${TESTING_REF}" "${COPR_PROJECT_TESTING}"
create_project_if_needed "${STABLE_REF}" "${COPR_PROJECT_STABLE}"

ensure_scm_package "${TESTING_REF}" "bcachefs-tools" "packaging/bcachefs" "on"
ensure_scm_package "${TESTING_REF}" "zfs-dkms" "packaging/zfs" "on"

ensure_scm_package "${STABLE_REF}" "bcachefs-tools" "packaging/bcachefs" "off"
ensure_scm_package "${STABLE_REF}" "zfs-dkms" "packaging/zfs" "off"

echo "Bootstrap complete."
