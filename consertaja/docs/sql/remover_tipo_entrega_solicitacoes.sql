-- ============================================================================
-- ConsertaJa — Remove `tipo_entrega` de `solicitacoes`.
-- O método escolhido pelo cliente ("Leva e Traz", "Retirado no Local",
-- "Receba em Casa", "Atendimento em Domicílio") vai SÓ em `tipo_execucao`.
-- Rode no SQL Editor do Supabase.
-- ============================================================================

-- 1) Remove o trigger que validava tipo_entrega (Domicilio/Retirada/Local).
DROP TRIGGER IF EXISTS validar_tipo_entrega_solicitacao_trigger
  ON public.solicitacoes;
DROP FUNCTION IF EXISTS public.validar_tipo_entrega_solicitacao();

-- 2) Remove a check constraint de tipo_entrega.
ALTER TABLE public.solicitacoes
  DROP CONSTRAINT IF EXISTS solicitacoes_tipo_entrega_check;

-- 3) Remove a coluna tipo_entrega.
ALTER TABLE public.solicitacoes
  DROP COLUMN IF EXISTS tipo_entrega;
