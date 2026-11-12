-- Payments and merchant subscriptions (issues #39-#46).
--
-- Every professional or freelancer pays a fixed monthly fee in Tunisian
-- dinars (stored in millimes: 20 TND = 20000). Three rails:
--   * flouci        automatic: an Edge Function creates the Flouci payment and
--                   confirms it from Flouci's signed webhook (see
--                   supabase/functions/flouci-payments).
--   * d17           La Poste Tunisienne wallet: the person pays the number shown
--                   and an admin confirms (no public merchant API known).
--   * bank_transfer virement to the RIB shown; an admin confirms.
-- Money state changes only through these functions: clients cannot write any
-- payment table. Provider callbacks are idempotent (payment_events). Nothing
-- hides an unpaid profile yet: enforcement is a later switch (issue #44).

create table public.subscription_plans (
  code text primary key check (code ~ '^[a-z][a-z0-9-]*$'),
  name_fr text not null,
  name_ar text not null,
  name_en text not null,
  amount_millimes integer not null check (amount_millimes > 0),
  period_days smallint not null default 30 check (period_days between 1 and 366),
  is_active boolean not null default true,
  sort_order integer not null default 0
);
insert into public.subscription_plans (code, name_fr, name_ar, name_en, amount_millimes, sort_order) values
  ('standard', 'Standard', 'عادي', 'Standard', 20000, 10),
  ('plus', 'Plus', 'بلس', 'Plus', 30000, 20);
alter table public.subscription_plans enable row level security;
revoke all on table public.subscription_plans from public, anon, authenticated;
grant select on public.subscription_plans to anon, authenticated;
create policy subscription_plans_read on public.subscription_plans
  for select to anon, authenticated using (is_active);

create table public.subscriptions (
  user_id uuid primary key references public.professional_profiles (user_id) on delete cascade,
  plan_code text not null references public.subscription_plans (code),
  status text not null default 'active' check (status in ('active', 'past_due', 'expired', 'cancelled')),
  current_period_end timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger subscriptions_updated_at
  before update on public.subscriptions
  for each row execute function public.set_updated_at();
alter table public.subscriptions enable row level security;
revoke all on table public.subscriptions from public, anon, authenticated;
grant select on public.subscriptions to authenticated;
create policy subscriptions_read_own on public.subscriptions
  for select to authenticated using (user_id = (select auth.uid()));

create table public.payment_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.professional_profiles (user_id) on delete cascade,
  plan_code text not null references public.subscription_plans (code),
  amount_millimes integer not null check (amount_millimes > 0),
  currency text not null default 'TND' check (currency = 'TND'),
  method text not null check (method in ('flouci', 'd17', 'bank_transfer')),
  status text not null default 'pending'
    check (status in ('pending', 'awaiting_confirmation', 'paid', 'failed', 'cancelled', 'rejected')),
  -- Short code the person writes in the transfer motif / D17 note.
  reference text not null unique check (reference ~ '^KH-[0-9A-Z]{6}$'),
  provider_ref text,
  payer_note text check (char_length(payer_note) <= 200),
  admin_note text check (char_length(admin_note) <= 500),
  decided_by uuid,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
create index payment_orders_user_idx on public.payment_orders (user_id, created_at desc);
create index payment_orders_queue_idx on public.payment_orders (status, created_at)
  where status in ('pending', 'awaiting_confirmation');
create unique index payment_orders_provider_ref_idx on public.payment_orders (method, provider_ref)
  where provider_ref is not null;
alter table public.payment_orders enable row level security;
revoke all on table public.payment_orders from public, anon, authenticated;
grant select (id, plan_code, amount_millimes, currency, method, status, reference, payer_note, created_at, paid_at)
  on public.payment_orders to authenticated;
create policy payment_orders_read_own on public.payment_orders
  for select to authenticated using (user_id = (select auth.uid()));

-- Provider callbacks already handled (idempotency). Service role only.
create table public.payment_events (
  provider text not null,
  event_id text not null,
  order_id uuid references public.payment_orders (id) on delete set null,
  received_at timestamptz not null default now(),
  primary key (provider, event_id)
);
alter table public.payment_events enable row level security;
revoke all on table public.payment_events from public, anon, authenticated;

-- Where manual payments go. Read only through get_payment_instructions().
create table public.payment_settings (
  key text primary key check (key in ('bank_name', 'bank_holder', 'bank_rib', 'd17_number', 'd17_holder')),
  value text not null check (char_length(value) between 1 and 120),
  updated_at timestamptz not null default now()
);
alter table public.payment_settings enable row level security;
revoke all on table public.payment_settings from public, anon, authenticated;

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
create or replace function public._new_payment_reference()
returns text
language plpgsql
volatile
set search_path = ''
as $$
declare
  ref text;
begin
  loop
    ref := 'KH-' || upper(substr(md5(gen_random_uuid()::text), 1, 6));
    exit when not exists (select 1 from public.payment_orders where reference = ref);
  end loop;
  return ref;
end;
$$;

-- Pays an order: marks it, extends the subscription by one period.
create or replace function public._settle_order(p_order uuid, p_decided_by uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.payment_orders;
  days smallint;
begin
  select * into o from public.payment_orders where id = p_order for update;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if o.status = 'paid' then
    return;
  end if;
  if o.status in ('cancelled', 'failed', 'rejected') then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  select period_days into days from public.subscription_plans where code = o.plan_code;
  update public.payment_orders
     set status = 'paid', paid_at = now(), decided_by = p_decided_by
   where id = o.id;
  insert into public.subscriptions (user_id, plan_code, status, current_period_end)
  values (o.user_id, o.plan_code, 'active', now() + make_interval(days => days))
  on conflict (user_id) do update
    set plan_code = excluded.plan_code,
        status = 'active',
        current_period_end = greatest(public.subscriptions.current_period_end, now())
                             + make_interval(days => days);
end;
$$;

create or replace function public.subscription_is_active(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.subscriptions s
     where s.user_id = p_user and s.status = 'active' and s.current_period_end > now())
$$;

------------------------------------------------------------------------
-- people: order, say "I paid", cancel, read
------------------------------------------------------------------------
create or replace function public.create_payment_order(p_plan text, p_method text)
returns table (id uuid, reference text, amount_millimes integer, method text, status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  plan public.subscription_plans;
  existing public.payment_orders;
begin
  if p_method not in ('flouci', 'd17', 'bank_transfer') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  select * into plan from public.subscription_plans where code = p_plan and is_active;
  if not found then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.professional_profiles where user_id = uid) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('payorder:' || uid::text, 0));
  -- The same unpaid order is returned, not duplicated.
  select * into existing from public.payment_orders o
   where o.user_id = uid and o.plan_code = plan.code and o.method = p_method
     and o.status in ('pending', 'awaiting_confirmation') and o.created_at > now() - interval '24 hours'
   order by o.created_at desc limit 1;
  if found then
    return query select existing.id, existing.reference, existing.amount_millimes, existing.method, existing.status;
    return;
  end if;
  if (select count(*) from public.payment_orders o
       where o.user_id = uid and o.created_at > now() - interval '24 hours') >= 10 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  return query
    insert into public.payment_orders as o (user_id, plan_code, amount_millimes, method, reference)
    values (uid, plan.code, plan.amount_millimes, p_method, public._new_payment_reference())
    returning o.id, o.reference, o.amount_millimes, o.method, o.status;
end;
$$;

create or replace function public.mark_payment_sent(p_order uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  note text := nullif(btrim(p_note), '');
begin
  if note is not null and char_length(note) > 200 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  update public.payment_orders
     set status = 'awaiting_confirmation', payer_note = note
   where id = p_order and user_id = uid and method in ('d17', 'bank_transfer')
     and status in ('pending', 'awaiting_confirmation');
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.cancel_payment_order(p_order uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  update public.payment_orders set status = 'cancelled'
   where id = p_order and user_id = uid and status in ('pending', 'awaiting_confirmation');
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.my_subscription()
returns table (plan_code text, status text, current_period_end timestamptz, days_left integer)
language sql
stable
security definer
set search_path = ''
as $$
  select s.plan_code,
         case when s.status = 'active' and s.current_period_end <= now() then 'past_due' else s.status end,
         s.current_period_end,
         greatest(0, ceil(extract(epoch from (s.current_period_end - now())) / 86400)::integer)
    from public.subscriptions s where s.user_id = (select auth.uid())
$$;

create or replace function public.get_payment_instructions()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  s jsonb := coalesce((select jsonb_object_agg(key, value) from public.payment_settings), '{}'::jsonb);
begin
  return jsonb_build_object(
    'bank', case when s ? 'bank_rib' then jsonb_build_object(
      'name', s -> 'bank_name', 'holder', s -> 'bank_holder', 'rib', s -> 'bank_rib') else null end,
    'd17', case when s ? 'd17_number' then jsonb_build_object(
      'number', s -> 'd17_number', 'holder', s -> 'd17_holder') else null end
  );
end;
$$;

------------------------------------------------------------------------
-- admins: queue, confirm, reject, settings
------------------------------------------------------------------------
create or replace function public.admin_list_payment_orders(
  p_status text default 'awaiting_confirmation', p_limit integer default 50, p_offset integer default 0
)
returns table (
  id uuid, reference text, method text, status text, plan_code text, amount_millimes integer,
  payer_note text, business_name text, full_name text, created_at timestamptz
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
    select o.id, o.reference, o.method, o.status, o.plan_code, o.amount_millimes, o.payer_note,
           p.business_name, pr.full_name, o.created_at
      from public.payment_orders o
      join public.professional_profiles p on p.user_id = o.user_id
      join public.profiles pr on pr.id = o.user_id
     where (p_status is null or o.status = p_status)
     order by o.created_at
     limit least(coalesce(p_limit, 50), 100) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.admin_confirm_payment(p_order uuid)
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
  if not exists (select 1 from public.payment_orders where id = p_order and method in ('d17', 'bank_transfer')) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  perform public._settle_order(p_order, uid);
  perform public._audit('payment_confirmed', 'payment_order', p_order::text);
end;
$$;

create or replace function public.admin_reject_payment(p_order uuid, p_note text default null)
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
  update public.payment_orders
     set status = 'rejected', admin_note = left(p_note, 500), decided_by = uid
   where id = p_order and method in ('d17', 'bank_transfer') and status in ('pending', 'awaiting_confirmation');
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  perform public._audit('payment_rejected', 'payment_order', p_order::text, p_note);
end;
$$;

create or replace function public.admin_set_payment_setting(p_key text, p_value text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v text := btrim(p_value);
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_key not in ('bank_name', 'bank_holder', 'bank_rib', 'd17_number', 'd17_holder')
     or (p_key = 'bank_rib' and regexp_replace(v, '[ ]', '', 'g') !~ '^[0-9]{20}$')
     or (p_key = 'd17_number' and regexp_replace(v, '[ ]', '', 'g') !~ '^[2-9][0-9]{7}$') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  insert into public.payment_settings (key, value)
  values (p_key, case when p_key in ('bank_rib', 'd17_number') then regexp_replace(v, '[ ]', '', 'g') else v end)
  on conflict (key) do update set value = excluded.value, updated_at = now();
  perform public._audit('payment_setting', 'payment_settings', p_key);
end;
$$;

------------------------------------------------------------------------
-- Flouci (service role only: called by the Edge Function)
------------------------------------------------------------------------
create or replace function public.service_attach_provider_ref(p_order uuid, p_ref text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.payment_orders set provider_ref = p_ref
   where id = p_order and method = 'flouci' and status = 'pending' and provider_ref is null;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
end;
$$;

-- Idempotent: a repeated event does nothing. The amount must match exactly.
create or replace function public.service_apply_flouci_event(
  p_event_id text, p_payment_id text, p_success boolean, p_amount_millimes integer
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.payment_orders;
begin
  if p_event_id is null or char_length(p_event_id) not between 1 and 100 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  insert into public.payment_events (provider, event_id) values ('flouci', p_event_id)
  on conflict do nothing;
  if not found then
    return 'duplicate';
  end if;
  select * into o from public.payment_orders
   where method = 'flouci' and provider_ref = p_payment_id for update;
  if not found then
    return 'unknown_order';
  end if;
  update public.payment_events set order_id = o.id where provider = 'flouci' and event_id = p_event_id;
  if not p_success then
    update public.payment_orders set status = 'failed' where id = o.id and status = 'pending';
    return 'failed';
  end if;
  if p_amount_millimes is distinct from o.amount_millimes then
    update public.payment_orders set status = 'failed', admin_note = 'amount_mismatch' where id = o.id and status = 'pending';
    return 'amount_mismatch';
  end if;
  perform public._settle_order(o.id, null);
  return 'paid';
end;
$$;

-- Subscriptions whose period ended: past_due for 7 days, then expired.
create or replace function public.service_expire_subscriptions()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
begin
  update public.subscriptions set status = 'past_due'
   where status = 'active' and current_period_end <= now();
  update public.subscriptions set status = 'expired'
   where status = 'past_due' and current_period_end <= now() - interval '7 days';
  get diagnostics n = row_count;
  return n;
end;
$$;

------------------------------------------------------------------------
-- execute rights
------------------------------------------------------------------------
revoke all on function
  public._new_payment_reference(), public._settle_order(uuid, uuid), public.subscription_is_active(uuid),
  public.create_payment_order(text, text), public.mark_payment_sent(uuid, text), public.cancel_payment_order(uuid),
  public.my_subscription(), public.get_payment_instructions(),
  public.admin_list_payment_orders(text, integer, integer), public.admin_confirm_payment(uuid),
  public.admin_reject_payment(uuid, text), public.admin_set_payment_setting(text, text),
  public.service_attach_provider_ref(uuid, text), public.service_apply_flouci_event(text, text, boolean, integer),
  public.service_expire_subscriptions()
  from public, anon, authenticated;
grant execute on function
  public.create_payment_order(text, text), public.mark_payment_sent(uuid, text), public.cancel_payment_order(uuid),
  public.my_subscription(), public.get_payment_instructions(),
  public.admin_list_payment_orders(text, integer, integer), public.admin_confirm_payment(uuid),
  public.admin_reject_payment(uuid, text), public.admin_set_payment_setting(text, text)
  to authenticated;
grant execute on function
  public.service_attach_provider_ref(uuid, text), public.service_apply_flouci_event(text, text, boolean, integer),
  public.service_expire_subscriptions(), public.subscription_is_active(uuid)
  to service_role;
