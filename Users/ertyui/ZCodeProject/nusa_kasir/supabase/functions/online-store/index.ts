// ============================================================================
// NUSA KASIR — Online Store Edge Function
// Deploy: supabase functions deploy online-store --project-ref sakeuhcbcnueplzlkltm
// ============================================================================
// Handles all admin operations for the online store:
//   action: 'upsert_store'      — create/update store settings (slug unik per variant)
//   action: 'check_slug'        — cek ketersediaan slug (untuk input real-time)
//   action: 'sync_products'     — batch upsert products for a store
//   action: 'get_orders'        — get online orders for a store
//   action: 'update_order'      — update order status (state machine)
//   action: 'get_store'         — get store settings
//   action: 'get_store_by_variant_slug' — public storefront lookup
//   action: 'submit_order'      — order dari web storefront (WA normalize + anti-dobel customer + poin + promo + referral)
//   action: 'redeem_points'     — tukar poin member (validasi saldo)
//   action: 'sync_branches'     — upload cabang Aktif + WA per cabang → tabel branches
//   action: 'sync_promos'       — upload promo (quota/periode/minSpend/limitPerUser) → tabel promos
//   action: 'get_promos'        — read-back promo milik store
//   action: 'sync_print_form_configs' — cadangan config field form Order Cetak (replace-all per store)
//   action: 'get_print_form_configs'  — read-back config field form Order Cetak
// ============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ─── WA normalize (adaptasi GAS normalizePhoneTo08 + formatWA) ──────
// Simpan selalu bentuk 08xx (strip non-digit, 62→0, 8→08).
function normalizePhoneTo08(phone: any): string {
  if (!phone) return "";
  const clean = String(phone).replace(/[^0-9]/g, "");
  if (clean.startsWith("62")) return "0" + clean.substring(2);
  if (clean.startsWith("8")) return "0" + clean;
  return clean;
}
// wa.me butuh 62xx — 08xx → 62xx.
function formatWA(phone: string): string {
  const n = normalizePhoneTo08(phone);
  if (!n) return "";
  return "62" + n.substring(1);
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { action, ...params } = await req.json();

    switch (action) {
      case "upsert_store":
        return upsertStore(supabase, params);
      case "check_slug":
        return checkSlug(supabase, params);
      case "sync_products":
        return syncProducts(supabase, params);
      case "get_orders":
        return getOrders(supabase, params);
      case "update_order":
        return updateOrder(supabase, params);
      case "get_store":
        return getStore(supabase, params);
      case "get_store_by_variant_slug":
        return getStoreByVariantSlug(supabase, params);
      case "submit_order":
        return submitOrder(supabase, params);
      case "redeem_points":
        return redeemPoints(supabase, params);
      case "sync_branches":
        return syncBranches(supabase, params);
      case "sync_promos":
        return syncPromos(supabase, params);
      case "get_promos":
        return getPromos(supabase, params);
      case "sync_print_form_configs":
        return syncPrintFormConfigs(supabase, params);
      case "get_print_form_configs":
        return getPrintFormConfigs(supabase, params);
      default:
        return jsonResponse({ error: `Unknown action: ${action}` }, 400);
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return jsonResponse({ error: msg }, 500);
  }
});

// ─── Slug helpers ────────────────────────────────────────────────────
// Slug hanya huruf kecil, angka, dan tanda hubung. Panjang maks 40.
function isValidSlug(slug: string): boolean {
  return /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug) && slug.length <= 40;
}

// Level member dari poin — konsisten dengan web (src/lib/supabase.ts).
function memberLevelOf(points: number, member: any): string {
  const goldMin = Number(member.goldMin) || 1000;
  const platinumMin = Number(member.platinumMin) || 5000;
  if (points >= platinumMin) return "Platinum";
  if (points >= goldMin) return "Gold";
  return "Silver";
}

