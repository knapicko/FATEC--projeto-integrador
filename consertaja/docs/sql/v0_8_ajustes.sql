-- ============================================================================
-- ConsertaJá — ajustes v0.8 (rode tudo de uma vez no SQL Editor do Supabase)
-- ============================================================================
--  1. Conclusão do cadastro do PROFISSIONAL pelo servidor.
--     O app gravava direto em dados_profissionais e a regra de acesso (RLS)
--     recusava ("new row violates row-level security policy for table
--     dados_profissionais"): a conta ficava criada pela metade, sem dados do
--     profissional, ofícios e documentos, e o app não ia para a home.
--     Esta função grava os três de uma vez para o PRÓPRIO usuário logado,
--     já com data de admissão e o perfil (fk_perfil).
--  2. Conserta as contas já criadas sem perfil ou sem data de admissão.
-- ============================================================================

BEGIN;

-- Cria o perfil do profissional (se ainda não tem) e liga em fk_perfil.
-- Mesmo padrão do app: id_perfil = id_profissional. CNPJ começa como
-- "Independente" (pode virar Loja no Modificar conta).
CREATE OR REPLACE FUNCTION public.garantir_perfil_profissional(p_prof bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil bigint;
  v_pj     boolean;
BEGIN
  SELECT dp.fk_perfil, (atp.fk_pessoa_juridica IS NOT NULL)
    INTO v_perfil, v_pj
  FROM public.dados_profissionais dp
  JOIN public.usuarios u ON u.id_usuario = dp.fk_usuario
  LEFT JOIN public.ass_tipo_pessoa atp ON atp.id_tipo_pessoa = u.fk_tipo_pessoa
  WHERE dp.id_profissional = p_prof;

  IF v_perfil IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.perfil WHERE id_perfil = v_perfil) THEN
    RETURN v_perfil;
  END IF;

  IF coalesce(v_pj, false) THEN
    INSERT INTO public.perfil (id_perfil, cor_banner, tipo_perfil)
    VALUES (p_prof, '0xFF0FB3FF', 'Independente')
    ON CONFLICT (id_perfil) DO NOTHING;
  ELSE
    INSERT INTO public.perfil (id_perfil, cor_banner)
    VALUES (p_prof, '0xFF0FB3FF')
    ON CONFLICT (id_perfil) DO NOTHING;
  END IF;

  UPDATE public.dados_profissionais SET fk_perfil = p_prof
  WHERE id_profissional = p_prof AND fk_perfil IS NULL;
  RETURN p_prof;
END;
$$;
REVOKE ALL ON FUNCTION public.garantir_perfil_profissional(bigint) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.concluir_cadastro_profissional(
  p_id_facial  text,
  p_funcoes    bigint[] DEFAULT '{}',
  p_documentos text[]   DEFAULT '{}'
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usuario bigint;
  v_prof    bigint;
  v_funcao  bigint;
  v_doc     text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Sessão expirada. Entre novamente.' USING ERRCODE = '42501';
  END IF;

  SELECT id_usuario INTO v_usuario
  FROM public.usuarios WHERE auth_id = auth.uid()
  LIMIT 1;
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'Usuário não encontrado.';
  END IF;

  -- Idempotente: se já existe (tentativa anterior), só completa.
  SELECT id_profissional INTO v_prof
  FROM public.dados_profissionais
  WHERE fk_usuario = v_usuario AND fk_grupo_empresa IS NULL
  ORDER BY id_profissional
  LIMIT 1;

  IF v_prof IS NULL THEN
    INSERT INTO public.dados_profissionais
      (fk_usuario, id_facial, rosto_validado, data_admissao)
    VALUES
      (v_usuario, p_id_facial, p_id_facial IS NOT NULL, current_date)
    RETURNING id_profissional INTO v_prof;
  ELSE
    UPDATE public.dados_profissionais
    SET id_facial = coalesce(p_id_facial, id_facial),
        rosto_validado = coalesce(rosto_validado, false) OR p_id_facial IS NOT NULL,
        data_admissao = coalesce(data_admissao, current_date)
    WHERE id_profissional = v_prof;
  END IF;

  -- Perfil do profissional (descrição, tipo, banner): antes só era criado
  -- depois pelo app (e o banco recusava -> "perfil profissional não
  -- encontrado" no Modificar conta).
  PERFORM public.garantir_perfil_profissional(v_prof);

  FOREACH v_funcao IN ARRAY coalesce(p_funcoes, '{}') LOOP
    INSERT INTO public.ass_oficio_profissional (fk_profissional, fk_funcao)
    SELECT v_prof, v_funcao
    WHERE NOT EXISTS (
      SELECT 1 FROM public.ass_oficio_profissional
      WHERE fk_profissional = v_prof AND fk_funcao = v_funcao
    );
  END LOOP;

  -- tipo_documento é do tipo (enum) "Documento": compara como texto e
  -- grava com cast. Um documento com nome fora da lista não derruba o
  -- cadastro (só é pulado).
  FOREACH v_doc IN ARRAY coalesce(p_documentos, '{}') LOOP
    BEGIN
      INSERT INTO public.documentos_profissionais
        (tipo_documento, fk_profissional, validacao_documento)
      SELECT v_doc::"Documento", v_prof, true
      WHERE NOT EXISTS (
        SELECT 1 FROM public.documentos_profissionais
        WHERE fk_profissional = v_prof AND tipo_documento::text = v_doc
      );
    EXCEPTION WHEN others THEN
      RAISE WARNING '[cadastro] documento "%" não salvo: %', v_doc, SQLERRM;
    END;
  END LOOP;

  RETURN v_prof;
END;
$$;

REVOKE ALL ON FUNCTION public.concluir_cadastro_profissional(text, bigint[], text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.concluir_cadastro_profissional(text, bigint[], text[]) TO authenticated;

-- 2) CORRIGE CONTAS JÁ CRIADAS ----------------------------------------------------
-- Profissionais (independentes) sem perfil ou sem data de admissão.
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT dp.id_profissional
    FROM public.dados_profissionais dp
    WHERE dp.fk_grupo_empresa IS NULL
      AND (dp.fk_perfil IS NULL
           OR NOT EXISTS (SELECT 1 FROM public.perfil p WHERE p.id_perfil = dp.fk_perfil))
  LOOP
    PERFORM public.garantir_perfil_profissional(r.id_profissional);
  END LOOP;
END $$;

UPDATE public.dados_profissionais dp
SET data_admissao = coalesce(u.data_criacao::date, current_date)
FROM public.usuarios u
WHERE u.id_usuario = dp.fk_usuario AND dp.data_admissao IS NULL;

NOTIFY pgrst, 'reload schema';

COMMIT;
