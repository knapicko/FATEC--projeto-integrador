import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/app_settings_controller.dart';

/// Botões flutuantes de acessibilidade, por cima de todas as telas:
///
/// - **Leitura em voz alta** (Configurações → Acessibilidade): lê os textos
///   da tela aberta com o motor de voz do próprio celular (`flutter_tts`,
///   que usa o TextToSpeech do Android / AVSpeechSynthesizer do iOS / Web
///   Speech API no navegador). Não usa API paga nem manda o texto para fora.
/// - **Libras**: abre um painel com o VLibras (tradutor oficial e gratuito
///   do Governo Federal, vlibras.gov.br) numa WebView, com os textos da
///   tela. O avatar traduz o texto tocado para Libras. Precisa de internet.
///
/// Os textos vêm da árvore de semântica do Flutter (a mesma que o leitor de
/// tela usa): títulos, botões, campos e os `semanticLabel` das imagens.
class AssistenteAcessibilidade extends StatefulWidget {
  const AssistenteAcessibilidade({super.key});

  @override
  State<AssistenteAcessibilidade> createState() =>
      _AssistenteAcessibilidadeState();
}

class _AssistenteAcessibilidadeState extends State<AssistenteAcessibilidade> {
  static const _azul = Color(0xFF0FB3FF);
  static const _rotuloOuvir = 'Ler a tela em voz alta';
  static const _rotuloParar = 'Parar a leitura';
  static const _rotuloLibras = 'Traduzir a tela para Libras';
  static const _rotuloFecharLibras = 'Fechar a tradução em Libras';

