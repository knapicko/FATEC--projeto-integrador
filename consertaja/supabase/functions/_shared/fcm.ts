// =============================================================================
// ConsertaJá — Firebase Cloud Messaging (API HTTP v1) para Edge Functions
//
// A credencial é a conta de serviço do Firebase, guardada SÓ no secret
// FIREBASE_SERVICE_ACCOUNT do Supabase (o JSON inteiro baixado do Console).
// Nada disso vai para o app nem para o repositório.
// =============================================================================

interface ContaServico {
  project_id: string;
  client_email: string;
  private_key: string;
}

let contaCache: ContaServico | null = null;
let tokenCache: { valor: string; expiraEm: number } | null = null;

export function contaServico(): ContaServico {
  if (contaCache) return contaCache;
  const bruto = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!bruto) throw new Error('Secret FIREBASE_SERVICE_ACCOUNT não configurado.');
  const conta = JSON.parse(bruto) as ContaServico;
  if (!conta.project_id || !conta.client_email || !conta.private_key) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT inválido (faltam project_id/client_email/private_key).');
  }
  contaCache = conta;
  return conta;
}

function base64Url(dados: Uint8Array | string): string {
  const bytes = typeof dados === 'string' ? new TextEncoder().encode(dados) : dados;
  let binario = '';
  for (const b of bytes) binario += String.fromCharCode(b);
  return btoa(binario).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function chavePrivada(pem: string): Promise<CryptoKey> {
  const corpo = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\\n/g, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(corpo), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

/** Token OAuth2 (escopo firebase.messaging), reaproveitado até expirar. */
export async function tokenAcesso(): Promise<string> {
  const agora = Math.floor(Date.now() / 1000);
  if (tokenCache && tokenCache.expiraEm - 60 > agora) return tokenCache.valor;

  const conta = contaServico();
  const cabecalho = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const corpo = base64Url(JSON.stringify({
    iss: conta.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: agora,
    exp: agora + 3600,
  }));
  const assinatura = new Uint8Array(await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    await chavePrivada(conta.private_key),
    new TextEncoder().encode(`${cabecalho}.${corpo}`),
  ));
  const jwt = `${cabecalho}.${corpo}.${base64Url(assinatura)}`;

  const resposta = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const json = await resposta.json();
  if (!resposta.ok || !json.access_token) {
    throw new Error(`OAuth do Firebase falhou: ${JSON.stringify(json)}`);
  }
  tokenCache = { valor: json.access_token, expiraEm: agora + Number(json.expires_in ?? 3600) };
  return tokenCache.valor;
}

export interface ResultadoEnvio {
  ok: boolean;
  /** Token não existe mais / é inválido: deve ser apagado do banco. */
  tokenInvalido: boolean;
  erro?: string;
}

/** Envia UMA mensagem (já montada no formato `message` da API v1). */
export async function enviarMensagemFcm(mensagem: Record<string, unknown>): Promise<ResultadoEnvio> {
  const conta = contaServico();
  const resposta = await fetch(
    `https://fcm.googleapis.com/v1/projects/${conta.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${await tokenAcesso()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message: mensagem }),
    },
  );
  if (resposta.ok) return { ok: true, tokenInvalido: false };

  const corpo = await resposta.json().catch(() => ({}));
  const detalhes = (corpo?.error?.details ?? []) as Array<{ errorCode?: string }>;
  const codigo = detalhes.find((d) => d.errorCode)?.errorCode ?? corpo?.error?.status ?? '';
  const tokenInvalido =
    codigo === 'UNREGISTERED' ||
    (resposta.status === 404) ||
    (codigo === 'INVALID_ARGUMENT' && String(corpo?.error?.message ?? '').toLowerCase().includes('token'));
  return {
    ok: false,
    tokenInvalido,
    erro: `${resposta.status} ${codigo}: ${corpo?.error?.message ?? 'erro desconhecido'}`,
  };
}
