-- Reviews tied to completed jobs.
--
-- After a booking is completed (confirmed by the customer), each of the two
-- people may leave ONE review about the other. Only reviews about a
-- professional count towards their public rating; a review about a customer is
-- kept (private, for future use). Nobody can write reviews directly: they go
-- through submit_review(), which checks the booking. Ratings on
-- professional_profiles are maintained by a trigger, never by clients.
--
-- Public reads show the rating, the comment and the date: not who wrote it
-- (author_id and booking_id are not selectable). Moderation: an admin can hide
-- a review (it leaves the public list and the average) with a note.

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  subject_id uuid not null references public.profiles (id) on delete cascade,
  -- True when a customer wrote it about the professional of the job: only
  -- these are public and count towards a rating. The other direction
  -- (professional about customer) stays private.
  about_professional boolean not null,
  rating smallint not null check (rating between 1 and 5),
  comment text check (comment is null or char_length(comment) between 1 and 1000),
  status text not null default 'published' check (status in ('published', 'hidden')),
  moderation_note text,
  created_at timestamptz not null default now(),
  -- What the public sees instead of the exact time: month only, plus an
  -- insertion counter for ordering. (Exact times would let someone match a
  -- review to a job they know about.)
  reviewed_month date not null default (date_trunc('month', now())::date),
  seq bigint generated always as identity,
  unique (booking_id, author_id),
  check (author_id <> subject_id)
);
create index reviews_subject_idx on public.reviews (subject_id, seq desc) where status = 'published' and about_professional;

alter table public.reviews enable row level security;
revoke all on table public.reviews from public, anon, authenticated;
-- Public columns only: who wrote it stays private.
grant select (id, subject_id, rating, comment, status, reviewed_month, seq) on public.reviews to anon, authenticated;

-- Everyone sees published reviews about professionals; nothing else (hidden
-- ones, reviews about customers, and any column that identifies people, are out
-- of reach).
create policy reviews_public_read on public.reviews
  for select to anon, authenticated
  using (status = 'published' and about_professional);

------------------------------------------------------------------------
-- aggregates: only professionals have a public rating
------------------------------------------------------------------------
create or replace function public._refresh_professional_rating(p_subject uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- One recount at a time per professional: the next statement then sees every
  -- review committed before the lock was granted.
  perform pg_advisory_xact_lock(hashtextextended('rating:' || p_subject::text, 0));
  update public.professional_profiles p
     set rating_avg = coalesce((
           select round(avg(r.rating)::numeric, 1) from public.reviews r
            where r.subject_id = p_subject and r.status = 'published' and r.about_professional
         ), 0),
         review_count = (
           select count(*)::integer from public.reviews r
            where r.subject_id = p_subject and r.status = 'published' and r.about_professional
         )
   where p.user_id = p_subject;
end;
$$;

create or replace function public._reviews_changed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform public._refresh_professional_rating(old.subject_id);
  else
    perform public._refresh_professional_rating(new.subject_id);
  end if;
  return null;
end;
$$;
create trigger reviews_aggregate
  after insert or update of status, rating or delete on public.reviews
  for each row execute function public._reviews_changed();

------------------------------------------------------------------------
-- leave a review
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

-- Which of my completed jobs I have already reviewed (the author column is
-- not selectable, so this is how the app knows).
create or replace function public.my_reviewed_bookings()
returns table (booking_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  return query select r.booking_id from public.reviews r where r.author_id = uid;
end;
$$;

------------------------------------------------------------------------
-- moderation hook (the admin dashboard, #29, calls this)
------------------------------------------------------------------------
create or replace function public.admin_set_review_status(p_review uuid, p_status text, p_note text default null)
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
  update public.reviews set status = p_status, moderation_note = left(p_note, 500) where id = p_review;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function
  public._refresh_professional_rating(uuid), public._reviews_changed(),
  public.submit_review(uuid, smallint, text), public.my_reviewed_bookings(),
  public.admin_set_review_status(uuid, text, text)
  from public, anon, authenticated;
grant execute on function
  public.submit_review(uuid, smallint, text), public.my_reviewed_bookings(),
  public.admin_set_review_status(uuid, text, text)
  to authenticated;
