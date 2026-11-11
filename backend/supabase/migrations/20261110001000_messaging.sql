-- Messaging between a customer and a professional about one offer.
--
-- A conversation hangs on an offer (one per offer), so a professional can only
-- talk to a customer who asked for something they answered, and the customer
-- stays anonymous (the professional sees "client" and the request title, never
-- a name or number: people may share what they like inside the chat).
-- Writing needs the offer to be pending or accepted; once it is declined,
-- withdrawn or the request is cancelled/expired the conversation is read-only.
--
-- Clients only READ the tables (RLS by membership). Every write goes through a
-- SECURITY DEFINER function. Images live in the private bucket `chat-images`,
-- under `<conversation id>/<file>`, readable only by the two members.

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null unique references public.quote_offers (id) on delete cascade,
  customer_id uuid not null references public.profiles (id) on delete cascade,
  professional_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz,
  -- Up to which message id each side has read (not timestamps: a message that
  -- arrives while the screen renders is never marked read unseen).
  customer_read_id bigint not null default 0,
  professional_read_id bigint not null default 0,
  check (customer_id <> professional_id)
);
create index conversations_customer_idx on public.conversations (customer_id, last_message_at desc nulls last);
create index conversations_professional_idx on public.conversations (professional_id, last_message_at desc nulls last);

create table public.messages (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  -- Who wrote it, as a role only: the table carries no user ids, so neither
  -- reads nor realtime payloads can link a customer across conversations.
  sender_is_customer boolean not null,
  body text check (body is null or char_length(body) between 1 and 2000),
  -- `<conversation id>/<file name>` in the chat-images bucket
  image_path text check (
    image_path is null or image_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._-]{1,100}\.(jpg|jpeg|png|webp)$'
  ),
  created_at timestamptz not null default now(),
  check (body is not null or image_path is not null),
  check (image_path is null or split_part(image_path, '/', 1) = conversation_id::text)
);
create index messages_conversation_idx on public.messages (conversation_id, id);

------------------------------------------------------------------------
-- membership helper and read-only access
------------------------------------------------------------------------
create or replace function public.is_conversation_member(p_conversation uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.conversations c
     where c.id = p_conversation
       and (select auth.uid()) in (c.customer_id, c.professional_id)
  )
$$;

alter table public.conversations enable row level security;
alter table public.messages enable row level security;
revoke all on table public.conversations, public.messages from public, anon, authenticated;
-- No user ids are selectable: the app reads its inbox through my_conversations().
grant select (id, offer_id, created_at, last_message_at) on public.conversations to authenticated;
grant select (id, conversation_id, sender_is_customer, body, image_path, created_at)
  on public.messages to authenticated;

create policy conversations_read on public.conversations
  for select to authenticated
  using ((select auth.uid()) in (customer_id, professional_id));

create policy messages_read on public.messages
  for select to authenticated
  using ((select public.is_conversation_member(conversation_id)));

revoke all on function public.is_conversation_member(uuid) from public, anon, authenticated;
grant execute on function public.is_conversation_member(uuid) to authenticated;

