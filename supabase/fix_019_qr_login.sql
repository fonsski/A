-- fix_019: вход по QR-коду.
-- Таблицей пользуется только Edge Function qr-login (service role):
-- RLS включён и политик нет, поэтому клиентам таблица недоступна напрямую.

create table if not exists public.qr_logins (
  id         uuid primary key,
  code_hash  text not null,            -- sha256 кода из QR (его видит телефон)
  claim_hash text not null,            -- sha256 секрета, который знает только экран входа
  device     text,                     -- подпись устройства для окна подтверждения
  status     text not null default 'pending'
             check (status in ('pending', 'approved', 'used')),
  user_id    uuid references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

alter table public.qr_logins enable row level security;
revoke all on public.qr_logins from anon, authenticated;

create index if not exists qr_logins_expires_idx on public.qr_logins (expires_at);
