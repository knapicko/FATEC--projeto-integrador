-- Permite que o cliente exclua a própria solicitação cancelável.
-- Os anexos são excluídos antes pelo app; a regra também mantém o vínculo
-- seguro caso a solicitação seja removida diretamente.

DROP POLICY IF EXISTS "solicitacoes_delete_cliente" ON public.solicitacoes;
CREATE POLICY "solicitacoes_delete_cliente"
  ON public.solicitacoes
  FOR DELETE TO authenticated
  USING (
    fk_usuario = public.meu_id_usuario_solicitacao()
  );

DROP POLICY IF EXISTS "solicitacoes_anexos_delete_cliente"
  ON public.solicitacoes_anexos;
CREATE POLICY "solicitacoes_anexos_delete_cliente"
  ON public.solicitacoes_anexos
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.solicitacoes s
      WHERE s.id_solicitacao = solicitacoes_anexos.fk_solicitacao
        AND s.fk_usuario = public.meu_id_usuario_solicitacao()
    )
  );
