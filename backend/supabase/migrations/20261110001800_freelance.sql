-- Freelance digital services (issues #47-#51).
--
-- A second, separate directory next to the local trades: developers, designers,
-- video editors, marketers... Remote work, no location. One account can hold a
-- local professional profile AND a freelancer profile: the freelancer profile
-- hangs off the professional profile, so there is ONE identity verification
-- (shared) and one contact number. A freelancer is public only when the owner
-- published it AND the identity is verified AND the account is not suspended.
--
-- Pieces: digital_categories, freelancer_profiles, freelancer_portfolio_items
-- (photos, short uploaded clips, YouTube/Vimeo links, plain links),
-- testimonials collected through one-time invite links (past clients who never
-- used Khidma), reporting of both, and an extended account deletion.

------------------------------------------------------------------------
-- digital categories (separate from the local trades: no impact on them)
------------------------------------------------------------------------
create table public.digital_categories (
  id smallint generated always as identity primary key,
  slug text not null unique check (slug ~ '^[a-z][a-z0-9-]*$'),
  name_fr text not null,
  name_ar text not null,
  name_en text not null,
  icon text not null default 'laptop',
  sort_order integer not null default 0,
  is_active boolean not null default true
);
insert into public.digital_categories (slug, name_fr, name_ar, name_en, icon, sort_order) values
  ('web-development',    'Développement web',            'تطوير المواقع',          'Web development',        'code',        10),
  ('mobile-development', 'Développement mobile',         'تطوير تطبيقات الجوال',   'Mobile app development', 'phone_iphone', 20),
  ('design',             'Design graphique et UI/UX',    'التصميم الغرافيكي وUI/UX','Graphic and UI/UX design', 'brush',       30),
  ('video-editing',      'Montage vidéo',                'مونتاج الفيديو',         'Video editing',          'movie',       40),
  ('marketing',          'Marketing digital',            'التسويق الرقمي',         'Digital marketing',      'campaign',    50),
  ('content-writing',    'Rédaction et traduction',      'الكتابة والترجمة',       'Writing and translation','edit_note',   60),
  ('photo-audio',        'Photo, audio et animation',    'التصوير والصوت والرسوم المتحركة', 'Photo, audio and animation', 'photo_camera', 70),
  ('other-digital',      'Autres services digitaux',     'خدمات رقمية أخرى',       'Other digital services', 'devices',     90);

alter table public.digital_categories enable row level security;
revoke all on table public.digital_categories from public, anon, authenticated;
grant select on public.digital_categories to anon, authenticated;
create policy digital_categories_read on public.digital_categories
  for select to anon, authenticated using (is_active);

------------------------------------------------------------------------
-- freelancer profiles
------------------------------------------------------------------------
create table public.freelancer_profiles (
  user_id uuid primary key references public.professional_profiles (user_id) on delete cascade,
  display_name text check (char_length(display_name) between 2 and 80),
  headline text check (char_length(headline) between 5 and 100),
  bio text check (char_length(bio) <= 2000),
  primary_category_id smallint references public.digital_categories (id),
  skills text[] not null default '{}' check (cardinality(skills) <= 12),
  languages text[] not null default '{}' check (cardinality(languages) <= 6),
  years_experience smallint check (years_experience between 0 and 60),
  -- Indicative starting price in millimes (1 TND = 1000 millimes); null = on quote.
  starting_price_millimes integer check (starting_price_millimes between 0 and 100000000),
  price_unit text not null default 'project' check (price_unit in ('project', 'hour', 'day')),
  availability text not null default 'available' check (availability in ('available', 'busy', 'offline')),
  is_published boolean not null default false,
  rating_avg numeric(2, 1) not null default 0 check (rating_avg between 0 and 5),
  review_count integer not null default 0 check (review_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint freelancer_published_complete check (
    not is_published or (
      display_name is not null and headline is not null
      and primary_category_id is not null
      and bio is not null and char_length(bio) >= 20
    )
  )
);
create index freelancer_profiles_category_idx
  on public.freelancer_profiles (primary_category_id) where is_published;
create trigger freelancer_profiles_updated_at
  before update on public.freelancer_profiles
  for each row execute function public.set_updated_at();

-- Short, clean values only: skills and languages are trimmed, empty ones
-- dropped, each at most 30 characters.
-- Publishing needs a verified identity, a contact number and no suspension.
create or replace function public.guard_freelancer_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  p record;
begin
  new.skills := coalesce((
    select array_agg(s) from (
      select distinct btrim(x) as s from unnest(new.skills) as x
       where btrim(x) <> '' and char_length(btrim(x)) <= 30
       limit 12
    ) t), '{}');
  new.languages := coalesce((
    select array_agg(s) from (
      select distinct btrim(x) as s from unnest(new.languages) as x
       where btrim(x) <> '' and char_length(btrim(x)) <= 30
       limit 6
    ) t), '{}');
  if new.is_published then
    select verification_status, suspended, contact_phone into p
      from public.professional_profiles where user_id = new.user_id;
    if p.suspended then
      raise exception 'suspended' using errcode = 'P0001';
    end if;
    if p.verification_status is distinct from 'verified' then
      raise exception 'not_verified' using errcode = 'P0001';
    end if;
    if p.contact_phone is null then
      raise exception 'incomplete' using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;
create trigger freelancer_profiles_guard
  before insert or update on public.freelancer_profiles
  for each row execute function public.guard_freelancer_profile();

-- Public = published + verified + not suspended. Owners always see their own.
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
       and p.verification_status = 'verified' and not p.suspended
  )
$$;

alter table public.freelancer_profiles enable row level security;
revoke all on table public.freelancer_profiles from public, anon, authenticated;
grant select (
  user_id, display_name, headline, bio, primary_category_id, skills, languages,
  years_experience, starting_price_millimes, price_unit, availability,
  is_published, rating_avg, review_count, created_at
) on public.freelancer_profiles to anon, authenticated;
grant update (
  display_name, headline, bio, primary_category_id, skills, languages,
  years_experience, starting_price_millimes, price_unit, availability, is_published
) on public.freelancer_profiles to authenticated;
create policy freelancer_profiles_read on public.freelancer_profiles
  for select to anon, authenticated
  using (public.freelancer_is_visible(user_id) or user_id = (select auth.uid()));
create policy freelancer_profiles_update_own on public.freelancer_profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Creates the freelancer profile (and the professional profile it hangs off).
create or replace function public.become_freelancer()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  perform public.become_professional();
  insert into public.freelancer_profiles (user_id) values (uid) on conflict do nothing;
end;
$$;

-- A visitor may read the phone of a visible freelancer, like for local trades:
-- registered users only, at most 40 reveals per hour.
create or replace function public.reveal_freelancer_contact(p_freelancer uuid)
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
  if not public.freelancer_is_visible(p_freelancer) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  select contact_phone into phone
    from public.professional_profiles where user_id = p_freelancer;
  if phone is null then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  insert into public.contact_reveals (user_id, professional_id) values (uid, p_freelancer);
  return phone;
end;
$$;

------------------------------------------------------------------------
-- portfolio: photos, short clips, video links, plain links
------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('freelance-media', 'freelance-media', true, 26214400,
        array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/webm'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create table public.freelancer_portfolio_items (
  id uuid primary key default gen_random_uuid(),
  freelancer_id uuid not null references public.freelancer_profiles (user_id) on delete cascade,
  kind text not null check (kind in ('image', 'video_file', 'video_link', 'link')),
  title text not null check (char_length(btrim(title)) between 2 and 100),
  description text check (char_length(description) <= 500),
  -- `<freelancer id>/<uuid>.<ext>` for uploaded files.
  path text check (path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(jpg|jpeg|png|webp|mp4|webm)$'),
  -- https only; video links only from YouTube and Vimeo.
  url text check (char_length(url) <= 300),
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  check (path is null or split_part(path, '/', 1) = freelancer_id::text),
  check (
    (kind = 'image' and path ~ '\.(jpg|jpeg|png|webp)$' and url is null)
    or (kind = 'video_file' and path ~ '\.(mp4|webm)$' and url is null)
    or (kind = 'video_link' and path is null and url ~
        '^https://(www\.)?(youtube\.com/watch\?v=[A-Za-z0-9_-]{6,20}|youtu\.be/[A-Za-z0-9_-]{6,20}|vimeo\.com/[0-9]{5,12})([&?][A-Za-z0-9=_&.-]*)?$')
    or (kind = 'link' and path is null and url ~ '^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/[^[:space:]]*)?$')
  )
);
create unique index freelancer_portfolio_path_idx on public.freelancer_portfolio_items (path) where path is not null;
create index freelancer_portfolio_owner_idx on public.freelancer_portfolio_items (freelancer_id, sort_order, created_at);

create or replace function public.enforce_freelancer_portfolio_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('fportfolio:' || new.freelancer_id::text, 0));
  if (select count(*) from public.freelancer_portfolio_items where freelancer_id = new.freelancer_id) >= 24 then
    raise exception 'limit_reached' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger freelancer_portfolio_limit
  before insert on public.freelancer_portfolio_items
  for each row execute function public.enforce_freelancer_portfolio_limit();

alter table public.freelancer_portfolio_items enable row level security;
revoke all on table public.freelancer_portfolio_items from public, anon, authenticated;
grant select on public.freelancer_portfolio_items to anon, authenticated;
grant insert, delete on public.freelancer_portfolio_items to authenticated;
grant update (title, description, sort_order) on public.freelancer_portfolio_items to authenticated;
create policy freelancer_portfolio_read on public.freelancer_portfolio_items
  for select to anon, authenticated
  using (public.freelancer_is_visible(freelancer_id) or freelancer_id = (select auth.uid()));
create policy freelancer_portfolio_insert_own on public.freelancer_portfolio_items
  for insert to authenticated
  with check (
    freelancer_id = (select auth.uid())
    and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') <> 'true'
  );
create policy freelancer_portfolio_update_own on public.freelancer_portfolio_items
  for update to authenticated
  using (freelancer_id = (select auth.uid()))
  with check (freelancer_id = (select auth.uid()));
create policy freelancer_portfolio_delete_own on public.freelancer_portfolio_items
  for delete to authenticated
  using (freelancer_id = (select auth.uid()));

-- Files: only freelancers upload, inside their own folder, at most 40 files.
create or replace function public.my_freelance_file_count()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from storage.objects o
   where o.bucket_id = 'freelance-media'
     and (storage.foldername(o.name))[1] = (select auth.uid())::text
$$;
create policy freelance_files_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'freelance-media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') <> 'true'
    and exists (select 1 from public.freelancer_profiles f where f.user_id = (select auth.uid()))
    and (select public.my_freelance_file_count()) < 40
  );
