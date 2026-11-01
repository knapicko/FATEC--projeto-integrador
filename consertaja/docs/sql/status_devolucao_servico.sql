-- Status usados no fluxo de devolução do produto após a manutenção.
INSERT INTO public.status (id_status, tipo_status, status)
VALUES
  (35, 'Serviço', 'Aguardando Devolução'),
  (36, 'Serviço', 'Devolução Deslocando'),
  (37, 'Serviço', 'Devolução Chegou')
ON CONFLICT (id_status) DO UPDATE
SET tipo_status = EXCLUDED.tipo_status,
    status = EXCLUDED.status;
