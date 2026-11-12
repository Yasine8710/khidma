// Pure helpers for the storage-cleanup worker (tested in backend/tests).

/** True when [header] is `Bearer <secret>` for the worker secret. Constant
 * time; an empty or short secret never authorizes. */
export function isAuthorized(header, secret) {
  if (typeof header !== 'string' || typeof secret !== 'string' || secret.length < 16) return false;
  const given = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (given.length !== secret.length) return false;
  let diff = 0;
  for (let i = 0; i < secret.length; i++) diff |= given.charCodeAt(i) ^ secret.charCodeAt(i);
  return diff === 0;
}

/** Buckets this worker may empty. Anything else in the queue is ignored. */
export const BUCKETS = ['portfolio', 'verification-docs', 'request-photos', 'chat-images', 'avatars', 'freelance-media'];

/** Groups queue rows `{id, bucket_id, name}` by bucket, at most [max] rows
 * in total, skipping unknown buckets and empty or path-escaping names.
 * Returns `[{bucket, ids, names}]`. */
export function planBatches(rows, max = 200) {
  const byBucket = new Map();
  let taken = 0;
  for (const r of Array.isArray(rows) ? rows : []) {
    if (taken >= max) break;
    if (!r || !BUCKETS.includes(r.bucket_id)) continue;
    const name = typeof r.name === 'string' ? r.name : '';
    if (name === '' || name.startsWith('/') || name.split('/').includes('..')) continue;
    const b = byBucket.get(r.bucket_id) ?? { bucket: r.bucket_id, ids: [], names: [] };
    b.ids.push(r.id);
    b.names.push(name);
    byBucket.set(r.bucket_id, b);
    taken++;
  }
  return [...byBucket.values()];
}
