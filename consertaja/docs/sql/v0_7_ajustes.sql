-- ============================================================================
-- ConsertaJá — ajustes v0.7 (rode tudo de uma vez no SQL Editor do Supabase)
-- ============================================================================
--  1. Proposta de alteração no chat: o cliente pode aceitar a alteração de
--     um pedido Aceito/Aguardando pagamento (antes só "Aberto").
--  2. Método de entrega "definido" (o padrão do cadastro não conta).
-- ============================================================================

BEGIN;

-- 1) ACEITAR ALTERAÇÃO DE PEDIDO AINDA NÃO PAGO --------------------------------
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

    -- Aberto, Aceito ou Aguardando Pagamento (ainda não pago): a proposta
    -- de alteração do chat atualiza o mesmo pedido.
    IF OLD.fk_status IN (1, 2, 31, v_status_aceito)
       AND NEW.fk_status = v_status_aceito
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

-- 2) MÉTODO DE ENTREGA "DEFINIDO" ------------------------------------------------
-- O cadastro grava um método padrão; só conta como definido depois que o
-- profissional/empresa salva na tela de Métodos de Entrega.
ALTER TABLE public.dados_profissionais
  ADD COLUMN IF NOT EXISTS metodo_entrega_definido boolean NOT NULL DEFAULT false;
ALTER TABLE public.grupo_empresa
  ADD COLUMN IF NOT EXISTS metodo_entrega_definido boolean NOT NULL DEFAULT false;

-- Quem já tem serviços cadastrados já configurou a conta.
UPDATE public.dados_profissionais dp SET metodo_entrega_definido = true
WHERE EXISTS (SELECT 1 FROM public.servicos_profissional s
              WHERE s.fk_profissional = dp.id_profissional AND s.fk_grupo_empresa IS NULL);
UPDATE public.grupo_empresa g SET metodo_entrega_definido = true
WHERE EXISTS (SELECT 1 FROM public.servicos_profissional s
              WHERE s.fk_grupo_empresa = g.id_grupo_empresa);

COMMIT;
