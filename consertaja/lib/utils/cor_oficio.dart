import 'package:flutter/material.dart';

class OficioInfo {
  final String funcao;
  final String? categoria;
  final String? cor;

  const OficioInfo({required this.funcao, this.categoria, this.cor});

  factory OficioInfo.fromMap(Map<String, dynamic> map) {
    final funcao = map['funcao']?.toString().trim() ?? '';
    final categoriaRaw = map['categoria']?.toString().trim();
    // `cor` (nome: "Vermelho", "Azul Escuro"...) é a fonte oficial; `cod_cor`
    // (hex do banco) só entra se o nome não vier na consulta.
    final corRaw = map['cor'] ?? map['Cor'] ?? map['cod_cor'];
    final cor = corRaw?.toString().trim();
    return OficioInfo(
      funcao: funcao,
      categoria:
          categoriaRaw != null &&
              categoriaRaw.isNotEmpty &&
              categoriaRaw.toLowerCase() != 'null'
          ? categoriaRaw
          : null,
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

  /// `cod_cor` gravado em `oficios` → mesma cor da paleta do nome (`cor`).
  /// Assim o ofício tem a mesma cor em todas as telas, venha o nome ou o hex.
  static const Map<String, String> _hexDoBanco = {
    'ff0000': 'vermelho',
    '8b4513': 'marrom',
    '00008b': 'azul escuro',
    '800000': 'vinho',
    '008000': 'verde',
    'add8e6': 'azul claro',
    '808080': 'cinza',
  };

  /// Converte a cor de um ofício (nome da coluna `cor` ou hex de `cod_cor`)
  /// para a cor da paleta do app.
  static Color parse(String? valor) {
    if (valor == null || valor.trim().isEmpty) return _corPadrao;

    final normalizado = valor.trim();
    final chave = normalizado
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('_', ' ');
    if (_coresNomeadas.containsKey(chave)) {
      return _coresNomeadas[chave]!;
    }
    final hexChave = chave.replaceAll('#', '').replaceFirst('0x', '');
    final alias =
        _hexDoBanco[hexChave.length == 8 ? hexChave.substring(2) : hexChave];
    if (alias != null) return _coresNomeadas[alias]!;

    var hex = normalizado.replaceAll('#', '');
    if (hex.startsWith('0x') || hex.startsWith('0X')) {
      hex = hex.substring(2);
    }
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

  /// Define uma cor de texto legível em cima da cor base (fundo).
  static Color corTextoContraste(Color base) {
    return base.computeLuminance() > 0.5
        ? const Color(0xFF20242B)
        : const Color(0xFFFFFFFF);
  }
}
