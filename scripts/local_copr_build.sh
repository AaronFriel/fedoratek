#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/local_copr_build.sh [options] <package-dir>

Build a COPR SCM make_srpm package locally inside a Fedora container, then
optionally rebuild the generated SRPM to simulate the COPR binary-RPM phase.

Options:
  --release <N>      Fedora container release to use (default: 43)
  --arch <arch>      Container arch/platform target (default: host arch)
  --runtime <name>   Container runtime: docker or podman (default: auto)
  --outdir <dir>     Output directory for SRPM/RPM/log artifacts (default: mktemp)
  --srpm-only        Stop after generating the SRPM
  -h, --help         Show this help

Examples:
  scripts/local_copr_build.sh packaging/bcachefs-kmod
  scripts/local_copr_build.sh --release 43 --arch aarch64 packaging/bcachefs-kmod
  DISTGIT_REF=f43 scripts/local_copr_build.sh --srpm-only packaging/bcachefs
USAGE
}

runtime=""
release="43"
arch="$(uname -m)"
outdir=""
mode="rebuild"
package_dir=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)
      release="$2"
      shift 2
      ;;
    --arch)
      arch="$2"
      shift 2
      ;;
    --runtime)
      runtime="$2"
      shift 2
      ;;
    --outdir)
      outdir="$2"
      shift 2
      ;;
    --srpm-only)
      mode="srpm"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      package_dir="$1"
      shift
      break
      ;;
  esac
done

if [[ -z "$package_dir" && $# -gt 0 ]]; then
  package_dir="$1"
  shift
fi

if [[ -z "$package_dir" ]]; then
  echo "Missing package-dir" >&2
  usage >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ "$package_dir" != /* ]]; then
  package_dir="$repo_root/$package_dir"
fi
package_dir="$(cd "$package_dir" && pwd)"
rel_package_dir="${package_dir#$repo_root/}"

if [[ ! -f "$package_dir/.copr/Makefile" ]]; then
  echo "No .copr/Makefile under $rel_package_dir" >&2
  exit 2
fi

if [[ -z "$runtime" ]]; then
  if command -v podman >/dev/null 2>&1; then
    runtime="podman"
  elif command -v docker >/dev/null 2>&1; then
    runtime="docker"
  else
    echo "Need docker or podman" >&2
    exit 2
  fi
fi

case "$arch" in
  x86_64|amd64) platform="linux/amd64" ;;
  aarch64|arm64) platform="linux/arm64" ;;
  *) platform="" ;;
esac

if [[ -z "$outdir" ]]; then
  outdir="$(mktemp -d)"
else
  mkdir -p "$outdir"
  outdir="$(cd "$outdir" && pwd)"
fi

image="fedora:${release}"
container_args=(run --rm -v "$repo_root:/repo" -v "$outdir:/out")
if [[ -n "$platform" ]]; then
  container_args+=(--platform "$platform")
fi

pass_env_vars=(DISTGIT_URL DISTGIT_REF SOURCE_BASE_URL OPENZFS_REPO OPENZFS_REF BCACHEFS_UPSTREAM_VERSION)
for name in "${pass_env_vars[@]}"; do
  if [[ -n "${!name:-}" ]]; then
    container_args+=(-e "$name=${!name}")
  fi
done

container_args+=(
  -e "PACKAGE_DIR=$rel_package_dir"
  -e "LOCAL_COPR_MODE=$mode"
  "$image"
  bash -lc '
    set -euo pipefail
    dnf -y install make dnf-plugins-core rpm-build rpmdevtools gzip >/dev/null
    cd "/repo/${PACKAGE_DIR}"
    echo "== Generating SRPM from ${PACKAGE_DIR} =="
    make -f .copr/Makefile srpm outdir=/out
    ls -1 /out/*.src.rpm

    if [[ "${LOCAL_COPR_MODE}" == "srpm" ]]; then
      exit 0
    fi

    echo
    echo "== Installing build dependencies =="
    dnf -y builddep /out/*.src.rpm >/dev/null

    echo
    echo "== Rebuilding SRPM locally =="
    rpmbuild --rebuild /out/*.src.rpm

    echo
    echo "== Copying binary RPMs to /out =="
    find /root/rpmbuild/RPMS -type f -name "*.rpm" -exec cp -v {} /out/ \;
    find /root/rpmbuild/SRPMS -type f -name "*.src.rpm" -exec cp -v {} /out/ \;
    ls -1 /out
  '
)

printf 'Runtime: %s\n' "$runtime"
printf 'Image: %s\n' "$image"
printf 'Package dir: %s\n' "$rel_package_dir"
printf 'Output dir: %s\n' "$outdir"
if [[ -n "$platform" ]]; then
  printf 'Platform: %s\n' "$platform"
fi

"$runtime" "${container_args[@]}"

echo
echo "Artifacts written to: $outdir"
