// =============================================================================
// ConsertaJá — Edge Function `enviar-notificacao`
//
// Chamada pelo próprio banco (trigger em `notificacoes`, via pg_net) com
// { id_notificacao }. Ela:
//   1. confere o segredo compartilhado (header x-notificacoes-segredo);
//   2. lê a notificação (já gravada — a gravação não depende do FCM);
//   3. busca os tokens do usuário em `dispositivos_notificacao`;
//   4. envia pelo FCM (API HTTP v1), um envio por aparelho;
//   5. apaga tokens inválidos/expirados;
//   6. marca push_status (não reenvia o que já foi enviado → sem duplicadas).
//
// Deploy:   supabase functions deploy enviar-notificacao --no-verify-jwt
// Secrets:  FIREBASE_SERVICE_ACCOUNT, NOTIFICACOES_SEGREDO
//           (opcional) NOTIFICACOES_MODO_ANDROID = dados | notificacao
// =============================================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { json, supabaseSecretKey } from '../_shared/stripe.ts';
import { enviarMensagemFcm } from '../_shared/fcm.ts';

const admin = createClient(Deno.env.get('SUPABASE_URL')!, supabaseSecretKey());

/** Canal Android de cada tipo (os mesmos criados no app). */
const CANAIS: Record<string, string> = {
  'Solicitação': 'consertaja_pedidos',
  Conversa: 'consertaja_mensagens',
  radar_prof: 'consertaja_radar',
  radar_cliente: 'consertaja_radar',
  Sistema: 'consertaja_conta',
  Global: 'consertaja_novidades',
  feedback: 'consertaja_feedback',
};

interface Notificacao {
  id_notificacao: number;
  fk_usuario: number;
  tipo: string;
  titulo: string;
  conteudo: string;
  tela_destino: string | null;
  imagem_url: string | null;
  fk_status: number | null;
  fk_conversa: number | null;
  fk_solicitacao: number | null;
  fk_solicitacao_geografica: number | null;
  dados: Record<string, unknown>;
  data_criacao: string;
  push_status: string;
  /** 'cliente' | 'independente' | 'empresa' | null (geral) — v0_10_ajustes.sql */
  perfil_destino?: string | null;
}

