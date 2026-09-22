-- Migration para o fluxo Cliente -> Solicitar Servico.
-- Execute no SQL Editor do Supabase.
-- Os valores abaixo sao TEXT de proposito: nao dependem dos enums existentes.

-- 1. Cada servico publicado pelo profissional informa como e executado.
ALTER TABLE public.servicos_profissional
  ADD COLUMN IF NOT EXISTS tipo_execucao text,
  ADD COLUMN IF NOT EXISTS carga_servico text;

UPDATE public.servicos_profissional
SET tipo_execucao = 'Execução'
WHERE tipo_execucao IS NULL;

UPDATE public.servicos_profissional
SET carga_servico = 'Médio'
WHERE carga_servico IS NULL;

ALTER TABLE public.servicos_profissional
  ALTER COLUMN tipo_execucao SET DEFAULT 'Execução',
  ALTER COLUMN tipo_execucao SET NOT NULL,
  ALTER COLUMN carga_servico SET DEFAULT 'Médio',
  ALTER COLUMN carga_servico SET NOT NULL;

ALTER TABLE public.servicos_profissional
  DROP CONSTRAINT IF EXISTS servicos_profissional_tipo_execucao_check;

ALTER TABLE public.servicos_profissional
  ADD CONSTRAINT servicos_profissional_tipo_execucao_check
  CHECK (
    tipo_execucao IN ('Entrega', 'Execução')
    OR tipo_execucao ~ '^(Leva e Traz|Retirado no Local|Receba em Casa|Atendimento em Domicílio)(, (Leva e Traz|Retirado no Local|Receba em Casa|Atendimento em Domicílio))*$'
  );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'servicos_profissional_carga_servico_check'
  ) THEN
    ALTER TABLE public.servicos_profissional
      ADD CONSTRAINT servicos_profissional_carga_servico_check
      CHECK (carga_servico IN ('Leve', 'Médio', 'Alto'));
  END IF;
END $$;

-- O catalogo tambem guarda o tipo para que novos servicos ja nascam classificados.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'servicos_catalogo_tipo_execucao_check'
  ) THEN
    ALTER TABLE public.servicos_catalogo
      ADD CONSTRAINT servicos_catalogo_tipo_execucao_check
      CHECK (tipo_execucao IN ('Entrega', 'Execução'));
  END IF;
END $$;

-- 2. Dados escolhidos pelo cliente na solicitacao.
ALTER TABLE public.solicitacoes
  ADD COLUMN IF NOT EXISTS fk_endereco bigint,
  ADD COLUMN IF NOT EXISTS fk_grupo_empresa bigint,
  ADD COLUMN IF NOT EXISTS tipo_execucao text,
  ADD COLUMN IF NOT EXISTS tipo_entrega text,
  ADD COLUMN IF NOT EXISTS detalhes text,
  ADD COLUMN IF NOT EXISTS data_agendada date,
  ADD COLUMN IF NOT EXISTS hora_agendada time without time zone;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'solicitacoes_fk_endereco_fkey'
  ) THEN
    ALTER TABLE public.solicitacoes
      ADD CONSTRAINT solicitacoes_fk_endereco_fkey
      FOREIGN KEY (fk_endereco) REFERENCES public.enderecos(id_endereco);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'solicitacoes_fk_grupo_empresa_fkey'
  ) THEN
    ALTER TABLE public.solicitacoes
      ADD CONSTRAINT solicitacoes_fk_grupo_empresa_fkey
      FOREIGN KEY (fk_grupo_empresa)
      REFERENCES public.grupo_empresa(id_grupo_empresa);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'solicitacoes_tipo_entrega_check'
  ) THEN
    ALTER TABLE public.solicitacoes
      ADD CONSTRAINT solicitacoes_tipo_entrega_check
      CHECK (tipo_entrega IS NULL OR tipo_entrega IN (
        'Domicilio',
        'Retirada',
        'Local'
      ));
  END IF;

  ALTER TABLE public.solicitacoes
    DROP CONSTRAINT IF EXISTS solicitacoes_tipo_execucao_check;

  ALTER TABLE public.solicitacoes
    ADD CONSTRAINT solicitacoes_tipo_execucao_check
    CHECK (
      tipo_execucao IS NULL
      OR tipo_execucao IN ('Entrega', 'Execução')
      OR tipo_execucao ~ '^(Leva e Traz|Retirado no Local|Receba em Casa|Atendimento em Domicílio)(, (Leva e Traz|Retirado no Local|Receba em Casa|Atendimento em Domicílio))*$'
    );
END $$;

