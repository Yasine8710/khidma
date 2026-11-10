-- A professional's own activity numbers, for their dashboard. Counts only:
-- nobody learns who revealed their phone or who saved them. Events from the
-- last hour are left out, so watching the numbers cannot pin one visitor's
-- action to a moment.

create index contact_reveals_professional_time_idx
  on public.contact_reveals (professional_id, created_at desc);
create index favorites_professional_idx on public.favorites (professional_id);

create or replace function public.get_my_activity()
returns table (reveals_30d integer, reveals_total integer, favorites_count integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  if not exists (select 1 from public.professional_profiles where user_id = uid) then
    raise exception 'not a professional' using errcode = '42501';
  end if;
  return query
  select
    (select count(*)::integer from public.contact_reveals r
      where r.professional_id = uid
        and r.created_at > now() - interval '30 days'
        and r.created_at <= now() - interval '1 hour'),
    (select count(*)::integer from public.contact_reveals r
      where r.professional_id = uid and r.created_at <= now() - interval '1 hour'),
    (select count(*)::integer from public.favorites f
      where f.professional_id = uid and f.created_at <= now() - interval '1 hour');
end;
$$;

revoke all on function public.get_my_activity() from public, anon, authenticated;
grant execute on function public.get_my_activity() to authenticated;
