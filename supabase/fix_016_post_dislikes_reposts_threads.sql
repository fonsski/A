-- fix_016: дизлайки (∀), репосты, ветки комментариев.

-- 1. Дизлайк: ещё один вид реакции на пост (один пользователь — одна реакция:
--    «Ага!» или «∀», как и раньше PK (post_id, user_id)).
alter table public.reactions drop constraint if exists reactions_kind_check;
alter table public.reactions
  add constraint reactions_kind_check check (kind in ('aga', 'dislike'));

-- 2. Репост: запись на моей стене со ссылкой на оригинал. Подпись к репосту
--    необязательна, поэтому пустой body разрешён только вместе с repost_of.
alter table public.posts
  add column if not exists repost_of uuid
  references public.posts (id) on delete set null;

alter table public.posts drop constraint if exists posts_body_check;
alter table public.posts
  add constraint posts_body_check check (
    length(body) <= 10000 and (repost_of is not null or length(body) >= 1));

-- 3. Ветки комментариев: ответ на комментарий.
alter table public.comments
  add column if not exists parent_id uuid
  references public.comments (id) on delete cascade;
create index if not exists comments_parent_idx on public.comments (parent_id);

-- Удалять комментарий может автор или владелец стены.
drop policy if exists comments_delete on public.comments;
create policy comments_delete on public.comments for delete using (
  author_id = auth.uid()
  or exists (select 1 from public.posts p
             where p.id = post_id and p.wall_owner_id = auth.uid()));

-- 4. Реакции на комментарии: «Ага!» и «∀».
create table if not exists public.comment_reactions (
  comment_id uuid not null references public.comments (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null default 'aga' check (kind in ('aga', 'dislike')),
  created_at timestamptz not null default now(),
  primary key (comment_id, user_id)
);

alter table public.comment_reactions enable row level security;

create policy comment_reactions_read on public.comment_reactions
  for select using (
    exists (select 1 from public.comments c where c.id = comment_id));

create policy comment_reactions_own on public.comment_reactions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

alter publication supabase_realtime add table public.comment_reactions;

-- 5. Рекомендации учитывают только «Ага!», дизлайк интереса не выражает.
create or replace function public.feed_for_me(limit_count int default 50)
returns table (post_id uuid, score real)
language sql stable security invoker as $$
  with my_likes as (
    select p.* from public.posts p
    join public.reactions r on r.post_id = p.id
    where r.user_id = auth.uid() and r.kind = 'aga'
  ),
  corpus as (
    select left(coalesce(string_agg(body, ' '), ''), 4000) as text
    from my_likes
  ),
  liked_authors as (select distinct author_id from my_likes)
  select
    p.id,
    (
      exp(-extract(epoch from now() - p.created_at) / 172800.0)
      + 2.0 * (public.are_friends(p.author_id, auth.uid()))::int
      + 1.5 * (p.author_id in (select author_id from liked_authors))::int
      + 0.5 * ln(1 + (select count(*) from public.reactions r2
                       where r2.post_id = p.id and r2.kind = 'aga'))
      + 2.0 * similarity(left(p.body, 1000), (select text from corpus))
    )::real as score
  from public.posts p
  where p.author_id <> auth.uid()
    and p.wall_owner_id <> auth.uid()
  order by score desc
  limit limit_count;
$$;
