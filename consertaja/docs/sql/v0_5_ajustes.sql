-- ============================================================================
-- ConsertaJá — ajustes v0.5 (rode tudo de uma vez no SQL Editor do Supabase)
-- ============================================================================
--  1. Cores dos ofícios (tons suaves que lembram cada área)
--  2. Função "Funileiro" no ofício certo
--  3. Avaliações com fotos/vídeos (coluna + bucket "Avaliacoes")
--  4. Certificados dos profissionais (tabela + bucket "Certificados Profissional")
-- ============================================================================

BEGIN;

-- 1) CORES DOS OFÍCIOS ------------------------------------------------------
-- O app passou a usar o cod_cor (hex) quando existe; a coluna "cor" (enum)
-- continua igual.
UPDATE public.oficios SET cod_cor = '#F2A27E' WHERE id_oficio = 1;  -- Reparos domésticos: laranja-pêssego (ferramentas, casa)
UPDATE public.oficios SET cod_cor = '#C9A27E' WHERE id_oficio = 5;  -- Móveis e interiores: madeira clara
UPDATE public.oficios SET cod_cor = '#8FA3D9' WHERE id_oficio = 8;  -- Segurança: azul-lavanda (confiança)
UPDATE public.oficios SET cod_cor = '#8CC7D6' WHERE id_oficio = 10; -- Vidros e estruturas: azul-vidro
UPDATE public.oficios SET cod_cor = '#E8A3BE' WHERE id_oficio = 12; -- Reparos pessoais: rosa (roupas, calçados)
UPDATE public.oficios SET cod_cor = '#86D3B5' WHERE id_oficio = 14; -- Limpeza especializada: verde-menta
UPDATE public.oficios SET cod_cor = '#D9BE7A' WHERE id_oficio = 16; -- Serviços tradicionais: mostarda/latão

-- 2) FUNÇÕES × OFÍCIOS --------------------------------------------------------
-- Revisão: quase tudo faz sentido. A exceção é "Funileiro" (calhas, chapas
-- metálicas), que combina com "Vidros e estruturas" (junto do Serralheiro),
-- não com "Serviços tradicionais".
UPDATE public.funcoes SET fk_oficio = 10 WHERE id_funcao = 19;
UPDATE public.ass_oficio_profissional SET fk_oficio = 10 WHERE fk_funcao = 19;
UPDATE public.ass_oficio_grupo_empresa SET fk_oficio = 10 WHERE fk_funcao = 19;
UPDATE public.servicos_profissional SET fk_oficios = 10 WHERE fk_funcao = 19;
UPDATE public.servicos_chat_temporarios SET fk_oficios = 10 WHERE fk_funcao = 19;
UPDATE public.solicitacoes_geograficas SET fk_oficio = 10 WHERE fk_funcao = 19;

-- 3) AVALIAÇÕES COM FOTOS E VÍDEOS ----------------------------------------------
ALTER TABLE public.avaliacoes_solicitacao
  ADD COLUMN IF NOT EXISTS midias text[] NOT NULL DEFAULT '{}';

-- Uma avaliação por tipo e por avaliador em cada pedido (evita duplicar).
CREATE UNIQUE INDEX IF NOT EXISTS avaliacoes_solicitacao_unica
  ON public.avaliacoes_solicitacao (fk_solicitacao, fk_avaliador, tipo_avaliacao);

ALTER TABLE public.avaliacoes_solicitacao ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS avaliacoes_leitura_publica ON public.avaliacoes_solicitacao;
CREATE POLICY avaliacoes_leitura_publica ON public.avaliacoes_solicitacao
  FOR SELECT USING (true);

DROP POLICY IF EXISTS avaliacoes_insere_proprio ON public.avaliacoes_solicitacao;
CREATE POLICY avaliacoes_insere_proprio ON public.avaliacoes_solicitacao
  FOR INSERT TO authenticated
  WITH CHECK (
    fk_avaliador IN (SELECT id_usuario FROM public.usuarios WHERE auth_id = auth.uid())
  );

