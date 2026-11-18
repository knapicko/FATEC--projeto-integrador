// Libera o pagamento de uma solicitação CONCLUÍDA (fk_status = 6: cliente e
// profissional confirmaram a conclusão).
//
// - Cartão: o PaymentIntent foi criado com capture_method=manual e está em
//   "requires_capture" (valor autorizado e retido). Aqui ele é capturado.
// - Pix: a Stripe já recebeu o valor na conta da plataforma; ele ficou retido
//   lá e aqui só marcamos como liberado para o profissional.
//
// Idempotente: chamar de novo não captura duas vezes.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, json, stripeRequest, supabasePublishableKey, supabaseSecretKey } from '../_shared/stripe.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const admin = createClient(url, supabaseSecretKey());
const anonKey = supabasePublishableKey();

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Método não permitido.' }, 405);
  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) return json({ error: 'Não autenticado.' }, 401);
    const authClient = createClient(url, anonKey);
    const { data: authData } = await authClient.auth.getUser(authorization.substring(7).trim());
    if (!authData.user) return json({ error: 'Sessão inválida.' }, 401);

    const body = await request.json();
    const id = Number(body.id_solicitacao);
    if (!Number.isInteger(id)) return json({ error: 'Solicitação inválida.' }, 400);

    const { data: usuario } = await admin
      .from('usuarios').select('id_usuario').eq('auth_id', authData.user.id).maybeSingle();
    if (!usuario) return json({ error: 'Usuário não encontrado.' }, 403);

    const { data: sol } = await admin
      .from('solicitacoes')
      .select('id_solicitacao, fk_status, fk_usuario, fk_profissional, fk_grupo_empresa, pagamento_liberado')
      .eq('id_solicitacao', id)
      .maybeSingle();
    if (!sol) return json({ error: 'Solicitação não encontrada.' }, 404);

    // Só o cliente ou alguém do lado do profissional/empresa.
    let participa = Number(sol.fk_usuario) === Number(usuario.id_usuario);
    if (!participa) {
      const { data: profs } = await admin
        .from('dados_profissionais')
        .select('id_profissional, fk_grupo_empresa')
        .eq('fk_usuario', usuario.id_usuario);
      participa = (profs ?? []).some((p: any) =>
        Number(p.id_profissional) === Number(sol.fk_profissional) ||
        (sol.fk_grupo_empresa != null && Number(p.fk_grupo_empresa) === Number(sol.fk_grupo_empresa)));
    }
    if (!participa) return json({ error: 'Solicitação não encontrada.' }, 404);

    if (Number(sol.fk_status) !== 6) {
      return json({ liberado: false, motivo: 'O serviço ainda não foi concluído pelos dois lados.' });
    }
    if (sol.pagamento_liberado) return json({ liberado: true });

    const { data: pagamento } = await admin
      .from('pagamentos_stripe')
      .select('stripe_payment_intent_id, status')
      .eq('fk_solicitacao', id)
      .maybeSingle();

    if (pagamento?.status === 'requires_capture' && pagamento.stripe_payment_intent_id) {
      const intent = await stripeRequest(
        `payment_intents/${pagamento.stripe_payment_intent_id}/capture`,
        new URLSearchParams(),
        `consertaja-captura-${id}`,
      );
      await admin
        .from('pagamentos_stripe')
        .update({ status: intent.status, data_atualizacao: new Date().toISOString() })
        .eq('fk_solicitacao', id);
    }

    await admin
      .from('solicitacoes')
      .update({ pagamento_liberado: true, data_pagamento_liberado: new Date().toISOString() })
      .eq('id_solicitacao', id);

    return json({ liberado: true });
  } catch (error) {
    console.error(error);
    return json({ error: error instanceof Error ? error.message : 'Erro interno.' }, 500);
  }
});