// ─── Upsert store settings ──────────────────────────────────────────
// Identitas toko: user_id (Google UID) + variant. store_id (= activation
// key) tetap disimpan untuk kompatibilitas data lama (produk/order).
// Alur:
//   1. user_id + variant → cari row milik user tsb; jika ada → UPDATE row itu.
//   2. Jika belum ada tapi ada row dengan store_id sama (milik user tsb,
//      dibuat sebelum migrasi user_id) → KLAIM: set user_id ke row itu.
//   3. Jika belum ada sama sekali → INSERT row baru dengan store_id + user_id.
// Slug unik per (user_id, variant) — toko milik user lain dengan variant
// sama TIDAK boleh pakai slug yang sama (409 slug_taken).
async function upsertStore(supabase: any, params: any) {
  const {
    store_id, user_id, store_name, description, whatsapp, address, open_hours,
    is_active, slug, variant, theme_id, primary_color, dark_color, soft_color,
    order_types, delivery_fee, pickup_options, payment_methods, member_settings,
    logo_url,
  } = params;
  if (!store_id) return jsonResponse({ error: "store_id required" }, 400);

  const uid = user_id || null;
  const varId = variant ?? "";

  // Ambil row milik user (by user_id+variant), lalu by store_id (legacy).
  const { data: userRow } = await supabase
    .from("store_settings")
    .select("store_id")
    .eq("user_id", uid)
    .eq("variant", varId)
    .maybeSingle();
  // SELALU query legacy by store_id — user tanpa Google login (user_id null)
  // tetap harus bisa UPDATE row lama; kalau hanya query saat uid, mereka
  // jatuh ke INSERT yang bentrok → 500 "server sibuk" (fix v2.2.57+116).
  const { data: legacyRow } = await supabase
    .from("store_settings")
    .select("store_id")
    .eq("store_id", store_id)
    .maybeSingle();

  // Slug unik per (user_id, variant): cek hanya antar row MILIK USER yang
  // bukan row target. Row user lain tidak menghalangi (anti rebutan slug).
  if (slug !== undefined && slug !== null && slug !== "") {
    if (!isValidSlug(slug)) {
      return jsonResponse({ error: "slug_invalid" }, 400);
    }
    const targetStoreId = userRow?.store_id ?? legacyRow?.store_id ?? store_id;
    const { data: existing, error: checkErr } = await supabase
      .from("store_settings")
      .select("store_id")
      .eq("variant", varId)
      .eq("slug", slug)
      .neq("store_id", targetStoreId)
      .maybeSingle();
    if (checkErr) return jsonResponse({ error: checkErr.message }, 500);
    // Kalau yang punya slug sama adalah row MILIK USER ini sendiri di
    // store_id lain (mis. varian lama) → row itu akan di-klaim/diupdate
    // lewat userRow, jadi tidak dianggap konflik. Konflik hanya bila
    // slug dipegang row milik user LAIN (user_id beda & bukan null).
    if (existing) {
      const { data: owner } = await supabase
        .from("store_settings")
        .select("user_id")
        .eq("store_id", existing.store_id)
        .maybeSingle();
      const ownerIsSelf = uid && owner?.user_id === uid;
      if (!ownerIsSelf) {
        return jsonResponse({ error: "slug_taken" }, 409);
      }
    }
  }

  const row: any = {
    store_id,
    store_name: store_name ?? "",
    description: description ?? "",
    whatsapp: whatsapp ? normalizePhoneTo08(whatsapp) : "", // WA selalu 08xx
    address: address ?? "",
    open_hours: open_hours ?? "08:00 - 21:00",
    is_active: is_active ?? false,
    slug: slug ?? "",
    variant: varId,
    theme_id: theme_id ?? "",
    primary_color: primary_color ?? "",
    dark_color: dark_color ?? "",
    soft_color: soft_color ?? "",
    updated_at: new Date().toISOString(),
  };
  if (uid) row.user_id = uid;
  // Kolom ekstra (C1) — hanya ditulis bila dikirim (JSON string dari app).
  if (order_types !== undefined) row.order_types = order_types;
  if (delivery_fee !== undefined) row.delivery_fee = Number(delivery_fee) || 0;
  if (pickup_options !== undefined) row.pickup_options = pickup_options;
  if (payment_methods !== undefined) row.payment_methods = payment_methods;
  if (member_settings !== undefined) row.member_settings = member_settings;
  if (logo_url !== undefined) row.logo_url = logo_url;

  // Target: row milik user (userRow), lalu row legacy by store_id,
  // lalu insert baru. UPDATE mempertahankan store_id asli (produk/order
  // lama tetap tertaut) — hanya data konfigurasi yang berubah.
  const targetId = userRow?.store_id ?? legacyRow?.store_id;
  if (targetId) {
    const { error } = await supabase
      .from("store_settings")
      .update(row)
      .eq("store_id", targetId);
    if (error) return jsonResponse({ error: error.message }, 500);
    return jsonResponse({ ok: true, store_id: targetId, claimed: legacyRow && !userRow ? true : false });
  }

  const { error: insErr } = await supabase
    .from("store_settings")
    .upsert(row, { onConflict: "store_id" });
  if (insErr) return jsonResponse({ error: insErr.message }, 500);
  return jsonResponse({ ok: true, store_id });
}

