-- Permite ao cliente iniciar o pagamento Pix sem liberar UPDATE direto
-- na tabela solicitacoes. O status 2 significa "Aguardando Pagamento".

CREATE OR REPLACE FUNCTION public.iniciar_pagamento_pix(
  p_id_solicitacao bigint
)
RETURNS public.solicitacoes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id_usuario bigint;
  v_solicitacao public.solicitacoes;
BEGIN
  SELECT u.id_usuario
    INTO v_id_usuario
  FROM public.usuarios AS u
  WHERE u.auth_id = auth.uid()
  LIMIT 1;

  IF v_id_usuario IS NULL THEN
    RAISE EXCEPTION 'Usuário não autenticado';
  END IF;

  UPDATE public.solicitacoes AS s
  SET fk_status = 2
  WHERE s.id_solicitacao = p_id_solicitacao
    AND s.fk_usuario = v_id_usuario
  RETURNING s.* INTO v_solicitacao;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitação não encontrada ou não pertence ao usuário';
  END IF;

  RETURN v_solicitacao;
END;
$$;

REVOKE ALL ON FUNCTION public.iniciar_pagamento_pix(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.iniciar_pagamento_pix(bigint) TO authenticated;
