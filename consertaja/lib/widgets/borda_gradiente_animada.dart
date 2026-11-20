import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Borda fina com um gradiente que fica girando em volta do [child]
/// (indica que há uma solicitação em curso, na cor do status).
class BordaGradienteAnimada extends StatefulWidget {
  const BordaGradienteAnimada({
    super.key,
    required this.child,
    required this.cor,
    this.ativa = true,
    this.raio = 16,
    this.espessura = 2,
    this.duracao = const Duration(milliseconds: 2600),
  });

  final Widget child;
  final Color cor;
  final bool ativa;
  final double raio;
  final double espessura;
  final Duration duracao;

  @override
  State<BordaGradienteAnimada> createState() => _BordaGradienteAnimadaState();
}

class _BordaGradienteAnimadaState extends State<BordaGradienteAnimada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duracao,
  );

  @override
  void initState() {
    super.initState();
    if (widget.ativa) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant BordaGradienteAnimada old) {
    super.didUpdateWidget(old);
    if (widget.ativa && !_c.isAnimating) _c.repeat();
    if (!widget.ativa && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ativa) return widget.child;
    final reduzir = MediaQuery.of(context).disableAnimations;
    return CustomPaint(
      foregroundPainter: _PintorBorda(
        animacao: _c,
        cor: widget.cor,
        raio: widget.raio,
        espessura: widget.espessura,
        parada: reduzir,
      ),
      child: widget.child,
    );
  }
}

class _PintorBorda extends CustomPainter {
  _PintorBorda({
    required this.animacao,
    required this.cor,
    required this.raio,
    required this.espessura,
    required this.parada,
  }) : super(repaint: animacao);

  final Animation<double> animacao;
  final Color cor;
  final double raio;
  final double espessura;
  final bool parada;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(espessura / 2),
      Radius.circular(raio),
    );
    final angulo = parada ? 0.0 : animacao.value * 2 * math.pi;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura
      ..shader = SweepGradient(
        colors: [
          cor.withValues(alpha: 0.12),
          cor.withValues(alpha: 0.35),
          cor,
          cor.withValues(alpha: 0.35),
          cor.withValues(alpha: 0.12),
        ],
        stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
        transform: GradientRotation(angulo),
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _PintorBorda old) =>
      old.cor != cor || old.parada != parada;
}
