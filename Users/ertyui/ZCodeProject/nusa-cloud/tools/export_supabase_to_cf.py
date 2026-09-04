#!/usr/bin/env python3
"""
export_supabase_to_cf.py — Milestone E: dump Supabase (PostgREST) → seed D1.

Butuh: SUPABASE_URL + SUPABASE_ANON (service-role lebih aman bila ada),
CLOUDFLARE_D1_URL (REST API d1) atau file seed SQL output.

Mode:
  1) --dump        : fetch semua tabel dari Supabase → ./seed/*.json
  2) --sql         : ubah seed JSON → ./seed/nusa_d1_seed.sql (INSERT statements)
  3) --push        : (opsional, butuh wrangler) wrangler d1 execute nusa-db --remote --file=...

Tabel (urutan menghormati FK):
  licenses, activations, payments, license_events, app_min_versions,
  store_settings, online_products, online_orders, promos, online_customers,
  branches, print_form_configs, tutorials, ai_settings, ai_chat_history,
  sheets_settings, sheets_accounts, sheets_registry, sheets_archive

Catatan:
  - PostgREST anon hanya bisa baca tabel yang RLS-nya terbuka. Tabel privat
    (licenses/payments/dll) butuh service_role key: SUPABASE_SERVICE_KEY env.
  - Booleans Postgres → 0/1 SQLite; timestamps ISO → TEXT (sudah ISO).
  - NULL tetap NULL. JSONB → JSON text.
"""
import argparse
import json
import os
import sys
from pathlib import Path

import urllib.request
import urllib.parse

# ── Config dari env ─────────────────────────────────────────────────────
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://sakeuhcbcnueplzlkltm.supabase.co")
SUPABASE_KEY = os.environ.get(
    "SUPABASE_SERVICE_KEY",
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNha2V1aGNiY251ZXBsemxrbHRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2ODIzMDEsImV4cCI6MjA5OTI1ODMwMX0.WvjZJ8Sd3o5T8a4vMApyvoCoS01Qv493mo1PxyWO06M",
)

TABLES = [
    "licenses",
    "activations",
    "payments",
    "license_events",
    "app_min_versions",
    "store_settings",
    "online_products",
    "online_orders",
    "promos",
    "online_customers",
    "branches",
    "print_form_configs",
    "tutorials",
    "ai_settings",
    "ai_chat_history",
    "sheets_settings",
    "sheets_accounts",
    "sheets_registry",
    "sheets_archive",
]

OUT_DIR = Path(__file__).parent / "seed"


def rest_get(table: str) -> list:
    """Fetch semua baris dari PostgREST (maks 50k per tabel, paginated 1k)."""
    rows: list = []
    offset = 0
    while True:
        params = urllib.parse.urlencode(
            {"select": "*", "limit": 1000, "offset": offset}
        )
        url = f"{SUPABASE_URL}/rest/v1/{table}?{params}"
        req = urllib.request.Request(url, headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Range-Unit": "items",
        })
        with urllib.request.urlopen(req, timeout=60) as resp:
            batch = json.loads(resp.read().decode())
        rows.extend(batch)
        if len(batch) < 1000:
            break
        offset += 1000
    return rows


def pg_value(v):
    """Konversi nilai Postgres → SQL literal SQLite."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, (dict, list)):
        s = json.dumps(v, ensure_ascii=False).replace("'", "''")
        return f"'{s}'"
    if isinstance(v, str) and (v.startswith("{") or v.startswith("[")):
        # array/jsonb text
        try:
            parsed = json.loads(v)
            if isinstance(parsed, (list, dict)):
                s = json.dumps(parsed, ensure_ascii=False).replace("'", "''")
                return f"'{s}'"
        except Exception:
            pass
    s = str(v).replace("'", "''")
    return f"'{s}'"


def row_to_insert(table: str, row: dict) -> str:
    cols = list(row.keys())
    col_names = ", ".join(cols)
    vals = ", ".join(pg_value(row[c]) for c in cols)
    # upsert-ish: INSERT OR REPLACE (deterministik untuk re-run)
    return f"INSERT OR REPLACE INTO {table} ({col_names}) VALUES ({vals});"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", action="store_true", help="fetch Supabase → seed/*.json")
    ap.add_argument("--sql", action="store_true", help="seed/*.json → nusa_d1_seed.sql")
    ap.add_argument("--tables", type=str, default="", help="comma list override")
    args = ap.parse_args()

    tables = [t for t in args.tables.split(",") if t] or TABLES
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    if args.dump:
        total = 0
        for t in tables:
            try:
                rows = rest_get(t)
                (OUT_DIR / f"{t}.json").write_text(
                    json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8"
                )
                print(f"  ✓ {t}: {len(rows)} baris")
                total += len(rows)
            except Exception as e:
                print(f"  ✗ {t}: {e}")
        print(f"Total: {total} baris → {OUT_DIR}")
        return 0

    if args.sql:
        out = OUT_DIR / "nusa_d1_seed.sql"
        with out.open("w", encoding="utf-8", newline="\n") as f:
            f.write("-- Generated by export_supabase_to_cf.py — jangan edit manual\n")
            f.write("PRAGMA foreign_keys = OFF;\nBEGIN TRANSACTION;\n")
            for t in tables:
                p = OUT_DIR / f"{t}.json"
                if not p.exists():
                    print(f"  (skip {t} — {p.name} tidak ada)")
                    continue
                rows = json.loads(p.read_text(encoding="utf-8"))
                n = 0
                for row in rows:
                    try:
                        f.write(row_to_insert(t, row) + "\n")
                        n += 1
                    except Exception as e:
                        print(f"  ✗ {t} row: {e}")
                print(f"  ✓ {t}: {n} INSERT")
            f.write("COMMIT;\nPRAGMA foreign_keys = ON;\n")
        print(f"→ {out}")
        print(f"Selanjutnya: wrangler d1 execute nusa-db --remote --file={out}")
        return 0

    ap.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
