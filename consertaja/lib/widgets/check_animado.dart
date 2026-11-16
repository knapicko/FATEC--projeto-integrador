import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Ícone vetorial de "concluído" (círculo + check), desenhado como um SVG de
/// traço e animado como se estivesse sendo traçado:
///   1. o círculo se fecha no sentido horário, a partir do topo;
///   2. o check é desenhado da esquerda para a direita;
///   3. um leve "pulo" e um halo suave finalizam.
///
/// Usa [progresso] externo (0 → 1) quando a tela quer sincronizar outras
/// animações; senão anima sozinho ao aparecer. Com "reduzir animações"
/// ligado, aparece pronto.
class CheckAnimado extends StatefulWidget {
  const CheckAnimado({
    super.key,
    this.tamanho = 200,
    this.cor = Colors.white,
    this.progresso,
    this.duracao = const Duration(milliseconds: 1500),
  });

  final double tamanho;
  final Color cor;
  final Animation<double>? progresso;
  final Duration duracao;

  /// Fração da animação em que o círculo termina e o check começa.
  static const double fimCirculo = 0.55;
  static const double fimCheck = 0.85;

  @override
  State<CheckAnimado> createState() => _CheckAnimadoState();
}

class _CheckAnimadoState extends State<CheckAnimado>
    with SingleTickerProviderStateMixin {
  AnimationController? _interno;

  Animation<double> get _anim => widget.progresso ?? _interno!;

  @override
  void initState() {
    super.initState();
    if (widget.progresso == null) {
      _interno = AnimationController(vsync: this, duration: widget.duracao);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = _interno;
    if (c == null) return;
    if (MediaQuery.of(context).disableAnimations) {
      c.value = 1;
    } else if (!c.isAnimating && c.value == 0) {
      c.forward();
    }
  }

  @override
  void dispose() {
    _interno?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Concluído',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _anim,
          builder: (context, _) {
            final t = _anim.value;
            // Pulo no final: 1 → 1.08 → 1.
            final pulo = t <= CheckAnimado.fimCheck
                ? 1.0
                : 1 +
                      0.08 *
                          math.sin(
                            ((t - CheckAnimado.fimCheck) /
                                    (1 - CheckAnimado.fimCheck)) *
                                math.pi,
                          );
            return Transform.scale(
              scale: pulo,
              child: CustomPaint(
                size: Size.square(widget.tamanho),
                painter: _CheckPainter(progresso: t, cor: widget.cor),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progresso, required this.cor});

  final double progresso;
  final Color cor;

  double _faixa(double inicio, double fim, Curve curva) {
    final v = ((progresso - inicio) / (fim - inicio)).clamp(0.0, 1.0);
    return curva.transform(v);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    final traco = lado * 0.065;
    final centro = size.center(Offset.zero);
    final raio = lado / 2 - traco;

    final pincel = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = traco
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Halo suave depois que tudo foi desenhado.
    final halo = _faixa(CheckAnimado.fimCheck, 1, Curves.easeOut);
    if (halo > 0) {
      canvas.drawCircle(
        centro,
        raio + traco * (0.5 + 1.2 * halo),
        Paint()
          ..color = cor.withValues(alpha: 0.22 * (1 - halo * 0.5))
          ..style = PaintingStyle.stroke
          ..strokeWidth = traco * 0.6,
      );
    }

    // 1) Círculo: do topo, sentido horário.
    final pCirculo = _faixa(0, CheckAnimado.fimCirculo, Curves.easeInOutCubic);
    if (pCirculo > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: raio),
        -math.pi / 2,
        2 * math.pi * pCirculo,
        false,
        pincel,
      );
    }

    // 2) Check: traçado pelo próprio caminho (como um stroke de SVG).
    final pCheck = _faixa(
      CheckAnimado.fimCirculo - 0.05,
      CheckAnimado.fimCheck,
      Curves.easeOutCubic,
    );
    if (pCheck > 0) {
      final caminho = ui.Path()
        ..moveTo(centro.dx - raio * 0.42, centro.dy + raio * 0.02)
        ..lineTo(centro.dx - raio * 0.12, centro.dy + raio * 0.32)
        ..lineTo(centro.dx + raio * 0.45, centro.dy - raio * 0.30);
      for (final metrica in caminho.computeMetrics()) {
        canvas.drawPath(
          metrica.extractPath(0, metrica.length * pCheck),
          pincel,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progresso != progresso || old.cor != cor;
}
