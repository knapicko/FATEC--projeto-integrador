-- ============================================================================
-- ConsertaJá — ajustes v0.6 (rode tudo de uma vez no SQL Editor do Supabase)
-- ============================================================================
--  1. Cor dos ofícios: só o hex (cod_cor). A coluna "cor" deixa de ser enum e
--     passa a guardar o mesmo hex (as consultas antigas continuam lendo "cor").
--  2. Funções com o nome do serviço (Marceneiro -> Marcenaria...).
--  3. Ofícios novos ("Relojoaria e joias", "Eletrodomésticos e eletrônicos")
--     e funções novas de serviços tradicionais.
--  4. Serviços favoritados pelo cliente.
--  5. Pagamento retido até a conclusão (colunas de controle).
--  6. Notificações sem emoji; "Pago" avisado uma vez só.
-- ============================================================================

BEGIN;

-- 1) CORES ---------------------------------------------------------------------
-- Cores vivas, a partir do nome que estava no enum "cor".
ALTER TABLE public.oficios ALTER COLUMN cor DROP DEFAULT;
ALTER TABLE public.oficios ALTER COLUMN cor TYPE text USING cor::text;

UPDATE public.oficios SET cod_cor = '#E53935' WHERE id_oficio = 1;  -- Vermelho    · Reparos domésticos
UPDATE public.oficios SET cod_cor = '#8D5524' WHERE id_oficio = 5;  -- Marrom      · Móveis e interiores
UPDATE public.oficios SET cod_cor = '#1E3A8A' WHERE id_oficio = 8;  -- Azul escuro · Segurança
UPDATE public.oficios SET cod_cor = '#8E1B3A' WHERE id_oficio = 10; -- Vinho       · Vidros e estruturas
UPDATE public.oficios SET cod_cor = '#2E9E4F' WHERE id_oficio = 12; -- Verde       · Reparos pessoais
UPDATE public.oficios SET cod_cor = '#29B6F6' WHERE id_oficio = 14; -- Azul claro  · Limpeza especializada
UPDATE public.oficios SET cod_cor = '#64748B' WHERE id_oficio = 16; -- Cinza       · Serviços tradicionais

-- 3a) OFÍCIOS NOVOS (cada um com pelo menos 2 funções) ----------------------------
INSERT INTO public.oficios (categoria, cor, cod_cor)
SELECT 'Relojoaria e joias', '#7C3AED', '#7C3AED'
WHERE NOT EXISTS (SELECT 1 FROM public.oficios WHERE categoria = 'Relojoaria e joias');

INSERT INTO public.oficios (categoria, cor, cod_cor)
SELECT 'Eletrodomésticos e eletrônicos', '#F97316', '#F97316'
WHERE NOT EXISTS (SELECT 1 FROM public.oficios WHERE categoria = 'Eletrodomésticos e eletrônicos');

-- "cor" = mesmo hex de cod_cor em todos.
UPDATE public.oficios SET cor = cod_cor WHERE cod_cor IS NOT NULL;

-- 2) FUNÇÕES COM O NOME DO SERVIÇO ---------------------------------------------
UPDATE public.funcoes SET funcao = 'Encanamento'             WHERE id_funcao = 1;
UPDATE public.funcoes SET funcao = 'Elétrica'                WHERE id_funcao = 2;
UPDATE public.funcoes SET funcao = 'Desentupimento'          WHERE id_funcao = 3;
UPDATE public.funcoes SET funcao = 'Reparos gerais'          WHERE id_funcao = 4;
UPDATE public.funcoes SET funcao = 'Montagem de móveis'      WHERE id_funcao = 5;
UPDATE public.funcoes SET funcao = 'Marcenaria'              WHERE id_funcao = 6;
UPDATE public.funcoes SET funcao = 'Tapeçaria'               WHERE id_funcao = 7;
UPDATE public.funcoes SET funcao = 'Chaves e aberturas'      WHERE id_funcao = 8;
UPDATE public.funcoes SET funcao = 'Instalação de fechaduras' WHERE id_funcao = 9;
UPDATE public.funcoes SET funcao = 'Vidraçaria'              WHERE id_funcao = 10;
UPDATE public.funcoes SET funcao = 'Serralheria'             WHERE id_funcao = 11;
UPDATE public.funcoes SET funcao = 'Sapataria'               WHERE id_funcao = 12;
UPDATE public.funcoes SET funcao = 'Costura'                 WHERE id_funcao = 13;
UPDATE public.funcoes SET funcao = 'Lavagem de tapetes'      WHERE id_funcao = 14;
UPDATE public.funcoes SET funcao = 'Higienização de colchões' WHERE id_funcao = 15;
UPDATE public.funcoes SET funcao = 'Conserto de panelas'     WHERE id_funcao = 16;
UPDATE public.funcoes SET funcao = 'Afiação'                 WHERE id_funcao = 17;
UPDATE public.funcoes SET funcao = 'Solda de utensílios'     WHERE id_funcao = 18;
UPDATE public.funcoes SET funcao = 'Funilaria'               WHERE id_funcao = 19;

