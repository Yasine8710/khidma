-- Subscription enforcement (#64).
--
-- Off by default. When an admin switches it on, a professional is listed
-- (profile, freelance listing, search, map, phone reveal, favorites, new
-- offers) only while one of these holds:
--   * their subscription is active or past_due and ended less than 7 days ago
--     (the grace period), or
--   * their professional profile is younger than the free trial (30 days by
--     default, set by admins).
-- Hiding is a read rule, not an unpublish: nothing is lost, and paying shows
-- the profile again at once. Jobs already accepted keep working (bookings,
-- chats and reviews do not look at listing status). The owner always sees
-- their own profile.
--
-- Reminders (each sent once per period, Tunis days): due in 5 days or less,
-- due tomorrow or today, 1 day late, grace over (7 days late).

alter table public.admin_config
  add column enforce_subscriptions boolean not null default false,
  add column free_trial_days smallint not null default 30 check (free_trial_days between 0 and 365);

alter table public.notification_outbox drop constraint notification_outbox_kind_check;
alter table public.notification_outbox add constraint notification_outbox_kind_check
  check (kind in (
    'offer_received', 'offer_accepted', 'message',
    'job_started', 'job_done', 'job_completed', 'job_cancelled',
    'report_actioned', 'report_dismissed', 'account_suspended', 'account_restored',
    'appeal_rejected', 'verification_expired', 'listing_held', 'listing_released',
    'payment_confirmed', 'payment_rejected',
    'subscription_due_soon', 'subscription_due_now', 'subscription_overdue', 'subscription_grace_over'
  ));

-- Whether a professional may be listed right now.
create or replace function public.listing_allowed(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not coalesce((select c.enforce_subscriptions from public.admin_config c), false)
      or exists (
        select 1 from public.subscriptions s
         where s.user_id = p_user and s.status in ('active', 'past_due')
           and s.current_period_end > now() - interval '7 days')
      or exists (
        select 1 from public.professional_profiles p
         where p.user_id = p_user
           and p.created_at > now() - make_interval(days => (select c.free_trial_days from public.admin_config c)))
$$;

-- Profiles (and through them services, areas, portfolio, favorites and the
-- search, which all read this table under its row security) follow the rule.
drop policy professional_profiles_read on public.professional_profiles;
create policy professional_profiles_read on public.professional_profiles
  for select to anon, authenticated
  using (
    (is_published and public.listing_allowed(user_id))
    or user_id = (select auth.uid())
    or (select public.is_admin())
  );

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
       and public.listing_allowed(p_user)
  )
$$;

-- Same as 0100, plus the listing rule (the function bypasses row security).
create or replace function public.reveal_professional_contact(p_professional uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  phone text;
begin
  perform pg_advisory_xact_lock(hashtextextended('reveal:' || uid::text, 0));
  if (select count(*) from public.contact_reveals
       where user_id = uid and created_at > now() - interval '1 hour') >= 40 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  select contact_phone into phone
    from public.professional_profiles
   where user_id = p_professional and is_published and public.listing_allowed(p_professional);
  if phone is null then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  insert into public.contact_reveals (user_id, professional_id) values (uid, p_professional);
  return phone;
end;
$$;

-- No new offers while unlisted (offers already made and jobs go on).
create or replace function public.block_unlisted_offer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.listing_allowed(new.professional_id) then
    raise exception 'subscription_required' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger quote_offers_block_unlisted
  before insert on public.quote_offers
  for each row execute function public.block_unlisted_offer();

-- The owner's view: is the switch on, am I listed, until when.
create or replace function public.my_listing_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  created timestamptz;
  s public.subscriptions;
  cfg public.admin_config;
begin
  select created_at into created from public.professional_profiles where user_id = uid;
  if not found then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select * into cfg from public.admin_config;
  select * into s from public.subscriptions where user_id = uid;
  return jsonb_build_object(
    'enforced', coalesce(cfg.enforce_subscriptions, false),
    'listed', public.listing_allowed(uid),
    'trial_ends_at', created + make_interval(days => coalesce(cfg.free_trial_days, 0)),
    'paid_until', s.current_period_end,
    'grace_ends_at', case when s.status in ('active', 'past_due') then s.current_period_end + interval '7 days' end
  );
end;
$$;

create or replace function public.admin_set_billing_config(p_enforce boolean, p_trial_days integer, p_reason text)
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
  if p_enforce is null or p_trial_days is null or p_trial_days < 0 or p_trial_days > 365
     or reason is null or char_length(reason) > 300 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  update public.admin_config set enforce_subscriptions = p_enforce, free_trial_days = p_trial_days;
  perform public._audit('billing_config', 'config', 'subscriptions',
    reason || ' (enforce=' || p_enforce || ', trial=' || p_trial_days || ' days)');
end;
$$;

-- The switch and trial length appear in the admin summary.
create or replace function public.admin_billing_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return (select jsonb_build_object('enforce_subscriptions', c.enforce_subscriptions, 'free_trial_days', c.free_trial_days)
            from public.admin_config c);
end;
$$;

-- Daily (service role): reminders, each once per period, in Tunis days.
create or replace function public.service_subscription_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer := 0;
  r record;
  kind text;
begin
  for r in
    select s.user_id, s.status, (s.current_period_end at time zone 'Africa/Tunis')::date as end_day,
           (s.current_period_end at time zone 'Africa/Tunis')::date - public.tunis_today() as days_left
      from public.subscriptions s
     where s.status in ('active', 'past_due', 'expired')
  loop
    kind := case
      when r.days_left between 2 and 5 then 'subscription_due_soon'
      when r.days_left between 0 and 1 then 'subscription_due_now'
      when r.days_left between -6 and -1 then 'subscription_overdue'
      when r.days_left between -30 and -7 then 'subscription_grace_over'
    end;
    if kind is not null then
      perform public._enqueue_notification(r.user_id, 'account', kind,
        'sub:' || r.user_id::text || ':' || r.end_day::text || ':' || kind, '{}'::jsonb);
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;

revoke all on function
  public.listing_allowed(uuid), public.block_unlisted_offer(), public.my_listing_status(),
  public.admin_set_billing_config(boolean, integer, text), public.admin_billing_config(),
  public.service_subscription_reminders()
  from public, anon, authenticated;
-- listing_allowed runs inside the read policy, so every client role needs it.
grant execute on function public.listing_allowed(uuid) to anon, authenticated;
grant execute on function
  public.my_listing_status(), public.admin_set_billing_config(boolean, integer, text), public.admin_billing_config()
  to authenticated;
grant execute on function public.service_subscription_reminders() to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('khidma-expire-subscriptions', '5 * * * *', 'select public.service_expire_subscriptions()');
    perform cron.schedule('khidma-subscription-reminders', '0 7 * * *', 'select public.service_subscription_reminders()');
  end if;
end;
$$;
