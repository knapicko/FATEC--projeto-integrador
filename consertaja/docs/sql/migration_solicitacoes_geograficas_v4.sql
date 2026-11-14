-- ============================================================================
-- ConsertaJá — Solicitação Geográfica v4
-- Rode DEPOIS da v3.
--
--   1. radar_coord(): lê latitude/longitude com segurança. Antes, um valor com
--      vírgula ("-23,55"), vazio ou "0" derrubava a RPC inteira e o mapa do
--      cliente ficava sem nenhum profissional.
--   2. radar_locais_perfis(): UM lugar só que diz onde fica cada perfil
--      (independente ou empresa), procurando em todas as tabelas de endereço.
--   3. profissionais_proximos_geo e solicitacoes_geograficas_proximas usam o
--      item 2; o ofício do profissional também vale pelos serviços dele
--      (servicos_profissional), não só por ass_oficio_*.
--   4. endereco_proximo em solicitacoes_geograficas: endereço cadastrado do
--      cliente a até 100 m do ponto (GPS) onde ele pediu. No aceite vira o
--      fk_endereco da `solicitacoes`.
--   5. diagnostico_radar(): números que o app mostra quando a lista vem
--      vazia (para saber se é raio, ofício, coordenada...).
-- ============================================================================

BEGIN;

-- 0) Coluna nova (as funções abaixo já a usam) --------------------------------
-- Endereço cadastrado do cliente a até 100 m do ponto do pedido (pode ser null).
ALTER TABLE public.solicitacoes_geograficas
  ADD COLUMN IF NOT EXISTS endereco_proximo bigint NULL
  REFERENCES public.enderecos (id_endereco) ON DELETE SET NULL;

-- 1) Coordenada segura ----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.radar_coord(v text)
RETURNS double precision
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN replace(trim(coalesce(v, '')), ',', '.') ~ '^-?[0-9]+(\.[0-9]+)?$'
     AND replace(trim(v), ',', '.')::double precision <> 0
    THEN replace(trim(v), ',', '.')::double precision
  END
$$;

CREATE OR REPLACE FUNCTION public.radar_km(
  lat1 double precision, lng1 double precision,
  lat2 double precision, lng2 double precision
)
RETURNS double precision
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT 6371 * 2 * asin(least(1, sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) *
    power(sin(radians(lng2 - lng1) / 2), 2)
  )))
$$;

