import 'package:flutter/material.dart';

class OficioInfo {
  final String funcao;
  final String? cor;

  const OficioInfo({required this.funcao, this.cor});

  factory OficioInfo.fromMap(Map<String, dynamic> map) {
    final funcao = map['funcao']?.toString().trim() ?? '';
    final corRaw = map['cor'] ?? map['Cor'];
    final cor = corRaw?.toString().trim();
    return OficioInfo(
      funcao: funcao,
      cor: (cor != null && cor.isNotEmpty && cor.toLowerCase() != 'null')
          ? cor
          : null,
    );
  }
}

class CorOficio {
  CorOficio._();

  static const Color _corPadrao = Color(0xFF7B5EA7);

  static const Map<String, Color> _coresNomeadas = {
    'vinho': Color(0xFF722F37),
    'roxo': Color(0xFF7B5EA7),
    'magenta': Color(0xFFB606B6),
    'azul escuro': Color(0xFF0C06FF),
    'verde': Color(0xFF43A047),
    'vermelho': Color(0xFFE53935),
    'marrom': Color(0xFF6D4C41),
    'cinza': Color(0xFF676768),
    'azul claro': Color(0xFF0FB3FF),
  };

  static Color parse(String? valor) {
    if (valor == null || valor.trim().isEmpty) return _corPadrao;

    final normalizado = valor.trim();
    final chave = normalizado.toLowerCase();
    if (_coresNomeadas.containsKey(chave)) {
      return _coresNomeadas[chave]!;
    }

    var hex = normalizado.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length == 8) {
      final parsed = int.tryParse(hex, radix: 16);
      if (parsed != null) return Color(parsed);
    }

    return _corPadrao;
  }

  static Color corTexto(Color base) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness * 0.45).clamp(0.18, 0.55))
        .withSaturation((hsl.saturation * 1.15).clamp(0.0, 1.0))
        .toColor();
  }

  static Color corFundo(Color base) => base.withValues(alpha: 0.3);
}
