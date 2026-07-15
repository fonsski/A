-- Фикс 7 (КРИТИЧЕСКИЙ): чужие посты были невидимы всем.
-- Подзапрос к privacy_settings внутри политик posts/comments выполнялся
-- от имени ЗРИТЕЛЯ, а RLS privacy_settings отдаёт только свою строку →
-- правило приватности всегда NULL → wall_allows(null) → пост скрыт.
-- Выносим чтение правила в security definer-функцию.

create or replace function public.wall_rule(owner uuid, kind text)
returns text
language sql stable security definer set search_path = public as $$
  select case kind
    when 'visible'  then wall_visible_to
    when 'post'     then wall_post_by
    when 'comments' then comments_by
    when 'online'   then online_visible_to
  end
  from privacy_settings where user_id = owner;
$$;

drop policy if exists posts_read on public.posts;
create policy posts_read on public.posts for select using (
  wall_allows(wall_owner_id, auth.uid(),
              coalesce(public.wall_rule(wall_owner_id, 'visible'), 'all')));

drop policy if exists posts_write on public.posts;
create policy posts_write on public.posts for insert with check (
  author_id = auth.uid()
  and wall_allows(wall_owner_id, auth.uid(),
                  coalesce(public.wall_rule(wall_owner_id, 'post'), 'friends')));

drop policy if exists comments_write on public.comments;
create policy comments_write on public.comments for insert with check (
  author_id = auth.uid()
  and exists (select 1 from public.posts p where p.id = post_id
    and wall_allows(p.wall_owner_id, auth.uid(),
                    coalesce(public.wall_rule(p.wall_owner_id, 'comments'),
                             'all'))));

-- ── «Был(а) в сети» ────────────────────────────────────────────────────────
alter table public.profiles add column if not exists last_seen_at timestamptz;

-- Последний визит с учётом приватности, по-телеграмному:
-- скрыл свой онлайн (online_visible_to = 'me') — не видишь чужой.
create or replace function public.last_seen_of(target uuid)
returns timestamptz
language sql stable security definer set search_path = public as $$
  select p.last_seen_at
  from profiles p
  where p.id = target
    and coalesce(public.wall_rule(auth.uid(), 'online'), 'all') <> 'me'
    and wall_allows(target, auth.uid(),
                    coalesce(public.wall_rule(target, 'online'), 'all'));
$$;
