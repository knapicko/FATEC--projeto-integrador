-- ======================================================================
-- ConsertaJá — Chat cliente <-> profissional (Supabase / Postgres)
-- Rode este script UMA VEZ no SQL Editor do Supabase.
-- Compatível com as tabelas conversas/mensagens JÁ existentes:
-- só adiciona constraint única, índices, Realtime e políticas RLS.
-- Idempotente: pode rodar de novo sem quebrar nada.
-- ======================================================================

-- 0) Garante coluna ultima_conexao em usuarios (usada na lista Mensagens)
ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS ultima_conexao timestamptz;

-- 1) Uma conversa por par (cliente, profissional) — evita duplicar chat.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'conversas_usuario_profissional_unique') THEN
    ALTER TABLE public.conversas
      ADD CONSTRAINT conversas_usuario_profissional_unique
      UNIQUE (fk_usuario, fk_profissional);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_conversas_fk_usuario
  ON public.conversas (fk_usuario);
CREATE INDEX IF NOT EXISTS idx_conversas_fk_profissional
  ON public.conversas (fk_profissional);
CREATE INDEX IF NOT EXISTS idx_mensagens_fk_conversa_data
  ON public.mensagens (fk_conversa, data_envio);

-- 2) Realtime: receber mensagem sem refresh (app tem polling de 5s de fallback)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
      AND tablename = 'mensagens'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.mensagens;
  END IF;
END $$;

-- 3) RLS: enviar + receber funcionando
ALTER TABLE public.conversas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mensagens ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.meu_id_usuario()
RETURNS bigint
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT id_usuario FROM public.usuarios WHERE auth_id = auth.uid() LIMIT 1
$$;

GRANT EXECUTE ON FUNCTION public.meu_id_usuario() TO authenticated;

DROP POLICY IF EXISTS "conversas_select_participante" ON public.conversas;
CREATE POLICY "conversas_select_participante"
  ON public.conversas FOR SELECT TO authenticated
  USING (
    fk_usuario = public.meu_id_usuario()
    OR EXISTS (
      SELECT 1 FROM public.dados_profissionais dp
      WHERE dp.id_profissional = conversas.fk_profissional
        AND dp.fk_usuario = public.meu_id_usuario()
    )
  );

DROP POLICY IF EXISTS "conversas_insert_cliente" ON public.conversas;
CREATE POLICY "conversas_insert_cliente"
  ON public.conversas FOR INSERT TO authenticated
  WITH CHECK (fk_usuario = public.meu_id_usuario());

DROP POLICY IF EXISTS "mensagens_select_participante" ON public.mensagens;
CREATE POLICY "mensagens_select_participante"
  ON public.mensagens FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.conversas c
      WHERE c.id_conversa = mensagens.fk_conversa
        AND (
          c.fk_usuario = public.meu_id_usuario()
          OR EXISTS (
            SELECT 1 FROM public.dados_profissionais dp
            WHERE dp.id_profissional = c.fk_profissional
              AND dp.fk_usuario = public.meu_id_usuario()
          )
        )
    )
  );

DROP POLICY IF EXISTS "mensagens_insert_participante" ON public.mensagens;
CREATE POLICY "mensagens_insert_participante"
  ON public.mensagens FOR INSERT TO authenticated
  WITH CHECK (
    fk_remitente_usuario = public.meu_id_usuario()
    AND EXISTS (
      SELECT 1 FROM public.conversas c
      WHERE c.id_conversa = mensagens.fk_conversa
        AND (
          c.fk_usuario = public.meu_id_usuario()
          OR EXISTS (
            SELECT 1 FROM public.dados_profissionais dp
            WHERE dp.id_profissional = c.fk_profissional
              AND dp.fk_usuario = public.meu_id_usuario()
          )
        )
    )
  );


-- 4) Leitura do ofício no chat (RLS):
-- o app busca ass_oficio_profissional + oficios para exibir a pílula
-- de ofício no header. Sem estas policies, a pílula cai para "Conversa".
ALTER TABLE public.ass_oficio_profissional ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.oficios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "ass_oficio_select_autenticado" ON public.ass_oficio_profissional;
CREATE POLICY "ass_oficio_select_autenticado"
  ON public.ass_oficio_profissional FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "oficios_select_autenticado" ON public.oficios;
CREATE POLICY "oficios_select_autenticado"
  ON public.oficios FOR SELECT TO authenticated
  USING (true);


