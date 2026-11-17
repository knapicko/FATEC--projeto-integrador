-- ============================================================================
-- Imagens das funções (tela "Áreas de Atuação" → Detalhes das Áreas)
-- ============================================================================
-- A tela agora mostra a imagem de `funcoes.img_funcao` (URL). Sem imagem
-- cadastrada, aparece o ícone da função num fundo azul.
--
-- COMO FAZER
--   1. Rode o PASSO 1 (cria o bucket público "funcoes" no Storage).
--   2. No painel do Supabase: Storage → funcoes → Upload. Suba as imagens
--      (jpg/png/webp, de preferência ~1200×600, paisagem).
--      Dica: dê ao arquivo o MESMO nome da função (ex.: "Eletricista.jpg")
--      para usar o PASSO 3B e preencher tudo de uma vez.
--   3. Rode o PASSO 2 para ver as funções e depois o PASSO 3A (uma por uma)
--      ou o PASSO 3B (todas cujo arquivo tem o nome da função).
--   4. Rode o PASSO 4 para conferir.
-- ============================================================================

-- PASSO 1: bucket público para as imagens ---------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('funcoes', 'funcoes', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- PASSO 2: funções cadastradas --------------------------------------------
SELECT id_funcao, funcao, img_funcao
FROM public.funcoes
ORDER BY funcao;

-- PASSO 3A: uma por uma (troque a URL e o id) ------------------------------
-- A URL pública fica em: Storage → funcoes → (arquivo) → "Get URL".
-- UPDATE public.funcoes
-- SET img_funcao = 'https://woqhicdlnkoksypipyoz.supabase.co/storage/v1/object/public/funcoes/Eletricista.jpg'
-- WHERE id_funcao = 1;

-- PASSO 3B: todas de uma vez (arquivo com o nome da função) ---------------
-- Compara ignorando maiúsculas e a extensão ("Eletricista.jpg" ↔ "Eletricista").
UPDATE public.funcoes f
SET img_funcao =
  'https://woqhicdlnkoksypipyoz.supabase.co/storage/v1/object/public/funcoes/'
  || o.name
FROM storage.objects o
WHERE o.bucket_id = 'funcoes'
  AND lower(regexp_replace(o.name, '\.[^.]+$', '')) = lower(trim(f.funcao));

-- Também vale qualquer URL pública de fora (ex.: imagem já hospedada):
-- UPDATE public.funcoes SET img_funcao = 'https://...' WHERE funcao = 'Pintor';

-- Para tirar a imagem de uma função (volta a mostrar o ícone):
-- UPDATE public.funcoes SET img_funcao = NULL WHERE id_funcao = 1;

-- PASSO 4: conferir --------------------------------------------------------
SELECT id_funcao, funcao, img_funcao IS NOT NULL AS tem_imagem, img_funcao
FROM public.funcoes
ORDER BY tem_imagem, funcao;
