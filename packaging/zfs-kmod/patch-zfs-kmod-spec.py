#!/usr/bin/env python3
from pathlib import Path
import sys


COMMON_PKG = """%package -n zfs-kmod-common
Summary: Common metadata for ZFS akmod packaging
BuildArch: noarch
Provides: zfs-kmod-common = %{?epoch:%{epoch}:}%{version}-%{release}

%description -n zfs-kmod-common
Compatibility package for ZFS akmod packaging.
"""

COMMON_FILES = """%files -n zfs-kmod-common
%{_datadir}/doc/zfs-kmod-common/README
"""

FIXED_CHMOD = (
    "if ls ${RPM_BUILD_ROOT}%{kmodinstdir_prefix}/*/extra/*/* >/dev/null 2>&1; "
    "then chmod u+x ${RPM_BUILD_ROOT}%{kmodinstdir_prefix}/*/extra/*/*; fi"
)

README_INSTALL = "install -Dpm0644 /dev/null ${RPM_BUILD_ROOT}%{_datadir}/doc/zfs-kmod-common/README"


def require_replace(text: str, old: str, new: str, what: str) -> str:
    if old not in text:
        raise SystemExit(f"failed to patch zfs-kmod spec: missing {what}")
    return text.replace(old, new, 1)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: patch-zfs-kmod-spec.py <spec> <akmod_override_frag>")

    spec_path = Path(sys.argv[1])
    override_path = Path(sys.argv[2])

    text = spec_path.read_text()
    override = override_path.read_text().rstrip() + "\n"

    text = require_replace(
        text,
        "Source10:       kmodtool\n",
        "Source10:       kmodtool\nSource11:       prepare-akmod-spec.sh\n",
        "Source11 insertion point",
    )
    buildforkernels_old = (
        "%define buildforkernels newest\n"
        "#define buildforkernels current\n"
        "#define buildforkernels akmod\n"
    )
    buildforkernels_new = (
        "#define buildforkernels newest\n"
        "#define buildforkernels current\n"
        "%define buildforkernels akmod\n"
        "%global debug_package %{nil}\n"
        "%global _debugsource_packages 0\n"
    )
    text = require_replace(
        text,
        buildforkernels_old,
        buildforkernels_new,
        "buildforkernels block",
    )
    text = require_replace(
        text,
        "%description\n",
        COMMON_PKG + "\n%description\n",
        "package insertion point",
    )
    text = require_replace(
        text,
        "%install\n",
        "%install\n" + override,
        "%install section",
    )
    text = require_replace(
        text,
        "%clean\n",
        COMMON_FILES + "\n%clean\n",
        "%clean section",
    )

    if "chmod u+x " in text:
        for line in text.splitlines():
            if line.startswith("chmod u+x "):
                text = text.replace(line, FIXED_CHMOD, 1)
                break
    else:
        raise SystemExit("failed to patch zfs-kmod spec: missing chmod line")

    text = require_replace(
        text,
        "%{?akmod_install}\n",
        "%{?akmod_install}\n" + README_INSTALL + "\n",
        "akmod install marker",
    )

    spec_path.write_text(text)


if __name__ == "__main__":
    main()
