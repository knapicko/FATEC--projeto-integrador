import 'package:flutter/material.dart';

class OficioInfo {
  final String funcao;
  final String? categoria;
  final String? cor;

  const OficioInfo({required this.funcao, this.categoria, this.cor});

  factory OficioInfo.fromMap(Map<String, dynamic> map) {
    final funcao = map['funcao']?.toString().trim() ?? '';
    final categoriaRaw = map['categoria']?.toString().trim();
    // `cod_cor` (hex) é a fonte; `cor` guarda o mesmo hex (antes era enum).
    final corRaw = map['cod_cor'] ?? map['cor'] ?? map['Cor'];
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

  /// Nome do ofício (categoria); cai na função quando não veio o ofício.
  String get nomeOficio =>
      (categoria?.isNotEmpty ?? false) ? categoria! : funcao;

  /// Cards de profissional mostram os OFÍCIOS em que ele atua, não cada
  /// função: agrupa a lista de funções por ofício, sem repetir, mantendo a
  /// ordem. A tag passa a exibir o nome do ofício (com a cor dele).
  static List<OficioInfo> soOficios(Iterable<OficioInfo> lista) {
    final vistos = <String>{};
    final resultado = <OficioInfo>[];
    for (final o in lista) {
      final nome = o.nomeOficio.trim();
      if (nome.isEmpty || !vistos.add(nome.toLowerCase())) continue;
      resultado.add(OficioInfo(funcao: nome, categoria: nome, cor: o.cor));
    }
    return resultado;
  }
}

class CorOficio {
  CorOficio._();

  static const Color _corPadrao = Color(0xFF7B5EA7);

  /// Cor de cada ofício. A fonte é o hex `cod_cor` (docs/sql/v0_6_ajustes.sql
  /// copia o mesmo hex na coluna `cor`). Os nomes abaixo só servem para
  /// registros antigos que ainda tragam o nome do enum.
  static const Map<String, Color> _coresNomeadas = {
    'vermelho': Color(0xFFE53935),
    'marrom': Color(0xFF8D5524),
    'azul escuro': Color(0xFF1E3A8A),
    'vinho': Color(0xFF8E1B3A),
    'verde': Color(0xFF2E9E4F),
    'azul claro': Color(0xFF29B6F6),
    'cinza': Color(0xFF64748B),
    'roxo': Color(0xFF7C3AED),
    'laranja': Color(0xFFF97316),
    'magenta': Color(0xFFD946EF),
  };

  /// Hex antigos de `cod_cor` → nome da paleta atual.
  static const Map<String, String> _hexDoBanco = {
    'ff0000': 'vermelho',
    '8b4513': 'marrom',
    '00008b': 'azul escuro',
    '800000': 'vinho',
    '008000': 'verde',
    'add8e6': 'azul claro',
    '808080': 'cinza',
    // tons pastel da v0.5
    'f2a27e': 'vermelho',
    'c9a27e': 'marrom',
    '8fa3d9': 'azul escuro',
    '8cc7d6': 'vinho',
    'e8a3be': 'verde',
    '86d3b5': 'azul claro',
    'd9be7a': 'cinza',
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
