#!/usr/bin/env python3
"""
NUSA Multi-Variant APK Builder
Builds all 8 variants sequentially by swapping config files per variant.
"""
import os, sys, shutil, subprocess, re

FLUTTER = r"C:\Users\ertyui\flutter\bin\flutter.bat"
BASE_DIR = r"C:\Users\ertyui\ZCodeProject\nusa_kasir"
OUTPUT_DIR = os.path.join(BASE_DIR, "nusa_builds")
CONFIG_FILE = os.path.join(BASE_DIR, "lib", "core", "config", "nusa_config.dart")
GRADLE_FILE = os.path.join(BASE_DIR, "android", "app", "build.gradle.kts")
MANIFEST_FILE = os.path.join(BASE_DIR, "android", "app", "src", "main", "AndroidManifest.xml")
GMS_DIR = os.path.join(BASE_DIR, "android", "app")

os.makedirs(OUTPUT_DIR, exist_ok=True)

# ── Variant definitions ──
VARIANTS = [
    {
        "id": "kelontong", "name": "NUSA Kelontong", "pkg": "com.nusa.kelontong",
        "product": "nusa-kelontong", "subtitle": "Aplikasi Kasir untuk Toko Kelontong",
        "primary": "0xFFF97316", "dark": "0xFFEA580C", "soft": "0xFFFFF7ED",
        "repo": "halugoods/nusa-kelontong",
        "cat_emoji": {
            "Sembako": "🍚", "Makanan": "🍜", "Minuman": "🥤",
            "Perlengkapan": "🧹", "Lainnya": "📦",
        },
        "cat_gradients": {
            "Sembako": ["Color(0xFFFFEDD5)", "Color(0xFFFED7AA)", "Color(0xFFFFF7ED)"],
            "Makanan": ["Color(0xFFFEF3C7)", "Color(0xFFFDE68A)", "Color(0xFFFEF9C3)"],
            "Minuman": ["Color(0xFFDBEAFE)", "Color(0xFFBFDBFE)", "Color(0xFFEFF6FF)"],
            "Perlengkapan": ["Color(0xFFDCFCE7)", "Color(0xFFBBF7D0)", "Color(0xFFF0FDF4)"],
            "Lainnya": ["Color(0xFFF3E8FF)", "Color(0xFFE9D5FF)", "Color(0xFFFAF5FF)"],
        },
        "cat_icons": {
            "Semua": "Icons.grid_view_rounded",
            "Sembako": "Icons.rice_bowl_rounded",
            "Makanan": "Icons.restaurant_rounded",
            "Minuman": "Icons.local_drink_rounded",
            "Perlengkapan": "Icons.cleaning_services_rounded",
            "Lainnya": "Icons.category_rounded",
        },
        "hidden_menus": ["meja", "laundry_status", "servis", "booking", "resep", "print_order"],
    },
    {
        "id": "fnb", "name": "NUSA F&B", "pkg": "com.nusa.fnb",
        "product": "nusa-fnb", "subtitle": "Aplikasi Kasir untuk Rumah Makan & Kafe",
        "primary": "0xFFE63946", "dark": "0xFFC1121F", "soft": "0xFFFDE8EA",
        "repo": "halugoods/nusa-fnb",
        "cat_emoji": {
            "Makanan": "🍜", "Minuman": "🥤", "Snack": "🍿",
            "Menu Utama": "🍽️", "Lainnya": "📦",
        },
        "cat_gradients": {
            "Makanan": ["Color(0xFFFEE2E2)", "Color(0xFFFECACA)", "Color(0xFFFEF2F2)"],
            "Minuman": ["Color(0xFFDBEAFE)", "Color(0xFFBFDBFE)", "Color(0xFFEFF6FF)"],
            "Snack": ["Color(0xFFFEF3C7)", "Color(0xFFFDE68A)", "Color(0xFFFEF9C3)"],
            "Menu Utama": ["Color(0xFFDCFCE7)", "Color(0xFFBBF7D0)", "Color(0xFFF0FDF4)"],
            "Lainnya": ["Color(0xFFF3E8FF)", "Color(0xFFE9D5FF)", "Color(0xFFFAF5FF)"],
        },
        "cat_icons": {
            "Semua": "Icons.grid_view_rounded",
            "Makanan": "Icons.restaurant_rounded",
            "Minuman": "Icons.local_drink_rounded",
            "Snack": "Icons.bakery_dining_rounded",
            "Menu Utama": "Icons.dinner_dining_rounded",
            "Lainnya": "Icons.category_rounded",
        },
        "hidden_menus": ["supplier", "piutang", "spreadsheet",
                         "laundry_status", "servis", "booking", "resep", "print_order"],
    },
    {
        "id": "laundry", "name": "NUSA Laundry", "pkg": "com.nusa.laundry",
        "product": "nusa-laundry", "subtitle": "Aplikasi Kasir untuk Usaha Laundry",
        "primary": "0xFF3B82F6", "dark": "0xFF2563EB", "soft": "0xFFEFF6FF",
        "repo": "halugoods/nusa-laundry",
        "cat_emoji": {
            "Cuci Kering": "👕", "Cuci Setrika": "✨", "Setrika Only": "🔥",
            "Express": "⚡", "Lainnya": "📦",
        },
        "cat_gradients": {
            "Cuci Kering": ["Color(0xFFDBEAFE)", "Color(0xFFBFDBFE)", "Color(0xFFEFF6FF)"],
            "Cuci Setrika": ["Color(0xFFFEF3C7)", "Color(0xFFFDE68A)", "Color(0xFFFEF9C3)"],
            "Setrika Only": ["Color(0xFFFEE2E2)", "Color(0xFFFECACA)", "Color(0xFFFEF2F2)"],
            "Express": ["Color(0xFFDCFCE7)", "Color(0xFFBBF7D0)", "Color(0xFFF0FDF4)"],
            "Lainnya": ["Color(0xFFF3E8FF)", "Color(0xFFE9D5FF)", "Color(0xFFFAF5FF)"],
        },
        "cat_icons": {
            "Semua": "Icons.grid_view_rounded",
            "Cuci Kering": "Icons.local_laundry_service_rounded",
            "Cuci Setrika": "Icons.auto_awesome_rounded",
            "Setrika Only": "Icons.whatshot_rounded",
            "Express": "Icons.bolt_rounded",
            "Lainnya": "Icons.category_rounded",
        },
        "hidden_menus": ["supplier", "piutang", "promo", "pesanan_online",
                         "meja", "servis", "booking", "resep", "print_order"],
    },
    {
        "id": "bengkel", "name": "NUSA Bengkel", "pkg": "com.nusa.bengkel",
        "product": "nusa-bengkel", "subtitle": "Aplikasi Kasir untuk Bengkel & Otomotif",
        "primary": "0xFF374151", "dark": "0xFF1F2937", "soft": "0xFFF3F4F6",
        "repo": "halugoods/nusa-bengkel",
        "cat_emoji": {
            "Oli": "🛢️", "Ban": "🛞", "Servis": "🔧",
            "Sparepart": "⚙️", "Lainnya": "📦",
        },
        "cat_gradients": {
            "Oli": ["Color(0xFFF3F4F6)", "Color(0xFFE5E7EB)", "Color(0xFFF9FAFB)"],
            "Ban": ["Color(0xFFDBEAFE)", "Color(0xFFBFDBFE)", "Color(0xFFEFF6FF)"],
            "Servis": ["Color(0xFFFEF3C7)", "Color(0xFFFDE68A)", "Color(0xFFFEF9C3)"],
            "Sparepart": ["Color(0xFFDCFCE7)", "Color(0xFFBBF7D0)", "Color(0xFFF0FDF4)"],
            "Lainnya": ["Color(0xFFF3E8FF)", "Color(0xFFE9D5FF)", "Color(0xFFFAF5FF)"],
        },
        "cat_icons": {
            "Semua": "Icons.grid_view_rounded",
            "Oli": "Icons.oil_barrel_rounded",
            "Ban": "Icons.tire_repair_rounded",
            "Servis": "Icons.build_rounded",
            "Sparepart": "Icons.settings_rounded",
            "Lainnya": "Icons.category_rounded",
        },
        "hidden_menus": ["pesanan_online",
                         "meja", "laundry_status", "booking", "resep", "print_order"],
    },
    {
        "id": "salon", "name": "NUSA Salon", "pkg": "com.nusa.salon",
        "product": "nusa-salon", "subtitle": "Aplikasi Kasir untuk Salon & Barbershop",
        "primary": "0xFF78716C", "dark": "0xFF57534E", "soft": "0xFFFAFAF9",
        "repo": "halugoods/nusa-salon",
        "cat_emoji": {
            "Haircut": "✂️", "Coloring": "🎨", "Treatment": "💆",
            "Styling": "💇", "Lainnya": "📦",
        },
        "cat_gradients": {
            "Haircut": ["Color(0xFFFAFAF9)", "Color(0xFFE7E5E4)", "Color(0xFFF5F5F4)"],
            "Coloring": ["Color(0xFFFEF3C7)", "Color(0xFFFDE68A)", "Color(0xFFFEF9C3)"],
            "Treatment": ["Color(0xFFDCFCE7)", "Color(0xFFBBF7D0)", "Color(0xFFF0FDF4)"],
            "Styling": ["Color(0xFFDBEAFE)", "Color(0xFFBFDBFE)", "Color(0xFFEFF6FF)"],
            "Lainnya": ["Color(0xFFF3E8FF)", "Color(0xFFE9D5FF)", "Color(0xFFFAF5FF)"],
        },
        "cat_icons": {
            "Semua": "Icons.grid_view_rounded",
            "Haircut": "Icons.content_cut_rounded",
            "Coloring": "Icons.palette_rounded",
            "Treatment": "Icons.spa_rounded",
            "Styling": "Icons.face_rounded",
            "Lainnya": "Icons.category_rounded",
        },
        "hidden_menus": ["supplier", "cabang", "piutang", "pesanan_online",
                         "meja", "laundry_status", "servis", "resep", "print_order"],
    },
    {
        "id": "apotek", "name": "NUSA Apotek", "pkg": "com.nusa.apotek",
        "product": "nusa-apotek", "subtitle": "Aplikasi Kasir untuk Apotek & Farmasi",
        "primary": "0xFF10B981", "dark": "0xFF059669", "soft": "0xFFECFDF5",
        "repo": "halugoods/nusa-apotek",
        "cat_emoji": {
            "Obat Bebas": "💊", "Obat Resep": "📋", "Vitamin": "💪",
            "Alkes": "🩺", "Lainnya": "📦",
        },
        "cat_gradients": {
            "Obat Bebas": ["Color(0xFFDCFCE7)", "Color(0xFFBBF7D0)", "Color(0xFFF0FDF4)"],
            "Obat Resep": ["Color(0xFFDBEAFE)", "Color(0xFFBFDBFE)", "Color(0xFFEFF6FF)"],
            "Vitamin": ["Color(0xFFFEF3C7)", "Color(0xFFFDE68A)", "Color(0xFFFEF9C3)"],
            "Alkes": ["Color(0xFFFEE2E2)", "Color(0xFFFECACA)", "Color(0xFFFEF2F2)"],
            "Lainnya": ["Color(0xFFF3E8FF)", "Color(0xFFE9D5FF)", "Color(0xFFFAF5FF)"],
        },
        "cat_icons": {
            "Semua": "Icons.grid_view_rounded",
            "Obat Bebas": "Icons.medication_rounded",
            "Obat Resep": "Icons.description_rounded",
            "Vitamin": "Icons.fitness_center_rounded",
            "Alkes": "Icons.monitor_heart_rounded",
            "Lainnya": "Icons.category_rounded",
        },
        "hidden_menus": ["promo", "piutang",
                         "meja", "laundry_status", "servis", "booking", "print_order"],
    },
    {
        "id": "fotocopy", "name": "NUSA Fotocopy", "pkg": "com.nusa.fotocopy",
        "product": "nusa-fotocopy", "subtitle": "Aplikasi Kasir untuk Fotocopy & Percetakan",
        "primary": "0xFF8B5CF6", "dark": "0xFF7C3AED", "soft": "0xFFF5F3FF",
        "repo": "halugoods/nusa-fotocopy",
        "cat_emoji": {
            "Print": "🖨️", "Fotocopy": "📄", "Jilid": "📚",
            "ATK": "✏️", "Lainnya": "📦",
        },
        "cat_gradients": {
            "Print": ["Color(0xFFF3E8FF)", "Color(0xFFE9D5FF)", "Color(0xFFFAF5FF)"],
            "Fotocopy": ["Color(0xFFDBEAFE)", "Color(0xFFBFDBFE)", "Color(0xFFEFF6FF)"],
            "Jilid": ["Color(0xFFFEF3C7)", "Color(0xFFFDE68A)", "Color(0xFFFEF9C3)"],
            "ATK": ["Color(0xFFDCFCE7)", "Color(0xFFBBF7D0)", "Color(0xFFF0FDF4)"],
            "Lainnya": ["Color(0xFFFEE2E2)", "Color(0xFFFECACA)", "Color(0xFFFEF2F2)"],
        },
        "cat_icons": {
            "Semua": "Icons.grid_view_rounded",
            "Print": "Icons.print_rounded",
            "Fotocopy": "Icons.copy_all_rounded",
            "Jilid": "Icons.book_rounded",
            "ATK": "Icons.edit_rounded",
            "Lainnya": "Icons.category_rounded",
        },
        "hidden_menus": ["cabang", "piutang", "pesanan_online",
                         "meja", "laundry_status", "servis", "booking", "resep"],
    },
    {
        "id": "servicehp", "name": "NUSA Service HP", "pkg": "com.nusa.servicehp",
        "product": "nusa-servicehp", "subtitle": "Aplikasi Kasir untuk Servis Handphone",
        "primary": "0xFF06B6D4", "dark": "0xFF0891B2", "soft": "0xFFECFEFF",
        "repo": "halugoods/nusa-servicehp",
        "cat_emoji": {
            "LCD": "📱", "Baterai": "🔋", "Software": "⚡",
            "Aksesoris": "🎧", "Lainnya": "📦",
        },
        "cat_gradients": {
            "LCD": ["Color(0xFFECFEFF)", "Color(0xFFCFFAFE)", "Color(0xFFF0FDFA)"],
            "Baterai": ["Color(0xFFFEF3C7)", "Color(0xFFFDE68A)", "Color(0xFFFEF9C3)"],
            "Software": ["Color(0xFFDBEAFE)", "Color(0xFFBFDBFE)", "Color(0xFFEFF6FF)"],
            "Aksesoris": ["Color(0xFFF3E8FF)", "Color(0xFFE9D5FF)", "Color(0xFFFAF5FF)"],
            "Lainnya": ["Color(0xFFFEE2E2)", "Color(0xFFFECACA)", "Color(0xFFFEF2F2)"],
        },
        "cat_icons": {
            "Semua": "Icons.grid_view_rounded",
            "LCD": "Icons.phone_android_rounded",
            "Baterai": "Icons.battery_charging_full_rounded",
            "Software": "Icons.terminal_rounded",
            "Aksesoris": "Icons.headphones_rounded",
            "Lainnya": "Icons.category_rounded",
        },
        "hidden_menus": ["promo", "cabang", "pesanan_online",
                         "meja", "laundry_status", "booking", "resep", "print_order"],
    },
]


