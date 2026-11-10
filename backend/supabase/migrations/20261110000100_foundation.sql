-- Khidma foundation: profiles, roles, geography, categories, professional profiles.
--
-- Security model (read docs/SECURITY.md):
--   * Supabase grants ALL on new public tables to anon/authenticated by default.
--     Every table below first REVOKEs everything, then grants the minimum.
--   * Row Level Security is enabled on every table. Column-level GRANTs protect
--     fields users must not edit (capability flags, verification, ratings).
--   * "admin" is a row in admin_users, never a profile column or JWT metadata, so
--     no UPDATE a user can issue (or sign-up metadata they can send) grants it.
--   * Privileged writes go through SECURITY DEFINER functions with a pinned
--     search_path and EXECUTE granted only to authenticated. They also refuse
--     Supabase anonymous-auth users (JWT is_anonymous), which hold the
--     `authenticated` role but are not registered users.
--   * Contact phone numbers are never selectable; they are revealed one at a
--     time through a rate-limited function (anti-scraping).

------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

------------------------------------------------------------------------
-- geography (public reference data, read-only for clients)
------------------------------------------------------------------------
create table public.governorates (
  id smallint primary key,
  code text not null unique check (code ~ '^TN-[0-9]{2}$'),
  name_fr text not null,
  name_ar text not null,
  name_en text not null
);

create table public.cities (
  id integer generated always as identity primary key,
  governorate_id smallint not null references public.governorates (id) on delete restrict,
  name_fr text not null,
  name_ar text not null,
  name_en text not null,
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  unique (governorate_id, name_fr),
  -- target of composite FKs that keep a city inside its governorate
  unique (id, governorate_id)
);
create index cities_governorate_idx on public.cities (governorate_id);

create table public.neighborhoods (
  id integer generated always as identity primary key,
  city_id integer not null references public.cities (id) on delete restrict,
  name_fr text not null,
  name_ar text not null,
  name_en text not null,
  unique (city_id, name_fr),
  unique (id, city_id)
);
create index neighborhoods_city_idx on public.neighborhoods (city_id);

------------------------------------------------------------------------
-- service categories (manageable by admins)
------------------------------------------------------------------------
create table public.service_categories (
  id smallint generated always as identity primary key,
  slug text not null unique check (slug ~ '^[a-z][a-z0-9-]*$'),
  name_fr text not null,
  name_ar text not null,
  name_en text not null,
  description_fr text not null default '',
  description_ar text not null default '',
  description_en text not null default '',
  icon text not null default 'build',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger service_categories_updated_at
  before update on public.service_categories
  for each row execute function public.set_updated_at();

------------------------------------------------------------------------
-- profiles (one per auth user) and admin membership
------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text check (char_length(full_name) <= 120),
  avatar_url text check (char_length(avatar_url) <= 500),
  -- E.164, private to the owner. Public contact lives on professional_profiles.
  phone text check (phone ~ '^\+216[234579][0-9]{7}$'),
  preferred_language text not null default 'fr' check (preferred_language in ('fr', 'ar', 'en')),
  -- capability flags: a user can be both. Changed only by become_professional().
  is_customer boolean not null default true,
  is_professional boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create table public.admin_users (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.customer_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  default_governorate_id smallint references public.governorates (id),
  default_city_id integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (default_city_id, default_governorate_id)
    references public.cities (id, governorate_id),
  check (default_city_id is null or default_governorate_id is not null)
);
create trigger customer_profiles_updated_at
  before update on public.customer_profiles
  for each row execute function public.set_updated_at();

-- is_admin() is SECURITY DEFINER so policies can ask it without granting any
-- access to admin_users itself.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.admin_users where user_id = (select auth.uid())
  );
$$;

