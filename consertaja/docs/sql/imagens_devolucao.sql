-- Armazena as fotos registradas pelo profissional no momento da devolução.
ALTER TABLE public.solicitacoes
ADD COLUMN IF NOT EXISTS imagens_devolucao text[];
