-- Trust v2 (#54): scam reporting, fast suspension, appeals, badge rules.
--
-- Reports: offers and single messages can be reported too, with two
-- marketplace reasons (asked to pay outside, no-show). Each report records who
-- it is about (subject_id), so the admin queue can sort by how many different
-- people reported the same person. Three or more different reporters within
-- 30 days raise a review flag; nothing is ever suspended automatically.
--
-- Suspension: an admin suspends a professional for N days (or until lifted)
-- with a reason the professional sees. While suspended the profile is hidden
-- (unpublished), new offers, conversations and the professional's messages
-- are refused by triggers, and pending offers are withdrawn. Bookings already
-- in progress stay as they are (the customer can still cancel or talk).
-- A suspended professional can file one appeal at a time.
--
-- Badge: a verification is valid 12 months (verified_until, a Tunis date).
-- Readers only treat a profile as verified while that date has not passed;
-- an admin can also revoke a badge. Document data is never exposed.

------------------------------------------------------------------------
-- notifications: account notices (always delivered, no preference)
------------------------------------------------------------------------
alter table public.notification_outbox drop constraint notification_outbox_category_check;
alter table public.notification_outbox add constraint notification_outbox_category_check
  check (category in ('offers', 'messages', 'jobs', 'account'));
alter table public.notification_outbox drop constraint notification_outbox_kind_check;
alter table public.notification_outbox add constraint notification_outbox_kind_check
  check (kind in (
    'offer_received', 'offer_accepted', 'message',
    'job_started', 'job_done', 'job_completed', 'job_cancelled',
    'report_actioned', 'report_dismissed', 'account_suspended', 'account_restored',
    'appeal_rejected', 'verification_expired'
  ));

create or replace function public._enqueue_notification(
  p_user uuid, p_category text, p_kind text, p_dedup text, p_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  wanted boolean;
begin
  select case p_category
           when 'account' then true
           when 'offers' then coalesce(p.offers, true)
           when 'messages' then coalesce(p.messages, true)
           else coalesce(p.jobs, true)
         end
    into wanted
    from (select 1) one
    left join public.notification_preferences p on p.user_id = p_user;
  if not wanted then
    return;
  end if;
  insert into public.notification_outbox (user_id, category, kind, dedup_key, payload)
  values (p_user, p_category, p_kind, p_dedup, coalesce(p_payload, '{}'::jsonb))
  on conflict (dedup_key) do nothing;
end;
$$;

------------------------------------------------------------------------
-- badge: validity and revocation
------------------------------------------------------------------------
alter table public.professional_profiles
  drop constraint professional_profiles_verification_status_check;
alter table public.professional_profiles
  add constraint professional_profiles_verification_status_check
  check (verification_status in ('unverified', 'pending', 'verified', 'rejected', 'revoked'));
alter table public.professional_profiles add column verified_until date;
update public.professional_profiles
   set verified_until = ((verified_at at time zone 'Africa/Tunis')::date + 365)
 where verification_status = 'verified';
alter table public.professional_profiles
  add constraint verified_until_matches_status
  check ((verification_status = 'verified') = (verified_until is not null));
-- The month a badge stays valid is public, the exact approval time is not.
grant select (verified_until) on public.professional_profiles to anon, authenticated;

-- Today in Tunisia (badges and suspensions are read as local dates).
create or replace function public.tunis_today()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Africa/Tunis')::date
$$;

-- True only for a verified badge whose validity has not run out.
create or replace function public.badge_valid(p_status text, p_until date)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_status = 'verified' and p_until is not null and p_until >= public.tunis_today()
$$;

-- Keeps verified_until in step with the status, whatever path changed it
-- (admin approval, identity-change reset, revocation). Named to run last.
create or replace function public.sync_verified_until()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.verification_status = 'verified' then
    if tg_op = 'INSERT' or old.verification_status is distinct from 'verified' or new.verified_until is null then
      new.verified_until := public.tunis_today() + 365;
    end if;
  else
    new.verified_until := null;
    new.verified_at := null;
  end if;
  return new;
end;
$$;
create trigger professional_profiles_zz_sync_verified_until
  before insert or update on public.professional_profiles
  for each row execute function public.sync_verified_until();

create or replace function public.admin_revoke_verification(p_user uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  reason text := nullif(btrim(p_reason), '');
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if reason is null or char_length(reason) > 300 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  update public.professional_profiles
     set verification_status = 'revoked', verified_at = null
   where user_id = p_user and verification_status = 'verified';
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  perform public._audit('verification_revoked', 'professional', p_user::text, reason);
end;
$$;

-- Daily job (service role): expired badges go back to unverified.
create or replace function public.service_expire_verifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer := 0;
  p record;
begin
  for p in
    update public.professional_profiles
       set verification_status = 'unverified', verified_at = null
     where verification_status = 'verified' and verified_until < public.tunis_today()
    returning user_id
  loop
    n := n + 1;
    perform public._enqueue_notification(p.user_id, 'account', 'verification_expired',
      'verification_expired:' || p.user_id::text || ':' || public.tunis_today()::text, '{}'::jsonb);
  end loop;
  return n;
end;
$$;

-- Freelance listings need a valid badge, not just the status.
create or replace function public.freelancer_is_visible(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.freelancer_profiles f
      join public.professional_profiles p on p.user_id = f.user_id
     where f.user_id = p_user and f.is_published
       and public.badge_valid(p.verification_status, p.verified_until) and not p.suspended
  )
$$;

------------------------------------------------------------------------
-- suspension
------------------------------------------------------------------------
alter table public.professional_profiles
  add column suspended_until timestamptz,
  add column suspension_reason text check (suspension_reason is null or char_length(suspension_reason) <= 300);
alter table public.professional_profiles
  add constraint suspension_fields_need_suspended
  check (suspended or (suspended_until is null and suspension_reason is null));

create or replace function public._suspension_active(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.professional_profiles p
     where p.user_id = p_user and p.suspended
       and (p.suspended_until is null or p.suspended_until > now())
  )
$$;

-- Lifts one suspension and tells the professional (does not republish).
create or replace function public._lift_suspension(p_user uuid, p_audit text, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.professional_profiles
     set suspended = false, suspended_until = null, suspension_reason = null
   where user_id = p_user and suspended;
  if found then
    update public.suspension_appeals set status = 'lifted', decided_at = now()
     where professional_id = p_user and status = 'open';
    -- The audit log records admin actions; a suspension running out is not one.
    if public.is_admin() then
      perform public._audit(p_audit, 'professional', p_user::text, p_note);
    end if;
    perform public._enqueue_notification(p_user, 'account', 'account_restored',
      'account_restored:' || p_user::text || ':' || extract(epoch from now())::bigint::text, '{}'::jsonb);
  end if;
end;
$$;

create table public.suspension_appeals (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles (user_id) on delete cascade,
  message text not null check (char_length(message) between 10 and 1000),
  status text not null default 'open' check (status in ('open', 'rejected', 'lifted')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid,
  decision_note text check (decision_note is null or char_length(decision_note) <= 300)
);
create unique index suspension_appeals_one_open_idx
  on public.suspension_appeals (professional_id) where status = 'open';
alter table public.suspension_appeals enable row level security;
revoke all on table public.suspension_appeals from public, anon, authenticated;

-- Admin: suspend for p_days (1-365) or until lifted (null). Withdraws pending
-- offers. When called from a report, every open report on the same person is
-- closed as actioned and their reporters are told (without details).
create or replace function public.admin_suspend(
  p_user uuid, p_days integer, p_reason text, p_report uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  reason text := nullif(btrim(p_reason), '');
  rep public.reports;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if reason is null or char_length(reason) > 300
     or (p_days is not null and (p_days < 1 or p_days > 365)) then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  if p_user = uid then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_report is not null then
    select * into rep from public.reports where id = p_report;
    if not found or rep.subject_id is distinct from p_user then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  end if;
  update public.professional_profiles
     set suspended = true, is_published = false,
         suspended_until = case when p_days is null then null else now() + make_interval(days => p_days) end,
         suspension_reason = reason
   where user_id = p_user;
  if not found then
    raise exception 'not_professional' using errcode = 'P0001';
  end if;
  update public.freelancer_profiles set is_published = false where user_id = p_user;
  update public.quote_offers set status = 'withdrawn' where professional_id = p_user and status = 'pending';
  perform public._audit('suspend', 'professional', p_user::text,
    reason || coalesce(' (' || p_days::text || ' days)', ' (until lifted)'));
  perform public._enqueue_notification(p_user, 'account', 'account_suspended',
    'account_suspended:' || p_user::text || ':' || extract(epoch from now())::bigint::text, '{}'::jsonb);
  if p_report is not null then
    perform public._close_reports_on_subject(p_user, 'actioned', reason);
  end if;
end;
$$;

-- Kept for the admin panel's existing toggle: true = until lifted.
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
  if p_suspended then
    perform public.admin_suspend(p_user, null, coalesce(nullif(btrim(p_reason), ''), 'Suspended by an admin'));
  else
    if not exists (select 1 from public.professional_profiles where user_id = p_user) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
    perform public._lift_suspension(p_user, 'unsuspend', p_reason);
  end if;
end;
$$;

-- Service role (daily job): lifts suspensions whose time ran out.
create or replace function public.service_lift_expired_suspensions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer := 0;
  p record;
begin
  for p in
    select user_id from public.professional_profiles
     where suspended and suspended_until is not null and suspended_until <= now()
  loop
    perform public._lift_suspension(p.user_id, 'suspension_expired', null);
    n := n + 1;
  end loop;
  return n;
end;
$$;

-- The caller's own account state: suspension and the latest appeal.
-- Lifts the caller's suspension right away when its time has run out.
create or replace function public.my_account_status()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  p public.professional_profiles;
  a public.suspension_appeals;
begin
  select * into p from public.professional_profiles where user_id = uid;
  if found and p.suspended and p.suspended_until is not null and p.suspended_until <= now() then
    perform public._lift_suspension(uid, 'suspension_expired', null);
    select * into p from public.professional_profiles where user_id = uid;
  end if;
  select * into a from public.suspension_appeals
   where professional_id = uid order by created_at desc limit 1;
  return jsonb_build_object(
    'suspended', coalesce(p.suspended, false),
    'suspended_until', p.suspended_until,
    'reason', p.suspension_reason,
    'appeal_status', a.status,
    'appeal_note', a.decision_note,
    'appeal_at', a.created_at
  );
end;
$$;

create or replace function public.submit_appeal(p_message text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  body text := nullif(btrim(p_message), '');
  new_id uuid;
begin
  if body is null or char_length(body) < 10 or char_length(body) > 1000 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  if not public._suspension_active(uid) then
    raise exception 'not_suspended' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('appeal:' || uid::text, 0));
  if exists (select 1 from public.suspension_appeals where professional_id = uid and status = 'open') then
    raise exception 'already_pending' using errcode = 'P0001';
  end if;
  -- After a rejection, wait a week before appealing again.
  if exists (select 1 from public.suspension_appeals
              where professional_id = uid and status = 'rejected' and decided_at > now() - interval '7 days') then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  insert into public.suspension_appeals (professional_id, message)
  values (uid, body) returning id into new_id;
  return new_id;
end;
$$;

create or replace function public.admin_list_appeals(p_status text default 'open', p_limit integer default 50, p_offset integer default 0)
returns table (
  id uuid, professional_id uuid, business_name text, message text, status text,
  created_at timestamptz, suspended_until timestamptz, suspension_reason text, decision_note text
)
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
  select a.id, a.professional_id, p.business_name, a.message, a.status, a.created_at,
         p.suspended_until, p.suspension_reason, a.decision_note
    from public.suspension_appeals a
    join public.professional_profiles p on p.user_id = a.professional_id
   where a.status = p_status
   order by a.created_at, a.id
   limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

create or replace function public.admin_decide_appeal(p_appeal uuid, p_lift boolean, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  a public.suspension_appeals;
  note text := nullif(btrim(p_note), '');
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if note is not null and char_length(note) > 300 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  select * into a from public.suspension_appeals where id = p_appeal for update;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if a.status <> 'open' then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  update public.suspension_appeals
     set status = case when p_lift then 'lifted' else 'rejected' end,
         decided_at = now(), decided_by = uid, decision_note = note
   where id = p_appeal;
  if p_lift then
    perform public._lift_suspension(a.professional_id, 'appeal_lifted', note);
  else
    perform public._audit('appeal_rejected', 'professional', a.professional_id::text, note);
    perform public._enqueue_notification(a.professional_id, 'account', 'appeal_rejected',
      'appeal_rejected:' || p_appeal::text, '{}'::jsonb);
  end if;
end;
$$;

-- Enforcement in the tables themselves, whatever function writes the row.
create or replace function public.block_suspended_professional()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  pro uuid;
begin
  if tg_table_name = 'messages' then
    if new.sender_is_customer then
      return new;
    end if;
    select c.professional_id into pro from public.conversations c where c.id = new.conversation_id;
  else
    pro := new.professional_id;
  end if;
  if public._suspension_active(pro) then
    raise exception 'suspended' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger quote_offers_block_suspended
  before insert on public.quote_offers
  for each row execute function public.block_suspended_professional();
create trigger conversations_block_suspended
  before insert on public.conversations
  for each row execute function public.block_suspended_professional();
create trigger messages_block_suspended
  before insert on public.messages
  for each row execute function public.block_suspended_professional();

------------------------------------------------------------------------
-- reports: offers, messages, subject, review flag
------------------------------------------------------------------------
alter table public.reports drop constraint reports_target_type_check;
alter table public.reports add constraint reports_target_type_check
  check (target_type in ('professional', 'review', 'conversation', 'freelancer', 'testimonial', 'offer', 'message'));
alter table public.reports drop constraint reports_reason_check;
alter table public.reports add constraint reports_reason_check
  check (reason in ('spam', 'fake', 'abuse', 'scam', 'inappropriate', 'other', 'pay_outside', 'no_show'));
-- A reported message: target_id is its conversation, message_id the message.
alter table public.reports add column message_id bigint;
alter table public.reports add constraint reports_message_ref
  check ((target_type = 'message') = (message_id is not null));
-- Who the report is about (null when unknown, e.g. a testimonial author).
alter table public.reports
  add column subject_id uuid references public.profiles (id) on delete set null;
create index reports_subject_idx on public.reports (subject_id, created_at);
drop index public.reports_one_open_idx;
create unique index reports_one_open_idx
  on public.reports (reporter_id, target_type, target_id, coalesce(message_id, 0))
  where status in ('open', 'reviewing');

update public.reports r set subject_id = r.target_id
 where r.target_type in ('professional', 'freelancer')
   and exists (select 1 from public.profiles p where p.id = r.target_id);
update public.reports r set subject_id = v.author_id
  from public.reviews v where r.target_type = 'review' and v.id = r.target_id;
update public.reports r
   set subject_id = case when r.reporter_id = c.customer_id then c.professional_id else c.customer_id end
  from public.conversations c where r.target_type = 'conversation' and c.id = r.target_id;

-- Shared by report_content and report_message: limits, then the row.
create or replace function public._file_report(
  p_reporter uuid, p_type text, p_target uuid, p_message bigint, p_subject uuid,
  p_reason text, p_details text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_id uuid;
  body text := nullif(btrim(p_details), '');
begin
  if p_reason not in ('spam', 'fake', 'abuse', 'scam', 'inappropriate', 'other', 'pay_outside', 'no_show')
     or (body is not null and char_length(body) > 500) then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('report:' || p_reporter::text, 0));
  if (select count(*) from public.reports where reporter_id = p_reporter and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  -- One person cannot pile reports on the same person (weaponised reporting).
  if p_subject is not null and (
       select count(*) from public.reports
        where reporter_id = p_reporter and subject_id = p_subject
          and created_at > now() - interval '30 days') >= 3 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.reports
              where reporter_id = p_reporter and target_type = p_type and target_id = p_target
                and coalesce(message_id, 0) = coalesce(p_message, 0)
                and status in ('open', 'reviewing')) then
    raise exception 'already_reported' using errcode = 'P0001';
  end if;
  insert into public.reports (reporter_id, target_type, target_id, message_id, subject_id, reason, details)
  values (p_reporter, p_type, p_target, p_message, p_subject, p_reason, body)
  returning id into new_id;
  return new_id;
end;
$$;

create or replace function public.report_content(p_type text, p_target uuid, p_reason text, p_details text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  subject uuid;
begin
  if p_type not in ('professional', 'review', 'conversation', 'freelancer', 'testimonial', 'offer') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  -- What can be reported is what the reporter can legitimately see.
  if p_type = 'professional' then
    if p_target = uid or not exists (
      select 1 from public.professional_profiles p where p.user_id = p_target and p.is_published
    ) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
    subject := p_target;
  elsif p_type = 'freelancer' then
    if p_target = uid or not public.freelancer_is_visible(p_target) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
    subject := p_target;
  elsif p_type = 'testimonial' then
    if not exists (
      select 1 from public.testimonials t
       where t.id = p_target and t.status = 'published'
         and public.freelancer_is_visible(t.freelancer_id) and t.freelancer_id <> uid
    ) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  elsif p_type = 'review' then
    select r.author_id into subject from public.reviews r
     where r.id = p_target and r.status = 'published' and r.about_professional and r.author_id <> uid;
    if not found then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  elsif p_type = 'offer' then
    -- Only the customer who received the offer can report it.
    select o.professional_id into subject
      from public.quote_offers o join public.quote_requests q on q.id = o.request_id
     where o.id = p_target and q.customer_id = uid;
    if not found then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  else
    select case when uid = c.customer_id then c.professional_id else c.customer_id end into subject
      from public.conversations c
     where c.id = p_target and uid in (c.customer_id, c.professional_id);
    if not found then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  end if;
  return public._file_report(uid, p_type, p_target, null, subject, p_reason, p_details);
end;
$$;

-- One message, by a member of its conversation who did not write it.
create or replace function public.report_message(p_message bigint, p_reason text, p_details text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  conv uuid;
  subject uuid;
begin
  select m.conversation_id,
         case when m.sender_is_customer then c.customer_id else c.professional_id end
    into conv, subject
    from public.messages m join public.conversations c on c.id = m.conversation_id
   where m.id = p_message and uid in (c.customer_id, c.professional_id);
  if not found or subject = uid then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  return public._file_report(uid, 'message', conv, p_message, subject, p_reason, p_details);
end;
$$;

-- Closes every open report on one person and tells each reporter the outcome.
create or replace function public._close_reports_on_subject(p_subject uuid, p_status text, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  r record;
begin
  for r in
    update public.reports
       set status = p_status, handled_by = uid, handled_at = now(), note = left(p_note, 500)
     where subject_id = p_subject and status in ('open', 'reviewing')
    returning id, reporter_id
  loop
    perform public._audit('report_' || p_status, 'report', r.id::text, p_note);
    perform public._enqueue_notification(r.reporter_id, 'account',
      case when p_status = 'actioned' then 'report_actioned' else 'report_dismissed' end,
      'report_outcome:' || r.id::text, '{}'::jsonb);
  end loop;
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
  reporter uuid;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_status not in ('reviewing', 'actioned', 'dismissed') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  update public.reports
     set status = p_status, handled_by = uid, handled_at = now(), note = left(p_note, 500)
   where id = p_report
  returning reporter_id into reporter;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  perform public._audit('report_' || p_status, 'report', p_report::text, p_note);
  -- The reporter learns the outcome, never the note or what was done.
  if p_status in ('actioned', 'dismissed') then
    perform public._enqueue_notification(reporter, 'account',
      case when p_status = 'actioned' then 'report_actioned' else 'report_dismissed' end,
      'report_outcome:' || p_report::text, '{}'::jsonb);
  end if;
end;
$$;

-- Queue: flagged people first (3+ different reporters in 30 days), then by
-- how many different people reported them, then oldest first.
drop function public.admin_list_reports(text, integer, integer);
create function public.admin_list_reports(p_status text default 'open', p_limit integer default 50, p_offset integer default 0)
returns table (
  id uuid, target_type text, target_id uuid, message_id bigint, subject_id uuid,
  reason text, details text, status text, created_at timestamptz,
  reports_on_target integer, subject_reporters_30d integer, flagged boolean,
  subject_is_professional boolean, subject_suspended boolean
)
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
  with q as (
    select r.*,
           (select count(*)::integer from public.reports x
             where x.target_type = r.target_type and x.target_id = r.target_id) as on_target,
           case when r.subject_id is null then 0 else
             (select count(distinct x.reporter_id)::integer from public.reports x
               where x.subject_id = r.subject_id and x.created_at > now() - interval '30 days') end as reporters
      from public.reports r
     where r.status = p_status
  )
  select q.id, q.target_type, q.target_id, q.message_id, q.subject_id,
         q.reason, q.details, q.status, q.created_at,
         q.on_target, q.reporters, q.reporters >= 3,
         p.user_id is not null, coalesce(p.suspended, false)
    from q left join public.professional_profiles p on p.user_id = q.subject_id
   order by (q.reporters >= 3) desc, q.reporters desc, q.created_at, q.id
   limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

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
  elsif r.target_type = 'freelancer' then
    select to_jsonb(x) into ctx from (
      select f.display_name, f.headline, f.bio, f.is_published, p.verification_status, p.suspended, f.rating_avg, f.review_count
        from public.freelancer_profiles f join public.professional_profiles p on p.user_id = f.user_id
       where f.user_id = r.target_id) x;
  elsif r.target_type = 'testimonial' then
    select to_jsonb(x) into ctx from (
      select t.author_name, t.rating, t.body, t.status, t.freelancer_id from public.testimonials t where t.id = r.target_id) x;
  elsif r.target_type = 'review' then
    select to_jsonb(x) into ctx from (
      select v.rating, v.comment, v.status, v.subject_id from public.reviews v where v.id = r.target_id) x;
  elsif r.target_type = 'offer' then
    select to_jsonb(x) into ctx from (
      select o.price_tnd, o.message, o.status, o.created_at, p.business_name
        from public.quote_offers o join public.professional_profiles p on p.user_id = o.professional_id
       where o.id = r.target_id) x;
  else
    -- conversation or one message: the last 50 messages (the reported one
    -- is flagged); reading them is logged.
    select jsonb_build_object('reported_message_id', r.message_id,
                              'messages', coalesce(jsonb_agg(m order by m.id), '[]'::jsonb)) into ctx
      from (select id, sender_is_customer, body, image_path, created_at
              from public.messages where conversation_id = r.target_id
               and (r.message_id is null or id <= r.message_id + 10)
             order by id desc limit 50) m;
    perform public._audit('read_conversation', 'report', p_report::text);
  end if;
  return coalesce(ctx, '{}'::jsonb);
end;
$$;

------------------------------------------------------------------------
-- search: same as 0400, but an expired badge is reported as unverified
------------------------------------------------------------------------
create or replace function public.search_professionals(
  p_query text default null,
  p_category smallint default null,
  p_governorate smallint default null,
  p_city integer default null,
  p_min_rating numeric default null,
  p_available_only boolean default false,
  p_lat double precision default null,
  p_lng double precision default null,
  p_radius_km double precision default null,
  p_sort text default 'rating',
  p_limit integer default 20,
  p_offset integer default 0
)
returns table (
  user_id uuid,
  business_name text,
  primary_category_id smallint,
  description text,
  years_experience smallint,
  governorate_id smallint,
  city_id integer,
  neighborhood_id integer,
  latitude double precision,
  longitude double precision,
  availability text,
  verification_status text,
  rating_avg numeric,
  review_count integer,
  distance_km double precision
)
language sql
stable
security invoker
set search_path = ''
as $$
  with params as (
    select
      -- whitespace collapsed, query capped at 100 characters (anonymous callers)
      nullif(btrim(regexp_replace(public.search_normalize(left(p_query, 100)), '\s+', ' ', 'g')), '') as q,
      case when p_sort in ('rating', 'reviews', 'nearest') then p_sort else 'rating' end as sort,
      greatest(1, least(coalesce(p_limit, 20), 50)) as lim,
      greatest(0, least(coalesce(p_offset, 0), 5000)) as off,
      -- a city given together with a governorate must belong to it
      case
        when p_city is not null and p_governorate is not null
         and not exists (select 1 from public.cities c
                          where c.id = p_city and c.governorate_id = p_governorate)
        then false else true
      end as place_ok,
      (select c.governorate_id from public.cities c where c.id = p_city) as city_governorate
  ),
  base as (
    select
      p.user_id, p.business_name, p.primary_category_id, p.description,
      p.years_experience, p.governorate_id, p.city_id, p.neighborhood_id,
      p.latitude, p.longitude, p.availability,
      -- an expired badge reads as unverified
      case when p.verification_status = 'verified' and not public.badge_valid(p.verification_status, p.verified_until)
           then 'unverified' else p.verification_status end as verification_status,
      p.rating_avg, p.review_count,
      case
        when p_lat is not null and p_lng is not null
         and p.latitude is not null and p.longitude is not null
        then 6371 * 2 * asin(least(1, sqrt(
          power(sin(radians(p.latitude - p_lat) / 2), 2)
          + cos(radians(p_lat)) * cos(radians(p.latitude))
          * power(sin(radians(p.longitude - p_lng) / 2), 2)
        )))
      end as distance_km
    from public.professional_profiles p, params
    where p.is_published
      and params.place_ok
      and (p_available_only is not true or p.availability = 'available')
      and (p_min_rating is null or p.rating_avg >= p_min_rating)
      and (p_category is null
           or p.primary_category_id = p_category
           or exists (select 1 from public.professional_services s
                       where s.professional_id = p.user_id and s.category_id = p_category))
      -- Where they work: one coverage place must satisfy the requested place.
      -- A city request is met by being based in that city, by serving that city,
      -- or by serving its whole governorate (a service area without a city).
      and (case
             when p_city is not null then
               p.city_id = p_city
               or exists (select 1 from public.service_areas a
                           where a.professional_id = p.user_id
                             and (a.city_id = p_city
                                  or (a.city_id is null and a.governorate_id = params.city_governorate)))
             when p_governorate is not null then
               p.governorate_id = p_governorate
               or exists (select 1 from public.service_areas a
                           where a.professional_id = p.user_id and a.governorate_id = p_governorate)
             else true
           end)
  )
  select b.user_id, b.business_name, b.primary_category_id, b.description,
         b.years_experience, b.governorate_id, b.city_id, b.neighborhood_id,
         b.latitude, b.longitude, b.availability, b.verification_status,
         b.rating_avg, b.review_count, b.distance_km
  from base b, params
  where
    -- text: name, description, profession and place names (all 3 languages),
    -- each field matched on its own
    (params.q is null or
      public.search_normalize(b.business_name) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
      or public.search_normalize(b.description) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
      or exists (
        select 1 from public.service_categories c
         where (c.id = b.primary_category_id
                or exists (select 1 from public.professional_services s
                            where s.professional_id = b.user_id and s.category_id = c.id))
           and (public.search_normalize(c.name_fr) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
             or public.search_normalize(c.name_ar) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
             or public.search_normalize(c.name_en) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
             or public.search_normalize(c.slug) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'))
      or exists (
        select 1 from public.governorates g
         where g.id = b.governorate_id
           and (public.search_normalize(g.name_fr) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
             or public.search_normalize(g.name_ar) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
             or public.search_normalize(g.name_en) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'))
      or exists (
        select 1 from public.cities c
         where c.id = b.city_id
           and (public.search_normalize(c.name_fr) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
             or public.search_normalize(c.name_ar) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
             or public.search_normalize(c.name_en) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'))
      or exists (
        select 1 from public.neighborhoods n
         where n.id = b.neighborhood_id
           and (public.search_normalize(n.name_fr) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
             or public.search_normalize(n.name_ar) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
             or public.search_normalize(n.name_en) like '%' || replace(replace(replace(params.q, '\', '\\'), '%', '\%'), '_', '\_') || '%')))
    -- radius only applies when a position and a radius were both given
    and (p_radius_km is null or p_lat is null or p_lng is null
         or (b.distance_km is not null and b.distance_km <= p_radius_km))
  order by
    case when params.sort = 'nearest' then b.distance_km end asc nulls last,
    case when params.sort = 'reviews' then b.review_count end desc,
    b.rating_avg desc,
    b.review_count desc,
    b.user_id
  limit (select lim from params) offset (select off from params);
$$;

------------------------------------------------------------------------
-- verification: an expired badge can be renewed (same as 1300 otherwise)
------------------------------------------------------------------------
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
  -- an expired badge can be renewed even before the daily job resets it
  if public.badge_valid(prof.verification_status, prof.verified_until) then
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

------------------------------------------------------------------------
-- privileges
------------------------------------------------------------------------
revoke all on function
  public.tunis_today(), public.badge_valid(text, date), public.sync_verified_until(),
  public.admin_revoke_verification(uuid, text), public.service_expire_verifications(),
  public._suspension_active(uuid), public._lift_suspension(uuid, text, text),
  public.admin_suspend(uuid, integer, text, uuid), public.service_lift_expired_suspensions(),
  public.my_account_status(), public.submit_appeal(text),
  public.admin_list_appeals(text, integer, integer), public.admin_decide_appeal(uuid, boolean, text),
  public.block_suspended_professional(),
  public._file_report(uuid, text, uuid, bigint, uuid, text, text),
  public.report_message(bigint, text, text), public._close_reports_on_subject(uuid, text, text),
  public.admin_list_reports(text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.tunis_today(), public.badge_valid(text, date) to anon, authenticated;
grant execute on function
  public.admin_revoke_verification(uuid, text), public.admin_suspend(uuid, integer, text, uuid),
  public.my_account_status(), public.submit_appeal(text),
  public.admin_list_appeals(text, integer, integer), public.admin_decide_appeal(uuid, boolean, text),
  public.report_message(bigint, text, text), public.admin_list_reports(text, integer, integer)
  to authenticated;
grant execute on function
  public.service_expire_verifications(), public.service_lift_expired_suspensions()
  to service_role;

-- Daily jobs, when pg_cron is enabled on the project (Database > Extensions).
-- Without it, call both service_* functions from any daily scheduler.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('khidma-expire-verifications', '15 2 * * *', 'select public.service_expire_verifications()');
    perform cron.schedule('khidma-lift-suspensions', '*/15 * * * *', 'select public.service_lift_expired_suspensions()');
  end if;
end;
$$;
