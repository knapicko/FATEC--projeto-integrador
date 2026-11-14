-- ============================================================================
-- ConsertaJá — RPC "completar_cadastro_google"
--
-- Problema: a tela Completar Perfil (login com Google) fazia 5–7 inserts
-- separados (emails, telefones, pessoa_fisica/juridica, ass_tipo_pessoa,
-- usuarios, dados_profissionais). Se qualquer um falhasse, os anteriores
-- ficavam gravados e a próxima tentativa quebrava por duplicidade
-- (e-mail/telefone/CPF "já cadastrado"). Também inseria telefone vazio quando
-- o usuário só tinha e-mail.
--
-- Esta função faz tudo numa única transação (tudo ou nada) e reaproveita
-- registros órfãos deixados por tentativas anteriores.
--
-- Rode inteiro no SQL Editor do Supabase.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.completar_cadastro_google(
  p_tipo_conta        text,              -- 'Cliente' | 'Profissional'
  p_nome              text,
  p_email             text,
  p_ddd               text DEFAULT NULL,
  p_numero            text DEFAULT NULL,
  p_pessoa_fisica     boolean DEFAULT true,
  p_cpf               text DEFAULT NULL,
  p_cnpj              text DEFAULT NULL,
  p_razao_social      text DEFAULT NULL,
  p_nome_fantasia     text DEFAULT NULL,
  p_tem_imovel        boolean DEFAULT false,
  p_data_nascimento   date DEFAULT NULL,
  p_data_fundacao     date DEFAULT NULL,
  p_foto_perfil_url   text DEFAULT NULL,
  p_id_facial         text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_id         uuid := auth.uid();
  v_id_usuario      bigint;
  v_id_profissional bigint;
  v_id_email        bigint;
  v_id_telefone     bigint;
  v_id_pf           bigint;
  v_id_pj           bigint;
  v_id_tipo_pessoa  bigint;
  v_email           text := nullif(lower(trim(coalesce(p_email, ''))), '');
  v_ddd             text := nullif(regexp_replace(coalesce(p_ddd, ''), '\D', '', 'g'), '');
  v_numero          text := nullif(regexp_replace(coalesce(p_numero, ''), '\D', '', 'g'), '');
  v_cpf             text := nullif(regexp_replace(coalesce(p_cpf, ''), '\D', '', 'g'), '');
  v_cnpj            text := nullif(regexp_replace(coalesce(p_cnpj, ''), '\D', '', 'g'), '');
BEGIN
  IF v_auth_id IS NULL THEN
    RAISE EXCEPTION 'Sessão expirada. Entre com o Google novamente.'
      USING ERRCODE = '42501';
  END IF;

  IF p_tipo_conta NOT IN ('Cliente', 'Profissional') THEN
    RAISE EXCEPTION 'Tipo de conta inválido: %', p_tipo_conta;
  END IF;

  IF v_email IS NULL AND (v_ddd IS NULL OR v_numero IS NULL) THEN
    RAISE EXCEPTION 'Informe e-mail ou telefone.';
  END IF;

  -- Já tem perfil? Não duplica: devolve o existente.
  SELECT u.id_usuario INTO v_id_usuario
    FROM public.usuarios u
   WHERE u.auth_id = v_auth_id
   LIMIT 1;

  IF v_id_usuario IS NOT NULL THEN
    SELECT dp.id_profissional INTO v_id_profissional
      FROM public.dados_profissionais dp
     WHERE dp.fk_usuario = v_id_usuario
     LIMIT 1;
    RETURN jsonb_build_object(
      'id_usuario', v_id_usuario,
      'id_profissional', v_id_profissional,
      'ja_existia', true
    );
  END IF;

  -- ---------------------------------------------------------------- E-mail
  IF v_email IS NOT NULL THEN
    SELECT e.id_email INTO v_id_email
      FROM public.emails e
     WHERE lower(trim(e.endereco_email)) = v_email
     ORDER BY e.id_email
     LIMIT 1;

    IF v_id_email IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.usuarios u WHERE u.fk_email = v_id_email
    ) THEN
      RAISE EXCEPTION 'Este e-mail já está cadastrado em outra conta.';
    END IF;

    IF v_id_email IS NULL THEN
      INSERT INTO public.emails (endereco_email, fk_status)
      VALUES (v_email, 1)
      RETURNING id_email INTO v_id_email;
    END IF;
  END IF;

  -- -------------------------------------------------------------- Telefone
  IF v_ddd IS NOT NULL AND v_numero IS NOT NULL THEN
    SELECT t.id_telefone INTO v_id_telefone
      FROM public.telefones t
     WHERE t.ddd = v_ddd AND t.numero = v_numero
     ORDER BY t.id_telefone
     LIMIT 1;

    IF v_id_telefone IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.usuarios u WHERE u.fk_telefone = v_id_telefone
    ) THEN
      RAISE EXCEPTION 'Este telefone já está cadastrado em outra conta.';
    END IF;

    IF v_id_telefone IS NULL THEN
      INSERT INTO public.telefones (ddd, numero, fk_status)
      VALUES (v_ddd, v_numero, 1)
      RETURNING id_telefone INTO v_id_telefone;
    END IF;
  END IF;

  -- ---------------------------------------------------------- Tipo pessoa
  IF p_pessoa_fisica THEN
    IF v_cpf IS NULL THEN
      RAISE EXCEPTION 'O CPF é obrigatório.';
    END IF;

    SELECT pf.id_pessoa_fisica INTO v_id_pf
      FROM public.pessoa_fisica pf
     WHERE pf.cpf = v_cpf
     ORDER BY pf.id_pessoa_fisica
     LIMIT 1;

    IF v_id_pf IS NOT NULL AND EXISTS (
      SELECT 1
        FROM public.ass_tipo_pessoa a
        JOIN public.usuarios u ON u.fk_tipo_pessoa = a.id_tipo_pessoa
       WHERE a.fk_pessoa_fisica = v_id_pf
    ) THEN
      RAISE EXCEPTION 'Este CPF já está cadastrado em outra conta.';
    END IF;

    IF v_id_pf IS NULL THEN
      INSERT INTO public.pessoa_fisica (cpf)
      VALUES (v_cpf)
      RETURNING id_pessoa_fisica INTO v_id_pf;
    END IF;

    SELECT a.id_tipo_pessoa INTO v_id_tipo_pessoa
      FROM public.ass_tipo_pessoa a
     WHERE a.fk_pessoa_fisica = v_id_pf
     ORDER BY a.id_tipo_pessoa
     LIMIT 1;

    IF v_id_tipo_pessoa IS NULL THEN
      INSERT INTO public.ass_tipo_pessoa (tipo, fk_pessoa_fisica, fk_pessoa_juridica)
      VALUES ('Física', v_id_pf, NULL)
      RETURNING id_tipo_pessoa INTO v_id_tipo_pessoa;
    END IF;
  ELSE
    IF v_cnpj IS NULL THEN
      RAISE EXCEPTION 'O CNPJ é obrigatório.';
    END IF;

    SELECT pj.id_pessoa_juridica INTO v_id_pj
      FROM public.pessoa_juridica pj
     WHERE pj.cnpj = v_cnpj
     ORDER BY pj.id_pessoa_juridica
     LIMIT 1;

    IF v_id_pj IS NOT NULL AND EXISTS (
      SELECT 1
        FROM public.ass_tipo_pessoa a
        JOIN public.usuarios u ON u.fk_tipo_pessoa = a.id_tipo_pessoa
       WHERE a.fk_pessoa_juridica = v_id_pj
    ) THEN
      RAISE EXCEPTION 'Este CNPJ já está cadastrado em outra conta.';
    END IF;

    IF v_id_pj IS NULL THEN
      INSERT INTO public.pessoa_juridica
        (cnpj, razao_social, nome_fantasia, tem_imovel, data_fundacao)
      VALUES
        (v_cnpj, nullif(trim(p_razao_social), ''), nullif(trim(p_nome_fantasia), ''),
         coalesce(p_tem_imovel, false), p_data_fundacao)
      RETURNING id_pessoa_juridica INTO v_id_pj;
    ELSE
      UPDATE public.pessoa_juridica
         SET razao_social  = coalesce(nullif(trim(p_razao_social), ''), razao_social),
             nome_fantasia = coalesce(nullif(trim(p_nome_fantasia), ''), nome_fantasia),
             tem_imovel    = coalesce(p_tem_imovel, tem_imovel),
             data_fundacao = coalesce(p_data_fundacao, data_fundacao)
       WHERE id_pessoa_juridica = v_id_pj;
    END IF;

    SELECT a.id_tipo_pessoa INTO v_id_tipo_pessoa
      FROM public.ass_tipo_pessoa a
     WHERE a.fk_pessoa_juridica = v_id_pj
     ORDER BY a.id_tipo_pessoa
     LIMIT 1;

    IF v_id_tipo_pessoa IS NULL THEN
      INSERT INTO public.ass_tipo_pessoa (tipo, fk_pessoa_fisica, fk_pessoa_juridica)
      VALUES ('Jurídica', NULL, v_id_pj)
      RETURNING id_tipo_pessoa INTO v_id_tipo_pessoa;
    END IF;
  END IF;

  -- -------------------------------------------------------------- Usuário
  IF p_tipo_conta = 'Profissional' THEN
    INSERT INTO public.usuarios
      (nome, data_nascimento, data_criacao, tipo_conta, fk_email, fk_telefone,
       fk_tipo_pessoa, foto_perfil_url, auth_id)
    VALUES
      (trim(p_nome), p_data_nascimento, now(), 'Profissional', v_id_email,
       v_id_telefone, v_id_tipo_pessoa, coalesce(p_foto_perfil_url, 'null'),
       v_auth_id)
    RETURNING id_usuario INTO v_id_usuario;

    INSERT INTO public.dados_profissionais
      (fk_usuario, id_facial, rosto_validado, data_admissao)
    VALUES
      (v_id_usuario, p_id_facial, p_id_facial IS NOT NULL, current_date)
    RETURNING id_profissional INTO v_id_profissional;
  ELSE
    INSERT INTO public.usuarios
      (nome, data_nascimento, data_criacao, tipo_conta, fk_email, fk_telefone,
       fk_tipo_pessoa, foto_perfil_url, auth_id)
    VALUES
      (trim(p_nome), p_data_nascimento, now(), 'Cliente', v_id_email,
       v_id_telefone, v_id_tipo_pessoa, coalesce(p_foto_perfil_url, 'null'),
       v_auth_id)
    RETURNING id_usuario INTO v_id_usuario;
  END IF;

  RETURN jsonb_build_object(
    'id_usuario', v_id_usuario,
    'id_profissional', v_id_profissional,
    'ja_existia', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.completar_cadastro_google(
  text, text, text, text, text, boolean, text, text, text, text, boolean,
  date, date, text, text
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.completar_cadastro_google(
  text, text, text, text, text, boolean, text, text, text, text, boolean,
  date, date, text, text
) TO authenticated;