// ─── Cek ketersediaan slug (real-time saat user mengetik) ───────────
// Slug dianggap TERSEDIA bila tidak ada row varian sama yang memakainya
// KECUALI row itu milik user yang sama (row sendiri tidak menghalangi).
async function checkSlug(supabase: any, params: any) {
  const { slug, variant, user_id } = params;
  if (!slug) return jsonResponse({ error: "slug required" }, 400);
  if (!isValidSlug(slug)) {
    return jsonResponse({ available: false, reason: "invalid" });
  }

  const { data, error } = await supabase
    .from("store_settings")
    .select("store_id, user_id")
    .eq("variant", variant ?? "")
    .eq("slug", slug)
    .maybeSingle();
  if (error) return jsonResponse({ error: error.message }, 500);

  // Row sendiri (user_id sama) → bukan "taken".
  if (data && user_id && data.user_id === user_id) {
    return jsonResponse({ available: true, reason: "ok" });
  }
  return jsonResponse({ available: !data, reason: data ? "taken" : "ok" });
}

// ─── Sync products (batch upsert, dedupe by product_id) ─────────────
// v2.2.57+120: DELETE+INSERT batch sebelumnya 500 "server sibuk" kalau
// daftar produk mengandung product_id duplikat (id dobel dari restore/
// import) → melanggar unique index (store_id, product_id). Sekarang:
//   1. dedupe by product_id (last-wins) — sync tidak pernah gagal total
//      gara-gara 1 produk bermasalah;
//   2. DELETE all dulu (clean sync, produk non-online dihapus dari web),
//      lalu INSERT batch yang sudah bersih.
async function syncProducts(supabase: any, params: any) {
  const { store_id, products } = params;
  if (!store_id) return jsonResponse({ error: "store_id required" }, 400);
  if (!products || !Array.isArray(products)) return jsonResponse({ error: "products array required" }, 400);

  const now = new Date().toISOString();
  const byId = new Map<number | string, any>();
  for (const p of products) {
    const pid = p.product_id;
    if (pid === undefined || pid === null || pid === "") continue; // skip row tanpa id
    // Last-wins: kalau product_id sama muncul 2x, pakai baris terakhir.
    byId.set(pid, {
      store_id,
      product_id: pid,
      name: p.name ?? "",
      category: p.category ?? "Lainnya",
      price: p.price ?? 0,
      original_price: p.original_price ?? null,
      stock: p.stock ?? 0,
      image_url: p.image ?? "",
      description: p.description ?? "",
      is_published: p.is_published ?? true,
      updated_at: now,
    });
  }
  const rows = [...byId.values()];

  // Delete old products, then insert clean batch (clean sync).
  const { error: delErr } = await supabase
    .from("online_products")
    .delete()
    .eq("store_id", store_id);

  if (delErr) return jsonResponse({ error: delErr.message }, 500);

  if (rows.length > 0) {
    // Chunk insert biar tidak kena payload limit / row limit (batch besar).
    for (let i = 0; i < rows.length; i += 500) {
      const chunk = rows.slice(i, i + 500);
      const { error: insErr } = await supabase
        .from("online_products")
        .insert(chunk);
      if (insErr) return jsonResponse({ error: insErr.message }, 500);
    }
  }

  return jsonResponse({ ok: true, count: rows.length, skipped: products.length - rows.length });
}

