/**
 * NUSA Cloud — Cloudflare Worker entry.
 * Route map:
 *   POST /api/{fn}/{action}   — port 1:1 edge fn Supabase (payload JSON identik)
 *   POST /api/auth/{action}   — custom auth (login/signup/anon/reset-*)
 *   GET  /img/{path...}       — R2 nusa-images public (cache 1h)
 *   GET  /ws?channel=X        — WebSocket upgrade ke RoomDO
 *   cron → scheduled()       — license-cron + sheets-archive-cron
 *
 * Identitas: Authorization Bearer JWT (akun email) ATAU field googleUserId
 * di body (Google Sign-In native — trust model sama seperti edge fn lama).
 */
import { Router } from './router';
import { RoomDO } from './room';
// Registrasi route fn saat startup (bukan dinamis — cold start deterministik).
import './fn';

export { RoomDO };

export interface Env {
  DB: D1Database;
  BUCKET_BACKUPS: R2Bucket;
  BUCKET_IMAGES: R2Bucket;
  BUCKET_THUMBS: R2Bucket;
  ROOM: DurableObjectNamespace;
  NUSA_ADMIN_KEY: string;
  NUSA_CRON_KEY: string;
  NUSA_PRIVATE_KEY: string;
  NUSA_PUBLIC_KEY: string;
  JWT_SECRET: string;
  MIDTRANS_SERVER_KEY: string;
  MIDTRANS_CLIENT_KEY: string;
  INSTANPAY_API_KEY: string;
  OPENROUTER_API_KEY: string;
  RESEND_API_KEY: string;
  RESEND_FROM_EMAIL: string;
  GOOGLE_OAUTH_CLIENT_ID: string;
  GOOGLE_OAUTH_CLIENT_SECRET: string;
}

export default {
  fetch(req: Request, env: Env, ctx: ExecutionContext) {
    return Router.handle(req, env, ctx);
  },

  async scheduled(_ctrl: ScheduledController, env: Env, _ctx: ExecutionContext) {
    const { runCrons } = await import('./cron');
    await runCrons(env);
  },
};
