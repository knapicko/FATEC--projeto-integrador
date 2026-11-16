// =============================================================================
// ConsertaJá — Notificações de FEEDBACK (o único tipo disparado pelo app)
//
// São confirmações imediatas de uma ação feita no app (app aberto). Não passam
// pelo servidor nem pelo FCM: viram uma notificação local, com o mesmo visual
// das outras. Nas telas, basta chamar a função correspondente, por exemplo:
//
//   await NotificacaoFeedback.solicitacaoEnviada(quantidade: itens.length);
//
// Para um feedback novo, crie outra função aqui chamando [_mostrar].
// =============================================================================
import 'package:flutter/foundation.dart';

import 'notificacao_app.dart';
import 'notificacao_exibicao.dart';
import 'notificacao_tipos.dart';

class NotificacaoFeedback {
  NotificacaoFeedback._();

  static Future<void> _mostrar({
    required String titulo,
    required String conteudo,
    String? telaDestino,
    int? fkStatus,
    Map<String, dynamic> dados = const {},
  }) async {
    try {
      await NotificacaoExibicao.mostrar(
        NotificacaoApp(
          id: null,
          tipo: TipoNotificacao.feedback,
          titulo: titulo,
          conteudo: conteudo,
          dataCriacao: DateTime.now(),
          aberta: true,
          telaDestino: telaDestino,
          fkStatus: fkStatus,
          dados: dados,
        ),
      );
    } catch (e) {
      // Feedback nunca pode quebrar o fluxo da tela.
      debugPrint('[Notificacoes] feedback: $e');
    }
  }

  /// Carrinho (lista_servicos) finalizado e solicitação(ões) criada(s).
  static Future<void> solicitacaoEnviada({int quantidade = 1}) {
    return _mostrar(
      titulo: quantidade > 1
          ? 'Solicitações enviadas! ✅'
          : 'Solicitação enviada! ✅',
      conteudo: quantidade > 1
          ? 'Os $quantidade profissionais foram avisados! Agora é só aguardar o retorno.'
          : 'O profissional foi avisado! Agora é só aguardar o retorno.',
      telaDestino: 'meus_pedidos',
      fkStatus: 1,
      dados: {'evento': 'carrinho_finalizado', 'quantidade': quantidade},
    );
  }
}
