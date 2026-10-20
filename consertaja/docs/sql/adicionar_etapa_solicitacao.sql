-- ============================================================================
-- ConsertaJa — Adiciona coluna 'etapa_solicitacao' na tabela 'solicitacoes'
-- Execute no SQL Editor do Supabase.
-- ============================================================================

ALTER TABLE public.solicitacoes
ADD COLUMN IF NOT EXISTS etapa_solicitacao INT4 NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.solicitacoes.etapa_solicitacao IS 'Controle sequencial da etapa atual da solicitação (inicia em 0: Solicitado, e avança conforme o fluxo da modalidade)';
