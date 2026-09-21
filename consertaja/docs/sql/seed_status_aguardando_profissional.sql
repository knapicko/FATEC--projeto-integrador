-- ============================================================================
-- ConsertaJa — Garante o status "Aguardando Profissional" (Tipo "Serviço")
-- Rode no SQL Editor do Supabase.
-- 1) Lista os status do Tipo "Serviço" já existentes (rode separado p/ ver)
-- 2) Insere "Aguardando Profissional" se ainda não existir
-- ============================================================================

-- 1) Ver o que já existe:
-- SELECT id_status, tipo_status::text AS tipo, status
--   FROM public.status
--  WHERE tipo_status::text = 'Serviço'
--  ORDER BY id_status;

-- 2) Inserir o status inicial do fluxo de solicitação (idempotente):
INSERT INTO public.status (tipo_status, status)
SELECT 'Serviço'::"Tipo Status", 'Aguardando Profissional'
WHERE NOT EXISTS (
  SELECT 1 FROM public.status
  WHERE tipo_status::text = 'Serviço'
    AND status = 'Aguardando Profissional'
);