CREATE INDEX IF NOT EXISTS solicitacoes_fk_usuario_idx
  ON public.solicitacoes (fk_usuario);
CREATE INDEX IF NOT EXISTS solicitacoes_fk_profissional_idx
  ON public.solicitacoes (fk_profissional);
CREATE INDEX IF NOT EXISTS solicitacoes_fk_grupo_empresa_idx
  ON public.solicitacoes (fk_grupo_empresa);
CREATE INDEX IF NOT EXISTS solicitacoes_data_agendada_idx
  ON public.solicitacoes (fk_profissional, data_agendada);

-- 3. Uma solicitacao pode ter uma ou mais imagens anexadas.
CREATE TABLE IF NOT EXISTS public.solicitacoes_anexos (
  id_anexo bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  fk_solicitacao bigint NOT NULL,
  anexo_url text NOT NULL,
  nome_arquivo text,
  tipo_mime text,
  tamanho_bytes bigint,
  ordem integer NOT NULL DEFAULT 1,
  data_criacao timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT solicitacoes_anexos_pkey PRIMARY KEY (id_anexo),
  CONSTRAINT solicitacoes_anexos_fk_solicitacao_fkey
    FOREIGN KEY (fk_solicitacao)
    REFERENCES public.solicitacoes(id_solicitacao)
    ON DELETE CASCADE,
  CONSTRAINT solicitacoes_anexos_tamanho_check
    CHECK (tamanho_bytes IS NULL OR tamanho_bytes >= 0)
);

CREATE INDEX IF NOT EXISTS solicitacoes_anexos_fk_solicitacao_idx
  ON public.solicitacoes_anexos (fk_solicitacao, ordem);

-- 4. Regras que dependem do tipo do servico.
-- Entrega: Domicilio ou Retirada.
-- Execucao: somente Local.
CREATE OR REPLACE FUNCTION public.validar_tipo_entrega_solicitacao()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  tipo_servico text;
  grupo_servico bigint;
BEGIN
  IF NEW.fk_servico_prof IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT tipo_execucao, fk_grupo_empresa
    INTO tipo_servico, grupo_servico
    FROM public.servicos_profissional
   WHERE id_servico_prof = NEW.fk_servico_prof;

  IF tipo_servico IS NOT NULL THEN
    NEW.tipo_execucao := tipo_servico;
    NEW.fk_grupo_empresa := grupo_servico;
  END IF;

  IF NEW.tipo_entrega IS NULL THEN
    RETURN NEW;
  END IF;

  IF tipo_servico = 'Entrega'
     AND NEW.tipo_entrega NOT IN ('Domicilio', 'Retirada') THEN
    RAISE EXCEPTION 'Servicos de Entrega aceitam somente Domicilio ou Retirada';
  END IF;

  IF tipo_servico = 'Execução'
     AND NEW.tipo_entrega <> 'Local' THEN
    RAISE EXCEPTION 'Servicos de Execução aceitam somente Local';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validar_tipo_entrega_solicitacao_trigger
  ON public.solicitacoes;

CREATE TRIGGER validar_tipo_entrega_solicitacao_trigger
BEFORE INSERT OR UPDATE OF fk_servico_prof, tipo_execucao, tipo_entrega
ON public.solicitacoes
FOR EACH ROW
EXECUTE FUNCTION public.validar_tipo_entrega_solicitacao();