-- 3b) FUNÇÕES NOVAS -------------------------------------------------------------
INSERT INTO public.funcoes (fk_oficio, funcao, descricao)
SELECT o.id_oficio, v.funcao, v.descricao
FROM (VALUES
  -- Reparos pessoais
  ('Reparos pessoais', 'Alfaiataria', 'Roupas sob medida e ajustes finos em ternos, vestidos e uniformes.'),
  ('Reparos pessoais', 'Bordado', 'Bordados à mão e à máquina, monogramas, nomes e patches.'),
  ('Reparos pessoais', 'Conserto de bolsas e malas', 'Troca de zíperes, alças, rodinhas e costuras de bolsas, mochilas e malas.'),
  ('Reparos pessoais', 'Selaria e couro', 'Conserto e confecção de peças de couro: cintos, selas, capas e acessórios.'),
  -- Serviços tradicionais
  ('Serviços tradicionais', 'Empalhação', 'Troca e restauração de palhinha e assento trançado de cadeiras.'),
  ('Serviços tradicionais', 'Encadernação', 'Encadernação, capas e restauração de livros, cadernos e documentos.'),
  ('Serviços tradicionais', 'Ferraria', 'Forja e conserto de ferramentas, ferragens e peças de ferro.'),
  ('Serviços tradicionais', 'Conserto de guarda-chuvas', 'Troca de varetas, cabos e tecido de guarda-chuvas e sombrinhas.'),
  -- Relojoaria e joias
  ('Relojoaria e joias', 'Relojoaria', 'Troca de bateria, pulseira e vidro e conserto de relógios de pulso e de parede.'),
  ('Relojoaria e joias', 'Ourivesaria', 'Conserto de joias: solda de correntes, ajuste de anéis, banho e polimento.'),
  -- Eletrodomésticos e eletrônicos
  ('Eletrodomésticos e eletrônicos', 'Conserto de eletrodomésticos', 'Geladeira, máquina de lavar, micro-ondas, fogão, liquidificador e ventilador.'),
  ('Eletrodomésticos e eletrônicos', 'Conserto de eletrônicos', 'TV, aparelho de som, rádio, videogame e pequenos eletrônicos.'),
  ('Eletrodomésticos e eletrônicos', 'Conserto de máquinas de costura', 'Regulagem, limpeza e troca de peças de máquinas de costura.')
) AS v(categoria, funcao, descricao)
JOIN public.oficios o ON o.categoria = v.categoria
WHERE NOT EXISTS (SELECT 1 FROM public.funcoes f WHERE f.funcao = v.funcao);

-- 4) SERVIÇOS FAVORITADOS ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.servicos_favoritos (
  id_favorito bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fk_usuario bigint NOT NULL REFERENCES public.usuarios (id_usuario) ON DELETE CASCADE,
  fk_servico_prof bigint NOT NULL REFERENCES public.servicos_profissional (id_servico_prof) ON DELETE CASCADE,
  data_criacao timestamptz NOT NULL DEFAULT now(),
  UNIQUE (fk_usuario, fk_servico_prof)
);
ALTER TABLE public.servicos_favoritos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS favoritos_proprios ON public.servicos_favoritos;
CREATE POLICY favoritos_proprios ON public.servicos_favoritos
  FOR ALL TO authenticated
  USING (fk_usuario IN (SELECT id_usuario FROM public.usuarios WHERE auth_id = auth.uid()))
  WITH CHECK (fk_usuario IN (SELECT id_usuario FROM public.usuarios WHERE auth_id = auth.uid()));

