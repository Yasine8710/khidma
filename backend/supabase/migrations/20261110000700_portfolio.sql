-- Portfolio photos of a professional.
--
-- Files live in the public Storage bucket `portfolio` under `<user id>/<file>`;
-- the bucket itself limits size (2 MB) and type (jpeg/png/webp). A row in
-- `portfolio_items` makes a file part of a profile: only the owner writes, and
-- only visible (published or own) profiles show their items. Capped at 12.
--
-- NOTES
-- * Removing a photo: the app deletes the file through the Storage API first,
--   then the row. Deleting an account removes the object rows (below), which
--   also stops the files being served; the leftover bytes need the server-side
--   cleanup tracked in issue #32 (SQL deletes never remove the stored bytes).
-- * The bucket is public: a photo URL stays readable by anyone who already has
--   it, even after the profile is unpublished. URLs are random UUIDs, never
--   listed, and the photos are meant to be shown publicly.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('portfolio', 'portfolio', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create table public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles (user_id) on delete cascade,
  -- `<professional id>/<file name>`: a professional can only point at their own folder.
  path text not null unique
    check (path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,100}\.(jpg|jpeg|png|webp)$'),
  caption text check (char_length(caption) <= 140),
  created_at timestamptz not null default now(),
  check (split_part(path, '/', 1) = professional_id::text)
);
create index portfolio_items_professional_idx
  on public.portfolio_items (professional_id, created_at);

alter table public.portfolio_items enable row level security;
revoke all on table public.portfolio_items from public, anon, authenticated;
grant select on public.portfolio_items to anon, authenticated;
grant insert, delete on public.portfolio_items to authenticated;
grant update (caption) on public.portfolio_items to authenticated;

-- Visible exactly when the professional profile is visible (published, or the
-- caller's own): the subquery runs under that table's own RLS.
create policy portfolio_read on public.portfolio_items
  for select to anon, authenticated
  using (exists (
    select 1 from public.professional_profiles p where p.user_id = professional_id
  ));

create policy portfolio_insert_own on public.portfolio_items
  for insert to authenticated
  with check (
    professional_id = (select auth.uid())
    and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') <> 'true'
  );

create policy portfolio_update_own on public.portfolio_items
  for update to authenticated
  using (professional_id = (select auth.uid()))
  with check (professional_id = (select auth.uid()));

create policy portfolio_delete_own on public.portfolio_items
  for delete to authenticated
  using (professional_id = (select auth.uid()));

create or replace function public.enforce_portfolio_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('portfolio:' || new.professional_id::text, 0));
  if (select count(*) from public.portfolio_items where professional_id = new.professional_id) >= 12 then
    raise exception 'portfolio_limit' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger portfolio_limit
  before insert on public.portfolio_items
  for each row execute function public.enforce_portfolio_limit();

revoke all on function public.enforce_portfolio_limit() from public, anon, authenticated;

------------------------------------------------------------------------
-- Storage policies: a registered user writes only inside their own folder.
-- Reading needs no policy: the bucket is public (files are served by URL).
------------------------------------------------------------------------
-- How many files the caller already has (a policy cannot read its own table
-- directly without recursing, so this definer function does it).
create or replace function public.my_portfolio_file_count()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from storage.objects o
   where o.bucket_id = 'portfolio'
     and (storage.foldername(o.name))[1] = (select auth.uid())::text
$$;

revoke all on function public.my_portfolio_file_count() from public, anon, authenticated;
grant execute on function public.my_portfolio_file_count() to authenticated;

-- Only professionals upload, and at most 16 files at a time (12 photos plus a
-- little room for uploads whose row has not been written yet): the storage
-- cannot be used as free file hosting.
create policy portfolio_files_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'portfolio'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') <> 'true'
    and exists (
      select 1 from public.professional_profiles p where p.user_id = (select auth.uid())
    )
    and (select public.my_portfolio_file_count()) < 16
  );

-- Deleting a row also needs to see it: the owner may see their own folder.
create policy portfolio_files_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'portfolio'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy portfolio_files_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'portfolio'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

------------------------------------------------------------------------
-- Account deletion also removes the person's object rows: Supabase refuses to
-- delete a user who still owns storage objects, and without the rows the files
-- are no longer served.
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
  delete from storage.objects
   where bucket_id = 'portfolio' and (storage.foldername(name))[1] = uid::text;
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon, authenticated;
grant execute on function public.delete_my_account() to authenticated;
