/**
 * Auth primitives — JWT HS256 (WebCrypto) + PBKDF2 password hashing.
 * Format password_hash: `pbkdf2$<iter>$<saltB64>$<hashB64>`.
 * Semua kripto via crypto.subtle native — zero dependency.
 */
import type { Env } from './index';

const PBKDF2_ITER = 100_000;
const JWT_TTL_SECONDS = 30 * 24 * 3600; // 30 hari (sesuai plan)

function b64urlEncode(bytes: Uint8Array): string {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlDecode(s: string): Uint8Array {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4) s += '=';
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function utf8(s: string): Uint8Array {
  return new TextEncoder().encode(s) as Uint8Array<ArrayBuffer>;
}

function asBuf(u: Uint8Array): Uint8Array<ArrayBuffer> {
  // TS 5.9 lib: WebCrypto butuh Uint8Array<ArrayBuffer> (bukan SharedArrayBuffer).
  return u as Uint8Array<ArrayBuffer>;
}

// ── Password hashing (PBKDF2-SHA256) ─────────────────────────────────

export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const keyMaterial = await crypto.subtle.importKey('raw', asBuf(utf8(password)), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt: asBuf(salt), iterations: PBKDF2_ITER, hash: 'SHA-256' },
    keyMaterial,
    256,
  );
  return `pbkdf2$${PBKDF2_ITER}$${b64urlEncode(salt)}$${b64urlEncode(new Uint8Array(bits))}`;
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2') return false;
  const iter = parseInt(parts[1], 10);
  const salt = b64urlDecode(parts[2]);
  const expected = b64urlDecode(parts[3]);
  const keyMaterial = await crypto.subtle.importKey('raw', asBuf(utf8(password)), 'PBKDF2', false, ['deriveBits']);
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt: asBuf(salt), iterations: iter, hash: 'SHA-256' },
    keyMaterial,
    expected.length * 8,
  );
  const got = new Uint8Array(bits);
  // constant-time compare
  if (got.length !== expected.length) return false;
  let diff = 0;
  for (let i = 0; i < got.length; i++) diff |= got[i] ^ expected[i];
  return diff === 0;
}

// ── JWT (HS256) ──────────────────────────────────────────────────────

export interface JwtClaims {
  sub: string;          // account id (uuid)
  email: string;
  provider: 'password' | 'google' | 'anon';
  google_user_id?: string;
  iat: number;
  exp: number;
}

export async function signJwt(env: Env, claims: Omit<JwtClaims, 'iat' | 'exp'>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const payload: JwtClaims = { ...claims, iat: now, exp: now + JWT_TTL_SECONDS };
  const header = b64urlEncode(utf8(JSON.stringify({ alg: 'HS256', typ: 'JWT' })));
  const body = b64urlEncode(utf8(JSON.stringify(payload)));
  const key = await crypto.subtle.importKey('raw', asBuf(utf8(env.JWT_SECRET)), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, asBuf(utf8(`${header}.${body}`))));
  return `${header}.${body}.${b64urlEncode(sig)}`;
}

export async function verifyJwt(env: Env, token: string): Promise<JwtClaims | null> {
  try {
    const [h, b, s] = token.split('.');
    if (!h || !b || !s) return null;
    const key = await crypto.subtle.importKey('raw', asBuf(utf8(env.JWT_SECRET)), { name: 'HMAC', hash: 'SHA-256' }, false, ['verify']);
    const ok = await crypto.subtle.verify('HMAC', key, asBuf(b64urlDecode(s)), asBuf(utf8(`${h}.${b}`)));
    if (!ok) return null;
    const claims = JSON.parse(new TextDecoder().decode(b64urlDecode(b))) as JwtClaims;
    if (claims.exp * 1000 < Date.now()) return null;
    return claims;
  } catch {
    return null;
  }
}

// ── UUID v4 (D1 tidak punya gen_random_uuid) ─────────────────────────

export function uuid(): string {
  return crypto.randomUUID();
}
