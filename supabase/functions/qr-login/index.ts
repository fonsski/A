// Edge Function «qr-login»: вход по QR-коду, как в Telegram.
//
// Схема: экран входа (create) показывает QR с id и code; залогиненный телефон
// сканирует его (info → approve); экран входа опрашивает (claim) и, когда
// вход подтверждён, получает одноразовый token_hash и меняет его на сессию
// через supabase.auth.verifyOtp({ token_hash, type: 'magiclink' }).
//
// Деплой: Supabase → Edge Functions → Deploy a new function → Via Editor,
// имя `qr-login`, вставить этот файл. SUPABASE_URL и SERVICE_ROLE_KEY функция
// получает из окружения сама. Таблицу создаёт supabase/fix_019_qr_login.sql.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const TTL_SECONDS = 120;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });

async function sha256(text: string): Promise<string> {
  const bytes = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function randomHex(bytes: number): string {
  const buf = crypto.getRandomValues(new Uint8Array(bytes));
  return [...buf].map((b) => b.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  let payload: Record<string, string>;
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: 'bad_request' }, 400);
  }
  const { action } = payload;
  const nowIso = new Date().toISOString();

  // ── create: экран входа просит новый QR ────────────────────────────────────
  if (action === 'create') {
    // Заодно подчищаем протухшее.
    await admin.from('qr_logins').delete().lt('expires_at', nowIso);
    const id = crypto.randomUUID();
    const code = randomHex(16);
    const claim = randomHex(32);
    const { error } = await admin.from('qr_logins').insert({
      id,
      code_hash: await sha256(code),
      claim_hash: await sha256(claim),
      device: (payload.device ?? '').slice(0, 80) || null,
      expires_at: new Date(Date.now() + TTL_SECONDS * 1000).toISOString(),
    });
    if (error) return json({ error: 'create_failed' }, 500);
    return json({ id, code, claim, expires_in: TTL_SECONDS });
  }

  // Дальше нужна живая строка с верным кодом/секретом.
  const { data: row } = await admin
    .from('qr_logins')
    .select('*')
    .eq('id', payload.id ?? '')
    .maybeSingle();
  if (!row) return json({ status: 'expired' });
  const expired = new Date(row.expires_at).getTime() < Date.now();

  // ── info / approve: телефон, пользователь залогинен ────────────────────────
  if (action === 'info' || action === 'approve') {
    const jwt = (req.headers.get('Authorization') ?? '').replace('Bearer ', '');
    const { data: auth } = await admin.auth.getUser(jwt);
    if (!auth?.user) return json({ error: 'unauthorized' }, 401);
    if (expired || row.status !== 'pending') return json({ status: 'expired' });
    if (row.code_hash !== (await sha256(payload.code ?? ''))) {
      return json({ error: 'bad_code' }, 403);
    }
    if (action === 'info') {
      return json({ status: 'pending', device: row.device ?? 'Новое устройство' });
    }
    await admin
      .from('qr_logins')
      .update({ status: 'approved', user_id: auth.user.id })
      .eq('id', row.id);
    return json({ status: 'approved' });
  }

  // ── claim: экран входа опрашивает ──────────────────────────────────────────
  if (action === 'claim') {
    if (row.claim_hash !== (await sha256(payload.claim ?? ''))) {
      return json({ error: 'bad_claim' }, 403);
    }
    if (expired || row.status === 'used') return json({ status: 'expired' });
    if (row.status === 'pending') return json({ status: 'pending' });

    // approved → одноразовый токен для verifyOtp, строку гасим.
    const { data: user } = await admin.auth.admin.getUserById(row.user_id);
    const email = user?.user?.email;
    if (!email) return json({ error: 'no_email' }, 500);
    const { data: link, error } = await admin.auth.admin.generateLink({
      type: 'magiclink',
      email,
    });
    const tokenHash = link?.properties?.hashed_token;
    if (error || !tokenHash) return json({ error: 'link_failed' }, 500);
    await admin.from('qr_logins').update({ status: 'used' }).eq('id', row.id);
    return json({ status: 'approved', token_hash: tokenHash });
  }

  return json({ error: 'unknown_action' }, 400);
});