create policy freelance_files_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'freelance-media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy freelance_files_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'freelance-media'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

------------------------------------------------------------------------
-- testimonials through one-time invite links
------------------------------------------------------------------------
-- A past client who never used Khidma follows a link the freelancer sent and
-- writes feedback. It is shown as a "client testimonial", never as a verified
-- review of a job done on Khidma. Only the SHA-256 of the token is stored.
create table public.freelancer_invites (
  id uuid primary key default gen_random_uuid(),
  freelancer_id uuid not null references public.freelancer_profiles (user_id) on delete cascade,
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  label text check (char_length(label) <= 100),
  expires_at timestamptz not null default now() + interval '30 days',
  used_at timestamptz,
  created_at timestamptz not null default now()
);
create index freelancer_invites_owner_idx on public.freelancer_invites (freelancer_id, created_at desc);
alter table public.freelancer_invites enable row level security;
revoke all on table public.freelancer_invites from public, anon, authenticated;
grant select (id, freelancer_id, label, expires_at, used_at, created_at)
  on public.freelancer_invites to authenticated;
grant delete on public.freelancer_invites to authenticated;
create policy freelancer_invites_select_own on public.freelancer_invites
  for select to authenticated using (freelancer_id = (select auth.uid()));
create policy freelancer_invites_delete_own on public.freelancer_invites
  for delete to authenticated using (freelancer_id = (select auth.uid()));

