-- Read and write functions behind the admin dashboard (admin/).
--
-- Every function checks is_admin() first and runs as definer, so the dashboard
-- needs no table access of its own. Lists are paged and capped; searching
-- never reveals more than the dashboard shows (no phone numbers, no message
-- bodies; reading a conversation stays a separate, audited action).

------------------------------------------------------------------------
-- Admins need a second factor.
--
-- With `require_mfa` on (the default), is_admin() is true only for a session
-- that passed the TOTP check (JWT claim aal = 'aal2'), so a stolen password
-- alone opens nothing, in the dashboard or through the API. Admins enroll a
-- TOTP factor in the dashboard on first sign-in. The flag exists for local
-- development and tests; switching it off in production is an owner decision.
------------------------------------------------------------------------
create table public.admin_config (
  singleton boolean primary key default true check (singleton),
  require_mfa boolean not null default true
);
insert into public.admin_config default values;
alter table public.admin_config enable row level security;
revoke all on table public.admin_config from public, anon, authenticated;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users where user_id = (select auth.uid())
  ) and (
    not (select c.require_mfa from public.admin_config c)
    or coalesce((select auth.jwt()) ->> 'aal', 'aal1') = 'aal2'
  );
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

create or replace function public._require_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
end;
$$;

create or replace function public._page(p_limit integer, p_default integer default 50)
returns integer
language sql
immutable
set search_path = ''
as $$ select greatest(1, least(coalesce(p_limit, p_default), 200)) $$;

------------------------------------------------------------------------
-- overview counters
------------------------------------------------------------------------
create or replace function public.admin_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public._require_admin();
  return jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'customers', (select count(*) from public.profiles where is_customer),
    'professionals', (select count(*) from public.professional_profiles),
    'published', (select count(*) from public.professional_profiles where is_published),
    'verified', (select count(*) from public.professional_profiles where verification_status = 'verified'),
    'suspended', (select count(*) from public.professional_profiles where suspended),
    'pending_verifications', (select count(*) from public.verification_requests where status = 'pending'),
    'open_reports', (select count(*) from public.reports where status in ('open', 'reviewing')),
    'open_requests', (select count(*) from public.quote_requests where status = 'open'),
    'bookings', (select coalesce(jsonb_object_agg(status, n), '{}'::jsonb)
                   from (select status, count(*) as n from public.bookings group by status) b),
    'reviews', (select count(*) from public.reviews where about_professional and status = 'published'),
    'hidden_reviews', (select count(*) from public.reviews where status = 'hidden'),
    'cleanup_queue', (select count(*) from public.storage_cleanup_queue)
  );
end;
$$;

