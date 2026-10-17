-- Execute no SQL Editor do Supabase.
-- Insere os status usados pelo fluxo de solicitações de profissionais.

INSERT INTO public.status (tipo_status, status)
SELECT 'Serviço'::"Tipo Status", 'Recusado'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.status
  WHERE tipo_status::text = 'Serviço'
    AND status = 'Recusado'
);

INSERT INTO public.status (tipo_status, status)
SELECT 'Serviço'::"Tipo Status", 'Aceito'
WHERE NOT EXISTS (
  SELECT 1
  FROM public.status
  WHERE tipo_status::text = 'Serviço'
    AND status = 'Aceito'
);

