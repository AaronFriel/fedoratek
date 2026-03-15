#!/usr/bin/env python3
import argparse
import gzip
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API_BASE = "https://copr.fedorainfracloud.org/api_3"
STANDARD_LOGS = [
    "builder-live.log.gz",
    "build.log.gz",
    "root.log.gz",
    "backend.log.gz",
    "state.log.gz",
    "build.info",
    "chroot_scan.tar.gz",
]
FINAL_STATES = {"failed", "succeeded", "canceled", "skipped"}


def http_get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "fedoratek-copr-watch/1"})
    with urllib.request.urlopen(req) as resp:
        return resp.read()


def http_get_json(url: str):
    return json.loads(http_get(url).decode("utf-8"))


def parse_project(ref: str):
    if "/" not in ref:
        raise SystemExit(f"Project must be OWNER/PROJECT, got: {ref}")
    owner, project = ref.split("/", 1)
    return owner, project


def build_list(owner: str, project: str):
    params = urllib.parse.urlencode({"ownername": owner, "projectname": project})
    return http_get_json(f"{API_BASE}/build/list?{params}")["items"]


def build_info(build_id: int):
    return http_get_json(f"{API_BASE}/build/{build_id}")


def chroot_info(build_id: int, chroot: str):
    params = urllib.parse.urlencode({"build_id": build_id, "chrootname": chroot})
    return http_get_json(f"{API_BASE}/build-chroot?{params}")


def find_build(owner: str, project: str, package: str | None, build_id: int | None):
    if build_id is not None:
        return build_info(build_id)
    items = build_list(owner, project)
    if package:
        items = [item for item in items if item["source_package"]["name"] == package]
    if not items:
        raise SystemExit("No matching builds found")
    return items[0]


def format_ts(epoch):
    if not epoch:
        return "-"
    return time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime(epoch))


def print_summary(build, chroots):
    print(f"Build: {build['id']}  state={build['state']}  package={build['source_package']['name']}  version={build['source_package']['version']}")
    print(f"Project: {build['ownername']}/{build['projectname']}")
    print(f"Submitted: {format_ts(build.get('submitted_on'))}")
    print(f"Started:   {format_ts(build.get('started_on'))}")
    print(f"Ended:     {format_ts(build.get('ended_on'))}")
    print(f"SRPM:      {build['source_package']['url']}")
    print("Chroots:")
    for info in chroots:
        print(f"  - {info['name']}: {info['state']}  {info['result_url']}")


def download_logs(chroots, download_dir: Path):
    for info in chroots:
        chroot_dir = download_dir / info["name"]
        chroot_dir.mkdir(parents=True, exist_ok=True)
        for log_name in STANDARD_LOGS:
            url = info["result_url"].rstrip("/") + "/" + log_name
            dest = chroot_dir / log_name
            try:
                data = http_get(url)
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    continue
                raise
            dest.write_bytes(data)
            print(f"downloaded {dest}")


def maybe_show_log(chroots, log_name: str, show_chroot: str | None):
    targets = [info for info in chroots if show_chroot in (None, info["name"])]
    if not targets:
        raise SystemExit(f"No chroot matched {show_chroot!r}")
    for info in targets:
        candidates = [log_name]
        if not log_name.endswith(".gz"):
            candidates.insert(0, log_name + ".gz")
        data = None
        chosen = None
        for candidate in candidates:
            url = info["result_url"].rstrip("/") + "/" + candidate
            try:
                data = http_get(url)
                chosen = candidate
                break
            except urllib.error.HTTPError as e:
                if e.code != 404:
                    raise
        if data is None:
            print(f"[{info['name']}] missing {log_name}")
            continue
        print(f"===== {info['name']} {chosen} =====")
        if chosen.endswith(".gz"):
            text = gzip.decompress(data).decode("utf-8", errors="replace")
        else:
            text = data.decode("utf-8", errors="replace")
        print(text.rstrip())


def main():
    ap = argparse.ArgumentParser(description="Poll public COPR build state and fetch logs without copr-cli")
    ap.add_argument("project", help="OWNER/PROJECT")
    ap.add_argument("--package", help="Filter to latest build for this package")
    ap.add_argument("--build-id", type=int, help="Inspect a specific build id")
    ap.add_argument("--poll", type=int, default=0, help="Poll every N seconds until build reaches a final state")
    ap.add_argument("--download-dir", help="Download standard chroot logs into this directory")
    ap.add_argument("--show-log", help="Print one log to stdout, for example build.log or builder-live.log")
    ap.add_argument("--chroot", help="Restrict --show-log to one chroot")
    args = ap.parse_args()

    owner, project = parse_project(args.project)

    while True:
        build = find_build(owner, project, args.package, args.build_id)
        chroots = [chroot_info(build["id"], name) for name in build["chroots"]]
        print_summary(build, chroots)

        if args.download_dir:
            download_logs(chroots, Path(args.download_dir) / str(build["id"]))
        if args.show_log:
            maybe_show_log(chroots, args.show_log, args.chroot)

        if args.poll <= 0 or build["state"] in FINAL_STATES:
            break
        print()
        time.sleep(args.poll)


if __name__ == "__main__":
    main()
