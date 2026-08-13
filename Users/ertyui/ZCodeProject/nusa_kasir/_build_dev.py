#!/usr/bin/env python3
"""
NUSA Developer Build — standalone APK for side-by-side testing.

Builds ONE APK for the DEV application id `com.nusa.dev` with the
`NUSA_DEV=true` dart-define enabled, so the app boots into the
variant picker. It installs alongside all production variants
(no data/activation overlap) and never touches the production
config files (_build_all.py or the real APK outputs).

    python _build_dev.py             # build apk
    python _build_dev.py --install   # build + adb install on the running device

Output: nusa_builds/nusa-dev.apk  (same folder as production APKs)
Release tag scheme (manual, on the dev repo):  v2.2.2-dev.1, v2.2.2-dev.2, ...
"""
import os, re, shutil, subprocess, sys, time

FLUTTER = r"C:\Users\ertyui\flutter\bin\flutter.bat"
BASE_DIR = r"C:\Users\ertyui\ZCodeProject\nusa_kasir"
OUTPUT_DIR = os.path.join(BASE_DIR, "nusa_builds")
APK_SRC = os.path.join(BASE_DIR, "build", "app", "outputs", "flutter-apk", "app-release.apk")
APK_DST = os.path.join(OUTPUT_DIR, "nusa-dev.apk")

# ── Config files swapped by _build_all.py per variant. The dev build must
#    NOT rely on whatever variant is currently checked out — it builds the
#    generic launcher identity (dev applicationId + "NUSA Dev" label) so it
#    is independent of the last production build. ──
GRADLE_FILE = os.path.join(BASE_DIR, "android", "app", "build.gradle.kts")
MANIFEST_FILE = os.path.join(BASE_DIR, "android", "app", "src", "main", "AndroidManifest.xml")
GMS_SRC = os.path.join(BASE_DIR, "android", "app", "google-services.json")


def ensure_launcher_identity():
    """Force dev identity in gradle + manifest, and stash google-services.json."""
    # Build.gradle.kts — patch the false-branch (production) ids to the
    # generic launcher identity; the true-branch is already com.nusa.dev.
    # NOTE: replacement must NOT add a closing quote — the original `"` after
    # the matched value is left in place (same convention as _build_all.py).
    with open(GRADLE_FILE, "r", encoding="utf-8") as f:
        gradle = f.read()
    gradle = re.sub(
        r'(else ")[^"]+',
        r'\g<1>com.nusa.laundry',
        gradle,
    )
    with open(GRADLE_FILE, "w", encoding="utf-8") as f:
        f.write(gradle)

    # AndroidManifest.xml — "NUSA Dev" label for easy identification.
    with open(MANIFEST_FILE, "r", encoding="utf-8") as f:
        manifest = f.read()
    manifest = re.sub(r'(android:label=")[^"]+', r'\g<1>NUSA Dev', manifest)
    with open(MANIFEST_FILE, "w", encoding="utf-8") as f:
        f.write(manifest)

    # google-services.json — stash (dev build skips the plugin entirely, but
    # the variant build's leftover file must not confuse anything).
    if os.path.exists(GMS_SRC):
        shutil.move(GMS_SRC, GMS_SRC + ".devbak")


def restore_launcher_identity():
    if os.path.exists(GMS_SRC + ".devbak"):
        shutil.move(GMS_SRC + ".devbak", GMS_SRC)


def main():
    do_install = "--install" in sys.argv
    ensure_launcher_identity()
    try:
        os.makedirs(OUTPUT_DIR, exist_ok=True)
        try:
            os.remove(APK_SRC)
        except FileNotFoundError:
            pass

        print("  → Flutter clean...")
        r = subprocess.run([FLUTTER, "clean"], cwd=BASE_DIR, capture_output=True, text=True)
        if r.returncode != 0:
            print(f"  ❌ clean failed:\n{r.stderr[-500:]}")
            return 1
        print("  → Flutter pub get...")
        r = subprocess.run([FLUTTER, "pub", "get"], cwd=BASE_DIR, capture_output=True, text=True)
        if r.returncode != 0:
            print(f"  ❌ pub get failed:\n{r.stderr[-500:]}")
            return 1
        print("  → Building dev release APK (NUSA_DEV=true, com.nusa.dev)...")
        started = time.time()
        r = subprocess.run(
            [FLUTTER, "build", "apk", "--release", "--dart-define=NUSA_DEV=true"],
            cwd=BASE_DIR,
            capture_output=True, text=True, timeout=2400,
        )
        if r.returncode != 0:
            print(f"  ❌ Build failed:\n{r.stderr[-1000:]}")
            return 1
        if not os.path.isfile(APK_SRC) or os.path.getsize(APK_SRC) == 0 or os.path.getmtime(APK_SRC) < started:
            print(f"  ❌ Missing or stale APK output: {APK_SRC}")
            return 1
        shutil.copy2(APK_SRC, APK_DST)
        print(f"  ✓ APK saved: {APK_DST} ({os.path.getsize(APK_DST) / (1024 * 1024):.1f} MB)")

        if do_install:
            print("  → Installing on device...")
            r = subprocess.run(["adb", "install", "-r", APK_DST], capture_output=True, text=True)
            if r.returncode != 0:
                print(f"  ❌ Install failed:\n{r.stderr[-500:]}")
                return 1
            print("  ✓ Installed com.nusa.dev")
        return 0
    finally:
        restore_launcher_identity()


if __name__ == "__main__":
    raise SystemExit(main())
