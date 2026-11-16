-- ============================================================================
-- ConsertaJá — Limpar TODAS as contas (dados de teste) + autenticação
--
-- APAGA DE VEZ, sem volta: usuários, profissionais, empresas, endereços,
-- serviços, solicitações, pagamentos, chat, postagens... e os logins do
-- Supabase (auth.users, sessões, identidades Google).
--
-- MANTÉM (tabelas de referência): status, oficios, funcoes,
-- servicos_catalogo, estados, cidades.
--
-- Não apaga os arquivos do Storage (fotos, anexos): limpe os buckets pelo
-- painel se quiser.
-- ============================================================================

BEGIN;

-- 1) Dados das contas ------------------------------------------------------------
-- CASCADE: leva junto qualquer tabela que aponte para estas (ex.: uma tabela
-- nova que referencie usuarios). As tabelas de referência acima não apontam
-- para nenhuma destas, então não são afetadas.
-- RESTART IDENTITY: os ids voltam a começar do 1.
TRUNCATE TABLE
  -- conta / pessoa
  usuarios,
  emails,
  telefones,
  pessoa_fisica,
  pessoa_juridica,
  ass_tipo_pessoa,
  -- endereços (cidades/estados ficam)
  enderecos,
  ass_usuario_endereco,
  ass_profissional_endereco,
  ass_grupo_empresa_endereco,
  -- profissional / empresa
  dados_profissionais,
  documentos_profissionais,
  ass_oficio_profissional,
  ass_oficio_grupo_empresa,
  agenda_profissional,
  grade_horario_excecao,
  perfil,
  grupo_empresa,
  convites_empresa,
  -- rede social
  postagens,
  imagens_postagem,
  imagens_postagens,
  curtidas_postagem,
  seguidores_profissional,
  seguidores_empresa,
  -- serviços e pedidos
  servicos,
  servicos_profissional,
  servicos_chat_temporarios,
  lista_servicos,
  ass_servicos_lista,
  solicitacoes,
  solicitacoes_anexos,
  solicitacoes_geograficas,
  avaliacoes_solicitacao,
  pagamentos_solicitacao,
  pagamentos_stripe,
  deslocamento_profissional,
  -- chat
  conversas,
  mensagens
RESTART IDENTITY CASCADE;

-- 2) Autenticação do Supabase ---------------------------------------------------
-- DELETE (e não TRUNCATE) para o próprio Supabase apagar em cascata sessões,
-- refresh tokens, identidades (Google) e fatores MFA de cada usuário.
DELETE FROM auth.users;

COMMIT;

-- Conferência (opcional):
--   SELECT count(*) FROM auth.users;        -- 0
--   SELECT count(*) FROM public.usuarios;   -- 0
--   SELECT count(*) FROM public.funcoes;    -- 19 (mantida)
