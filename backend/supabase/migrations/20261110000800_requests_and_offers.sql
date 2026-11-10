-- Requests, offers and bookings (Phase 5).
--
-- A customer posts a quote request; published professionals send offers; the
-- customer accepts one, which creates a booking that moves through an explicit
-- lifecycle:
--
--   request : open -> awarded | cancelled | expired
--   offer   : pending -> accepted | declined | withdrawn
--   booking : scheduled -> in_progress -> pending_confirmation -> completed
--             scheduled | in_progress -> cancelled
--
-- Nothing is written by clients directly. Every change goes through a
-- SECURITY DEFINER function that checks who is calling and which transition is
-- allowed; the tables only grant SELECT, narrowed by Row Level Security:
--   * a customer sees their own requests and the offers on them;
--   * a professional sees their own offers and the requests they offered on;
--   * nobody sees a rival's offer;
--   * professionals discover open requests only through list_open_requests(),
--     which never returns who asked.
-- Error tags (P0001): rate_limited, limit_reached, not_open, expired,
-- own_request, offer_closed, invalid_transition, invalid_input.

------------------------------------------------------------------------
-- tables
------------------------------------------------------------------------
create table public.quote_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customer_profiles (user_id) on delete cascade,
  category_id smallint not null references public.service_categories (id),
  governorate_id smallint not null references public.governorates (id),
  city_id integer,
  title text not null check (char_length(btrim(title)) between 3 and 120),
  description text not null check (char_length(btrim(description)) between 10 and 2000),
  budget_tnd numeric(10, 3) check (budget_tnd is null or (budget_tnd >= 0 and budget_tnd <= 1000000)),
  needed_by date,
  status text not null default 'open'
    check (status in ('open', 'awarded', 'cancelled', 'expired')),
  expires_at timestamptz not null default (now() + interval '14 days'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (city_id, governorate_id) references public.cities (id, governorate_id)
);
create index quote_requests_customer_idx on public.quote_requests (customer_id, created_at desc);
create index quote_requests_open_idx
  on public.quote_requests (governorate_id, category_id, created_at desc) where status = 'open';

create table public.quote_offers (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.quote_requests (id) on delete cascade,
  professional_id uuid not null references public.professional_profiles (user_id) on delete cascade,
  price_tnd numeric(10, 3) not null check (price_tnd >= 1 and price_tnd <= 1000000),
  message text check (message is null or char_length(message) <= 1000),
  estimated_days smallint check (estimated_days is null or estimated_days between 1 and 365),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'withdrawn')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (request_id, professional_id)
);
create index quote_offers_professional_idx on public.quote_offers (professional_id, created_at desc);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.quote_requests (id) on delete cascade,
  offer_id uuid not null unique references public.quote_offers (id) on delete cascade,
  customer_id uuid not null references public.customer_profiles (user_id) on delete cascade,
  professional_id uuid not null references public.professional_profiles (user_id) on delete cascade,
  price_tnd numeric(10, 3) not null,
  status text not null default 'scheduled'
    check (status in ('scheduled', 'in_progress', 'pending_confirmation', 'completed', 'cancelled')),
  cancelled_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  started_at timestamptz,
  done_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  check (customer_id <> professional_id),
  check ((status = 'cancelled') = (cancelled_at is not null))
);
create index bookings_customer_idx on public.bookings (customer_id, created_at desc);
create index bookings_professional_idx on public.bookings (professional_id, created_at desc);

create trigger quote_requests_updated_at before update on public.quote_requests
  for each row execute function public.set_updated_at();
create trigger quote_offers_updated_at before update on public.quote_offers
  for each row execute function public.set_updated_at();
create trigger bookings_updated_at before update on public.bookings
  for each row execute function public.set_updated_at();

------------------------------------------------------------------------
-- privileges and Row Level Security: read-only for clients
------------------------------------------------------------------------
revoke all on table public.quote_requests, public.quote_offers, public.bookings
  from public, anon, authenticated;
-- customer_id is not selectable: a professional who offered on a request must
-- not learn who asked (customers know who they are; bookings, which both sides
-- may see, name both parties).
grant select (
  id, category_id, governorate_id, city_id, title, description, budget_tnd,
  needed_by, status, expires_at, created_at, updated_at
) on public.quote_requests to authenticated;
grant select on public.quote_offers, public.bookings to authenticated;

alter table public.quote_requests enable row level security;
alter table public.quote_offers enable row level security;
alter table public.bookings enable row level security;

