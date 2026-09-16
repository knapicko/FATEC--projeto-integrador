import 'dart:typed_data';

import 'package:consertaja/services/cor_dominante_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _pngCorSolida(int r, int g, int b) {
  final imagem = img.Image(width: 32, height: 32);
  for (int y = 0; y < imagem.height; y++) {
    for (int x = 0; x < imagem.width; x++) {
      imagem.setPixelRgb(x, y, r, g, b);
    }
  }
  return Uint8List.fromList(img.encodePng(imagem));
}

void main() {
  group('CorDominanteService', () {
    test('extrair retorna a cor dominante da imagem', () {
      final bytes = _pngCorSolida(255, 0, 0);
      expect(CorDominanteService.extrair(bytes), '0xFFE00000');
    });

    test('extrair com bytes invalidos retorna o default', () {
      expect(
        CorDominanteService.extrair(Uint8List(0)),
        CorDominanteService.corPadrao,
      );
      expect(
        CorDominanteService.extrair(Uint8List.fromList([1, 2, 3])),
        CorDominanteService.corPadrao,
      );
    });

    test('extrairDaUrl nula/vazia retorna o default', () async {
      expect(await CorDominanteService.extrairDaUrl(null), '0xFF0FB3FF');
      expect(await CorDominanteService.extrairDaUrl(''), '0xFF0FB3FF');
      expect(await CorDominanteService.extrairDaUrl('null'), '0xFF0FB3FF');
    });

    test('corPadrao e 0xFF0FB3FF', () {
      expect(CorDominanteService.corPadrao, '0xFF0FB3FF');
    });

    test('paraColor converte e usa default 0xFF0FB3FF', () {
      expect(
        CorDominanteService.paraColor('0xFFFF0000'),
        const Color(0xFFFF0000),
      );
      expect(CorDominanteService.paraColor(null), const Color(0xFF0FB3FF));
      expect(
        CorDominanteService.paraColor('invalida'),
        const Color(0xFF0FB3FF),
      );
    });
  });
}

