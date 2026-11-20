-- ============================================================================
-- ConsertaJá — ajustes v0.9 (rode tudo de uma vez no SQL Editor do Supabase)
-- ============================================================================
--  Acesso do profissional aos PRÓPRIOS dados.
--  Sintoma: a conta é criada (a linha existe em dados_profissionais), mas o
--  app não consegue lê-la: "Perfil não localizado" em Serviços Solicitados,
--  "perfil profissional não encontrado" no Modificar conta, nenhum aviso "!"
--  na home e criar serviço liberado (sem ler os dados, o app acha que não
--  falta nada). Funções e documentos também ficam invisíveis.
--
--  As regras abaixo só ACRESCENTAM acesso (no Postgres as policies se somam):
--  cada pessoa lê/edita apenas o que é dela. Nada do que já funcionava é
--  removido.
-- ============================================================================

BEGIN;

-- Ids da pessoa logada (SECURITY DEFINER: não depende das próprias RLS).
CREATE OR REPLACE FUNCTION public.meus_ids_usuario()
RETURNS SETOF bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT id_usuario FROM public.usuarios WHERE auth_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.meus_ids_profissional()
RETURNS SETOF bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT dp.id_profissional
  FROM public.dados_profissionais dp
  WHERE dp.fk_usuario IN (SELECT public.meus_ids_usuario());
$$;

CREATE OR REPLACE FUNCTION public.meus_ids_perfil()
RETURNS SETOF bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT dp.fk_perfil
  FROM public.dados_profissionais dp
  WHERE dp.fk_usuario IN (SELECT public.meus_ids_usuario())
    AND dp.fk_perfil IS NOT NULL;
$$;

GRANT EXECUTE ON FUNCTION public.meus_ids_usuario() TO authenticated;
GRANT EXECUTE ON FUNCTION public.meus_ids_profissional() TO authenticated;
GRANT EXECUTE ON FUNCTION public.meus_ids_perfil() TO authenticated;

-- dados_profissionais: ler e editar a própria linha ------------------------------
DROP POLICY IF EXISTS v09_dados_prof_select_proprio ON public.dados_profissionais;
CREATE POLICY v09_dados_prof_select_proprio ON public.dados_profissionais
  FOR SELECT TO authenticated
  USING (fk_usuario IN (SELECT public.meus_ids_usuario()));

DROP POLICY IF EXISTS v09_dados_prof_update_proprio ON public.dados_profissionais;
CREATE POLICY v09_dados_prof_update_proprio ON public.dados_profissionais
  FOR UPDATE TO authenticated
  USING (fk_usuario IN (SELECT public.meus_ids_usuario()))
  WITH CHECK (fk_usuario IN (SELECT public.meus_ids_usuario()));

-- perfil: ler, criar e editar o próprio -------------------------------------------
DROP POLICY IF EXISTS v09_perfil_select_proprio ON public.perfil;
CREATE POLICY v09_perfil_select_proprio ON public.perfil
  FOR SELECT TO authenticated
  USING (id_perfil IN (SELECT public.meus_ids_perfil())
         OR id_perfil IN (SELECT public.meus_ids_profissional()));

DROP POLICY IF EXISTS v09_perfil_insert_proprio ON public.perfil;
CREATE POLICY v09_perfil_insert_proprio ON public.perfil
  FOR INSERT TO authenticated
  WITH CHECK (id_perfil IN (SELECT public.meus_ids_profissional()));

DROP POLICY IF EXISTS v09_perfil_update_proprio ON public.perfil;
CREATE POLICY v09_perfil_update_proprio ON public.perfil
  FOR UPDATE TO authenticated
  USING (id_perfil IN (SELECT public.meus_ids_perfil())
         OR id_perfil IN (SELECT public.meus_ids_profissional()))
  WITH CHECK (id_perfil IN (SELECT public.meus_ids_perfil())
              OR id_perfil IN (SELECT public.meus_ids_profissional()));

-- Funções (áreas de atuação) do profissional -------------------------------------
DROP POLICY IF EXISTS v09_ass_oficio_select_proprio ON public.ass_oficio_profissional;
CREATE POLICY v09_ass_oficio_select_proprio ON public.ass_oficio_profissional
  FOR SELECT TO authenticated
  USING (fk_profissional IN (SELECT public.meus_ids_profissional()));

DROP POLICY IF EXISTS v09_ass_oficio_insert_proprio ON public.ass_oficio_profissional;
CREATE POLICY v09_ass_oficio_insert_proprio ON public.ass_oficio_profissional
  FOR INSERT TO authenticated
  WITH CHECK (fk_profissional IN (SELECT public.meus_ids_profissional()));

DROP POLICY IF EXISTS v09_ass_oficio_delete_proprio ON public.ass_oficio_profissional;
CREATE POLICY v09_ass_oficio_delete_proprio ON public.ass_oficio_profissional
  FOR DELETE TO authenticated
  USING (fk_profissional IN (SELECT public.meus_ids_profissional()));

-- Documentos validados do profissional --------------------------------------------
DROP POLICY IF EXISTS v09_docs_prof_select_proprio ON public.documentos_profissionais;
CREATE POLICY v09_docs_prof_select_proprio ON public.documentos_profissionais
  FOR SELECT TO authenticated
  USING (fk_profissional IN (SELECT public.meus_ids_profissional()));

DROP POLICY IF EXISTS v09_docs_prof_insert_proprio ON public.documentos_profissionais;
CREATE POLICY v09_docs_prof_insert_proprio ON public.documentos_profissionais
  FOR INSERT TO authenticated
  WITH CHECK (fk_profissional IN (SELECT public.meus_ids_profissional()));

NOTIFY pgrst, 'reload schema';

COMMIT;

-- ----------------------------------------------------------------------------
-- CONFERÊNCIA (rode separado, trocando o e-mail): mostra a conta, a linha de
-- profissional, o perfil, quantas funções e quantos documentos ela tem.
--
-- select u.id_usuario, u.auth_id, dp.id_profissional, dp.fk_perfil,
--        dp.data_admissao,
--        (select count(*) from ass_oficio_profissional a
--          where a.fk_profissional = dp.id_profissional) as funcoes,
--        (select count(*) from documentos_profissionais d
--          where d.fk_profissional = dp.id_profissional) as documentos
-- from usuarios u
-- join emails e on e.id_email = u.fk_email
-- left join dados_profissionais dp on dp.fk_usuario = u.id_usuario
-- where e.endereco_email = 'SEU_EMAIL@exemplo.com';
-- ----------------------------------------------------------------------------
