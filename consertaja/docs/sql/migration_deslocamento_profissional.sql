-- Migration para Suporte a Deslocamento do Profissional em Tempo Real
-- Execute este script no SQL Editor do Supabase

CREATE TABLE IF NOT EXISTS public.deslocamento_profissional (
    id_deslocamento BIGSERIAL PRIMARY KEY,
    fk_solicitacao BIGINT NOT NULL UNIQUE REFERENCES public.solicitacoes(id_solicitacao) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    velocidade DOUBLE PRECISION DEFAULT 0.0,
    bearing DOUBLE PRECISION DEFAULT 0.0,
    rua_atual TEXT,
    proxima_manobra TEXT,
    distancia_metros DOUBLE PRECISION,
    duracao_segundos INTEGER,
    data_inicio TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    atualizado_em TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Habilitar Row Level Security (RLS)
ALTER TABLE public.deslocamento_profissional ENABLE ROW LEVEL SECURITY;

-- Políticas de acesso
DROP POLICY IF EXISTS "Permitir leitura de deslocamento para usuários autenticados" ON public.deslocamento_profissional;
CREATE POLICY "Permitir leitura de deslocamento para usuários autenticados"
ON public.deslocamento_profissional FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Permitir inserção e atualização de deslocamento para usuários autenticados" ON public.deslocamento_profissional;
CREATE POLICY "Permitir inserção e atualização de deslocamento para usuários autenticados"
ON public.deslocamento_profissional FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Habilitar publicação Realtime para sincronização ao vivo
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
      AND schemaname = 'public' 
      AND tablename = 'deslocamento_profissional'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.deslocamento_profissional;
  END IF;
END $$;

