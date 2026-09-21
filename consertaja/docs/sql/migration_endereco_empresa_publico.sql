-- ======================================================================
-- ConsertaJa - Leitura PUBLICA do endereco da empresa (perfil_loja)
-- Rode UMA VEZ no SQL Editor do Supabase (idempotente, nao quebra nada).
-- Motivo: as policies atuais de ass_grupo_empresa_endereco exigem ser
-- MEMBRO do grupo (dados_profissionais.fk_grupo_empresa), entao o CLIENTE
-- que abre o perfil_loja nao enxerga nada ("endereco nao encontrado").
-- O perfil da loja e publico: qualquer pessoa autenticada pode VER o
-- endereco da empresa. Escrita continua restrita aos membros.
-- Sem isso, o app ate mostra, mas o Supabase retorna lista vazia por RLS.
-- ======================================================================

-- Garante helper de "quem sou eu" (mesmo das outras migrations).
CREATE OR REPLACE FUNCTION public.meu_id_usuario()
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT id_usuario FROM public.usuarios WHERE auth_id = auth.uid() LIMIT 1
$$;
GRANT EXECUTE ON FUNCTION public.meu_id_usuario() TO authenticated;

-- Leitura publica autenticada do vinculo empresa x endereco.
DROP POLICY IF EXISTS "ass_grupo_emp_endereco_select" ON public.ass_grupo_empresa_endereco;
DROP POLICY IF EXISTS "ass_grupo_emp_endereco_select_publico" ON public.ass_grupo_empresa_endereco;
CREATE POLICY "ass_grupo_emp_endereco_select_publico"
  ON public.ass_grupo_empresa_endereco FOR SELECT TO authenticated
  USING (true);

-- Endereco fisico da empresa tambem precisa ser visivel ao cliente.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'enderecos'
      AND policyname = 'enderecos_select_autenticado'
  ) THEN
    CREATE POLICY "enderecos_select_autenticado"
      ON public.enderecos FOR SELECT TO authenticated
      USING (true);
  END IF;
END $$;

-- Cidade/estado do endereco tambem precisam ser visiveis ao cliente.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'cidades'
      AND policyname = 'cidades_select_autenticado'
  ) THEN
    CREATE POLICY "cidades_select_autenticado"
      ON public.cidades FOR SELECT TO authenticated
      USING (true);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'estados'
      AND policyname = 'estados_select_autenticado'
  ) THEN
    CREATE POLICY "estados_select_autenticado"
      ON public.estados FOR SELECT TO authenticated
      USING (true);
  END IF;
END $$;