CAT_MAP_TYPES = {
    "catEmoji": "Map<String, String>",
    "catGradients": "Map<String, List<Color>>",
    "catIcons": "Map<String, IconData>",
}


def find_map_lines(lines: list, marker: str) -> tuple:
    """Return (decl_line, open_brace_line, close_brace_line) for a Dart const map."""
    for i, line in enumerate(lines):
        stripped = line.strip()
        if marker in stripped and "static const" in stripped and "=" in stripped:
            decl_line = i
            # If '{' is on the declaration line, open_brace is same line
            if "{" in stripped:
                open_line = i
            else:
                open_line = i + 1
            # Count nested braces from open_line
            depth = 0
            started = False
            for j in range(open_line, len(lines)):
                for ch in lines[j]:
                    if ch == "{":
                        depth += 1
                        started = True
                    elif ch == "}":
                        depth -= 1
                if started and depth == 0:
                    return (decl_line, open_line, j)
    return None


def replace_map_section(lines: list, marker: str, entry_lines: list) -> list:
    """Replace map entries between { and }, keeping the declaration type."""
    info = find_map_lines(lines, marker)
    if info is None:
        raise ValueError(f"Could not find map section for: {marker}")
    decl_line, open_line, close_line = info

    # Detect original indentation from declaration line
    orig_decl = lines[decl_line]
    base_indent = orig_decl[:len(orig_decl) - len(orig_decl.lstrip())]
    entry_indent = base_indent + "  "

    map_type = CAT_MAP_TYPES.get(marker, "Map<String, dynamic>")
    decl = f"{base_indent}static const {map_type} {marker} = {{"

    # Apply entry_indent to each entry line
    indented_entries = []
    for ln in entry_lines:
        indented_entries.append(f"{entry_indent}{ln.strip()}")

    closing = f"{base_indent}}};"
    result = [decl] + indented_entries + [closing]
    return lines[:decl_line] + result + lines[close_line + 1:]


