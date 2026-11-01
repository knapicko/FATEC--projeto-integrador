-- Permite que clientes autenticados consultem os vínculos de endereço
-- necessários para exibir serviços de profissionais independentes.
DROP POLICY IF EXISTS "ass_prof_endereco_select_publico"
  ON public.ass_profissional_endereco;

CREATE POLICY "ass_prof_endereco_select_publico"
  ON public.ass_profissional_endereco
  FOR SELECT
  TO authenticated
  USING (true);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'cidades'
      AND policyname = 'cidades_select_autenticado'
  ) THEN
    CREATE POLICY "cidades_select_autenticado"
      ON public.cidades FOR SELECT TO authenticated USING (true);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'estados'
      AND policyname = 'estados_select_autenticado'
  ) THEN
    CREATE POLICY "estados_select_autenticado"
      ON public.estados FOR SELECT TO authenticated USING (true);
  END IF;
END $$;
