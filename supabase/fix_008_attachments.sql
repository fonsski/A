-- Фикс 8: вложения в сообщениях — не только фото, но видео и файлы.
-- URL живёт в image_url (историческое имя), тип и имя файла — в новых колонках.
alter table public.messages add column if not exists attachment_type text
  check (attachment_type in ('image', 'video', 'file'));
alter table public.messages add column if not exists attachment_name text;

-- Тип последнего вложения в обзоре чатов (превью «🎬 Видео» и т.п.).
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
  lm.attachment_type as last_attachment
from public.chats c
join public.chat_members cm on cm.chat_id = c.id
left join public.chat_members other
       on other.chat_id = c.id and other.user_id <> cm.user_id
left join public.profiles p on p.id = other.user_id
left join lateral (select body, created_at, attachment_type
                     from public.messages m
                    where m.chat_id = c.id
                    order by m.id desc limit 1) lm on true;
