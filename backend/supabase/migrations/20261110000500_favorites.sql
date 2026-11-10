-- Favorites: a registered user saves published professionals.
--
-- Private to the owner (nobody, not even the professional, can see who saved
-- them). Capped per user so the table cannot be used as free storage.
-- Deleting an account, or a professional, removes the rows (ON DELETE CASCADE;
-- the account-deletion test checks nothing is left).

create table public.favorites (
  user_id uuid not null references public.profiles (id) on delete cascade,
  professional_id uuid not null references public.professional_profiles (user_id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, professional_id),
  check (user_id <> professional_id)
);
create index favorites_user_time_idx on public.favorites (user_id, created_at desc);

alter table public.favorites enable row level security;
revoke all on table public.favorites from public, anon, authenticated;
grant select, insert, delete on public.favorites to authenticated;

create policy favorites_read_own on public.favorites
  for select to authenticated
  using (user_id = (select auth.uid()));

-- Only published professionals can be saved (the subquery runs under that
-- table's own RLS, which already hides other people's drafts), and Supabase
-- anonymous-auth users are not registered accounts.
create policy favorites_insert_own on public.favorites
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') <> 'true'
    and exists (
      select 1 from public.professional_profiles p
       where p.user_id = professional_id and p.is_published
    )
  );

create policy favorites_delete_own on public.favorites
  for delete to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.enforce_favorites_limit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- One insert at a time per user, so two requests cannot both pass the count.
  perform pg_advisory_xact_lock(hashtextextended('favorites:' || new.user_id::text, 0));
  if (select count(*) from public.favorites where user_id = new.user_id) >= 200 then
    raise exception 'favorites_limit' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger favorites_limit
  before insert on public.favorites
  for each row execute function public.enforce_favorites_limit();

revoke all on function public.enforce_favorites_limit() from public, anon, authenticated;
