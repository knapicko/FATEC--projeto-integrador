import 'package:flutter/material.dart';

/// Ondas de "sonar" saindo de um marcador do mapa (bolinha do profissional
/// no Radar do cliente / bolinha do pedido no Radar do profissional).
///
/// O [child] fica no centro; as ondas crescem de [tamanho] até
/// [tamanho] * [alcance] e somem. Com "reduzir animações" ligado (sistema ou
/// configurações do app) fica só um halo parado.
class SonarPulso extends StatefulWidget {
  const SonarPulso({
    super.key,
    required this.child,
    required this.cor,
    required this.tamanho,
    this.alcance = 2.2,
    this.ondas = 2,
    this.duracao = const Duration(milliseconds: 2200),
    this.atraso = Duration.zero,
  });

  final Widget child;
  final Color cor;

  /// Diâmetro do [child].
  final double tamanho;

  /// Diâmetro máximo da onda em relação a [tamanho].
  final double alcance;
  final int ondas;
  final Duration duracao;

  /// Defasagem para os marcadores não pulsarem todos juntos.
  final Duration atraso;

  @override
  State<SonarPulso> createState() => _SonarPulsoState();
}

class _SonarPulsoState extends State<SonarPulso>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duracao,
  );

  @override
  void initState() {
    super.initState();
    final inicio = widget.duracao.inMilliseconds == 0
        ? 0.0
        : (widget.atraso.inMilliseconds % widget.duracao.inMilliseconds) /
              widget.duracao.inMilliseconds;
    _c.value = inicio;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lado = widget.tamanho * widget.alcance;
    final parado = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: lado,
      height: lado,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: parado
                ? Container(
                    width: widget.tamanho * 1.45,
                    height: widget.tamanho * 1.45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.cor.withValues(alpha: 0.18),
                    ),
                  )
                : CustomPaint(
                    size: Size.square(lado),
                    painter: _OndasPainter(
                      progresso: _c,
                      cor: widget.cor,
                      raioMin: widget.tamanho / 2,
                      raioMax: lado / 2,
                      ondas: widget.ondas,
                    ),
                  ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _OndasPainter extends CustomPainter {
  _OndasPainter({
    required this.progresso,
    required this.cor,
    required this.raioMin,
    required this.raioMax,
    required this.ondas,
  }) : super(repaint: progresso);

  final Animation<double> progresso;
  final Color cor;
  final double raioMin;
  final double raioMax;
  final int ondas;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    for (var i = 0; i < ondas; i++) {
      final t = (progresso.value + i / ondas) % 1.0;
      final curva = Curves.easeOutCubic.transform(t);
      final raio = raioMin + (raioMax - raioMin) * curva;
      final opacidade = (1 - t) * 0.55;
      canvas.drawCircle(
        centro,
        raio,
        Paint()..color = cor.withValues(alpha: opacidade * 0.45),
      );
      canvas.drawCircle(
        centro,
        raio,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = cor.withValues(alpha: opacidade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OndasPainter old) =>
      old.cor != cor || old.raioMin != raioMin || old.raioMax != raioMax;
}
