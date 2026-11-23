import 'package:flutter/material.dart';

import 'tutorial.dart';

/// Botão "?" do canto superior direito: abre a explicação da tela (a caixa
/// destaca e explica as seções e os principais elementos).
///
/// - [cor]: cor do ícone (padrão: a cor dos ícones do cabeçalho/AppBar);
/// - [fundo]: com fundo, vira um círculo (igual aos botões redondos do
///   cabeçalho, como o do sino).
class BotaoAjuda extends StatelessWidget {
  const BotaoAjuda({
    super.key,
    required this.passos,
    this.cor,
    this.fundo,
    this.tamanhoIcone = 24,
    this.diametro = 46,
    this.borda,
  });

  final List<PassoTutorial> Function() passos;
  final Color? cor;
  final Color? fundo;
  final double tamanhoIcone;
  final double diametro;
  final BoxBorder? borda;

  Future<void> _explicar(BuildContext context) async {
    final lista = passos();
    if (lista.isEmpty) return;
    await Tutorial.mostrar(
      context,
      chave: 'ajuda',
      forcar: true,
      marcarVisto: false,
      passos: lista,
    );
  }

  @override
  Widget build(BuildContext context) {
    const icone = Icons.help_outline_rounded;
    if (fundo != null) {
      return Material(
        color: fundo,
        shape: CircleBorder(
          side: borda is Border ? (borda! as Border).top : BorderSide.none,
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _explicar(context),
          child: SizedBox(
            width: diametro,
            height: diametro,
            child: Tooltip(
              message: 'Como usar esta tela',
              child: Icon(icone, color: cor, size: tamanhoIcone),
            ),
          ),
        ),
      );
    }
    return IconButton(
      tooltip: 'Como usar esta tela',
      onPressed: () => _explicar(context),
      icon: Icon(icone, color: cor, size: tamanhoIcone),
    );
  }
}

/// Faixa do cabeçalho (topo da tela, logo abaixo da barra de status).
Rect? regiaoCabecalho(BuildContext context, {double altura = kToolbarHeight}) {
  if (!context.mounted) return null;
  final mq = MediaQuery.of(context);
  return Rect.fromLTWH(0, mq.padding.top, mq.size.width, altura);
}

/// Conteúdo da tela (abaixo do cabeçalho, acima da barra inferior).
Rect? regiaoConteudo(
  BuildContext context, {
  double cabecalho = kToolbarHeight,
  double rodape = 0,
}) {
  if (!context.mounted) return null;
  final mq = MediaQuery.of(context);
  final topo = mq.padding.top + cabecalho;
  final base = mq.size.height - mq.padding.bottom - rodape;
  return Rect.fromLTRB(8, topo + 6, mq.size.width - 8, base - 6);
}

/// Explicação padrão de uma tela: o 1º balão destaca o cabeçalho (o que é a
/// tela); os outros, o conteúdo (como usar).
List<PassoTutorial> explicacaoDaTela(
  BuildContext context, {
  required String tela,
  required List<String> conteudo,
  double cabecalho = kToolbarHeight,
  double rodape = 0,
}) => [
  PassoTutorial(
    tela,
    alvoRect: () => regiaoCabecalho(context, altura: cabecalho),
    raio: 12,
    folga: 0,
  ),
  for (final t in conteudo)
    PassoTutorial(
      t,
      alvoRect: () =>
          regiaoConteudo(context, cabecalho: cabecalho, rodape: rodape),
      raio: 16,
      folga: 0,
    ),
];
