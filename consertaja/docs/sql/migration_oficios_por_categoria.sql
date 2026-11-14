-- ============================================================================
-- ConsertaJá — 1 ofício por categoria
-- Rode DEPOIS de migration_solicitacoes_geograficas_v4.sql.
--
-- Problema: `oficios` tinha 19 linhas (uma por função antiga), então a mesma
-- categoria ("Reparos domésticos") aparecia com ids 1, 2, 3 e 4, e
-- `funcoes.fk_oficio` apontava para ids diferentes da mesma categoria.
--
-- O que este script faz (tudo numa transação: se algo falhar, nada muda):
--   1. ass_oficio_profissional / ass_oficio_grupo_empresa ganham `fk_funcao`.
--      Hoje o app grava ali a FUNÇÃO escolhida (Encanador, Eletricista...)
--      usando o id do ofício antigo, que era igual ao id da função. Sem essa
--      coluna, ao juntar os ofícios, "Encanador" e "Eletricista" virariam a
--      mesma linha e a escolha do profissional se perderia.
--   2. Escolhe 1 id por categoria (o menor) e troca TODAS as colunas que
--      apontam para `oficios` (funcoes, serviços, associações, solicitações
--      geográficas...) para esse id — achadas pelas FKs do próprio banco.
--   3. Apaga as linhas repetidas de `oficios` e trava `categoria` como única.
--   4. Triggers: quem grava `fk_funcao` tem o ofício preenchido sozinho.
--   5. O Radar passa a comparar pela FUNÇÃO (não pela categoria). Senão um
--      Encanador passaria a ver pedidos de Eletricista (mesma categoria).
--
-- Resultado esperado: oficios com 7 linhas (1, 5, 8, 10, 12, 14, 16) e
-- funcoes.fk_oficio = 1,1,1,1,5,5,5,8,8,10,10,12,12,14,14,16,16,16,16.
-- ============================================================================

BEGIN;

-- 1) Associações passam a guardar a FUNÇÃO ----------------------------------------
ALTER TABLE public.ass_oficio_profissional
  ADD COLUMN IF NOT EXISTS fk_funcao bigint
  REFERENCES public.funcoes (id_funcao) ON DELETE CASCADE;
ALTER TABLE public.ass_oficio_grupo_empresa
  ADD COLUMN IF NOT EXISTS fk_funcao bigint
  REFERENCES public.funcoes (id_funcao) ON DELETE CASCADE;

-- Até aqui fk_oficio == id_funcao (migration_funcoes criou funcoes com o
-- mesmo id do ofício), então a função escolhida é o próprio fk_oficio.
UPDATE public.ass_oficio_profissional a
SET fk_funcao = f.id_funcao
FROM public.funcoes f
WHERE a.fk_funcao IS NULL AND f.id_funcao = a.fk_oficio;

UPDATE public.ass_oficio_grupo_empresa a
SET fk_funcao = f.id_funcao
FROM public.funcoes f
WHERE a.fk_funcao IS NULL AND f.id_funcao = a.fk_oficio;

-- Restrições únicas (ou PK) que incluem fk_oficio nas associações deixariam
-- de valer (duas funções da mesma categoria = mesmo fk_oficio). Remove e
-- recria pela função.
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT con.conname, cl.relname
    FROM pg_constraint con
    JOIN pg_class cl ON cl.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = cl.relnamespace
    WHERE n.nspname = 'public'
      AND cl.relname IN ('ass_oficio_profissional', 'ass_oficio_grupo_empresa')
      AND con.contype IN ('p', 'u')
      AND EXISTS (
        SELECT 1 FROM pg_attribute a
        WHERE a.attrelid = con.conrelid
          AND a.attnum = ANY (con.conkey)
          AND a.attname = 'fk_oficio')
  LOOP
    EXECUTE format('ALTER TABLE public.%I DROP CONSTRAINT %I', r.relname, r.conname);
  END LOOP;

  FOR r IN
    SELECT i.relname AS indice
    FROM pg_index x
    JOIN pg_class i ON i.oid = x.indexrelid
    JOIN pg_class t ON t.oid = x.indrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public'
      AND t.relname IN ('ass_oficio_profissional', 'ass_oficio_grupo_empresa')
      AND x.indisunique
      AND NOT x.indisprimary
      AND EXISTS (
        SELECT 1 FROM pg_attribute a
        WHERE a.attrelid = t.oid
          AND a.attnum = ANY (x.indkey::int2[])
          AND a.attname = 'fk_oficio')
  LOOP
    EXECUTE format('DROP INDEX IF EXISTS public.%I', r.indice);
  END LOOP;
