import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class CorDominanteService {
  static const String corPadrao = '0xFF0A6E9D';

  static String extrair(Uint8List bytes) {
    final imagem = img.decodeImage(bytes);
    if (imagem == null) return corPadrao;

    final miniatura = img.copyResize(imagem, width: 64, height: 64);
    final frequencias = <int, int>{};

    for (final pixel in miniatura) {
      final alpha = pixel.a;
      if (alpha < 128) continue;

      final vermelho = (pixel.r ~/ 32) * 32;
      final verde = (pixel.g ~/ 32) * 32;
      final azul = (pixel.b ~/ 32) * 32;
      final chave = (vermelho << 16) | (verde << 8) | azul;
      frequencias[chave] = (frequencias[chave] ?? 0) + 1;
    }

    if (frequencias.isEmpty) return corPadrao;

    final cor = frequencias.entries.reduce(
      (atual, proxima) => proxima.value > atual.value ? proxima : atual,
    ).key;
    return '0xFF${cor.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color paraColor(String? valor) {
    final texto = valor?.trim() ?? '';
    final normalizado = texto.startsWith('#')
        ? texto.substring(1)
        : texto.startsWith('0x') || texto.startsWith('0X')
        ? texto.substring(2)
        : texto;
    final numero = int.tryParse(normalizado, radix: 16);
    if (numero == null) return const Color(0xFF0A6E9D);
    if (normalizado.length == 6) return Color(0xFF000000 | numero);
    if (normalizado.length == 8) return Color(numero);
    return const Color(0xFF0A6E9D);
  }
}