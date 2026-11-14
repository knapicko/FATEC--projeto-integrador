-- ============================================================================
-- ConsertaJá — Solicitação Geográfica v3 (aceite pelo profissional)
-- Rode DEPOIS de migration_solicitacoes_geograficas.sql e da _v2.
--
--   1. Status 40 "Concluída"
--   2. metodo_entrega em solicitacoes_geograficas (+ criar_solicitacao_geografica)
--   3. aceitar_solicitacao_geografica: o profissional aceita → geo vira 42 e
--      nasce a `solicitacoes` (status 2 "Aguardando Pagamento")
--   4. Trigger: solicitação vinculada concluída (6) ou cancelada (7) → geo 40
--   5. cancelar_solicitacao_geografica (cliente), antes ou depois do aceite
--   6. Radar do profissional só mostra as que ainda não foram aceitas
--   7. RPCs de leitura: o que o profissional aceitou / o que o cliente acompanha
--
-- Tudo numa transação: se algo falhar, nada muda.
-- ============================================================================

BEGIN;

-- 1) Status --------------------------------------------------------------------
INSERT INTO public.status (id_status, tipo_status, status)
VALUES (40, 'Solicitação Geográfica', 'Concluída')
ON CONFLICT (id_status) DO UPDATE
SET tipo_status = EXCLUDED.tipo_status,
    status      = EXCLUDED.status;

-- 2) Método de realização escolhido pelo cliente --------------------------------
ALTER TABLE public.solicitacoes_geograficas
  ADD COLUMN IF NOT EXISTS metodo_entrega text;

UPDATE public.solicitacoes_geograficas
SET metodo_entrega = 'Atendimento em Domicílio'
WHERE metodo_entrega IS NULL OR trim(metodo_entrega) = '';

ALTER TABLE public.solicitacoes_geograficas
  ALTER COLUMN metodo_entrega SET DEFAULT 'Atendimento em Domicílio',
  ALTER COLUMN metodo_entrega SET NOT NULL;

ALTER TABLE public.solicitacoes_geograficas
  DROP CONSTRAINT IF EXISTS solicitacoes_geograficas_metodo_entrega_check;
ALTER TABLE public.solicitacoes_geograficas
  ADD CONSTRAINT solicitacoes_geograficas_metodo_entrega_check
  CHECK (metodo_entrega IN ('Atendimento em Domicílio', 'Leva e Traz',
                            'Retirado no Local', 'Receba em Casa'));

-- Uma solicitação geográfica gera no máximo UMA solicitação.
CREATE UNIQUE INDEX IF NOT EXISTS solicitacoes_fk_solicitacao_geografica_uidx
  ON public.solicitacoes (fk_solicitacao_geografica)
  WHERE fk_solicitacao_geografica IS NOT NULL;

DROP FUNCTION IF EXISTS public.criar_solicitacao_geografica(
  text, text, bigint, text[], double precision, double precision, double precision
);

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

  SELECT fk_oficio INTO v_oficio FROM public.funcoes WHERE id_funcao = p_fk_funcao;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Área do pedido inválida.';
  END IF;

  INSERT INTO public.solicitacoes_geograficas
    (fk_usuario, titulo, descricao, fk_funcao, fk_oficio, metodo_entrega,
     img_solicitacao, latitude, longitude, raio_km)
  VALUES
    (v_usuario, trim(p_titulo), trim(p_descricao), p_fk_funcao, v_oficio,
     p_metodo_entrega, p_img_solicitacao, p_lat, p_lng, coalesce(p_raio_km, 5))
  RETURNING id_solicitacao_geografica INTO v_id;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.criar_solicitacao_geografica(
  text, text, bigint, text, text[], double precision, double precision, double precision
) TO authenticated;

-- 3) Profissional aceita --------------------------------------------------------
-- `solicitacoes` não tem titulo / fk_funcao / fk_oficio: eles vão para um
-- serviço em `servicos_chat_temporarios` (o mesmo que a proposta do chat usa),
-- ligado por fk_servico_temp. Assim todas as telas que já leem o serviço
-- (detalhes, pagamento, listas) mostram o título, a função e o valor.
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
  v_end     bigint;
  v_temp    bigint;
  v_sol     bigint;
