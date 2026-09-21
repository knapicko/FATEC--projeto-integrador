-- ============================================================================
-- ConsertaJa — LIMPAR tabela solicitacoes (ambiente de dev/teste)
-- ATENÇÃO: apaga TODOS os registros de solicitacoes. Operação irreversível.
-- Tabelas dependentes (ex.: solicitacoes_anexos com ON DELETE CASCADE)
-- têm seus vínculos removidos automaticamente pelo CASCADE.
-- ============================================================================

-- 1) Confere quantos registros existem antes de apagar (rode separado p/ ver)
-- SELECT COUNT(*) AS total_solicitacoes FROM public.solicitacoes;

-- 2) Apaga tudo e reinicia o identity (próximo id volta a 1)
TRUNCATE TABLE public.solicitacoes RESTART IDENTITY CASCADE;

-- 3) Confere que ficou vazia (rode separado p/ ver)
-- SELECT COUNT(*) AS total_solicitacoes FROM public.solicitacoes;