-- 2) Onde fica cada perfil --------------------------------------------------------
-- Independente = dados_profissionais sem empresa OU dono de empresa (o perfil
-- pessoal do dono aparece separado). Membros entram pelo perfil da empresa.
CREATE OR REPLACE FUNCTION public.radar_locais_perfis()
RETURNS TABLE (
  tipo             text,
  id_profissional  bigint,
  id_grupo_empresa bigint,
  fk_usuario       bigint,
  latitude         double precision,
  longitude        double precision
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT 'profissional'::text, dp.id_profissional, NULL::bigint, dp.fk_usuario,
         loc.lat, loc.lng
  FROM public.dados_profissionais dp
  CROSS JOIN LATERAL (
    SELECT public.radar_coord(en.latitude::text)  AS lat,
           public.radar_coord(en.longitude::text) AS lng
    FROM (
      SELECT ape.fk_endereco, 0 AS ordem, ape.endereco_ativo
      FROM public.ass_profissional_endereco ape
      WHERE ape.fk_profissional = dp.id_profissional
      UNION ALL
      SELECT aue.fk_endereco,
             CASE WHEN aue.tipo_endereco::text IN ('Loja', 'Oficina', 'Outro') THEN 1 ELSE 2 END,
             aue.endereco_ativo
      FROM public.ass_usuario_endereco aue
      WHERE aue.fk_usuario = dp.fk_usuario
    ) v
    JOIN public.enderecos en ON en.id_endereco = v.fk_endereco
    WHERE public.radar_coord(en.latitude::text) IS NOT NULL
      AND public.radar_coord(en.longitude::text) IS NOT NULL
    ORDER BY v.ordem, v.endereco_ativo DESC NULLS LAST
    LIMIT 1
  ) loc
  WHERE dp.fk_grupo_empresa IS NULL
     OR EXISTS (SELECT 1 FROM public.grupo_empresa g WHERE g.fk_perfil = dp.fk_perfil)

  UNION ALL

  SELECT 'empresa'::text, NULL::bigint, g.id_grupo_empresa,
         (SELECT dp.fk_usuario FROM public.dados_profissionais dp
           WHERE dp.fk_perfil = g.fk_perfil LIMIT 1),
         loc.lat, loc.lng
  FROM public.grupo_empresa g
  CROSS JOIN LATERAL (
    SELECT public.radar_coord(en.latitude::text)  AS lat,
           public.radar_coord(en.longitude::text) AS lng
    FROM (
      SELECT age.fk_endereco, 0 AS ordem, age.endereco_ativo
      FROM public.ass_grupo_empresa_endereco age
      WHERE age.fk_grupo_empresa = g.id_grupo_empresa
      UNION ALL
      -- legado: endereço comercial do dono/membros
      SELECT ape.fk_endereco, 1, ape.endereco_ativo
      FROM public.ass_profissional_endereco ape
      JOIN public.dados_profissionais dp ON dp.id_profissional = ape.fk_profissional
      WHERE dp.fk_grupo_empresa = g.id_grupo_empresa OR dp.fk_perfil = g.fk_perfil
      UNION ALL
      SELECT aue.fk_endereco, 2, aue.endereco_ativo
      FROM public.ass_usuario_endereco aue
      JOIN public.dados_profissionais dp ON dp.fk_usuario = aue.fk_usuario
      WHERE (dp.fk_grupo_empresa = g.id_grupo_empresa OR dp.fk_perfil = g.fk_perfil)
        AND aue.tipo_endereco::text IN ('Loja', 'Oficina', 'Outro')
    ) v
    JOIN public.enderecos en ON en.id_endereco = v.fk_endereco
    WHERE public.radar_coord(en.latitude::text) IS NOT NULL
      AND public.radar_coord(en.longitude::text) IS NOT NULL
    ORDER BY v.ordem, v.endereco_ativo DESC NULLS LAST
    LIMIT 1
  ) loc;
$$;

-- Ofícios de um perfil (associações + serviços cadastrados).
CREATE OR REPLACE FUNCTION public.radar_oficios_perfil(
  p_id_profissional  bigint,
  p_id_grupo_empresa bigint
)
RETURNS TABLE (fk_oficio bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT aop.fk_oficio FROM public.ass_oficio_profissional aop
  WHERE p_id_profissional IS NOT NULL AND aop.fk_profissional = p_id_profissional
  UNION
  SELECT sp.fk_oficios FROM public.servicos_profissional sp
  WHERE p_id_profissional IS NOT NULL AND sp.fk_profissional = p_id_profissional
    AND sp.fk_grupo_empresa IS NULL AND sp.fk_oficios IS NOT NULL
  UNION
  SELECT aoe.fk_oficio FROM public.ass_oficio_grupo_empresa aoe
  WHERE p_id_grupo_empresa IS NOT NULL AND aoe.fk_grupo_empresa = p_id_grupo_empresa
  UNION
  SELECT sp.fk_oficios FROM public.servicos_profissional sp
  WHERE p_id_grupo_empresa IS NOT NULL AND sp.fk_grupo_empresa = p_id_grupo_empresa
    AND sp.fk_oficios IS NOT NULL
  UNION
  SELECT aop.fk_oficio
  FROM public.ass_oficio_profissional aop
  JOIN public.dados_profissionais dp ON dp.id_profissional = aop.fk_profissional
  JOIN public.grupo_empresa g ON g.id_grupo_empresa = p_id_grupo_empresa
  WHERE p_id_grupo_empresa IS NOT NULL
    AND (dp.fk_grupo_empresa = g.id_grupo_empresa OR dp.fk_perfil = g.fk_perfil);
$$;

-- 3a) Perfis próximos (mapa do cliente) — mesma assinatura e retorno --------
CREATE OR REPLACE FUNCTION public.profissionais_proximos_geo(
  p_lat       double precision,
  p_lng       double precision,
  p_raio_km   double precision DEFAULT 5,
  p_fk_funcao bigint DEFAULT NULL
)
RETURNS TABLE (
  tipo             text,
  id_profissional  bigint,
  id_grupo_empresa bigint,
  nome             text,
  foto_url         text,
  tag_empresa      text,
  cor_tag_empresa  text,
  latitude         double precision,
  longitude        double precision,
  distancia_km     double precision,
  nota             numeric,
  ultima_conexao   timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH eu AS (SELECT public.meu_id_usuario() AS id_usuario),
funcao AS (SELECT f.fk_oficio FROM public.funcoes f WHERE f.id_funcao = p_fk_funcao),
locais AS (
  SELECT l.*, public.radar_km(p_lat, p_lng, l.latitude, l.longitude) AS dist
  FROM public.radar_locais_perfis() l
  WHERE l.fk_usuario IS DISTINCT FROM (SELECT id_usuario FROM eu)
),
no_raio AS (
  SELECT * FROM locais
  WHERE dist <= coalesce(p_raio_km, 5)
    AND (
      p_fk_funcao IS NULL
      OR (SELECT fk_oficio FROM funcao) IN (
        SELECT o.fk_oficio FROM public.radar_oficios_perfil(id_profissional, id_grupo_empresa) o
      )
    )
)
SELECT r.tipo,
       r.id_profissional,
       r.id_grupo_empresa,
       CASE WHEN r.tipo = 'empresa' THEN g.nome_empresa::text ELSE u.nome::text END,
       CASE WHEN r.tipo = 'empresa' THEN NULLIF(g.foto_url_empresa::text, '')
            ELSE NULLIF(NULLIF(u.foto_perfil_url::text, ''), 'null') END,
       NULLIF(g.tag_empresa::text, ''),
       NULLIF(g.cor_tag_empresa::text, ''),
       r.latitude,
       r.longitude,
       round(r.dist::numeric, 2)::double precision,
       (SELECT round(avg(av.nota)::numeric, 1)
          FROM public.avaliacoes_solicitacao av
          JOIN public.solicitacoes s ON s.id_solicitacao = av.fk_solicitacao
         WHERE av.tipo_avaliacao::text = 'profissional'
           AND ((r.tipo = 'empresa' AND s.fk_grupo_empresa = r.id_grupo_empresa)
             OR (r.tipo = 'profissional' AND s.fk_profissional = r.id_profissional))),
       u.ultima_conexao
FROM no_raio r
LEFT JOIN public.grupo_empresa g ON g.id_grupo_empresa = r.id_grupo_empresa
LEFT JOIN public.usuarios u ON u.id_usuario = r.fk_usuario
ORDER BY r.dist
LIMIT 60;
$$;

GRANT EXECUTE ON FUNCTION public.profissionais_proximos_geo(
  double precision, double precision, double precision, bigint
) TO authenticated;

-- Ofícios de quem está logado (independente / empresa / os dois).
CREATE OR REPLACE FUNCTION public.radar_meus_oficios(p_conta_empresa boolean DEFAULT NULL)
RETURNS TABLE (fk_oficio bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH perfis AS (
    SELECT dp.id_profissional, dp.fk_grupo_empresa, dp.fk_perfil
    FROM public.dados_profissionais dp
    WHERE dp.fk_usuario = public.meu_id_usuario()
  ),
  grupos AS (
    SELECT g.id_grupo_empresa FROM public.grupo_empresa g
    WHERE g.id_grupo_empresa IN (SELECT fk_grupo_empresa FROM perfis)
       OR g.fk_perfil IN (SELECT fk_perfil FROM perfis)
  )
  SELECT o.fk_oficio FROM perfis p
  CROSS JOIN LATERAL public.radar_oficios_perfil(p.id_profissional, NULL) o
  WHERE p_conta_empresa IS NOT TRUE
  UNION
  SELECT o.fk_oficio FROM grupos gr
  CROSS JOIN LATERAL public.radar_oficios_perfil(NULL, gr.id_grupo_empresa) o
  WHERE p_conta_empresa IS NOT FALSE;
$$;

-- 3b) Radar do profissional — mesma assinatura e retorno da v3 --------------
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
  metodo_entrega  text,
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
candidatas AS (
  SELECT sg.*, public.radar_km(p_lat, p_lng, sg.latitude, sg.longitude) AS dist
  FROM public.solicitacoes_geograficas sg
  WHERE sg.fk_status IN (39, 41)
    AND sg.fk_usuario IS DISTINCT FROM (SELECT id_usuario FROM eu)
    AND coalesce(sg.fk_oficio, (SELECT f.fk_oficio FROM public.funcoes f WHERE f.id_funcao = sg.fk_funcao))
        IN (SELECT fk_oficio FROM public.radar_meus_oficios(NULL))
)
SELECT c.id_solicitacao_geografica,
       c.titulo,
       c.descricao,
       c.img_solicitacao,
       c.fk_funcao,
       f.funcao::text,
       o.cor::text,
       c.metodo_entrega,
       c.fk_status,
       c.latitude,
       c.longitude,
       round(c.dist::numeric, 2)::double precision,
       c.data_criacao,
       u.nome::text,
       NULLIF(NULLIF(u.foto_perfil_url::text, ''), 'null'),
       (
         SELECT NULLIF(concat_ws(' - ',
                  NULLIF(concat_ws(', ', NULLIF(e.logradouro::text, ''), NULLIF(e.numero::text, '')), ''),
                  NULLIF(concat_ws(', ', NULLIF(e.bairro::text, ''), NULLIF(es.sigla_estado::text, '')), '')), '')
         FROM public.enderecos e
         LEFT JOIN public.cidades ci ON ci.id_cidade = e.fk_cidade
         LEFT JOIN public.estados es ON es.id_estado = ci.fk_estado
         WHERE e.id_endereco = c.endereco_proximo
       )
FROM candidatas c
JOIN public.funcoes f ON f.id_funcao = c.fk_funcao
LEFT JOIN public.oficios o ON o.id_oficio = f.fk_oficio
JOIN public.usuarios u ON u.id_usuario = c.fk_usuario
WHERE c.dist <= c.raio_km
ORDER BY c.data_criacao DESC
LIMIT 50;
$$;

-- 4) Endereço do cliente a até 100 m do ponto do pedido ----------------------
CREATE OR REPLACE FUNCTION public.radar_endereco_proximo(
  p_usuario  bigint,
  p_lat      double precision,
  p_lng      double precision,
  p_max_m    double precision DEFAULT 100
)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT x.id_endereco FROM (
    SELECT e.id_endereco,
           public.radar_km(p_lat, p_lng,
             public.radar_coord(e.latitude::text),
             public.radar_coord(e.longitude::text)) * 1000 AS metros
    FROM public.ass_usuario_endereco aue
    JOIN public.enderecos e ON e.id_endereco = aue.fk_endereco
    WHERE aue.fk_usuario = p_usuario
      AND public.radar_coord(e.latitude::text) IS NOT NULL
      AND public.radar_coord(e.longitude::text) IS NOT NULL
  ) x
  WHERE x.metros <= p_max_m
  ORDER BY x.metros
  LIMIT 1;
$$;

-- Preenche as solicitações abertas que já existem.
UPDATE public.solicitacoes_geograficas sg
SET endereco_proximo = public.radar_endereco_proximo(sg.fk_usuario, sg.latitude, sg.longitude)
WHERE sg.endereco_proximo IS NULL AND sg.fk_status IN (39, 41);

-- criar_solicitacao_geografica: mesma assinatura da v3, agora com endereco_proximo.
CREATE OR REPLACE FUNCTION public.criar_solicitacao_geografica(
  p_titulo          text,
  p_descricao       text,
  p_fk_funcao       bigint,
  p_metodo_entrega  text,
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
  IF p_metodo_entrega IS NULL OR p_metodo_entrega NOT IN (
       'Atendimento em Domicílio', 'Leva e Traz', 'Retirado no Local', 'Receba em Casa') THEN
    RAISE EXCEPTION 'Escolha o método de realização.';
  END IF;
  IF coalesce(array_length(p_img_solicitacao, 1), 0) = 0 THEN
    RAISE EXCEPTION 'Anexe pelo menos uma imagem.';
  END IF;
  IF p_lat IS NULL OR p_lng IS NULL OR (p_lat = 0 AND p_lng = 0) THEN
    RAISE EXCEPTION 'Não foi possível obter a sua localização.';
  END IF;

  SELECT fk_oficio INTO v_oficio FROM public.funcoes WHERE id_funcao = p_fk_funcao;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Área do pedido inválida.';
  END IF;

  INSERT INTO public.solicitacoes_geograficas
    (fk_usuario, titulo, descricao, fk_funcao, fk_oficio, metodo_entrega,
     img_solicitacao, latitude, longitude, raio_km, endereco_proximo)
  VALUES
    (v_usuario, trim(p_titulo), trim(p_descricao), p_fk_funcao, v_oficio,
     p_metodo_entrega, p_img_solicitacao, p_lat, p_lng, coalesce(p_raio_km, 5),
     public.radar_endereco_proximo(v_usuario, p_lat, p_lng, 100))
  RETURNING id_solicitacao_geografica INTO v_id;

  RETURN v_id;
END;
$$;

-- aceitar: fk_endereco = endereco_proximo (o resto igual à v3).
CREATE OR REPLACE FUNCTION public.aceitar_solicitacao_geografica(
  p_id_solicitacao_geografica bigint,
  p_valor                     numeric,
  p_conta_empresa             boolean DEFAULT false
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usuario bigint := public.meu_id_usuario();
  v_geo     public.solicitacoes_geograficas%ROWTYPE;
  v_prof    bigint;
  v_grupo   bigint;
  v_temp    bigint;
  v_sol     bigint;
BEGIN
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'Sessão expirada. Entre novamente.' USING ERRCODE = '42501';
  END IF;
  IF p_valor IS NULL OR p_valor <= 0 THEN
    RAISE EXCEPTION 'Informe o valor do serviço.';
  END IF;

  SELECT * INTO v_geo
  FROM public.solicitacoes_geograficas
  WHERE id_solicitacao_geografica = p_id_solicitacao_geografica
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitação não encontrada.';
  END IF;
  IF v_geo.fk_status NOT IN (39, 41) THEN
    RAISE EXCEPTION 'Esta solicitação já foi aceita por outro profissional ou foi cancelada.';
  END IF;
  IF v_geo.fk_usuario = v_usuario THEN
    RAISE EXCEPTION 'Você não pode aceitar a sua própria solicitação.';
  END IF;

  IF coalesce(p_conta_empresa, false) THEN
    SELECT dp.id_profissional, g.id_grupo_empresa
      INTO v_prof, v_grupo
    FROM public.dados_profissionais dp
    JOIN public.grupo_empresa g
      ON g.fk_perfil = dp.fk_perfil OR g.id_grupo_empresa = dp.fk_grupo_empresa
    WHERE dp.fk_usuario = v_usuario
    ORDER BY coalesce(g.fk_perfil = dp.fk_perfil, false) DESC
    LIMIT 1;

    IF v_grupo IS NULL THEN
      RAISE EXCEPTION 'Nenhuma empresa encontrada para a sua conta.';
    END IF;
    IF v_geo.fk_oficio NOT IN (SELECT o.fk_oficio FROM public.radar_oficios_perfil(NULL, v_grupo) o) THEN
      RAISE EXCEPTION 'A empresa não atende a área deste pedido.';
    END IF;
  ELSE
    SELECT dp.id_profissional INTO v_prof
    FROM public.dados_profissionais dp
    WHERE dp.fk_usuario = v_usuario
    ORDER BY (v_geo.fk_oficio IN (
               SELECT o.fk_oficio FROM public.radar_oficios_perfil(dp.id_profissional, NULL) o)) DESC,
             dp.id_profissional
    LIMIT 1;

    IF v_prof IS NULL THEN
      RAISE EXCEPTION 'Perfil profissional não encontrado.';
    END IF;
    IF v_geo.fk_oficio NOT IN (SELECT o.fk_oficio FROM public.radar_oficios_perfil(v_prof, NULL) o) THEN
      RAISE EXCEPTION 'Você não atende a área deste pedido.';
    END IF;
    v_grupo := NULL;
  END IF;

  INSERT INTO public.servicos_chat_temporarios
    (titulo, descricao, valor, imagem_url, ativo, fk_profissional,
     fk_grupo_empresa, fk_oficios, fk_funcao, tipo_execucao, carga_servico)
  VALUES
    (v_geo.titulo, v_geo.descricao, round(p_valor, 2), v_geo.img_solicitacao[1],
     true, v_prof, v_grupo, v_geo.fk_oficio, v_geo.fk_funcao,
     v_geo.metodo_entrega, 'Médio')
  RETURNING id_servico_temp INTO v_temp;

  INSERT INTO public.solicitacoes
    (data_solicitacao, data_aceite, valor_final, fk_usuario, fk_profissional,
     fk_status, fk_servico_prof, fk_servico_temp, fk_endereco, fk_grupo_empresa,
     tipo_execucao, detalhes, data_agendada, hora_agendada, hora_agendada_fim,
     etapa_solicitacao, imagens_anexadas_cliente, fk_solicitacao_geografica)
  VALUES
    (v_geo.data_criacao, now(), round(p_valor, 2), v_geo.fk_usuario, v_prof,
     2, NULL, v_temp, v_geo.endereco_proximo, v_grupo,
     v_geo.metodo_entrega, v_geo.descricao, NULL, NULL, NULL,
     1, v_geo.img_solicitacao, v_geo.id_solicitacao_geografica)
  RETURNING id_solicitacao INTO v_sol;

  UPDATE public.solicitacoes_geograficas
  SET fk_status = 42
  WHERE id_solicitacao_geografica = v_geo.id_solicitacao_geografica;

  RETURN v_sol;
END;
$$;

-- 5) Diagnóstico (mostrado no app quando a lista vem vazia) ------------------
CREATE OR REPLACE FUNCTION public.diagnostico_radar(
  p_lat double precision,
  p_lng double precision
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH eu AS (SELECT public.meu_id_usuario() AS id_usuario),
locais AS (
  SELECT public.radar_km(p_lat, p_lng, l.latitude, l.longitude) AS dist
  FROM public.radar_locais_perfis() l
  WHERE l.fk_usuario IS DISTINCT FROM (SELECT id_usuario FROM eu)
),
abertas AS (
  SELECT sg.*,
         public.radar_km(p_lat, p_lng, sg.latitude, sg.longitude) AS dist,
         sg.fk_oficio IN (SELECT fk_oficio FROM public.radar_meus_oficios(NULL)) AS da_area
  FROM public.solicitacoes_geograficas sg
  WHERE sg.fk_status IN (39, 41)
)
SELECT jsonb_build_object(
  'perfis_com_coordenadas', (SELECT count(*) FROM locais),
  'perfis_no_raio',         (SELECT count(*) FROM locais WHERE dist <= 5),
  'perfil_mais_proximo_km', (SELECT round(min(dist)::numeric, 1) FROM locais),
  'meus_oficios',           (SELECT count(*) FROM public.radar_meus_oficios(NULL)),
  'abertas_total',          (SELECT count(*) FROM abertas),
  'abertas_minhas',         (SELECT count(*) FROM abertas WHERE fk_usuario = (SELECT id_usuario FROM eu)),
  'abertas_da_area',        (SELECT count(*) FROM abertas
                              WHERE da_area AND fk_usuario IS DISTINCT FROM (SELECT id_usuario FROM eu)),
  'aberta_area_mais_proxima_km', (SELECT round(min(dist)::numeric, 1) FROM abertas
                              WHERE da_area AND fk_usuario IS DISTINCT FROM (SELECT id_usuario FROM eu))
);
$$;

GRANT EXECUTE ON FUNCTION public.radar_coord(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.radar_km(double precision, double precision, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION public.diagnostico_radar(double precision, double precision) TO authenticated;

-- Funções internas: só as RPCs acima as chamam.
REVOKE ALL ON FUNCTION public.radar_locais_perfis() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.radar_oficios_perfil(bigint, bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.radar_meus_oficios(boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.radar_endereco_proximo(bigint, double precision, double precision, double precision) FROM PUBLIC, anon, authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