------------------------------------------------------------------------
-- professional profiles
------------------------------------------------------------------------
create table public.professional_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  business_name text check (char_length(business_name) <= 120),
  primary_category_id smallint references public.service_categories (id),
  description text check (char_length(description) <= 2000),
  years_experience smallint check (years_experience between 0 and 60),
  governorate_id smallint references public.governorates (id),
  city_id integer,
  neighborhood_id integer,
  -- Approximate location only: rounded to 2 decimals (~1.1 km) by a trigger, so
  -- a home-based professional is not pinpointed.
  latitude double precision check (latitude between -90 and 90),
  longitude double precision check (longitude between -180 and 180),
  -- Not selectable by any client role. Owners read it with
  -- get_my_professional_contact(); others with reveal_professional_contact().
  contact_phone text check (contact_phone ~ '^\+216[234579][0-9]{7}$'),
  availability text not null default 'available'
    check (availability in ('available', 'busy', 'offline')),
  is_published boolean not null default false,
  -- Set only by admin_set_verification(); owners cannot touch these columns.
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified', 'pending', 'verified', 'rejected')),
  verified_at timestamptz,
  rating_avg numeric(2, 1) not null default 0 check (rating_avg between 0 and 5),
  review_count integer not null default 0 check (review_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (city_id, governorate_id) references public.cities (id, governorate_id),
  foreign key (neighborhood_id, city_id) references public.neighborhoods (id, city_id),
  check ((latitude is null) = (longitude is null)),
  check (city_id is null or governorate_id is not null),
  check (neighborhood_id is null or city_id is not null),
  -- A profile cannot go public half-empty (and a public profile needs a name).
  constraint published_profile_complete check (
    not is_published or (
      -- The public name: profiles are private, so this is the only name shown.
      business_name is not null and char_length(btrim(business_name)) >= 2
      and primary_category_id is not null
      and description is not null and char_length(description) >= 20
      and governorate_id is not null
      and contact_phone is not null
    )
  ),
  check ((verification_status = 'verified') = (verified_at is not null))
);
create index professional_profiles_published_idx
  on public.professional_profiles (governorate_id, primary_category_id)
  where is_published;
create index professional_profiles_city_idx on public.professional_profiles (city_id);

create or replace function public.round_professional_location()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.latitude := round(new.latitude::numeric, 2)::double precision;
  new.longitude := round(new.longitude::numeric, 2)::double precision;
  return new;
end;
$$;
create trigger professional_profiles_round_location
  before insert or update of latitude, longitude on public.professional_profiles
  for each row execute function public.round_professional_location();
create trigger professional_profiles_updated_at
  before update on public.professional_profiles
  for each row execute function public.set_updated_at();

-- A verification covers who the professional is. If the owner changes the
-- business name or the contact phone, the badge is withdrawn until re-verified.
create or replace function public.reset_verification_on_identity_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.verification_status = 'verified'
     and (new.business_name is distinct from old.business_name
          or new.contact_phone is distinct from old.contact_phone) then
    new.verification_status := 'unverified';
    new.verified_at := null;
  end if;
  return new;
end;
$$;
create trigger professional_profiles_reset_verification
  before update on public.professional_profiles
  for each row execute function public.reset_verification_on_identity_change();

-- Categories must be active when assigned or published (RLS hides inactive
-- ones from non-admins, so a plain existence check is enough).
create or replace function public.assert_active_category()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  cat smallint;
begin
  if tg_table_name = 'professional_services' then
    cat := new.category_id;
  else
    cat := new.primary_category_id;
  end if;
  if cat is not null and not exists (
    select 1 from public.service_categories where id = cat and is_active
  ) then
    raise exception 'category is not active' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger professional_profiles_active_category_ins
  before insert on public.professional_profiles
  for each row execute function public.assert_active_category();
create trigger professional_profiles_active_category_upd
  before update on public.professional_profiles
  for each row
  when (
    new.primary_category_id is distinct from old.primary_category_id
    or (new.is_published and not old.is_published)
  )
  execute function public.assert_active_category();

