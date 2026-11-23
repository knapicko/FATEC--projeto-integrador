import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/movimento.dart';

enum EstadoSalvamento { ocioso, salvando, salvo, erro }

/// Salvamento automático: cada mudança agenda um salvamento (com um pequeno
/// atraso, para juntar toques seguidos) e o estado aparece num indicador
/// discreto — sem botão de "Salvar".
class SalvamentoAutomatico extends ChangeNotifier {
  SalvamentoAutomatico(
    this._salvar, {
    this.atraso = const Duration(milliseconds: 600),
  });

  final Future<void> Function() _salvar;
  final Duration atraso;

  EstadoSalvamento estado = EstadoSalvamento.ocioso;
  String? erro;
  Timer? _timer;
  bool _pendente = false;
  bool _rodando = false;
  bool _descartado = false;

  /// Agenda um salvamento.
  void agendar() {
    _timer?.cancel();
    _timer = Timer(atraso, salvarAgora);
  }

  /// Salva já (ex.: ao sair da tela com algo pendente).
  Future<void> salvarAgora() async {
    _timer?.cancel();
    if (_rodando) {
      _pendente = true;
      return;
    }
    _rodando = true;
    _definir(EstadoSalvamento.salvando);
    try {
      await _salvar();
      erro = null;
      _definir(EstadoSalvamento.salvo);
    } catch (e) {
      erro = e.toString().replaceFirst('Exception: ', '');
      _definir(EstadoSalvamento.erro);
    } finally {
      _rodando = false;
      if (_pendente) {
        _pendente = false;
        unawaited(salvarAgora());
      }
    }
  }

  bool get temAlgoPendente => _timer?.isActive == true || _rodando;

  void _definir(EstadoSalvamento novo) {
    if (_descartado) return;
    estado = novo;
    notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    // Mudança feita logo antes de sair: salva mesmo assim.
    if (_timer?.isActive == true) {
      _timer!.cancel();
      unawaited(_salvar().catchError((_) {}));
    }
    super.dispose();
  }
}

/// "Salvando…" / "Alterações salvas" / erro, para o topo ou rodapé da tela.
class IndicadorSalvamento extends StatelessWidget {
  const IndicadorSalvamento({
    super.key,
    required this.controle,
    this.corTexto = const Color(0xFF6B7280),
  });

  final SalvamentoAutomatico controle;
  final Color corTexto;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controle,
      builder: (context, _) {
        final (
          IconData icone,
          String texto,
          Color cor,
        ) = switch (controle.estado) {
          EstadoSalvamento.ocioso => (
            Icons.cloud_done_outlined,
            'As alterações são salvas automaticamente',
            corTexto,
          ),
          EstadoSalvamento.salvando => (
            Icons.cloud_upload_outlined,
            'Salvando…',
            corTexto,
          ),
          EstadoSalvamento.salvo => (
            Icons.check_circle_outline_rounded,
            'Alterações salvas',
            const Color(0xFF16A34A),
          ),
          EstadoSalvamento.erro => (
            Icons.error_outline_rounded,
            controle.erro == null
                ? 'Não foi possível salvar'
                : 'Não foi possível salvar: ${controle.erro}',
            const Color(0xFFDC2626),
          ),
        };
        return AnimatedSwitcher(
          duration: duracao(const Duration(milliseconds: 220)),
          child: Row(
            key: ValueKey(controle.estado),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controle.estado == EstadoSalvamento.salvando)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: cor),
                )
              else
                Icon(icone, size: 16, color: cor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
