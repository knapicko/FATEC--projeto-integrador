import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, json, marcarSolicitacaoComoPaga, qrData, stripeRequest, supabasePublishableKey, supabaseSecretKey } from '../_shared/stripe.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceKey = supabaseSecretKey();
const anonKey = supabasePublishableKey();
const admin = createClient(supabaseUrl, serviceKey);

// Números de cartão de teste da Stripe -> PaymentMethod de teste.
const TEST_PAYMENT_METHODS: Record<string, string> = {
  '4242424242424242': 'pm_card_visa',
  '4000056655665556': 'pm_card_visa_debit',
  '4000000760000002': 'pm_card_br',
  '5555555555554444': 'pm_card_mastercard',
  '2223003122003222': 'pm_card_mastercard',
  '5200828282828210': 'pm_card_mastercard_debit',
  '378282246310005': 'pm_card_amex',
  '6011111111111117': 'pm_card_discover',
  '3056930009020004': 'pm_card_diners',
  '3566002020360505': 'pm_card_jcb',
  // Cartões que simulam recusa
  '4000000000000002': 'pm_card_chargeDeclined',
  '4000000000009995': 'pm_card_chargeDeclinedInsufficientFunds',
  '4000000000000127': 'pm_card_chargeDeclinedIncorrectCvc',
  '4000000000000069': 'pm_card_chargeDeclinedExpiredCard',
};

