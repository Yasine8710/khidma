-- Photos attached to a quote request (the leak, the broken heater...).
--
-- These show the inside of someone's home, so unlike portfolio photos they are
-- PRIVATE: the bucket is not public and files are read through signed URLs.
-- Who may read a photo: the customer who owns the request, and published
-- professionals while the request is open, or while their own offer on it is
-- pending or accepted (not once it was declined or withdrawn).
-- At most 5 photos per request, 2 MB each, jpeg/png/webp.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('request-photos', 'request-photos', false, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create table public.request_photos (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.quote_requests (id) on delete cascade,
  -- `<customer id>/<file name>`
  path text not null unique
    check (path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,100}\.(jpg|jpeg|png|webp)$'),
  created_at timestamptz not null default now()
);
create index request_photos_request_idx on public.request_photos (request_id, created_at);

-- Who may see a request's photos (also used by the storage policy below).
create or replace function public.can_view_request_photos(p_request uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.quote_requests r
     where r.id = p_request
       and (
         r.customer_id = (select auth.uid())
         or (
           exists (select 1 from public.professional_profiles p
                    where p.user_id = (select auth.uid()) and p.is_published)
           and (
             (r.status = 'open' and r.expires_at > now())
             or exists (select 1 from public.quote_offers o
                         where o.request_id = r.id and o.professional_id = (select auth.uid())
                           and o.status in ('pending', 'accepted'))
           )
         )
       )
  )
$$;

-- Does the caller own this request, and is it still open?
create or replace function public.owns_open_request(p_request uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.quote_requests r
     where r.id = p_request and r.customer_id = (select auth.uid()) and r.status = 'open'
  )
$$;

-- A photo of a request that is no longer open is kept as it was: not deletable.
create or replace function public.request_photo_is_locked(p_path text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.request_photos rp
      join public.quote_requests r on r.id = rp.request_id
     where rp.path = p_path and r.status <> 'open'
  )
$$;

-- The caller's own requests (the table itself also shows requests a
-- professional offered on, and hides who asked).
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
   where r.customer_id = uid
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
   where r.id = p_request and r.customer_id = uid;
end;
$$;

revoke all on function
  public.can_view_request_photos(uuid), public.owns_open_request(uuid),
  public.request_photo_is_locked(text), public.my_quote_requests(), public.get_my_quote_request(uuid)
  from public, anon, authenticated;
grant execute on function
  public.can_view_request_photos(uuid), public.owns_open_request(uuid),
  public.request_photo_is_locked(text), public.my_quote_requests(), public.get_my_quote_request(uuid)
  to authenticated;

alter table public.request_photos enable row level security;
revoke all on table public.request_photos from public, anon, authenticated;
grant select, insert, delete on public.request_photos to authenticated;

create policy request_photos_read on public.request_photos
  for select to authenticated
  using ((select public.can_view_request_photos(request_id)));

-- Only the owner, only while the request is open, and only a file in their
-- own folder.
create policy request_photos_insert on public.request_photos
  for insert to authenticated
  with check (
    (select public.owns_open_request(request_id))
    and split_part(path, '/', 1) = (select auth.uid())::text
  );

create policy request_photos_delete on public.request_photos
  for delete to authenticated
  using ((select public.owns_open_request(request_id)));

create or replace function public.enforce_request_photo_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('request-photos:' || new.request_id::text, 0));
  if (select count(*) from public.request_photos where request_id = new.request_id) >= 5 then
    raise exception 'photo_limit' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger request_photos_limit
  before insert on public.request_photos
  for each row execute function public.enforce_request_photo_limit();
revoke all on function public.enforce_request_photo_limit() from public, anon, authenticated;

------------------------------------------------------------------------
-- Storage: the caller's own folder for writing; reading follows the table.
------------------------------------------------------------------------
create or replace function public.my_request_file_count()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from storage.objects o
   where o.bucket_id = 'request-photos'
     and (storage.foldername(o.name))[1] = (select auth.uid())::text
$$;
revoke all on function public.my_request_file_count() from public, anon, authenticated;
grant execute on function public.my_request_file_count() to authenticated;

-- A registered customer uploads into their own folder, at most 60 files in all
-- (10 open requests x 5 photos, plus slack): not free file hosting. The count is
-- a snapshot, so a burst of parallel uploads can overshoot slightly; unattached
-- files are meant to be swept by the server-side cleanup of issue #32.
create policy request_files_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'request-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') <> 'true'
    and exists (select 1 from public.customer_profiles c where c.user_id = (select auth.uid()))
    and (select public.my_request_file_count()) < 60
  );

create policy request_files_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'request-photos'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or exists (
        select 1 from public.request_photos rp
         where rp.path = name and (select public.can_view_request_photos(rp.request_id))
      )
    )
  );

create policy request_files_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'request-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and not (select public.request_photo_is_locked(name))
  );

------------------------------------------------------------------------
-- Account deletion clears both buckets' object rows (see the portfolio
-- migration for why) before removing the account.
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
   where bucket_id in ('portfolio', 'request-photos')
     and (storage.foldername(name))[1] = uid::text;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon, authenticated;
grant execute on function public.delete_my_account() to authenticated;
