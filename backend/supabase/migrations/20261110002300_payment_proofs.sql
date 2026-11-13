-- Payment proofs and decision notices (#63).
--
-- For a manual payment (D17, bank transfer) the professional can attach up to
-- 3 proofs (photo or PDF of the receipt) to their own unpaid order. Files go
-- to the private `payment-proofs` bucket under `<uid>/`; only the owner reads
-- them through Storage. Admins see them through the admin-media signer, which
-- first calls the audited admin_payment_proofs(). Account deletion queues the
-- files for the cleanup worker.
--
-- Whatever confirms or rejects an order (admin, Flouci callback), one notice
-- is queued for its owner. The rejection note is readable by the owner in the
-- app; the push itself never carries it.

alter table public.notification_outbox drop constraint notification_outbox_kind_check;
alter table public.notification_outbox add constraint notification_outbox_kind_check
  check (kind in (
    'offer_received', 'offer_accepted', 'message',
    'job_started', 'job_done', 'job_completed', 'job_cancelled',
    'report_actioned', 'report_dismissed', 'account_suspended', 'account_restored',
    'appeal_rejected', 'verification_expired', 'listing_held', 'listing_released',
    'payment_confirmed', 'payment_rejected'
  ));

-- The owner may read why their payment was refused.
grant select (admin_note) on public.payment_orders to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('payment-proofs', 'payment-proofs', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create table public.payment_proofs (
  order_id uuid not null references public.payment_orders (id) on delete cascade,
  -- `<owner id>/<file name>`
  path text not null unique
    check (path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,100}\.(jpg|jpeg|png|webp|pdf)$'),
  created_at timestamptz not null default now(),
  primary key (order_id, path)
);
alter table public.payment_proofs enable row level security;
revoke all on table public.payment_proofs from public, anon, authenticated;

-- Volatile with a per-user lock, so two uploads cannot both pass the count.
create or replace function public.my_payment_proof_file_count()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid text := (select auth.uid())::text;
begin
  perform pg_advisory_xact_lock(hashtextextended('payment-proofs:' || coalesce(uid, ''), 0));
  return (
    select count(*)::integer from storage.objects o
     where o.bucket_id = 'payment-proofs'
       and (storage.foldername(o.name))[1] = uid
       and not exists (select 1 from public.storage_cleanup_queue q
                        where q.bucket_id = 'payment-proofs' and q.name = o.name)
  );
end;
$$;

create or replace function public.payment_proof_unattached(p_name text)
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  select not exists (select 1 from public.payment_proofs p where p.path = p_name)
$$;

create policy payment_proofs_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'payment-proofs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') <> 'true'
    and exists (select 1 from public.professional_profiles p where p.user_id = (select auth.uid()))
    and (select public.my_payment_proof_file_count()) < 20
  );
create policy payment_proofs_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
-- An attached proof stays (it is the record of the payment).
create policy payment_proofs_delete_unattached on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'payment-proofs'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.payment_proof_unattached(name))
  );

-- Attaches an uploaded file to the caller's own unpaid manual order.
create or replace function public.attach_payment_proof(p_order uuid, p_path text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  o public.payment_orders;
begin
  select * into o from public.payment_orders where id = p_order and user_id = uid for update;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if o.method not in ('d17', 'bank_transfer') or o.status not in ('pending', 'awaiting_confirmation') then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;
  if p_path is null or split_part(p_path, '/', 1) <> uid::text
     or not exists (select 1 from storage.objects s
                     where s.bucket_id = 'payment-proofs' and s.name = p_path)
     or exists (select 1 from public.storage_cleanup_queue q
                 where q.bucket_id = 'payment-proofs' and q.name = p_path) then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  if (select count(*) from public.payment_proofs where order_id = p_order) >= 3 then
    raise exception 'limit_reached' using errcode = 'P0001';
  end if;
  insert into public.payment_proofs (order_id, path) values (p_order, p_path)
  on conflict do nothing;
end;
$$;

-- How many proofs the caller attached to one of their orders.
create or replace function public.my_payment_proof_count(p_order uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from public.payment_proofs p
    join public.payment_orders o on o.id = p.order_id
   where p.order_id = p_order and o.user_id = (select auth.uid())
$$;

-- Admins: the proof paths of an order, for the signer. Every look is logged.
create or replace function public.admin_payment_proofs(p_order uuid)
returns table (path text)
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not public.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  perform public._audit('view_payment_proofs', 'payment_order', p_order::text);
  return query select p.path from public.payment_proofs p where p.order_id = p_order order by p.created_at, p.path;
end;
$$;

-- One notice per decision, whoever made it.
create or replace function public._notify_payment_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status in ('paid', 'rejected') and old.status is distinct from new.status then
    perform public._enqueue_notification(new.user_id, 'account',
      case when new.status = 'paid' then 'payment_confirmed' else 'payment_rejected' end,
      'payment:' || new.id::text || ':' || new.status, jsonb_build_object('order_id', new.id));
  end if;
  return new;
end;
$$;
create trigger payment_orders_notify_decision
  after update of status on public.payment_orders
  for each row execute function public._notify_payment_decision();

------------------------------------------------------------------------
-- account deletion also queues payment proofs (same as 1800 otherwise)
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
   where (o.bucket_id in ('portfolio', 'verification-docs', 'avatars', 'freelance-media', 'payment-proofs')
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

revoke all on function
  public.my_payment_proof_file_count(), public.payment_proof_unattached(text),
  public.attach_payment_proof(uuid, text), public.my_payment_proof_count(uuid),
  public.admin_payment_proofs(uuid), public._notify_payment_decision()
  from public, anon, authenticated;
grant execute on function
  public.my_payment_proof_file_count(), public.payment_proof_unattached(text),
  public.attach_payment_proof(uuid, text), public.my_payment_proof_count(uuid),
  public.admin_payment_proofs(uuid)
  to authenticated;
