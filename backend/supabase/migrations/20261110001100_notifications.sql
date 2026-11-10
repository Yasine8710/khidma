-- Push notifications through a transactional outbox.
--
-- Events (a new offer, a message, a job step) write a row to
-- `notification_outbox` in the SAME transaction as the event, so a
-- notification exists if and only if the event does. A separate worker (an
-- Edge Function holding the FCM credentials, running as the service role)
-- claims rows, sends them and reports back; it can crash and retry without
-- losing or duplicating anything (dedup keys, attempt counter, lease).
--
-- Privacy: a row holds only the kind and ids, never text. Push text is built
-- from the kind in the recipient's language; message bodies never leave the
-- database through a notification.

create table public.notification_preferences (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  offers boolean not null default true,
  messages boolean not null default true,
  jobs boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  token text not null unique check (char_length(token) between 20 and 4096),
  platform text not null check (platform in ('ios', 'android')),
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);
create index device_tokens_user_idx on public.device_tokens (user_id);

create table public.notification_outbox (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  category text not null check (category in ('offers', 'messages', 'jobs')),
  kind text not null check (kind in (
    'offer_received', 'offer_accepted', 'message',
    'job_started', 'job_done', 'job_completed', 'job_cancelled'
  )),
  payload jsonb not null default '{}'::jsonb,
  dedup_key text not null unique,
  created_at timestamptz not null default now(),
  attempts smallint not null default 0,
  leased_until timestamptz,
  sent_at timestamptz,
  dead boolean not null default false,
  last_error text
);
create index notification_outbox_pending_idx
  on public.notification_outbox (id) where sent_at is null and not dead;

alter table public.notification_preferences enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notification_outbox enable row level security;
revoke all on table public.notification_preferences, public.device_tokens, public.notification_outbox
  from public, anon, authenticated;
-- The owner reads their own preferences; the outbox and tokens have no client
-- access at all (tokens are written through functions).
grant select on public.notification_preferences to authenticated;
create policy notification_preferences_read on public.notification_preferences
  for select to authenticated using (user_id = (select auth.uid()));