def format_emoji_entries(emoji_dict: dict) -> list:
    """Format catEmoji key-value entries (indentation applied by caller)."""
    return [f"'{k}': '{v}'," for k, v in emoji_dict.items()]


def format_gradient_entries(grad_dict: dict) -> list:
    """Format catGradients key-value entries (indentation applied by caller)."""
    result = []
    for k, colors in grad_dict.items():
        color_str = ", ".join(colors)
        result.append(f"'{k}': [{color_str}],")
    return result


def format_icons_entries(icons_dict: dict) -> list:
    """Format catIcons key-value entries (indentation applied by caller)."""
    return [f"'{k}': {v}," for k, v in icons_dict.items()]


def _escape_xml(s: str) -> str:
    """Escape XML special characters (&, <, >, \", ') for safe manifest usage."""
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;") \
            .replace('"', "&quot;").replace("'", "&apos;")


def update_config(variant: dict):
    """Update all 3 config files for the given variant."""
    v = variant

    # ── 1. Update google-services.json ──
    src = os.path.join(GMS_DIR, f"google-services-{v['id']}.json")
    dst = os.path.join(GMS_DIR, "google-services.json")
    if not os.path.exists(src):
        print(f"  ❌ google-services JSON not found: {src}")
        return False
    shutil.copy2(src, dst)
    print(f"  ✓ google-services.json → {v['id']}")

    # ── 2. Update nusa_config.dart ──
    with open(CONFIG_FILE, "r", encoding="utf-8") as f:
        config = f.read()

    # Single-line replacements
    config = re.sub(r'(productId\s*=\s*")[^"]+', rf'\g<1>{v["product"]}', config)
    config = re.sub(r'(appSubtitle\s*=\s*")[^"]+', rf'\g<1>{v["subtitle"]}', config)
    config = re.sub(r'(githubRepo\s*=\s*")[^"]+', rf'\g<1>{v["repo"]}', config)
    config = re.sub(r'(applicationId\s*=\s*")[^"]+', rf'\g<1>{v["pkg"]}', config)
    config = re.sub(r'(primaryColor\s*=\s*Color\()[^)]+', rf'\g<1>{v["primary"]}', config)
    config = re.sub(r'(primaryDark\s*=\s*Color\()[^)]+', rf'\g<1>{v["dark"]}', config)
    config = re.sub(r'(primarySoft\s*=\s*Color\()[^)]+', rf'\g<1>{v["soft"]}', config)
    hm = v["hidden_menus"]
    hm_str = "[" + ", ".join("'" + m + "'" for m in hm) + "]"
    config = re.sub(r'(hiddenMenus\s*=\s*)\[.*?\]', r'\g<1>' + hm_str, config)

    # Category maps: use line-based replacement (regex can't handle nested braces + emoji)
    lines = config.split("\n")
    lines = replace_map_section(lines, "catEmoji", format_emoji_entries(v["cat_emoji"]))
    lines = replace_map_section(lines, "catGradients", format_gradient_entries(v["cat_gradients"]))
    lines = replace_map_section(lines, "catIcons", format_icons_entries(v["cat_icons"]))
    config = "\n".join(lines)

    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        f.write(config)
    print(f"  ✓ nusa_config.dart updated")

    # ── 3. Update build.gradle.kts ──
    with open(GRADLE_FILE, "r", encoding="utf-8") as f:
        gradle = f.read()

    gradle = re.sub(r'(namespace\s*=\s*")[^"]+', rf'\g<1>{v["pkg"]}', gradle)
    gradle = re.sub(r'(applicationId\s*=\s*")[^"]+', rf'\g<1>{v["pkg"]}', gradle)

    with open(GRADLE_FILE, "w", encoding="utf-8") as f:
        f.write(gradle)
    print(f"  ✓ build.gradle.kts updated")

    # ── 4. Update AndroidManifest.xml ──
    with open(MANIFEST_FILE, "r", encoding="utf-8") as f:
        manifest = f.read()

    manifest = re.sub(r'(android:label=")[^"]+', rf'\g<1>{_escape_xml(v["name"])}', manifest)

    with open(MANIFEST_FILE, "w", encoding="utf-8") as f:
        f.write(manifest)
    print(f"  ✓ AndroidManifest.xml updated")

    return True


