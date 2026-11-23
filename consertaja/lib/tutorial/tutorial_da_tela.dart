import 'package:flutter/material.dart';

import 'tutorial.dart';
import 'tutorial_visto.dart';

/// Ajuda para as telas com tutorial:
/// - [alvoTut] marca uma parte da tela para ser destacada;
/// - [tutorialDaTela] mostra o tutorial na primeira visita, ou (quando a tela
///   foi aberta pelo tutorial da home, [sair] = true) mostra sempre e volta
///   devolvendo o resultado.
mixin TutorialDaTela<T extends StatefulWidget> on State<T> {
  final Map<String, GlobalKey> _chavesTut = {};
  bool _tutPedido = false;

  GlobalKey chaveTut(String nome) =>
      _chavesTut.putIfAbsent(nome, () => GlobalKey(debugLabel: 'tut_$nome'));

  Widget alvoTut(String nome, Widget child) =>
      KeyedSubtree(key: chaveTut(nome), child: child);

  /// Retângulo de uma parte marcada (null se não estiver na tela).
  Rect? rectTut(String nome) {
    final chave = _chavesTut[nome];
    final box = chave == null ? null : caixaDoAlvo(chave);
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Junta várias partes num destaque só.
  Rect? Function() uniaoTut(List<String> nomes) => () {
    Rect? r;
    for (final n in nomes) {
      final x = rectTut(n);
      if (x != null) r = r == null ? x : r.expandToInclude(x);
    }
    return r;
  };

  /// Chame no build (ou depois de carregar): roda uma vez.
  void tutorialDaTela({
    required String chave,
    required List<PassoTutorial> Function() passos,
    bool sair = false,
    Duration atraso = const Duration(milliseconds: 650),
  }) {
    if (_tutPedido) return;
    _tutPedido = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(atraso);
      if (!mounted) return;
      if (!sair && await TutorialVisto.jaViu(chave)) return;
      // Espera a tela ficar na frente (sem bottom sheet/diálogo por cima) e
      // nenhum outro tutorial aberto.
      for (var i = 0; i < 60; i++) {
        if (!mounted) return;
        final naFrente = ModalRoute.of(context)?.isCurrent ?? true;
        if (naFrente && !Tutorial.aberto) break;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
      if (!mounted) return;
      // A fala final ("Pronto!...") só existe no fluxo de apresentação da
      // home (aqui: quando a tela foi aberta por ele, [sair]). Nas outras
      // telas o "Pular" encerra direto.
      final lista = [
        ...passos(),
        if (sair) passoFinalTutorial(apenasAoPular: true),
      ];
      final r = await Tutorial.mostrar(
        context,
        chave: chave,
        forcar: sair,
        comEntrada: !sair,
        pularParaFinal: sair,
        passos: lista,
      );
      if (sair && mounted) Navigator.of(context).pop(r);
    });
  }
}