create table public.testimonials (
  id uuid primary key default gen_random_uuid(),
  freelancer_id uuid not null references public.freelancer_profiles (user_id) on delete cascade,
  invite_id uuid unique references public.freelancer_invites (id) on delete set null,
  author_name text not null check (char_length(author_name) between 2 and 60),
  project_title text check (char_length(project_title) <= 100),
  rating smallint not null check (rating between 1 and 5),
  body text not null check (char_length(body) between 10 and 1000),
  status text not null default 'published' check (status in ('published', 'hidden')),
  moderation_note text check (char_length(moderation_note) <= 500),
  created_at timestamptz not null default now()
);
create index testimonials_freelancer_idx on public.testimonials (freelancer_id, created_at desc);
alter table public.testimonials enable row level security;
revoke all on table public.testimonials from public, anon, authenticated;
grant select (id, freelancer_id, author_name, project_title, rating, body, status, created_at)
  on public.testimonials to anon, authenticated;
-- The freelancer cannot edit or remove a testimonial: only admins hide one.
create policy testimonials_read on public.testimonials
  for select to anon, authenticated
  using (
    (status = 'published' and public.freelancer_is_visible(freelancer_id))
    or freelancer_id = (select auth.uid())
  );

create or replace function public.refresh_freelancer_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  fid uuid := coalesce(new.freelancer_id, old.freelancer_id);
begin
  update public.freelancer_profiles f
     set rating_avg = coalesce((select round(avg(rating)::numeric, 1) from public.testimonials
                                 where freelancer_id = fid and status = 'published'), 0),
         review_count = (select count(*) from public.testimonials
                          where freelancer_id = fid and status = 'published')
   where f.user_id = fid;
  return null;
