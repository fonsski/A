-- Фикс 5: фото в сообщениях + рекомендательная лента стенки.

-- ── Фото в сообщениях ──────────────────────────────────────────────────────
alter table public.messages add column if not exists image_url text;

-- Сообщение может быть только фото (без текста).
alter table public.messages drop constraint if exists messages_body_check;
alter table public.messages add constraint messages_body_check
  check (image_url is not null or length(body) between 1 and 4000);

-- Бакет для медиа чатов: путь {chat_id}/файл, писать могут только участники.
insert into storage.buckets (id, name, public)
values ('chat-media', 'chat-media', true)
on conflict (id) do nothing;

create policy chat_media_read on storage.objects
  for select using (bucket_id = 'chat-media');

create policy chat_media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and public.is_chat_member(((storage.foldername(name))[1])::uuid, auth.uid()));

-- ── Рекомендательная лента ─────────────────────────────────────────────────
-- Скор: свежесть + друзья + «я уже лайкал этого автора» + популярность
-- + текстовая похожесть (pg_trgm) на посты, которым я ставил «Ага!».
create extension if not exists pg_trgm;

create or replace function public.feed_for_me(limit_count int default 50)
returns table (post_id uuid, score real)
language sql stable security invoker as $$
  with my_likes as (
    select p.* from public.posts p
    join public.reactions r on r.post_id = p.id
    where r.user_id = auth.uid()
  ),
  corpus as (
    select left(coalesce(string_agg(body, ' '), ''), 4000) as text
    from my_likes
  ),
  liked_authors as (select distinct author_id from my_likes)
  select
    p.id,
    (
      exp(-extract(epoch from now() - p.created_at) / 172800.0)  -- полураспад ~2 суток
      + 2.0 * (public.are_friends(p.author_id, auth.uid()))::int
      + 1.5 * (p.author_id in (select author_id from liked_authors))::int
      + 0.5 * ln(1 + (select count(*) from public.reactions r2
                       where r2.post_id = p.id))
      + 2.0 * similarity(left(p.body, 1000), (select text from corpus))
    )::real as score
  from public.posts p
  where p.author_id <> auth.uid()
    and p.wall_owner_id <> auth.uid()
  order by score desc
  limit limit_count;
$$;
-- security invoker: RLS на posts продолжает фильтровать невидимые посты.
