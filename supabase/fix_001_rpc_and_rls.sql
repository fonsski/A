-- Фикс 1: в username_available параметр `name` конфликтовал с колонкой
-- reserved_usernames.name (колонка приоритетнее) — функция всегда
-- возвращала false. Переименовываем параметры в обеих RPC.
drop function if exists public.username_available(citext);
create function public.username_available(candidate citext)
returns boolean
language sql stable security definer set search_path = public as $$
  select not exists (select 1 from profiles p where p.username = candidate)
     and not exists (select 1 from reserved_usernames r where r.name = candidate);
$$;

drop function if exists public.email_for_username(citext);
create function public.email_for_username(login citext)
returns text
language sql stable security definer set search_path = public as $$
  select u.email from auth.users u
  join profiles p on p.id = u.id
  where p.username = login;
$$;

-- Фикс 2: служебные таблицы были без RLS — anon-ключ мог в них писать.
alter table public.reserved_usernames enable row level security;
create policy reserved_read on public.reserved_usernames
  for select using (true);

alter table public.username_history enable row level security;
-- Политик нет: пишет только security definer-триггер, читать никому не нужно.