end;
$$;
create trigger testimonials_rating
  after insert or update of status on public.testimonials
  for each row execute function public.refresh_freelancer_rating();

create or replace function public.create_testimonial_invite(p_label text default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  token text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  label text := nullif(btrim(p_label), '');
begin
  if not exists (select 1 from public.freelancer_profiles where user_id = uid) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if label is not null and char_length(label) > 100 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('invite:' || uid::text, 0));
  if (select count(*) from public.freelancer_invites
       where freelancer_id = uid and used_at is null and expires_at > now()) >= 20 then
    raise exception 'limit_reached' using errcode = 'P0001';
  end if;
  insert into public.freelancer_invites (freelancer_id, token_hash, label)
  values (uid, encode(sha256(convert_to(token, 'UTF8')), 'hex'), label);
  return token;
end;
$$;

-- Callable by anyone holding a valid token (no account needed): single use,
-- expires, and every failure looks the same so tokens cannot be probed.
create or replace function public.submit_testimonial(
  p_token text, p_name text, p_rating smallint, p_body text, p_project text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  inv public.freelancer_invites;
  nm text := btrim(p_name);
  bd text := btrim(p_body);
  pj text := nullif(btrim(p_project), '');
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$'
     or nm is null or char_length(nm) not between 2 and 60
     or bd is null or char_length(bd) not between 10 and 1000
     or p_rating is null or p_rating not between 1 and 5
     or (pj is not null and char_length(pj) > 100) then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  select * into inv from public.freelancer_invites
   where token_hash = encode(sha256(convert_to(p_token, 'UTF8')), 'hex')
   for update;
  if not found or inv.used_at is not null or inv.expires_at <= now()
     or not public.freelancer_is_visible(inv.freelancer_id) then
    raise exception 'invalid_token' using errcode = 'P0001';
  end if;
  insert into public.testimonials (freelancer_id, invite_id, author_name, project_title, rating, body)
  values (inv.freelancer_id, inv.id, nm, coalesce(pj, inv.label), p_rating, bd);
  update public.freelancer_invites set used_at = now() where id = inv.id;
end;
$$;

-- Admins hide (or restore) a testimonial.
create or replace function public.admin_set_testimonial_status(p_id uuid, p_status text, p_note text default null)
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
  if p_status not in ('published', 'hidden') then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  update public.testimonials set status = p_status, moderation_note = left(p_note, 500) where id = p_id;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  perform public._audit('testimonial_' || p_status, 'testimonial', p_id::text, p_note);
end;
$$;

------------------------------------------------------------------------
-- reporting: freelancers and testimonials can be reported too
------------------------------------------------------------------------
alter table public.reports drop constraint reports_target_type_check;
alter table public.reports add constraint reports_target_type_check
  check (target_type in ('professional', 'review', 'conversation', 'freelancer', 'testimonial'));

create or replace function public.report_content(p_type text, p_target uuid, p_reason text, p_details text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  new_id uuid;
  body text := nullif(btrim(p_details), '');
begin
  if p_type not in ('professional', 'review', 'conversation', 'freelancer', 'testimonial')
     or p_reason not in ('spam', 'fake', 'abuse', 'scam', 'inappropriate', 'other')
     or (body is not null and char_length(body) > 500) then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  -- What can be reported is what the reporter can legitimately see.
  if p_type = 'professional' then
    if p_target = uid or not exists (
      select 1 from public.professional_profiles p where p.user_id = p_target and p.is_published
    ) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  elsif p_type = 'freelancer' then
    if p_target = uid or not public.freelancer_is_visible(p_target) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  elsif p_type = 'testimonial' then
    if not exists (
      select 1 from public.testimonials t
       where t.id = p_target and t.status = 'published'
         and public.freelancer_is_visible(t.freelancer_id) and t.freelancer_id <> uid
    ) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  elsif p_type = 'review' then
    if not exists (
      select 1 from public.reviews r
       where r.id = p_target and r.status = 'published' and r.about_professional and r.author_id <> uid
    ) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  else
    if not public.is_conversation_member(p_target) then
      raise exception 'not found' using errcode = 'P0002';
    end if;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('report:' || uid::text, 0));
  if (select count(*) from public.reports where reporter_id = uid and created_at > now() - interval '24 hours') >= 10 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.reports
              where reporter_id = uid and target_type = p_type and target_id = p_target
                and status in ('open', 'reviewing')) then
    raise exception 'already_reported' using errcode = 'P0001';
  end if;
  insert into public.reports (reporter_id, target_type, target_id, reason, details)
  values (uid, p_type, p_target, p_reason, body)
  returning id into new_id;
  return new_id;
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
  else
    select jsonb_build_object('messages', coalesce(jsonb_agg(m order by m.id), '[]'::jsonb)) into ctx
      from (select id, sender_is_customer, body, image_path, created_at
              from public.messages where conversation_id = r.target_id order by id desc limit 50) m;
    perform public._audit('read_conversation', 'report', p_report::text);
  end if;
  return coalesce(ctx, '{}'::jsonb);
