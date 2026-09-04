/**
 * db.ts — helper D1 yang meniru pola query Supabase yang dipakai di
 * edge fn (select/eq/single/insert/update/upsert), supaya port 1:1
 * tetap sederhana tanpa ORM. Tulis SQL mentah bila lebih jelas.
 */
import type { Env } from '../index';

export function uid(): string {
  return crypto.randomUUID();
}

export function nowIso(): string {
  return new Date().toISOString();
}

/** Konversi row D1 (snake_case kolom) → objek yang dikirim ke app (sama dgn Supabase). */
export function camelize(row: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(row)) {
    out[k] = v;
  }
  return out;
}

/** Parse JSON kolom dengan fallback aman. */
export function parseJson<T>(s: unknown, fallback: T): T {
  if (s == null) return fallback;
  if (typeof s === 'object') return s as T;
  try {
    return JSON.parse(String(s)) as T;
  } catch {
    return fallback;
  }
}

/** Admin key check — semua fn mengharuskan x-admin-key ATAU JWT dashboard. */
export function requireAdmin(ctx: { isAdmin: boolean; jwt: Record<string, unknown> | null }): boolean {
  return ctx.isAdmin || ctx.jwt != null;
}

export type { Env };