// ─── Get orders for a store ────────────────────────────────────────
async function getOrders(supabase: any, params: any) {
  const { store_id, status, limit } = params;
  if (!store_id) return jsonResponse({ error: "store_id required" }, 400);

  let query = supabase
    .from("online_orders")
    .select("*")
    .eq("store_id", store_id)
    .order("created_at", { ascending: false });

  if (status) {
    query = query.eq("status", status);
  }

  query = query.limit(limit ?? 50);

  const { data, error } = await query;
  if (error) return jsonResponse({ error: error.message }, 500);

  return jsonResponse({ orders: data ?? [] });
}

// ─── Update order status (state machine) ───────────────────────────
// Status baru (v2.2.23):
//   "Menunggu Verifikasi Pembeli" → [Online Baru, Dibatalkan]   (non-tunai: kasir cek bukti)
//   "Online Baru"                 → [Disiapkan, Dibatalkan]
//   "Disiapkan"                   → [Siap Diambil, Dibatalkan]
//   "Siap Diambil"                → [Lunas, Dibatalkan]
//   "Lunas"                       → [Direfund]
//   "Direfund"                    → []   (terminal)
//   "Dibatalkan"                  → []
async function updateOrder(supabase: any, params: any) {
  const { store_id, order_id, status, processed_by } = params;
  if (!store_id || !order_id || !status) {
    return jsonResponse({ error: "store_id, order_id, status required" }, 400);
  }

  // Validate state transition
  const validTransitions: Record<string, string[]> = {
    "Menunggu Verifikasi Pembeli": ["Online Baru", "Dibatalkan"],
    "Online Baru": ["Disiapkan", "Dibatalkan"],
    "Disiapkan": ["Siap Diambil", "Dibatalkan"],
    "Siap Diambil": ["Lunas", "Dibatalkan"],
    "Lunas": ["Direfund"],
    "Direfund": [],
    "Dibatalkan": [],
  };

  // Get current status
  const { data: existing } = await supabase
    .from("online_orders")
    .select("status, used_points, customer_phone, store_id")
    .eq("id", order_id)
    .eq("store_id", store_id)
    .single();

  if (!existing) return jsonResponse({ error: "Order not found" }, 404);

  const currentStatus = existing.status;
  const allowed = validTransitions[currentStatus];
  if (!allowed || !allowed.includes(status)) {
    return jsonResponse({
      error: `Cannot transition from '${currentStatus}' to '${status}'`,
      allowed,
    }, 400);
  }

  const updates: any = {
    status,
    updated_at: new Date().toISOString(),
  };
  if (processed_by) {
    updates.processed_by = processed_by;
  }

  // Lunas: akumulasi poin + total_spent ke online_customers (GAS pattern).
  if (status === "Lunas" && (existing.used_points > 0 || existing.customer_phone)) {
    await applyOrderToCustomer(supabase, store_id, existing, params);
  }

  const { error } = await supabase
    .from("online_orders")
    .update(updates)
    .eq("id", order_id)
    .eq("store_id", store_id);

  if (error) return jsonResponse({ error: error.message }, 500);

  return jsonResponse({ ok: true, status });
}

