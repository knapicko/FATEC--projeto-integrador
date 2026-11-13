-- ============================================================================
-- ConsertaJá — Permissões do CLIENTE no fluxo de solicitações
-- Execute no SQL Editor do Supabase (pode rodar mais de uma vez).
--
-- Por que é necessário:
--   O app do cliente atualiza a própria solicitação em alguns passos do fluxo
--   (iniciar deslocamento, registrar entrada no balcão, confirmar devolução,
--   confirmar retirada, confirmar atendimento em domicílio, aceitar proposta
--   do chat). Até aqui só existia policy de UPDATE para o PROFISSIONAL, então
--   esses updates eram ignorados pelo RLS sem erro.
--
-- Segurança:
--   A policy libera UPDATE só nas solicitações do próprio cliente, e o
--   trigger abaixo aceita SOMENTE as transições previstas no fluxo, alterando
--   SOMENTE as colunas daquela transição. Qualquer outro update do cliente
--   (ex.: mudar valor_final ou pular para "Concluído") é rejeitado.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Função auxiliar: o usuário logado é o cliente da solicitação?
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cliente_pode_acessar_solicitacao_id(
  p_id_solicitacao bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.solicitacoes s
    WHERE s.id_solicitacao = p_id_solicitacao
      AND s.fk_usuario = public.meu_id_usuario_solicitacao()
  );
$$;

REVOKE ALL ON FUNCTION public.cliente_pode_acessar_solicitacao_id(bigint)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_pode_acessar_solicitacao_id(bigint)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Policy de UPDATE do cliente (somente as próprias solicitações)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "solicitacoes_update_cliente" ON public.solicitacoes;
CREATE POLICY "solicitacoes_update_cliente"
  ON public.solicitacoes
  FOR UPDATE
  TO authenticated
  USING (fk_usuario = public.meu_id_usuario_solicitacao())
  WITH CHECK (fk_usuario = public.meu_id_usuario_solicitacao());

-- ---------------------------------------------------------------------------
-- 3. Trigger que valida as transições feitas pelo cliente
-- ---------------------------------------------------------------------------
-- Auxiliares (SECURITY DEFINER) usadas pelo trigger, que roda como o próprio
-- usuário para conseguir distinguir update direto do app de RPC.
CREATE OR REPLACE FUNCTION public.id_status_aceito_servico()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT id_status FROM public.status
  WHERE tipo_status::text = 'Serviço' AND status = 'Aceito'
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.valor_servico_chat_temp(p_id bigint)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT valor FROM public.servicos_chat_temporarios
  WHERE id_servico_temp = p_id;
$$;