end;
$$;

------------------------------------------------------------------------
-- grants for the functions above
------------------------------------------------------------------------
revoke all on function
  public.guard_freelancer_profile(), public.freelancer_is_visible(uuid), public.become_freelancer(),
  public.reveal_freelancer_contact(uuid), public.enforce_freelancer_portfolio_limit(),
  public.my_freelance_file_count(), public.refresh_freelancer_rating(),
  public.create_testimonial_invite(text), public.submit_testimonial(text, text, smallint, text, text),
  public.admin_set_testimonial_status(uuid, text, text)
  from public, anon, authenticated;
-- RLS policies call freelancer_is_visible as the reader.
grant execute on function public.freelancer_is_visible(uuid) to anon, authenticated;
grant execute on function public.my_freelance_file_count() to authenticated;
grant execute on function
  public.become_freelancer(), public.reveal_freelancer_contact(uuid),
  public.create_testimonial_invite(text), public.admin_set_testimonial_status(uuid, text, text)
  to authenticated;
grant execute on function public.submit_testimonial(text, text, smallint, text, text) to anon, authenticated;

------------------------------------------------------------------------
-- account deletion also queues the freelance files
------------------------------------------------------------------------
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
   where (o.bucket_id in ('portfolio', 'verification-docs', 'avatars', 'freelance-media')
          and (storage.foldername(o.name))[1] = uid::text)
      or (o.bucket_id = 'request-photos' and alias <> ''
          and (storage.foldername(o.name))[1] = alias)
      or (o.bucket_id = 'chat-images'
          and exists (
            select 1 from public.conversations c
             where c.id::text = (storage.foldername(o.name))[1]
               and uid in (c.customer_id, c.professional_id)))
  on conflict do nothing;
  delete from auth.users where id = uid;
end;
$$;
revoke all on function public.delete_my_account() from public, anon, authenticated;
grant execute on function public.delete_my_account() to authenticated;
