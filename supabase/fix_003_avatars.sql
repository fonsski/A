-- Фикс 3: аватарки в Storage + аватары собеседников в выдачах.

-- Публичный бакет: читают все, пишет каждый только в свою папку {uid}/...
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

create policy avatars_read on storage.objects
  for select using (bucket_id = 'avatars');

create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = auth.uid()::text);

create policy avatars_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = auth.uid()::text);

-- Аватар собеседника в списке чатов.
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
  p.avatar_url as peer_avatar
from public.chats c
join public.chat_members cm on cm.chat_id = c.id
left join public.chat_members other
       on other.chat_id = c.id and other.user_id <> cm.user_id
left join public.profiles p on p.id = other.user_id
left join lateral (select body, created_at from public.messages m
                    where m.chat_id = c.id
                    order by m.id desc limit 1) lm on true;