REVOKE ALL ON FUNCTION public.id_status_aceito_servico() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.valor_servico_chat_temp(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.id_status_aceito_servico() TO authenticated;
GRANT EXECUTE ON FUNCTION public.valor_servico_chat_temp(bigint)
  TO authenticated;

-- SECURITY INVOKER de propósito: dentro de RPCs SECURITY DEFINER
-- (ex.: confirmar_conclusao_solicitacao) o current_user é o dono da função,
-- então o trigger não interfere nelas; só valida updates diretos do app.
CREATE OR REPLACE FUNCTION public.validar_update_cliente_solicitacao()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tipo text := lower(coalesce(OLD.tipo_execucao, ''));
  v_permitidas text[];
  v_status_aceito bigint;
  v_valor_temp numeric;
BEGIN
  -- RPCs SECURITY DEFINER, service_role / Edge Functions e profissionais
  -- seguem livres (o profissional já é limitado pela policy
  -- solicitacoes_update_profissional).
  IF current_user <> 'authenticated'
     OR auth.uid() IS NULL
     OR public.profissional_pode_acessar_solicitacao(
          OLD.fk_profissional, OLD.fk_grupo_empresa) THEN
    RETURN NEW;
  END IF;

  -- Não é o cliente desta solicitação: o RLS decide.
  IF OLD.fk_usuario IS DISTINCT FROM public.meu_id_usuario_solicitacao() THEN
    RETURN NEW;
  END IF;

  -- Retirado no Local / Receba em Casa — etapa 1 → 2: cliente inicia trajeto.
  IF OLD.fk_status = 3 AND NEW.fk_status = 38
     AND NEW.etapa_solicitacao = 2
     AND (v_tipo LIKE '%retirad%' OR v_tipo LIKE '%receba%') THEN
    v_permitidas := ARRAY['fk_status', 'etapa_solicitacao', 'codigo_rec_dev'];

  -- Retirado no Local / Receba em Casa — etapa 2 → 3: entrada no balcão.
  ELSIF OLD.fk_status = 38 AND NEW.fk_status = 4
     AND NEW.etapa_solicitacao = 3 THEN
    v_permitidas := ARRAY['fk_status', 'etapa_solicitacao',
      'imagens_recebimento', 'data_inicio_andamento', 'andamento_pausado'];

  -- Leva e Traz / Receba em Casa — etapa 4 → 5: confirma a devolução.
  -- (34 na etapa 4 = registros antigos do Receba em Casa)
  ELSIF (OLD.fk_status = 37
         OR (OLD.fk_status = 34 AND OLD.etapa_solicitacao >= 4))
     AND (v_tipo LIKE '%leva%' OR v_tipo LIKE '%receba%')
     AND NEW.fk_status = 6 AND NEW.etapa_solicitacao = 5 THEN
    v_permitidas := ARRAY['fk_status', 'etapa_solicitacao', 'imagens_devolucao'];

  -- Retirado no Local — etapa 4 → 5: confirma a retirada no balcão.
  ELSIF OLD.fk_status = 35 AND v_tipo LIKE '%retirad%'
     AND NEW.fk_status = 6 AND NEW.etapa_solicitacao = 5 THEN
    v_permitidas := ARRAY['fk_status', 'etapa_solicitacao', 'imagens_devolucao'];

  -- Atendimento em Domicílio — etapa 3 → 4: confirma após o profissional
  -- finalizar o atendimento.
  ELSIF OLD.fk_status = 34 AND v_tipo LIKE '%domic%'
     AND OLD.profissional_finalizado_atendimento = true
     AND NEW.fk_status = 6 AND NEW.etapa_solicitacao = 4 THEN
    v_permitidas := ARRAY['fk_status', 'etapa_solicitacao'];

  -- Chat — cliente aceita a proposta do profissional (status 1 → Aceito).
  ELSE
    v_status_aceito := public.id_status_aceito_servico();
    IF NEW.fk_servico_temp IS NOT NULL THEN
      v_valor_temp := public.valor_servico_chat_temp(NEW.fk_servico_temp);
    END IF;

    IF OLD.fk_status = 1 AND NEW.fk_status = v_status_aceito
       AND NEW.etapa_solicitacao = 1
       AND v_valor_temp IS NOT NULL
       AND NEW.valor_final = v_valor_temp THEN
      v_permitidas := ARRAY['fk_status', 'etapa_solicitacao', 'data_aceite',
        'valor_final', 'fk_servico_prof', 'fk_servico_temp', 'tipo_execucao',
        'detalhes'];
    ELSE
      RAISE EXCEPTION
        'Transição não permitida para o cliente (status % → %, etapa %).',
        OLD.fk_status, NEW.fk_status, NEW.etapa_solicitacao
        USING ERRCODE = '42501';
    END IF;
  END IF;

  -- Nenhuma outra coluna pode mudar.
  IF (to_jsonb(NEW) - v_permitidas) IS DISTINCT FROM
     (to_jsonb(OLD) - v_permitidas) THEN
    RAISE EXCEPTION 'O cliente não pode alterar estes campos da solicitação.'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_update_cliente_solicitacao
  ON public.solicitacoes;
CREATE TRIGGER trg_validar_update_cliente_solicitacao
  BEFORE UPDATE ON public.solicitacoes
  FOR EACH ROW
  EXECUTE FUNCTION public.validar_update_cliente_solicitacao();

-- ---------------------------------------------------------------------------
-- 4. Storage: o cliente envia fotos na entrada (Receba em Casa / Retirado no
--    Local) e na devolução / retirada final.
--    Caminho usado pelo app: solicitacao/{id_solicitacao}/{arquivo}
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "imagens_recebimento_cliente_insert" ON storage.objects;
CREATE POLICY "imagens_recebimento_cliente_insert"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'Imagens Recebimento'
    AND (storage.foldername(name))[1] = 'solicitacao'
    AND CASE
      WHEN (storage.foldername(name))[2] ~ '^[0-9]+$'
        THEN public.cliente_pode_acessar_solicitacao_id(
          ((storage.foldername(name))[2])::bigint
        )
      ELSE false
    END
  );

DROP POLICY IF EXISTS "imagens_devolucao_cliente_insert" ON storage.objects;
CREATE POLICY "imagens_devolucao_cliente_insert"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'Imagens Devolucao'
    AND (storage.foldername(name))[1] = 'solicitacao'
    AND CASE
      WHEN (storage.foldername(name))[2] ~ '^[0-9]+$'
        THEN public.cliente_pode_acessar_solicitacao_id(
          ((storage.foldername(name))[2])::bigint
        )
      ELSE false
    END
  );
