-- ============================================================================
-- ConsertaJá — Diagnóstico do push (rode DEPOIS de notificacoes.sql)
--
-- Os tokens chegam em dispositivos_notificacao, então app + Firebase estão
-- ok. Se o push não chega, o problema está entre o banco e o FCM. Este
-- script:
--   1. guarda o id da requisição do pg_net em cada notificação, para ligar a
--      notificação à resposta HTTP da Edge Function (net._http_response);
--   2. cria public.diagnostico_push(), que mostra numa consulta só o que
--      está faltando;
--   3. cria public.testar_push(id_usuario) para disparar um teste.
--
-- Depois de rodar:
--   select public.testar_push(<seu id_usuario>);
--   -- espere ~5 segundos
--   select jsonb_pretty(public.diagnostico_push());
-- ============================================================================

BEGIN;

ALTER TABLE public.notificacoes
  ADD COLUMN IF NOT EXISTS push_request_id bigint;

-- Igual à versão anterior + grava o id da requisição e o motivo quando não
-- consegue disparar (antes falhava em silêncio).
CREATE OR REPLACE FUNCTION public.notif_disparar_push(p_id_notificacao bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_url     text;
  v_segredo text;
  v_req     bigint;
BEGIN
  SELECT decrypted_secret INTO v_url
  FROM vault.decrypted_secrets WHERE name = 'notificacoes_url_funcao' LIMIT 1;
  SELECT decrypted_secret INTO v_segredo
  FROM vault.decrypted_secrets WHERE name = 'notificacoes_segredo' LIMIT 1;

  IF v_url IS NULL OR v_segredo IS NULL THEN
    UPDATE public.notificacoes
    SET push_erro = 'Vault sem notificacoes_url_funcao/notificacoes_segredo'
    WHERE id_notificacao = p_id_notificacao;
    RETURN; -- continua 'pendente' e é reenviada depois de configurar
  END IF;

  SELECT net.http_post(
    url := v_url,
    body := jsonb_build_object('id_notificacao', p_id_notificacao),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-notificacoes-segredo', v_segredo),
    timeout_milliseconds := 10000
  ) INTO v_req;

  UPDATE public.notificacoes
  SET push_status = 'enviando',
      push_tentativas = push_tentativas + 1,
      push_request_id = v_req,
      push_erro = NULL
  WHERE id_notificacao = p_id_notificacao;
EXCEPTION WHEN others THEN
  UPDATE public.notificacoes
  SET push_erro = left('Falha ao chamar pg_net: ' || SQLERRM, 500)
  WHERE id_notificacao = p_id_notificacao;
  RAISE WARNING '[notificacoes] falha ao disparar push %: %', p_id_notificacao, SQLERRM;
END;
$$;

REVOKE ALL ON FUNCTION public.notif_disparar_push(bigint) FROM PUBLIC, anon, authenticated;

-- Tudo o que importa para o push, numa consulta.
CREATE OR REPLACE FUNCTION public.diagnostico_push()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v jsonb := '{}'::jsonb;
  v_url text;
BEGIN
  v := v || jsonb_build_object(
    'extensao_pg_net', EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net'),
    'extensao_pg_cron', EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'));

  SELECT decrypted_secret INTO v_url
  FROM vault.decrypted_secrets WHERE name = 'notificacoes_url_funcao' LIMIT 1;
  v := v || jsonb_build_object(
    'vault_url_funcao', coalesce(v_url, 'FALTANDO'),
    'vault_segredo', CASE WHEN EXISTS (
        SELECT 1 FROM vault.decrypted_secrets WHERE name = 'notificacoes_segredo')
      THEN 'ok' ELSE 'FALTANDO' END);

  v := v || jsonb_build_object('dispositivos', (
    SELECT count(*) FROM public.dispositivos_notificacao));

  v := v || jsonb_build_object('notificacoes_por_status', (
    SELECT coalesce(jsonb_object_agg(push_status, qtd), '{}'::jsonb)
    FROM (SELECT push_status, count(*) AS qtd
          FROM public.notificacoes GROUP BY push_status) x));

  -- Últimas notificações com a resposta da Edge Function.
  BEGIN
    v := v || jsonb_build_object('ultimas', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
               'id', n.id_notificacao,
               'tipo', n.tipo,
               'push_status', n.push_status,
               'push_erro', n.push_erro,
               'http_status', r.status_code,
               'http_erro', r.error_msg,
               'http_resposta', left(r.content::text, 300)
             ) ORDER BY n.id_notificacao DESC), '[]'::jsonb)
      FROM (SELECT * FROM public.notificacoes
            ORDER BY id_notificacao DESC LIMIT 8) n
      LEFT JOIN net._http_response r ON r.id = n.push_request_id));
  EXCEPTION WHEN others THEN
    v := v || jsonb_build_object('ultimas_erro', SQLERRM);
  END;

  -- Respostas HTTP mais recentes (mesmo sem ligação com a notificação).
  BEGIN
    v := v || jsonb_build_object('respostas_http_recentes', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
               'id', r.id,
               'status', r.status_code,
               'erro', r.error_msg,
               'resposta', left(r.content::text, 300),
               'quando', r.created
             ) ORDER BY r.id DESC), '[]'::jsonb)
      FROM (SELECT * FROM net._http_response ORDER BY id DESC LIMIT 5) r));
  EXCEPTION WHEN others THEN
    v := v || jsonb_build_object('respostas_http_erro', SQLERRM);
  END;

  RETURN v;
