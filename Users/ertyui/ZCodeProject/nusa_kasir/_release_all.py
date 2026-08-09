#!/usr/bin/env python3
"""Replace APK assets in each NUSA GitHub release without accumulating old files."""
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
    tag = sys.argv[1] if len(sys.argv) == 2 else None
    if not tag:
        print("Usage: python _release_all.py <release-tag>", file=sys.stderr)
        return 2

    for variant, repo in VARIANTS.items():
        apk = os.path.join(OUTPUT_DIR, f"nusa-{variant}.apk")
        if not os.path.isfile(apk):
            print(f"Missing APK: {apk}", file=sys.stderr)
            return 1

        print(f"\n{repo} ({tag})")

        # Check if release exists; create if missing
        view = subprocess.run(
            ["gh", "release", "view", tag, "--repo", repo],
            cwd=BASE_DIR, text=True, capture_output=True,
        )
        if view.returncode != 0:
            print(f"  Creating release {tag}...")
            run(["gh", "release", "create", tag, "--repo", repo,
                 "--title", f"NUSA {variant} {tag}",
                 "--notes", f"Release {tag} — build {variant}"])
        else:
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
