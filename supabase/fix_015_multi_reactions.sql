-- fix_015: несколько реакций от одного пользователя на одно сообщение.
-- Было: primary key (message_id, user_id) — одна реакция на сообщение.
-- Стало: primary key (message_id, user_id, emoji).

alter table public.message_reactions
  drop constraint message_reactions_pkey;

alter table public.message_reactions
  add primary key (message_id, user_id, emoji);
