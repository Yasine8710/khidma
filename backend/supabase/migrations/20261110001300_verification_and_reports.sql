-- Verification of professionals and reporting of content.
--
-- Verification: a professional sends identity/trade documents (private bucket,
-- readable only by the owner and admins); an admin approves or rejects. Only
-- an approval makes the public "verified" badge appear. Documents are deleted
-- as soon as the decision is made (data minimisation).
--
-- Reports: any registered user can report a professional, a public review or a
-- conversation they are in; admins work the queue. Everything an admin does
-- goes into an audit log nobody but admins can read.

------------------------------------------------------------------------
-- Storage cleanup queue.
--
-- Supabase refuses direct SQL deletes on storage.objects ("use the Storage
-- API"), so database functions never delete files: they queue the names and a
-- server-side worker (service role, issue #32) removes them through the
-- Storage API and then the queue row.
------------------------------------------------------------------------
create table public.storage_cleanup_queue (
  id bigint generated always as identity primary key,
  bucket_id text not null,
  name text not null,
  queued_at timestamptz not null default now(),
  unique (bucket_id, name)
);
alter table public.storage_cleanup_queue enable row level security;
revoke all on table public.storage_cleanup_queue from public, anon, authenticated;
grant select, delete on table public.storage_cleanup_queue to service_role;

create or replace function public._queue_storage_cleanup(p_bucket text, p_names text[])
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.storage_cleanup_queue (bucket_id, name)
  select p_bucket, n from unnest(p_names) as n
  on conflict do nothing
$$;

------------------------------------------------------------------------
-- audit log (admins only)
------------------------------------------------------------------------
create table public.admin_audit_log (
  id bigint generated always as identity primary key,
  admin_id uuid not null,
  action text not null,
  target_type text not null,
  target_id text not null,
  detail text,
  created_at timestamptz not null default now()
);
alter table public.admin_audit_log enable row level security;
revoke all on table public.admin_audit_log from public, anon, authenticated;

create or replace function public._audit(p_action text, p_type text, p_target text, p_detail text default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.admin_audit_log (admin_id, action, target_type, target_id, detail)
  values ((select auth.uid()), p_action, p_type, p_target, left(p_detail, 500))
$$;

-- Admin reads of the log (the dashboard will page through it).
create or replace function public.admin_audit_log_page(p_limit integer default 50, p_offset integer default 0)
returns table (id bigint, admin_id uuid, action text, target_type text, target_id text, detail text, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
  select a.id, a.admin_id, a.action, a.target_type, a.target_id, a.detail, a.created_at
    from public.admin_audit_log a
   order by a.id desc
   limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, least(coalesce(p_offset, 0), 5000));
end;
$$;

-- Moderating a review is audited too.
create or replace function public.admin_set_review_status(p_review uuid, p_status text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_status not in ('published', 'hidden') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  update public.reviews set status = p_status, moderation_note = left(p_note, 500) where id = p_review;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  perform public._audit('review_' || p_status, 'review', p_review::text, p_note);
end;
$$;

------------------------------------------------------------------------
-- suspension: an admin can take a professional off the listings for good
------------------------------------------------------------------------
alter table public.professional_profiles add column suspended boolean not null default false;
-- Owners cannot publish while suspended (is_published is owner-writable).
alter table public.professional_profiles
  add constraint not_published_while_suspended check (not (is_published and suspended));

create or replace function public.admin_set_suspended(p_user uuid, p_suspended boolean, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.professional_profiles
     set suspended = p_suspended,
         is_published = case when p_suspended then false else is_published end
   where user_id = p_user;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  perform public._audit(case when p_suspended then 'suspend' else 'unsuspend' end, 'professional', p_user::text, p_reason);
end;
$$;

------------------------------------------------------------------------
-- verification
------------------------------------------------------------------------
create table public.verification_requests (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles (user_id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid,
  reject_reason text check (reject_reason is null or char_length(reject_reason) between 1 and 300)
);
create unique index verification_one_pending_idx
  on public.verification_requests (professional_id) where status = 'pending';
create index verification_queue_idx on public.verification_requests (status, submitted_at);

create table public.verification_documents (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.verification_requests (id) on delete cascade,
  path text not null unique
    check (path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,100}\.(jpg|jpeg|png|webp|pdf)$')
);

alter table public.verification_requests enable row level security;
alter table public.verification_documents enable row level security;
revoke all on table public.verification_requests, public.verification_documents from public, anon, authenticated;
-- No client reads: the owner uses my_verification(), admins the admin_* functions.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('verification-docs', 'verification-docs', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Volatile on purpose: it takes a per-user lock so two uploads cannot both
-- pass the count, and each statement sees what the other committed.
create or replace function public.my_verification_file_count()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid text := (select auth.uid())::text;
begin
  perform pg_advisory_xact_lock(hashtextextended('verification-files:' || coalesce(uid, ''), 0));
  return (
    select count(*)::integer from storage.objects o
     where o.bucket_id = 'verification-docs'
       and (storage.foldername(o.name))[1] = uid
       and not exists (select 1 from public.storage_cleanup_queue q
                        where q.bucket_id = 'verification-docs' and q.name = o.name)
  );
end;
$$;

create or replace function public.verification_file_unsubmitted(p_name text)
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  select not exists (select 1 from public.verification_documents d where d.path = p_name)
$$;

-- Professionals upload into their own folder (6 files at a time at most);
-- the owner and admins read; the owner may remove a file not yet submitted.
create policy verification_files_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'verification-docs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') <> 'true'
    and exists (select 1 from public.professional_profiles p where p.user_id = (select auth.uid()))
    and (select public.my_verification_file_count()) < 6
  );
-- Only the owner reads through Storage. Admins get links from a server-side
-- signer (service role) that first calls the audited admin_verification_documents,
-- so every look at an identity document leaves a log entry.
create policy verification_files_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'verification-docs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy verification_files_delete_unsubmitted on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'verification-docs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.verification_file_unsubmitted(name))
  );

create or replace function public.submit_verification(p_paths text[])
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  prof public.professional_profiles;
  req uuid;
  p text;
begin
  select * into prof from public.professional_profiles where user_id = uid;
  if not found then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if prof.verification_status = 'verified' then
    raise exception 'already_verified' using errcode = 'P0001';
  end if;
  if p_paths is null or array_ndims(p_paths) is distinct from 1
     or cardinality(p_paths) > 3 or array_position(p_paths, null) is not null then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('verification:' || uid::text, 0));
  if exists (select 1 from public.verification_requests where professional_id = uid and status = 'pending') then
    raise exception 'already_pending' using errcode = 'P0001';
  end if;
  if (select count(*) from public.verification_requests
       where professional_id = uid and submitted_at > now() - interval '30 days') >= 3 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  foreach p in array p_paths loop
    if split_part(p, '/', 1) <> uid::text then
      raise exception 'invalid_input' using errcode = 'P0001';
    end if;
  end loop;
  -- Lock the files so an owner cannot delete one while it is being attached
  -- (a delete that waited re-checks and finds it submitted).
  perform 1 from storage.objects o
   where o.bucket_id = 'verification-docs' and o.name = any (p_paths) for share;
  if (select count(*) from storage.objects o
       where o.bucket_id = 'verification-docs' and o.name = any (p_paths))
     <> (select count(distinct x) from unnest(p_paths) x) then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  insert into public.verification_requests (professional_id) values (uid) returning id into req;
  insert into public.verification_documents (request_id, path)
    select req, x from (select distinct unnest(p_paths) as x) d;
  update public.professional_profiles set verification_status = 'pending' where user_id = uid;
  return req;
end;
$$;

-- Drops a request's documents: the rows go now, the files are queued for the
-- server-side worker (SQL may not delete storage rows).
create or replace function public._discard_verification_documents(p_request uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public._queue_storage_cleanup(
    'verification-docs',
    array(select d.path from public.verification_documents d where d.request_id = p_request));
  delete from public.verification_documents where request_id = p_request;
end;
$$;

create or replace function public.cancel_verification()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  req uuid;
begin
  select id into req from public.verification_requests
   where professional_id = uid and status = 'pending' for update;
  if not found then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  update public.verification_requests set status = 'cancelled', reviewed_at = now() where id = req;
  perform public._discard_verification_documents(req);
  update public.professional_profiles set verification_status = 'unverified'
   where user_id = uid and verification_status = 'pending';
end;
$$;

-- My latest request (status 'none' when there never was one).
create or replace function public.my_verification()
returns table (status text, reject_reason text, submitted_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  return query
  select v.status, v.reject_reason, v.submitted_at
    from public.verification_requests v
   where v.professional_id = uid
   order by v.submitted_at desc
   limit 1;
end;
$$;

create or replace function public.admin_list_verifications(
  p_status text default 'pending', p_limit integer default 50, p_offset integer default 0
)
returns table (id uuid, professional_id uuid, business_name text, submitted_at timestamptz, documents integer, status text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
  select v.id, v.professional_id, p.business_name, v.submitted_at,
         (select count(*)::integer from public.verification_documents d where d.request_id = v.id),
         v.status
    from public.verification_requests v
    join public.professional_profiles p on p.user_id = v.professional_id
   where v.status = p_status
   order by v.submitted_at, v.id
   limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, least(coalesce(p_offset, 0), 5000));
end;
$$;

create or replace function public.admin_verification_documents(p_request uuid)
returns table (path text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  perform public._audit('view_documents', 'verification', p_request::text);
  return query select d.path from public.verification_documents d where d.request_id = p_request order by d.path;
end;
$$;

create or replace function public.admin_review_verification(p_request uuid, p_approve boolean, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  v public.verification_requests;
  reason text := nullif(btrim(p_reason), '');
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select * into v from public.verification_requests where id = p_request for update;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if v.status <> 'pending' then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  if not p_approve and (reason is null or char_length(reason) > 300) then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  update public.verification_requests
     set status = case when p_approve then 'approved' else 'rejected' end,
         reviewed_at = now(), reviewed_by = uid,
         reject_reason = case when p_approve then null else reason end
   where id = p_request;
  perform public.admin_set_verification(v.professional_id, case when p_approve then 'verified' else 'rejected' end);
  perform public._discard_verification_documents(p_request);
  perform public._audit(case when p_approve then 'verification_approved' else 'verification_rejected' end,
                        'professional', v.professional_id::text, reason);
end;
$$;

------------------------------------------------------------------------
-- reports
------------------------------------------------------------------------
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  target_type text not null check (target_type in ('professional', 'review', 'conversation')),
  target_id uuid not null,
  reason text not null check (reason in ('spam', 'fake', 'abuse', 'scam', 'inappropriate', 'other')),
  details text check (details is null or char_length(details) between 1 and 500),
  status text not null default 'open' check (status in ('open', 'reviewing', 'actioned', 'dismissed')),
  handled_by uuid,
  handled_at timestamptz,
  note text check (note is null or char_length(note) <= 500),
  created_at timestamptz not null default now()
);
create unique index reports_one_open_idx
  on public.reports (reporter_id, target_type, target_id) where status in ('open', 'reviewing');
create index reports_queue_idx on public.reports (status, created_at);
alter table public.reports enable row level security;
revoke all on table public.reports from public, anon, authenticated;

create or replace function public.report_content(p_type text, p_target uuid, p_reason text, p_details text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  new_id uuid;
  body text := nullif(btrim(p_details), '');
begin
  if p_type not in ('professional', 'review', 'conversation')
     or p_reason not in ('spam', 'fake', 'abuse', 'scam', 'inappropriate', 'other')
     or (body is not null and char_length(body) > 500) then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  -- What can be reported is what the reporter can legitimately see.
  if p_type = 'professional' then
    if p_target = uid or not exists (
      select 1 from public.professional_profiles p where p.user_id = p_target and p.is_published
    ) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  elsif p_type = 'review' then
    if not exists (
      select 1 from public.reviews r
       where r.id = p_target and r.status = 'published' and r.about_professional and r.author_id <> uid
    ) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  else
    if not public.is_conversation_member(p_target) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('report:' || uid::text, 0));
  if (select count(*) from public.reports where reporter_id = uid and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.reports
              where reporter_id = uid and target_type = p_type and target_id = p_target
                and status in ('open', 'reviewing')) then
    raise exception 'already_reported' using errcode = 'P0001';
  end if;
  insert into public.reports (reporter_id, target_type, target_id, reason, details)
  values (uid, p_type, p_target, p_reason, body)
  returning id into new_id;
  return new_id;
end;
$$;

create or replace function public.admin_list_reports(p_status text default 'open', p_limit integer default 50, p_offset integer default 0)
returns table (id uuid, target_type text, target_id uuid, reason text, details text, status text, created_at timestamptz, reports_on_target integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
  select r.id, r.target_type, r.target_id, r.reason, r.details, r.status, r.created_at,
         (select count(*)::integer from public.reports x where x.target_type = r.target_type and x.target_id = r.target_id)
    from public.reports r
   where r.status = p_status
   order by r.created_at, r.id
   limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, least(coalesce(p_offset, 0), 5000));
end;
$$;

-- What the admin needs to judge a report (reading a conversation is logged).
create or replace function public.admin_report_context(p_report uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r public.reports;
  ctx jsonb;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select * into r from public.reports where id = p_report;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if r.target_type = 'professional' then
    select to_jsonb(x) into ctx from (
      select p.business_name, p.description, p.verification_status, p.is_published, p.suspended, p.rating_avg, p.review_count
        from public.professional_profiles p where p.user_id = r.target_id) x;
  elsif r.target_type = 'review' then
    select to_jsonb(x) into ctx from (
      select v.rating, v.comment, v.status, v.subject_id from public.reviews v where v.id = r.target_id) x;
  else
    select jsonb_build_object('messages', coalesce(jsonb_agg(m order by m.id), '[]'::jsonb)) into ctx
      from (select id, sender_is_customer, body, image_path, created_at
              from public.messages where conversation_id = r.target_id order by id desc limit 50) m;
    perform public._audit('read_conversation', 'report', p_report::text);
  end if;
  return coalesce(ctx, '{}'::jsonb);
end;
$$;

create or replace function public.admin_handle_report(p_report uuid, p_status text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_status not in ('reviewing', 'actioned', 'dismissed') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  update public.reports
     set status = p_status, handled_by = uid, handled_at = now(), note = left(p_note, 500)
   where id = p_report;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  perform public._audit('report_' || p_status, 'report', p_report::text, p_note);
end;
$$;

revoke all on function
  public._queue_storage_cleanup(text, text[]), public.admin_set_verification(uuid, text),
  public._audit(text, text, text, text), public.admin_audit_log_page(integer, integer),
  public.admin_set_review_status(uuid, text, text), public.admin_set_suspended(uuid, boolean, text),
  public.my_verification_file_count(), public.verification_file_unsubmitted(text),
  public.submit_verification(text[]), public._discard_verification_documents(uuid),
  public.cancel_verification(), public.my_verification(),
  public.admin_list_verifications(text, integer, integer), public.admin_verification_documents(uuid),
  public.admin_review_verification(uuid, boolean, text),
  public.report_content(text, uuid, text, text), public.admin_list_reports(text, integer, integer),
  public.admin_report_context(uuid), public.admin_handle_report(uuid, text, text)
  from public, anon, authenticated;
-- (admin_set_verification and the helpers stay internal.)
grant execute on function
  public.admin_audit_log_page(integer, integer), public.admin_set_review_status(uuid, text, text),
  public.admin_set_suspended(uuid, boolean, text),
  public.my_verification_file_count(), public.verification_file_unsubmitted(text),
  public.submit_verification(text[]), public.cancel_verification(), public.my_verification(),
  public.admin_list_verifications(text, integer, integer), public.admin_verification_documents(uuid),
  public.admin_review_verification(uuid, boolean, text),
  public.report_content(text, uuid, text, text), public.admin_list_reports(text, integer, integer),
  public.admin_report_context(uuid), public.admin_handle_report(uuid, text, text)
  to authenticated;

------------------------------------------------------------------------
-- Account deletion: files (including verification documents) are queued.
------------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  update public.quote_requests r set status = 'cancelled'
   where r.status = 'awarded'
     and exists (select 1 from public.bookings b where b.request_id = r.id and b.professional_id = uid);
  -- Files are queued (SQL cannot delete storage rows); the worker removes them.
  insert into public.storage_cleanup_queue (bucket_id, name)
  select o.bucket_id, o.name from storage.objects o
   where (o.bucket_id in ('portfolio', 'request-photos', 'verification-docs')
          and (storage.foldername(o.name))[1] = uid::text)
      or (o.bucket_id = 'chat-images'
          and exists (
            select 1 from public.conversations c
             where c.id::text = (storage.foldername(o.name))[1]
               and uid in (c.customer_id, c.professional_id)))
  on conflict do nothing;
  delete from auth.users where id = uid;
end;
$$;
revoke all on function public.delete_my_account() from public, anon, authenticated;
grant execute on function public.delete_my_account() to authenticated;
