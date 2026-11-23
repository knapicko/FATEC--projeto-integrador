import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'caixa_tutorial.dart';
import 'tutorial_visto.dart';

/// Um balão do tutorial.
///
/// - [alvo] / [alvoRect]: o que fica em destaque (sem desfoque). Sem alvo, a
///   caixa fala no meio da tela, com tudo desfocado.
/// - [antes]: roda antes do balão (abrir um bottom sheet, trocar de tela...).
/// - [rolagem]: rola até o alvo (a caixa acompanha a descida).
/// - [ilustracao]: desenho animado mostrado junto da caixa.
/// - [ehFinal]: para onde o "Pular" leva.
class PassoTutorial {
  const PassoTutorial(
    this.texto, {
    this.alvo,
    this.alvoRect,
    this.folga = 8,
    this.raio = 18,
    this.antes,
    this.rolagem,
    this.alinhamentoRolagem = 0.3,
    this.ilustracao,
    this.ehFinal = false,
    this.apenasAoPular = false,
  });

  final String texto;
  final GlobalKey? alvo;
  final Rect? Function()? alvoRect;
  final double folga;
  final double raio;
  final Future<void> Function()? antes;
  final ScrollController? rolagem;
  final double alinhamentoRolagem;
  final Widget? ilustracao;
  final bool ehFinal;

  /// Só aparece quando a pessoa toca em "Pular" (fim de uma parte do
  /// tutorial que continua em outra tela).
  final bool apenasAoPular;
}

enum ResultadoTutorial { concluido, pulado, naoMostrado, interrompido }

/// Caixa (RenderBox) de uma parte marcada; aceita também seções de listas
/// com slivers (usa a caixa de dentro).
RenderBox? caixaDoAlvo(GlobalKey chave) {
  final ro = chave.currentContext?.findRenderObject();
  if (ro is RenderBox) return ro;
  if (ro is RenderSliverSingleBoxAdapter) return ro.child;
  return null;
}

/// Fala final padrão (o "Pular" sempre termina nela).
const String kFalaFinalTutorial =
    'Pronto! Se precisar de ajuda depois, é só tocar no botão de tutorial '
    'que eu explico tudo de novo.';

/// Último balão (o "Pular" sempre termina nele).
PassoTutorial passoFinalTutorial({
  String texto = kFalaFinalTutorial,
  bool apenasAoPular = false,
}) => PassoTutorial(texto, ehFinal: true, apenasAoPular: apenasAoPular);

class Tutorial {
  Tutorial._();

  static bool _aberto = false;

  /// Resultado do último tutorial mostrado.
  static ResultadoTutorial? ultimoResultado;

  /// Algum tutorial está na tela agora.
  static bool get aberto => _aberto;

  /// Mostra o tutorial [chave] (uma vez por conta, a não ser [forcar]).
  /// [marcarVisto] = false deixa para quem chama marcar no fim (tutoriais
  /// em várias partes, que atravessam telas).
  static Future<ResultadoTutorial> mostrar(
    BuildContext context, {
    required String chave,
    required List<PassoTutorial> passos,
    bool forcar = false,
    bool marcarVisto = true,
    bool comEntrada = true,
    bool pularParaFinal = false,
  }) async {
    if (passos.isEmpty || _aberto) return ResultadoTutorial.naoMostrado;
    try {
      await CaixaTutorial.precarregar();
    } catch (e) {
      debugPrint('[tutorial] imagens da caixa: $e');
    }
    if (!forcar && await TutorialVisto.jaViu(chave)) {
      return ResultadoTutorial.naoMostrado;
    }
    if (!context.mounted) return ResultadoTutorial.naoMostrado;
    final overlay = Overlay.of(context, rootOverlay: true);
    // Se a tela sair (ex.: voltar do Android), o tutorial fecha junto.
    final rota = ModalRoute.of(context);
    final fim = Completer<ResultadoTutorial>();
    late final OverlayEntry entrada;
    _aberto = true;
    entrada = OverlayEntry(
      builder: (_) => _TutorialOverlay(
        passos: passos,
        rota: rota,
        comEntrada: comEntrada,
        pularParaFinal: pularParaFinal,
        aoTerminar: (r) {
          entrada.remove();
          _aberto = false;
          if (!fim.isCompleted) fim.complete(r);
        },
      ),
    );
    overlay.insert(entrada);
    final r = await fim.future;
    ultimoResultado = r;
    // Interrompido (a tela saiu no meio): aparece de novo depois.
    if (marcarVisto && r != ResultadoTutorial.interrompido) {
      await TutorialVisto.marcar(chave);
    }
    return r;
  }

