-- fix_018: звонки. Служебные сообщения WebRTC (приглашение, SDP, ICE)
-- ходят через таблицу call_signals: отправитель вставляет строку,
-- получатель ловит её по realtime и сразу удаляет.

-- Есть ли у двух пользователей общий чат (звонить можно только тем,
-- с кем есть переписка). security definer — чтобы обойти RLS chat_members.
create or replace function public.shares_chat(a uuid, b uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.chat_members x
    join public.chat_members y on y.chat_id = x.chat_id
    where x.user_id = a and y.user_id = b);
$$;

create table if not exists public.call_signals (
  id         bigint generated always as identity primary key,
  call_id    text not null,
  from_user  uuid not null references public.profiles (id) on delete cascade,
  to_user    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null check (kind in (
               'invite', 'accept', 'decline', 'busy', 'cancel',
               'hangup', 'offer', 'answer', 'ice')),
  payload    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists call_signals_to_idx
  on public.call_signals (to_user, created_at);

alter table public.call_signals enable row level security;

-- Читать и удалять — только адресат; отправитель может подчистить своё.
create policy call_signals_read on public.call_signals
  for select using (to_user = auth.uid());

create policy call_signals_delete on public.call_signals
  for delete using (to_user = auth.uid() or from_user = auth.uid());

-- Слать можно от своего имени, тому, с кем есть чат и кто меня не заблокировал.
create policy call_signals_send on public.call_signals
  for insert with check (
    from_user = auth.uid()
    and from_user <> to_user
    and public.shares_chat(from_user, to_user)
    and not public.is_blocked(to_user, from_user));

alter publication supabase_realtime add table public.call_signals;