-- 5) PAGAMENTO RETIDO ATÉ A CONCLUSÃO ------------------------------------------
-- O pagamento é autorizado (retido no Stripe) ao pagar e só é capturado/
-- liberado ao profissional quando cliente E profissional concluem.
ALTER TABLE public.solicitacoes
  ADD COLUMN IF NOT EXISTS pagamento_liberado boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS data_pagamento_liberado timestamptz,
  -- Já avisou "Pago" uma vez: voltar etapa para "Pago" não avisa de novo.
  ADD COLUMN IF NOT EXISTS aviso_pago_enviado boolean NOT NULL DEFAULT false;
-- Pedidos que já passaram do pagamento já tiveram o aviso.
UPDATE public.solicitacoes SET aviso_pago_enviado = true
WHERE fk_status NOT IN (1, 2, 7, 30, 31);
UPDATE public.solicitacoes SET pagamento_liberado = true,
       data_pagamento_liberado = coalesce(data_pagamento_liberado, now())
WHERE fk_status = 6;

-- 6) NOTIFICAÇÕES -------------------------------------------------------------
-- Sem emojis nos textos; "Pago" avisado uma vez só; pagamento retido/liberado.
CREATE OR REPLACE FUNCTION public.trg_notif_solicitacao_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status   text;
  v_tipo     text;
  v_servico  text;
  v_cliente  record;
  v_prof_nome text;
  v_prof_foto text;
  v_titulo   text;
  v_texto    text;
  v_dest     bigint;
  v_minuto   text := to_char(date_trunc('minute', now()), 'YYYYMMDDHH24MI');
  v_retirada boolean := lower(coalesce(NEW.tipo_execucao, '')) LIKE '%retirad%';