  /// Mostra na primeira visita da tela (chama depois do primeiro quadro).
  static void naPrimeiraVisita(
    State state, {
    required String chave,
    required List<PassoTutorial> Function() passos,
    Duration atraso = const Duration(milliseconds: 700),
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(atraso);
      if (!state.mounted) return;
      if (await TutorialVisto.jaViu(chave)) return;
      if (!state.mounted) return;
      await mostrar(state.context, chave: chave, passos: passos());
    });
  }

  /// Retângulo de um item da barra inferior (para destacar uma aba).
  static Rect? Function() itemBarra(
    GlobalKey barra, {
    required int indice,
    required int total,
  }) {
    return () {
      final box = barra.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return null;
      final topo = box.localToGlobal(Offset.zero);
      final ctx = barra.currentContext!;
      final inferior = MediaQuery.of(ctx).viewPadding.bottom;
      final altura = kBottomNavigationBarHeight;
      final largura = box.size.width / total;
      final y = topo.dy + box.size.height - inferior - altura;
      return Rect.fromLTWH(topo.dx + largura * indice, y, largura, altura);
    };
  }
}

class _TutorialOverlay extends StatefulWidget {
  const _TutorialOverlay({
    required this.passos,
    required this.rota,
    required this.comEntrada,
    required this.pularParaFinal,
    required this.aoTerminar,
  });

  final List<PassoTutorial> passos;
  final ModalRoute<dynamic>? rota;
  final bool comEntrada;

  /// Só o fluxo de apresentação da home: "Pular" leva à fala final. Nos
  /// outros, "Pular" encerra na hora (com a animação de saída).
  final bool pularParaFinal;
  final void Function(ResultadoTutorial) aoTerminar;

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay>
    with TickerProviderStateMixin {
  static const _azul = Color(0xFF0FB3FF);
  static const _tamCaixa = 170.0;

  /// Entrada: a caixa surge (cresce de um ponto) e dá um pulinho.
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// Saída: a caixa pula e some (encolhe até um ponto, girando no lugar).
  late final AnimationController _saida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  );
  late final Ticker _ticker;

  int _indice = 0;
  int _pulos = 0;
  bool _ocupado = true; // rodando "antes" / rolando
  bool _pulou = false;
  bool _terminando = false;

  String _mostrado = '';
  Timer? _digitacao;
  bool get _digitando => _digitacao != null;

  Rect? _alvo; // atual (medido a cada quadro)
  Rect? _furo; // exibido (suavizado)
  // A caixa é a âncora (posição suavizada); o balão fica preso em cima
  // dela. Assim nada "pula" quando o balão muda de tamanho.
  double _yCaixa = -1;
  double _xCaixa = -1;
  final _conteudoKey = GlobalKey();
  double _alturaConteudo = 160;
  // Canto do "Pular" (0 embaixo à direita, 1 em cima à direita,
  // 2 embaixo à esquerda, 3 em cima à esquerda).
  int _cantoPular = 0;

  /// Brilho azul atrás da caixa (0 → 1): aparece quando ela está em cima da
  /// área destacada, para a caixa não se misturar com o que está embaixo.
  double _halo = 0;
  Duration _ultimo = Duration.zero;

