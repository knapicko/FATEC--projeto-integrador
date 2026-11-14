import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "Segmented Circular Loading Animation": 4 arcos girando em volta de um
/// ícone. Os arcos alternam entre azul e cinza numa onda contínua.
/// Com [sonar] = true, ondas saem do centro (efeito radar).
class CarregamentoSegmentado extends StatefulWidget {
  const CarregamentoSegmentado({
    super.key,
    required this.icone,
    this.sonar = false,
    this.tamanho = 64,
    this.corAtiva = const Color(0xFF0FB3FF),
    this.corInativa = const Color(0xFFCBD5E1),
    this.corIcone = const Color(0xFF0B2545),
  });

  final IconData icone;
  final bool sonar;
  final double tamanho;
  final Color corAtiva;
  final Color corInativa;
  final Color corIcone;

  @override
  State<CarregamentoSegmentado> createState() => _CarregamentoSegmentadoState();
}

class _CarregamentoSegmentadoState extends State<CarregamentoSegmentado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semAnimacao = MediaQuery.of(context).disableAnimations;
    if (semAnimacao && _controller.isAnimating) {
      _controller.stop();
    } else if (!semAnimacao && !_controller.isAnimating) {
      _controller.repeat();
    }

    return SizedBox.square(
      dimension: widget.tamanho,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return CustomPaint(
            painter: _SegmentosPainter(
              progresso: t,
              sonar: widget.sonar,
              corAtiva: widget.corAtiva,
              corInativa: widget.corInativa,
            ),
            child: Center(
              child: Icon(
                widget.icone,
                color: widget.corIcone,
                size: widget.tamanho * 0.38,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SegmentosPainter extends CustomPainter {
  _SegmentosPainter({
    required this.progresso,
    required this.sonar,
    required this.corAtiva,
    required this.corInativa,
  });

  final double progresso;
  final bool sonar;
  final Color corAtiva;
  final Color corInativa;

  static const int _segmentos = 4;
  static const double _vao = 0.42; // rad entre arcos

  @override
  void paint(Canvas canvas, Size size) {
    final centro = size.center(Offset.zero);
    final espessura = size.width * 0.085;
    final raio = size.width / 2 - espessura / 2;

    // Ondas de sonar (2 ondas defasadas, crescendo e sumindo).
    if (sonar) {
      for (var i = 0; i < 2; i++) {
        final fase = (progresso + i * 0.5) % 1.0;
        final r = raio * (0.35 + 0.65 * Curves.easeOut.transform(fase));
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = corAtiva.withValues(alpha: (1 - fase) * 0.45);
        canvas.drawCircle(centro, r, paint);
      }
    }

    // Arcos: giram e "acendem" um após o outro.
    final rotacao = progresso * 2 * math.pi;
    final varredura = (2 * math.pi / _segmentos) - _vao;
    for (var i = 0; i < _segmentos; i++) {
      // Onda suave: cada segmento atinge o pico em um momento diferente.
      final onda =
          (math.sin((progresso * 2 * math.pi) - i * (math.pi / 2)) + 1) / 2;
      final cor = Color.lerp(
        corInativa,
        corAtiva,
        Curves.easeInOut.transform(onda),
      )!;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = espessura
        ..color = cor;
      final inicio =
          -math.pi / 2 + rotacao + i * (2 * math.pi / _segmentos) + _vao / 2;
      canvas.drawArc(
        Rect.fromCircle(center: centro, radius: raio),
        inicio,
        varredura,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentosPainter old) =>
      old.progresso != progresso || old.sonar != sonar;
}

/// Reticências que aparecem uma a uma ("", ".", "..", "...") e recomeçam.
/// [aoCompletar] é chamado sempre que a terceira reticência aparece.
class ReticenciasAnimadas extends StatefulWidget {
  const ReticenciasAnimadas({
    super.key,
    required this.estilo,
    this.intervalo = const Duration(milliseconds: 520),
    this.aoCompletar,
  });

  final TextStyle estilo;
  final Duration intervalo;
  final VoidCallback? aoCompletar;

  @override
  State<ReticenciasAnimadas> createState() => _ReticenciasAnimadasState();
}

class _ReticenciasAnimadasState extends State<ReticenciasAnimadas> {
  int _quantidade = 0;
  bool _ativo = true;

  @override
  void initState() {
    super.initState();
    _ciclo();
  }

  Future<void> _ciclo() async {
    while (mounted && _ativo) {
      await Future<void>.delayed(widget.intervalo);
      if (!mounted || !_ativo) return;
      setState(() => _quantidade = (_quantidade + 1) % 4);
      if (_quantidade == 3) widget.aoCompletar?.call();
    }
  }

  @override
  void dispose() {
    _ativo = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Largura fixa (3 pontos) para o texto não "pular" ao animar.
    return Stack(
      children: [
        Opacity(opacity: 0, child: Text('...', style: widget.estilo)),
        Text('.' * _quantidade, style: widget.estilo),
      ],
    );
  }
}
