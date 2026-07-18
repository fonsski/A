-- Схема авторизации «А?»: профили с уникальным @ником.
-- Применять в SQL Editor проекта Supabase (или supabase db push).
-- В Auth → Settings должно быть включено "Confirm email".

create extension if not exists citext;

-- ── Профили ────────────────────────────────────────────────────────────────
-- Создаются триггером при регистрации; username = null до шага онбординга.
create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  username     citext unique,
  display_name text,
  bio          text,
  avatar_url   text,
  phone        text,
  last_seen_at timestamptz,
  links        jsonb not null default '[]',
  created_at   timestamptz not null default now(),
  -- 3–30 символов: строчная латиница/цифры/подчёркивание,
  -- точки — только одиночные и не по краям. Зеркало lib/auth/username.dart.
  constraint username_format check (
    username is null or username ~ '^[a-z0-9](\.?[a-z0-9_]){2,29}$'
  )
);

alter table public.profiles enable row level security;

create policy profiles_read_all on public.profiles
  for select using (true);          -- профили публичны (ник, имя, аватар)

create policy profiles_update_own on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- ── Автосоздание профиля при регистрации ──────────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── Зарезервированные ники ─────────────────────────────────────────────────
create table if not exists public.reserved_usernames (name citext primary key);
insert into public.reserved_usernames (name) values
  ('admin'), ('support'), ('help'), ('root'), ('moderator'), ('a'), ('api')
on conflict do nothing;

alter table public.reserved_usernames enable row level security;
create policy reserved_read on public.reserved_usernames
  for select using (true);

-- ── История ников (защита от фишинга через освободившиеся ники) ───────────
create table if not exists public.username_history (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  username   citext not null,
  changed_at timestamptz not null default now()
);

-- Пишет только security definer-триггер, читать никому не нужно.
alter table public.username_history enable row level security;

create or replace function public.log_username_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.username is not null and old.username is distinct from new.username then
    insert into public.username_history (user_id, username)
    values (old.id, old.username);
  end if;
  return new;
end $$;

drop trigger if exists on_username_change on public.profiles;
create trigger on_username_change
  before update of username on public.profiles
  for each row execute function public.log_username_change();

-- ── RPC: живая проверка ника на экране онбординга ─────────────────────────
-- Имя параметра не должно совпадать с именами колонок (колонка приоритетнее).
create or replace function public.username_available(candidate citext)
returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (select 1 from profiles p where p.username = candidate)
     and not exists (select 1 from reserved_usernames r where r.name = candidate);
$$;

-- ── RPC: вход по нику (ищет почту; security definer, т.к. auth.users закрыт)
create or replace function public.email_for_username(login citext)
returns text
language sql stable security definer set search_path = public as $$
  select u.email from auth.users u
  join profiles p on p.id = u.id
  where p.username = login;
$$;

-- Ограничиваем прямой доступ к RPC анонимам не нужно:
-- email_for_username возвращает почту только при точном знании ника,
-- что эквивалентно обычной форме входа.

-- ════════════════════════════════════════════════════════════════════════
-- ЧАСТЬ 2: чаты, стенка, приватность
-- ════════════════════════════════════════════════════════════════════════

-- ── Друзья ─────────────────────────────────────────────────────────────────
create table if not exists public.friendships (
  user_a       uuid not null references public.profiles (id) on delete cascade,
  user_b       uuid not null references public.profiles (id) on delete cascade,
  status       text not null default 'pending' check (status in ('pending','accepted')),
  requested_by uuid not null,
  created_at   timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)          -- одна строка на пару
);

create or replace function public.are_friends(x uuid, y uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from friendships
    where user_a = least(x, y) and user_b = greatest(x, y)
      and status = 'accepted');
$$;

alter table public.friendships enable row level security;

create policy friendships_select on public.friendships
  for select using (auth.uid() in (user_a, user_b));

create policy friendships_insert on public.friendships
  for insert with check (
    auth.uid() = requested_by
    and auth.uid() in (user_a, user_b)
    and status = 'pending');

-- Принять может только вторая сторона (не автор заявки).
create policy friendships_accept on public.friendships
  for update
  using (auth.uid() in (user_a, user_b) and auth.uid() <> requested_by)
  with check (status = 'accepted');

create policy friendships_delete on public.friendships
  for delete using (auth.uid() in (user_a, user_b));

