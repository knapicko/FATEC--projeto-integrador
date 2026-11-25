import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_settings_controller.dart';
import '../utils/movimento.dart';

/// Dedinho "apertando" a tela, com uma ondinha saindo do ponto do toque.
/// Aparece só depois de [atraso] sem a pessoa tocar, para mostrar que é
/// preciso tocar na tela para continuar. Some ao trocar o [gatilho] (cada
/// toque ou etapa nova muda o gatilho e a contagem recomeça).
///
/// Não recebe toques (IgnorePointer): quem trata o toque é a tela de baixo.
class DicaToque extends StatefulWidget {
  const DicaToque({
    super.key,
    required this.ativo,
    required this.gatilho,
    this.atraso = const Duration(seconds: 5),
    this.tamanho = 56,
    this.cor = Colors.white,
  });

  /// false = nunca mostra (etapa com campos, carregando...).
  final bool ativo;

  /// Muda a cada toque/etapa: esconde o dedo e recomeça a espera.
  final Object gatilho;
  final Duration atraso;

  /// Tamanho do ícone da mão.
  final double tamanho;

  /// Branco no fundo azul (onboarding); azul sobre o fundo claro (tutorial).
  final Color cor;

  /// Ponta do dedo no ícone `pan_tool_alt_rounded`, medida no próprio
  /// glifo (fração do tamanho do ícone). O toque fica um pouco abaixo da
  /// ponta, no meio da curva do dedo.
  static const double _pontaX = 0.478;
  static const double _toqueY = 0.17;

  /// Tamanho total do widget para um ícone de [tamanho].
  static Size medida(double tamanho) => Size(tamanho * 1.5, tamanho * 1.45);

  @override
  State<DicaToque> createState() => _DicaToqueState();
}

class _DicaToqueState extends State<DicaToque>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  Timer? _espera;
  bool _visivel = false;

  @override
  void initState() {
    super.initState();
    _agendar();
  }

  @override
  void didUpdateWidget(covariant DicaToque old) {
    super.didUpdateWidget(old);
    if (old.gatilho != widget.gatilho || old.ativo != widget.ativo) {
      _agendar();
    }
  }

  void _agendar() {
    _espera?.cancel();
    if (_visivel) setState(() => _visivel = false);
    _anim.stop();
    if (!widget.ativo) return;
    _espera = Timer(widget.atraso, () {
      if (!mounted || !widget.ativo) return;
      setState(() => _visivel = true);
      // Reduzir animações: mostra o dedo parado, sem o movimento.
      if (!AppSettingsController.semAnimacao) _anim.repetir();
    });
  }

  @override
  void dispose() {
    _espera?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tamanho;
    final medida = DicaToque.medida(t);
    // Ponto do toque dentro do widget (onde a onda nasce).
    final toque = Offset(medida.width / 2, t * 0.34);
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _visivel ? 1 : 0,
        duration: duracao(const Duration(milliseconds: 350)),
        child: SizedBox.fromSize(
          size: medida,
          child: AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final v = _anim.value;
              // 0–0.3 desce e aperta; 0.3–0.5 segura; depois sobe.
              final aperto = v < 0.3
                  ? Curves.easeOut.transform(v / 0.3)
                  : v < 0.5
                  ? 1.0
                  : 1 - Curves.easeIn.transform((v - 0.5) / 0.5);
              // A onda nasce no instante do aperto e se espalha.
              final onda = v < 0.28 ? 0.0 : ((v - 0.28) / 0.6).clamp(0.0, 1.0);
              final raio = t * (0.12 + 0.42 * Curves.easeOut.transform(onda));
              final subida = t * 0.2 * (1 - aperto);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  if (onda > 0 && onda < 1)
                    Positioned(
                      left: toque.dx - raio,
                      top: toque.dy - raio,
                      child: Container(
                        width: raio * 2,
                        height: raio * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.cor.withValues(
                            alpha: 0.28 * (1 - onda),
                          ),
                          border: Border.all(
                            color: widget.cor.withValues(
                              alpha: 0.9 * (1 - onda),
                            ),
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),
                  // A ponta do dedo fica exatamente no ponto do toque.
                  Positioned(
                    left: toque.dx - t * DicaToque._pontaX,
                    top: toque.dy - t * DicaToque._toqueY - subida,
                    child: Transform.scale(
                      scale: 1 - 0.1 * aperto,
                      alignment: const Alignment(
                        DicaToque._pontaX * 2 - 1,
                        DicaToque._toqueY * 2 - 1,
                      ),
                      child: Icon(
                        Icons.pan_tool_alt_rounded,
                        size: t,
                        color: widget.cor,
                        shadows: const [
                          Shadow(
                            color: Color(0x55000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
