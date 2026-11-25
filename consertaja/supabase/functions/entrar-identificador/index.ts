// Login por CPF, CNPJ ou telefone.
//
// O app NÃO consulta mais as tabelas de CPF/e-mail/telefone para descobrir o
// e-mail da conta: manda o identificador e a senha para cá, o servidor acha a
// conta, faz o login e devolve só o refresh token. O e-mail nunca sai do
// servidor, e cada identificador tem limite de tentativas erradas.
//
// Publicar SEM verificação de JWT (é chamada antes do login):
//   supabase functions deploy entrar-identificador --no-verify-jwt
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, json, supabasePublishableKey, supabaseSecretKey } from '../_shared/stripe.ts';

const MAX_TENTATIVAS = 5;
const JANELA_MINUTOS = 15;

async function sha256(texto: string) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(texto));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ ok: false, erro: 'metodo' }, 405);

  let identificador = '';
  let senha = '';
  try {
    const body = await request.json();
    identificador = String(body?.identificador ?? '').trim();
    senha = String(body?.senha ?? '');
  } catch (_) {
    return json({ ok: false, erro: 'requisicao' }, 400);
  }
  const digitos = identificador.replace(/\D/g, '');
  if (digitos.length < 10 || digitos.length > 14 || !senha || senha.length > 200) {
    return json({ ok: false, erro: 'nao_encontrado' });
  }

  const url = Deno.env.get('SUPABASE_URL')!;
  const admin = createClient(url, supabaseSecretKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const chave = await sha256(`login:${digitos}`);

  // Limite de tentativas erradas por identificador.
  const desde = new Date(Date.now() - JANELA_MINUTOS * 60 * 1000).toISOString();
  const { count } = await admin
    .from('tentativas_login')
    .select('id', { count: 'exact', head: true })
    .eq('chave', chave)
    .gte('data_tentativa', desde);
  if ((count ?? 0) >= MAX_TENTATIVAS) {
    return json({ ok: false, erro: 'bloqueado' });
  }

  const registrarFalha = () =>
    admin.from('tentativas_login').insert({ chave }).then(() => undefined);

  // Acha o e-mail (ou o telefone) da conta — só aqui no servidor.
  const { data: cred, error: credErro } = await admin.rpc('credencial_login', {
    p_identificador: digitos,
  });
  const linha = Array.isArray(cred) ? cred[0] : cred;
  if (credErro || !linha || (!linha.email && !linha.telefone)) {
    await registrarFalha();
    return json({ ok: false, erro: 'nao_encontrado' });
  }

  const publico = createClient(url, supabasePublishableKey(), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = linha.email
    ? await publico.auth.signInWithPassword({ email: linha.email, password: senha })
    : await publico.auth.signInWithPassword({ phone: linha.telefone, password: senha });

  if (error || !data.session) {
    const msg = (error?.message ?? '').toLowerCase();
    if (msg.includes('not confirmed')) return json({ ok: false, erro: 'email_nao_confirmado' });
    await registrarFalha();
    return json({ ok: false, erro: 'senha' });
  }

  // Deu certo: zera as tentativas desse identificador.
  await admin.from('tentativas_login').delete().eq('chave', chave);
  return json({ ok: true, refresh_token: data.session.refresh_token });
});
