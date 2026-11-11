// Empties storage_cleanup_queue (Supabase Edge Function).
//
// SQL cannot delete from storage.objects, so account deletion, request
// cancellation and verification decisions queue file names instead. This
// worker removes the files through the Storage API, then the queue rows.
// Run it on a schedule (Dashboard > Integrations > Cron, or pg_cron + pg_net),
// sending `Authorization: Bearer <CLEANUP_SECRET>`.
//
// Secrets (never in the repo):
//   CLEANUP_SECRET  long random string (16+ characters)
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (provided by Supabase)
//
// A bucket that fails keeps its queue rows and is retried next run. Files that
// are already gone count as done.
import { createClient } from 'jsr:@supabase/supabase-js@2';
import { isAuthorized, planBatches } from './logic.mjs';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false } },
);

Deno.serve(async (req) => {
  if (!isAuthorized(req.headers.get('authorization'), Deno.env.get('CLEANUP_SECRET') ?? '')) {
    return new Response('forbidden', { status: 403 });
  }
  const { data: rows, error } = await supabase
    .from('storage_cleanup_queue')
    .select('id, bucket_id, name')
    .order('id', { ascending: true })
    .limit(200);
  if (error) return new Response('queue', { status: 500 });

  let removed = 0;
  let failed = 0;
  for (const { bucket, ids, names } of planBatches(rows)) {
    const { error: rmError } = await supabase.storage.from(bucket).remove(names);
    if (rmError) {
      failed += ids.length;
      continue;
    }
    const { error: delError } = await supabase.from('storage_cleanup_queue').delete().in('id', ids);
    if (delError) failed += ids.length;
    else removed += ids.length;
  }
  return new Response(JSON.stringify({ removed, failed }), {
    headers: { 'content-type': 'application/json' },
  });
});