// Akumulasi ke online_customers saat Lunas: total_spent, poin earned,
// referral reward untuk referrer, promo history. Di-call dari update_order
// (kasir konfirmasi Lunas) — order sudah final.
async function applyOrderToCustomer(supabase: any, storeId: string, order: any, params: any) {
  try {
    const phone = normalizePhoneTo08(order.customer_phone);
    if (!phone) return;

    // Ambil store settings (member_settings: poin rate + referral).
    const { data: store } = await supabase
      .from("store_settings")
      .select("store_id, member_settings")
      .eq("store_id", storeId)
      .maybeSingle();
    let member = { pointEarnPercent: 0, referralRewardType: "nominal", referralRewardValue: 0, goldMin: 1000, platinumMin: 5000 };
    try {
      member = { ...member, ...(JSON.parse(store?.member_settings ?? "{}")) };
    } catch (_) {}

    // Order detail (used_points, promo) sudah di kolom online_orders.
    const { data: ord } = await supabase
      .from("online_orders")
      .select("id, total, used_points, used_promo_id, promo_discount, referred_by, customer_name")
      .eq("id", order.id)
      .single();
    if (!ord) return;

    const total = Number(ord.total) || 0;
    const usedPoints = Number(ord.used_points) || 0;
    const earned = Math.floor(total * (Number(member.pointEarnPercent) || 0) / 100);

    // Upsert customer by (store_id, phone) — anti-dobel: update nama & akumulasi.
    const { data: existing } = await supabase
      .from("online_customers")
      .select("id, points, total_spent, promo_history")
      .eq("store_id", storeId)
      .eq("phone", phone)
      .maybeSingle();

    if (existing) {
      const history = Array.isArray(existing.promo_history) ? existing.promo_history : [];
      if (ord.used_promo_id && !history.some((h: any) => h.promo_id === ord.used_promo_id)) {
        history.push({ promo_id: ord.used_promo_id, used_at: new Date().toISOString() });
      }
      const newPoints = (existing.points || 0) + earned - usedPoints;
      await supabase
        .from("online_customers")
        .update({
          name: ord.customer_name || existing.name,
          points: newPoints,
          level: memberLevelOf(newPoints, member),
          total_spent: (existing.total_spent || 0) + total,
          promo_history: history,
          updated_at: new Date().toISOString(),
        })
        .eq("id", existing.id);
    } else {
      const history = ord.used_promo_id ? [{ promo_id: ord.used_promo_id, used_at: new Date().toISOString() }] : [];
      const newPoints = earned - usedPoints;
      const { data: newCust } = await supabase
        .from("online_customers")
        .insert({
          store_id: storeId,
          name: ord.customer_name || "Pelanggan",
          phone,
          total_spent: total,
          points: newPoints,
          level: memberLevelOf(newPoints, member),
          promo_history: history,
          referred_by: normalizePhoneTo08(ord.referred_by || ""),
        })
        .select("id, referred_by")
        .single();

      // Ajak teman: reward referrer HANYA untuk customer BARU (GAS pattern).
      const refPhone = normalizePhoneTo08(ord.referred_by || "");
      if (newCust && refPhone && refPhone !== phone) {
        let refPts = 0;
        if (member.referralRewardType === "persen") {
          refPts = Math.floor(total * (Number(member.referralRewardValue) || 0) / 100);
        } else {
          refPts = Number(member.referralRewardValue) || 0;
        }
        if (refPts > 0) {
          const { data: ref } = await supabase
            .from("online_customers")
            .select("id, points")
            .eq("store_id", storeId)
            .eq("phone", refPhone)
            .maybeSingle();
          if (ref) {
            const refPoints = (ref.points || 0) + refPts;
            await supabase
              .from("online_customers")
              .update({ points: refPoints, level: memberLevelOf(refPoints, member) })
              .eq("id", ref.id);
          }
        }
      }
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.warn("[applyOrderToCustomer] failed (non-blocking):", msg);
  }
}

// ─── Submit order (web storefront / direct) ─────────────────────────
// Non-tunai → status "Menunggu Verifikasi Pembeli" (kasir cek bukti dulu).
// Tunai → "Online Baru". WA dinormalisasi 08xx; customer anti-dobel.
async function submitOrder(supabase: any, params: any) {
  const {
    store_id, customer_name, customer_phone, items, subtotal, discount,
    promo_code, handling_fee, total, payment_method, pickup_time, branch,
    notes, order_type, used_points, used_promo_id, promo_discount, referred_by,
  } = params;
  if (!store_id || !customer_phone || !items || !Array.isArray(items)) {
    return jsonResponse({ error: "store_id, customer_phone, items required" }, 400);
  }

  const phone = normalizePhoneTo08(customer_phone);
  if (!phone) return jsonResponse({ error: "Nomor WhatsApp tidak valid" }, 400);

  const invoice = `ONL-${new Date().toISOString().replace(/[-:T]/g, "").slice(2, 14)}`;
  const isTunai = String(payment_method || "").toLowerCase().includes("tunai");
  // GAS initStatus: tunai → "Online Baru"; non-tunai → "Menunggu Verifikasi Pembeli".
  const initStatus = isTunai ? "Online Baru" : "Menunggu Verifikasi Pembeli";

  const { error } = await supabase.from("online_orders").insert({
    store_id,
    invoice,
    customer_name: customer_name ?? "Pelanggan",
    customer_phone: phone,
    items,
    subtotal: Number(subtotal) || 0,
    discount: Number(discount) || 0,
    promo_code: promo_code ?? "",
    handling_fee: Number(handling_fee) || 0,
    total: Number(total) || 0,
    payment_method: payment_method ?? "Tunai",
    pickup_time: pickup_time ?? "Segera",
    branch: branch ?? "Pusat",
    notes: notes ?? "",
    order_type: order_type ?? "",
    used_points: Number(used_points) || 0,
    used_promo_id: used_promo_id ?? null,
    promo_discount: Number(promo_discount) || 0,
    status: initStatus,
  });

  if (error) return jsonResponse({ error: error.message }, 500);

  // Anti-dobel customer: lookup by (store_id, phone ternormalisasi) →
  // update nama + akumulasi, BUKAN insert baru ("Adi"/"adi" = 1 pelanggan).
  try {
    const { data: existing } = await supabase
      .from("online_customers")
      .select("id")
      .eq("store_id", store_id)
      .eq("phone", phone)
      .maybeSingle();
    if (existing) {
      await supabase
        .from("online_customers")
        .update({ name: customer_name ?? "", updated_at: new Date().toISOString() })
        .eq("id", existing.id);
    } else {
      await supabase.from("online_customers").insert({
        store_id,
        name: customer_name ?? "Pelanggan",
        phone,
        referred_by: normalizePhoneTo08(referred_by || ""),
      });
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.warn("[submitOrder] customer upsert failed (non-blocking):", msg);
  }

  // WA link tujuan: store.whatsapp (08xx → 62xx).
  const { data: store } = await supabase
    .from("store_settings")
    .select("store_name, whatsapp")
    .eq("store_id", store_id)
    .maybeSingle();
  const storeWa = formatWA(store?.whatsapp || "");
  const storeName = store?.store_name || "Toko";

  const itemsText = items.map((i: any) => `• ${i.name} x${i.qty} — ${formatRupiah(i.subtotal ?? i.price * i.qty)}`).join("\n");
  const waMessage = encodeURIComponent(
    `🛒 *Pesanan Baru — ${storeName}*\n\n` +
    `📋 *${invoice}*\n` +
    `👤 ${customer_name}\n` +
    `📱 ${phone}\n` +
    `🏪 ${branch ?? "Pusat"}\n` +
    `💳 ${payment_method}\n` +
    `🕐 ${pickup_time ?? "Segera"}\n\n` +
    `*Item:*\n${itemsText}\n\n` +
    `💰 *Total: ${formatRupiah(Number(total) || 0)}*\n\n` +
    `_Catatan: ${notes || "-"}_`
  );

  return jsonResponse({
    ok: true,
    invoice,
    status: initStatus,
    whatsappUrl: storeWa ? `https://wa.me/${storeWa}?text=${waMessage}` : "",
  });
}

// ─── Redeem points (tukar poin member) ──────────────────────────────
async function redeemPoints(supabase: any, params: any) {
  const { store_id, phone, points } = params;
  if (!store_id || !phone || !points || Number(points) <= 0) {
    return jsonResponse({ error: "store_id, phone, points required" }, 400);
  }
  const p = normalizePhoneTo08(phone);
  const pts = Number(points);

  const { data: cust, error } = await supabase
    .from("online_customers")
    .select("id, points")
    .eq("store_id", store_id)
    .eq("phone", p)
    .maybeSingle();
  if (error) return jsonResponse({ error: error.message }, 500);
  if (!cust) return jsonResponse({ error: "Customer not found" }, 404);
  if ((cust.points || 0) < pts) {
    return jsonResponse({ error: "Poin tidak cukup", available: cust.points }, 400);
  }

  // Ambil member_settings untuk hitung ulang level setelah tukar poin.
  let member: any = {};
  try {
    const { data: store } = await supabase
      .from("store_settings")
      .select("member_settings")
      .eq("store_id", store_id)
      .maybeSingle();
    member = JSON.parse(store?.member_settings ?? "{}");
  } catch (_) {}

  const pointsLeft = (cust.points || 0) - pts;
  const { error: upErr } = await supabase
    .from("online_customers")
    .update({
      points: pointsLeft,
      level: memberLevelOf(pointsLeft, member),
      updated_at: new Date().toISOString(),
    })
    .eq("id", cust.id);
  if (upErr) return jsonResponse({ error: upErr.message }, 500);

  return jsonResponse({ ok: true, points_left: pointsLeft });
}

// ─── Sync branches (cabang toko online + WA per cabang) ─────────────
// Dedupe by name (unique idx_branches_store_name) — nama dobel tidak
// boleh menggagalkan seluruh sync (v2.2.57+120).
async function syncBranches(supabase: any, params: any) {
  const { store_id, branches } = params;
  if (!store_id) return jsonResponse({ error: "store_id required" }, 400);
  if (!branches || !Array.isArray(branches)) {
    return jsonResponse({ error: "branches array required" }, 400);
  }

  const { error: delErr } = await supabase
    .from("branches")
    .delete()
    .eq("store_id", store_id);
  if (delErr) return jsonResponse({ error: delErr.message }, 500);

  if (branches.length > 0) {
    const byName = new Map<string, any>();
    branches.forEach((b: any, i: number) => {
      const name = String(b.name ?? "").trim();
      if (!name) return;
      byName.set(name, {
        store_id,
        name,
        phone: normalizePhoneTo08(b.phone || ""),
        is_active: b.is_active ?? true,
        sort: i,
      });
    });
    const rows = [...byName.values()];
    if (rows.length > 0) {
      const { error: insErr } = await supabase.from("branches").insert(rows);
      if (insErr) return jsonResponse({ error: insErr.message }, 500);
    }
    return jsonResponse({ ok: true, count: rows.length, skipped: branches.length - rows.length });
  }

  return jsonResponse({ ok: true, count: 0 });
}

// ─── Sync promos (kupon online) ─────────────────────────────────────
// Dedupe by code (unique idx_promos_store_code) — kode dobel tidak
// boleh menggagalkan seluruh sync (v2.2.57+120).
async function syncPromos(supabase: any, params: any) {
  const { store_id, promos } = params;
  if (!store_id) return jsonResponse({ error: "store_id required" }, 400);
  if (!promos || !Array.isArray(promos)) {
    return jsonResponse({ error: "promos array required" }, 400);
  }

  const { error: delErr } = await supabase
    .from("promos")
    .delete()
    .eq("store_id", store_id);
  if (delErr) return jsonResponse({ error: delErr.message }, 500);

  if (promos.length > 0) {
    const byCode = new Map<string, any>();
    for (const p of promos) {
      const code = String(p.code ?? "").trim().toUpperCase();
      if (!code) continue;
      byCode.set(code, {
        store_id,
        code,
        title: p.title ?? p.code ?? "",
        type: p.type ?? "persen", // persen | nominal
        value: Number(p.value) || 0,
        min_spend: Number(p.min_spend) || 0,
        quota: p.quota === undefined || p.quota === null ? null : Number(p.quota),
        limit_per_user: p.limit_per_user === undefined || p.limit_per_user === null ? null : Number(p.limit_per_user),
        start_date: p.start_date ?? null,
        end_date: p.end_date ?? null,
        is_active: p.is_active ?? true,
      });
    }
    const rows = [...byCode.values()];
    if (rows.length > 0) {
      const { error: insErr } = await supabase.from("promos").insert(rows);
      if (insErr) return jsonResponse({ error: insErr.message }, 500);
    }
    return jsonResponse({ ok: true, count: rows.length, skipped: promos.length - rows.length });
  }

  return jsonResponse({ ok: true, count: 0 });
}

// ─── Get promos (admin app read-back untuk CRUD kupon) ────────────
async function getPromos(supabase: any, params: any) {
  const { store_id } = params;
  if (!store_id) return jsonResponse({ error: "store_id required" }, 400);
  const { data, error } = await supabase
    .from("promos")
    .select("*")
    .eq("store_id", store_id)
    .order("created_at", { ascending: false });
  if (error) return jsonResponse({ error: error.message }, 500);
  return jsonResponse({ promos: data ?? [] });
}

// ─── Print form configs (Order Cetak — field per layanan) ──────────
// Cadangan cloud dari config field form per layanan percetakan.
// Store keyed by store_id (sama dengan tabel lain). Web tidak memakai —
// murni supaya config tidak hilang saat clear-data / ganti device.
async function syncPrintFormConfigs(supabase: any, params: any) {
  const { store_id, configs } = params;
  if (!store_id) return jsonResponse({ error: "store_id required" }, 400);
  if (!configs || !Array.isArray(configs)) {
    return jsonResponse({ error: "configs array required" }, 400);
  }

  const { error: delErr } = await supabase
    .from("print_form_configs")
    .delete()
    .eq("store_id", store_id);
  if (delErr) return jsonResponse({ error: delErr.message }, 500);

  if (configs.length === 0) return jsonResponse({ ok: true, count: 0 });

  // Dedupe by service_name — nama layanan dobel tidak menggagalkan sync.
  const byService = new Map<string, any>();
  for (const c of configs) {
    const name = String(c.service_name ?? "").trim();
    if (!name) continue;
    byService.set(name, {
      store_id,
      service_name: name,
      fields_json: c.fields_json ?? null,
      updated_at: new Date().toISOString(),
    });
  }
  const rows = [...byService.values()];
  const { error: insErr } = await supabase.from("print_form_configs").insert(rows);
  if (insErr) return jsonResponse({ error: insErr.message }, 500);
  return jsonResponse({ ok: true, count: rows.length, skipped: configs.length - rows.length });
}

async function getPrintFormConfigs(supabase: any, params: any) {
  const { store_id } = params;
  if (!store_id) return jsonResponse({ error: "store_id required" }, 400);
  const { data, error } = await supabase
    .from("print_form_configs")
    .select("service_name, fields_json")
    .eq("store_id", store_id);
  if (error) return jsonResponse({ error: error.message }, 500);
  return jsonResponse({ configs: data ?? [] });
}

// ─── Get store settings (admin app) ────────────────────────────
// TANPA filter is_active: app harus bisa membaca toko walau toggle
// OFF (mis. user baru saja mematikan lalu kembali ke layar). Storefront
// publik (getStoreByVariantSlug) yang memfilter is_active.
// Lookup: store_id (legacy) DULU, lalu fallback (user_id, variant) —
// supaya user yang clear-data + re-login (key mungkin beda) tetap
// menemukan setup lamanya.
async function getStore(supabase: any, params: any) {
  const { store_id, user_id, variant } = params;
  if (!store_id && !(user_id && variant)) {
    return jsonResponse({ error: "store_id (atau user_id+variant) required" }, 400);
  }

  let data: any = null;
  if (store_id) {
    const r = await supabase
      .from("store_settings")
      .select("*")
      .eq("store_id", store_id)
      .maybeSingle();
    if (r.error) return jsonResponse({ error: r.error.message }, 500);
    data = r.data;
  }

  // Fallback: row milik user ini di varian ini (setup lama tetap ketemu).
  if (!data && user_id && variant) {
    const r = await supabase
      .from("store_settings")
      .select("*")
      .eq("user_id", user_id)
      .eq("variant", variant)
      .maybeSingle();
    if (r.error) return jsonResponse({ error: r.error.message }, 500);
    data = r.data;
  }

  if (!data) return jsonResponse({ error: "Store not found" }, 404);

  return jsonResponse({ store: data });
}

// ─── Public storefront lookup: /toko/{variant}/{slug} ──────────────
async function getStoreByVariantSlug(supabase: any, params: any) {
  const { variant, slug } = params;
  if (!variant || !slug) {
    return jsonResponse({ error: "variant and slug required" }, 400);
  }

  const { data, error } = await supabase
    .from("store_settings")
    .select("*")
    .eq("variant", variant)
    .eq("slug", slug)
    .eq("is_active", true)
    .maybeSingle();

  if (error) return jsonResponse({ error: error.message }, 500);
  if (!data) return jsonResponse({ error: "Store not found or inactive" }, 404);

  return jsonResponse({ store: data });
}

function formatRupiah(n: number): string {
  return `Rp ${(n || 0).toLocaleString("id-ID")}`;
}

function jsonResponse(body: any, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
