// Supabase Edge Function: ai-assistant
//
// Uses Groq API (gratis, cepat) for AI chat with tool calling support.
// Endpoint: https://api.groq.com/openai/v1/chat/completions
// Default model: llama-3.1-8b-instant (free tier, fast)
//
// When `tools` are provided by the client, the function passes them to Groq
// with tool_choice: "auto". If Groq returns tool_calls, they are returned
// to the client for local execution. The client then sends results back
// as `tool` role messages for the final text reply.
//
// Deploy: supabase functions deploy ai-assistant
//
// Environment variables (set via Supabase Dashboard → Edge Functions):
//   GROQ_API_KEY  – Groq API key (https://console.groq.com/keys)
//   SYSTEM_PROMPT – optional, overrides the built-in prompt

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

// ── Default system prompt ──────────────────────────────────────────
const DEFAULT_SYSTEM_PROMPT = `Kamu AI Assistant NUSA Kasir, aplikasi POS untuk UMKM Indonesia.

ATURAN:
1. Jawab maks 3 kalimat. Langsung inti, tanpa basa-basi.
2. Untuk data detail (produk, pelanggan, transaksi, dll), GUNAKAN TOOL. Jangan mengarang.
3. Jika data tool tidak cukup, katakan jujur: "Data tidak tersedia."
4. Bahasa Indonesia natural, singkat.
5. Di luar topik bisnis/POS: arahkan kembali 1 kalimat.

Tools tersedia: get_products, get_low_stock, get_customers, get_summary, get_monthly_summary, get_transactions, get_top_products, get_promos, get_employees, get_attendance, get_expenses, get_debts, get_suppliers (+ domain-specific tools).`;

const DEFAULT_MODEL = "llama-3.1-8b-instant";

// ── Main handler ───────────────────────────────────────────────────
serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const messages: { role: string; content: string; tool_call_id?: string; name?: string }[] = body.messages ?? [];
    const storeName: string | undefined = body.store_name;
    const dbContext: string | undefined = body.db_context;
    const tools: any[] | undefined = body.tools;

    if (!messages || messages.length === 0) {
      return new Response(
        JSON.stringify({ reply: "Tidak ada pesan yang dikirim." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const apiKey = Deno.env.get("GROQ_API_KEY");
    if (!apiKey) {
      return new Response(
        JSON.stringify({ reply: "⚠️ AI Assistant belum dikonfigurasi. Admin perlu menambahkan GROQ_API_KEY di Supabase Edge Function settings. Dapatkan key gratis di https://console.groq.com/keys" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const systemPrompt = Deno.env.get("SYSTEM_PROMPT") ?? DEFAULT_SYSTEM_PROMPT;

    // Build context-aware system prompt (keep lean to avoid 429)
    let fullSystemPrompt = systemPrompt;
    if (storeName) {
      fullSystemPrompt = `Toko: "${storeName}". ${systemPrompt}`;
    }

    // Build message array with system prompt
    const apiMessages = [
      { role: "system", content: fullSystemPrompt },
      ...messages,
    ];

    // Build request body
    const requestBody: any = {
      model: DEFAULT_MODEL,
      messages: apiMessages,
      max_tokens: 200,
      temperature: 0.3,
    };

    // Add tools if provided
    if (tools && tools.length > 0) {
      requestBody.tools = tools;
      requestBody.tool_choice = "auto";
    }

    // Call Groq API (OpenAI-compatible)
    const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(requestBody),
    });

    if (!response.ok) {
      const err = await response.text();
      console.error(`Groq error ${response.status}:`, err);
      return new Response(
        JSON.stringify({ reply: `Maaf, AI Assistant sedang sibuk (error ${response.status}). Coba lagi nanti ya.` }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const data = await response.json();
    const choice = data.choices?.[0];
    const message = choice?.message;

    // Check for tool calls first
    if (message?.tool_calls && message.tool_calls.length > 0) {
      return new Response(
        JSON.stringify({ tool_calls: message.tool_calls }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Text reply
    const reply = message?.content ?? "Maaf, tidak ada jawaban dari AI.";

    return new Response(
      JSON.stringify({ reply }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("ai-assistant error:", err);
    return new Response(
      JSON.stringify({ reply: `⚠️ Gagal memproses: ${err instanceof Error ? err.message : "unknown error"}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