-- Offers: the professional's own, and the ones on the customer's own requests.
-- (The two tables' policies would look at each other; these definer helpers
-- check ownership without going through the other table's policy.)
create or replace function public.is_request_owner(p_request uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.quote_requests r
     where r.id = p_request and r.customer_id = (select auth.uid())
  )
$$;

create or replace function public.has_offered_on(p_request uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.quote_offers o
     where o.request_id = p_request and o.professional_id = (select auth.uid())
  )
$$;

-- Requests: the customer's own, and those a professional has offered on.
create policy requests_read on public.quote_requests
  for select to authenticated
  using (
    customer_id = (select auth.uid())
    or (select public.has_offered_on(id))
  );

create policy offers_read on public.quote_offers
  for select to authenticated
  using (
    professional_id = (select auth.uid())
    or (select public.is_request_owner(request_id))
  );

create policy bookings_read on public.bookings
  for select to authenticated
  using (customer_id = (select auth.uid()) or professional_id = (select auth.uid()));

revoke all on function public.is_request_owner(uuid), public.has_offered_on(uuid)
  from public, anon, authenticated;
grant execute on function public.is_request_owner(uuid), public.has_offered_on(uuid) to authenticated;

------------------------------------------------------------------------
-- customer: create and cancel a request
------------------------------------------------------------------------
create or replace function public.create_quote_request(
  p_title text, p_description text, p_category smallint, p_governorate smallint,
  p_city integer default null, p_budget numeric default null, p_needed_by date default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  new_id uuid;
begin
  if not exists (select 1 from public.customer_profiles where user_id = uid) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('request:' || uid::text, 0));
  if (select count(*) from public.quote_requests
       where customer_id = uid and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  if (select count(*) from public.quote_requests
       where customer_id = uid and status = 'open') >= 10 then
    raise exception 'limit_reached' using errcode = 'P0001';
  end if;
  if p_needed_by is not null and p_needed_by < current_date then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.service_categories where id = p_category and is_active) then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  insert into public.quote_requests
    (customer_id, category_id, governorate_id, city_id, title, description, budget_tnd, needed_by)
  values
    (uid, p_category, p_governorate, p_city, btrim(p_title), btrim(p_description), p_budget, p_needed_by)
  returning id into new_id;
  return new_id;
end;
$$;

create or replace function public.cancel_quote_request(p_request uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  r public.quote_requests;
begin
  select * into r from public.quote_requests where id = p_request for update;
  if not found or r.customer_id <> uid then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if r.status <> 'open' then
    raise exception 'not_open' using errcode = 'P0001';
  end if;
  update public.quote_requests set status = 'cancelled' where id = p_request;
  update public.quote_offers set status = 'declined' where request_id = p_request and status = 'pending';
end;
$$;

------------------------------------------------------------------------
-- professional: discover open requests (never reveals who asked)
------------------------------------------------------------------------
create or replace function public.list_open_requests(
  p_category smallint default null, p_governorate smallint default null,
  p_limit integer default 20, p_offset integer default 0
)
returns table (
  id uuid, title text, description text, category_id smallint, governorate_id smallint,
  city_id integer, budget_tnd numeric, needed_by date, created_at timestamptz,
  expires_at timestamptz, offers_count integer, my_offer_status text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  if not exists (select 1 from public.professional_profiles where user_id = uid and is_published) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
  select r.id, r.title, r.description, r.category_id, r.governorate_id, r.city_id,
         r.budget_tnd, r.needed_by, r.created_at, r.expires_at,
         (select count(*)::integer from public.quote_offers o where o.request_id = r.id),
         (select o.status from public.quote_offers o where o.request_id = r.id and o.professional_id = uid)
    from public.quote_requests r
   where r.status = 'open' and r.expires_at > now() and r.customer_id <> uid
     and (p_category is null or r.category_id = p_category)
     and (p_governorate is null or r.governorate_id = p_governorate)
   order by r.created_at desc, r.id
   limit greatest(1, least(coalesce(p_limit, 20), 50))
  offset greatest(0, least(coalesce(p_offset, 0), 5000));
end;
$$;

create or replace function public.get_open_request(p_request uuid)
returns table (
  id uuid, title text, description text, category_id smallint, governorate_id smallint,
  city_id integer, budget_tnd numeric, needed_by date, created_at timestamptz,
  expires_at timestamptz, offers_count integer, my_offer_status text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  if not exists (select 1 from public.professional_profiles where user_id = uid and is_published) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
  select r.id, r.title, r.description, r.category_id, r.governorate_id, r.city_id,
         r.budget_tnd, r.needed_by, r.created_at, r.expires_at,
         (select count(*)::integer from public.quote_offers o where o.request_id = r.id),
         (select o.status from public.quote_offers o where o.request_id = r.id and o.professional_id = uid)
    from public.quote_requests r
   where r.id = p_request and r.customer_id <> uid
     and (r.status = 'open' and r.expires_at > now()
          or exists (select 1 from public.quote_offers o where o.request_id = r.id and o.professional_id = uid));
end;
$$;

------------------------------------------------------------------------
-- professional: offers
------------------------------------------------------------------------
create or replace function public.submit_offer(
  p_request uuid, p_price numeric, p_message text default null, p_days smallint default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  r public.quote_requests;
  existing public.quote_offers;
  offer_id uuid;
begin
  if not exists (select 1 from public.professional_profiles where user_id = uid and is_published) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select * into r from public.quote_requests where id = p_request for share;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if r.customer_id = uid then
    raise exception 'own_request' using errcode = 'P0001';
  end if;
  if r.status <> 'open' then
    raise exception 'not_open' using errcode = 'P0001';
  end if;
  if r.expires_at <= now() then
    raise exception 'expired' using errcode = 'P0001';
  end if;
  if p_price is null or p_price < 1 or p_price > 1000000 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('offer:' || uid::text, 0));
  select * into existing from public.quote_offers
   where request_id = p_request and professional_id = uid for update;
  if found then
    if existing.status = 'declined' or existing.status = 'accepted' then
      raise exception 'offer_closed' using errcode = 'P0001';
    end if;
    if existing.status = 'withdrawn'
       and (select count(*) from public.quote_offers where professional_id = uid and status = 'pending') >= 50 then
      raise exception 'limit_reached' using errcode = 'P0001';
    end if;
    update public.quote_offers
       set price_tnd = p_price, message = nullif(btrim(p_message), ''), estimated_days = p_days,
           status = 'pending'
     where id = existing.id
    returning id into offer_id;
    return offer_id;
  end if;

  if (select count(*) from public.quote_offers where professional_id = uid and status = 'pending') >= 50 then
    raise exception 'limit_reached' using errcode = 'P0001';
  end if;
  insert into public.quote_offers (request_id, professional_id, price_tnd, message, estimated_days)
  values (p_request, uid, p_price, nullif(btrim(p_message), ''), p_days)
  returning id into offer_id;
  return offer_id;
end;
$$;

create or replace function public.withdraw_offer(p_offer uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  o public.quote_offers;
begin
  select * into o from public.quote_offers where id = p_offer for update;
  if not found or o.professional_id <> uid then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if o.status <> 'pending' then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  update public.quote_offers set status = 'withdrawn' where id = p_offer;
end;
$$;

------------------------------------------------------------------------
-- customer: decline or accept an offer (accept is atomic)
------------------------------------------------------------------------
create or replace function public.decline_offer(p_offer uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  o public.quote_offers;
begin
  select * into o from public.quote_offers where id = p_offer for update;
  if not found or not exists (
    select 1 from public.quote_requests r where r.id = o.request_id and r.customer_id = uid
  ) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if o.status <> 'pending' then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  update public.quote_offers set status = 'declined' where id = p_offer;
end;
$$;

-- Accepting locks the request first, so two accepts (or an accept and a
-- cancel) can never both win: the second sees the new status and fails.
create or replace function public.accept_offer(p_offer uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  o public.quote_offers;
  r public.quote_requests;
  booking_id uuid;
begin
  select * into o from public.quote_offers where id = p_offer;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  select * into r from public.quote_requests where id = o.request_id for update;
  if r.customer_id <> uid then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if r.status <> 'open' then
    raise exception 'not_open' using errcode = 'P0001';
  end if;
  if r.expires_at <= now() then
    raise exception 'expired' using errcode = 'P0001';
  end if;
  -- Re-read under the request lock: the offer may have been withdrawn meanwhile.
  select * into o from public.quote_offers where id = p_offer for update;
  if o.status <> 'pending' then
    raise exception 'offer_closed' using errcode = 'P0001';
  end if;
  if not exists (
    select 1 from public.professional_profiles where user_id = o.professional_id and is_published
  ) then
    raise exception 'offer_closed' using errcode = 'P0001';
  end if;

  update public.quote_offers set status = 'accepted' where id = p_offer;
  update public.quote_offers set status = 'declined'
   where request_id = r.id and id <> p_offer and status = 'pending';
  update public.quote_requests set status = 'awarded' where id = r.id;
  insert into public.bookings (request_id, offer_id, customer_id, professional_id, price_tnd)
  values (r.id, o.id, r.customer_id, o.professional_id, o.price_tnd)
  returning id into booking_id;
  return booking_id;
end;
$$;

------------------------------------------------------------------------
-- bookings: lifecycle
------------------------------------------------------------------------
-- Moves a booking from one of [p_from] to p_to, only for the allowed party.
create or replace function public._booking_step(
  p_booking uuid, p_from text[], p_to text, p_by_professional boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  b public.bookings;
begin
  select * into b from public.bookings where id = p_booking for update;
  if not found or uid not in (b.customer_id, b.professional_id) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if p_by_professional and uid <> b.professional_id then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not p_by_professional and uid <> b.customer_id then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not (b.status = any (p_from)) then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  update public.bookings set
    status = p_to,
    started_at = case when p_to = 'in_progress' then now() else started_at end,
    done_at = case when p_to = 'pending_confirmation' then now() else done_at end,
    completed_at = case when p_to = 'completed' then now() else completed_at end
  where id = p_booking;
end;
$$;

create or replace function public.start_booking(p_booking uuid)
returns void language sql security definer set search_path = ''
as $$ select public._booking_step(p_booking, array['scheduled'], 'in_progress', true) $$;

create or replace function public.mark_booking_done(p_booking uuid)
returns void language sql security definer set search_path = ''
as $$ select public._booking_step(p_booking, array['in_progress'], 'pending_confirmation', true) $$;

create or replace function public.confirm_booking_completed(p_booking uuid)
returns void language sql security definer set search_path = ''
as $$ select public._booking_step(p_booking, array['pending_confirmation'], 'completed', false) $$;

create or replace function public.cancel_booking(p_booking uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  b public.bookings;
begin
  select * into b from public.bookings where id = p_booking for update;
  if not found or uid not in (b.customer_id, b.professional_id) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if b.status not in ('scheduled', 'in_progress') then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  update public.bookings set status = 'cancelled', cancelled_by = uid, cancelled_at = now()
   where id = p_booking;
end;
$$;

------------------------------------------------------------------------
-- housekeeping (for a scheduled job running as the service role)
------------------------------------------------------------------------
create or replace function public.expire_stale_requests()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n integer;
  ids uuid[];
begin
  -- Lock the requests first (cancel and accept lock requests before offers),
  -- so housekeeping can never deadlock with them.
  select coalesce(array_agg(id), '{}') into ids from (
    select id from public.quote_requests
     where status = 'open' and expires_at <= now()
     order by id for update
  ) locked;
  update public.quote_requests set status = 'expired' where id = any (ids);
  get diagnostics n = row_count;
  update public.quote_offers set status = 'declined'
   where status = 'pending' and request_id = any (ids);
  return n;
end;
$$;

------------------------------------------------------------------------
-- function privileges: signed-in users only; helpers and housekeeping closed
------------------------------------------------------------------------
revoke all on function
  public.create_quote_request(text, text, smallint, smallint, integer, numeric, date),
  public.cancel_quote_request(uuid),
  public.list_open_requests(smallint, smallint, integer, integer),
  public.get_open_request(uuid),
  public.submit_offer(uuid, numeric, text, smallint),
  public.withdraw_offer(uuid),
  public.decline_offer(uuid),
  public.accept_offer(uuid),
  public._booking_step(uuid, text[], text, boolean),
  public.start_booking(uuid),
  public.mark_booking_done(uuid),
  public.confirm_booking_completed(uuid),
  public.cancel_booking(uuid),
  public.expire_stale_requests()
  from public, anon, authenticated;

grant execute on function
  public.create_quote_request(text, text, smallint, smallint, integer, numeric, date),
  public.cancel_quote_request(uuid),
  public.list_open_requests(smallint, smallint, integer, integer),
  public.get_open_request(uuid),
  public.submit_offer(uuid, numeric, text, smallint),
  public.withdraw_offer(uuid),
  public.decline_offer(uuid),
  public.accept_offer(uuid),
  public.start_booking(uuid),
  public.mark_booking_done(uuid),
  public.confirm_booking_completed(uuid),
  public.cancel_booking(uuid)
  to authenticated;

------------------------------------------------------------------------
-- Account deletion: a professional who leaves takes their offers and bookings
-- with them. Requests they had won would be left "awarded" without a booking,
-- so those are cancelled (the customer sees them as cancelled).
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
  delete from storage.objects
   where bucket_id = 'portfolio' and (storage.foldername(name))[1] = uid::text;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon, authenticated;
grant execute on function public.delete_my_account() to authenticated;