BEGIN
  IF v_usuario IS NULL THEN
    RAISE EXCEPTION 'Sessão expirada. Entre novamente.' USING ERRCODE = '42501';
  END IF;
  IF p_valor IS NULL OR p_valor <= 0 THEN
    RAISE EXCEPTION 'Informe o valor do serviço.';
  END IF;

  -- Trava a linha: dois profissionais aceitando ao mesmo tempo → só um passa.
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
    -- Conta empresa: empresa da qual é dono (prioridade) ou membro.
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

    IF NOT EXISTS (
         SELECT 1 FROM public.ass_oficio_grupo_empresa aoe
         WHERE aoe.fk_grupo_empresa = v_grupo AND aoe.fk_oficio = v_geo.fk_oficio)
       AND NOT EXISTS (
         SELECT 1
         FROM public.dados_profissionais dp
         JOIN public.grupo_empresa g ON g.id_grupo_empresa = v_grupo
         JOIN public.ass_oficio_profissional aop ON aop.fk_profissional = dp.id_profissional
         WHERE (dp.fk_grupo_empresa = v_grupo OR dp.fk_perfil = g.fk_perfil)
           AND aop.fk_oficio = v_geo.fk_oficio) THEN
      RAISE EXCEPTION 'A empresa não atende a área deste pedido.';
    END IF;
  ELSE
    -- Profissional independente.
    SELECT dp.id_profissional INTO v_prof
    FROM public.dados_profissionais dp
    WHERE dp.fk_usuario = v_usuario
    ORDER BY EXISTS (
      SELECT 1 FROM public.ass_oficio_profissional aop
      WHERE aop.fk_profissional = dp.id_profissional
        AND aop.fk_oficio = v_geo.fk_oficio) DESC,
      dp.id_profissional
    LIMIT 1;

    IF v_prof IS NULL THEN
      RAISE EXCEPTION 'Perfil profissional não encontrado.';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.ass_oficio_profissional aop
      WHERE aop.fk_profissional = v_prof AND aop.fk_oficio = v_geo.fk_oficio) THEN
      RAISE EXCEPTION 'Você não atende a área deste pedido.';
    END IF;
    v_grupo := NULL;
  END IF;

  -- Endereço do cliente (ativo primeiro) para o deslocamento / entrega.
  SELECT aue.fk_endereco INTO v_end
  FROM public.ass_usuario_endereco aue
  WHERE aue.fk_usuario = v_geo.fk_usuario
  ORDER BY aue.endereco_ativo DESC
  LIMIT 1;

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
     2, NULL, v_temp, v_end, v_grupo,
     v_geo.metodo_entrega, v_geo.descricao, NULL, NULL, NULL,
     1, v_geo.img_solicitacao, v_geo.id_solicitacao_geografica)
  RETURNING id_solicitacao INTO v_sol;

  UPDATE public.solicitacoes_geograficas
  SET fk_status = 42
  WHERE id_solicitacao_geografica = v_geo.id_solicitacao_geografica;

  RETURN v_sol;
END;
$$;

GRANT EXECUTE ON FUNCTION public.aceitar_solicitacao_geografica(bigint, numeric, boolean)
  TO authenticated;

-- 4) Solicitação vinculada concluída/cancelada → geográfica "Concluída" (40) ---
CREATE OR REPLACE FUNCTION public.concluir_solicitacao_geografica_vinculada()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.fk_solicitacao_geografica IS NOT NULL
     AND NEW.fk_status IN (6, 7)
     AND OLD.fk_status IS DISTINCT FROM NEW.fk_status THEN
    UPDATE public.solicitacoes_geograficas
    SET fk_status = 40
    WHERE id_solicitacao_geografica = NEW.fk_solicitacao_geografica
      AND fk_status <> 40;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_concluir_solicitacao_geografica ON public.solicitacoes;
CREATE TRIGGER trg_concluir_solicitacao_geografica
  AFTER UPDATE OF fk_status ON public.solicitacoes
  FOR EACH ROW
  EXECUTE FUNCTION public.concluir_solicitacao_geografica_vinculada();

-- Acerta o que já estiver concluído/cancelado.
UPDATE public.solicitacoes_geograficas sg
SET fk_status = 40
FROM public.solicitacoes s
WHERE s.fk_solicitacao_geografica = sg.id_solicitacao_geografica
  AND s.fk_status IN (6, 7)
  AND sg.fk_status <> 40;

