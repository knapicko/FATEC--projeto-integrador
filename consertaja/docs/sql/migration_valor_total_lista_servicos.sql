-- ==============================================================================
-- Migration: Adicionar 'valor_total' na tabela 'lista_servicos' e trigger automático
-- ==============================================================================

-- 1. Adiciona a coluna 'valor_total' na tabela 'lista_servicos'
ALTER TABLE public.lista_servicos
    ADD COLUMN IF NOT EXISTS valor_total numeric NOT NULL DEFAULT 0;

-- 2. Função para recalcular o valor_total da lista de serviços automaticamente
CREATE OR REPLACE FUNCTION public.atualizar_valor_total_lista_servicos()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id_lista bigint;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id_lista := OLD.fk_lista;
    ELSE
        v_id_lista := NEW.fk_lista;
    END IF;

    UPDATE public.lista_servicos
    SET valor_total = COALESCE(
        (SELECT SUM(valor_final) FROM public.ass_servicos_lista WHERE fk_lista = v_id_lista),
        0
    )
    WHERE id_lista = v_id_lista;

    RETURN NULL;
END;
$$;

-- 3. Criação do Trigger em 'ass_servicos_lista'
DROP TRIGGER IF EXISTS trg_atualizar_valor_total_lista_servicos ON public.ass_servicos_lista;

CREATE TRIGGER trg_atualizar_valor_total_lista_servicos
AFTER INSERT OR UPDATE OF valor_final, fk_lista OR DELETE
ON public.ass_servicos_lista
FOR EACH ROW
EXECUTE FUNCTION public.atualizar_valor_total_lista_servicos();

-- 4. Atualiza os valores totais existentes
UPDATE public.lista_servicos l
SET valor_total = COALESCE(
    (SELECT SUM(a.valor_final) FROM public.ass_servicos_lista a WHERE a.fk_lista = l.id_lista),
    0
);
