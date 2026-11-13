-- Remote freelance jobs (#50).
--
-- A remote project is a quote request of kind 'remote': a digital category,
-- a brief, deliverables, a deadline, a budget range and up to 5 reference
-- links, and no place at all. It reuses offers, bookings, chat, reviews and
-- notifications. Freelancers (a visible freelance listing) see and answer
-- remote projects; local lists and screens only ever see local requests.
--
-- An offer on a remote project also says how many revisions are included.
-- The freelancer delivers through `deliver_booking` (a note, an https link
-- and/or files in the private `deliveries` bucket, readable only by the two
-- parties); the booking then waits for the customer, who confirms or asks
-- for one of the included revisions. Khidma holds no money: the parties
-- arrange payment between them (the app says so before an offer is accepted).

------------------------------------------------------------------------
-- requests
------------------------------------------------------------------------
-- Only plain https links (no spaces, no other scheme), at most 300 characters.
create or replace function public._valid_links(p_links text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(bool_and(l ~ '^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/[^[:space:]]*)?$' and char_length(l) <= 300), true)
    from unnest(coalesce(p_links, '{}'::text[])) as l
$$;

alter table public.quote_requests
  add column kind text not null default 'local' check (kind in ('local', 'remote')),
  add column digital_category_id smallint references public.digital_categories (id),
  add column deliverables text check (deliverables is null or char_length(btrim(deliverables)) between 3 and 1000),
  add column budget_max_tnd numeric(10, 3) check (budget_max_tnd is null or (budget_max_tnd >= 0 and budget_max_tnd <= 1000000)),
  add column reference_links text[] not null default '{}';
alter table public.quote_requests alter column category_id drop not null;
alter table public.quote_requests alter column governorate_id drop not null;
alter table public.quote_requests add constraint quote_requests_kind_fields check (
  case kind
    when 'local' then category_id is not null and governorate_id is not null
                      and digital_category_id is null and deliverables is null
                      and budget_max_tnd is null and cardinality(reference_links) = 0
    else digital_category_id is not null and category_id is null
         and governorate_id is null and city_id is null
  end
);
alter table public.quote_requests add constraint quote_requests_budget_range
  check (budget_max_tnd is null or budget_tnd is null or budget_max_tnd >= budget_tnd);
alter table public.quote_requests add constraint quote_requests_links
  check (cardinality(reference_links) <= 5 and public._valid_links(reference_links));
create index quote_requests_remote_open_idx
  on public.quote_requests (digital_category_id, created_at desc) where status = 'open' and kind = 'remote';
grant select (kind, digital_category_id, deliverables, budget_max_tnd, reference_links)
  on public.quote_requests to authenticated;



create or replace function public.create_remote_request(
  p_title text, p_description text, p_digital_category smallint, p_deliverables text,
  p_budget_min numeric default null, p_budget_max numeric default null,
  p_needed_by date default null, p_links text[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  links text[] := coalesce((select array_agg(distinct btrim(l)) from unnest(coalesce(p_links, '{}'::text[])) l
                             where btrim(l) <> ''), '{}');
  new_id uuid;
begin
  if not exists (select 1 from public.customer_profiles where user_id = uid) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  -- same budget as local requests: they share the counters
  perform pg_advisory_xact_lock(hashtextextended('request:' || uid::text, 0));
  if (select count(*) from public.quote_requests
       where customer_id = uid and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  if (select count(*) from public.quote_requests
       where customer_id = uid and status = 'open') >= 10 then
    raise exception 'limit_reached' using errcode = 'P0001';
  end if;
  if (p_needed_by is not null and p_needed_by < public.tunis_today())
     or not exists (select 1 from public.digital_categories where id = p_digital_category and is_active)
     or cardinality(links) > 5 or not public._valid_links(links)
     or (p_budget_min is not null and p_budget_max is not null and p_budget_max < p_budget_min) then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  insert into public.quote_requests
    (customer_id, kind, digital_category_id, title, description, deliverables,
     budget_tnd, budget_max_tnd, needed_by, reference_links)
  values
    (uid, 'remote', p_digital_category, btrim(p_title), btrim(p_description), nullif(btrim(p_deliverables), ''),
     p_budget_min, p_budget_max, p_needed_by, links)
  returning id into new_id;
  return new_id;
end;
$$;

-- The customer's own remote projects.
create or replace function public.my_remote_requests()
returns table (
  id uuid, title text, description text, digital_category_id smallint, deliverables text,
  budget_tnd numeric, budget_max_tnd numeric, needed_by date, reference_links text[],
  status text, expires_at timestamptz, created_at timestamptz, offers_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  return query
  select r.id, r.title, r.description, r.digital_category_id, r.deliverables, r.budget_tnd, r.budget_max_tnd,
         r.needed_by, r.reference_links, r.status, r.expires_at, r.created_at,
         (select count(*)::integer from public.quote_offers o where o.request_id = r.id)
    from public.quote_requests r
   where r.customer_id = uid and r.kind = 'remote'
   order by r.created_at desc
   limit 100;
end;
$$;

-- Freelancers: open remote projects (never who asked), and one project they
-- can see (open, or one they offered on).
create or replace function public._is_freelancer(p_user uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.freelancer_is_visible(p_user)
$$;

create or replace function public.list_remote_requests(
  p_category smallint default null, p_limit integer default 20, p_offset integer default 0
)
returns table (
  id uuid, title text, description text, digital_category_id smallint, deliverables text,
  budget_tnd numeric, budget_max_tnd numeric, needed_by date, reference_links text[],
  status text, created_at timestamptz, expires_at timestamptz, offers_count integer, my_offer_status text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  if not public._is_freelancer(uid) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
  select r.id, r.title, r.description, r.digital_category_id, r.deliverables, r.budget_tnd, r.budget_max_tnd,
         r.needed_by, r.reference_links, r.status, r.created_at, r.expires_at,
         (select count(*)::integer from public.quote_offers o where o.request_id = r.id),
         (select o.status from public.quote_offers o where o.request_id = r.id and o.professional_id = uid)
    from public.quote_requests r
   where r.kind = 'remote' and r.status = 'open' and r.expires_at > now() and r.customer_id <> uid
     and (p_category is null or r.digital_category_id = p_category)
   order by r.created_at desc, r.id
   limit greatest(1, least(coalesce(p_limit, 20), 50))
  offset greatest(0, least(coalesce(p_offset, 0), 5000));
end;
$$;

create or replace function public.get_remote_request(p_request uuid)
returns table (
  id uuid, title text, description text, digital_category_id smallint, deliverables text,
  budget_tnd numeric, budget_max_tnd numeric, needed_by date, reference_links text[],
  status text, created_at timestamptz, expires_at timestamptz, offers_count integer, my_offer_status text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  mine boolean;
begin
  select exists (select 1 from public.quote_offers o where o.request_id = p_request and o.professional_id = uid) into mine;
  if not mine and not public._is_freelancer(uid) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
  select r.id, r.title, r.description, r.digital_category_id, r.deliverables, r.budget_tnd, r.budget_max_tnd,
         r.needed_by, r.reference_links, r.status, r.created_at, r.expires_at,
         (select count(*)::integer from public.quote_offers o where o.request_id = r.id),
         (select o.status from public.quote_offers o where o.request_id = r.id and o.professional_id = uid)
    from public.quote_requests r
   where r.id = p_request and r.kind = 'remote' and r.customer_id <> uid
     and ((r.status = 'open' and r.expires_at > now()) or mine);
end;
$$;

------------------------------------------------------------------------
-- offers: revisions, and who may offer on what
------------------------------------------------------------------------
alter table public.quote_offers
  add column revisions smallint check (revisions is null or revisions between 0 and 20);
grant select (revisions) on public.quote_offers to authenticated;

-- Remote projects take offers from visible freelancers only; local requests
-- keep their own rules (submit_offer checks a published local profile).
create or replace function public.check_offer_kind()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  k text;
begin
  select kind into k from public.quote_requests where id = new.request_id;
  if k = 'remote' and not public._is_freelancer(new.professional_id) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if k = 'local' and new.revisions is not null then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger quote_offers_check_kind
  before insert or update of revisions on public.quote_offers
  for each row execute function public.check_offer_kind();

create or replace function public.submit_remote_offer(
  p_request uuid, p_price numeric, p_days smallint, p_revisions smallint, p_message text default null
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
  if not public._is_freelancer(uid) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select * into r from public.quote_requests where id = p_request for share;
  if not found or r.kind <> 'remote' then
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
  if p_price is null or p_price < 1 or p_price > 1000000
     or p_days is null or p_days < 1 or p_days > 365
     or p_revisions is null or p_revisions < 0 or p_revisions > 20
     or char_length(coalesce(p_message, '')) > 1000 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('offer:' || uid::text, 0));
  select * into existing from public.quote_offers
   where request_id = p_request and professional_id = uid for update;
  if found then
    if existing.status in ('declined', 'accepted') then
      raise exception 'offer_closed' using errcode = 'P0001';
    end if;
    if existing.status = 'withdrawn'
       and (select count(*) from public.quote_offers where professional_id = uid and status = 'pending') >= 50 then
      raise exception 'limit_reached' using errcode = 'P0001';
    end if;
    update public.quote_offers
       set price_tnd = p_price, message = nullif(btrim(p_message), ''), estimated_days = p_days,
           revisions = p_revisions, status = 'pending'
     where id = existing.id
    returning id into offer_id;
    return offer_id;
  end if;
  if (select count(*) from public.quote_offers where professional_id = uid and status = 'pending') >= 50 then
    raise exception 'limit_reached' using errcode = 'P0001';
  end if;
  insert into public.quote_offers (request_id, professional_id, price_tnd, message, estimated_days, revisions)
  values (p_request, uid, p_price, nullif(btrim(p_message), ''), p_days, p_revisions)
  returning id into offer_id;
  return offer_id;
end;
$$;

------------------------------------------------------------------------
-- deliveries
------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('deliveries', 'deliveries', false, 26214400,
        array['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'application/zip', 'video/mp4'])
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create table public.job_deliveries (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  note text check (note is null or char_length(note) <= 1000),
  link text check (link is null or (char_length(link) <= 300 and link ~ '^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/[^[:space:]]*)?$')),
  created_at timestamptz not null default now()
);
create index job_deliveries_booking_idx on public.job_deliveries (booking_id, created_at);
alter table public.job_deliveries enable row level security;
revoke all on table public.job_deliveries from public, anon, authenticated;

create table public.delivery_files (
  delivery_id uuid not null references public.job_deliveries (id) on delete cascade,
  -- `<booking id>/<file name>`
  path text not null unique
    check (path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,100}\.(jpg|jpeg|png|webp|pdf|zip|mp4)$'),
  primary key (delivery_id, path)
);
alter table public.delivery_files enable row level security;
revoke all on table public.delivery_files from public, anon, authenticated;

-- Revisions asked so far on a booking.
alter table public.bookings add column revisions_used smallint not null default 0 check (revisions_used >= 0);

-- The parties of a remote booking, by folder name (the booking id).
create or replace function public.delivery_folder_party(p_folder text, p_writer boolean)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.bookings b join public.quote_requests r on r.id = b.request_id
     where b.id::text = p_folder and r.kind = 'remote'
       and (case when p_writer
                 then b.professional_id = (select auth.uid()) and b.status in ('in_progress', 'pending_confirmation')
                 else (select auth.uid()) in (b.customer_id, b.professional_id) end)
  )
$$;

create or replace function public.delivery_file_count(p_folder text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('deliveries:' || p_folder, 0));
  return (select count(*)::integer from storage.objects o
           where o.bucket_id = 'deliveries' and (storage.foldername(o.name))[1] = p_folder);
end;
$$;

create or replace function public.delivery_file_unattached(p_name text)
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  select not exists (select 1 from public.delivery_files f where f.path = p_name)
$$;

create policy deliveries_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'deliveries'
    and (select public.delivery_folder_party((storage.foldername(name))[1], true))
    and (select public.delivery_file_count((storage.foldername(name))[1])) < 30
  );
create policy deliveries_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'deliveries'
    and (select public.delivery_folder_party((storage.foldername(name))[1], false))
  );
create policy deliveries_delete_unattached on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'deliveries'
    and (select public.delivery_folder_party((storage.foldername(name))[1], true))
    and (select public.delivery_file_unattached(name))
  );

-- The freelancer hands in work; the booking then waits for the customer.
create or replace function public.deliver_booking(
  p_booking uuid, p_note text default null, p_link text default null, p_paths text[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  b public.bookings;
  k text;
  note text := nullif(btrim(p_note), '');
  link text := nullif(btrim(p_link), '');
  paths text[] := coalesce(p_paths, '{}');
  p text;
  new_id uuid;
begin
  select * into b from public.bookings where id = p_booking for update;
  if not found or uid not in (b.customer_id, b.professional_id) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  select kind into k from public.quote_requests where id = b.request_id;
  if uid <> b.professional_id or k <> 'remote' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if b.status not in ('in_progress', 'pending_confirmation') then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  if (note is null and link is null and cardinality(paths) = 0)
     or cardinality(paths) > 10 or (note is not null and char_length(note) > 1000)
     or (link is not null and not public._valid_links(array[link])) then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  foreach p in array paths loop
    if split_part(p, '/', 1) <> p_booking::text
       or not exists (select 1 from storage.objects s where s.bucket_id = 'deliveries' and s.name = p)
       or exists (select 1 from public.delivery_files f where f.path = p) then
      raise exception 'invalid_input' using errcode = 'P0001';
    end if;
  end loop;
  insert into public.job_deliveries (booking_id, note, link) values (p_booking, note, link) returning id into new_id;
  insert into public.delivery_files (delivery_id, path) select new_id, x from unnest(paths) x;
  if b.status = 'in_progress' then
    update public.bookings set status = 'pending_confirmation', done_at = now() where id = p_booking;
  end if;
  return new_id;
end;
$$;

-- The customer asks for one of the included revisions: back to in progress.
create or replace function public.request_revision(p_booking uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  b public.bookings;
  allowed smallint;
  note text := nullif(btrim(p_note), '');
begin
  select * into b from public.bookings where id = p_booking for update;
  if not found or uid not in (b.customer_id, b.professional_id) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if uid <> b.customer_id then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if b.status <> 'pending_confirmation' then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  if note is null or char_length(note) > 1000 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  select coalesce(o.revisions, 0) into allowed from public.quote_offers o where o.id = b.offer_id;
  if b.revisions_used >= allowed then
    raise exception 'limit_reached' using errcode = 'P0001';
  end if;
  update public.bookings
     set status = 'in_progress', revisions_used = revisions_used + 1
   where id = p_booking;
  -- the request lands in the conversation, where the work is discussed
  insert into public.messages (conversation_id, sender_is_customer, body)
  select c.id, true, left(note, 2000) from public.conversations c where c.offer_id = b.offer_id;
end;
$$;

-- Both parties: every delivery with its files (paths in the private bucket).
create or replace function public.booking_deliveries(p_booking uuid)
returns table (id uuid, note text, link text, created_at timestamptz, paths text[], revisions_used smallint, revisions_included smallint)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  b public.bookings;
begin
  select * into b from public.bookings x where x.id = p_booking;
  if not found or uid not in (b.customer_id, b.professional_id) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  return query
  select d.id, d.note, d.link, d.created_at,
         coalesce((select array_agg(f.path order by f.path) from public.delivery_files f where f.delivery_id = d.id), '{}'),
         b.revisions_used,
         (select o.revisions from public.quote_offers o where o.id = b.offer_id)
    from public.job_deliveries d
   where d.booking_id = p_booking
   order by d.created_at, d.id;
end;
$$;

------------------------------------------------------------------------
-- existing functions, adjusted for remote projects
------------------------------------------------------------------------

-- accept_offer: remote offers need a visible freelancer instead of a published local profile
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
  -- local: a published profile; remote: a visible freelance listing
  if not (case (select q.kind from public.quote_requests q where q.id = o.request_id)
            when 'remote' then public._is_freelancer(o.professional_id)
            else exists (select 1 from public.professional_profiles where user_id = o.professional_id and is_published)
          end) then
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

-- local discovery lists local requests only
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
   where r.status = 'open' and r.expires_at > now() and r.customer_id <> uid and r.kind = 'local'
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
   where r.id = p_request and r.customer_id <> uid and r.kind = 'local'
     and (r.status = 'open' and r.expires_at > now()
          or exists (select 1 from public.quote_offers o where o.request_id = r.id and o.professional_id = uid));
end;
$$;

-- the customer's local requests (remote ones: my_remote_requests)
create or replace function public.my_quote_requests()
returns table (
  id uuid, title text, description text, category_id smallint, governorate_id smallint,
  city_id integer, budget_tnd numeric, needed_by date, status text, expires_at timestamptz,
  created_at timestamptz, offers_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  return query
  select r.id, r.title, r.description, r.category_id, r.governorate_id, r.city_id, r.budget_tnd,
         r.needed_by, r.status, r.expires_at, r.created_at,
         (select count(*)::integer from public.quote_offers o where o.request_id = r.id)
    from public.quote_requests r
   where r.customer_id = uid and r.kind = 'local'
   order by r.created_at desc
   limit 100;
end;
$$;
create or replace function public.get_my_quote_request(p_request uuid)
returns table (
  id uuid, title text, description text, category_id smallint, governorate_id smallint,
  city_id integer, budget_tnd numeric, needed_by date, status text, expires_at timestamptz,
  created_at timestamptz, offers_count integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  return query
  select r.id, r.title, r.description, r.category_id, r.governorate_id, r.city_id, r.budget_tnd,
         r.needed_by, r.status, r.expires_at, r.created_at,
         (select count(*)::integer from public.quote_offers o where o.request_id = r.id)
    from public.quote_requests r
   where r.id = p_request and r.customer_id = uid and r.kind = 'local';
end;
$$;

-- account deletion also queues delivery files of the person's jobs (same as 2300 otherwise)
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  alias text := public._my_file_alias_text();
begin
  update public.quote_requests r set status = 'cancelled'
   where r.status = 'awarded'
     and exists (select 1 from public.bookings b where b.request_id = r.id and b.professional_id = uid);
  -- Files are queued (SQL cannot delete storage rows); the worker removes them.
  insert into public.storage_cleanup_queue (bucket_id, name)
  select o.bucket_id, o.name from storage.objects o
   where (o.bucket_id in ('portfolio', 'verification-docs', 'avatars', 'freelance-media', 'payment-proofs')
          and (storage.foldername(o.name))[1] = uid::text)
      or (o.bucket_id = 'request-photos' and alias <> ''
          and (storage.foldername(o.name))[1] = alias)
      or (o.bucket_id = 'deliveries'
          and exists (
            select 1 from public.bookings b
             where b.id::text = (storage.foldername(o.name))[1]
               and uid in (b.customer_id, b.professional_id)))
      or (o.bucket_id = 'chat-images'
          and exists (
            select 1 from public.conversations c
             where c.id::text = (storage.foldername(o.name))[1]
               and uid in (c.customer_id, c.professional_id)))
  on conflict do nothing;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function
  public._valid_links(text[]), public.create_remote_request(text, text, smallint, text, numeric, numeric, date, text[]),
  public.my_remote_requests(), public._is_freelancer(uuid),
  public.list_remote_requests(smallint, integer, integer), public.get_remote_request(uuid),
  public.check_offer_kind(), public.submit_remote_offer(uuid, numeric, smallint, smallint, text),
  public.delivery_folder_party(text, boolean), public.delivery_file_count(text), public.delivery_file_unattached(text),
  public.deliver_booking(uuid, text, text, text[]), public.request_revision(uuid, text), public.booking_deliveries(uuid)
  from public, anon, authenticated;
grant execute on function
  public.create_remote_request(text, text, smallint, text, numeric, numeric, date, text[]),
  public.my_remote_requests(), public.list_remote_requests(smallint, integer, integer), public.get_remote_request(uuid),
  public.submit_remote_offer(uuid, numeric, smallint, smallint, text),
  public.delivery_folder_party(text, boolean), public.delivery_file_count(text), public.delivery_file_unattached(text),
  public.deliver_booking(uuid, text, text, text[]), public.request_revision(uuid, text), public.booking_deliveries(uuid)
  to authenticated;
