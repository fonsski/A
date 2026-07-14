-- Фикс 2: редактору профиля нужен номер телефона.
alter table public.profiles add column if not exists phone text;
