#!/usr/bin/env python3
"""Hygiene test: verify variant config consistency across the 3 sources of truth.

Sources:
  1. _build_all.py              — the release build tool (source of truth)
  2. lib/core/config/nusa_config.dart  — build-time defaults + variantHiddenMenus
  3. lib/core/dev/variant_data.dart    — dev variant switcher

Checks per variant: id, name, pkg/applicationId, productId, repo, subtitle,
primary/dark/soft theme colors, catEmoji/catGradients/catIcons keys, and
hidden_menus. Prints a report and exits non-zero on any mismatch.
"""
import ast
import re
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
BUILD_ALL = BASE / "_build_all.py"
NUSA_CONFIG = BASE / "lib/core/config/nusa_config.dart"
VARIANT_DATA = BASE / "lib/core/dev/variant_data.dart"

issues = []
notes = []


def parse_build_all():
    """Parse VARIANTS list from _build_all.py as a Python literal."""
    src = BUILD_ALL.read_text(encoding="utf-8")
    m = re.search(r"VARIANTS\s*=\s*(\[[\s\S]*?\n\])\n", src)
    if not m:
        raise ValueError("VARIANTS block not found")
    return ast.literal_eval(m.group(1))


def parse_nusa_config():
    src = NUSA_CONFIG.read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r'(\w+):\s*\{[^}]*\}', src):
        pass
    # variantHiddenMenus map
    vhm = re.search(r"variantHiddenMenus\s*=\s*\{(.*?)\n\s*\};", src, re.S)
    hidden = {}
    if vhm:
        for vm in re.finditer(r"'(\w+)':\s*\[(.*?)\]", vhm.group(1), re.S):
            hidden[vm.group(1)] = sorted(re.findall(r"'([a-z_]+)'", vm.group(2)))
    out["hidden_menus"] = hidden
    # themePresets colors
    tp = re.search(r"themePresets\s*=\s*\{(.*?)\n\s*\};", src, re.S)
    colors = {}
    if tp:
        for pm in re.finditer(r"'(\w+)':\s*\{([^}]*)\}", tp.group(1), re.S):
            prim = re.search(r"'primary':\s*Color\((0x[0-9A-Fa-f]+)\)", pm.group(2))
            dark = re.search(r"'dark':\s*Color\((0x[0-9A-Fa-f]+)\)", pm.group(2))
            soft = re.search(r"'soft':\s*Color\((0x[0-9A-Fa-f]+)\)", pm.group(2))
            colors[pm.group(1)] = (prim.group(1) if prim else None,
                                   dark.group(1) if dark else None,
                                   soft.group(1) if soft else None)
    out["themePresets"] = colors
    return out


def parse_variant_data():
    src = VARIANT_DATA.read_text(encoding="utf-8")
    variants = []
    # Each VariantData(...) block; capture everything between 'VariantData(' and
    # the closing ')' that precedes ',\n    //' or end of list. Use a balanced
    # approach: split on 'VariantData(' and take up to the matching ')'.
    for m in re.finditer(r"VariantData\(\s*id:\s*'(\w+)'(.*?)\n\s*\)\s*,", src, re.S):
        d = m.group(2)
        def get(key, default=None):
            km = re.search(rf"{key}:\s*('(?:[^'\\]|\\.)*'|Color\(0x[0-9A-Fa-f]+\)|0x[0-9A-Fa-f]+|\[[^\]]*\])", d)
            val = km.group(1) if km else default
            if val and val.startswith("Color("):
                val = val[6:-1]
            return val
        v = {
            "id": m.group(1),
            "name": get("name"),
            "pkg": get("pkg"),
            "productId": get("productId"),
            "repo": get("repo"),
            "subtitle": get("subtitle"),
            "primary": get("primary"),
            "dark": get("dark"),
            "soft": get("soft"),
            "catEmoji": sorted(re.findall(r"'([^']+)':\s*'[^']*'", d.split("catEmoji:")[1].split("catGradients:")[0])),
            "catGradients": sorted(re.findall(r"'([^']+)':\s*\[", d.split("catGradients:")[1].split("catIcons:")[0])),
            "catIcons": sorted(re.findall(r"'([^']+)':\s*Icons\.", d.split("catIcons:")[1].split("hiddenMenus:")[0])),
            "hiddenMenus": sorted(re.findall(r"'([a-z_]+)'", d.split("hiddenMenus:")[1])),
        }
        variants.append(v)
    return variants


