-- As Edge Functions de pagamento (criar-pagamento-stripe,
-- consultar-pagamento-stripe e stripe-webhook) usam a service_role.
-- Sem estes GRANTs o Postgres responde "permission denied for table ...".

GRANT USAGE ON SCHEMA public TO service_role;

GRANT SELECT, UPDATE ON public.solicitacoes TO service_role;
GRANT SELECT ON public.usuarios TO service_role;
GRANT SELECT ON public.servicos_profissional TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.pagamentos_stripe TO service_role;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;
