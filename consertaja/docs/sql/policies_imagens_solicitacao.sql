-- As fotos sao enviadas para:
-- solicitacao/{id_solicitacao}/{arquivo}
-- Crie previamente os buckets "Imagens Recebimento" e "Imagens Devolucao".

ALTER TABLE public.solicitacoes
  ADD COLUMN IF NOT EXISTS imagens_recebimento text[],
  ADD COLUMN IF NOT EXISTS imagens_devolucao text[];

CREATE OR REPLACE FUNCTION public.profissional_pode_acessar_solicitacao(
  p_fk_profissional bigint,
  p_fk_grupo_empresa bigint
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.dados_profissionais dp
    WHERE dp.fk_usuario = public.meu_id_usuario_solicitacao()
      AND (
        dp.id_profissional = p_fk_profissional
        OR (
          p_fk_grupo_empresa IS NOT NULL
          AND dp.fk_grupo_empresa = p_fk_grupo_empresa
        )
      )
  );
$$;

REVOKE ALL ON FUNCTION public.profissional_pode_acessar_solicitacao(bigint, bigint)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.profissional_pode_acessar_solicitacao(bigint, bigint)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.profissional_pode_acessar_solicitacao_id(
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
      AND public.profissional_pode_acessar_solicitacao(
        s.fk_profissional,
        s.fk_grupo_empresa
      )
  );
$$;

REVOKE ALL ON FUNCTION public.profissional_pode_acessar_solicitacao_id(bigint)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.profissional_pode_acessar_solicitacao_id(bigint)
  TO authenticated;

-- A policy original bloqueava atualizacoes de membros da empresa diferentes
-- do profissional individual atribuido, apesar de pertencerem ao grupo.
DROP POLICY IF EXISTS "solicitacoes_update_profissional" ON public.solicitacoes;
CREATE POLICY "solicitacoes_update_profissional"
  ON public.solicitacoes
  FOR UPDATE
  TO authenticated
  USING (
    public.profissional_pode_acessar_solicitacao(
      fk_profissional,
      fk_grupo_empresa
    )
  )
  WITH CHECK (
    data_aceite IS NOT NULL
    AND public.profissional_pode_acessar_solicitacao(
      fk_profissional,
      fk_grupo_empresa
    )
  );

DROP POLICY IF EXISTS "imagens_recebimento_solicitacao_insert" ON storage.objects;
CREATE POLICY "imagens_recebimento_solicitacao_insert"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'Imagens Recebimento'
    AND (storage.foldername(name))[1] = 'solicitacao'
    AND CASE
      WHEN (storage.foldername(name))[2] ~ '^[0-9]+$'
        THEN public.profissional_pode_acessar_solicitacao_id(
          ((storage.foldername(name))[2])::bigint
        )
      ELSE false
    END
  );

DROP POLICY IF EXISTS "imagens_devolucao_solicitacao_insert" ON storage.objects;
CREATE POLICY "imagens_devolucao_solicitacao_insert"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'Imagens Devolucao'
    AND (storage.foldername(name))[1] = 'solicitacao'
    AND CASE
      WHEN (storage.foldername(name))[2] ~ '^[0-9]+$'
        THEN public.profissional_pode_acessar_solicitacao_id(
          ((storage.foldername(name))[2])::bigint
        )
      ELSE false
    END
  );