------------------------------------------------------------------------
-- start (or reopen) the conversation about an offer
------------------------------------------------------------------------
create or replace function public.start_conversation(p_offer uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  o public.quote_offers;
  r public.quote_requests;
  conv uuid;
begin
  select * into o from public.quote_offers where id = p_offer;
  if not found then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  select * into r from public.quote_requests where id = o.request_id;
  if uid not in (r.customer_id, o.professional_id) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  select id into conv from public.conversations where offer_id = p_offer;
  if found then
    return conv;
  end if;
  if o.status not in ('pending', 'accepted')
     or not (r.status = 'awarded' or (r.status = 'open' and r.expires_at > now())) then
    raise exception 'not_open' using errcode = 'P0001';
  end if;
  insert into public.conversations (offer_id, customer_id, professional_id)
  values (p_offer, r.customer_id, o.professional_id)
  on conflict (offer_id) do nothing
  returning id into conv;
  if conv is null then
    select id into conv from public.conversations where offer_id = p_offer;
  end if;
  return conv;
end;
$$;

------------------------------------------------------------------------
-- may this conversation still receive messages?
------------------------------------------------------------------------
create or replace function public._conversation_writable(p_conversation uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.conversations c
      join public.quote_offers o on o.id = c.offer_id
      join public.quote_requests r on r.id = o.request_id
     where c.id = p_conversation
       and o.status in ('pending', 'accepted')
       and (r.status = 'awarded' or (r.status = 'open' and r.expires_at > now()))
  )
$$;

------------------------------------------------------------------------
-- send a message (text and/or one image)
------------------------------------------------------------------------
create or replace function public.send_message(
  p_conversation uuid, p_body text default null, p_image_path text default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  c public.conversations;
  body text := nullif(btrim(p_body), '');
  msg_id bigint;
begin
  select * into c from public.conversations where id = p_conversation;
  if not found or uid not in (c.customer_id, c.professional_id) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  if body is null and p_image_path is null then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  if body is not null and char_length(body) > 2000 then
    raise exception 'invalid_input' using errcode = 'P0001';
  end if;
  if not public._conversation_writable(p_conversation) then
    raise exception 'not_open' using errcode = 'P0001';
  end if;
  if p_image_path is not null then
    -- the file must exist in this conversation's folder, uploaded by a member
    if split_part(p_image_path, '/', 1) <> p_conversation::text
       or not exists (
         select 1 from storage.objects o
          where o.bucket_id = 'chat-images' and o.name = p_image_path
       ) then
      raise exception 'invalid_input' using errcode = 'P0001';
    end if;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('send:' || uid::text, 0));
  -- Rate limit per sender across their conversations (counted through the
  -- conversations they belong to, since messages carry no user id).
  if (select count(*) from public.messages m
        join public.conversations cc on cc.id = m.conversation_id
       where m.created_at > now() - interval '1 minute'
         and ((cc.customer_id = uid and m.sender_is_customer)
              or (cc.professional_id = uid and not m.sender_is_customer))) >= 30 then
    raise exception 'rate_limited' using errcode = 'P0001';
  end if;
  insert into public.messages (conversation_id, sender_is_customer, body, image_path)
  values (p_conversation, uid = c.customer_id, body, p_image_path)
  returning id into msg_id;
  update public.conversations
     set last_message_at = now(),
         customer_read_id = case when uid = customer_id then msg_id else customer_read_id end,
         professional_read_id = case when uid = professional_id then msg_id else professional_read_id end
   where id = p_conversation;
  return msg_id;
end;
$$;

create or replace function public.mark_conversation_read(p_conversation uuid, p_up_to bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
  c public.conversations;
begin
  select * into c from public.conversations where id = p_conversation;
  if not found or uid not in (c.customer_id, c.professional_id) then
    raise exception 'not found' using errcode = 'P0002';
  end if;
  -- Only up to what was actually shown, and never backwards.
  update public.conversations
     set customer_read_id = case when uid = customer_id then greatest(customer_read_id, coalesce(p_up_to, 0)) else customer_read_id end,
         professional_read_id = case when uid = professional_id then greatest(professional_read_id, coalesce(p_up_to, 0)) else professional_read_id end
   where id = p_conversation;
end;
$$;

------------------------------------------------------------------------
-- the inbox: my conversations with the last message and unread count
------------------------------------------------------------------------
create or replace function public.my_conversations()
returns table (
  conversation_id uuid, offer_id uuid, request_id uuid, request_title text,
  i_am_customer boolean, other_name text, other_id uuid, last_body text, last_has_image boolean,
  last_at timestamptz, unread_count integer, writable boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  return query
  select c.id, c.offer_id, r.id, r.title,
         (c.customer_id = uid),
         -- the customer stays anonymous to the professional
         case when c.customer_id = uid
              then (select p.business_name from public.professional_profiles p where p.user_id = c.professional_id)
              else null end,
         case when c.customer_id = uid then c.professional_id else null end,
         (select m.body from public.messages m where m.conversation_id = c.id order by m.id desc limit 1),
         coalesce((select m.image_path is not null from public.messages m where m.conversation_id = c.id order by m.id desc limit 1), false),
         c.last_message_at,
         (select count(*)::integer from public.messages m
           where m.conversation_id = c.id
             and m.sender_is_customer <> (c.customer_id = uid)
             and m.id > case when c.customer_id = uid then c.customer_read_id else c.professional_read_id end),
         public._conversation_writable(c.id)
    from public.conversations c
    join public.quote_offers o on o.id = c.offer_id
    join public.quote_requests r on r.id = o.request_id
   where uid in (c.customer_id, c.professional_id)
   order by c.last_message_at desc nulls last, c.created_at desc
   limit 100;
end;
$$;

------------------------------------------------------------------------
-- chat images: private bucket, members only
------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('chat-images', 'chat-images', false, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Is the first folder of an object name a conversation the caller belongs to?
-- (Safe against names that are not UUIDs.)
create or replace function public.chat_folder_member(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when (storage.foldername(p_name))[1] ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then public.is_conversation_member(((storage.foldername(p_name))[1])::uuid)
    else false
  end
$$;

-- Same, and the conversation can still receive messages.
create or replace function public.chat_folder_writable(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.chat_folder_member(p_name)
     and public._conversation_writable(((storage.foldername(p_name))[1])::uuid)
$$;

-- An upload that no message points to yet (a failed send must not keep
-- consuming the quota).
create or replace function public.chat_file_unsent(p_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.chat_folder_member(p_name)
     and not exists (select 1 from public.messages m where m.image_path = p_name)
$$;

create or replace function public.chat_image_count(p_name text)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from storage.objects o
   where o.bucket_id = 'chat-images'
     and (storage.foldername(o.name))[1] = (storage.foldername(p_name))[1]
$$;

revoke all on function
  public.chat_folder_member(text), public.chat_folder_writable(text), public.chat_file_unsent(text),
  public.chat_image_count(text),
  public.start_conversation(uuid), public._conversation_writable(uuid),
  public.send_message(uuid, text, text), public.mark_conversation_read(uuid, bigint),
  public.my_conversations()
  from public, anon, authenticated;
grant execute on function
  public.chat_folder_member(text), public.chat_folder_writable(text), public.chat_file_unsent(text),
  public.chat_image_count(text),
  public.start_conversation(uuid), public.send_message(uuid, text, text),
  public.mark_conversation_read(uuid, bigint), public.my_conversations()
  to authenticated;

-- Members upload into their conversation's folder only while it can still
-- receive messages, at most 100 images per conversation; an upload no message
-- points to can be removed.
create policy chat_files_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-images'
    and (select public.chat_folder_writable(name))
    and coalesce((select auth.jwt()) ->> 'is_anonymous', 'false') <> 'true'
    and (select public.chat_image_count(name)) < 100
  );

create policy chat_files_delete_unsent on storage.objects
  for delete to authenticated
  using (bucket_id = 'chat-images' and (select public.chat_file_unsent(name)));

create policy chat_files_select on storage.objects
  for select to authenticated
  using (bucket_id = 'chat-images' and (select public.chat_folder_member(name)));

-- Account deletion: also the person's chat images (conversations they took
-- part in disappear with them, so their objects must go too).
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := public.require_registered_user();
begin
  update public.quote_requests r set status = 'cancelled'
   where r.status = 'awarded'
     and exists (select 1 from public.bookings b where b.request_id = r.id and b.professional_id = uid);
  delete from storage.objects
   where bucket_id in ('portfolio', 'request-photos')
     and (storage.foldername(name))[1] = uid::text;
  delete from storage.objects o
   where o.bucket_id = 'chat-images'
     and exists (
       select 1 from public.conversations c
        where c.id::text = (storage.foldername(o.name))[1]
          and uid in (c.customer_id, c.professional_id)
     );
  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon, authenticated;
grant execute on function public.delete_my_account() to authenticated;

-- Live updates: new messages are published to realtime (which honours the
-- read policy above, so only members receive them). Skipped where the
-- publication does not exist.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;
