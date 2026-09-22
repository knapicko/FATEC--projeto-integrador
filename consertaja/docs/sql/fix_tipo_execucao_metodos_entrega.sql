-- Execute este script no SQL Editor do Supabase.
-- Corrige a constraint antiga que aceitava apenas Entrega/Execucao.

ALTER TABLE public.servicos_profissional
  DROP CONSTRAINT IF EXISTS servicos_profissional_tipo_execucao_check;

ALTER TABLE public.servicos_profissional
  ADD CONSTRAINT servicos_profissional_tipo_execucao_check
  CHECK (
    tipo_execucao IN ('Entrega', 'Execução')
    OR tipo_execucao ~ '^(Leva e Traz|Retirado no Local|Receba em Casa|Atendimento em Domicílio)(, (Leva e Traz|Retirado no Local|Receba em Casa|Atendimento em Domicílio))*$'
  );

ALTER TABLE public.solicitacoes
  DROP CONSTRAINT IF EXISTS solicitacoes_tipo_execucao_check;

ALTER TABLE public.solicitacoes
  ADD CONSTRAINT solicitacoes_tipo_execucao_check
  CHECK (
    tipo_execucao IS NULL
    OR tipo_execucao IN ('Entrega', 'Execução')
    OR tipo_execucao ~ '^(Leva e Traz|Retirado no Local|Receba em Casa|Atendimento em Domicílio)(, (Leva e Traz|Retirado no Local|Receba em Casa|Atendimento em Domicílio))*$'
  );