-- 5. Aceite exclusivo.
-- Pedido individual: somente o profissional indicado pode aceitar.
-- Pedido de loja: qualquer funcionario vinculado a fk_grupo_empresa pode
-- visualiza-lo, mas somente o primeiro aceite e gravado.
CREATE OR REPLACE FUNCTION public.aceitar_solicitacao(
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
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.dados_profissionais dp_atual
    WHERE dp_atual.id_profissional = p_id_profissional
      AND (
        dp_atual.fk_usuario = (
          SELECT u.id_usuario
          FROM public.usuarios u
          WHERE u.auth_id = auth.uid()
          LIMIT 1
        )
        OR EXISTS (
          SELECT 1
          FROM public.dados_profissionais dp_sessao
          WHERE dp_sessao.fk_usuario = (
            SELECT u.id_usuario
            FROM public.usuarios u
            WHERE u.auth_id = auth.uid()
            LIMIT 1
          )
            AND dp_sessao.fk_grupo_empresa IS NOT NULL
            AND dp_sessao.fk_grupo_empresa = dp_atual.fk_grupo_empresa
        )
      )
  ) THEN
    RAISE EXCEPTION 'Profissional nao pertence a sessao autenticada';
  END IF;

  UPDATE public.solicitacoes AS s
  SET data_aceite = now(),
      fk_profissional = p_id_profissional
  WHERE s.id_solicitacao = p_id_solicitacao
    AND s.data_aceite IS NULL
    AND (
      s.fk_profissional = p_id_profissional
      OR EXISTS (
        SELECT 1
        FROM public.dados_profissionais AS dp
        WHERE dp.id_profissional = p_id_profissional
          AND dp.fk_grupo_empresa = s.fk_grupo_empresa
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

GRANT EXECUTE ON FUNCTION public.aceitar_solicitacao(bigint, bigint)
  TO authenticated;

-- 6. RLS das solicitacoes.
CREATE OR REPLACE FUNCTION public.meu_id_usuario_solicitacao()
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT id_usuario
  FROM public.usuarios
  WHERE auth_id = auth.uid()
  LIMIT 1
$$;

GRANT EXECUTE ON FUNCTION public.meu_id_usuario_solicitacao() TO authenticated;

ALTER TABLE public.solicitacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitacoes_anexos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "solicitacoes_select_participante" ON public.solicitacoes;
CREATE POLICY "solicitacoes_select_participante"
  ON public.solicitacoes FOR SELECT TO authenticated
  USING (
    fk_usuario = public.meu_id_usuario_solicitacao()
    OR EXISTS (
      SELECT 1
      FROM public.dados_profissionais dp
      WHERE dp.fk_usuario = public.meu_id_usuario_solicitacao()
        AND (
          dp.id_profissional = solicitacoes.fk_profissional
          OR (
            solicitacoes.fk_grupo_empresa IS NOT NULL
            AND dp.fk_grupo_empresa = solicitacoes.fk_grupo_empresa
          )
        )
    )
  );

DROP POLICY IF EXISTS "solicitacoes_insert_cliente" ON public.solicitacoes;
CREATE POLICY "solicitacoes_insert_cliente"
  ON public.solicitacoes FOR INSERT TO authenticated
  WITH CHECK (
    fk_usuario = public.meu_id_usuario_solicitacao()
    AND EXISTS (
      SELECT 1
      FROM public.ass_usuario_endereco aue
      WHERE aue.fk_usuario = public.meu_id_usuario_solicitacao()
        AND aue.fk_endereco = solicitacoes.fk_endereco
        AND aue.endereco_ativo = true
    )
  );

DROP POLICY IF EXISTS "solicitacoes_update_profissional" ON public.solicitacoes;
CREATE POLICY "solicitacoes_update_profissional"
  ON public.solicitacoes FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.dados_profissionais dp
      WHERE dp.fk_usuario = public.meu_id_usuario_solicitacao()
        AND (
          dp.id_profissional = solicitacoes.fk_profissional
          OR (
            solicitacoes.fk_grupo_empresa IS NOT NULL
            AND dp.fk_grupo_empresa = solicitacoes.fk_grupo_empresa
          )
        )
    )
  )
  WITH CHECK (
    data_aceite IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM public.dados_profissionais dp
      WHERE dp.fk_usuario = public.meu_id_usuario_solicitacao()
        AND dp.id_profissional = solicitacoes.fk_profissional
    )
  );

DROP POLICY IF EXISTS "solicitacoes_anexos_select_participante" ON public.solicitacoes_anexos;
CREATE POLICY "solicitacoes_anexos_select_participante"
  ON public.solicitacoes_anexos FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.solicitacoes s
      WHERE s.id_solicitacao = solicitacoes_anexos.fk_solicitacao
    )
  );

DROP POLICY IF EXISTS "solicitacoes_anexos_insert_cliente" ON public.solicitacoes_anexos;
CREATE POLICY "solicitacoes_anexos_insert_cliente"
  ON public.solicitacoes_anexos FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.solicitacoes s
      WHERE s.id_solicitacao = solicitacoes_anexos.fk_solicitacao
        AND s.fk_usuario = public.meu_id_usuario_solicitacao()
    )
  );

-- 7. Storage para imagens da solicitacao.
-- Use o bucket publico existente "Imagens Servico" no Storage.
-- O app deve salvar em: solicitacao/{id_solicitacao}/nome-do-arquivo
DROP POLICY IF EXISTS "imagens_servico_solicitacao_insert" ON storage.objects;
CREATE POLICY "imagens_servico_solicitacao_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'Imagens Servico'
    AND (storage.foldername(name))[1] = 'solicitacao'
  );

DROP POLICY IF EXISTS "imagens_servico_solicitacao_select" ON storage.objects;
CREATE POLICY "imagens_servico_solicitacao_select"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'Imagens Servico');
