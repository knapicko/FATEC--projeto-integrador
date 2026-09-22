-- =====================================================================
-- Postagens separadas por conta: profissional (CNPJ individual) x empresa
-- Tabela: public.postagens + public.imagens_postagens
-- =====================================================================
-- Como usar: cole este arquivo inteiro no SQL Editor do Supabase e rode.
-- Ele é idempotente (pode rodar mais de uma vez sem quebrar).

-- 1) Coluna que diz QUEM postou: 'profissional' ou 'empresa'
ALTER TABLE public.postagens
  ADD COLUMN IF NOT EXISTS tipo_autor text NOT NULL DEFAULT 'profissional';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'postagens_tipo_autor_check'
  ) THEN
    ALTER TABLE public.postagens
      ADD CONSTRAINT postagens_tipo_autor_check
      CHECK (tipo_autor IN ('profissional', 'empresa'));
  END IF;
END $$;

-- 2) Vínculo direto com a empresa (grupo_empresa).
--    Postagem de empresa  => fk_grupo_empresa preenchido + tipo_autor='empresa'
--    Postagem profissional => fk_grupo_empresa NULL + tipo_autor='profissional'
ALTER TABLE public.postagens
  ADD COLUMN IF NOT EXISTS fk_grupo_empresa bigint;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'postagens_fk_grupo_empresa_fkey'
  ) THEN
    ALTER TABLE public.postagens
      ADD CONSTRAINT postagens_fk_grupo_empresa_fkey
      FOREIGN KEY (fk_grupo_empresa)
      REFERENCES public.grupo_empresa(id_grupo_empresa)
      ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS postagens_fk_grupo_empresa_idx
  ON public.postagens (fk_grupo_empresa);
CREATE INDEX IF NOT EXISTS postagens_fk_perfil_tipo_autor_idx
  ON public.postagens (fk_perfil, tipo_autor);

-- 3) Backfill OPCIONAL (desligado por padrão — descomente se precisar):
--    Se hoje a empresa posta usando o MESMO fk_perfil do profissional
--    (colisão), você pode marcar manualmente postagens específicas como
--    'empresa'. NÃO rode o UPDATE genérico abaixo sem filtrar por
--    id_postagem, senão posts do profissional viram 'empresa'.
--    Exemplo manual:
--    UPDATE public.postagens SET tipo_autor = 'empresa',
--      fk_grupo_empresa = <ID_DO_GRUPO>
--    WHERE id_postagem IN (...ids das postagens que são da empresa...);
--    -- UPDATE genérico (PERIGOSO se os perfis colidem — manter comentado):
--    -- UPDATE public.postagens p
--    -- SET tipo_autor = 'empresa'
--    -- WHERE p.tipo_autor = 'profissional'
--    --   AND EXISTS (
--    --     SELECT 1 FROM public.grupo_empresa g WHERE g.fk_perfil = p.fk_perfil
--    --   );

-- 4) Tabela de imagens da postagem (uma linha por imagem, na ordem de envio)
CREATE TABLE IF NOT EXISTS public.imagens_postagens (
  id_imagem_postagem bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fk_postagem bigint NOT NULL
    REFERENCES public.postagens(id_postagem) ON DELETE CASCADE,
  url_imagem text NOT NULL,
  ordem integer NOT NULL DEFAULT 0,
  data_criacao timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS imagens_postagens_fk_postagem_idx
  ON public.imagens_postagens (fk_postagem);

-- 5) RLS mínimo para leitura/inserção/remoção (ajuste às suas policies)
ALTER TABLE public.imagens_postagens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "leitura publica imagens" ON public.imagens_postagens;
CREATE POLICY "leitura publica imagens"
  ON public.imagens_postagens FOR SELECT USING (true);

DROP POLICY IF EXISTS "insert autenticado imagens" ON public.imagens_postagens;
CREATE POLICY "insert autenticado imagens"
  ON public.imagens_postagens FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "delete autenticado imagens" ON public.imagens_postagens;
CREATE POLICY "delete autenticado imagens"
  ON public.imagens_postagens FOR DELETE TO authenticated USING (true);
