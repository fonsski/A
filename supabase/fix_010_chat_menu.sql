-- Фикс 10: меню чата — очистка и удаление, системные сообщения.

-- Тип сообщения: обычное или системное событие
-- ('clear' — очистка чата, 'pin' — задел под закрепы).
alter table public.messages add column if not exists kind text
  not null default 'user' check (kind in ('user', 'clear', 'pin'));

-- Системным сообщениям пустое тело разрешено.
alter table public.messages drop constraint if exists messages_body_check;
alter table public.messages add constraint messages_body_check
  check (kind <> 'user'
         or image_url is not null
         or length(body) between 1 and 4000);

-- Очистить переписку у обеих сторон + системная отметка.
create or replace function public.clear_chat(chat uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_chat_member(chat, auth.uid()) then
    raise exception 'not a member';
  end if;
  delete from messages where chat_id = chat;
  insert into messages (chat_id, author_id, body, kind)
  values (chat, auth.uid(), '', 'clear');
end $$;

-- Удалить чат целиком (участники и сообщения уходят каскадом).
create or replace function public.delete_chat(chat uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not is_chat_member(chat, auth.uid()) then
    raise exception 'not a member';
  end if;
  delete from chats where id = chat;
end $$;

-- Тип последнего сообщения в обзоре чатов (превью «Чат очищен»).
create or replace view public.chat_overview
with (security_invoker = true) as
select
  c.id  as chat_id,
  cm.user_id,
  p.username as peer_username,
  coalesce(p.display_name, p.username::text, 'Чат') as peer_name,
  lm.body as last_body,
  lm.created_at as last_at,
  (select count(*) from public.messages m2
    where m2.chat_id = c.id
      and m2.id > cm.last_read_message_id
      and m2.author_id <> cm.user_id) as unread,
  p.avatar_url as peer_avatar,
  other.user_id as peer_id,
  lm.attachment_type as last_attachment,
  lm.kind as last_kind
from public.chats c
join public.chat_members cm on cm.chat_id = c.id
left join public.chat_members other
       on other.chat_id = c.id and other.user_id <> cm.user_id
left join public.profiles p on p.id = other.user_id
left join lateral (select body, created_at, attachment_type, kind
                     from public.messages m
                    where m.chat_id = c.id
                    order by m.id desc limit 1) lm on true;