function cents(value: unknown) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) {
    throw new Error('O valor da solicitação é inválido.');
  }
  return Math.round(number * 100);
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'Método não permitido.' }, 405);

  try {
    const authorization = request.headers.get('Authorization');
    if (!authorization?.startsWith('Bearer ')) return json({ error: 'Não autenticado.' }, 401);
    const token = authorization.substring(7).trim();
    const authClient = createClient(supabaseUrl, anonKey);
    const { data: authData, error: authError } = await authClient.auth.getUser(token);
    if (authError || !authData.user) return json({ error: 'Sessão inválida.' }, 401);

    const body = await request.json();
    const idSolicitacao = Number(body.id_solicitacao);
    const metodoPagamento = String(body.metodo_pagamento ?? 'pix').toLowerCase();
    if (!Number.isInteger(idSolicitacao)) return json({ error: 'Solicitação inválida.' }, 400);
    if (!['pix', 'card_credit', 'card_debit'].includes(metodoPagamento)) {
      return json({ error: 'Método de pagamento não suportado.' }, 400);
    }

    const { data: usuario } = await admin
      .from('usuarios')
      .select('id_usuario')
      .eq('auth_id', authData.user.id)
      .maybeSingle();
    if (!usuario) return json({ error: 'Usuário não encontrado.' }, 403);

    const { data: solicitacao, error: solicitacaoError } = await admin
      .from('solicitacoes')
      .select('id_solicitacao, fk_usuario, fk_servico_prof, valor_final')
      .eq('id_solicitacao', idSolicitacao)
      .limit(1)
      .maybeSingle();
    if (solicitacaoError) {
      // Erro do banco (ex.: permission denied) não é "não encontrada".
      console.error('Erro ao consultar solicitação para pagamento', {
        idSolicitacao,
        idUsuario: usuario.id_usuario,
        erro: solicitacaoError.message,
      });
      return json({
        error: 'Erro ao consultar a solicitação.',
        id_solicitacao_recebido: idSolicitacao,
        detalhe: solicitacaoError.message,
      }, 500);
    }
    if (!solicitacao) {
      return json({
        error: 'Solicitação não encontrada.',
        id_solicitacao_recebido: idSolicitacao,
        detalhe: 'Nenhuma linha retornada para este id_solicitacao.',
      }, 404);
    }
    if (Number(solicitacao.fk_usuario) !== Number(usuario.id_usuario)) {
      return json({ error: 'A solicitação não pertence ao usuário autenticado.' }, 403);
    }

    const existente = await admin
      .from('pagamentos_stripe')
      .select('*')
      .eq('fk_solicitacao', idSolicitacao)
      .maybeSingle();
    const metodoExistente = String(existente.data?.metodo_pagamento ?? '').toLowerCase();
    if (existente.data && metodoExistente === metodoPagamento && !['canceled', 'failed'].includes(existente.data.status)) {
      if (existente.data.status === 'succeeded') {
        await marcarSolicitacaoComoPaga(admin, idSolicitacao);
      }
      return json({
        id_solicitacao: idSolicitacao,
        payment_intent_id: existente.data.stripe_payment_intent_id,
        status: existente.data.status,
        pix_copia_cola: existente.data.pix_copia_cola,
        pix_qr_code_url: existente.data.pix_qr_code_url,
        valor_centavos: existente.data.valor_centavos,
        moeda: existente.data.moeda,
      });
    }

    let valor = solicitacao.valor_final;
    if (valor == null && solicitacao.fk_servico_prof != null) {
      const servico = await admin
        .from('servicos_profissional')
        .select('valor')
        .eq('id_servico_prof', solicitacao.fk_servico_prof)
        .maybeSingle();
      valor = servico.data?.valor;
    }
    const taxa = Number(Deno.env.get('STRIPE_SERVICE_FEE_CENTS') ?? '300');
    const valorCentavos = cents(valor) + (Number.isFinite(taxa) ? taxa : 300);

    const params = new URLSearchParams();
    params.set('amount', String(valorCentavos));
    params.set('currency', 'brl');
    // As versões novas da API da Stripe não aceitam mais `payment_method_types`:
    // os métodos disponíveis vêm do Dashboard. Como alguns deles podem exigir
    // redirecionamento, com confirm=true a Stripe exige um `return_url`.
    // Ele só é usado se algum método precisar redirecionar o cliente.
    params.set(
      'return_url',
      Deno.env.get('STRIPE_RETURN_URL')?.trim() || `${supabaseUrl}/functions/v1/stripe-webhook`,
    );
    if (metodoPagamento === 'pix') {
      params.set('payment_method_data[type]', 'pix');
    } else {
      const card = body.cartao ?? {};
      const number = String(card.number ?? '').replace(/\D/g, '');
      const expMonth = String(card.exp_month ?? '');
      const expYear = String(card.exp_year ?? '');
      const cvc = String(card.cvc ?? '');
      if (number.length < 12 || !/^\d{1,2}$/.test(expMonth) || !/^\d{2,4}$/.test(expYear) || !/^\d{3,4}$/.test(cvc)) {
        return json({ error: 'Dados do cartão de teste inválidos.' }, 400);
      }
      // A Stripe bloqueia o envio de número de cartão direto para a API
      // (raw card data). Em modo de teste usamos o PaymentMethod de teste
      // equivalente ao número digitado (https://docs.stripe.com/testing).
      const paymentMethodTeste = TEST_PAYMENT_METHODS[number];
      if (!paymentMethodTeste) {
        return json({
          error: 'Cartão não aceito no modo de teste. Use um cartão de teste da Stripe, '
            + 'como 4242 4242 4242 4242 (crédito) ou 4000 0566 5566 5556 (débito).',
        }, 400);
      }
      params.set('payment_method', paymentMethodTeste);
    }
    params.set('confirm', 'true');
    params.set('description', `ConsertaJá - solicitação ${idSolicitacao}`);
    params.set('metadata[id_solicitacao]', String(idSolicitacao));
    params.set('metadata[id_usuario]', String(usuario.id_usuario));

    const intent = await stripeRequest(
      'payment_intents',
      params,
      // Chave única por tentativa: reutilizar a mesma chave com parâmetros
      // diferentes (ex.: após corrigir o erro ou trocar de cartão) faz a
      // Stripe responder com "idempotency_error".
      `consertaja-solicitacao-${idSolicitacao}-${metodoPagamento}-${crypto.randomUUID()}`,
    );
    const qr = qrData(intent);

    if (intent.status === 'succeeded') {
      await marcarSolicitacaoComoPaga(admin, idSolicitacao);
    }

    const { error: insertError } = await admin.from('pagamentos_stripe').upsert({
      fk_solicitacao: idSolicitacao,
      stripe_payment_intent_id: intent.id,
      metodo_pagamento: metodoPagamento === 'pix' ? 'Pix' : 'Cartão',
      status: intent.status,
      valor_centavos: valorCentavos,
      moeda: intent.currency ?? 'brl',
      pix_copia_cola: qr.pix_copia_cola,
      pix_qr_code_url: qr.pix_qr_code_url,
    }, { onConflict: 'fk_solicitacao' });
    if (insertError) throw new Error(`Não foi possível salvar o pagamento: ${insertError.message}`);

    const { error: statusError } = await admin
      .from('solicitacoes')
      .update({ fk_status: 2 })
      .eq('id_solicitacao', idSolicitacao);
    if (statusError) throw new Error(`Não foi possível atualizar o status: ${statusError.message}`);

    return json({
      id_solicitacao: idSolicitacao,
      payment_intent_id: intent.id,
      status: intent.status,
      pix_copia_cola: qr.pix_copia_cola,
      pix_qr_code_url: qr.pix_qr_code_url,
      valor_centavos: valorCentavos,
      moeda: intent.currency ?? 'brl',
    });
  } catch (error) {
    console.error(error);
    return json({ error: error instanceof Error ? error.message : 'Erro interno.' }, 500);
  }
});
