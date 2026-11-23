import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/movimento.dart';

/// Camadas da caixa do tutorial (tool/gerar_caixa_tutorial.py): cada quadro
/// da fala sem as ferramentas + cada ferramenta separada (com o "contorno"
/// usado para vazar a linha em volta dela quando ela pula).
class _Camadas {
  _Camadas._();

  static const _pasta = 'assets/images/caixa/tutorial';
  static const bocas = ['fechada', 'meia', 'aberta', 'o'];
  static const ferramentas = 3; // chave inglesa, chave de fenda, martelo

  /// Centro de cada ferramenta na arte 500×500 (para girar em volta dele).
  static const centros = [
    Offset(143.6, 198.3),
    Offset(215.2, 226.1),
    Offset(287.8, 249.1),
  ];

  static const fundo = '$_pasta/fundo.png';
  static const mascara = '$_pasta/frente_mascara.png';

  static String frente({required bool olhosFechados, required String boca}) =>
      '$_pasta/frente_olhos_${olhosFechados ? 'fechados' : 'abertos'}'
      '_boca_$boca.png';

  static String ferramenta(int i) => '$_pasta/ferramenta_$i.png';
  static String contorno(int i) => '$_pasta/ferramenta_${i}_contorno.png';

  static List<String> get todas => [
    fundo,
    mascara,
    for (final f in [false, true])
      for (final b in bocas) frente(olhosFechados: f, boca: b),
    for (var i = 0; i < ferramentas; i++) ...[ferramenta(i), contorno(i)],
  ];

  static final Map<String, ui.Image> _cache = {};
  static Future<void>? _carregando;

  static bool get prontas => _cache.length == todas.length;

  static Future<void> carregar() => _carregando ??= () async {
    for (final caminho in todas) {
      final dados = await rootBundle.load(caminho);
      final codec = await ui.instantiateImageCodec(dados.buffer.asUint8List());
      _cache[caminho] = (await codec.getNextFrame()).image;
    }
  }();

  static ui.Image? img(String caminho) => _cache[caminho];
}

/// Caixa de ferramentas do tutorial (a mesma do onboarding):
/// - enquanto [falando], troca a boca, pisca e balança (igual ao onboarding);
/// - parada, pisca de vez em quando (olhos fechados por um instante);
/// - a cada novo balão ([pulos] muda) dá um pulinho: estica ao subir, amassa
///   ao cair, e as ferramentas pulam soltas, uma depois da outra, girando um
///   pouco (com a linha vazada em volta, como no desenho).
class CaixaTutorial extends StatefulWidget {
  const CaixaTutorial({
    super.key,
    required this.falando,
    required this.pulos,
    this.tamanho = 170,
  });

  final bool falando;
  final int pulos;
  final double tamanho;

  /// Carrega as camadas antes (o tutorial chama ao abrir).
  static Future<void> precarregar() => _Camadas.carregar();

  @override
  State<CaixaTutorial> createState() => _CaixaTutorialState();
}