-- ── Настройки приватности ──────────────────────────────────────────────────
create table if not exists public.privacy_settings (
  user_id          uuid primary key references public.profiles (id) on delete cascade,
  wall_visible_to  text not null default 'all'     check (wall_visible_to  in ('all','friends','me')),
  wall_post_by     text not null default 'friends' check (wall_post_by     in ('all','friends','me')),
  comments_by      text not null default 'all'     check (comments_by      in ('all','friends','nobody')),
  phone_visible_to text not null default 'friends' check (phone_visible_to in ('all','friends','me')),
  online_visible_to text not null default 'all'    check (online_visible_to in ('all','friends','me'))
);

alter table public.privacy_settings enable row level security;
create policy privacy_own on public.privacy_settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Профиль + приватность создаются вместе (обновляем триггер из части 1).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id);
  insert into public.privacy_settings (user_id) values (new.id);
  return new;
end $$;

create or replace function public.wall_allows(owner uuid, viewer uuid, rule text)
returns boolean language sql stable security definer set search_path = public as $$
  select owner = viewer or case rule
    when 'all'     then true
    when 'friends' then are_friends(owner, viewer)
    else false end;
$$;

-- ── Чёрный список ──────────────────────────────────────────────────────────
create table if not exists public.blacklist (
  owner_id   uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, blocked_id),
  check (owner_id <> blocked_id)
);

alter table public.blacklist enable row level security;
create policy blacklist_own on public.blacklist
  for all using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create or replace function public.is_blocked(owner uuid, target uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from blacklist
                  where owner_id = owner and blocked_id = target);
$$;

-- ── Чаты 1:1 ───────────────────────────────────────────────────────────────
create table if not exists public.chats (
  id                uuid primary key default gen_random_uuid(),
  kind              text not null default 'dm' check (kind in ('dm','group')),
  pinned_message_id bigint, -- FK добавляется после создания messages
  created_at        timestamptz not null default now()
);

create table if not exists public.chat_members (
  chat_id              uuid not null references public.chats (id) on delete cascade,
  user_id              uuid not null references public.profiles (id) on delete cascade,
  joined_at            timestamptz not null default now(),
  last_read_message_id bigint not null default 0,
  primary key (chat_id, user_id)
);

create table if not exists public.messages (
  id              bigint generated always as identity primary key,
  chat_id         uuid not null references public.chats (id) on delete cascade,
  author_id       uuid not null references public.profiles (id),
  body            text not null,
  image_url       text,   -- URL вложения (имя историческое)
  attachment_type text check (attachment_type in ('image', 'video', 'file')),
  attachment_name text,
  -- 'user' — обычное, 'clear'/'pin' — системные события.
  kind            text not null default 'user'
                  check (kind in ('user', 'clear', 'pin')),
  reply_to        bigint references public.messages (id) on delete set null,
  created_at      timestamptz not null default now(),
  check (kind <> 'user'
         or image_url is not null
         or length(body) between 1 and 4000)
);
create index if not exists messages_chat_idx on public.messages (chat_id, id);

alter table public.chats
  add constraint chats_pinned_message_fk
  foreign key (pinned_message_id) references public.messages (id)
  on delete set null;

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

-- «Удалить у себя»: персональное скрытие сообщений.
create table if not exists public.message_hidden (
  user_id    uuid   not null references public.profiles (id) on delete cascade,
  message_id bigint not null references public.messages (id) on delete cascade,
  primary key (user_id, message_id)
);

alter table public.message_hidden enable row level security;
create policy message_hidden_own on public.message_hidden
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Без security definer-функции политика chat_members ссылалась бы сама на себя.
create or replace function public.is_chat_member(chat uuid, member uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from chat_members
                 where chat_id = chat and user_id = member);
$$;

alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;

create policy chats_member on public.chats
  for select using (is_chat_member(id, auth.uid()));
create policy chat_members_visible on public.chat_members
  for select using (is_chat_member(chat_id, auth.uid()));
create policy chat_members_update_own on public.chat_members
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy messages_read on public.messages
  for select using (is_chat_member(chat_id, auth.uid()));
create policy messages_delete_own on public.messages
  for delete using (author_id = auth.uid());
create policy messages_send on public.messages
  for insert with check (
    author_id = auth.uid()
    and is_chat_member(chat_id, auth.uid())
    and not exists (
      select 1 from public.chat_members cm
      join public.blacklist b
        on (b.owner_id = cm.user_id and b.blocked_id = auth.uid())
        or (b.owner_id = auth.uid() and b.blocked_id = cm.user_id)
      where cm.chat_id = messages.chat_id));

