// Signs short-lived links to identity documents and reported chat images for
// the admin dashboard.
//
// Admins have no Storage access of their own. This function first calls the
// audited database function *as the caller* (so is_admin() and the second
// factor are enforced and the view is logged), then signs with the service
// role. It has not been run (needs a Supabase project, issue #6).
import { createClient } from 'npm:@supabase/supabase-js@2.119.0';
import { chatImagePaths, corsHeaders, KINDS, parseRequest, safePaths } from './logic.mjs';

const url = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const allowedOrigin = Deno.env.get('ADMIN_ORIGIN') ?? '';

Deno.serve(async (req) => {
  const cors = corsHeaders(req.headers.get('origin'), allowedOrigin);
  const reply = (status: number, body: unknown) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

  if (req.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (req.method !== 'POST') return reply(405, { error: 'method' });
  const auth = req.headers.get('authorization');
  if (!auth) return reply(401, { error: 'auth' });

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return reply(400, { error: 'input' });
  }
  const parsed = parseRequest(body);
  if (!parsed) return reply(400, { error: 'input' });

  // As the caller: the database decides who is an admin and logs the view.
  const caller = createClient(url, anonKey, { global: { headers: { Authorization: auth } } });
  let paths: string[];
  if (parsed.kind === 'verification') {
    const { data, error } = await caller.rpc('admin_verification_documents', { p_request: parsed.id });
    if (error) return reply(error.code === '42501' ? 403 : 400, { error: 'refused' });
    paths = safePaths((data as { path: string }[]).map((r) => r.path));
  } else {
    const { data, error } = await caller.rpc('admin_report_context', { p_report: parsed.id });
    if (error) return reply(error.code === '42501' ? 403 : 400, { error: 'refused' });
    paths = chatImagePaths(data);
  }
  if (paths.length === 0) return reply(200, { urls: [] });

  const { bucket, seconds } = KINDS[parsed.kind];
  const service = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data, error } = await service.storage.from(bucket).createSignedUrls(paths, seconds);
  if (error || !data) return reply(502, { error: 'sign' });
  return reply(200, { urls: data.flatMap((d) => (d.signedUrl ? [d.signedUrl] : [])) });
});
