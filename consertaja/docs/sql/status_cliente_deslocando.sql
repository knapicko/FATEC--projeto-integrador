-- Status usado quando o cliente inicia o deslocamento até o profissional.
INSERT INTO public.status (id_status, tipo_status, status)
VALUES (38, 'Serviço', 'Cliente Deslocando')
ON CONFLICT (id_status) DO UPDATE
SET tipo_status = EXCLUDED.tipo_status,
    status = EXCLUDED.status;