END $$;

-- Remove repetidas (mesmo dono + mesma função).
DELETE FROM public.ass_oficio_profissional a
USING public.ass_oficio_profissional b
WHERE a.fk_profissional = b.fk_profissional
  AND a.fk_funcao = b.fk_funcao
  AND a.ctid > b.ctid;

DELETE FROM public.ass_oficio_grupo_empresa a
USING public.ass_oficio_grupo_empresa b
WHERE a.fk_grupo_empresa = b.fk_grupo_empresa
  AND a.fk_funcao = b.fk_funcao
  AND a.ctid > b.ctid;

CREATE UNIQUE INDEX IF NOT EXISTS ass_oficio_profissional_prof_funcao_uidx
  ON public.ass_oficio_profissional (fk_profissional, fk_funcao);
CREATE UNIQUE INDEX IF NOT EXISTS ass_oficio_grupo_empresa_grupo_funcao_uidx
  ON public.ass_oficio_grupo_empresa (fk_grupo_empresa, fk_funcao);

-- 2) Um id por categoria e troca de todas as referências ------------------------
-- Mapa "id antigo -> id da categoria" (sem tabela temporária: o SQL Editor do
-- Supabase pode rodar os comandos em sessões diferentes). `oficios` só é
-- apagado no passo 3, então o mapa dá o mesmo resultado em todos os comandos.
CREATE OR REPLACE VIEW public.vw_mapa_oficio_categoria AS
SELECT o.id_oficio AS antigo, c.novo
FROM public.oficios o
JOIN (
  SELECT lower(trim(categoria::text)) AS chave, min(id_oficio) AS novo
  FROM public.oficios
  GROUP BY lower(trim(categoria::text))
) c ON c.chave = lower(trim(o.categoria::text))
WHERE o.id_oficio <> c.novo;

-- Toda coluna (de qualquer tabela) com FK para oficios(id_oficio).
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT n.nspname AS esquema, cl.relname AS tabela, a.attname AS coluna
    FROM pg_constraint con
    JOIN pg_class cl ON cl.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = cl.relnamespace
    JOIN pg_attribute a
      ON a.attrelid = con.conrelid AND a.attnum = con.conkey[1]
    WHERE con.contype = 'f'
      AND con.confrelid = 'public.oficios'::regclass
      AND array_length(con.conkey, 1) = 1
  LOOP
    RAISE NOTICE 'Atualizando %.%.%', r.esquema, r.tabela, r.coluna;
    EXECUTE format(
      'UPDATE %I.%I t SET %I = m.novo FROM public.vw_mapa_oficio_categoria m WHERE t.%I = m.antigo',
      r.esquema, r.tabela, r.coluna, r.coluna);
  END LOOP;
END $$;

-- 3) Apaga os ofícios repetidos ----------------------------------------------------
-- A view é lida uma vez no início do DELETE (mesmo snapshot), antes de apagar.
DELETE FROM public.oficios o
WHERE o.id_oficio IN (SELECT antigo FROM public.vw_mapa_oficio_categoria);

DROP VIEW IF EXISTS public.vw_mapa_oficio_categoria;

CREATE UNIQUE INDEX IF NOT EXISTS oficios_categoria_uidx
  ON public.oficios (lower(trim(categoria::text)));

-- 4) Ofício preenchido a partir da função ------------------------------------------
CREATE OR REPLACE FUNCTION public.preencher_fk_oficio_pela_funcao()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.fk_funcao IS NOT NULL THEN
    SELECT f.fk_oficio INTO NEW.fk_oficio
    FROM public.funcoes f WHERE f.id_funcao = NEW.fk_funcao;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.preencher_fk_oficios_pela_funcao()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.fk_funcao IS NOT NULL THEN
    SELECT f.fk_oficio INTO NEW.fk_oficios
    FROM public.funcoes f WHERE f.id_funcao = NEW.fk_funcao;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ass_oficio_prof_funcao ON public.ass_oficio_profissional;
