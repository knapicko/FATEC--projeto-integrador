import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, json, marcarSolicitacaoComoPaga, supabasePublishableKey, supabaseSecretKey } from '../_shared/stripe.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = supabaseSecretKey();
const anonKey = supabasePublishableKey();
const admin = createClient(url, serviceKey);

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) return json({ error: 'Não autenticado.' }, 401);
    const authClient = createClient(url, anonKey);
    const { data: authData } = await authClient.auth.getUser(authorization.substring(7));
    if (!authData.user) return json({ error: 'Sessão inválida.' }, 401);

    const body = await request.json();
    const id = Number(body.id_solicitacao);
    const usuario = await admin.from('usuarios').select('id_usuario').eq('auth_id', authData.user.id).maybeSingle();
    const pagamento = await admin
      .from('pagamentos_stripe')
      .select('status, metodo_pagamento, stripe_payment_intent_id, pix_copia_cola, pix_qr_code_url, solicitacoes!inner(fk_usuario)')
      .eq('fk_solicitacao', id)
      .maybeSingle();
    if (!pagamento.data || Number(pagamento.data.solicitacoes?.fk_usuario) !== Number(usuario.data?.id_usuario)) {
      return json({ error: 'Pagamento não encontrado.' }, 404);
    }
    if (pagamento.data.status === 'succeeded') {
      await marcarSolicitacaoComoPaga(admin, id);
    }
    return json(pagamento.data);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : 'Erro interno.' }, 500);
  }
});