create table public.professional_services (
  professional_id uuid not null references public.professional_profiles (user_id) on delete cascade,
  category_id smallint not null references public.service_categories (id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (professional_id, category_id)
);
create index professional_services_category_idx on public.professional_services (category_id);
create trigger professional_services_active_category
  before insert on public.professional_services
  for each row execute function public.assert_active_category();

create table public.service_areas (
  id bigint generated always as identity primary key,
  professional_id uuid not null references public.professional_profiles (user_id) on delete cascade,
  governorate_id smallint not null references public.governorates (id),
  city_id integer,
  created_at timestamptz not null default now(),
  foreign key (city_id, governorate_id) references public.cities (id, governorate_id)
);
create unique index service_areas_unique_idx
  on public.service_areas (professional_id, governorate_id, coalesce(city_id, 0));
create index service_areas_area_idx on public.service_areas (governorate_id, city_id);

-- Who revealed whose phone, and when. Powers the rate limit; no client access.
create table public.contact_reveals (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  professional_id uuid not null references public.professional_profiles (user_id) on delete cascade,
  created_at timestamptz not null default now()
);
create index contact_reveals_user_time_idx on public.contact_reveals (user_id, created_at desc);

------------------------------------------------------------------------
-- new-user trigger: profile + customer profile
------------------------------------------------------------------------
-- Reads only a display name and a UI language from sign-up metadata (both
-- harmless and validated). Roles, admin and professional flags are NEVER read
-- from metadata, which the user controls.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  lang text := new.raw_user_meta_data ->> 'preferred_language';
begin
  insert into public.profiles (id, full_name, preferred_language)
  values (
    new.id,
    nullif(left(btrim(coalesce(new.raw_user_meta_data ->> 'full_name', '')), 120), ''),
    case when lang in ('fr', 'ar', 'en') then lang else 'fr' end
  );
  insert into public.customer_profiles (user_id) values (new.id);
  return new;
end;
$$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

------------------------------------------------------------------------
-- privileged operations
------------------------------------------------------------------------
-- Returns the caller's user id, or raises. Refuses anonymous-auth users: they
-- have the `authenticated` role but are not registered accounts.
create or replace function public.require_registered_user()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'not authenticated' using errcode = '28000';
  end if;
  if coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') = 'true' then
    raise exception 'registered account required' using errcode = '42501';
  end if;
  return uid;
end;
$$;

-- A signed-in user opts in to being a professional. Idempotent.
create or replace function public.become_professional()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  insert into public.professional_profiles (user_id) values (uid)
    on conflict (user_id) do nothing;
  update public.profiles set is_professional = true where id = uid;
end;
$$;

-- The owner reads their own contact phone (it is not selectable).
create or replace function public.get_my_professional_contact()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  return (select contact_phone from public.professional_profiles where user_id = uid);
end;
$$;

-- Reveals one published professional's phone to a registered user, at most
-- 40 reveals per hour: bulk scraping of the directory is not possible.
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
  -- Serialize this caller's reveals so concurrent requests cannot all pass the
  -- count below (released automatically at the end of the transaction).
  perform pg_advisory_xact_lock(hashtextextended('reveal:' || uid::text, 0));
  if (select count(*) from public.contact_reveals
       where user_id = uid and created_at > now() - interval '1 hour') >= 40 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  select contact_phone into phone
    from public.professional_profiles
   where user_id = p_professional and is_published;
  if phone is null then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  insert into public.contact_reveals (user_id, professional_id) values (uid, p_professional);
  return phone;
end;
$$;

-- Admins set verification. Phase 6 adds the document review workflow in front.
create or replace function public.admin_set_verification(p_user uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;
  if p_status not in ('unverified', 'pending', 'verified', 'rejected') then
    raise exception 'invalid status' using errcode = '22023';
  end if;
  update public.professional_profiles
     set verification_status = p_status,
         verified_at = case when p_status = 'verified' then now() else null end
   where user_id = p_user;
  if not found then
    raise exception 'professional not found' using errcode = 'P0002';
  end if;
end;
$$;

------------------------------------------------------------------------
-- privileges: revoke Supabase's permissive defaults, grant the minimum
------------------------------------------------------------------------
revoke all on table
  public.governorates, public.cities, public.neighborhoods,
  public.service_categories, public.profiles, public.admin_users,
  public.customer_profiles, public.professional_profiles,
  public.professional_services, public.service_areas, public.contact_reveals
  from public, anon, authenticated;

-- Sequences: clients never need them (identity columns are used by definer
-- functions or by service-role migrations). Also stop future ones inheriting
-- Supabase's permissive defaults.
revoke all on all sequences in schema public from public, anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;

revoke all on function
  public.set_updated_at(), public.round_professional_location(),
  public.handle_new_user(), public.is_admin(), public.become_professional(),
  public.admin_set_verification(uuid, text), public.require_registered_user(),
  public.get_my_professional_contact(), public.reveal_professional_contact(uuid),
  public.reset_verification_on_identity_change(), public.assert_active_category()
  from public, anon, authenticated;
grant execute on function public.is_admin() to anon, authenticated;
grant execute on function public.become_professional() to authenticated;
grant execute on function public.admin_set_verification(uuid, text) to authenticated;
grant execute on function public.get_my_professional_contact() to authenticated;
grant execute on function public.reveal_professional_contact(uuid) to authenticated;

-- reference data: everyone reads, nobody writes through the API
grant select on public.governorates, public.cities, public.neighborhoods
  to anon, authenticated;
alter table public.governorates enable row level security;
alter table public.cities enable row level security;
alter table public.neighborhoods enable row level security;
create policy governorates_read on public.governorates for select to anon, authenticated using (true);
create policy cities_read on public.cities for select to anon, authenticated using (true);
create policy neighborhoods_read on public.neighborhoods for select to anon, authenticated using (true);

-- categories: active ones are public; admins edit/delete through the API.
-- There is deliberately NO insert grant: a rejected INSERT still consumes an
-- identity value, so any user could exhaust the smallint sequence. New
-- categories come from migrations / service role (an admin RPC arrives with the
-- admin dashboard, Phase 7).
grant select on public.service_categories to anon, authenticated;
grant update, delete on public.service_categories to authenticated;
alter table public.service_categories enable row level security;
create policy categories_read on public.service_categories
  for select to anon, authenticated
  using (is_active or (select public.is_admin()));
create policy categories_admin_update on public.service_categories
  for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy categories_admin_delete on public.service_categories
  for delete to authenticated using ((select public.is_admin()));

-- profiles: owner-only; only four columns are editable
grant select on public.profiles to authenticated;
grant update (full_name, avatar_url, phone, preferred_language)
  on public.profiles to authenticated;
alter table public.profiles enable row level security;
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- admin_users and contact_reveals: no client access at all (RLS on, no policies, no grants)
alter table public.admin_users enable row level security;
alter table public.contact_reveals enable row level security;

-- customer_profiles: owner-only
grant select on public.customer_profiles to authenticated;
grant update (default_governorate_id, default_city_id)
  on public.customer_profiles to authenticated;
alter table public.customer_profiles enable row level security;
create policy customer_profiles_select_own on public.customer_profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy customer_profiles_update_own on public.customer_profiles
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- professional_profiles: published rows are public (minus contact details for
-- anonymous visitors); owners edit their own limited columns; no direct insert
-- or delete (become_professional() creates, account deletion cascades).
-- contact_phone and verified_at are not readable by any client role.
grant select (
  user_id, business_name, primary_category_id, description, years_experience,
  governorate_id, city_id, neighborhood_id, latitude, longitude, availability,
  is_published, verification_status, rating_avg, review_count, created_at,
  updated_at
) on public.professional_profiles to anon, authenticated;
grant update (
  business_name, primary_category_id, description, years_experience,
  governorate_id, city_id, neighborhood_id, latitude, longitude,
  contact_phone, availability, is_published
) on public.professional_profiles to authenticated;
alter table public.professional_profiles enable row level security;
create policy professional_profiles_read on public.professional_profiles
  for select to anon, authenticated
  using (
    is_published
    or user_id = (select auth.uid())
    or (select public.is_admin())
  );
create policy professional_profiles_update_own on public.professional_profiles
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- professional_services / service_areas: visible exactly when the professional
-- profile is visible (the subquery runs under that table's own RLS)
grant select on public.professional_services, public.service_areas to anon, authenticated;
grant insert, delete on public.professional_services, public.service_areas to authenticated;
alter table public.professional_services enable row level security;
alter table public.service_areas enable row level security;
create policy professional_services_read on public.professional_services
  for select to anon, authenticated
  using (exists (
    select 1 from public.professional_profiles p where p.user_id = professional_id
  ));
create policy professional_services_insert_own on public.professional_services
  for insert to authenticated with check (professional_id = (select auth.uid()));
create policy professional_services_delete_own on public.professional_services
  for delete to authenticated using (professional_id = (select auth.uid()));
create policy service_areas_read on public.service_areas
  for select to anon, authenticated
  using (exists (
    select 1 from public.professional_profiles p where p.user_id = professional_id
  ));
create policy service_areas_insert_own on public.service_areas
  for insert to authenticated with check (professional_id = (select auth.uid()));
create policy service_areas_delete_own on public.service_areas
  for delete to authenticated using (professional_id = (select auth.uid()));
