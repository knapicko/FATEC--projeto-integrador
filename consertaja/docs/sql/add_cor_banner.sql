ALTER TABLE public.perfil ADD COLUMN IF NOT EXISTS cor_banner text;

ALTER TABLE public.perfil
ALTER COLUMN cor_banner
SET DEFAULT '0xFF0A6E9D';

UPDATE public.perfil
SET
    cor_banner = '0xFF0A6E9D'
WHERE
    cor_banner IS NULL
    OR btrim (cor_banner) = '';

ALTER TABLE public.perfil ALTER COLUMN cor_banner SET NOT NULL;