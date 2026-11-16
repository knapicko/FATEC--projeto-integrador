// =============================================================================
// ConsertaJá — "Voltar" das telas do fluxo de uma solicitação
//
// As telas de etapa (deslocamento, atendimento, andamento, devolução,
// pagamento...) são abertas de acordo com o status/etapa do pedido. Voltar
// para "a última tela" podia levar a uma etapa que já passou. Por isso, nessas
// telas, voltar (botão da tela OU voltar do sistema) sempre leva para a lista:
//   • cliente      → meus_pedidos.dart
//   • profissional → meus_servicos_solicitados.dart
// A pilha é limpa até a Home e a lista abre de novo (dados atualizados).
//
// Uso numa tela:
//   class _MinhaTelaState extends State<MinhaTela>
//       with VoltarParaPedidosMixin {
//     @override
//     bool get voltarComoProfissional => false;
//     ... IconButton(onPressed: voltarParaPedidos, ...)
//   }
//
// `Navigator.pop(context, resultado)` usado pelas telas para devolver um
// resultado continua funcionando (só o "voltar" é desviado).
// =============================================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../meus_pedidos.dart';
import '../meus_servicos_solicitados.dart';
import 'app_navigation_util.dart';

class VoltarFluxoSolicitacao {
  VoltarFluxoSolicitacao._();

  /// Abre a lista de pedidos certa com a Home por baixo.
  static void irParaPedidos(
    BuildContext context, {
    required bool profissional,
  }) {
    final navegador = Navigator.of(context);
    final Widget lista = profissional
        ? const MeusServicosSolicitadosPage()
        : const MeusPedidosPage();
    final nome = profissional ? 'MeusServicosSolicitadosPage' : 'MeusPedidosPage';
    navegador.pushAndRemoveUntil(
      AppNavigationUtil.rotaSemAnimacao(lista, nome: nome),
      (rota) => rota.isFirst,
    );
  }
}

/// Intercepta o voltar do sistema (gesto / botão do Android) na rota da tela.
class _EntradaVoltarPedidos extends PopEntry<Object?> {
  _EntradaVoltarPedidos(this._aoVoltar);

  final VoidCallback _aoVoltar;
  final ValueNotifier<bool> _podeSairDireto = ValueNotifier<bool>(false);

  @override
  ValueListenable<bool> get canPopNotifier => _podeSairDireto;

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (!didPop) _aoVoltar();
  }
}

mixin VoltarParaPedidosMixin<T extends StatefulWidget> on State<T> {
  /// true = tela do profissional (volta para os serviços solicitados).
  bool get voltarComoProfissional;

  ModalRoute<dynamic>? _rotaVoltar;
  late final _EntradaVoltarPedidos _entradaVoltar = _EntradaVoltarPedidos(
    voltarParaPedidos,
  );

  /// Use no botão de voltar da tela.
  void voltarParaPedidos() {
    if (!mounted) return;
    VoltarFluxoSolicitacao.irParaPedidos(
      context,
      profissional: voltarComoProfissional,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rota = ModalRoute.of(context);
    if (!identical(rota, _rotaVoltar)) {
      _rotaVoltar?.unregisterPopEntry(_entradaVoltar);
      _rotaVoltar = rota;
      rota?.registerPopEntry(_entradaVoltar);
    }
  }

  @override
  void dispose() {
    _rotaVoltar?.unregisterPopEntry(_entradaVoltar);
    super.dispose();
  }
}