-- Quem avaliou pode anexar as fotos/vídeos (coluna midias) depois.
DROP POLICY IF EXISTS avaliacoes_atualiza_proprio ON public.avaliacoes_solicitacao;
CREATE POLICY avaliacoes_atualiza_proprio ON public.avaliacoes_solicitacao
  FOR UPDATE TO authenticated
  USING (fk_avaliador IN (SELECT id_usuario FROM public.usuarios WHERE auth_id = auth.uid()))
  WITH CHECK (fk_avaliador IN (SELECT id_usuario FROM public.usuarios WHERE auth_id = auth.uid()));

INSERT INTO storage.buckets (id, name, public)
VALUES ('Avaliacoes', 'Avaliacoes', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "avaliacoes_upload" ON storage.objects;
CREATE POLICY "avaliacoes_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'Avaliacoes' AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS "avaliacoes_leitura" ON storage.objects;
CREATE POLICY "avaliacoes_leitura" ON storage.objects
  FOR SELECT USING (bucket_id = 'Avaliacoes');

-- 4) CERTIFICADOS ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.certificados_profissional (
  id_certificado bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fk_profissional bigint REFERENCES public.dados_profissionais (id_profissional) ON DELETE CASCADE,
  fk_grupo_empresa bigint REFERENCES public.grupo_empresa (id_grupo_empresa) ON DELETE CASCADE,
  titulo text NOT NULL CHECK (char_length(trim(titulo)) BETWEEN 1 AND 120),
  data_emissao date,
  -- Caminho do arquivo no bucket "Certificados Profissional".
  arquivo text NOT NULL,
  tipo_arquivo text NOT NULL DEFAULT 'imagem' CHECK (tipo_arquivo IN ('imagem', 'pdf')),
  data_criacao timestamptz NOT NULL DEFAULT now(),
  CHECK (fk_profissional IS NOT NULL OR fk_grupo_empresa IS NOT NULL)
);
CREATE INDEX IF NOT EXISTS certificados_prof_idx ON public.certificados_profissional (fk_profissional);
CREATE INDEX IF NOT EXISTS certificados_grupo_idx ON public.certificados_profissional (fk_grupo_empresa);

-- Dono do certificado: o próprio profissional ou o dono da empresa.
CREATE OR REPLACE FUNCTION public.sou_dono_certificado(p_prof bigint, p_grupo bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.dados_profissionais d
    JOIN public.usuarios u ON u.id_usuario = d.fk_usuario
    WHERE u.auth_id = auth.uid()
      AND (d.id_profissional = p_prof
           OR (p_grupo IS NOT NULL AND EXISTS (
                 SELECT 1 FROM public.grupo_empresa g
                 WHERE g.id_grupo_empresa = p_grupo AND g.fk_perfil = d.fk_perfil)))
  );
$$;

ALTER TABLE public.certificados_profissional ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS certificados_leitura ON public.certificados_profissional;
CREATE POLICY certificados_leitura ON public.certificados_profissional
  FOR SELECT USING (true);
DROP POLICY IF EXISTS certificados_escrita ON public.certificados_profissional;
CREATE POLICY certificados_escrita ON public.certificados_profissional
  FOR ALL TO authenticated
  USING (public.sou_dono_certificado(fk_profissional, fk_grupo_empresa))
  WITH CHECK (public.sou_dono_certificado(fk_profissional, fk_grupo_empresa));

INSERT INTO storage.buckets (id, name, public)
VALUES ('Certificados Profissional', 'Certificados Profissional', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "certificados_upload" ON storage.objects;
CREATE POLICY "certificados_upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'Certificados Profissional'
              AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS "certificados_apagar" ON storage.objects;
CREATE POLICY "certificados_apagar" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'Certificados Profissional'
         AND (storage.foldername(name))[1] = auth.uid()::text);
DROP POLICY IF EXISTS "certificados_leitura" ON storage.objects;
CREATE POLICY "certificados_leitura" ON storage.objects
  FOR SELECT USING (bucket_id = 'Certificados Profissional');

COMMIT;
