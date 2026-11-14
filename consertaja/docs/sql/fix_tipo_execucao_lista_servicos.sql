-- ============================================================================
-- ConsertaJá — Corrige "violates check constraint solicitacoes_tipo_execucao_check"
-- ao finalizar a Lista de Serviços.
--
-- Causa: ass_servicos_lista.tipo_execucao_escolhido tinha valores fora do
-- padrão (ex.: " Retirado no Local" com espaço na frente, "Retirada no Local"
-- ou "Retirada"), que eram copiados para solicitacoes.tipo_execucao.
--
-- Rode inteiro no SQL Editor do Supabase.
-- ============================================================================

-- 1) Função que converte qualquer variação para o texto canônico.
CREATE OR REPLACE FUNCTION public.normalizar_tipo_execucao(p_valor text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v text := lower(trim(coalesce(p_valor, '')));
BEGIN
  IF v = '' THEN
    RETURN NULL;
  ELSIF v LIKE '%leva%traz%' THEN
    RETURN 'Leva e Traz';
  ELSIF v LIKE '%retirad%' THEN
    RETURN 'Retirado no Local';
  ELSIF v LIKE '%receba%' THEN
    RETURN 'Receba em Casa';
  ELSIF v LIKE '%domic%' OR v LIKE '%presencial%' THEN
    RETURN 'Atendimento em Domicílio';
  ELSIF v IN ('entrega') THEN
    RETURN 'Entrega';
  ELSIF v IN ('execução', 'execucao') THEN
    RETURN 'Execução';
  END IF;
  RETURN trim(p_valor);
END;
$$;

-- 2) Corrige os itens que já estão nas listas dos clientes.
UPDATE public.ass_servicos_lista
SET tipo_execucao_escolhido = public.normalizar_tipo_execucao(tipo_execucao_escolhido)
WHERE tipo_execucao_escolhido IS DISTINCT FROM
      public.normalizar_tipo_execucao(tipo_execucao_escolhido)
  AND public.normalizar_tipo_execucao(tipo_execucao_escolhido) IS NOT NULL;

-- 3) Corrige solicitações antigas (se houver alguma fora do padrão).
UPDATE public.solicitacoes
SET tipo_execucao = public.normalizar_tipo_execucao(tipo_execucao)
WHERE tipo_execucao IS DISTINCT FROM public.normalizar_tipo_execucao(tipo_execucao);

-- 4) Garante que a constraint é a versão nova (aceita os 4 métodos).
ALTER TABLE public.solicitacoes
  DROP CONSTRAINT IF EXISTS solicitacoes_tipo_execucao_check;

ALTER TABLE public.solicitacoes
  ADD CONSTRAINT solicitacoes_tipo_execucao_check
  CHECK (
    tipo_execucao IS NULL
    OR tipo_execucao IN ('Entrega', 'Execução')
    OR tipo_execucao ~ '^(Leva e Traz|Retirado no Local|Receba em Casa|Atendimento em Domicílio)(, (Leva e Traz|Retirado no Local|Receba em Casa|Atendimento em Domicílio))*$'
  );

-- 5) Rede de segurança: normaliza automaticamente antes de gravar.
CREATE OR REPLACE FUNCTION public.trg_normalizar_tipo_execucao_solicitacao()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.tipo_execucao IS NOT NULL
     AND NEW.tipo_execucao NOT LIKE '%,%' THEN
    NEW.tipo_execucao := public.normalizar_tipo_execucao(NEW.tipo_execucao);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS normalizar_tipo_execucao_solicitacao ON public.solicitacoes;
CREATE TRIGGER normalizar_tipo_execucao_solicitacao
BEFORE INSERT OR UPDATE OF tipo_execucao ON public.solicitacoes
FOR EACH ROW
EXECUTE FUNCTION public.trg_normalizar_tipo_execucao_solicitacao();

CREATE OR REPLACE FUNCTION public.trg_normalizar_tipo_execucao_lista()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.tipo_execucao_escolhido IS NOT NULL THEN
    NEW.tipo_execucao_escolhido :=
      coalesce(public.normalizar_tipo_execucao(NEW.tipo_execucao_escolhido),
               NEW.tipo_execucao_escolhido);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS normalizar_tipo_execucao_lista ON public.ass_servicos_lista;
CREATE TRIGGER normalizar_tipo_execucao_lista
BEFORE INSERT OR UPDATE OF tipo_execucao_escolhido ON public.ass_servicos_lista
FOR EACH ROW
EXECUTE FUNCTION public.trg_normalizar_tipo_execucao_lista();
