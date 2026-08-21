#!/usr/bin/env python3
"""Fast sequential multi-variant builder (NO flutter clean between variants).

Reuses config-swap + validation from _build_all.py but skips `flutter clean`
so the Gradle daemon & Flutter cache stay warm — each variant rebuild takes
minutes instead of 40. The identity-bearing files (config/gradle/manifest/
icons) still get swapped per variant; Flutter sees the change and rebuilds.

Usage: python _build_all_fast.py [variant1 variant2 ...]   (default: all 8)
"""
import os, sys, shutil, subprocess, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _build_all as ba  # noqa: E402  (reuse update_config/validate_variant/VARIANTS)

FLUTTER = r"C:\Users\ertyui\flutter\bin\flutter.bat"
BASE_DIR = r"C:\Users\ertyui\ZCodeProject\nusa_kasir"
OUTPUT_DIR = os.path.join(BASE_DIR, "nusa_builds")
APK_SRC = os.path.join(BASE_DIR, "build", "app", "outputs", "flutter-apk",
                       "app-release.apk")


def build_variant(variant: dict) -> bool:
    vid = variant["id"]
    print(f"  → flutter build apk --release ({vid}) ...")
    started = time.time()
    try:
        r = subprocess.run(
            [FLUTTER, "build", "apk", "--release"],
            cwd=BASE_DIR, capture_output=True, text=True,
            timeout=3600,  # warm cache: plenty; first one may need more
        )
    except subprocess.TimeoutExpired:
        print("  ❌ build timed out")
        return False
    elapsed = time.time() - started
    if r.returncode != 0:
        print(f"  ❌ Build failed ({elapsed:.0f}s):\n{r.stderr[-1200:]}")
        return False
    if not os.path.isfile(APK_SRC) or os.path.getsize(APK_SRC) == 0 or os.path.getmtime(APK_SRC) < started:
        print(f"  ❌ Missing/stale APK output ({elapsed:.0f}s)")
        return False
    apk_dst = os.path.join(OUTPUT_DIR, f"nusa-{vid}.apk")
    shutil.copy2(APK_SRC, apk_dst)
    print(f"  ✓ {vid}: {os.path.getsize(apk_dst) / (1024*1024):.1f} MB in {elapsed:.0f}s")
    return True


def main():
    requested = set(sys.argv[1:])
    variants = [v for v in ba.VARIANTS if not requested or v["id"] in requested]
    unknown = requested - {v["id"] for v in ba.VARIANTS}
    if unknown:
        print(f"Unknown variant(s): {', '.join(sorted(unknown))}", file=sys.stderr)
        return 2

    backups = [(ba.CONFIG_FILE, ba.CONFIG_FILE + ".orig"),
               (ba.GRADLE_FILE, ba.GRADLE_FILE + ".orig"),
               (ba.MANIFEST_FILE, ba.MANIFEST_FILE + ".orig")]
    orig_gms = os.path.join(ba.GMS_DIR, "google-services.json")
    if os.path.exists(orig_gms):
        backups.append((orig_gms, orig_gms + ".orig"))

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    success, failed = [], []
    try:
        for source, backup in backups:
            shutil.copy2(source, backup)
        for i, variant in enumerate(variants, 1):
            vid = variant["id"]
            print(f"\n{'='*50}\n  [{i}/{len(variants)}] {variant['name']} ({vid})\n{'='*50}")
            # Remove stale canonical APK for this variant before building.
            apk_dst = os.path.join(OUTPUT_DIR, f"nusa-{vid}.apk")
            for filename in os.listdir(OUTPUT_DIR):
                if filename == f"nusa-{vid}.apk" or (
                    filename.startswith(f"nusa-{vid}-") and filename.endswith(".apk")
                ):
                    try:
                        os.remove(os.path.join(OUTPUT_DIR, filename))
                    except FileNotFoundError:
                        pass
            if not ba.update_config(variant):
                failed.append(vid)
                continue
            if not ba.validate_variant(variant):
                failed.append(vid)
                continue
            if not build_variant(variant):
                failed.append(vid)
                continue
            success.append(vid)
    finally:
        print("\n  Restoring original config...")
        for source, backup in backups:
            if os.path.exists(backup):
                shutil.copy2(backup, source)
                os.remove(backup)

    print(f"\nBUILD SUMMARY: {len(success)} succeeded, {len(failed)} failed")
    if failed:
        print("Failed: " + ", ".join(failed))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
