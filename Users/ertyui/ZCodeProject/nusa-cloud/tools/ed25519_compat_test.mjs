// B1 blocker check: Ed25519 sign (noble, same as license-manager) →
// verify (WebCrypto, same as what Cloudflare Workers expose natively).
// App (package:cryptography) verifies with RAW 32-byte public key.
// If WebCrypto can verify a noble-signed message with raw keys →
// worker can drop the noble dependency and use crypto.subtle everywhere.
import * as ed from '@noble/ed25519';
import { sha512 } from '@noble/hashes/sha2.js';
ed.etc.sha512Sync = (...m) => sha512.create().update(ed.etc.concatBytes(...m)).digest();

// Mirror the same hex keys as Supabase secrets (NUSA_PRIVATE_KEY hex 64 chars).
const PRIV_HEX = '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'; // RFC 8032 test key 1
const priv = ed.utils.randomPrivateKey(); // generate fresh to mimic real flow
const pub = await ed.getPublicKey(priv);

function hexToBytes(h) { return Uint8Array.from(h.match(/.{1,2}/g).map(x => parseInt(x, 16))); }
function bytesToHex(b) { return Buffer.from(b).toString('hex'); }

// 1) noble sign (license-manager generateKey flow)
const serial = 'ABCD2345';
const sig = await ed.sign(new TextEncoder().encode(serial), priv);

// 2) WebCrypto verify — import RAW 32-byte public key
const pubRaw = await crypto.subtle.importKey(
  'raw', pub, { name: 'Ed25519' }, false, ['verify'],
);
const okWebCrypto = await crypto.subtle.verify(
  'Ed25519', pubRaw, sig, new TextEncoder().encode(serial),
);
console.log('WebCrypto verifies noble sig (raw pub):', okWebCrypto);

// 3) WebCrypto sign → noble verify (reverse direction: reset-confirm tokens etc.)
const wcPriv = await crypto.subtle.importKey(
  'pkcs8', wrapPkcs8(priv), { name: 'Ed25519' }, false, ['sign'],
);
const sig2 = new Uint8Array(await crypto.subtle.sign('Ed25519', wcPriv, new TextEncoder().encode(serial)));
const okNoble = await ed.verify(sig2, new TextEncoder().encode(serial), pub);
console.log('noble verifies WebCrypto sig:', okNoble);

// 4) Public key hex equality (the value embedded in activation_public_key.dart)
console.log('pub hex:', bytesToHex(pub).slice(0, 16) + '…');

// PKCS8 wrapper for Ed25519 private key (RFC 8410 prefix)
function wrapPkcs8(raw32) {
  const prefix = Uint8Array.from([48, 46, 2, 1, 0, 48, 5, 6, 3, 43, 101, 112, 4, 34, 4, 32]);
  const out = new Uint8Array(prefix.length + 32);
  out.set(prefix, 0);
  out.set(raw32, prefix.length);
  return out;
}