BEGIN
  IF NEW.fk_status IS NOT DISTINCT FROM OLD.fk_status THEN
    RETURN NEW;
  END IF;
  -- "Pago" só é avisado uma vez: quando o profissional volta uma etapa para
  -- "Pago", ninguém recebe de novo (parecia que tinha pago duas vezes).
  IF NEW.fk_status = 3 AND coalesce(NEW.aviso_pago_enviado, false) THEN
    RETURN NEW;
  END IF;

  SELECT s.status::text, s.tipo_status::text INTO v_status, v_tipo
  FROM public.status s WHERE s.id_status = NEW.fk_status;
  IF v_tipo IS DISTINCT FROM 'Serviço' THEN
    RETURN NEW;
  END IF;

  v_servico := public.notif_titulo_servico(NEW.id_solicitacao);

  SELECT u.nome, NULLIF(NULLIF(u.foto_perfil_url, ''), 'null') AS foto
    INTO v_cliente
  FROM public.usuarios u WHERE u.id_usuario = NEW.fk_usuario;

  IF NEW.fk_grupo_empresa IS NOT NULL THEN
    SELECT g.nome_empresa, NULLIF(g.foto_url_empresa, '')
      INTO v_prof_nome, v_prof_foto
    FROM public.grupo_empresa g WHERE g.id_grupo_empresa = NEW.fk_grupo_empresa;
  ELSE
    SELECT u.nome, NULLIF(NULLIF(u.foto_perfil_url, ''), 'null')
      INTO v_prof_nome, v_prof_foto
    FROM public.dados_profissionais dp
    JOIN public.usuarios u ON u.id_usuario = dp.fk_usuario
    WHERE dp.id_profissional = NEW.fk_profissional;
  END IF;

  -- Cliente: toda mudança.
  v_titulo := CASE NEW.fk_status
    WHEN 1  THEN 'Pedido enviado'
    WHEN 2  THEN 'Pedido aceito! Falta o pagamento'
    WHEN 3  THEN 'Pagamento confirmado'
    WHEN 4  THEN 'Serviço em andamento'
    WHEN 5  THEN 'O profissional está aguardando você'
    WHEN 6  THEN 'Serviço concluído'
    WHEN 7  THEN 'Pedido cancelado'
    WHEN 30 THEN 'Pedido recusado'
    WHEN 31 THEN 'Pedido aceito'
    WHEN 32 THEN 'Aguardando o deslocamento'
    WHEN 33 THEN 'O profissional está a caminho'
    WHEN 34 THEN 'O profissional chegou'
    WHEN 35 THEN CASE WHEN v_retirada THEN 'Pronto para retirada'
                      ELSE 'Serviço pronto, aguardando devolução' END
    WHEN 36 THEN 'Seu item está a caminho'
    WHEN 37 THEN 'A devolução chegou'
    WHEN 38 THEN 'Você está a caminho'
    ELSE coalesce(v_status, 'Pedido atualizado')
  END;
  v_texto := CASE NEW.fk_status
    WHEN 3 THEN v_servico || ': pagamento confirmado. O valor fica retido com segurança e só é liberado para '
                || coalesce(v_prof_nome, 'o profissional') || ' quando o serviço for concluído.'
    ELSE concat_ws(' • ', v_servico, coalesce(v_prof_nome, 'Profissional'),
                   'Status: ' || coalesce(v_status, '—'))
  END;

  PERFORM public.criar_notificacao(
    NEW.fk_usuario, 'Solicitação', v_titulo, v_texto,
    'detalhes_pedido', v_prof_foto,
    NEW.id_solicitacao, NULL, NULL, NEW.fk_status,
    jsonb_build_object(
      'id_solicitacao', NEW.id_solicitacao,
      'papel', 'cliente',
      'evento', 'status',
      'status', v_status,
      'servico', v_servico),
    format('sol_status:%s:%s>%s:%s:%s', NEW.id_solicitacao, OLD.fk_status,
           NEW.fk_status, NEW.fk_usuario, v_minuto));

  -- Profissional: Pago (3), Aguardando Cliente (5), Concluído (6, pagamento
  -- liberado) e Cliente Deslocando (38).
  IF NEW.fk_status IN (3, 5, 6, 38) THEN
    v_titulo := CASE NEW.fk_status
      WHEN 3  THEN 'Pagamento garantido'
      WHEN 5  THEN coalesce(v_cliente.nome, 'O cliente') || ' está aguardando você'
      WHEN 6  THEN 'Serviço concluído: pagamento liberado'
      WHEN 38 THEN coalesce(v_cliente.nome, 'O cliente') || ' está a caminho'
    END;
    v_texto := CASE NEW.fk_status
      WHEN 3 THEN coalesce(v_cliente.nome, 'O cliente') || ' pagou ' || v_servico ||
                  coalesce(' (' || public.notif_formatar_reais(NEW.valor_final) || ')', '') ||
                  '. O valor fica retido e é liberado para você quando o serviço for concluído. Já pode começar!'
      WHEN 6 THEN v_servico ||
                  coalesce(' (' || public.notif_formatar_reais(NEW.valor_final) || ')', '') ||
                  ' foi concluído pelos dois lados e o valor foi liberado para você.'
      ELSE concat_ws(' • ', v_servico, 'Status: ' || v_status)
    END;

    FOR v_dest IN
      SELECT x.fk_usuario
      FROM public.notif_usuarios_profissionais(NEW.fk_profissional, NEW.fk_grupo_empresa) x
      WHERE x.fk_usuario IS DISTINCT FROM NEW.fk_usuario
    LOOP
      PERFORM public.criar_notificacao(
        v_dest, 'Solicitação', v_titulo, v_texto,
        'solicitacao_estado', v_cliente.foto,
        NEW.id_solicitacao, NULL, NULL, NEW.fk_status,
        jsonb_build_object(
          'id_solicitacao', NEW.id_solicitacao,
          'papel', 'profissional',
          'evento', 'status',
          'status', v_status,
          'nome_cliente', v_cliente.nome,
          'servico', v_servico),
        format('sol_status:%s:%s>%s:%s:%s', NEW.id_solicitacao, OLD.fk_status,
               NEW.fk_status, v_dest, v_minuto));
    END LOOP;
  END IF;

  IF NEW.fk_status = 3 THEN
    -- Não muda fk_status: este UPDATE não dispara o trigger de novo.
    UPDATE public.solicitacoes SET aviso_pago_enviado = true
    WHERE id_solicitacao = NEW.id_solicitacao;
  END IF;

  RETURN NEW;
