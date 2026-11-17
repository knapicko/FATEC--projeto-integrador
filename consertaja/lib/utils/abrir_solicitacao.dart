import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../acompanhar_deslocamento.dart';
import '../atendimento_no_local_cliente.dart';
import '../confirmar_retirada_cliente.dart';
import '../detalhes_pedido.dart';
import '../meus_servicos_solicitados.dart';
import '../tela_deslocamento_cliente.dart';
import 'fluxo_solicitacao.dart';

/// Abre a tela certa de uma solicitação conforme o status e o método de
/// entrega — a mesma regra de meus_pedidos.dart (cliente) e
/// meus_servicos_solicitados.dart (profissional).
Future<void> abrirSolicitacaoPorStatus(
  BuildContext context,
  int idSolicitacao, {
  required bool comoProfissional,
}) async {
  final navegador = Navigator.of(context);
  if (comoProfissional) {
    // As telas do profissional precisam de vários dados do item; a lista já
    // monta tudo e abre a etapa certa sozinha.
    await navegador.push(
      MaterialPageRoute(
        builder: (_) =>
            MeusServicosSolicitadosPage(abrirIdSolicitacao: idSolicitacao),
      ),
    );
    return;
  }

  Widget destino = DetalhesPedidoPage(idSolicitacao: idSolicitacao);
  try {
    final row = await Supabase.instance.client
        .from('solicitacoes')
        .select('tipo_execucao, fk_status, etapa_solicitacao')
        .eq('id_solicitacao', idSolicitacao)
        .maybeSingle();
    if (row != null) {
      final fluxo = FluxoSolicitacao(
        tipoExecucao: row['tipo_execucao']?.toString(),
        fkStatus: (row['fk_status'] as num?)?.toInt(),
        etapa: (row['etapa_solicitacao'] as num?)?.toInt() ?? 0,
      );
      destino = switch (fluxo.destinoCliente) {
        DestinoCliente.atendimentoNoLocal => AtendimentoNoLocalClientePage(
          idSolicitacao: idSolicitacao,
        ),
        DestinoCliente.deslocamentoCliente => TelaDeslocamentoClientePage(
          idSolicitacao: idSolicitacao,
        ),
        DestinoCliente.acompanharDeslocamento => AcompanharDeslocamentoPage(
          idSolicitacao: idSolicitacao,
        ),
        DestinoCliente.confirmarRetirada => ConfirmarRetiradaClientePage(
          idSolicitacao: idSolicitacao,
        ),
        DestinoCliente.detalhes => DetalhesPedidoPage(
          idSolicitacao: idSolicitacao,
        ),
      };
    }
  } catch (_) {}
  await navegador.push(MaterialPageRoute(builder: (_) => destino));
}
