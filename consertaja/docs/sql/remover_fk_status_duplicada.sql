-- ============================================================================
-- ConsertaJa — Remove a FK duplicada solicitacoes -> status.
-- A tabela tem 2 constraints para a mesma relação:
--   1) solicitacao_fk_status_fkey (legada, sem "es" no nome)
--   2) solicitacoes_fk_status_fkey (criada pela migration_lista_servicos)
-- Isso quebra o embed do PostgREST (PGRST201: "more than one relationship").
-- O app usa `status!solicitacoes_fk_status_fkey(status)`, então removemos a
-- legada. Rode no SQL Editor do Supabase.
-- ============================================================================

ALTER TABLE public.solicitacoes
  DROP CONSTRAINT IF EXISTS solicitacao_fk_status_fkey;