CREATE TRIGGER trg_ass_oficio_prof_funcao
  BEFORE INSERT OR UPDATE OF fk_funcao ON public.ass_oficio_profissional
  FOR EACH ROW EXECUTE FUNCTION public.preencher_fk_oficio_pela_funcao();

DROP TRIGGER IF EXISTS trg_ass_oficio_grupo_funcao ON public.ass_oficio_grupo_empresa;
CREATE TRIGGER trg_ass_oficio_grupo_funcao
  BEFORE INSERT OR UPDATE OF fk_funcao ON public.ass_oficio_grupo_empresa
  FOR EACH ROW EXECUTE FUNCTION public.preencher_fk_oficio_pela_funcao();

DROP TRIGGER IF EXISTS trg_servicos_prof_oficio ON public.servicos_profissional;
CREATE TRIGGER trg_servicos_prof_oficio
  BEFORE INSERT OR UPDATE OF fk_funcao ON public.servicos_profissional
  FOR EACH ROW EXECUTE FUNCTION public.preencher_fk_oficios_pela_funcao();

DROP TRIGGER IF EXISTS trg_servicos_temp_oficio ON public.servicos_chat_temporarios;
CREATE TRIGGER trg_servicos_temp_oficio
  BEFORE INSERT OR UPDATE OF fk_funcao ON public.servicos_chat_temporarios
  FOR EACH ROW EXECUTE FUNCTION public.preencher_fk_oficios_pela_funcao();

DROP TRIGGER IF EXISTS trg_solic_geo_oficio ON public.solicitacoes_geograficas;
CREATE TRIGGER trg_solic_geo_oficio
  BEFORE INSERT OR UPDATE OF fk_funcao ON public.solicitacoes_geograficas
  FOR EACH ROW EXECUTE FUNCTION public.preencher_fk_oficio_pela_funcao();

-- 5) Radar compara pela FUNÇÃO -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.radar_funcoes_perfil(
  p_id_profissional  bigint,
  p_id_grupo_empresa bigint
)
RETURNS TABLE (fk_funcao bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT aop.fk_funcao FROM public.ass_oficio_profissional aop
  WHERE p_id_profissional IS NOT NULL AND aop.fk_profissional = p_id_profissional
    AND aop.fk_funcao IS NOT NULL
  UNION
  SELECT sp.fk_funcao FROM public.servicos_profissional sp
  WHERE p_id_profissional IS NOT NULL AND sp.fk_profissional = p_id_profissional
    AND sp.fk_grupo_empresa IS NULL AND sp.fk_funcao IS NOT NULL
  UNION
  SELECT aoe.fk_funcao FROM public.ass_oficio_grupo_empresa aoe
  WHERE p_id_grupo_empresa IS NOT NULL AND aoe.fk_grupo_empresa = p_id_grupo_empresa
    AND aoe.fk_funcao IS NOT NULL
  UNION
  SELECT sp.fk_funcao FROM public.servicos_profissional sp
  WHERE p_id_grupo_empresa IS NOT NULL AND sp.fk_grupo_empresa = p_id_grupo_empresa
    AND sp.fk_funcao IS NOT NULL
  UNION
  SELECT aop.fk_funcao
  FROM public.ass_oficio_profissional aop
  JOIN public.dados_profissionais dp ON dp.id_profissional = aop.fk_profissional
  JOIN public.grupo_empresa g ON g.id_grupo_empresa = p_id_grupo_empresa
  WHERE p_id_grupo_empresa IS NOT NULL AND aop.fk_funcao IS NOT NULL
    AND (dp.fk_grupo_empresa = g.id_grupo_empresa OR dp.fk_perfil = g.fk_perfil);
$$;

CREATE OR REPLACE FUNCTION public.radar_minhas_funcoes(p_conta_empresa boolean DEFAULT NULL)
RETURNS TABLE (fk_funcao bigint)
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
  SELECT f.fk_funcao FROM perfis p
  CROSS JOIN LATERAL public.radar_funcoes_perfil(p.id_profissional, NULL) f
  WHERE p_conta_empresa IS NOT TRUE
  UNION
  SELECT f.fk_funcao FROM grupos gr
  CROSS JOIN LATERAL public.radar_funcoes_perfil(NULL, gr.id_grupo_empresa) f
  WHERE p_conta_empresa IS NOT FALSE;
$$;

-- 5a) Mapa do cliente: perfis com a função escolhida.
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
      OR p_fk_funcao IN (
        SELECT f.fk_funcao FROM public.radar_funcoes_perfil(id_profissional, id_grupo_empresa) f
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

-- 5b) Radar do profissional: pedidos com uma função dele.
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
    AND sg.fk_funcao IN (SELECT fk_funcao FROM public.radar_minhas_funcoes(NULL))
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