def build_apk(variant_id: str):
    """Run flutter build apk --release."""
    print(f"  → Flutter clean...")
    subprocess.run([FLUTTER, "clean"], cwd=BASE_DIR, capture_output=True)

    print(f"  → Flutter pub get...")
    r = subprocess.run([FLUTTER, "pub", "get"], cwd=BASE_DIR, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"  ❌ pub get failed:\n{r.stderr[-500:]}")
        return False

    print(f"  → Building release APK (5-40 min for first variant, faster after)...")
    r = subprocess.run(
        [FLUTTER, "build", "apk", "--release"],
        cwd=BASE_DIR, capture_output=True, text=True, timeout=2400
    )
    if r.returncode != 0:
        print(f"  ❌ Build failed:\n{r.stderr[-1000:]}")
        return False

    # Show last few lines of output
    for line in r.stdout.strip().split("\n")[-3:]:
        print(f"    {line}")
    if r.stderr.strip():
        for line in r.stderr.strip().split("\n")[-5:]:
            if line.strip():
                print(f"    {line}")

    return True


def main():
    # Backup original state
    shutil.copy2(CONFIG_FILE, CONFIG_FILE + ".orig")
    shutil.copy2(GRADLE_FILE, GRADLE_FILE + ".orig")
    shutil.copy2(MANIFEST_FILE, MANIFEST_FILE + ".orig")
    orig_gms = os.path.join(GMS_DIR, "google-services.json")
    if os.path.exists(orig_gms):
        shutil.copy2(orig_gms, orig_gms + ".orig")

    print("=" * 50)
    print("  NUSA Multi-Variant Builder")
    print(f"  Building {len(VARIANTS)} variants")
    print("=" * 50)

    success = []
    failed = []

    for i, variant in enumerate(VARIANTS, 1):
        vid = variant["id"]
        vname = variant["name"]
        print(f"\n{'='*50}")
        print(f"  [{i}/{len(VARIANTS)}] {vname} ({vid})")
        print(f"  Package: {variant['pkg']}")
        print(f"{'='*50}")

        # Update configs
        if not update_config(variant):
            failed.append(vid)
            continue

        # Build APK
        if not build_apk(vid):
            failed.append(vid)
            continue

        # Copy APK
        apk_src = os.path.join(BASE_DIR, "build", "app", "outputs", "flutter-apk", "app-release.apk")
        apk_dst = os.path.join(OUTPUT_DIR, f"nusa-{vid}-v1.0.0.apk")
        if os.path.exists(apk_src):
            shutil.copy2(apk_src, apk_dst)
            size_mb = os.path.getsize(apk_dst) / (1024 * 1024)
            print(f"  ✅ APK saved: {apk_dst} ({size_mb:.1f} MB)")
            success.append(vid)
        else:
            print(f"  ❌ APK not found at {apk_src}")
            failed.append(vid)

    # ── Restore original state ──
    print(f"\n{'='*50}")
    print("  Restoring original config...")
    for f in [CONFIG_FILE, GRADLE_FILE, MANIFEST_FILE]:
        orig = f + ".orig"
        if os.path.exists(orig):
            shutil.copy2(orig, f)
            os.remove(orig)
    orig_gms_bak = orig_gms + ".orig"
    if os.path.exists(orig_gms_bak):
        shutil.copy2(orig_gms_bak, orig_gms)
        os.remove(orig_gms_bak)

    # ── Summary ──
    print(f"\n{'='*50}")
    print(f"  BUILD SUMMARY")
    print(f"{'='*50}")
    print(f"  ✅ Success: {len(success)} — {', '.join(success)}")
    if failed:
        print(f"  ❌ Failed:  {len(failed)} — {', '.join(failed)}")
    print(f"\n  APK output: {OUTPUT_DIR}")
    apks = sorted([f for f in os.listdir(OUTPUT_DIR) if f.endswith(".apk")])
    for a in apks:
        sz = os.path.getsize(os.path.join(OUTPUT_DIR, a)) / (1024 * 1024)
        print(f"    {a} ({sz:.1f} MB)")
    print()


if __name__ == "__main__":
    main()
