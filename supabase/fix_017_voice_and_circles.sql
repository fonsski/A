-- fix_017: голосовые сообщения и видеокружки.
-- Новые типы вложений + длительность и волна голосового.

alter table public.messages
  drop constraint if exists messages_attachment_type_check;
alter table public.messages
  add constraint messages_attachment_type_check
  check (attachment_type in ('image', 'video', 'file', 'voice', 'circle'));

alter table public.messages
  add column if not exists duration_ms int check (duration_ms >= 0),
  add column if not exists waveform jsonb;  -- массив чисел 0..31
