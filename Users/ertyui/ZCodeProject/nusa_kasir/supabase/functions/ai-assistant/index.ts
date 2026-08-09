// Supabase Edge Function: ai-assistant
//
// Uses Groq API (gratis, cepat) for AI chat.
// Endpoint: https://api.groq.com/openai/v1/chat/completions
// Default model: llama-3.1-8b-instant (free tier, fast)
//
// Deploy: supabase functions deploy ai-assistant
//
// Environment variables (set via Supabase Dashboard → Edge Functions):
//   GROQ_API_KEY  – Groq API key (https://console.groq.com/keys)
//   SYSTEM_PROMPT – optional, overrides the built-in prompt

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";

// ── Default system prompt ──────────────────────────────────────────
const DEFAULT_SYSTEM_PROMPT = `Kamu adalah AI Assistant untuk NUSA Kasir, aplikasi Point of Sale (POS) untuk toko kelontong, UMKM, dan retail di Indonesia.

ATURAN PENTING — WAJIB DIPATUHI:
1. Kamu HANYA menggunakan data yang diberikan dalam konteks. JANGAN PERNAH mengarang angka, fakta, statistik, nama produk, atau data apapun yang tidak ada di konteks.
2. Jika data yang diberikan tidak cukup untuk menjawab pertanyaan, katakan dengan jujur: "Saya tidak memiliki data untuk menjawab pertanyaan ini." Jangan mencoba menebak atau mengarang.
3. Jawab MAKSIMAL 3 kalimat. Langsung ke intinya — tanpa pembukaan, tanpa penutup, tanpa basa-basi. Tidak perlu "Halo!", "Tentu!", "Semoga membantu!", atau kalimat serupa.
4. Setiap angka yang kamu sebutkan HARUS berasal dari data konteks yang diberikan. Jika menyebut angka, pastikan itu ada di data.
5. Gunakan bahasa Indonesia natural, singkat, padat.

Topik yang bisa kamu bantu: analisis penjualan, stok, keuangan, promosi, pelanggan, laporan, absensi, dan fitur NUSA Kasir lainnya.

Jika ditanya hal di luar konteks bisnis/POS/NUSA Kasir, arahkan kembali dengan sopan dalam 1 kalimat saja.`;

const DEFAULT_MODEL = "llama-3.1-8b-instant";

// ── Main handler ───────────────────────────────────────────────────
serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const messages: { role: string; content: string }[] = body.messages ?? [];
    const storeName: string | undefined = body.store_name;
    const dbContext: string | undefined = body.db_context;

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

    // Build context-aware system prompt
    let fullSystemPrompt = systemPrompt;
    if (storeName) {
      fullSystemPrompt = `Konteks: kamu sedang membantu pemilik toko "${storeName}".\n\n${systemPrompt}`;
    }
    // Inject database context if available (real-time store data)
    if (dbContext && dbContext.trim().length > 0) {
      fullSystemPrompt = `${fullSystemPrompt}\n\nBerikut adalah data real-time toko saat ini (gunakan untuk menjawab pertanyaan dengan akurat):\n${dbContext}`;
    }

    // Build message array with system prompt
    const apiMessages = [
      { role: "system", content: fullSystemPrompt },
      ...messages,
    ];

    // Call Groq API (OpenAI-compatible)
    const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: DEFAULT_MODEL,
        messages: apiMessages,
        max_tokens: 512,
        temperature: 0.3,
      }),
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
    const reply = data.choices?.[0]?.message?.content
      ?? "Maaf, tidak ada jawaban dari AI.";

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
