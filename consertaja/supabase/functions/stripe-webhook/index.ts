import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, marcarSolicitacaoComoPaga, supabaseSecretKey } from '../_shared/stripe.ts';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  supabaseSecretKey(),
);

async function validarAssinatura(payload: string, header: string, secret: string) {
  const partes = header.split(',');
  const timestamp = partes.find((item) => item.startsWith('t='))?.substring(2);
  const assinatura = partes.find((item) => item.startsWith('v1='))?.substring(3);
  if (!timestamp || !assinatura) return false;

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const digest = await crypto.subtle.sign(
    'HMAC',
    key,
    encoder.encode(`${timestamp}.${payload}`),
  );
  const esperado = [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
  return esperado === assinatura && Math.abs(Date.now() / 1000 - Number(timestamp)) < 300;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return new Response('Method Not Allowed', { status: 405 });

  try {
    const payload = await request.text();
    const signature = request.headers.get('Stripe-Signature');
    const secret = Deno.env.get('STRIPE_WEBHOOK_SECRET')?.trim();
    if (!signature || !secret || !(await validarAssinatura(payload, signature, secret))) {
      return new Response('Assinatura inválida.', { status: 400 });
    }

    const event = JSON.parse(payload);
    const object = event.data?.object ?? {};
    const intentId = object.id;
    const status = object.status;
    if (!intentId) return new Response('ok', { status: 200 });

    const pagamento = await supabase
      .from('pagamentos_stripe')
      .select('fk_solicitacao')
      .eq('stripe_payment_intent_id', intentId)
      .maybeSingle();
    if (!pagamento.data) return new Response('ok', { status: 200 });

    const updates: Record<string, unknown> = {
      status,
      ultimo_evento_stripe: event.id ?? event.type,
      data_atualizacao: new Date().toISOString(),
    };
    if (status === 'succeeded') {
      updates.data_pagamento = new Date().toISOString();
      await marcarSolicitacaoComoPaga(supabase, pagamento.data.fk_solicitacao);
    }

    await supabase
      .from('pagamentos_stripe')
      .update(updates)
      .eq('stripe_payment_intent_id', intentId);
    return new Response('ok', { status: 200 });
  } catch (error) {
    console.error(error);
    return new Response('Erro interno.', { status: 500 });
  }
});
