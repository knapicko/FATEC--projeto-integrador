export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function getSupabaseKey(newVariable: string, legacyVariable: string): string {
  const raw = Deno.env.get(newVariable)?.trim();
  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (typeof parsed === 'string') return parsed;
      if (parsed?.default) return String(parsed.default);
      const first = Object.values(parsed ?? {})[0];
      if (first) return String(first);
    } catch (_) {
      return raw;
    }
  }
  const legacy = Deno.env.get(legacyVariable)?.trim();
  if (!legacy) throw new Error(`${legacyVariable} nÃ£o configurada no Supabase.`);
  return legacy;
}

export function supabaseSecretKey(): string {
  return getSupabaseKey('SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY');
}

export function supabasePublishableKey(): string {
  return getSupabaseKey('SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY');
}

export function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function stripeKey(): string {
  const key = Deno.env.get('STRIPE_SECRET_KEY')?.trim() ?? '';
  if (!key) throw new Error('STRIPE_SECRET_KEY não configurada no Supabase.');
  return key;
}

export async function stripeRequest(
  path: string,
  params: URLSearchParams,
  idempotencyKey?: string,
) {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${stripeKey()}`,
    'Content-Type': 'application/x-www-form-urlencoded',
  };
  if (idempotencyKey) headers['Idempotency-Key'] = idempotencyKey;

  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    method: 'POST',
    headers,
    body: params.toString(),
  });
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body?.error?.message ?? 'Stripe recusou a operação.');
  }
  return body;
}

export function qrData(paymentIntent: Record<string, any>) {
  const action = paymentIntent.next_action?.pix_display_qr_code ?? {};
  return {
    pix_copia_cola:
      action.data ?? action.pix_code ?? action.qr_code ?? null,
    pix_qr_code_url:
      action.image_url_png ?? action.image_url_svg ?? null,
  };
}

export async function marcarSolicitacaoComoPaga(
  supabase: any,
  idSolicitacao: number,
) {
  const { error } = await supabase
    .from('solicitacoes')
    .update({ fk_status: 3 })
    .eq('id_solicitacao', idSolicitacao);
  if (error) {
    throw new Error(`NÃ£o foi possÃ­vel marcar a solicitaÃ§Ã£o como paga: ${error.message}`);
  }
}
