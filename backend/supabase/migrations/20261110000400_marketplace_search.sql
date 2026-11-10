-- Marketplace: a public name is required to publish, and one search function
-- that filters, matches text (accent- and Arabic-variant-insensitive), measures
-- distance and sorts, so the logic lives in one tested place.
--
-- SECURITY INVOKER: Row Level Security and column grants of the caller apply,
-- so it can only ever return published profiles and never contact phones. It
-- also filters on `is_published` explicitly so owners and admins do not see
-- their own drafts mixed into public results.

-- Profiles are private, so `business_name` is the only name the public sees: a
-- profile cannot be published without one.
alter table public.professional_profiles drop constraint published_profile_complete;
alter table public.professional_profiles add constraint published_profile_complete check (
  not is_published or (
    business_name is not null and char_length(btrim(business_name)) >= 2
    and primary_category_id is not null
    and description is not null and char_length(description) >= 20
    and governorate_id is not null
    and contact_phone is not null
  )
);

-- Normalizes text for matching: lower case, French accents removed, Arabic
-- diacritics/tatweel removed, and Arabic letter variants unified (alef forms,
-- alef maqsura, taa marbuta, Persian ya/kaf, hamza on waw/ya). The Dart mirror
-- (app/lib/core/format/search_text.dart) must stay identical: both are tested
-- on the shared vectors in backend/tests/vectors/search_normalize.json.
create or replace function public.search_normalize(p_text text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select translate(
    regexp_replace(lower(coalesce(p_text, '')), '[\u064B-\u0652\u0640]', '', 'g'),
    'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœأإآىةیکؤئ',
    'aaaaaaceeeeiiiinooooouuuuyyoااايهيكوي'
  );
$$;

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
      p.latitude, p.longitude, p.availability, p.verification_status,
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

revoke all on function public.search_normalize(text) from public, anon, authenticated;
revoke all on function public.search_professionals(
  text, smallint, smallint, integer, numeric, boolean,
  double precision, double precision, double precision, text, integer, integer
) from public, anon, authenticated;
grant execute on function public.search_normalize(text) to anon, authenticated;
grant execute on function public.search_professionals(
  text, smallint, smallint, integer, numeric, boolean,
  double precision, double precision, double precision, text, integer, integer
) to anon, authenticated;