  final _settings = AppSettingsController.instance;
  FlutterTts? _tts;
  SemanticsHandle? _semantica;
  bool _falando = false;
  bool _cancelado = false;
  List<String>? _textosLibras;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_aoMudarConfiguracao);
    _aoMudarConfiguracao();
  }

  @override
  void dispose() {
    _settings.removeListener(_aoMudarConfiguracao);
    _semantica?.dispose();
    _tts?.stop();
    super.dispose();
  }

  bool get _algumAtivo => _settings.leituraVozAlta || _settings.libras;

  /// Liga a árvore de semântica só enquanto algum recurso está ativo (ela
  /// tem custo); desligando, para a fala e fecha o painel.
  void _aoMudarConfiguracao() {
    if (_algumAtivo) {
      _semantica ??= SemanticsBinding.instance.ensureSemantics();
    } else {
      _semantica?.dispose();
      _semantica = null;
    }
    if (!_settings.leituraVozAlta && _falando) unawaited(_parar());
    if (!_settings.libras && _textosLibras != null) {
      setState(() => _textosLibras = null);
    }
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------ textos

  /// Textos visíveis da tela de cima, na ordem da árvore de semântica.
  Future<List<String>> _textosDaTela() async {
    var textos = _coletar();
    if (textos.isEmpty) {
      // A semântica acabou de ser ligada: espera um quadro e tenta de novo.
      await WidgetsBinding.instance.endOfFrame;
      textos = _coletar();
    }
    return textos;
  }

  List<String> _coletar() {
    const ignorar = {
      _rotuloOuvir,
      _rotuloParar,
      _rotuloLibras,
      _rotuloFecharLibras,
    };
    final textos = <String>[];
    void adicionar(String t) {
      final limpo = t.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (limpo.isEmpty || ignorar.contains(limpo)) return;
      if (textos.isNotEmpty && textos.last == limpo) return;
      textos.add(limpo);
    }

    void visitar(SemanticsNode no) {
      if (no.isInvisible) return;
      final d = no.getSemanticsData();
      adicionar(d.label);
      adicionar(d.value);
      adicionar(d.tooltip);
      no.visitChildren((filho) {
        visitar(filho);
        return true;
      });
    }

    for (final view in RendererBinding.instance.renderViews) {
      final raiz = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (raiz != null) visitar(raiz);
    }
    return textos;
  }

  // ------------------------------------------------------- voz alta

  Future<FlutterTts> _motorVoz() async {
    final existente = _tts;
    if (existente != null) return existente;
    final tts = FlutterTts();
    await tts.setLanguage('pt-BR');
    await tts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
    await tts.awaitSpeakCompletion(true);
    _tts = tts;
    return tts;
  }

  Future<void> _lerTela() async {
    if (_falando) return _parar();
    final textos = await _textosDaTela();
    if (textos.isEmpty) return;
    setState(() {
      _falando = true;
      _cancelado = false;
    });
    try {
      final tts = await _motorVoz();
      // Fala um trecho por vez: o Android limita o tamanho de cada fala.
      for (final trecho in _trechos(textos)) {
        if (_cancelado || !mounted) break;
        await tts.speak(trecho);
      }
    } catch (e) {
      debugPrint('Leitura em voz alta: $e');
    } finally {
      if (mounted) setState(() => _falando = false);
    }
  }

  Iterable<String> _trechos(List<String> textos) sync* {
    final buffer = StringBuffer();
    for (final t in textos) {
      final frase = RegExp(r'[.!?:]$').hasMatch(t) ? t : '$t.';
      if (buffer.length + frase.length > 900) {
        yield buffer.toString();
        buffer.clear();
      }
      buffer.write('$frase ');
    }
    if (buffer.isNotEmpty) yield buffer.toString();
  }

  Future<void> _parar() async {
    _cancelado = true;
    await _tts?.stop();
    if (mounted) setState(() => _falando = false);
  }

  // ------------------------------------------------------------ Libras

  Future<void> _abrirLibras() async {
    if (_textosLibras != null) {
      setState(() => _textosLibras = null);
      return;
    }
    if (_falando) await _parar();
    final textos = await _textosDaTela();
    if (!mounted) return;
    setState(() => _textosLibras = textos);
  }

  // ------------------------------------------------------------- tela

  @override
  Widget build(BuildContext context) {
    if (!_algumAtivo) return const SizedBox.shrink();
    final mq = MediaQuery.of(context);
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (_textosLibras != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: mq.size.height * 0.62,
              child: _PainelLibras(
                textos: _textosLibras!,
                rotuloFechar: _rotuloFecharLibras,
                aoFechar: () => setState(() => _textosLibras = null),
              ),
            ),
          Positioned(
            left: 12,
            bottom: mq.padding.bottom + 92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_settings.leituraVozAlta)
                  _BotaoRedondo(
                    icone: _falando
                        ? Icons.stop_rounded
                        : Icons.volume_up_rounded,
                    rotulo: _falando ? _rotuloParar : _rotuloOuvir,
                    aoTocar: _lerTela,
                  ),
                if (_settings.leituraVozAlta && _settings.libras)
                  const SizedBox(height: 10),
                if (_settings.libras && _textosLibras == null)
                  _BotaoRedondo(
                    icone: Icons.sign_language_rounded,
                    rotulo: _rotuloLibras,
                    aoTocar: _abrirLibras,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotaoRedondo extends StatelessWidget {
  const _BotaoRedondo({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: rotulo,
      child: Semantics(
        button: true,
        label: rotulo,
        excludeSemantics: true,
        child: Material(
          color: _AssistenteAcessibilidadeState._azul,
          shape: const CircleBorder(),
          elevation: 6,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: aoTocar,
            child: SizedBox(
              width: 52,
              height: 52,
              child: Icon(icone, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

/// Painel com o VLibras. O avatar abre sozinho e traduz o primeiro texto;
/// tocando em outro parágrafo, traduz aquele.
class _PainelLibras extends StatefulWidget {
  const _PainelLibras({
    required this.textos,
    required this.rotuloFechar,
    required this.aoFechar,
  });

  final List<String> textos;
  final String rotuloFechar;
  final VoidCallback aoFechar;

  @override
  State<_PainelLibras> createState() => _PainelLibrasState();
}

class _PainelLibrasState extends State<_PainelLibras> {
  WebViewController? _web;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..loadHtmlString(_html(widget.textos), baseUrl: 'https://vlibras.gov.br');
    }
  }

  static String _html(List<String> textos) {
    const esc = HtmlEscape();
    final paragrafos = textos.isEmpty
        ? '<p>Esta tela não tem textos para traduzir.</p>'
        : textos.map((t) => '<p>${esc.convert(t)}</p>').join();
    return '''
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { font-family: sans-serif; font-size: 18px; color: #1A1A1A;
         margin: 0; padding: 12px 16px 260px; }
  p { margin: 0 0 10px; padding: 10px 12px; border-radius: 10px;
      background: #F1F5F9; }
  .dica { background: #E0F2FE; color: #075985; font-size: 15px; }
</style>
</head>
<body>
<p class="dica">Toque em um texto para o avatar traduzir para Libras.</p>
<div id="textos">$paragrafos</div>
<div vw class="enabled">
  <div vw-access-button class="active"></div>
  <div vw-plugin-wrapper><div class="vw-plugin-top-wrapper"></div></div>
</div>
<script src="https://vlibras.gov.br/app/vlibras-plugin.js"></script>
<script>
  new window.VLibras.Widget('https://vlibras.gov.br/app');
  window.addEventListener('load', function () {
    setTimeout(function () {
      var botao = document.querySelector('[vw-access-button]');
      if (botao) botao.click();
      setTimeout(function () {
        var primeiro = document.querySelector('#textos p');
        if (primeiro) primeiro.click();
      }, 4000);
    }, 1500);
  });
</script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 16,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: _AssistenteAcessibilidadeState._azul,
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: [
                const Icon(Icons.sign_language_rounded, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Libras (VLibras)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: widget.rotuloFechar,
                  onPressed: widget.aoFechar,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: _web == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'A tradução em Libras funciona no app do celular.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : WebViewWidget(controller: _web!),
          ),
        ],
      ),
    );
  }
}
