import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Leitura de documentos mais certeira para conferir CPF/CNPJ:
/// 1. lê a foto original E uma versão tratada (cinza, contraste, nitidez e
///    ampliada) — o ML Kit erra bem menos em fotos escuras/pequenas;
/// 2. confere o número informado no texto tolerando as trocas comuns do OCR
///    (O→0, I/l→1, S→5, B→8…), separadores e espaços, e até 1 dígito lido
///    errado (o número já foi validado no cadastro).
class OcrDocumento {
  OcrDocumento._();

  /// Texto da foto original + da versão tratada.
  static Future<String> lerTexto(File arquivo) async {
    final textos = <String>[];
    final reconhecedor = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      textos.add(
        (await reconhecedor.processImage(InputImage.fromFile(arquivo))).text,
      );
      final tratada = await _versaoTratada(arquivo);
      if (tratada != null) {
        textos.add(
          (await reconhecedor.processImage(InputImage.fromFile(tratada))).text,
        );
        try {
          await tratada.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[OCR] $e');
    } finally {
      await reconhecedor.close();
    }
    return textos.where((t) => t.trim().isNotEmpty).join('\n');
  }

  static Future<File?> _versaoTratada(File arquivo) async {
    try {
      final bytes = await arquivo.readAsBytes();
      final processado = await compute(_tratar, bytes);
      if (processado == null) return null;
      final dir = await getTemporaryDirectory();
      final f = File(
        '${dir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await f.writeAsBytes(processado);
      return f;
    } catch (e) {
      debugPrint('[OCR] tratamento: $e');
      return null;
    }
  }

  static Uint8List? _tratar(Uint8List bytes) {
    var imagem = img.decodeImage(bytes);
    if (imagem == null) return null;
    imagem = img.bakeOrientation(imagem);
    // Texto pequeno: amplia até ~2200 px no lado maior.
    final maior = imagem.width > imagem.height ? imagem.width : imagem.height;
    if (maior < 2200) {
      final f = 2200 / maior;
      imagem = img.copyResize(
        imagem,
        width: (imagem.width * f).round(),
        height: (imagem.height * f).round(),
        interpolation: img.Interpolation.cubic,
      );
    }
    imagem = img.grayscale(imagem);
    imagem = img.normalize(imagem, min: 0, max: 255);
    imagem = img.adjustColor(imagem, contrast: 1.5);
    imagem = img.convolution(imagem, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0]);
    return Uint8List.fromList(img.encodeJpg(imagem, quality: 92));
  }

  static const _trocas = {
    'O': '0',
    'o': '0',
    'Q': '0',
    'D': '0',
    'U': '0',
    'I': '1',
    'l': '1',
    'i': '1',
    '|': '1',
    '!': '1',
    'L': '1',
    'J': '1',
    'Z': '2',
    'z': '2',
    'S': '5',
    's': '5',
    'G': '6',
    'b': '6',
    'T': '7',
    'B': '8',
    'g': '9',
    'q': '9',
  };

  /// Sequências "numéricas" do texto, com as letras confundidas trocadas
  /// por dígitos e sem separadores.
  static List<String> _sequencias(String texto) {
    final blocos = texto.split(RegExp(r'[\n\r]+'));
    final saida = <String>[];
    for (final linha in blocos) {
      // Junta tokens da linha (o OCR costuma separar "123.456. 789-00").
      final b = StringBuffer();
      for (final ch in linha.split('')) {
        if (RegExp(r'\d').hasMatch(ch)) {
          b.write(ch);
        } else if (_trocas.containsKey(ch)) {
          b.write(_trocas[ch]);
        } else if (RegExp(r'[\s.\-/,:]').hasMatch(ch)) {
          continue;
        } else {
          if (b.isNotEmpty) saida.add(b.toString());
          b.clear();
        }
      }
      if (b.isNotEmpty) saida.add(b.toString());
    }
    // Também o texto inteiro só com dígitos (número quebrado em linhas).
    saida.add(texto.replaceAll(RegExp(r'\D'), ''));
    return saida;
  }

  /// O [esperado] (só dígitos) aparece no texto? Tolera 1 dígito errado.
  static bool contemNumero(String texto, String esperado) {
    final alvo = esperado.replaceAll(RegExp(r'\D'), '');
    if (alvo.length < 8) return false;
    for (final s in _sequencias(texto)) {
      if (s.contains(alvo)) return true;
      if (s.length < alvo.length) continue;
      for (var i = 0; i <= s.length - alvo.length; i++) {
        var erros = 0;
        for (var j = 0; j < alvo.length && erros <= 1; j++) {
          if (s.codeUnitAt(i + j) != alvo.codeUnitAt(j)) erros++;
        }
        if (erros <= 1) return true;
      }
    }
    return false;
  }

  static String formatarCpf(String d) => d.length == 11
      ? '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}'
      : d;

  static String formatarCnpj(String d) => d.length == 14
      ? '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}'
      : d;
}