  PassoTutorial get _passo => widget.passos[_indice];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_quadro)..start();
    _entrada.forward();
    _irPara(0, primeiro: true);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _digitacao?.cancel();
    _entrada.dispose();
    _saida.dispose();
    super.dispose();
  }

  // ── Medidas a cada quadro (a caixa acompanha a rolagem) ───────────────────

  Rect? _medirAlvo() {
    final p = _passo;
    Rect? r;
    if (p.alvoRect != null) {
      r = p.alvoRect!();
    } else if (p.alvo != null) {
      final box = caixaDoAlvo(p.alvo!);
      if (box != null && box.hasSize && box.attached) {
        r = box.localToGlobal(Offset.zero) & box.size;
      }
    }
    return r?.inflate(p.folga);
  }

  void _quadro(Duration agora) {
    if (!mounted) return;
    final rota = widget.rota;
    if (rota != null && !rota.isActive && !_terminando) {
      _terminar(ResultadoTutorial.interrompido);
      return;
    }
    final dt = _ultimo == Duration.zero
        ? 0.016
        : (agora - _ultimo).inMicroseconds / 1e6;
    _ultimo = agora;
    // Suavização independente da taxa de quadros.
    final k = 1 - math.pow(0.0009, dt).toDouble();

    _alvo = _medirAlvo();
    final cont = _conteudoKey.currentContext?.findRenderObject() as RenderBox?;
    if (cont != null && cont.hasSize) _alturaConteudo = cont.size.height;
    final tela = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    const t = _tamCaixa;

    // Furo do destaque.
    final destino = _alvo;
    if (destino == null) {
      _furo = _furo == null
          ? null
          : Rect.lerp(_furo, _furo!.center & Size.zero, k);
      if (_furo != null && _furo!.width < 2) _furo = null;
    } else {
      _furo = _furo == null ? destino : Rect.lerp(_furo, destino, k);
    }

    // Caixa: sem alvo, no meio; com alvo, o conjunto (balão + caixa) fica
    // embaixo dele ou, sem espaço, em cima (a caixa colada no alvo).
    final hc = _alturaConteudo;
    double yAlvo;
    if (destino == null) {
      yAlvo = (tela.height - hc - t) * 0.45 + hc;
    } else {
      final abaixo = tela.height - pad.bottom - 12 - destino.bottom;
      final acima = destino.top - pad.top - 12;
      final precisa = hc + t + 10;
      yAlvo = abaixo >= precisa || abaixo >= acima
          ? destino.bottom + 10 + hc
          : destino.top - 10 - t;
    }
    yAlvo = yAlvo.clamp(pad.top + 8 + hc, tela.height - pad.bottom - t - 8);
    _yCaixa = _yCaixa < 0 ? yAlvo : _yCaixa + (yAlvo - _yCaixa) * k;

    final xDestino = destino == null
        ? (tela.width - t) / 2
        : (destino.center.dx - t / 2).clamp(12.0, tela.width - t - 12);
    _xCaixa = _xCaixa < 0 ? xDestino : _xCaixa + (xDestino - _xCaixa) * k;

    final caixaRect = Rect.fromLTWH(_xCaixa, _yCaixa, t, t).deflate(t * 0.15);
    final sobreDestaque = _furo != null && caixaRect.overlaps(_furo!);
    _halo += ((sobreDestaque ? 1.0 : 0.0) - _halo) * k;
    _escolherCantoPular(tela, pad);
    setState(() {});
  }

  static const _tamPular = Size(112, 44);

  Rect _rectPular(int canto, Size tela, EdgeInsets pad) {
    final direita = canto == 0 || canto == 1;
    final embaixo = canto == 0 || canto == 2;
    final x = direita ? tela.width - 16 - _tamPular.width : 16.0;
    final y = embaixo
        ? tela.height - pad.bottom - 16 - _tamPular.height
        : pad.top + 12;
    return Offset(x, y) & _tamPular;
  }

  void _escolherCantoPular(Size tela, EdgeInsets pad) {
    final ocupados = [
      Rect.fromLTWH(_xCaixa, _yCaixa, _tamCaixa, _tamCaixa),
      Rect.fromLTWH(0, _yCaixa - _alturaConteudo, tela.width, _alturaConteudo),
      ?_furo,
    ];
    double sobra(int c) {
      final r = _rectPular(c, tela, pad).inflate(6);
      var area = 0.0;
      for (final o in ocupados) {
        final i = r.intersect(o);
        if (i.width > 0 && i.height > 0) area += i.width * i.height;
      }
      return area;
    }

    // Fica onde está enquanto o canto estiver livre (sem trocar à toa).
    if (sobra(_cantoPular) == 0) return;
    var melhor = _cantoPular;
    var menor = sobra(_cantoPular);
    for (final c in [0, 1, 2, 3]) {
      final a = sobra(c);
      if (a < menor) {
        menor = a;
        melhor = c;
      }
    }
    _cantoPular = melhor;
  }

  // ── Passos ────────────────────────────────────────────────────────────────

  Future<void> _irPara(int i, {bool primeiro = false}) async {
    _digitacao?.cancel();
    _digitacao = null;
    setState(() {
      _indice = i;
      _ocupado = true;
      _mostrado = '';
    });
    // Primeiro balão só depois da caixa surgir.
    if (primeiro) {
      await Future<void>.delayed(const Duration(milliseconds: 820));
    }
    final p = widget.passos[i];
    try {
      await p.antes?.call();
    } catch (e) {
      debugPrint('[tutorial] antes: $e');
    }
    await _garantirVisivel(p);
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _pulos++;
    });
    HapticFeedback.selectionClick();
    _digitar(p.texto);
  }

  /// Rola até o alvo; se ele ainda não foi construído (listas longas), desce
  /// aos poucos até aparecer. A caixa acompanha porque mede a cada quadro.
  Future<void> _garantirVisivel(PassoTutorial p) async {
    final chave = p.alvo;
    if (chave == null) return;
    for (var tentativa = 0; tentativa < 14; tentativa++) {
      final ctx = chave.currentContext;
      if (ctx != null && ctx.mounted) {
        try {
          // Contexto lido agora (não atravessou nenhum await).
          // ignore: use_build_context_synchronously
          await Scrollable.ensureVisible(
            ctx,
            alignment: p.alinhamentoRolagem,
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
          );
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 120));
        return;
      }
      final c = p.rolagem;
      if (c == null || !c.hasClients) return;
      final pos = c.position;
      if (pos.pixels >= pos.maxScrollExtent) return;
      await c.animateTo(
        math.min(pos.pixels + 420, pos.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  void _digitar(String texto) {
    var n = 0;
    _digitacao = Timer.periodic(const Duration(milliseconds: 22), (t) {
      if (!mounted) return t.cancel();
      n += 1;
      if (n >= texto.length) {
        t.cancel();
        setState(() {
          _mostrado = texto;
          _digitacao = null;
        });
        return;
      }
      setState(() => _mostrado = texto.substring(0, n));
    });
  }

  void _tocar() {
    if (_ocupado || _terminando) return;
    if (_digitando) {
      _digitacao?.cancel();
      setState(() {
        _digitacao = null;
        _mostrado = _passo.texto;
      });
      return;
    }
    final proximo = _proximo(_indice);
    if (proximo >= widget.passos.length || (_pulou && _passo.ehFinal)) {
      _terminar(
        _pulou ? ResultadoTutorial.pulado : ResultadoTutorial.concluido,
      );
      return;
    }
    _irPara(proximo);
  }

  /// Próximo balão do fluxo normal (pula os que são só do "Pular").
  int _proximo(int i) {
    var j = i + 1;
    while (j < widget.passos.length && widget.passos[j].apenasAoPular) {
      j++;
    }
    return j;
  }

  void _pular() {
    if (_terminando) return;
    _pulou = true;
    if (!widget.pularParaFinal) {
      _terminar(ResultadoTutorial.pulado);
      return;
    }
    final finalIdx = widget.passos.indexWhere((p) => p.ehFinal);
    if (finalIdx < 0 || finalIdx == _indice) {
      _terminar(ResultadoTutorial.pulado);
      return;
    }
    _irPara(finalIdx);
  }

  Future<void> _terminar(ResultadoTutorial r) async {
    _terminando = true;
    _digitacao?.cancel();
    _digitacao = null;
    HapticFeedback.lightImpact();
    await _saida.forward();
    widget.aoTerminar(r);
  }

  // ── Caixa: surge crescendo e, no fim, pula e some ───────────────────────

  Widget _caixaAnimada() {
    const t = _tamCaixa;
    double fase(double v, double a, double b) =>
        ((v - a) / (b - a)).clamp(0.0, 1.0);

    // Entrada: a caixa surge crescendo de um ponto, com um pulinho.
    final e = _entrada.value;
    final cresce = Curves.easeOutBack.transform(fase(e, 0.18, 0.62));
    final puloE = -math.sin(math.pi * fase(e, 0.18, 0.78)) * t * 0.22;

    // Saída: agacha, pula, volta e encolhe até sumir (girando no lugar).
    final s = _saida.value;
    final agacha = math.sin(math.pi * fase(s, 0, 0.18)) * 0.16;
    final puloS = -math.sin(math.pi * fase(s, 0.14, 0.5)) * t * 0.36;
    final encolhe = Curves.easeInCubic.transform(fase(s, 0.44, 0.7));
    final giroS = Curves.easeIn.transform(fase(s, 0.44, 0.7)) * math.pi * 0.9;
    final estica = math.sin(math.pi * fase(s, 0.44, 0.7)) * 0.2;

    final escala = cresce * (1 - encolhe);
    final y = puloE + puloS;

    return SizedBox(
      width: t,
      height: t,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Transform.translate(
            offset: Offset(0, y),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..rotateZ(giroS)
                ..scaleByDouble(
                  escala * (1 + agacha - estica * 0.5),
                  escala * (1 - agacha + estica),
                  1,
                  1,
                ),
              child: CaixaTutorial(
                falando: _digitando,
                pulos: _pulos,
                tamanho: t,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tela = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    final entrada = Curves.easeOut.transform(
      (_entrada.value / 0.45).clamp(0.0, 1.0),
    );
    // O fundo some no fim da saída (depois da caixa sumir).
    final saida =
        1 - Curves.easeIn.transform(((_saida.value - 0.6) / 0.4).clamp(0, 1));
    final visivel = entrada * saida;
    // O balão só aparece depois que a caixa surgiu e some logo na saída.
    final balaoVisivel =
        (1 - (_saida.value * 5).clamp(0.0, 1.0)) *
        ((_entrada.value - 0.5) / 0.3).clamp(0.0, 1.0);
    final furo = _furo;
    final ultimo =
        _proximo(_indice) >= widget.passos.length || (_pulou && _passo.ehFinal);
    final pularRect = _rectPular(_cantoPular, tela, pad);
    final posicionado = _yCaixa >= 0;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Só desfoque (sem cor), com o furo do destaque.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tocar,
              child: ClipPath(
                clipper: _Furo(furo, _passo.raio),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: 6 * visivel,
                    sigmaY: 6 * visivel,
                  ),
                  child: ColoredBox(
                    color: const Color(
                      0xFFD9DDE3,
                    ).withValues(alpha: 0.5 * visivel),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
          // Contorno do destaque (o toque passa para o tutorial).
          if (furo != null)
            Positioned.fromRect(
              rect: furo,
              child: IgnorePointer(
                child: Opacity(
                  opacity: visivel,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_passo.raio),
                      border: Border.all(color: Colors.white, width: 2.2),
                    ),
                  ),
                ),
              ),
            ),
          if (furo != null)
            Positioned.fromRect(
              rect: furo,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tocar,
              ),
            ),
          if (posicionado) ...[
            // Ilustração + balão, presos em cima da caixa.
            Positioned(
              left: 0,
              right: 0,
              bottom: tela.height - _yCaixa - 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tocar,
                child: Column(
                  key: _conteudoKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.bottomCenter,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child:
                            _ocupado || _terminando || _passo.ilustracao == null
                            ? const SizedBox(key: ValueKey('sem'), width: 1)
                            : Padding(
                                key: ValueKey('il$_indice'),
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _passo.ilustracao,
                              ),
                      ),
                    ),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      opacity: _ocupado ? 0 : balaoVisivel,
                      child: _Balao(
                        texto: _mostrado,
                        textoCompleto: _passo.texto,
                        ultimo: ultimo,
                        digitando: _digitando,
                        xSeta: _xCaixa + _tamCaixa / 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Brilho azul fraco atrás da caixa (sobre o destaque).
            if (_halo > 0.01)
              Positioned(
                left: _xCaixa - _tamCaixa * 0.2,
                top: _yCaixa - _tamCaixa * 0.2,
                width: _tamCaixa * 1.4,
                height: _tamCaixa * 1.4,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _azul.withValues(alpha: 0.42 * _halo * visivel),
                          _azul.withValues(alpha: 0.18 * _halo * visivel),
                          _azul.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            // A caixa.
            Positioned(
              left: _xCaixa,
              top: _yCaixa,
              width: _tamCaixa,
              height: _tamCaixa,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tocar,
                child: _caixaAnimada(),
              ),
            ),
          ],
          // Pular: num canto livre (nunca em cima do balão, da caixa ou do
          // destaque); muda de canto deslizando.
          AnimatedPositioned(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeInOutCubic,
            left: pularRect.left,
            top: pularRect.top,
            width: pularRect.width,
            height: pularRect.height,
            child: IgnorePointer(
              ignoring: ultimo || _terminando,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: ultimo || _terminando ? 0 : visivel,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(22),
                  elevation: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _pular,
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Pular',
                            style: TextStyle(
                              color: _azul,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.fast_forward_rounded,
                            color: _azul,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Balão de fala com a ponta apontando para a caixa.
class _Balao extends StatelessWidget {
  const _Balao({
    required this.texto,
    required this.textoCompleto,
    required this.ultimo,
    required this.digitando,
    required this.xSeta,
  });

  final String texto;
  final String textoCompleto;
  final bool ultimo;
  final bool digitando;
  final double xSeta;

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    final maxW = math.min(largura - 32, 340.0);
    final esquerda = (largura - maxW) / 2;
    return SizedBox(
      width: largura,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: maxW,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // O texto completo invisível reserva o tamanho: o balão não
                // cresce letra por letra.
                Stack(
                  children: [
                    Opacity(
                      opacity: 0,
                      child: Text(textoCompleto, style: _estilo),
                    ),
                    Text(texto, style: _estilo),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: digitando ? 0 : 1,
                    child: Text(
                      ultimo ? 'Toque para fechar ✓' : 'Toque para continuar ›',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: largura,
            height: 12,
            child: Stack(
              children: [
                Positioned(
                  left: (xSeta - 12).clamp(esquerda + 16, esquerda + maxW - 40),
                  top: 0,
                  child: CustomPaint(
                    size: const Size(24, 12),
                    painter: _Ponta(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _estilo = TextStyle(
    color: Color(0xFF0F172A),
    fontSize: 15.5,
    height: 1.38,
    fontWeight: FontWeight.w600,
  );
}

class _Ponta extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tela inteira menos o furo arredondado do destaque.
class _Furo extends CustomClipper<Path> {
  _Furo(this.furo, this.raio);

  final Rect? furo;
  final double raio;

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (furo != null) {
      path.addRRect(RRect.fromRectAndRadius(furo!, Radius.circular(raio)));
      path.fillType = PathFillType.evenOdd;
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _Furo old) =>
      old.furo != furo || old.raio != raio;
}