-- 5) Cliente cancela --------------------------------------------------------------
-- Antes do aceite → 43. Depois do aceite e antes de pagar → a solicitação
-- vai para 7 (Cancelado) e o trigger acima deixa a geográfica em 40.
-- Depois de pago o cancelamento segue pelo fluxo normal (chat/suporte).
CREATE OR REPLACE FUNCTION public.cancelar_solicitacao_geografica(
  p_id_solicitacao_geografica bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usuario bigint := public.meu_id_usuario();
  v_geo     public.solicitacoes_geograficas%ROWTYPE;
  v_sol     public.solicitacoes%ROWTYPE;
BEGIN
  SELECT * INTO v_geo
  FROM public.solicitacoes_geograficas
  WHERE id_solicitacao_geografica = p_id_solicitacao_geografica
  FOR UPDATE;

  IF NOT FOUND OR v_geo.fk_usuario IS DISTINCT FROM v_usuario THEN
    RAISE EXCEPTION 'Solicitação não encontrada.';
  END IF;

  IF v_geo.fk_status IN (39, 41) THEN
    UPDATE public.solicitacoes_geograficas SET fk_status = 43
    WHERE id_solicitacao_geografica = v_geo.id_solicitacao_geografica;
    RETURN;
  END IF;

  IF v_geo.fk_status = 42 THEN
    SELECT * INTO v_sol FROM public.solicitacoes
    WHERE fk_solicitacao_geografica = v_geo.id_solicitacao_geografica
    FOR UPDATE;

    IF NOT FOUND THEN
      UPDATE public.solicitacoes_geograficas SET fk_status = 43
      WHERE id_solicitacao_geografica = v_geo.id_solicitacao_geografica;
      RETURN;
    END IF;
    IF v_sol.fk_status NOT IN (1, 2) THEN
      RAISE EXCEPTION 'O pagamento já foi feito. Para cancelar, fale com o profissional pelo chat.';
    END IF;

    UPDATE public.solicitacoes SET fk_status = 7
    WHERE id_solicitacao = v_sol.id_solicitacao;  -- trigger → geográfica 40
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancelar_solicitacao_geografica(bigint) TO authenticated;

-- 6) Radar do profissional: só as que ainda não foram aceitas -------------------
DROP FUNCTION IF EXISTS public.solicitacoes_geograficas_proximas(double precision, double precision);

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
  WHERE sg.fk_status IN (39, 41)
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

