-- Execute no Supabase antes de usar o fluxo de Atendimento a Domicílio.
ALTER TABLE public.solicitacoes
  ADD COLUMN IF NOT EXISTS duracao_atendimento integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS data_inicio_andamento timestamptz,
  ADD COLUMN IF NOT EXISTS imagens_atendimento_antes text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS imagens_atendimento_depois text[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS profissional_finalizado_atendimento boolean NOT NULL DEFAULT false;

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('Imagens Atendimento Antes', 'Imagens Atendimento Antes', true),
  ('Imagens Atendimento Depois', 'Imagens Atendimento Depois', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "atendimento_antes_profissional_insert" ON storage.objects;
CREATE POLICY "atendimento_antes_profissional_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'Imagens Atendimento Antes'
    AND (storage.foldername(name))[1] = 'solicitacao'
    AND (storage.foldername(name))[2] ~ '^[0-9]+$'
    AND public.profissional_pode_acessar_solicitacao_id(
      ((storage.foldername(name))[2])::bigint
    )
  );

DROP POLICY IF EXISTS "atendimento_depois_profissional_insert" ON storage.objects;
CREATE POLICY "atendimento_depois_profissional_insert"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'Imagens Atendimento Depois'
    AND (storage.foldername(name))[1] = 'solicitacao'
    AND (storage.foldername(name))[2] ~ '^[0-9]+$'
    AND public.profissional_pode_acessar_solicitacao_id(
      ((storage.foldername(name))[2])::bigint
    )
  );

DROP POLICY IF EXISTS "atendimento_antes_authenticated_select" ON storage.objects;
CREATE POLICY "atendimento_antes_authenticated_select"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'Imagens Atendimento Antes');

DROP POLICY IF EXISTS "atendimento_depois_authenticated_select" ON storage.objects;
CREATE POLICY "atendimento_depois_authenticated_select"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'Imagens Atendimento Depois');
