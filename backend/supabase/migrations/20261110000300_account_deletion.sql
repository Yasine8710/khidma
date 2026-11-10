-- In-app account deletion (App Store guideline 5.1.1(v)): a person can delete
-- their own account and everything that hangs off it.
--
-- Deleting the auth user cascades through every foreign key declared so far
-- (profiles -> customer_profiles, professional_profiles -> services, areas,
-- contact_reveals, ...). New tables that store personal data MUST reference
-- profiles/auth.users with ON DELETE CASCADE (or be cleaned up here); a test
-- checks that nothing is left behind.
--
-- NOTE: this relies on the function owner being allowed to DELETE from
-- auth.users, which is true on hosted Supabase projects but must be confirmed
-- on the real project (issue #6). If it is not, replace the body with a call to
-- an Edge Function that uses the admin API (auth.admin.deleteUser).

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon, authenticated;
grant execute on function public.delete_my_account() to authenticated;
