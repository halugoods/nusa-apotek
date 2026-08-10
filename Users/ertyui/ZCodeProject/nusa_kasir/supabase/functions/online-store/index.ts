// NUSA KASIR -- Online Store Edge Function
// Deploy: supabase functions deploy online-store --project-ref sakeuhcbcnueplzlkltm
// Actions: upsert_store, get_store, sync_products, get_orders, update_order

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const body = await req.json();
    const { action } = body;
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceRoleKey) {
      return json({ error: "server_misconfigured" }, 500);
    }

    // Use service_role client — fully trusted, bypasses RLS.
    const sb = createClient(supabaseUrl, serviceRoleKey);

    switch (action) {
      case "upsert_store":
        return upsertStore(sb, body);
      case "get_store":
        return getStore(sb, body);
      case "sync_products":
        return syncProducts(sb, body);
      case "get_orders":
        return getOrders(sb, body);
      case "update_order":
        return updateOrder(sb, body);
      default:
        return json({ error: "Unknown action: " + action }, 400);
    }
  } catch (e) {
    console.error("online-store error:", e);
    return json({ error: "server_error" }, 500);
  }
});

async function upsertStore(sb: any, b: any) {
  const { store_id, store_name, slug } = b;
  if (!store_id || !store_name) {
    return json({ error: "store_id and store_name required" }, 400);
  }

  const s = slug || store_name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");

  const { error } = await sb.from("store_settings").upsert(
    {
      store_id,
      store_name,
      slug: s,
      description: b.description || "",
      whatsapp: b.whatsapp || "",
      address: b.address || "",
      open_hours: b.open_hours || "08:00 - 21:00",
      is_active: b.is_active ?? false,
    },
    { onConflict: "store_id" },
  );

  if (error) {
    console.error("upsertStore error:", error);
    return json({ error: error.message }, 500);
  }
  return json({ ok: true, slug: s });
}

async function getStore(sb: any, b: any) {
  const { store_id } = b;
  if (!store_id) return json({ error: "store_id required" }, 400);
  const { data, error } = await sb
    .from("store_settings")
    .select("*")
    .eq("store_id", store_id)
    .maybeSingle();
  if (error) return json({ error: error.message }, 500);
  return json({ store: data });
}

async function syncProducts(sb: any, b: any) {
  const { store_id, products } = b;
  if (!store_id || !Array.isArray(products)) {
    return json({ error: "store_id and products required" }, 400);
  }

  const { error: deleteError } = await sb
    .from("online_products")
    .delete()
    .eq("store_id", store_id);
  if (deleteError) {
    console.error("syncProducts delete error:", deleteError);
    return json({ error: "product_delete_failed" }, 500);
  }

  if (products.length === 0) return json({ ok: true, count: 0 });

  const rows = products.map((p: any) => ({
    store_id,
    product_id: p.product_id,
    name: p.name,
    category: p.category || "Lainnya",
    price: p.price,
    stock: p.stock ?? 0,
    image_url: p.image || "",
    description: p.description || "",
    is_published: p.is_published ?? true,
  }));

  const { error } = await sb.from("online_products").insert(rows);
  if (error) {
    console.error("syncProducts insert error:", error);
    return json({ error: error.message }, 500);
  }
  return json({ ok: true, count: rows.length });
}

async function getOrders(sb: any, b: any) {
  const { store_id, status, limit } = b;
  if (!store_id) return json({ error: "store_id required" }, 400);

  let q = sb
    .from("online_orders")
    .select("*")
    .eq("store_id", store_id)
    .order("created_at", { ascending: false })
    .limit(Math.min(Math.max(Number(limit) || 50, 1), 100));
  if (status) q = q.eq("status", status);

  const { data, error } = await q;
  if (error) return json({ error: error.message }, 500);
  return json({ orders: data ?? [] });
}

async function updateOrder(sb: any, b: any) {
  const { store_id, order_id, status, processed_by } = b;
  if (!store_id || !order_id || !status) {
    return json({ error: "store_id, order_id, status required" }, 400);
  }

  const { error } = await sb
    .from("online_orders")
    .update({ status, processed_by: processed_by || "" })
    .eq("id", order_id)
    .eq("store_id", store_id);
  if (error) return json({ error: error.message }, 500);
  return json({ ok: true });
}

function json(data: any, code = 200) {
  return new Response(JSON.stringify(data), {
    status: code,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
