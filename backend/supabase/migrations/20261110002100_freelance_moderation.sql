-- Freelance moderation (#67): an admin can take a freelance listing down
-- from the report queue, with a reason the freelancer sees. While the hold
-- is on, the freelancer cannot republish; an admin lifts it. The local
-- professional profile is not affected (that is what suspension is for).

alter table public.notification_outbox drop constraint notification_outbox_kind_check;
alter table public.notification_outbox add constraint notification_outbox_kind_check
  check (kind in (
    'offer_received', 'offer_accepted', 'message',
    'job_started', 'job_done', 'job_completed', 'job_cancelled',
    'report_actioned', 'report_dismissed', 'account_suspended', 'account_restored',
    'appeal_rejected', 'verification_expired', 'listing_held', 'listing_released'
  ));

alter table public.freelancer_profiles
  add column admin_hold_reason text
  check (admin_hold_reason is null or char_length(admin_hold_reason) between 1 and 300);
-- Readable by the owner only in practice: a held listing is unpublished, so
-- row security shows it to nobody else (and visitors get no grant at all).
grant select (admin_hold_reason) on public.freelancer_profiles to authenticated;

create or replace function public.block_held_freelancer()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.is_published and new.admin_hold_reason is not null then
    raise exception 'on_hold' using errcode = 'P0001';
  end if;
  return new;
end;
$$;
create trigger freelancer_profiles_block_held
  before insert or update on public.freelancer_profiles
  for each row execute function public.block_held_freelancer();

-- Admin: unpublish and hold. From a report on the listing, the report is
-- closed as actioned and its reporter told (without details).
create or replace function public.admin_hold_freelancer(p_user uuid, p_reason text, p_report uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  reason text := nullif(btrim(p_reason), '');
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if reason is null or char_length(reason) > 300 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  if p_report is not null and not exists (
    select 1 from public.reports r
     where r.id = p_report and r.target_type = 'freelancer' and r.target_id = p_user
  ) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  update public.freelancer_profiles
     set is_published = false, admin_hold_reason = reason
   where user_id = p_user;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  perform public._audit('freelancer_held', 'freelancer', p_user::text, reason);
  perform public._enqueue_notification(p_user, 'account', 'listing_held',
    'listing_held:' || p_user::text || ':' || extract(epoch from now())::bigint::text, '{}'::jsonb);
  if p_report is not null then
    perform public.admin_handle_report(p_report, 'actioned', reason);
  end if;
end;
$$;

create or replace function public.admin_release_freelancer(p_user uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.freelancer_profiles set admin_hold_reason = null
   where user_id = p_user and admin_hold_reason is not null;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  perform public._audit('freelancer_released', 'freelancer', p_user::text, left(p_note, 300));
  perform public._enqueue_notification(p_user, 'account', 'listing_released',
    'listing_released:' || p_user::text || ':' || extract(epoch from now())::bigint::text, '{}'::jsonb);
end;
$$;

-- The report context shows whether a listing is on hold (same as 2000 otherwise).
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
      select f.display_name, f.headline, f.bio, f.is_published, f.admin_hold_reason, p.verification_status, p.suspended, f.rating_avg, f.review_count
        from public.freelancer_profiles f join public.professional_profiles p on p.user_id = f.user_id
       where f.user_id = r.target_id) x;
  elsif r.target_type = 'testimonial' then
    select to_jsonb(x) into ctx from (
      select t.author_name, t.rating, t.body, t.status, t.freelancer_id from public.testimonials t where t.id = r.target_id) x;
  elsif r.target_type = 'review' then
    select to_jsonb(x) into ctx from (
      select v.rating, v.comment, v.status, v.subject_id from public.reviews v where v.id = r.target_id) x;
  elsif r.target_type = 'offer' then
    select to_jsonb(x) into ctx from (
      select o.price_tnd, o.message, o.status, o.created_at, p.business_name
        from public.quote_offers o join public.professional_profiles p on p.user_id = o.professional_id
       where o.id = r.target_id) x;
  else
    -- conversation or one message: the last 50 messages (the reported one
    -- is flagged); reading them is logged.
    select jsonb_build_object('reported_message_id', r.message_id,
                              'messages', coalesce(jsonb_agg(m order by m.id), '[]'::jsonb)) into ctx
      from (select id, sender_is_customer, body, image_path, created_at
              from public.messages where conversation_id = r.target_id
               and (r.message_id is null or id <= r.message_id + 10)
             order by id desc limit 50) m;
    perform public._audit('read_conversation', 'report', p_report::text);
  end if;
  return coalesce(ctx, '{}'::jsonb);
end;
$$;

revoke all on function
  public.block_held_freelancer(), public.admin_hold_freelancer(uuid, text, uuid),
  public.admin_release_freelancer(uuid, text)
  from public, anon, authenticated;
grant execute on function
  public.admin_hold_freelancer(uuid, text, uuid), public.admin_release_freelancer(uuid, text)
  to authenticated;
