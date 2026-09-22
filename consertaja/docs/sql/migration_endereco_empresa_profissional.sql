-- ======================================================================
-- ConsertaJa - Enderecos separados: EMPRESA x PROFISSIONAL (CNPJ)
-- Rode UMA VEZ no SQL Editor do Supabase (idempotente, nao quebra nada).
-- Modelo novo (soma, nao altera nada existente):
--   Empresa ativa  -> public.ass_grupo_empresa_endereco (N por empresa)
--   Profissional CNPJ -> public.ass_profissional_endereco (1 comercial)
--   Cliente/pessoal -> public.ass_usuario_endereco (INTOCADA)
-- Associativa = permite N enderecos, segue seu padrao atual, sem ALTER.
-- ======================================================================

CREATE OR REPLACE FUNCTION public.meu_id_usuario()
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT id_usuario FROM public.usuarios WHERE auth_id = auth.uid() LIMIT 1
$$;
GRANT EXECUTE ON FUNCTION public.meu_id_usuario() TO authenticated;

-- 1) Enderecos da EMPRESA
CREATE TABLE IF NOT EXISTS public.ass_grupo_empresa_endereco (
  fk_grupo_empresa bigint NOT NULL
    REFERENCES public.grupo_empresa(id_grupo_empresa) ON DELETE CASCADE,
  fk_endereco bigint NOT NULL
    REFERENCES public.enderecos(id_endereco) ON DELETE CASCADE,
  apelido_endereco text NULL,
  endereco_ativo boolean NOT NULL DEFAULT false,
  tipo_endereco text NULL,
  PRIMARY KEY (fk_grupo_empresa, fk_endereco)
);
CREATE INDEX IF NOT EXISTS idx_ass_grupo_emp_endereco_grupo
  ON public.ass_grupo_empresa_endereco (fk_grupo_empresa);
CREATE INDEX IF NOT EXISTS idx_ass_grupo_emp_endereco_endereco
  ON public.ass_grupo_empresa_endereco (fk_endereco);
ALTER TABLE public.ass_grupo_empresa_endereco ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ass_grupo_emp_endereco_select" ON public.ass_grupo_empresa_endereco;
CREATE POLICY "ass_grupo_emp_endereco_select"
  ON public.ass_grupo_empresa_endereco FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.dados_profissionais dp
      WHERE dp.fk_grupo_empresa = ass_grupo_empresa_endereco.fk_grupo_empresa
        AND dp.fk_usuario = public.meu_id_usuario()
    )
  );
DROP POLICY IF EXISTS "ass_grupo_emp_endereco_insert" ON public.ass_grupo_empresa_endereco;
CREATE POLICY "ass_grupo_emp_endereco_insert"
  ON public.ass_grupo_empresa_endereco FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.dados_profissionais dp
      WHERE dp.fk_grupo_empresa = ass_grupo_empresa_endereco.fk_grupo_empresa
        AND dp.fk_usuario = public.meu_id_usuario()
    )
  );
DROP POLICY IF EXISTS "ass_grupo_emp_endereco_update" ON public.ass_grupo_empresa_endereco;
CREATE POLICY "ass_grupo_emp_endereco_update"
  ON public.ass_grupo_empresa_endereco FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.dados_profissionais dp
      WHERE dp.fk_grupo_empresa = ass_grupo_empresa_endereco.fk_grupo_empresa
        AND dp.fk_usuario = public.meu_id_usuario()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.dados_profissionais dp
      WHERE dp.fk_grupo_empresa = ass_grupo_empresa_endereco.fk_grupo_empresa
        AND dp.fk_usuario = public.meu_id_usuario()
    )
  );
DROP POLICY IF EXISTS "ass_grupo_emp_endereco_delete" ON public.ass_grupo_empresa_endereco;
CREATE POLICY "ass_grupo_emp_endereco_delete"
  ON public.ass_grupo_empresa_endereco FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.dados_profissionais dp
      WHERE dp.fk_grupo_empresa = ass_grupo_empresa_endereco.fk_grupo_empresa
        AND dp.fk_usuario = public.meu_id_usuario()
    )
  );

-- 2) Endereco do PROFISSIONAL independente (CNPJ individual)
CREATE TABLE IF NOT EXISTS public.ass_profissional_endereco (
  fk_profissional bigint NOT NULL
    REFERENCES public.dados_profissionais(id_profissional) ON DELETE CASCADE,
  fk_endereco bigint NOT NULL
    REFERENCES public.enderecos(id_endereco) ON DELETE CASCADE,
  apelido_endereco text NULL,
  endereco_ativo boolean NOT NULL DEFAULT false,
  tipo_endereco text NULL,
  PRIMARY KEY (fk_profissional, fk_endereco)
);
CREATE INDEX IF NOT EXISTS idx_ass_prof_endereco_prof
  ON public.ass_profissional_endereco (fk_profissional);
CREATE INDEX IF NOT EXISTS idx_ass_prof_endereco_endereco
  ON public.ass_profissional_endereco (fk_endereco);
ALTER TABLE public.ass_profissional_endereco ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ass_prof_endereco_select" ON public.ass_profissional_endereco;
CREATE POLICY "ass_prof_endereco_select"
  ON public.ass_profissional_endereco FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.dados_profissionais dp
      WHERE dp.id_profissional = ass_profissional_endereco.fk_profissional
        AND dp.fk_usuario = public.meu_id_usuario()
    )
  );
DROP POLICY IF EXISTS "ass_prof_endereco_insert" ON public.ass_profissional_endereco;
CREATE POLICY "ass_prof_endereco_insert"
  ON public.ass_profissional_endereco FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.dados_profissionais dp
      WHERE dp.id_profissional = ass_profissional_endereco.fk_profissional
        AND dp.fk_usuario = public.meu_id_usuario()
    )
  );
DROP POLICY IF EXISTS "ass_prof_endereco_update" ON public.ass_profissional_endereco;
CREATE POLICY "ass_prof_endereco_update"
  ON public.ass_profissional_endereco FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.dados_profissionais dp
      WHERE dp.id_profissional = ass_profissional_endereco.fk_profissional
        AND dp.fk_usuario = public.meu_id_usuario()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.dados_profissionais dp
      WHERE dp.id_profissional = ass_profissional_endereco.fk_profissional
        AND dp.fk_usuario = public.meu_id_usuario()
    )
  );
DROP POLICY IF EXISTS "ass_prof_endereco_delete" ON public.ass_profissional_endereco;
CREATE POLICY "ass_prof_endereco_delete"
  ON public.ass_profissional_endereco FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.dados_profissionais dp
      WHERE dp.id_profissional = ass_profissional_endereco.fk_profissional
        AND dp.fk_usuario = public.meu_id_usuario()
    )
  );
