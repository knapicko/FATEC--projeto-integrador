-- ============================================================================
-- ConsertaJá — Solicitação Geográfica v2
-- Rode DEPOIS de migration_solicitacoes_geograficas.sql (já rodado).
--
--   1. Adiciona `titulo` em solicitacoes_geograficas
--   2. Remove (por enquanto) a tabela solicitacoes_geograficas_profissionais
--      e o que dependia dela
--   3. criar_solicitacao_geografica passa a receber o título e só cria
--   4. Nova RPC solicitacoes_geograficas_proximas: o que o profissional vê
--      no Radar (solicitações abertas da área dele, com a função dele)
--
-- `fk_usuario` (quem criou) já existe desde a v1.
-- Tudo numa transação: se algo falhar, nada muda.
-- ============================================================================

BEGIN;

-- 1) Título -------------------------------------------------------------------
ALTER TABLE public.solicitacoes_geograficas
  ADD COLUMN IF NOT EXISTS titulo text;

-- Solicitações criadas antes do título ganham um a partir da descrição.
UPDATE public.solicitacoes_geograficas
SET titulo = left(trim(descricao), 80)
WHERE titulo IS NULL OR trim(titulo) = '';

ALTER TABLE public.solicitacoes_geograficas
  ALTER COLUMN titulo SET NOT NULL;

ALTER TABLE public.solicitacoes_geograficas
  DROP CONSTRAINT IF EXISTS solicitacoes_geograficas_titulo_check;
ALTER TABLE public.solicitacoes_geograficas
  ADD CONSTRAINT solicitacoes_geograficas_titulo_check
  CHECK (char_length(trim(titulo)) BETWEEN 1 AND 80);

-- 2) Remove a tabela de notificados (e o que dependia dela) -----------------
-- A policy de SELECT olhava a tabela extra; recria só com o dono.
-- O profissional lê pelas RPCs abaixo (SECURITY DEFINER).
DROP POLICY IF EXISTS "sg_select" ON public.solicitacoes_geograficas;
CREATE POLICY "sg_select" ON public.solicitacoes_geograficas
  FOR SELECT TO authenticated
  USING (fk_usuario = public.meu_id_usuario());

DROP TABLE IF EXISTS public.solicitacoes_geograficas_profissionais;
DROP FUNCTION IF EXISTS public.sou_notificado_geo(bigint, bigint);

-- 3) Criar solicitação (agora com título, sem notificar ninguém) ------------
DROP FUNCTION IF EXISTS public.criar_solicitacao_geografica(
  text, bigint, text[], double precision, double precision, double precision
);

