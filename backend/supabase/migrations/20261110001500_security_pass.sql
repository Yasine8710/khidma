-- Findings of the full security pass (issue #30).

------------------------------------------------------------------------
-- 1. Request photos must not reveal the customer's account id.
--
-- Files used to live in a folder named after the customer's user id, and any
-- published professional can read the `path` of a request photo, which would
-- link a customer's requests together and to their account. Folders now use a
-- random alias that only the customer can read.
------------------------------------------------------------------------
alter table public.customer_profiles add column file_alias uuid not null default gen_random_uuid();
alter table public.customer_profiles add constraint customer_profiles_file_alias_key unique (file_alias);
-- (customer_profiles is readable only by its owner; the alias is also returned by my_file_alias().)

create or replace function public.my_file_alias()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  result uuid;
begin
  select c.file_alias into result from public.customer_profiles c where c.user_id = uid;
  if result is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return result;
end;
$$;

-- The alias of the caller as text, '' when there is none (used in policies).
create or replace function public._my_file_alias_text()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select c.file_alias::text from public.customer_profiles c where c.user_id = (select auth.uid())), '')
$$;

create or replace function public.my_request_file_count()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from storage.objects o
   where o.bucket_id = 'request-photos'
     and (storage.foldername(o.name))[1] = public._my_file_alias_text()
     and public._my_file_alias_text() <> ''
$$;

drop policy request_photos_insert on public.request_photos;
create policy request_photos_insert on public.request_photos
  for insert to authenticated
  with check (
    (select public.owns_open_request(request_id))
    and split_part(path, '/', 1) = (select public._my_file_alias_text())
    and split_part(path, '/', 1) <> ''
  );

drop policy request_files_insert_own on storage.objects;
create policy request_files_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'request-photos'
    and (storage.foldername(name))[1] = (select public._my_file_alias_text())
    and (select public._my_file_alias_text()) <> ''
    and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') <> 'true'
    and exists (select 1 from public.customer_profiles c where c.user_id = (select auth.uid()))
    and (select public.my_request_file_count()) < 60
  );

drop policy request_files_select on storage.objects;
create policy request_files_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'request-photos'
    and (
      ((storage.foldername(name))[1] = (select public._my_file_alias_text())
         and (select public._my_file_alias_text()) <> '')
      or exists (
        select 1 from public.request_photos rp
         where rp.path = name and (select public.can_view_request_photos(rp.request_id))
      )
    )
  );

drop policy request_files_delete_own on storage.objects;
create policy request_files_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'request-photos'
    and (storage.foldername(name))[1] = (select public._my_file_alias_text())
    and (select public._my_file_alias_text()) <> ''
    and not (select public.request_photo_is_locked(name))
  );

revoke all on function public.my_file_alias(), public._my_file_alias_text(), public.my_request_file_count()
  from public, anon, authenticated;
grant execute on function public.my_file_alias(), public._my_file_alias_text(), public.my_request_file_count()
  to authenticated;

------------------------------------------------------------------------
-- 2. A pending verification must not survive a change of identity.
------------------------------------------------------------------------
create or replace function public.reset_verification_on_identity_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  req uuid;
begin
  if new.business_name is distinct from old.business_name
     or new.contact_phone is distinct from old.contact_phone then
    if old.verification_status = 'verified' then
      new.verification_status := 'unverified';
      new.verified_at := null;
    elsif old.verification_status = 'pending' then
      -- What was submitted no longer describes this profile: withdraw it.
      select id into req from public.verification_requests
       where professional_id = old.user_id and status = 'pending' for update;
      if found then
        update public.verification_requests set status = 'cancelled', reviewed_at = now() where id = req;
        perform public._discard_verification_documents(req);
      end if;
      new.verification_status := 'unverified';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.reset_verification_on_identity_change() from public, anon, authenticated;

------------------------------------------------------------------------
-- 3. Reviews: the per-pair cap holds under parallel submissions.
------------------------------------------------------------------------
create or replace function public.submit_review(p_booking uuid, p_rating smallint, p_comment text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  b public.bookings;
  subject uuid;
  new_id uuid;
  body text := nullif(btrim(p_comment), '');
begin
  select * into b from public.bookings where id = p_booking;
  if not found or uid not in (b.customer_id, b.professional_id) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if b.status <> 'completed' then
    raise exception 'not_completed' using errcode = 'P0001';
  end if;
  if p_rating is null or p_rating not between 1 and 5 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  if body is not null and char_length(body) > 1000 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  subject := case when uid = b.customer_id then b.professional_id else b.customer_id end;
  -- The same two people cannot keep rating each other: at most 3 reviews from
  -- one author about one subject (repeat jobs are real, farming is not).
  -- Serialize per pair so two parallel submissions cannot both pass the count.
  perform pg_advisory_xact_lock(hashtextextended('review-pair:' || uid::text || subject::text, 0));
  if (select count(*) from public.reviews r where r.author_id = uid and r.subject_id = subject) >= 3 then
    raise exception 'review_limit' using errcode = 'P0001';
  end if;
  insert into public.reviews (booking_id, author_id, subject_id, about_professional, rating, comment)
  values (p_booking, uid, subject, uid = b.customer_id, p_rating, body)
  on conflict (booking_id, author_id) do nothing
  returning id into new_id;
  if new_id is null then
    raise exception 'already_reviewed' using errcode = 'P0001';
  end if;
  return new_id;
end;
$$;

revoke all on function public.submit_review(uuid, smallint, text) from public, anon, authenticated;
grant execute on function public.submit_review(uuid, smallint, text) to authenticated;

------------------------------------------------------------------------
-- 4. Account deletion queues request-photo files by alias.
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
