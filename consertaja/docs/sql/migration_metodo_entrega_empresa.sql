-- ======================================================================
-- ConsertaJa - Metodo de entrega da EMPRESA (grupo_empresa)
-- Rode UMA VEZ no SQL Editor do Supabase (idempotente).
-- Modelo:
--   Conta profissional (CNPJ): dados_profissionais.metodo_entrega
--   Conta empresa: grupo_empresa.metodo_entrega_empresa
--   Default (novo/NULL/vazio): 'Leva e Traz'
-- ======================================================================

ALTER TABLE public.grupo_empresa
  ADD COLUMN IF NOT EXISTS metodo_entrega_empresa text
    NOT NULL DEFAULT 'Leva e Traz';

-- Normaliza valores antigos: NULL ou vazio vira o default 'Leva e Traz'.
UPDATE public.grupo_empresa
SET metodo_entrega_empresa = 'Leva e Traz'
WHERE metodo_entrega_empresa IS NULL
   OR btrim(metodo_entrega_empresa) = '';

-- Garante o default tambem no lado do profissional (se a coluna existir).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'dados_profissionais'
      AND column_name = 'metodo_entrega'
  ) THEN
    UPDATE public.dados_profissionais
    SET metodo_entrega = 'Leva e Traz'
    WHERE metodo_entrega IS NULL
       OR btrim(metodo_entrega) = '';
  END IF;
END $$;