-- 7a) O que o profissional aceitou (ainda não concluído) -------------------------
CREATE OR REPLACE FUNCTION public.solicitacoes_geograficas_aceitas(
  p_conta_empresa boolean DEFAULT false
)
RETURNS TABLE (
  id_solicitacao_geografica bigint,
  titulo            text,
  descricao         text,
  img_solicitacao   text[],
  funcao            text,
  cor               text,
  metodo_entrega    text,
  latitude          double precision,
  longitude         double precision,
  data_criacao      timestamptz,
  id_solicitacao    bigint,
  fk_status         bigint,
  status            text,
  etapa_solicitacao integer,
  valor_final       numeric,
  data_aceite       timestamptz,
  nome_cliente      text,
  foto_cliente      text,
  endereco_cliente  text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
SELECT sg.id_solicitacao_geografica,
       sg.titulo,
       sg.descricao,
       sg.img_solicitacao,
       f.funcao::text,
       o.cor::text,
       sg.metodo_entrega,
       sg.latitude,
       sg.longitude,
       sg.data_criacao,
       s.id_solicitacao,
       s.fk_status,
       st.status::text,
       s.etapa_solicitacao,
       s.valor_final,
       s.data_aceite,
       u.nome::text,
       NULLIF(NULLIF(u.foto_perfil_url::text, ''), 'null'),
       (
         SELECT NULLIF(concat_ws(' - ',
                  NULLIF(concat_ws(', ', NULLIF(e.logradouro::text, ''), NULLIF(e.numero::text, '')), ''),
                  NULLIF(concat_ws(', ', NULLIF(e.bairro::text, ''), NULLIF(es.sigla_estado::text, '')), '')), '')
         FROM public.enderecos e
         LEFT JOIN public.cidades ci ON ci.id_cidade = e.fk_cidade
         LEFT JOIN public.estados es ON es.id_estado = ci.fk_estado
         WHERE e.id_endereco = s.fk_endereco
       )
FROM public.solicitacoes s
JOIN public.solicitacoes_geograficas sg
  ON sg.id_solicitacao_geografica = s.fk_solicitacao_geografica
JOIN public.funcoes f ON f.id_funcao = sg.fk_funcao
LEFT JOIN public.oficios o ON o.id_oficio = sg.fk_oficio
LEFT JOIN public.status st ON st.id_status = s.fk_status
JOIN public.usuarios u ON u.id_usuario = sg.fk_usuario
WHERE sg.fk_status = 42
  AND s.fk_status NOT IN (6, 7)
  AND public.profissional_pode_acessar_solicitacao(s.fk_profissional, s.fk_grupo_empresa)
  AND (s.fk_grupo_empresa IS NOT NULL) = coalesce(p_conta_empresa, false)
ORDER BY s.data_aceite DESC NULLS LAST;
$$;

GRANT EXECUTE ON FUNCTION public.solicitacoes_geograficas_aceitas(boolean) TO authenticated;

-- 7b) O que o cliente acompanha depois do aceite ---------------------------------
CREATE OR REPLACE FUNCTION public.acompanhamento_solicitacao_geografica(
  p_id_solicitacao_geografica bigint
)
RETURNS TABLE (
  id_solicitacao    bigint,
  fk_status         bigint,
  status            text,
  etapa_solicitacao integer,
  valor_final       numeric,
  tipo_execucao     text,
  eh_empresa        boolean,
  id_profissional   bigint,
  id_grupo_empresa  bigint,
  nome              text,
  foto_url          text,
  tag_empresa       text,
  cor_tag_empresa   text,
  nota              numeric,
  total_avaliacoes  bigint,
  latitude          double precision,
  longitude         double precision
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH base AS (
  SELECT s.*
  FROM public.solicitacoes s
  JOIN public.solicitacoes_geograficas sg
    ON sg.id_solicitacao_geografica = s.fk_solicitacao_geografica
  WHERE sg.id_solicitacao_geografica = p_id_solicitacao_geografica
    AND sg.fk_usuario = public.meu_id_usuario()
  LIMIT 1
),
aval AS (
  SELECT round(avg(av.nota)::numeric, 1) AS nota, count(*) AS total
  FROM public.avaliacoes_solicitacao av
  JOIN public.solicitacoes s2 ON s2.id_solicitacao = av.fk_solicitacao
  JOIN base b ON (b.fk_grupo_empresa IS NOT NULL AND s2.fk_grupo_empresa = b.fk_grupo_empresa)
              OR (b.fk_grupo_empresa IS NULL AND s2.fk_profissional = b.fk_profissional)
  WHERE av.tipo_avaliacao::text = 'profissional'
)
SELECT b.id_solicitacao,
       b.fk_status,
       st.status::text,
       b.etapa_solicitacao,
       b.valor_final,
       b.tipo_execucao,
       (b.fk_grupo_empresa IS NOT NULL),
       b.fk_profissional,
       b.fk_grupo_empresa,
       CASE WHEN b.fk_grupo_empresa IS NOT NULL THEN g.nome_empresa::text ELSE u.nome::text END,
       CASE WHEN b.fk_grupo_empresa IS NOT NULL THEN NULLIF(g.foto_url_empresa::text, '')
            ELSE NULLIF(NULLIF(u.foto_perfil_url::text, ''), 'null') END,
       NULLIF(g.tag_empresa::text, ''),
       NULLIF(g.cor_tag_empresa::text, ''),
       (SELECT nota FROM aval),
       (SELECT total FROM aval),
       NULLIF(loc.latitude::text, '')::double precision,
       NULLIF(loc.longitude::text, '')::double precision
FROM base b
LEFT JOIN public.status st ON st.id_status = b.fk_status
LEFT JOIN public.dados_profissionais dp ON dp.id_profissional = b.fk_profissional
LEFT JOIN public.usuarios u ON u.id_usuario = dp.fk_usuario
LEFT JOIN public.grupo_empresa g ON g.id_grupo_empresa = b.fk_grupo_empresa
LEFT JOIN LATERAL (
  -- Endereço de quem aceitou: empresa → endereço da empresa;
  -- independente → comercial, depois o ativo do usuário.
  SELECT en.latitude, en.longitude FROM (
    SELECT age.fk_endereco, 0 AS ordem, age.endereco_ativo
    FROM public.ass_grupo_empresa_endereco age
    WHERE b.fk_grupo_empresa IS NOT NULL AND age.fk_grupo_empresa = b.fk_grupo_empresa
    UNION ALL
    SELECT ape.fk_endereco, 1, ape.endereco_ativo
    FROM public.ass_profissional_endereco ape
    WHERE b.fk_grupo_empresa IS NULL AND ape.fk_profissional = b.fk_profissional
    UNION ALL
    SELECT aue.fk_endereco, 2, aue.endereco_ativo
    FROM public.ass_usuario_endereco aue
    WHERE b.fk_grupo_empresa IS NULL AND aue.fk_usuario = dp.fk_usuario
      AND aue.endereco_ativo = true
  ) v
  JOIN public.enderecos en ON en.id_endereco = v.fk_endereco
  WHERE en.latitude IS NOT NULL AND en.longitude IS NOT NULL
  ORDER BY v.ordem, v.endereco_ativo DESC
  LIMIT 1
) loc ON true;
$$;

GRANT EXECUTE ON FUNCTION public.acompanhamento_solicitacao_geografica(bigint) TO authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