------------------------------------------------------------------------
-- client functions: preferences and device registration
------------------------------------------------------------------------
create or replace function public.set_notification_preferences(
  p_offers boolean, p_messages boolean, p_jobs boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  insert into public.notification_preferences (user_id, offers, messages, jobs)
  values (uid, coalesce(p_offers, true), coalesce(p_messages, true), coalesce(p_jobs, true))
  on conflict (user_id) do update
    set offers = excluded.offers, messages = excluded.messages, jobs = excluded.jobs,
        updated_at = now();
end;
$$;

-- Registers (or moves) a device token to the caller. A token belongs to one
-- account at a time: signing in on a phone takes the token over, so the
-- previous account stops receiving pushes there. At most 10 per account.
create or replace function public.register_device_token(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  if p_platform not in ('ios', 'android') or p_token is null
     or char_length(p_token) not between 20 and 4096 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('token:' || uid::text, 0));
  delete from public.device_tokens where token = p_token and user_id <> uid;
  insert into public.device_tokens (user_id, token, platform)
  values (uid, p_token, p_platform)
  on conflict (token) do update set last_seen_at = now(), platform = excluded.platform;
  -- keep the 10 most recently seen
  delete from public.device_tokens d
   where d.user_id = uid
     and d.id not in (
       select id from public.device_tokens where user_id = uid order by last_seen_at desc, id desc limit 10
     );
end;
$$;

create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  delete from public.device_tokens where token = p_token and user_id = uid;
end;
$$;

-- Missing preferences mean everything on.
create or replace function public.my_notification_preferences()
returns table (offers boolean, messages boolean, jobs boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  return query
  select coalesce(p.offers, true), coalesce(p.messages, true), coalesce(p.jobs, true)
    from (select 1) one
    left join public.notification_preferences p on p.user_id = uid;
end;
$$;

------------------------------------------------------------------------
-- enqueueing (internal)
------------------------------------------------------------------------
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

-- A new offer: tell the customer.
create or replace function public._notify_offer_events()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  customer uuid;
begin
  select r.customer_id into customer from public.quote_requests r where r.id = new.request_id;
  if tg_op = 'INSERT' then
    perform public._enqueue_notification(customer, 'offers', 'offer_received',
      'offer_received:' || new.id::text, jsonb_build_object('request_id', new.request_id, 'offer_id', new.id));
  elsif new.status = 'accepted' and old.status <> 'accepted' then
    perform public._enqueue_notification(new.professional_id, 'offers', 'offer_accepted',
      'offer_accepted:' || new.id::text, jsonb_build_object('request_id', new.request_id, 'offer_id', new.id));
  end if;
  return new;
end;
$$;
create trigger quote_offers_notify
  after insert or update of status on public.quote_offers
  for each row execute function public._notify_offer_events();

-- A message: tell the other member, once per unread burst.
create or replace function public._notify_message()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.conversations;
  recipient uuid;
  read_id bigint;
begin
  select * into c from public.conversations where id = new.conversation_id;
  if new.sender_is_customer then
    recipient := c.professional_id;
    read_id := c.professional_read_id;
  else
    recipient := c.customer_id;
    read_id := c.customer_read_id;
  end if;
  perform public._enqueue_notification(recipient, 'messages', 'message',
    'message:' || c.id::text || ':' || recipient::text || ':' || read_id::text,
    jsonb_build_object('conversation_id', c.id));
  return new;
end;
$$;
create trigger messages_notify
  after insert on public.messages
  for each row execute function public._notify_message();

-- A job step: tell the other party.
create or replace function public._notify_booking()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  payload jsonb := jsonb_build_object('booking_id', new.id, 'request_id', new.request_id);
begin
  if new.status = old.status then
    return new;
  end if;
  if new.status = 'in_progress' then
    perform public._enqueue_notification(new.customer_id, 'jobs', 'job_started', 'job_started:' || new.id::text, payload);
  elsif new.status = 'pending_confirmation' then
    perform public._enqueue_notification(new.customer_id, 'jobs', 'job_done', 'job_done:' || new.id::text, payload);
  elsif new.status = 'completed' then
    perform public._enqueue_notification(new.professional_id, 'jobs', 'job_completed', 'job_completed:' || new.id::text, payload);
  elsif new.status = 'cancelled' then
    perform public._enqueue_notification(
      case when new.cancelled_by = new.customer_id then new.professional_id else new.customer_id end,
      'jobs', 'job_cancelled', 'job_cancelled:' || new.id::text, payload);
  end if;
  return new;
end;
$$;
create trigger bookings_notify
  after update of status on public.bookings
  for each row execute function public._notify_booking();

------------------------------------------------------------------------
-- worker functions (service role only)
------------------------------------------------------------------------
-- Takes up to p_limit due notifications, leases them for 5 minutes and
-- returns them with the recipient's tokens and language.
create or replace function public.claim_notifications(p_limit integer default 50)
returns table (id bigint, attempt smallint, user_id uuid, kind text, payload jsonb, language text, tokens jsonb)
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- A worker that crashed after claiming (so never reported) must not retry
  -- forever: rows whose lease ran out after the fifth attempt are given up.
  update public.notification_outbox o
     set dead = true, last_error = coalesce(o.last_error, 'worker did not report')
   where o.sent_at is null and not o.dead and o.attempts >= 5 and o.leased_until < now();
  return query
  with due as (
    select o.id from public.notification_outbox o
     where o.sent_at is null and not o.dead
       and (o.leased_until is null or o.leased_until < now())
     order by o.id
     limit greatest(1, least(coalesce(p_limit, 50), 200))
     for update skip locked
  ), taken as (
    update public.notification_outbox o
       set attempts = o.attempts + 1, leased_until = now() + interval '5 minutes'
      from due where o.id = due.id
    returning o.id, o.attempts, o.user_id, o.kind, o.payload
  )
  select t.id, t.attempts, t.user_id, t.kind, t.payload,
         coalesce((select pr.preferred_language from public.profiles pr where pr.id = t.user_id), 'fr'),
         coalesce((select jsonb_agg(jsonb_build_object('token', d.token, 'platform', d.platform))
                     from public.device_tokens d where d.user_id = t.user_id), '[]'::jsonb)
    from taken t
   order by t.id;
end;
$$;

-- Reports the outcome: delivered, or failed (retried with a growing delay,
-- given up after 5 attempts).
create or replace function public.complete_notification(
  p_id bigint, p_attempt smallint, p_delivered boolean, p_error text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Only the worker that holds the current claim may report: a late report
  -- from a worker whose lease expired (and whose row was claimed again) is
  -- ignored, as is a report for a row already sent.
  if p_delivered then
    update public.notification_outbox
       set sent_at = now(), leased_until = null, last_error = null
     where id = p_id and attempts = p_attempt and sent_at is null;
  else
    update public.notification_outbox
       set last_error = left(p_error, 300),
           leased_until = now() + (interval '1 minute' * power(2, least(attempts, 6))::integer),
           dead = (attempts >= 5)
     where id = p_id and attempts = p_attempt and sent_at is null;
  end if;
end;
$$;

-- The push service says a token is invalid: forget it.
create or replace function public.forget_device_token(p_token text)
returns void
language sql
security definer
set search_path = ''
as $$ delete from public.device_tokens where token = p_token $$;

create or replace function public.purge_old_notifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  delete from public.notification_outbox
   where (sent_at is not null and sent_at < now() - interval '14 days')
      or (dead and created_at < now() - interval '30 days');
  get diagnostics n = row_count;
  -- devices not seen for 60 days are forgotten (a signed-out phone that
  -- could not unregister stops receiving pushes at the latest then)
  delete from public.device_tokens where last_seen_at < now() - interval '60 days';
  return n;
end;
$$;

revoke all on function
  public.set_notification_preferences(boolean, boolean, boolean),
  public.register_device_token(text, text), public.unregister_device_token(text),
  public.my_notification_preferences(),
  public._enqueue_notification(uuid, text, text, text, jsonb),
  public._notify_offer_events(), public._notify_message(), public._notify_booking(),
  public.claim_notifications(integer), public.complete_notification(bigint, smallint, boolean, text),
  public.forget_device_token(text), public.purge_old_notifications()
  from public, anon, authenticated;
grant execute on function
  public.set_notification_preferences(boolean, boolean, boolean),
  public.register_device_token(text, text), public.unregister_device_token(text),
  public.my_notification_preferences()
  to authenticated;
grant execute on function
  public.claim_notifications(integer), public.complete_notification(bigint, smallint, boolean, text),
  public.forget_device_token(text), public.purge_old_notifications()
  to service_role;
