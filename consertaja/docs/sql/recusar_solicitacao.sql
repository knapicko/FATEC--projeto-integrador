-- Execute este script no SQL Editor do Supabase.
-- Ele cria a RPC chamada por meus_servicos_solicitados.dart.

CREATE OR REPLACE FUNCTION public.recusar_solicitacao(
  p_id_solicitacao bigint,
  p_id_profissional bigint
)
RETURNS public.solicitacoes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  pedido public.solicitacoes;
  status_recusado bigint;
  id_usuario_sessao bigint;
BEGIN
  SELECT u.id_usuario
  INTO id_usuario_sessao
  FROM public.usuarios AS u
  WHERE u.auth_id = auth.uid()
  LIMIT 1;

  IF NOT EXISTS (
    SELECT 1
    FROM public.dados_profissionais AS dp
    WHERE dp.id_profissional = p_id_profissional
      AND (
        dp.fk_usuario = id_usuario_sessao
        OR EXISTS (
          SELECT 1
          FROM public.dados_profissionais AS sessao
          WHERE sessao.fk_usuario = id_usuario_sessao
            AND sessao.fk_grupo_empresa IS NOT NULL
            AND sessao.fk_grupo_empresa = dp.fk_grupo_empresa
        )
      )
  ) THEN
    RAISE EXCEPTION 'Profissional nao pertence a sessao autenticada';
  END IF;

  SELECT s.id_status
  INTO status_recusado
  FROM public.status AS s
  WHERE s.tipo_status::text = 'Serviço'
    AND s.status = 'Recusado'
  LIMIT 1;

  IF status_recusado IS NULL THEN
    RAISE EXCEPTION
      'Status Recusado ausente. Execute status_solicitacao_aceito_recusado.sql';
  END IF;

  UPDATE public.solicitacoes AS s
  SET fk_status = status_recusado
  WHERE s.id_solicitacao = p_id_solicitacao
    AND s.data_aceite IS NULL
    AND (
      s.fk_profissional = p_id_profissional
      OR EXISTS (
        SELECT 1
        FROM public.dados_profissionais AS dp_grupo
        WHERE dp_grupo.id_profissional = p_id_profissional
          AND dp_grupo.fk_grupo_empresa = s.fk_grupo_empresa
          AND s.fk_grupo_empresa IS NOT NULL
      )
    )
  RETURNING s.* INTO pedido;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitacao inexistente, ja aceita ou sem permissao';
  END IF;

  RETURN pedido;
END;
$$;

GRANT EXECUTE ON FUNCTION public.recusar_solicitacao(bigint, bigint)
  TO authenticated;

-- Atualiza o cache de funções do PostgREST imediatamente.
NOTIFY pgrst, 'reload schema';

