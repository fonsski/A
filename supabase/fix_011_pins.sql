-- Фикс 11: закрепление сообщений.

alter table public.chats add column if not exists pinned_message_id bigint
  references public.messages (id) on delete set null;

-- Закрепить сообщение (+ системная отметка в ленте).
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
  update chats set pinned_message_id = message where id = chat;
  insert into messages (chat_id, author_id, body, kind)
  values (chat, auth.uid(), '', 'pin');
end $$;

-- Открепить (без системной отметки, как в Telegram).
create or replace function public.unpin_chat(chat uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_chat_member(chat, auth.uid()) then
    raise exception 'not a member';
  end if;
  update chats set pinned_message_id = null where id = chat;
end $$;

-- Реалтайм на chats — плашка пина обновляется у обеих сторон.
alter publication supabase_realtime add table public.chats;
