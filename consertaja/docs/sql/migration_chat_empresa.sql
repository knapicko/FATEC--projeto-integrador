-- ======================================================================
-- ConsertaJa - Chat da EMPRESA (grupo_empresa) separado do profissional
-- Rode UMA VEZ no SQL Editor do Supabase (idempotente).
-- Rode PRIMEIRO o docs/sql/chat.sql (politicas base), depois este.
-- Modelo:
--   Chat do profissional (CNPJ individual): conversas.fk_grupo_empresa IS NULL
--   Chat da empresa: conversas.fk_grupo_empresa = grupo_empresa.id_grupo_empresa
-- ======================================================================

CREATE OR REPLACE FUNCTION public.meu_id_usuario()
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT id_usuario FROM public.usuarios WHERE auth_id = auth.uid() LIMIT 1
$$;

GRANT EXECUTE ON FUNCTION public.meu_id_usuario() TO authenticated;

ALTER TABLE public.conversas
  ADD COLUMN IF NOT EXISTS fk_grupo_empresa bigint;

-- Conversas da empresa nao usam fk_profissional: libera NULL nessa coluna.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'conversas'
      AND column_name = 'fk_profissional'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE public.conversas ALTER COLUMN fk_profissional DROP NOT NULL;
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'conversas_fk_grupo_empresa_fkey'
  ) THEN
    ALTER TABLE public.conversas
      ADD CONSTRAINT conversas_fk_grupo_empresa_fkey
      FOREIGN KEY (fk_grupo_empresa)
      REFERENCES public.grupo_empresa(id_grupo_empresa)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_conversas_fk_grupo_empresa
  ON public.conversas (fk_grupo_empresa);

-- Uma conversa por par cliente x empresa (evita duplicar o chat da loja).
-- UNIQUE em (fk_usuario, fk_grupo_empresa): conversas do profissional tem
-- fk_grupo_empresa NULL e nao conflitam (NULL nunca e igual a NULL).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'conversas_usuario_empresa_unique'
  ) THEN
    ALTER TABLE public.conversas
      ADD CONSTRAINT conversas_usuario_empresa_unique
      UNIQUE (fk_usuario, fk_grupo_empresa);
  END IF;
END $$;

-- RLS conversas da empresa: cliente da conversa OU profissional do grupo.
DROP POLICY IF EXISTS "conversas_select_empresa" ON public.conversas;
CREATE POLICY "conversas_select_empresa"
  ON public.conversas FOR SELECT TO authenticated
  USING (
    fk_grupo_empresa IS NOT NULL
    AND (
      fk_usuario = public.meu_id_usuario()
      OR EXISTS (
        SELECT 1 FROM public.dados_profissionais dp
        WHERE dp.fk_grupo_empresa = conversas.fk_grupo_empresa
          AND dp.fk_usuario = public.meu_id_usuario()
      )
    )
  );

DROP POLICY IF EXISTS "conversas_insert_empresa" ON public.conversas;
CREATE POLICY "conversas_insert_empresa"
  ON public.conversas FOR INSERT TO authenticated
  WITH CHECK (
    fk_grupo_empresa IS NOT NULL
    AND (
      fk_usuario = public.meu_id_usuario()
      OR EXISTS (
        SELECT 1 FROM public.dados_profissionais dp
        WHERE dp.fk_grupo_empresa = conversas.fk_grupo_empresa
          AND dp.fk_usuario = public.meu_id_usuario()
      )
    )
  );

DROP POLICY IF EXISTS "conversas_update_empresa" ON public.conversas;
CREATE POLICY "conversas_update_empresa"
  ON public.conversas FOR UPDATE TO authenticated
  USING (
    fk_grupo_empresa IS NOT NULL
    AND (
      fk_usuario = public.meu_id_usuario()
      OR EXISTS (
        SELECT 1 FROM public.dados_profissionais dp
        WHERE dp.fk_grupo_empresa = conversas.fk_grupo_empresa
          AND dp.fk_usuario = public.meu_id_usuario()
      )
    )
  )
  WITH CHECK (
    fk_grupo_empresa IS NOT NULL
    AND (
      fk_usuario = public.meu_id_usuario()
      OR EXISTS (
        SELECT 1 FROM public.dados_profissionais dp
        WHERE dp.fk_grupo_empresa = conversas.fk_grupo_empresa
          AND dp.fk_usuario = public.meu_id_usuario()
      )
    )
  );

-- RLS mensagens da conversa da empresa (SELECT / INSERT / UPDATE leitura).
DROP POLICY IF EXISTS "mensagens_select_empresa" ON public.mensagens;
CREATE POLICY "mensagens_select_empresa"
  ON public.mensagens FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversas c
      WHERE c.id_conversa = mensagens.fk_conversa
        AND c.fk_grupo_empresa IS NOT NULL
        AND (
          c.fk_usuario = public.meu_id_usuario()
          OR EXISTS (
            SELECT 1 FROM public.dados_profissionais dp
            WHERE dp.fk_grupo_empresa = c.fk_grupo_empresa
              AND dp.fk_usuario = public.meu_id_usuario()
          )
        )
    )
  );

DROP POLICY IF EXISTS "mensagens_insert_empresa" ON public.mensagens;
CREATE POLICY "mensagens_insert_empresa"
  ON public.mensagens FOR INSERT TO authenticated
  WITH CHECK (
    fk_remitente_usuario = public.meu_id_usuario()
    AND EXISTS (
      SELECT 1 FROM public.conversas c
      WHERE c.id_conversa = mensagens.fk_conversa
        AND c.fk_grupo_empresa IS NOT NULL
        AND (
          c.fk_usuario = public.meu_id_usuario()
          OR EXISTS (
            SELECT 1 FROM public.dados_profissionais dp
            WHERE dp.fk_grupo_empresa = c.fk_grupo_empresa
              AND dp.fk_usuario = public.meu_id_usuario()
          )
        )
    )
  );

DROP POLICY IF EXISTS "mensagens_update_empresa" ON public.mensagens;
CREATE POLICY "mensagens_update_empresa"
  ON public.mensagens FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversas c
      WHERE c.id_conversa = mensagens.fk_conversa
        AND c.fk_grupo_empresa IS NOT NULL
        AND (
          c.fk_usuario = public.meu_id_usuario()
          OR EXISTS (
            SELECT 1 FROM public.dados_profissionais dp
            WHERE dp.fk_grupo_empresa = c.fk_grupo_empresa
              AND dp.fk_usuario = public.meu_id_usuario()
          )
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.conversas c
      WHERE c.id_conversa = mensagens.fk_conversa
        AND c.fk_grupo_empresa IS NOT NULL
        AND (
          c.fk_usuario = public.meu_id_usuario()
          OR EXISTS (
            SELECT 1 FROM public.dados_profissionais dp
            WHERE dp.fk_grupo_empresa = c.fk_grupo_empresa
              AND dp.fk_usuario = public.meu_id_usuario()
          )
        )
    )
  );