CREATE OR REPLACE FUNCTION public.criar_solicitacao_geografica(
  p_titulo          text,
  p_descricao       text,
  p_fk_funcao       bigint,
  p_img_solicitacao text[],
  p_lat             double precision,
  p_lng             double precision,
  p_raio_km         double precision DEFAULT 5
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usuario bigint := public.meu_id_usuario();
  v_oficio  bigint;
  v_id      bigint;
BEGIN
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'Sessão expirada. Entre novamente.' USING ERRCODE = '42501';
  END IF;
  IF coalesce(trim(p_titulo), '') = '' THEN
    RAISE EXCEPTION 'Informe o título do pedido.';
  END IF;
  IF coalesce(trim(p_descricao), '') = '' THEN
    RAISE EXCEPTION 'Descreva o que você precisa.';
  END IF;
  IF coalesce(array_length(p_img_solicitacao, 1), 0) = 0 THEN
    RAISE EXCEPTION 'Anexe pelo menos uma imagem.';
  END IF;

  SELECT fk_oficio INTO v_oficio FROM public.funcoes WHERE id_funcao = p_fk_funcao;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Área do pedido inválida.';
  END IF;

  INSERT INTO public.solicitacoes_geograficas
    (fk_usuario, titulo, descricao, fk_funcao, fk_oficio, img_solicitacao,
     latitude, longitude, raio_km)
  VALUES
    (v_usuario, trim(p_titulo), trim(p_descricao), p_fk_funcao, v_oficio,
     p_img_solicitacao, p_lat, p_lng, coalesce(p_raio_km, 5))
  RETURNING id_solicitacao_geografica INTO v_id;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.criar_solicitacao_geografica(
  text, text, bigint, text[], double precision, double precision, double precision
) TO authenticated;

-- 4) Radar do profissional ---------------------------------------------------
-- Solicitações abertas (Solicitada/Visualizada/Respondida) cujo círculo
-- (centro + raio) alcança a posição do profissional e cuja função pertence
-- a um ofício dele (perfil independente, empresa da qual é dono ou membro).
CREATE OR REPLACE FUNCTION public.solicitacoes_geograficas_proximas(
  p_lat double precision,
  p_lng double precision
)
RETURNS TABLE (
  id_solicitacao_geografica bigint,
  titulo          text,
  descricao       text,
  img_solicitacao text[],
  fk_funcao       bigint,
  funcao          text,
  cor             text,
  fk_status       bigint,
  latitude        double precision,
  longitude       double precision,
  distancia_km    double precision,
  data_criacao    timestamptz,
  nome_cliente    text,
  foto_cliente    text,
  endereco_cliente text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH eu AS (SELECT public.meu_id_usuario() AS id_usuario),
meus_perfis AS (
  SELECT dp.id_profissional, dp.fk_grupo_empresa, dp.fk_perfil
  FROM public.dados_profissionais dp
  WHERE dp.fk_usuario = (SELECT id_usuario FROM eu)
),
meus_oficios AS (
  SELECT aop.fk_oficio
  FROM public.ass_oficio_profissional aop
  WHERE aop.fk_profissional IN (SELECT id_profissional FROM meus_perfis)
  UNION
  SELECT aoe.fk_oficio
  FROM public.ass_oficio_grupo_empresa aoe
  JOIN public.grupo_empresa g ON g.id_grupo_empresa = aoe.fk_grupo_empresa
  WHERE g.id_grupo_empresa IN (SELECT fk_grupo_empresa FROM meus_perfis)
     OR g.fk_perfil IN (SELECT fk_perfil FROM meus_perfis)
),
candidatas AS (
  SELECT sg.*,
         6371 * 2 * asin(sqrt(
           power(sin(radians(sg.latitude - p_lat) / 2), 2) +
           cos(radians(p_lat)) * cos(radians(sg.latitude)) *
           power(sin(radians(sg.longitude - p_lng) / 2), 2)
         )) AS dist
  FROM public.solicitacoes_geograficas sg
  WHERE sg.fk_status IN (39, 41, 42)
    AND sg.fk_usuario IS DISTINCT FROM (SELECT id_usuario FROM eu)
    AND sg.fk_oficio IN (SELECT fk_oficio FROM meus_oficios)
)
SELECT c.id_solicitacao_geografica,
       c.titulo,
       c.descricao,
       c.img_solicitacao,
       c.fk_funcao,
       f.funcao::text,
       o.cor::text,
       c.fk_status,
       c.latitude,
       c.longitude,
       round(c.dist::numeric, 2)::double precision,
       c.data_criacao,
       u.nome::text,
       NULLIF(NULLIF(u.foto_perfil_url::text, ''), 'null'),
       (
         -- "Av. Paulista, 1578 - Bela Vista, SP"
         SELECT NULLIF(concat_ws(' - ',
                  NULLIF(concat_ws(', ', NULLIF(e.logradouro::text, ''), NULLIF(e.numero::text, '')), ''),
                  NULLIF(concat_ws(', ', NULLIF(e.bairro::text, ''), NULLIF(es.sigla_estado::text, '')), '')), '')
         FROM public.ass_usuario_endereco aue
         JOIN public.enderecos e ON e.id_endereco = aue.fk_endereco
         LEFT JOIN public.cidades ci ON ci.id_cidade = e.fk_cidade
         LEFT JOIN public.estados es ON es.id_estado = ci.fk_estado
         WHERE aue.fk_usuario = c.fk_usuario
         ORDER BY aue.endereco_ativo DESC
         LIMIT 1
       )
FROM candidatas c
JOIN public.funcoes f ON f.id_funcao = c.fk_funcao
LEFT JOIN public.oficios o ON o.id_oficio = c.fk_oficio
JOIN public.usuarios u ON u.id_usuario = c.fk_usuario
WHERE c.dist <= c.raio_km
ORDER BY c.data_criacao DESC
LIMIT 50;
$$;

GRANT EXECUTE ON FUNCTION public.solicitacoes_geograficas_proximas(
  double precision, double precision
) TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
