# COPR New Project Form: Recommended Values

Use this for both projects:

- `fedoratek-testing`
- `fedoratek-stable`

## 1) Project information

- Project Name: `fedoratek-testing` (or `fedoratek-stable`)
- Description: short text (for example `Fedora bcachefs + ZFS module builds`)
- Instructions: include `dnf copr enable <owner>/<project>` and package install examples
- Homepage/Contact: your GitHub repo/issue tracker

## 2) Build options

Pick only Fedora chroots you actually need now:

- `fedora-43-x86_64`
- `fedora-43-aarch64`

If you want ZFS akmod coverage beyond Fedora 43, also add:

- `fedora-44-x86_64`

Avoid enabling rawhide by default for this repo right now. Current live COPR
results show `zfs-kmod` fails on rawhide and `bcachefs-tools` currently fails on
Fedora 44/rawhide with the present upstream/dist-git state.

Leave `External Repositories` empty initially.

## 3) Initial builds

Leave blank. Build after package source registration.

## 4) Other options

- `Follow Fedora branching`: ON
- `Create repositories manually`: OFF
- `Enable internet access during builds`: ON
  - required for this repo's current `make_srpm` flow (it clones upstream sources)
- `Multilib support`: OFF
- `Module hotfixes`: OFF
- `Generate AppStream metadata`: OFF

Everything else default/blank.