-- New sign-ups, requests and completed jobs per day (UTC), last p_days days.
create or replace function public.admin_stats_daily(p_days integer default 30)
returns table (day date, signups integer, requests integer, completed_jobs integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  n integer := greatest(1, least(coalesce(p_days, 30), 180));
begin
  perform public._require_admin();
  return query
  select d::date,
         (select count(*)::integer from public.profiles p where p.created_at::date = d::date),
         (select count(*)::integer from public.quote_requests r where r.created_at::date = d::date),
         (select count(*)::integer from public.bookings b where b.completed_at::date = d::date)
    from generate_series((now() at time zone 'utc')::date - (n - 1), (now() at time zone 'utc')::date, interval '1 day') d
   order by d;
end;
$$;

------------------------------------------------------------------------
-- lists
------------------------------------------------------------------------
create or replace function public.admin_list_users(p_query text default null, p_limit integer default 50, p_offset integer default 0)
returns table (id uuid, full_name text, is_customer boolean, is_professional boolean, is_admin boolean, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  q text := nullif(btrim(p_query), '');
begin
  perform public._require_admin();
  return query
  select p.id, p.full_name, p.is_customer, p.is_professional,
         exists (select 1 from public.admin_users a where a.user_id = p.id), p.created_at
    from public.profiles p
   where q is null or p.full_name ilike '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
      or p.id::text = q
   order by p.created_at desc, p.id
   limit public._page(p_limit)
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

create or replace function public.admin_list_professionals(p_query text default null, p_filter text default 'all', p_limit integer default 50, p_offset integer default 0)
returns table (user_id uuid, business_name text, is_published boolean, verification_status text, suspended boolean,
               rating_avg numeric, review_count integer, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  q text := nullif(btrim(p_query), '');
begin
  perform public._require_admin();
  if p_filter not in ('all', 'published', 'unpublished', 'verified', 'pending', 'suspended') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  return query
  select p.user_id, p.business_name, p.is_published, p.verification_status, p.suspended,
         p.rating_avg, p.review_count, p.created_at
    from public.professional_profiles p
   where (q is null or p.business_name ilike '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%'
          or p.user_id::text = q)
     and case p_filter
           when 'published' then p.is_published
           when 'unpublished' then not p.is_published
           when 'verified' then p.verification_status = 'verified'
           when 'pending' then p.verification_status = 'pending'
           when 'suspended' then p.suspended
           else true
         end
   order by p.created_at desc, p.user_id
   limit public._page(p_limit)
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

create or replace function public.admin_list_requests(p_status text default null, p_limit integer default 50, p_offset integer default 0)
returns table (id uuid, title text, status text, category_id smallint, governorate_id smallint, offers integer, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public._require_admin();
  if p_status is not null and p_status not in ('open', 'awarded', 'cancelled', 'expired') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  return query
  select r.id, r.title, r.status, r.category_id, r.governorate_id,
         (select count(*)::integer from public.quote_offers o where o.request_id = r.id), r.created_at
    from public.quote_requests r
   where p_status is null or r.status = p_status
   order by r.created_at desc, r.id
   limit public._page(p_limit)
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

create or replace function public.admin_list_reviews(p_status text default 'published', p_limit integer default 50, p_offset integer default 0)
returns table (id uuid, subject_id uuid, about_professional boolean, rating smallint, comment text, status text, created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public._require_admin();
  if p_status not in ('published', 'hidden') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  return query
  select r.id, r.subject_id, r.about_professional, r.rating, r.comment, r.status, r.created_at
    from public.reviews r
   where r.status = p_status
   order by r.created_at desc, r.id
   limit public._page(p_limit)
  offset greatest(0, coalesce(p_offset, 0));
end;
$$;

------------------------------------------------------------------------
-- categories (audited)
------------------------------------------------------------------------
create or replace function public.admin_upsert_category(
  p_id smallint, p_slug text, p_name_fr text, p_name_ar text, p_name_en text,
  p_icon text default 'build', p_sort_order integer default 0, p_active boolean default true
)
returns smallint
language plpgsql
security definer
set search_path = ''
as $$
declare
  result smallint;
begin
  perform public._require_admin();
  if p_slug is null or p_slug !~ '^[a-z][a-z0-9-]*$' or char_length(p_slug) > 60
     or nullif(btrim(p_name_fr), '') is null or nullif(btrim(p_name_ar), '') is null or nullif(btrim(p_name_en), '') is null
     or char_length(p_name_fr) > 80 or char_length(p_name_ar) > 80 or char_length(p_name_en) > 80
     or p_icon is null or char_length(p_icon) > 40 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  if p_id is null then
    insert into public.service_categories (slug, name_fr, name_ar, name_en, icon, sort_order, is_active)
    values (p_slug, btrim(p_name_fr), btrim(p_name_ar), btrim(p_name_en), p_icon, coalesce(p_sort_order, 0), coalesce(p_active, true))
    returning id into result;
  else
    update public.service_categories
       set slug = p_slug, name_fr = btrim(p_name_fr), name_ar = btrim(p_name_ar), name_en = btrim(p_name_en),
           icon = p_icon, sort_order = coalesce(p_sort_order, sort_order), is_active = coalesce(p_active, is_active),
           updated_at = now()
     where id = p_id
     returning id into result;
    if result is null then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  end if;
  perform public._audit(case when p_id is null then 'category_created' else 'category_updated' end,
                        'category', result::text, p_slug);
  return result;
exception when unique_violation then
  raise exception 'invalid_input' using errcode = 'P0001';
end;
$$;

-- Category changes go through admin_upsert_category only (audited): the direct
-- UPDATE/DELETE grants and policies of the foundation migration are removed.
-- (Retire a category by deactivating it.)
revoke update, delete on table public.service_categories from authenticated;
drop policy categories_admin_update on public.service_categories;
drop policy categories_admin_delete on public.service_categories;

revoke all on function
  public._require_admin(), public._page(integer, integer), public.admin_overview(),
  public.admin_stats_daily(integer), public.admin_list_users(text, integer, integer),
  public.admin_list_professionals(text, text, integer, integer),
  public.admin_list_requests(text, integer, integer), public.admin_list_reviews(text, integer, integer),
  public.admin_upsert_category(smallint, text, text, text, text, text, integer, boolean)
  from public, anon, authenticated;
grant execute on function
  public.admin_overview(), public.admin_stats_daily(integer), public.admin_list_users(text, integer, integer),
  public.admin_list_professionals(text, text, integer, integer),
  public.admin_list_requests(text, integer, integer), public.admin_list_reviews(text, integer, integer),
  public.admin_upsert_category(smallint, text, text, text, text, text, integer, boolean)
  to authenticated;
