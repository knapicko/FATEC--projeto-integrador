-- ==============================================================================
-- Migration: Criação da tabela servicos_chat_temporarios e ajuste em solicitacoes
-- Descrição: Permite que profissionais enviem propostas/serviços personalizados
--            diretamente no chat para clientes específicos.
-- ==============================================================================

-- 1. Criação da tabela servicos_chat_temporarios
CREATE TABLE IF NOT EXISTS public.servicos_chat_temporarios (
    id_servico_temp bigserial PRIMARY KEY,
    titulo text NOT NULL,
    descricao text,
    valor numeric(10, 2) NOT NULL,
    imagem_url text,
    ativo boolean NOT NULL DEFAULT true,
    fk_profissional bigint NOT NULL REFERENCES public.dados_profissionais(id_profissional) ON DELETE CASCADE,
    fk_grupo_empresa bigint REFERENCES public.grupo_empresa(id_grupo_empresa) ON DELETE SET NULL,
    fk_oficios bigint REFERENCES public.oficios(id_oficio) ON DELETE SET NULL,
    tipo_execucao text NOT NULL,
    carga_servico text NOT NULL DEFAULT 'Médio',
    data_criacao timestamptz NOT NULL DEFAULT timezone('utc'::text, now()),
    data_alteracao timestamptz
);

-- Comentários descritivos
COMMENT ON TABLE public.servicos_chat_temporarios IS 'Serviços personalizados temporários criados por profissionais diretamente no chat para um cliente.';
COMMENT ON COLUMN public.servicos_chat_temporarios.id_servico_temp IS 'Identificador único do serviço temporário.';
COMMENT ON COLUMN public.servicos_chat_temporarios.fk_oficios IS 'Ofício (função) do profissional associado ao serviço.';
COMMENT ON COLUMN public.servicos_chat_temporarios.tipo_execucao IS 'Método de atendimento definido na proposta (Leva e Traz, Retirada no Local, Receba em Casa, Atendimento em Domicílio).';

-- 2. Alteração na tabela solicitacoes para permitir vínculo com o serviço temporário
ALTER TABLE public.solicitacoes
    ADD COLUMN IF NOT EXISTS fk_servico_temp bigint REFERENCES public.servicos_chat_temporarios(id_servico_temp) ON DELETE SET NULL;

-- 3. Garantir que fk_servico_prof seja anulável (NULL), permitindo que solicitações
--    sejam criadas a partir de serviços temporários (onde fk_servico_prof é NULL e fk_servico_temp é preenchido)
ALTER TABLE public.solicitacoes
    ALTER COLUMN fk_servico_prof DROP NOT NULL;

-- 4. Índices para performance
CREATE INDEX IF NOT EXISTS idx_servicos_chat_temp_prof ON public.servicos_chat_temporarios(fk_profissional);
CREATE INDEX IF NOT EXISTS idx_servicos_chat_temp_grupo ON public.servicos_chat_temporarios(fk_grupo_empresa);
CREATE INDEX IF NOT EXISTS idx_solicitacoes_servico_temp ON public.solicitacoes(fk_servico_temp);

-- 5. Configuração de RLS (Row Level Security) e permissões
ALTER TABLE public.servicos_chat_temporarios ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'servicos_chat_temporarios' 
        AND policyname = 'servicos_chat_temporarios_auth_policy'
    ) THEN
        CREATE POLICY "servicos_chat_temporarios_auth_policy" 
        ON public.servicos_chat_temporarios
        FOR ALL 
        TO authenticated 
        USING (true) 
        WITH CHECK (true);
    END IF;
END $$;

GRANT ALL ON public.servicos_chat_temporarios TO authenticated;
GRANT ALL ON SEQUENCE public.servicos_chat_temporarios_id_servico_temp_seq TO authenticated;

-- 6. Atualização da constraint de tipo_mensagem na tabela mensagens para suportar 'Proposta'
ALTER TABLE public.mensagens DROP CONSTRAINT IF EXISTS mensagens_tipo_mensagem_check;
ALTER TABLE public.mensagens ADD CONSTRAINT mensagens_tipo_mensagem_check 
  CHECK (tipo_mensagem IN ('Texto', 'Imagem', 'Documento', 'Audio', 'Proposta', 'proposta'));