-- Начать (или найти существующий) диалог с пользователем.
create or replace function public.start_dm(peer uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare c uuid;
begin
  if peer = auth.uid() then raise exception 'cannot dm yourself'; end if;
  if public.is_blocked(peer, auth.uid())
     or public.is_blocked(auth.uid(), peer) then
    raise exception 'blocked';
  end if;
  select cm.chat_id into c
    from chat_members cm
    join chat_members cm2 on cm2.chat_id = cm.chat_id and cm2.user_id = peer
    join chats ch on ch.id = cm.chat_id and ch.kind = 'dm'
   where cm.user_id = auth.uid()
   limit 1;
  if c is not null then return c; end if;
  insert into chats (kind) values ('dm') returning id into c;
  insert into chat_members (chat_id, user_id)
    values (c, auth.uid()), (c, peer);
  return c;
end $$;

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

create or replace function public.mark_read(chat uuid)
returns void language sql security definer set search_path = public as $$
  update chat_members
     set last_read_message_id =
         coalesce((select max(id) from messages where chat_id = chat), 0)
   where chat_id = chat and user_id = auth.uid();
$$;

-- Обзор чатов для списка: собеседник, последнее сообщение, непрочитанные.
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

-- ── Стенка ─────────────────────────────────────────────────────────────────
create table if not exists public.posts (
  id            uuid primary key default gen_random_uuid(),
  wall_owner_id uuid not null references public.profiles (id) on delete cascade,
  author_id     uuid not null references public.profiles (id),
  body          text not null check (length(body) between 1 and 10000),
  created_at    timestamptz not null default now()
);
create index if not exists posts_wall_idx on public.posts (wall_owner_id, created_at desc);

create table if not exists public.comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts (id) on delete cascade,
  author_id  uuid not null references public.profiles (id),
  body       text not null check (length(body) between 1 and 4000),
  image_url  text,
  created_at timestamptz not null default now()
);

create table if not exists public.reactions (
  post_id    uuid not null references public.posts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  kind       text not null default 'aga',
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)   -- одна реакция «Ага!» на пользователя
);

alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.reactions enable row level security;

-- Правило приватности читаем через security definer — RLS privacy_settings
-- отдаёт только свою строку, прямой подзапрос вернул бы NULL (fix_007).
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

-- Видимость поста = настройка стены её владельца; заблокированным — ничего.
create policy posts_read on public.posts for select using (
  wall_allows(wall_owner_id, auth.uid(),
              coalesce(public.wall_rule(wall_owner_id, 'visible'), 'all'))
  and not public.is_blocked(wall_owner_id, auth.uid()));

-- Писать на стену: своя — всегда, чужая — по настройке владельца.
create policy posts_write on public.posts for insert with check (
  author_id = auth.uid()
  and wall_allows(wall_owner_id, auth.uid(),
                  coalesce(public.wall_rule(wall_owner_id, 'post'), 'friends')));

create policy posts_delete_own on public.posts for delete
  using (auth.uid() in (author_id, wall_owner_id));

create policy comments_read on public.comments for select using (
  exists (select 1 from public.posts p where p.id = post_id));  -- пост уже отфильтрован RLS

create policy comments_write on public.comments for insert with check (
  author_id = auth.uid()
  and exists (select 1 from public.posts p where p.id = post_id
    and wall_allows(p.wall_owner_id, auth.uid(),
                    coalesce(public.wall_rule(p.wall_owner_id, 'comments'),
                             'all'))));

create policy reactions_read on public.reactions for select using (
  exists (select 1 from public.posts p where p.id = post_id));

create policy reactions_own on public.reactions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── Рекомендательная лента (см. fix_005) ──────────────────────────────────
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
      exp(-extract(epoch from now() - p.created_at) / 172800.0)
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

-- Последний визит с учётом приватности, по-телеграмному:
-- скрыл свой онлайн — не видишь чужой.
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

-- ── Storage: аватары и медиа чатов ─────────────────────────────────────────
insert into storage.buckets (id, name, public) values
  ('avatars', 'avatars', true),
  ('chat-media', 'chat-media', true)
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

create policy chat_media_read on storage.objects
  for select using (bucket_id = 'chat-media');
create policy chat_media_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'chat-media'
    and public.is_chat_member(((storage.foldername(name))[1])::uuid, auth.uid()));

-- ── Realtime ───────────────────────────────────────────────────────────────
alter publication supabase_realtime
  add table public.messages, public.posts, public.comments, public.reactions,
            public.blacklist, public.chats;
