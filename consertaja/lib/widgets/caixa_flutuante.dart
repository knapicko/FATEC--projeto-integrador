import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'imagem_app.dart';

/// Camadas da caixa da tela inicial (geradas por
/// tool/gerar_caixa_animacao.dart, todas no mesmo quadro 500×500 da arte).
class CaixaAnimacaoAssets {
  CaixaAnimacaoAssets._();

  static const _pasta = 'assets/images/caixa_animacao/transparente';
  static const fechada = '$_pasta/caixa_fechada.png';
  static const abertaFundo = '$_pasta/caixa_aberta_fundo.png';
  static const abertaFrente = '$_pasta/caixa_aberta_frente.png';
  static const abertaFrenteMascara = '$_pasta/caixa_aberta_frente_mascara.png';
  static const ferramentas = '$_pasta/ferramentas.png';
  static const ferramentasMascara = '$_pasta/ferramentas_mascara.png';

  static const todas = [
    fechada,
    abertaFundo,
    abertaFrente,
    abertaFrenteMascara,
    ferramentas,
    ferramentasMascara,
  ];
}

/// Caixa da tela inicial montada em camadas, de trás para a frente:
///   1. caixa fechada (some quando abre);
///   2. tampa + interior da caixa aberta;
///   3. ferramentas (com contorno na cor do fundo, da grossura das
///      linhas da caixa, para não "grudar" na tampa);
///   4. frente da caixa (silhueta na cor do fundo + traços), que esconde a
///      parte de baixo das ferramentas — elas parecem estar DENTRO da caixa.
///
/// Só desenha; quem anima é a tela, passando os progressos (0 → 1).
class CaixaFlutuante extends StatelessWidget {
  const CaixaFlutuante({
    super.key,
    required this.tamanho,
    required this.corFundo,
    this.abertura = 1,
    this.ferramentas = 1,
    this.fase = 0,
    this.intensidadeFlutuacao = 1,
  });

  final double tamanho;

  /// Cor do fundo da tela (pinta as máscaras de contorno/frente).
  final Color corFundo;

  /// 0 = fechada, 1 = aberta.
  final double abertura;

  /// 0 = ferramentas guardadas, 1 = flutuando acima da caixa.
  final double ferramentas;

  /// Fase da flutuação (radianos), vinda de um controller em loop.
  final double fase;

  /// 0 = parada, 1 = flutuação completa das ferramentas.
  final double intensidadeFlutuacao;

  Widget _camada(String asset, {Color? tinta}) {
    return Image.asset(
      asset,
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      color: tinta,
      colorBlendMode: tinta == null ? null : BlendMode.srcIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = tamanho / 500; // unidade da arte
    final abre = abertura.clamp(0.0, 1.0);
    final sobe = ferramentas.clamp(0.0, 1.2);
    final f = intensidadeFlutuacao.clamp(0.0, 1.0);

    // Ferramentas: saem do fundo da caixa (+70) até a altura da arte (0),
    // com a parte de baixo dentro da caixa, flutuando ali com um balanço
    // leve, defasado da caixa.
    final ferramentasY =
        (70 - 70 * sobe) * u + math.sin(fase + 1.3) * 5 * u * f;
    final ferramentasGiro = math.sin(fase + 0.6) * 0.04 * f;
    final ferramentasOpacidade = (sobe * 1.6).clamp(0.0, 1.0);

    // Ilustração: mantém as cores reais no modo escuro.
    return CorOriginal(
      child: SizedBox(
        width: tamanho,
        height: tamanho,
        child: Stack(
          children: [
            if (abre < 1)
              Opacity(
                opacity: 1 - abre,
                child: _camada(CaixaAnimacaoAssets.fechada),
              ),
            if (abre > 0) ...[
              Opacity(
                opacity: abre,
                child: _camada(CaixaAnimacaoAssets.abertaFundo),
              ),
              if (ferramentasOpacidade > 0)
                Opacity(
                  opacity: ferramentasOpacidade,
                  child: Transform.translate(
                    offset: Offset(0, ferramentasY),
                    child: Transform.rotate(
                      angle: ferramentasGiro,
                      origin: Offset(-12 * u, 40 * u),
                      // Contorno na cor do fundo (mesma grossura das linhas
                      // da caixa) + ferramentas brancas por cima.
                      child: Stack(
                        children: [
                          _camada(
                            CaixaAnimacaoAssets.ferramentasMascara,
                            tinta: corFundo,
                          ),
                          _camada(CaixaAnimacaoAssets.ferramentas),
                        ],
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: abre,
                child: Stack(
                  children: [
                    _camada(
                      CaixaAnimacaoAssets.abertaFrenteMascara,
                      tinta: corFundo,
                    ),
                    _camada(CaixaAnimacaoAssets.abertaFrente),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Voo do Hero da caixa entre telas: em vez de trocar de imagem de uma vez
/// (caixa animada da tela inicial ↔ caixa parada do onboarding), uma some
/// enquanto a outra aparece, já no tamanho do voo.
Widget caixaHeroShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final de = (fromHeroContext.widget as Hero).child;
  final para = (toHeroContext.widget as Hero).child;
  // No pop a animação da rota anda de 1 para 0.
  final progresso = direction == HeroFlightDirection.push
      ? animation
      : ReverseAnimation(animation);
  return Stack(
    fit: StackFit.expand,
    children: [
      FadeTransition(
        opacity: ReverseAnimation(
          CurvedAnimation(
            parent: progresso,
            curve: const Interval(0, 0.65, curve: Curves.easeInOut),
          ),
        ),
        child: FittedBox(child: de),
      ),
      FadeTransition(
        opacity: CurvedAnimation(
          parent: progresso,
          curve: const Interval(0.35, 1, curve: Curves.easeInOut),
        ),
        child: FittedBox(child: para),
      ),
    ],
  );
}
