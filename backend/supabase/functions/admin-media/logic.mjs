// Pure helpers of the admin-media Edge Function (tested without Deno).

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PATH = /^[0-9a-f-]{36}\/[A-Za-z0-9._-]{1,100}\.(jpg|jpeg|png|webp|pdf)$/;

/** What the signer may be asked for: verification documents of one request or
 * the images of one reported conversation. Anything else is refused. */
export function parseRequest(body) {
  if (!body || typeof body !== 'object') return null;
  const { kind, id } = body;
  if ((kind !== 'verification' && kind !== 'chat') || typeof id !== 'string' || !UUID.test(id)) return null;
  return { kind, id };
}

/** Bucket and signed-link lifetime (seconds) for each kind. Short on purpose. */
export const KINDS = {
  verification: { bucket: 'verification-docs', seconds: 120 },
  chat: { bucket: 'chat-images', seconds: 120 },
};

/** Image paths out of a conversation report context, in message order. */
export function chatImagePaths(context) {
  const messages = context && Array.isArray(context.messages) ? context.messages : [];
  const out = [];
  for (const m of messages) {
    const p = m && typeof m.image_path === 'string' ? m.image_path : null;
    if (p && PATH.test(p) && !out.includes(p)) out.push(p);
  }
  return out;
}

/** Only well-formed storage paths are ever signed: the database answer is not
 * trusted blindly (a path with `..` is dropped). */
export function safePaths(paths) {
  return (Array.isArray(paths) ? paths : []).filter((p) => typeof p === 'string' && PATH.test(p));
}

/** CORS for the one configured admin origin; others get no allow header. */
export function corsHeaders(origin, allowed) {
  const base = {
    Vary: 'Origin',
    'Access-Control-Allow-Headers': 'authorization, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
  return origin && allowed && origin === allowed ? { ...base, 'Access-Control-Allow-Origin': origin } : base;
}
