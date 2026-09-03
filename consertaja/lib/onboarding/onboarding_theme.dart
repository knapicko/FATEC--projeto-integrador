import 'package:flutter/material.dart';

class OnboardingColors {
  static const blue = Color(0xFF0FB3FF);
  static const historyFill = Color(0xFFDAF3FF);
  static const historyText = Color(0xFFAABDC5);
  static const orange = Color(0xFFF2994A);
}

class CaixaAssets {
  static const normal = 'assets/images/caixa/caixa_normal.png';
  static const falandoFechado = 'assets/images/caixa/caixa_falando_fechado.png';
  static const falandoAberto = 'assets/images/caixa/caixa_falando_aberto.png';
}

enum CaixaPose { normal, falandoFechado, falandoAberto }

extension CaixaPoseX on CaixaPose {
  String get asset {
    switch (this) {
      case CaixaPose.normal:
        return CaixaAssets.normal;
      case CaixaPose.falandoFechado:
        return CaixaAssets.falandoFechado;
      case CaixaPose.falandoAberto:
        return CaixaAssets.falandoAberto;
    }
  }
}