EXCEPTION WHEN others THEN
  RAISE WARNING '[notificacoes] status solicitacao %: %', NEW.id_solicitacao, SQLERRM;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_notif_mensagem_nova()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_conv     public.conversas%ROWTYPE;
  v_nome     text;
  v_foto     text;
  v_previa   text;
  v_cliente_enviou boolean;
  v_dest     bigint;
  v_json     jsonb;
BEGIN
  SELECT * INTO v_conv FROM public.conversas WHERE id_conversa = NEW.fk_conversa;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  v_cliente_enviou := (NEW.fk_remitente_usuario = v_conv.fk_usuario);

  -- Quem enviou (a empresa aparece com o nome/foto dela).
  IF NOT v_cliente_enviou AND v_conv.fk_grupo_empresa IS NOT NULL THEN
    SELECT g.nome_empresa, NULLIF(g.foto_url_empresa, '') INTO v_nome, v_foto
    FROM public.grupo_empresa g WHERE g.id_grupo_empresa = v_conv.fk_grupo_empresa;
  END IF;
  IF v_nome IS NULL THEN
    SELECT u.nome, NULLIF(NULLIF(u.foto_perfil_url, ''), 'null') INTO v_nome, v_foto
    FROM public.usuarios u WHERE u.id_usuario = NEW.fk_remitente_usuario;
  END IF;

  -- Prévia do conteúdo.
  v_previa := coalesce(NEW.conteudo, '');
  IF v_previa LIKE '{%' THEN
    BEGIN
      v_json := v_previa::jsonb;
    EXCEPTION WHEN others THEN
      v_json := NULL;
    END;
  END IF;
  v_previa := CASE
    WHEN v_json ? 'titulo' AND lower(coalesce(v_json->>'tipo', '')) LIKE '%proposta%'
      THEN 'Enviou uma proposta: ' || (v_json->>'titulo')
    WHEN lower(NEW.tipo_mensagem) = 'proposta' THEN 'Enviou uma proposta'
    WHEN NEW.tipo_mensagem = 'Imagem'    THEN 'Imagem'
    WHEN NEW.tipo_mensagem = 'Audio'     THEN 'Mensagem de voz'
    WHEN NEW.tipo_mensagem = 'Documento' THEN 'Documento'
    WHEN char_length(v_previa) > 160 THEN left(v_previa, 157) || '...'
    ELSE v_previa
  END;
  IF coalesce(trim(v_previa), '') = '' THEN
    v_previa := 'Nova mensagem';
  END IF;

  FOR v_dest IN
    SELECT DISTINCT d FROM (
      SELECT v_conv.fk_usuario AS d WHERE NOT v_cliente_enviou
      UNION ALL
      SELECT x.fk_usuario
      FROM public.notif_usuarios_profissionais(v_conv.fk_profissional, v_conv.fk_grupo_empresa) x
      WHERE v_cliente_enviou
    ) t
    WHERE d IS NOT NULL AND d IS DISTINCT FROM NEW.fk_remitente_usuario
  LOOP
    PERFORM public.criar_notificacao(
      v_dest, 'Conversa', coalesce(v_nome, 'Nova mensagem'), v_previa,
      'conversa', v_foto,
      v_conv.fk_solicitacao, v_conv.id_conversa, NULL, NULL,
      jsonb_build_object(
        'id_conversa', v_conv.id_conversa,
        'id_mensagem', NEW.id_mensagem,
        'nome_remetente', v_nome,
        'foto_remetente', v_foto,
        'id_profissional', v_conv.fk_profissional,
        'id_grupo_empresa', v_conv.fk_grupo_empresa,
        'papel', CASE WHEN v_dest = v_conv.fk_usuario THEN 'cliente' ELSE 'profissional' END),
      format('msg:%s:%s', NEW.id_mensagem, v_dest));
  END LOOP;
  RETURN NEW;
EXCEPTION WHEN others THEN
  RAISE WARNING '[notificacoes] mensagem %: %', NEW.id_mensagem, SQLERRM;
  RETURN NEW;
END;
$$;

COMMIT;