class _CaixaTutorialState extends State<CaixaTutorial>
    with TickerProviderStateMixin {
  final _sorteio = math.Random();
  Timer? _fala;
  Timer? _piscada;
  String _boca = 'fechada';
  bool _olhosFechados = false;
  int _quadrosOlhos = 0;
  bool _pronto = _Camadas.prontas;

  late final AnimationController _tremor = AnimationController(
    vsync: this,
    duration: duracao(const Duration(milliseconds: 680)),
  );
  late final AnimationController _intensidade = AnimationController(
    vsync: this,
    duration: duracao(const Duration(milliseconds: 260)),
  );
  late final AnimationController _pulo = AnimationController(
    vsync: this,
    duration: duracao(const Duration(milliseconds: 900)),
  );

  @override
  void initState() {
    super.initState();
    _Camadas.carregar().then((_) {
      if (mounted) setState(() => _pronto = true);
    });
    _aplicarFala();
    _agendarPiscada();
  }

  @override
  void didUpdateWidget(covariant CaixaTutorial old) {
    super.didUpdateWidget(old);
    if (old.pulos != widget.pulos) _pulo.forward(from: 0);
    if (old.falando != widget.falando) _aplicarFala();
  }

  // ── Piscar parada ─────────────────────────────────────────────────────────

  void _agendarPiscada() {
    _piscada?.cancel();
    _piscada = Timer(
      Duration(milliseconds: 1800 + _sorteio.nextInt(2800)),
      _piscar,
    );
  }

  Future<void> _piscar() async {
    if (!mounted) return;
    if (_fala == null) {
      final duas = _sorteio.nextDouble() < 0.25; // às vezes pisca 2 vezes
      for (var i = 0; i < (duas ? 2 : 1); i++) {
        if (!mounted || _fala != null) break;
        setState(() => _olhosFechados = true);
        await Future<void>.delayed(const Duration(milliseconds: 130));
        if (!mounted || _fala != null) break;
        setState(() => _olhosFechados = false);
        if (duas) await Future<void>.delayed(const Duration(milliseconds: 110));
      }
    }
    if (mounted) _agendarPiscada();
  }

  // ── Fala ──────────────────────────────────────────────────────────────────

  void _aplicarFala() {
    if (widget.falando && _fala == null) {
      _quadrosOlhos = 6 + _sorteio.nextInt(10);
      _boca = 'meia';
      _olhosFechados = false;
      _fala = Timer.periodic(
        const Duration(milliseconds: 95),
        (_) => _proximoQuadro(),
      );
      _tremor.repetir();
      _intensidade.forward();
    } else if (!widget.falando && _fala != null) {
      _fala!.cancel();
      _fala = null;
      _intensidade.reverse().whenComplete(() {
        if (_fala == null && mounted) _tremor.stop();
      });
      if (mounted) {
        setState(() {
          _boca = 'fechada';
          _olhosFechados = false;
        });
      }
    }
  }

  void _proximoQuadro() {
    if (!mounted) return;
    const pesos = {'meia': 4, 'aberta': 4, 'o': 2, 'fechada': 2};
    final opcoes = [
      for (final e in pesos.entries)
        if (e.key != _boca)
          for (var i = 0; i < e.value; i++) e.key,
    ];
    var olhos = _olhosFechados;
    _quadrosOlhos--;
    if (_quadrosOlhos <= 0) {
      olhos = !olhos;
      _quadrosOlhos = olhos
          ? 2 + _sorteio.nextInt(4)
          : 8 + _sorteio.nextInt(16);
    }
    setState(() {
      _boca = opcoes[_sorteio.nextInt(opcoes.length)];
      _olhosFechados = olhos;
    });
  }

  @override
  void dispose() {
    _fala?.cancel();
    _piscada?.cancel();
    _tremor.dispose();
    _intensidade.dispose();
    _pulo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tamanho;
    return AnimatedBuilder(
      animation: Listenable.merge([_tremor, _intensidade, _pulo]),
      builder: (context, _) {
        // Balanço enquanto fala.
        final i = Curves.easeOut.transform(_intensidade.value);
        final tt = _tremor.value * 2 * math.pi;
        final giro = math.sin(tt) * 0.022 * i;
        final tremorY = -math.sin(tt * 2).abs() * 2.4 * i;
        final estica = math.sin(tt * 2 + 0.8) * 0.014 * i;

        // Pulo da caixa: sobe esticando, cai amassando.
        final p = _pulo.value;
        final fase = (p / 0.55).clamp(0.0, 1.0);
        final puloY = -math.sin(math.pi * fase) * t * 0.2;
        final subindo = fase < 0.5 ? math.sin(math.pi * fase) * 0.07 : 0.0;
        final amassa = p > 0.55 && p < 0.8
            ? math.sin(math.pi * (p - 0.55) / 0.25) * 0.1
            : 0.0;

        return SizedBox(
          width: t,
          height: t,
          child: Transform.translate(
            offset: Offset(0, puloY + tremorY),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..rotateZ(giro)
                ..scaleByDouble(
                  1 - estica * 0.6 + amassa - subindo * 0.5,
                  1 + estica - amassa + subindo,
                  1,
                  1,
                ),
              child: _pronto
                  ? CustomPaint(
                      size: Size(t, t),
                      painter: _PintaCaixa(
                        frente: _Camadas.img(
                          _Camadas.frente(
                            olhosFechados: _olhosFechados,
                            boca: _boca,
                          ),
                        ),
                        pulo: p,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class _PintaCaixa extends CustomPainter {
  _PintaCaixa({required this.frente, required this.pulo});

  final ui.Image? frente;
  final double pulo;

  // Cada ferramenta: atraso, altura (na arte 500) e giro máximo.
  static const _atrasos = [0.06, 0.14, 0.1];
  static const _alturas = [92.0, 74.0, 84.0];
  static const _giros = [-0.34, 0.18, 0.3];

  @override
  void paint(Canvas canvas, Size size) {
    final fr = frente;
    final fundo = _Camadas.img(_Camadas.fundo);
    final mascara = _Camadas.img(_Camadas.mascara);
    if (fr == null || fundo == null || mascara == null) return;
    final escala = size.width / 500;
    final area = Offset.zero & size;
    const origem = Rect.fromLTWH(0, 0, 500, 500);
    final apagar = Paint()..blendMode = BlendMode.dstOut;

    // Camadas, de trás para a frente:
    // 1. fundo (tampa + interior); 2. cada ferramenta, vazando a linha em
    // volta dela; 3. a silhueta da frente apaga o que fica atrás dela (a
    // parte das ferramentas "dentro" da caixa); 4. a frente com o rosto.
    void desenhar(Paint tinta, {required bool vazar}) {
      canvas.drawImageRect(fundo, origem, area, tinta);
      for (var i = 0; i < _Camadas.ferramentas; i++) {
        final fill = _Camadas.img(_Camadas.ferramenta(i));
        final cont = _Camadas.img(_Camadas.contorno(i));
        if (fill == null || cont == null) continue;
        final f = ((pulo - _atrasos[i]) / 0.6).clamp(0.0, 1.0);
        final sobe = math.sin(math.pi * f);
        final c = _Camadas.centros[i] * escala;
        canvas.save();
        canvas.translate(c.dx, c.dy - sobe * _alturas[i] * escala);
        canvas.rotate(sobe * _giros[i]);
        canvas.translate(-c.dx, -c.dy);
        if (vazar) canvas.drawImageRect(cont, origem, area, apagar);
        canvas.drawImageRect(fill, origem, area, tinta);
        canvas.restore();
      }
      if (vazar) canvas.drawImageRect(mascara, origem, area, apagar);
      canvas.drawImageRect(fr, origem, area, tinta);
    }

    // Sombra azul-escura suave atrás (a caixa branca aparece em qualquer
    // fundo).
    canvas.saveLayer(
      area.inflate(size.width * 0.4),
      Paint()
        ..colorFilter = const ColorFilter.mode(
          Color(0x660A6E9D),
          BlendMode.srcIn,
        )
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
    );
    canvas.translate(0, 4);
    desenhar(Paint(), vazar: false);
    canvas.restore();

    // A caixa numa camada própria (o "vazar" não fura o que está atrás).
    canvas.saveLayer(area.inflate(size.width * 0.4), Paint());
    desenhar(Paint(), vazar: true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PintaCaixa old) =>
      old.frente != frente || old.pulo != pulo;
}
