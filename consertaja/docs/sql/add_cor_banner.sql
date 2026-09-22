ALTER TABLE public.perfil ADD COLUMN IF NOT EXISTS cor_banner text;

-- Novo default: 0xFF0FB3FF (profissional sem foto de perfil).
ALTER TABLE public.perfil
ALTER COLUMN cor_banner
SET DEFAULT '0xFF0FB3FF';

-- Migra valores antigos/nulos/vazios para o novo default.
UPDATE public.perfil
SET
    cor_banner = '0xFF0FB3FF'
WHERE
    cor_banner IS NULL
    OR btrim(cor_banner) = ''
    OR btrim(cor_banner) = '0xFF0A6E9D'
    OR btrim(cor_banner) = '0XFF0A6E9D';

ALTER TABLE public.perfil ALTER COLUMN cor_banner SET NOT NULL;