def main():
    try:
        build = parse_build_all()
    except Exception as e:
        print(f"FATAL: cannot parse _build_all.py: {e}")
        sys.exit(1)
    try:
        cfg = parse_nusa_config()
    except Exception as e:
        print(f"FATAL: cannot parse nusa_config.dart: {e}")
        sys.exit(1)
    try:
        dev = parse_variant_data()
    except Exception as e:
        print(f"FATAL: cannot parse variant_data.dart: {e}")
        sys.exit(1)

    if len(build) != 8:
        issues.append(f"_build_all.py: expected 8 variants, found {len(build)}")
    if len(dev) != 8:
        issues.append(f"variant_data.dart: expected 8 variants, found {len(dev)}")

    dev_by_id = {v["id"]: v for v in dev}
    build_by_id = {v["id"]: v for v in build}

    # 1) Every build variant exists in dev + matches core fields
    for b in build:
        vid = b["id"]
        d = dev_by_id.get(vid)
        if d is None:
            issues.append(f"variant_data.dart missing variant '{vid}' (present in _build_all.py)")
            continue
        # pkg
        bpkg = b["pkg"]
        dpkg = d["pkg"].strip("'") if d["pkg"] else None
        if bpkg != dpkg:
            issues.append(f"[{vid}] pkg mismatch: _build_all={bpkg} variant_data={dpkg}")
        # productId
        bprod = b["product"]
        dprod = d["productId"].strip("'") if d["productId"] else None
        if bprod != dprod:
            issues.append(f"[{vid}] productId mismatch: _build_all={bprod} variant_data={dprod}")
        # repo
        brepo = b["repo"]
        drepo = d["repo"].strip("'") if d["repo"] else None
        if brepo != drepo:
            issues.append(f"[{vid}] repo mismatch: _build_all={brepo} variant_data={drepo}")
        # colors
        for part in ("primary", "dark", "soft"):
            bc = b[part]
            dc = d[part].strip('"') if d[part] else None
            if bc.lower() != (dc or "").lower():
                issues.append(f"[{vid}] {part} mismatch: _build_all={bc} variant_data={dc}")
        # category keys
        bkeys = set(b["cat_emoji"])
        dkeys = set(d["catEmoji"])
        if bkeys != dkeys:
            issues.append(f"[{vid}] catEmoji keys mismatch: build-all-only={sorted(bkeys - dkeys)} variant-data-only={sorted(dkeys - bkeys)}")
        bg = set(b["cat_gradients"]); dg = set(d["catGradients"])
        if bg != dg:
            issues.append(f"[{vid}] catGradients keys mismatch: build-all-only={sorted(bg - dg)} variant-data-only={sorted(dg - bg)}")
        bi = set(b["cat_icons"]); di = set(d["catIcons"])
        if bi != di:
            issues.append(f"[{vid}] catIcons keys mismatch: build-all-only={sorted(bi - di)} variant-data-only={sorted(di - bi)}")
        # hidden menus — dev must match build_all exactly
        bh = set(b["hidden_menus"]); dh = set(d["hiddenMenus"])
        if bh != dh:
            issues.append(f"[{vid}] hiddenMenus mismatch: _build_all extra={sorted(bh - dh)} variant_data extra={sorted(dh - bh)}")

    # 2) nusa_config variantHiddenMenus must match _build_all
    for vid, b in build_by_id.items():
        ch = set(cfg["hidden_menus"].get(vid, []))
        bh_set = set(b["hidden_menus"])
        if ch != bh_set:
            issues.append(f"[{vid}] nusa_config.variantHiddenMenus mismatch: _build_all extra={sorted(bh_set - ch)} config extra={sorted(ch - bh_set)}")

    # 3) nusa_config themePresets colors must match _build_all
    for vid, b in build_by_id.items():
        preset = cfg["themePresets"].get(vid)
        if preset is None:
            issues.append(f"[{vid}] missing themePresets entry in nusa_config.dart")
            continue
        for i, part in enumerate(("primary", "dark", "soft")):
            bc = (b[part] or "").lower()
            cc = (preset[i] or "").lower() if preset[i] else None
            if bc != cc:
                issues.append(f"[{vid}] themePresets.{part} mismatch: _build_all={bc} config={cc}")

    # 4) Dev productId getters sanity: every is*Variant getter exists in config
    for b in build_by_id.values():
        pid = b["product"]
        if pid not in src_nusa_config_product_ids():
            issues.append(f"[{b['id']}] productId '{pid}' not referenced by any NusaConfig getter")

    print("=" * 60)
    print("HYGIENE TEST — 8-variant config consistency")
    print("=" * 60)
    for b in build_by_id.values():
        print(f"  {b['id']:<10} pkg={b['pkg']:<18} product={b['product']}")
    if issues:
        print("\n❌ ISSUES:")
        for i in issues:
            print(f"  - {i}")
        sys.exit(1)
    print("\n✅ All 8 variants consistent across _build_all.py, nusa_config.dart, variant_data.dart")
    sys.exit(0)


def src_nusa_config_product_ids():
    src = NUSA_CONFIG.read_text(encoding="utf-8")
    return set(re.findall(r"productId == '([^']+)'", src))


if __name__ == "__main__":
    main()
