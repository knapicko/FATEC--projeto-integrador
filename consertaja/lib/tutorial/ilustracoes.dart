import 'dart:math' as math;

import 'package:flutter/material.dart';

const _azul = Color(0xFF0FB3FF);
const _laranja = Color(0xFFF59E0B);
const _verde = Color(0xFF16A34A);

/// Cartão branco onde as ilustrações ficam (o fundo do tutorial é escuro).
class _Cartao extends StatelessWidget {
  const _Cartao({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: math.min(MediaQuery.of(context).size.width - 48, 320),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    child: child,
  );
}

class _Icone extends StatelessWidget {
  const _Icone(this.icone, this.cor, this.rotulo, {this.escala = 1});

  final IconData icone;
  final Color cor;
  final String rotulo;
  final double escala;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Transform.scale(
        scale: escala,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icone, color: cor, size: 27),
        ),
      ),
      const SizedBox(height: 5),
      Text(
        rotulo,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF334155),
        ),
      ),
    ],
  );
}

/// Seta tracejada com os traços andando (de [paraDireita] lado).
class _SetaAnimada extends StatelessWidget {
  const _SetaAnimada({
    required this.t,
    required this.cor,
    this.paraDireita = true,
  });

  final double t;
  final Color cor;
  final bool paraDireita;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: CustomPaint(
        size: const Size(double.infinity, 16),
        painter: _PintaSeta(t, cor, paraDireita),
      ),
    ),
  );
}

class _PintaSeta extends CustomPainter {
  _PintaSeta(this.t, this.cor, this.paraDireita);

  final double t;
  final Color cor;
  final bool paraDireita;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final p = Paint()
      ..color = cor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const traco = 7.0;
    const espaco = 6.0;
    final passo = traco + espaco;
    final desloc = (paraDireita ? t : 1 - t) * passo;
    for (var x = -passo + desloc; x < size.width - 10; x += passo) {
      final a = x.clamp(2.0, size.width - 10);
      final b = (x + traco).clamp(2.0, size.width - 10);
      if (b > a) canvas.drawLine(Offset(a, y), Offset(b, y), p);
    }
    final ponta = Path();
    if (paraDireita) {
      ponta
        ..moveTo(size.width - 12, y - 6)
        ..lineTo(size.width - 2, y)
        ..lineTo(size.width - 12, y + 6);
    } else {
      ponta
        ..moveTo(12, y - 6)
        ..lineTo(2, y)
        ..lineTo(12, y + 6);
    }
    canvas.drawPath(
      ponta,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PintaSeta old) => old.t != t;
}

/// Como funciona a solicitação geográfica: o cliente manda o pedido para o
/// Radar e o profissional da área vê e responde.
/// [doProfissional]: versão contada do lado do profissional.
class IlustracaoRadar extends StatefulWidget {
  const IlustracaoRadar({super.key, this.doProfissional = false});

  final bool doProfissional;

  @override
  State<IlustracaoRadar> createState() => _IlustracaoRadarState();
}

class _IlustracaoRadarState extends State<IlustracaoRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Cartao(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final pulso = 1 + math.sin(t * 2 * math.pi) * 0.08;
        return Row(
          children: [
            _Icone(
              Icons.person_rounded,
              _azul,
              'Cliente',
              escala: widget.doProfissional ? 1 : pulso,
            ),
            _SetaAnimada(t: t, cor: _azul),
            Stack(
              alignment: Alignment.topCenter,
              children: [
                // Ondas do radar.
                for (final atraso in [0.0, 0.5])
                  Builder(
                    builder: (_) {
                      final f = (t + atraso) % 1;
                      return Opacity(
                        opacity: (1 - f) * 0.5,
                        child: Container(
                          width: 50 + f * 26,
                          height: 50 + f * 26,
                          margin: EdgeInsets.only(top: -f * 13),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _verde, width: 2),
                          ),
                        ),
                      );
                    },
                  ),
                const _Icone(Icons.sensors_rounded, _verde, 'Radar'),
              ],
            ),
            _SetaAnimada(t: t, cor: _laranja, paraDireita: false),
            _Icone(
              Icons.handyman_rounded,
              _laranja,
              'Profissional',
              escala: widget.doProfissional ? pulso : 1,
            ),
          ],
        );
      },
    ),
  );
}

/// Troca de conta: a pessoa (independente) e a loja trocando de lugar.
class IlustracaoTrocaConta extends StatefulWidget {
  const IlustracaoTrocaConta({super.key});

  @override
  State<IlustracaoTrocaConta> createState() => _IlustracaoTrocaContaState();
}

class _IlustracaoTrocaContaState extends State<IlustracaoTrocaConta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Cartao(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Metade do tempo a loja está ativa, metade a conta independente.
        final fase = Curves.easeInOutCubic.transform(
          (math.sin(_c.value * 2 * math.pi) + 1) / 2,
        );
        return SizedBox(
          height: 86,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _c.value * 2 * math.pi,
                child: const Icon(
                  Icons.sync_rounded,
                  color: Color(0xFFCBD5E1),
                  size: 40,
                ),
              ),
              Align(
                alignment: Alignment(-0.8 + 1.6 * fase, 0),
                child: Transform.scale(
                  scale: 1.15 - 0.3 * fase,
                  child: Opacity(
                    opacity: 1 - 0.45 * fase,
                    child: const _Icone(
                      Icons.person_rounded,
                      _azul,
                      'Independente',
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment(0.8 - 1.6 * fase, 0),
                child: Transform.scale(
                  scale: 0.85 + 0.3 * fase,
                  child: Opacity(
                    opacity: 0.55 + 0.45 * fase,
                    child: const _Icone(
                      Icons.storefront_rounded,
                      Color(0xFF7C3AED),
                      'Loja',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Loja com a equipe: funcionários aparecendo um a um.
class IlustracaoEquipe extends StatefulWidget {
  const IlustracaoEquipe({super.key});

  @override
  State<IlustracaoEquipe> createState() => _IlustracaoEquipeState();
}

class _IlustracaoEquipeState extends State<IlustracaoEquipe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Cartao(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        double aparece(double ini) =>
            Curves.elasticOut.transform(((t - ini) / 0.25).clamp(0.0, 1.0));
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const _Icone(Icons.storefront_rounded, Color(0xFF7C3AED), 'Loja'),
            const Icon(Icons.add_rounded, color: Color(0xFF94A3B8)),
            for (final (i, cor) in [(0, _azul), (1, _verde), (2, _laranja)])
              Transform.scale(
                scale: aparece(0.1 + i * 0.18),
                child: _Icone(Icons.person_rounded, cor, 'Equipe'),
              ),
          ],
        );
      },
    ),
  );
}
