-- fix_020: галочки прочтения «А» / «АА».
--
-- Своё сообщение считается прочитанным, когда его id <= last_read_message_id
-- собеседника (поле уже есть в chat_members, его обновляет mark_read).
-- Нужно две вещи:
--   1. realtime на chat_members — клиент узнаёт, что собеседник прочитал;
--   2. в chat_overview — автор и id последнего сообщения и «прочитано до»
--      у собеседника, чтобы в списке чатов нарисовать «А»/«АА».
-- До применения миграции клиент работает: все свои сообщения остаются «А».

do $$
begin
  if not exists (select 1 from pg_publication_tables
                  where pubname = 'supabase_realtime'
                    and schemaname = 'public'
                    and tablename = 'chat_members') then
    alter publication supabase_realtime add table public.chat_members;
  end if;
end $$;

-- Новые колонки — в конце: create or replace view не позволяет вставлять
-- их в середину.
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
  lm.kind as last_kind,
  lm.id as last_id,
  lm.author_id as last_author_id,
  other.last_read_message_id as peer_last_read
from public.chats c
join public.chat_members cm on cm.chat_id = c.id
left join public.chat_members other
       on other.chat_id = c.id and other.user_id <> cm.user_id
left join public.profiles p on p.id = other.user_id
left join lateral (select id, author_id, body, created_at, attachment_type, kind
                     from public.messages m
                    where m.chat_id = c.id
                    order by m.id desc limit 1) lm on true;