END;
$$;

REVOKE ALL ON FUNCTION public.diagnostico_push() FROM PUBLIC, anon, authenticated;

-- Notificação de teste (rode no SQL Editor).
CREATE OR REPLACE FUNCTION public.testar_push(p_fk_usuario bigint)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.criar_notificacao(
    p_fk_usuario, 'Sistema', 'Teste de notificação 🔔',
    'Se você está vendo isto no celular, o push está funcionando!',
    'notificacoes', NULL, NULL, NULL, NULL, NULL,
    jsonb_build_object('teste', true),
    'teste:' || p_fk_usuario || ':' || extract(epoch FROM clock_timestamp())::text);
$$;

REVOKE ALL ON FUNCTION public.testar_push(bigint) FROM PUBLIC, anon, authenticated;

COMMIT;

-- ============================================================================
-- COMO LER O RESULTADO de select jsonb_pretty(public.diagnostico_push());
--
-- vault_url_funcao = FALTANDO / vault_segredo = FALTANDO
--   → crie os segredos (passo 12 de notificacoes.sql). Depois:
--     select public.reenviar_pushes_pendentes();
--
-- http_status = 401 (ou "Invalid JWT" / "Missing authorization header")
--   → a função está exigindo JWT. Dashboard → Edge Functions →
--     enviar-notificacao → Details → desligue "Enforce JWT Verification"
--     (ou publique de novo: supabase functions deploy enviar-notificacao --no-verify-jwt)
--
-- http_status = 404
--   → a função não foi publicada ou a URL no Vault está errada.
--
-- http_status = 500 com "FIREBASE_SERVICE_ACCOUNT não configurado"
--   → faltou o secret da conta de serviço (supabase secrets set ...).
--
-- push_status = falhou com SENDER_ID_MISMATCH / PERMISSION_DENIED
--   → a conta de serviço é de OUTRO projeto do Firebase (tem que ser do
--     mesmo projeto do google-services.json).
--
-- push_status = falhou com 401 "Não autorizado."
--   → NOTIFICACOES_SEGREDO da função ≠ notificacoes_segredo do Vault.
--
-- push_status = enviado mas não aparece no celular
--   → veja permissão de notificação do app e o modo de economia de bateria.
-- ============================================================================
