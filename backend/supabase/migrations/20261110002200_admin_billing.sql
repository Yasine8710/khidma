-- Admin billing overview (#65): summary (MRR, past_due), subscriptions list,
-- one merchant's billing, and corrective actions with a required reason.
-- Every action is audited. Nothing here is reachable by non-admins.

-- MRR = what active subscriptions bring per 30 days, in millimes.
create or replace function public.admin_billing_summary()
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
  return jsonb_build_object(
    'mrr_millimes', coalesce((
      select sum(round(p.amount_millimes * 30.0 / p.period_days))::bigint
        from public.subscriptions s join public.subscription_plans p on p.code = s.plan_code
       where s.status = 'active' and s.current_period_end > now()), 0),
    'active', (select count(*) from public.subscriptions where status = 'active' and current_period_end > now()),
    'past_due', (select count(*) from public.subscriptions
                  where status = 'past_due' or (status = 'active' and current_period_end <= now())),
    'expired', (select count(*) from public.subscriptions where status = 'expired'),
    'cancelled', (select count(*) from public.subscriptions where status = 'cancelled'),
    'orders_waiting', (select count(*) from public.payment_orders where status = 'awaiting_confirmation'),
    'orders_waiting_48h', (select count(*) from public.payment_orders
                            where status = 'awaiting_confirmation' and created_at < now() - interval '48 hours')
  );
end;
$$;

create or replace function public.admin_list_subscriptions(
  p_status text default null, p_limit integer default 50, p_offset integer default 0
)
returns table (
  user_id uuid, business_name text, plan_code text, status text,
  current_period_end timestamptz, amount_millimes integer, last_paid_at timestamptz
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
  if p_status is not null and p_status not in ('active', 'past_due', 'expired', 'cancelled') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  return query
  select s.user_id, pr.business_name, s.plan_code,
         -- a period that ended reads as past_due even before the daily job
         case when s.status = 'active' and s.current_period_end <= now() then 'past_due' else s.status end,
         s.current_period_end, pl.amount_millimes,
         (select max(o.paid_at) from public.payment_orders o where o.user_id = s.user_id and o.status = 'paid')
    from public.subscriptions s
    join public.subscription_plans pl on pl.code = s.plan_code
    join public.professional_profiles pr on pr.user_id = s.user_id
   where p_status is null
      or (case when s.status = 'active' and s.current_period_end <= now() then 'past_due' else s.status end) = p_status
   order by s.current_period_end, s.user_id
   limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

-- One merchant: subscription and the last 50 orders.
create or replace function public.admin_billing_detail(p_user uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  sub jsonb;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not exists (select 1 from public.professional_profiles where user_id = p_user) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  select to_jsonb(x) into sub from (
    select s.plan_code, s.status, s.current_period_end, s.created_at from public.subscriptions s where s.user_id = p_user) x;
  return jsonb_build_object(
    'subscription', sub,
    'orders', coalesce((
      select jsonb_agg(o order by o.created_at desc) from (
        select id, reference, plan_code, method, status, amount_millimes, created_at, paid_at, admin_note
          from public.payment_orders where user_id = p_user order by created_at desc limit 50) o), '[]'::jsonb)
  );
end;
$$;

-- Extend grace or comp a period: adds p_days (1-60) from the later of now
-- and the current end, and makes the subscription active.
create or replace function public.admin_extend_subscription(p_user uuid, p_days integer, p_reason text, p_plan text default null)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  reason text := nullif(btrim(p_reason), '');
  new_end timestamptz;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if reason is null or char_length(reason) > 300 or p_days is null or p_days < 1 or p_days > 60 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.professional_profiles where user_id = p_user) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  update public.subscriptions
     set status = 'active',
         current_period_end = greatest(current_period_end, now()) + make_interval(days => p_days)
   where user_id = p_user
  returning current_period_end into new_end;
  if new_end is null then
    -- no subscription yet: a comp starts one on the given (or cheapest) plan
    insert into public.subscriptions (user_id, plan_code, status, current_period_end)
    values (p_user,
            coalesce(p_plan, (select code from public.subscription_plans where is_active order by amount_millimes limit 1)),
            'active', now() + make_interval(days => p_days))
    returning current_period_end into new_end;
  end if;
  perform public._audit('subscription_extended', 'professional', p_user::text, reason || ' (+' || p_days || ' days)');
  return new_end;
end;
$$;

-- Suspend (cancelled) or reactivate (active, only while the period runs).
create or replace function public.admin_set_subscription_status(p_user uuid, p_status text, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  reason text := nullif(btrim(p_reason), '');
  s public.subscriptions;
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if reason is null or char_length(reason) > 300 or p_status not in ('active', 'cancelled') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  select * into s from public.subscriptions where user_id = p_user for update;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if p_status = 'active' and s.current_period_end <= now() then
    -- nothing left to reactivate: extend instead
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  update public.subscriptions set status = p_status where user_id = p_user;
  perform public._audit('subscription_' || case when p_status = 'active' then 'reactivated' else 'suspended' end,
                        'professional', p_user::text, reason);
end;
$$;

revoke all on function
  public.admin_billing_summary(), public.admin_list_subscriptions(text, integer, integer),
  public.admin_billing_detail(uuid), public.admin_extend_subscription(uuid, integer, text, text),
  public.admin_set_subscription_status(uuid, text, text)
  from public, anon, authenticated;
grant execute on function
  public.admin_billing_summary(), public.admin_list_subscriptions(text, integer, integer),
  public.admin_billing_detail(uuid), public.admin_extend_subscription(uuid, integer, text, text),
  public.admin_set_subscription_status(uuid, text, text)
  to authenticated;
