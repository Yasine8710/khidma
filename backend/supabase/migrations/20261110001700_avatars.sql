-- Profile pictures.
--
-- A public `avatars` bucket (one folder per account) and an `avatar_path` on the
-- private profile (the owner's own picture) and on the public professional
-- profile (shown on cards and the profile page). The path is stored, never a
-- URL, so the app builds it from its own storage address and nobody can point a
-- profile at an outside image. Pictures are meant to be public for
-- professionals; customers' pictures are readable only by the customer because
-- profiles are private. Account deletion queues the files for the cleanup
-- worker (SQL cannot delete storage objects).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 1048576, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

alter table public.profiles
  add column avatar_path text
    check (avatar_path ~ '^[0-9a-f-]{36}/avatar-[0-9]{10,14}\.(jpg|jpeg|png|webp)$'
           and split_part(avatar_path, '/', 1) = id::text);
alter table public.professional_profiles
  add column avatar_path text
    check (avatar_path ~ '^[0-9a-f-]{36}/avatar-[0-9]{10,14}\.(jpg|jpeg|png|webp)$'
           and split_part(avatar_path, '/', 1) = user_id::text);

grant update (avatar_path) on public.profiles to authenticated;
grant update (avatar_path) on public.professional_profiles to authenticated;
grant select (avatar_path) on public.professional_profiles to anon, authenticated;

-- Owners write only inside their own folder; anonymous-auth users cannot.
create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') <> 'true'
  );
create policy avatars_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

------------------------------------------------------------------------
-- Account deletion also queues the avatar files.
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
   where (o.bucket_id in ('portfolio', 'verification-docs')
          and (storage.foldername(o.name))[1] = uid::text)
      or (o.bucket_id = 'avatars'
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
