-- Фикс 12: ответы на сообщения и удаление (у себя / у всех).

-- Ответ: ссылка на исходное сообщение.
alter table public.messages add column if not exists reply_to bigint
  references public.messages (id) on delete set null;

-- «Удалить у всех»: автор может удалить своё сообщение.
create policy messages_delete_own on public.messages
  for delete using (author_id = auth.uid());

-- «Удалить у себя»: персональное скрытие.
create table if not exists public.message_hidden (
  user_id    uuid   not null references public.profiles (id) on delete cascade,
  message_id bigint not null references public.messages (id) on delete cascade,
  primary key (user_id, message_id)
);

alter table public.message_hidden enable row level security;
create policy message_hidden_own on public.message_hidden
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());
