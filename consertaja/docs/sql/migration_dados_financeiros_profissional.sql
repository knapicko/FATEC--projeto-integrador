-- =====================================================================
-- Migration: Formas de Pagamento e Chave Pix do Profissional
-- Tabela: public.dados_profissionais
-- =====================================================================

-- 1) Coluna com os tipos de pagamento aceitos separados por vírgula (NOT NULL com default 'Pix')
ALTER TABLE public.dados_profissionais
  ADD COLUMN IF NOT EXISTS pagamento_aceito text NOT NULL DEFAULT 'Pix';

-- 2) Coluna para armazenar a chave PIX selecionada/cadastrada pelo profissional (NULL)
ALTER TABLE public.dados_profissionais
  ADD COLUMN IF NOT EXISTS chave_pix text;

-- 3) Coluna para armazenar as condições de parcelamento de cartão de crédito (NULL)
ALTER TABLE public.dados_profissionais
  ADD COLUMN IF NOT EXISTS condicoes_parcela text;

-- 4) As mesmas configurações para a conta empresarial ativa.
ALTER TABLE public.grupo_empresa
  ADD COLUMN IF NOT EXISTS pagamento_aceito text NOT NULL DEFAULT 'Pix';

ALTER TABLE public.grupo_empresa
  ADD COLUMN IF NOT EXISTS chave_pix text;

ALTER TABLE public.grupo_empresa
  ADD COLUMN IF NOT EXISTS condicoes_parcela text;
