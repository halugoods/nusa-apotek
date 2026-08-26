#!/usr/bin/env python3
"""Replace APK assets in each NUSA GitHub release without accumulating old files.

Usage: python _release_all.py <release-tag> [changelog-file.md]

Release notes default to a short line, but if a changelog markdown file is
given (e.g. CHANGELOG_v2.1.5.md), its content is used as the notes so each
GitHub release carries the full update log. When the release already exists,
the notes are updated too.
"""
import os
import subprocess
import sys

BASE_DIR = r"C:\Users\ertyui\ZCodeProject\nusa_kasir"
OUTPUT_DIR = os.path.join(BASE_DIR, "nusa_builds")

VARIANTS = {
    "kelontong": "halugoods/nusa-kelontong",
    "fnb": "halugoods/nusa-fnb",
    "laundry": "halugoods/nusa-laundry",
    "bengkel": "halugoods/nusa-bengkel",
    "salon": "halugoods/nusa-salon",
    "apotek": "halugoods/nusa-apotek",
    "fotocopy": "halugoods/nusa-fotocopy",
    "servis": "halugoods/nusa-servis",
}


def run(args):
    return subprocess.run(args, cwd=BASE_DIR, check=True, text=True,
                          capture_output=True)


def main():
    args = sys.argv[1:]
    tag = args[0] if args else None
    changelog = args[1] if len(args) > 1 else None
    if not tag:
        print("Usage: python _release_all.py <release-tag> [changelog-file.md]",
              file=sys.stderr)
        return 2

    notes = f"Release {tag} — build {tag}"
    if changelog:
        changelog_path = os.path.join(BASE_DIR, changelog)
        if not os.path.isfile(changelog_path):
            print(f"Changelog not found: {changelog_path}", file=sys.stderr)
            return 2
        with open(changelog_path, "r", encoding="utf-8") as fh:
            notes = fh.read().strip()
        print(f"Using changelog notes from {changelog_path}")

    for variant, repo in VARIANTS.items():
        apk = os.path.join(OUTPUT_DIR, f"nusa-{variant}.apk")
        if not os.path.isfile(apk):
            print(f"Missing APK: {apk}", file=sys.stderr)
            return 1

        print(f"\n{repo} ({tag})")

        # Create release idempotently — if tag already exists, edit instead.
        try:
            print(f"  Creating release {tag}...")
            run(["gh", "release", "create", tag, "--repo", repo,
                 "--title", f"NUSA {variant} {tag}",
                 "--notes", notes])
        except subprocess.CalledProcessError as e:
            if e.returncode == 1:
                # Tag already exists — update notes only (don't re-upload assets).
                print(f"  Release {tag} already exists, skipping upload.")
            else:
                raise
            assets = subprocess.run(
                ["gh", "release", "view", tag, "--repo", repo,
                 "--json", "assets", "--jq", ".assets[].name"],
                cwd=BASE_DIR, text=True, capture_output=True,
            ).stdout.splitlines()
            for asset in assets:
                if asset.lower().endswith(".apk"):
                    print(f"  Removing old asset: {asset}")
                    run(["gh", "release", "delete-asset", tag, asset,
                         "--repo", repo, "--yes"])

        print(f"  Uploading: {os.path.basename(apk)}")
        run(["gh", "release", "upload", tag, apk, "--repo", repo,
             "--clobber"])

    print("\nAll APK assets replaced successfully.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

