-- Professionals had no map position at all: nothing in the app writes one.
-- Give every governorate a centre and let the database fill a missing position
-- from the city (when it has coordinates) or else the governorate. A position the
-- owner sets explicitly is kept. Everything stays rounded to ~1.1 km.

alter table public.governorates
  add column latitude double precision check (latitude between -90 and 90),
  add column longitude double precision check (longitude between -180 and 180);

update public.governorates g set latitude = v.lat, longitude = v.lng
  from (values
    (11, 36.81, 10.18), (12, 36.86, 10.19), (13, 36.75, 10.23), (14, 36.81, 10.10),
    (21, 36.45, 10.74), (22, 36.40, 10.14), (23, 37.27,  9.87), (31, 36.73,  9.18),
    (32, 36.50,  8.78), (33, 36.17,  8.71), (34, 36.08,  9.37), (41, 35.68, 10.10),
    (42, 35.17,  8.83), (43, 35.04,  9.49), (51, 35.83, 10.64), (52, 35.78, 10.83),
    (53, 35.50, 11.06), (61, 34.74, 10.76), (71, 34.43,  8.78), (72, 33.92,  8.13),
    (73, 33.70,  8.97), (81, 33.88, 10.10), (82, 33.35, 10.50), (83, 32.93, 10.45)
  ) as v(id, lat, lng)
 where g.id = v.id;

-- Runs before the rounding trigger ("fill" sorts before "round").
create or replace function public.fill_professional_position()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  lat double precision;
  lng double precision;
begin
  if new.latitude is not null or new.governorate_id is null then
    return new;
  end if;
  select c.latitude, c.longitude into lat, lng
    from public.cities c where c.id = new.city_id;
  if lat is null or lng is null then
    select g.latitude, g.longitude into lat, lng
      from public.governorates g where g.id = new.governorate_id;
  end if;
  new.latitude := lat;
  new.longitude := lng;
  return new;
end;
$$;
revoke all on function public.fill_professional_position() from public, anon, authenticated;
create trigger professional_profiles_fill_position
  before insert or update on public.professional_profiles
  for each row execute function public.fill_professional_position();

-- Existing profiles without a position.
update public.professional_profiles set governorate_id = governorate_id
 where latitude is null and governorate_id is not null;
