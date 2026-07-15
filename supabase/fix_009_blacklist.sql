-- Фикс 9: чёрный список — таблица, RLS, функция и интеграция в политики.

create table if not exists public.blacklist (
  owner_id   uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, blocked_id),
  check (owner_id <> blocked_id)
);

alter table public.blacklist enable row level security;
create policy blacklist_own on public.blacklist
  for all using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create or replace function public.is_blocked(owner uuid, target uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from blacklist
                  where owner_id = owner and blocked_id = target);
$$;

-- Заблокированный не видит стену блокировавшего.
drop policy if exists posts_read on public.posts;
create policy posts_read on public.posts for select using (
  wall_allows(wall_owner_id, auth.uid(),
              coalesce(public.wall_rule(wall_owner_id, 'visible'), 'all'))
  and not public.is_blocked(wall_owner_id, auth.uid()));

-- Нельзя писать в чат, где одна из сторон заблокировала другую.
drop policy if exists messages_send on public.messages;
create policy messages_send on public.messages for insert with check (
  author_id = auth.uid()
  and is_chat_member(chat_id, auth.uid())
  and not exists (
    select 1 from public.chat_members cm
    join public.blacklist b
      on (b.owner_id = cm.user_id and b.blocked_id = auth.uid())
      or (b.owner_id = auth.uid() and b.blocked_id = cm.user_id)
    where cm.chat_id = messages.chat_id));

alter publication supabase_realtime add table public.blacklist;

-- Новый диалог с заблокировавшим/заблокированным не начать.
create or replace function public.start_dm(peer uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare c uuid;
begin
  if peer = auth.uid() then raise exception 'cannot dm yourself'; end if;
  if public.is_blocked(peer, auth.uid())
     or public.is_blocked(auth.uid(), peer) then
    raise exception 'blocked';
  end if;
  select cm.chat_id into c
    from chat_members cm
    join chat_members cm2 on cm2.chat_id = cm.chat_id and cm2.user_id = peer
    join chats ch on ch.id = cm.chat_id and ch.kind = 'dm'
   where cm.user_id = auth.uid()
   limit 1;
  if c is not null then return c; end if;
  insert into chats (kind) values ('dm') returning id into c;
  insert into chat_members (chat_id, user_id)
    values (c, auth.uid()), (c, peer);
  return c;
end $$;
