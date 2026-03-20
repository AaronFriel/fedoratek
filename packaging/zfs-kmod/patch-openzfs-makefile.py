#!/usr/bin/env python3
from pathlib import Path


def main() -> None:
    path = Path("Makefile")
    lines = path.read_text().splitlines(True)
    out: list[str] = []
    inserted = False

    for line in lines:
        out.append(line)
        if not inserted and "scripts/kmodtool" in line and "$(rpmbuild)/SOURCES" in line:
            indent = line[: len(line) - len(line.lstrip())]
            out.append(f"{indent}cp ./prepare-akmod-spec.sh $(rpmbuild)/SOURCES && \\\n")
            inserted = True

    if not inserted:
        raise SystemExit("failed to patch OpenZFS Makefile source staging for Source11")

    path.write_text("".join(out))


if __name__ == "__main__":
    main()
