import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fundos desenhados do chat, usados na prévia (alterar_tema_chat.dart) e na
/// conversa (tela_chat_profissional.dart) — os dois ficam iguais.

/// Cor por trás do tema "Aurora Profundo": escura, para a opacidade não
/// deixar o fundo cinza (com branco atrás ele "lavava").
const Color kBaseAurora = Color(0xFF0B1226);

/// "Aurora Profundo": azul-noite com faixas de luz (verde-água, ciano e
/// violeta) como uma aurora.
class FundoAurora extends StatelessWidget {
  const FundoAurora({super.key});

  @override
  Widget build(BuildContext context) {
    Widget brilho(Alignment centro, Color cor, double raio) => Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: centro,
            radius: raio,
            colors: [cor, cor.withValues(alpha: 0)],
          ),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF172554), Color(0xFF1E3A8A)],
            ),
          ),
        ),
        brilho(const Alignment(-0.9, -0.7), const Color(0x8034D399), 0.9),
        brilho(const Alignment(0.8, -0.4), const Color(0x7022D3EE), 0.85),
        brilho(const Alignment(0.2, 0.15), const Color(0x608B5CF6), 0.9),
        brilho(const Alignment(-0.6, 0.85), const Color(0x4038BDF8), 0.8),
      ],
    );
  }
}

/// "Geométrico": fundo claro com formas azuis (círculos, triângulos,
/// quadrados e anéis) em pouca opacidade.
class FundoGeometrico extends StatelessWidget {
  const FundoGeometrico({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF4F8FC),
      child: CustomPaint(painter: _FormasGeometricasPainter()),
    );
  }
}

class _FormasGeometricasPainter extends CustomPainter {
  const _FormasGeometricasPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const azul = Color(0xFF0FB3FF);
    final cheio = Paint()..color = azul.withValues(alpha: 0.10);
    final traco = Paint()
      ..color = azul.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Grade de "células" de 96 px, cada uma com uma forma, deslocadas para
    // não parecer uma tabela (sempre as mesmas → o fundo não "pula").
    const celula = 96.0;
    final aleatorio = math.Random(7);
    for (double y = -celula / 2; y < size.height + celula; y += celula) {
      final linha = (y / celula).round();
      for (double x = -celula / 2; x < size.width + celula; x += celula) {
        final desloc = linha.isOdd ? celula / 2 : 0.0;
        final c = Offset(
          x + desloc + aleatorio.nextDouble() * 22 - 11,
          y + aleatorio.nextDouble() * 22 - 11,
        );
        final tam = 12 + aleatorio.nextDouble() * 14;
        final giro = aleatorio.nextDouble() * math.pi;
        switch (aleatorio.nextInt(5)) {
          case 0:
            canvas.drawCircle(c, tam * 0.7, cheio);
          case 1:
            canvas.drawCircle(c, tam * 0.8, traco);
          case 2:
            canvas.drawPath(_triangulo(c, tam, giro), cheio);
          case 3:
            canvas.save();
            canvas.translate(c.dx, c.dy);
            canvas.rotate(giro);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: Offset.zero,
                  width: tam * 1.3,
                  height: tam * 1.3,
                ),
                const Radius.circular(4),
              ),
              traco,
            );
            canvas.restore();
          default:
            canvas.drawPath(_triangulo(c, tam, giro), traco);
        }
      }
    }
  }

  Path _triangulo(Offset c, double tam, double giro) {
    final p = Path();
    for (var i = 0; i < 3; i++) {
      final a = giro + i * 2 * math.pi / 3;
      final ponto = c + Offset(math.cos(a), math.sin(a)) * tam;
      if (i == 0) {
        p.moveTo(ponto.dx, ponto.dy);
      } else {
        p.lineTo(ponto.dx, ponto.dy);
      }
    }
    return p..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
