-- Фикс 13: несколько закрепов на чат + открепление (как в Telegram).

create table if not exists public.chat_pins (
  chat_id    uuid   not null references public.chats (id) on delete cascade,
  message_id bigint not null references public.messages (id) on delete cascade,
  pinned_by  uuid   not null references public.profiles (id),
  pinned_at  timestamptz not null default now(),
  primary key (chat_id, message_id)
);

alter table public.chat_pins enable row level security;
create policy chat_pins_member on public.chat_pins
  for all using (is_chat_member(chat_id, auth.uid()))
  with check (is_chat_member(chat_id, auth.uid()));

-- Переносим одиночный пин из fix_011 и убираем колонку.
insert into public.chat_pins (chat_id, message_id, pinned_by)
select c.id, c.pinned_message_id,
       (select cm.user_id from public.chat_members cm
         where cm.chat_id = c.id limit 1)
from public.chats c
where c.pinned_message_id is not null
on conflict do nothing;

alter table public.chats drop column if exists pinned_message_id;

-- Закрепить (повторный закреп поднимает пин наверх).
create or replace function public.pin_message(chat uuid, message bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_chat_member(chat, auth.uid()) then
    raise exception 'not a member';
  end if;
  if not exists (select 1 from messages
                  where id = message and chat_id = chat and kind = 'user') then
    raise exception 'no such message';
  end if;
  insert into chat_pins (chat_id, message_id, pinned_by)
  values (chat, message, auth.uid())
  on conflict (chat_id, message_id)
  do update set pinned_at = now(), pinned_by = auth.uid();
  insert into messages (chat_id, author_id, body, kind)
  values (chat, auth.uid(), '', 'pin');
end $$;

-- Открепить конкретное сообщение.
create or replace function public.unpin_message(chat uuid, message bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_chat_member(chat, auth.uid()) then
    raise exception 'not a member';
  end if;
  delete from chat_pins where chat_id = chat and message_id = message;
end $$;

drop function if exists public.unpin_chat(uuid);

alter publication supabase_realtime add table public.chat_pins;