-- 5c) Aceite: confere a função (o resto igual à v4).
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
    IF v_geo.fk_funcao NOT IN (SELECT f.fk_funcao FROM public.radar_funcoes_perfil(NULL, v_grupo) f) THEN
      RAISE EXCEPTION 'A empresa não atende a área deste pedido.';
    END IF;
  ELSE
    SELECT dp.id_profissional INTO v_prof
    FROM public.dados_profissionais dp
    WHERE dp.fk_usuario = v_usuario
    ORDER BY (v_geo.fk_funcao IN (
               SELECT f.fk_funcao FROM public.radar_funcoes_perfil(dp.id_profissional, NULL) f)) DESC,
             dp.id_profissional
    LIMIT 1;

    IF v_prof IS NULL THEN
      RAISE EXCEPTION 'Perfil profissional não encontrado.';
    END IF;
    IF v_geo.fk_funcao NOT IN (SELECT f.fk_funcao FROM public.radar_funcoes_perfil(v_prof, NULL) f) THEN
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

-- 5d) Diagnóstico: mesmas chaves de antes ("meus_oficios" agora conta funções).
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
         sg.fk_funcao IN (SELECT fk_funcao FROM public.radar_minhas_funcoes(NULL)) AS da_area
  FROM public.solicitacoes_geograficas sg
  WHERE sg.fk_status IN (39, 41)
)
SELECT jsonb_build_object(
  'perfis_com_coordenadas', (SELECT count(*) FROM locais),
  'perfis_no_raio',         (SELECT count(*) FROM locais WHERE dist <= 5),
  'perfil_mais_proximo_km', (SELECT round(min(dist)::numeric, 1) FROM locais),
  'meus_oficios',           (SELECT count(*) FROM public.radar_minhas_funcoes(NULL)),
  'abertas_total',          (SELECT count(*) FROM abertas),
  'abertas_minhas',         (SELECT count(*) FROM abertas WHERE fk_usuario = (SELECT id_usuario FROM eu)),
  'abertas_da_area',        (SELECT count(*) FROM abertas
                              WHERE da_area AND fk_usuario IS DISTINCT FROM (SELECT id_usuario FROM eu)),
  'aberta_area_mais_proxima_km', (SELECT round(min(dist)::numeric, 1) FROM abertas
                              WHERE da_area AND fk_usuario IS DISTINCT FROM (SELECT id_usuario FROM eu))
);
$$;

-- As versões por categoria deixam de ser usadas.
DROP FUNCTION IF EXISTS public.radar_meus_oficios(boolean);
DROP FUNCTION IF EXISTS public.radar_oficios_perfil(bigint, bigint);

REVOKE ALL ON FUNCTION public.radar_funcoes_perfil(bigint, bigint) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.radar_minhas_funcoes(boolean) FROM PUBLIC, anon, authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- Conferência (rode depois, opcional):
--   SELECT * FROM oficios ORDER BY id_oficio;                 -- 7 linhas
--   SELECT id_funcao, funcao, fk_oficio FROM funcoes ORDER BY id_funcao;
--   SELECT fk_profissional, fk_funcao, fk_oficio FROM ass_oficio_profissional;