function montarMensagem(n: Notificacao, token: string, plataforma: string) {
  const canal = CANAIS[n.tipo] ?? 'consertaja_conta';
  // Conversa: uma notificação por conversa (as novas substituem a anterior).
  const tag = n.fk_conversa ? `conversa_${n.fk_conversa}` : `notif_${n.id_notificacao}`;

  // FCM exige que todos os valores de `data` sejam strings.
  const data: Record<string, string> = {
    id_notificacao: String(n.id_notificacao),
    tipo: n.tipo,
    titulo: n.titulo,
    conteudo: n.conteudo ?? '',
    tela_destino: n.tela_destino ?? '',
    imagem_url: n.imagem_url ?? '',
    fk_status: n.fk_status == null ? '' : String(n.fk_status),
    fk_conversa: n.fk_conversa == null ? '' : String(n.fk_conversa),
    fk_solicitacao: n.fk_solicitacao == null ? '' : String(n.fk_solicitacao),
    fk_solicitacao_geografica:
      n.fk_solicitacao_geografica == null ? '' : String(n.fk_solicitacao_geografica),
    dados: JSON.stringify(n.dados ?? {}),
    data_criacao: n.data_criacao,
    perfil_destino: n.perfil_destino ?? '',
    canal,
    tag,
  };

  // Android, modo "dados" (padrão): a mensagem chega só com `data` e o app
  // desenha a notificação (foto do remetente, estilo de conversa, cor do
  // status...) mesmo em segundo plano/fechado. Modo "notificacao": o próprio
  // sistema desenha (mais simples, menos estilizado).
  const modoAndroid = Deno.env.get('NOTIFICACOES_MODO_ANDROID') ?? 'dados';

  const mensagem: Record<string, unknown> = { token, data };

  if (plataforma === 'android') {
    mensagem.android = modoAndroid === 'notificacao'
      ? {
        priority: 'HIGH',
        notification: {
          title: n.titulo,
          body: n.conteudo,
          channel_id: canal,
          color: '#0FB3FF',
          icon: 'ic_notificacao',
          tag,
          ...(n.imagem_url ? { image: n.imagem_url } : {}),
        },
      }
      : { priority: 'HIGH' };
  } else {
    // iOS / web: o sistema precisa do alerta pronto.
    mensagem.notification = { title: n.titulo, body: n.conteudo };
    mensagem.apns = {
      headers: { 'apns-priority': '10' },
      payload: { aps: { sound: 'default', 'thread-id': tag, 'mutable-content': 1 } },
    };
  }
  return mensagem;
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return json({ error: 'Use POST.' }, 405);

  const segredo = Deno.env.get('NOTIFICACOES_SEGREDO');
  if (!segredo || request.headers.get('x-notificacoes-segredo') !== segredo) {
    return json({ error: 'Não autorizado.' }, 401);
  }

  let id = 0;
  try {
    id = Number((await request.json()).id_notificacao);
    if (!id) return json({ error: 'id_notificacao obrigatório.' }, 400);

    const { data: n, error } = await admin
      .from('notificacoes')
      .select('*')
      .eq('id_notificacao', id)
      .maybeSingle<Notificacao>();
    if (error) throw error;
    if (!n) return json({ error: 'Notificação não encontrada.' }, 404);
    if (n.push_status === 'enviado' || n.push_status === 'nao_enviar') {
      return json({ ok: true, ignorada: n.push_status });
    }

    const { data: todosDispositivos, error: erroDisp } = await admin
      .from('dispositivos_notificacao')
      .select('id_dispositivo, token_fcm, plataforma, perfil_ativo')
      .eq('fk_usuario', n.fk_usuario);
    if (erroDisp) throw erroDisp;

    // Profissional com conta independente E de loja: o aviso de uma conta só
    // vai para o aparelho que está com essa conta ativa (o outro vê ao trocar).
    const destino = n.perfil_destino ?? null;
    const dispositivos = (todosDispositivos ?? []).filter((d) =>
      destino !== 'independente' && destino !== 'empresa'
        ? true
        : d.perfil_ativo === destino
    );
    if ((todosDispositivos?.length ?? 0) > 0 && dispositivos.length === 0) {
      await admin.from('notificacoes')
        .update({ push_status: 'nao_enviar', push_erro: 'outro perfil ativo' })
        .eq('id_notificacao', id);
      return json({ ok: true, enviados: 0, motivo: 'outro_perfil' });
    }

    if (!dispositivos || dispositivos.length === 0) {
      await admin.from('notificacoes')
        .update({ push_status: 'sem_dispositivo', push_erro: null })
        .eq('id_notificacao', id);
      return json({ ok: true, enviados: 0, motivo: 'sem_dispositivo' });
    }

    const resultados = await Promise.all(
      dispositivos.map(async (d) => ({
        d,
        r: await enviarMensagemFcm(montarMensagem(n, d.token_fcm, d.plataforma)),
      })),
    );

    const invalidos = resultados.filter((x) => x.r.tokenInvalido).map((x) => x.d.id_dispositivo);
    if (invalidos.length > 0) {
      await admin.from('dispositivos_notificacao').delete().in('id_dispositivo', invalidos);
    }

    const enviados = resultados.filter((x) => x.r.ok).length;
    const erros = resultados.filter((x) => !x.r.ok).map((x) => x.r.erro).join(' | ');
    await admin.from('notificacoes').update({
      push_status: enviados > 0 ? 'enviado' : (invalidos.length === dispositivos.length ? 'sem_dispositivo' : 'falhou'),
      push_enviado_em: enviados > 0 ? new Date().toISOString() : null,
      push_erro: erros || null,
    }).eq('id_notificacao', id);

    return json({ ok: true, enviados, tokens_removidos: invalidos.length });
  } catch (e) {
    const mensagem = e instanceof Error ? e.message : String(e);
    if (id) {
      await admin.from('notificacoes')
        .update({ push_status: 'falhou', push_erro: mensagem.slice(0, 500) })
        .eq('id_notificacao', id);
    }
    return json({ error: mensagem }, 500);
  }
});
