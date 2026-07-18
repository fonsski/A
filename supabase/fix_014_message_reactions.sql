-- Фикс 14: реакции на сообщения (одна на сообщение от пользователя, как в ТГ).

create table if not exists public.message_reactions (
  message_id bigint not null references public.messages (id) on delete cascade,
  user_id    uuid   not null references public.profiles (id) on delete cascade,
  -- денормализация для realtime-фильтра по чату
  chat_id    uuid   not null references public.chats (id) on delete cascade,
  emoji      text   not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

alter table public.message_reactions enable row level security;

create policy message_reactions_read on public.message_reactions
  for select using (is_chat_member(chat_id, auth.uid()));

create policy message_reactions_insert on public.message_reactions
  for insert with check (
    user_id = auth.uid()
    and is_chat_member(chat_id, auth.uid())
    and exists (select 1 from public.messages m
                 where m.id = message_id and m.chat_id = chat_id));

create policy message_reactions_update on public.message_reactions
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy message_reactions_delete on public.message_reactions
  for delete using (user_id = auth.uid());

alter publication supabase_realtime add table public.message_reactions;
