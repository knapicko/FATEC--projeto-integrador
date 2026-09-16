import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Extrai a cor dominante da foto de perfil e converte para o formato
/// salvo no Supabase (`'0xFFRRGGBB'`).
class CorDominanteService {
  /// Cor usada quando o profissional NÃO tem foto de perfil.
  static const String corPadrao = '0xFF0FB3FF';
  static const Color corPadraoColor = Color(0xFF0FB3FF);

  /// Extrai a cor dominante a partir dos bytes de uma imagem.
  ///
  /// Nunca lança exceção: em qualquer falha retorna [corPadrao], então é
  /// seguro chamar toda vez que a foto de perfil for trocada.
  static String extrair(Uint8List bytes) {
    try {
      if (bytes.isEmpty) return corPadrao;
      final imagem = img.decodeImage(bytes);
      if (imagem == null) return corPadrao;

      // Reduz para acelerar (mantém proporção).
      final miniatura = img.copyResize(imagem, width: 64);

      final todas = <int, int>{};
      final saturadas = <int, int>{};

      // Amostragem de 1 em cada 2 pixels: suficiente e mais rápido.
      for (int y = 0; y < miniatura.height; y += 2) {
        for (int x = 0; x < miniatura.width; x += 2) {
          final pixel = miniatura.getPixel(x, y);

          // `pixel.r/g/b/a` são `num` no pacote image ^4.x,
          // por isso a conversão explícita para int.
          final int alpha = pixel.a.toInt();
          if (alpha < 128) continue;

          final int r = pixel.r.toInt();
          final int g = pixel.g.toInt();
          final int b = pixel.b.toInt();

          // Quantiza para agrupar tons parecidos (passo 32).
          final int rq = (r ~/ 32) * 32;
          final int gq = (g ~/ 32) * 32;
          final int bq = (b ~/ 32) * 32;
          final int chave = (rq << 16) | (gq << 8) | bq;

          todas[chave] = (todas[chave] ?? 0) + 1;

          // Prioriza pixels coloridos: ignora branco/preto/cinza quase
          // neutros (fundo de foto, por exemplo) na primeira escolha.
          final int maxC = r > g ? (r > b ? r : b) : (g > b ? g : b);
          final int minC = r < g ? (r < b ? r : b) : (g < b ? g : b);
          final bool quaseBranco = r > 240 && g > 240 && b > 240;
          final bool quasePreto = r < 15 && g < 15 && b < 15;
          if (!quaseBranco && !quasePreto && (maxC - minC) > 24) {
            saturadas[chave] = (saturadas[chave] ?? 0) + 1;
          }
        }
      }

      final mapa =
          saturadas.isNotEmpty ? saturadas : todas;
      if (mapa.isEmpty) return corPadrao;

      final cor = mapa.entries
          .reduce(
            (atual, proxima) =>
                proxima.value > atual.value ? proxima : atual,
          )
          .key;
      return '0xFF${cor.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    } catch (_) {
      return corPadrao;
    }
  }

  /// Baixa a imagem de [url] e extrai a cor dominante.
  /// Retorna [corPadrao] se a URL for nula/vazia ou o download falhar.
  static Future<String> extrairDaUrl(String? url) async {
    try {
      if (url == null || url.trim().isEmpty || url.trim() == 'null') {
        return corPadrao;
      }
      final resposta = await http.get(Uri.parse(url.trim()));
      if (resposta.statusCode != 200 || resposta.bodyBytes.isEmpty) {
        return corPadrao;
      }
      return extrair(resposta.bodyBytes);
    } catch (_) {
      return corPadrao;
    }
  }

  /// Recalcula e salva o `cor_banner` do perfil no Supabase.
  ///
  /// - Se [fotoBytes] for informado, extrai dele (caso da troca de foto,
  ///   sem precisar baixar nada).
  /// - Senão, se [fotoUrl] for informado, baixa e extrai.
  /// - Se não houver foto, salva [corPadrao].
  /// Retorna a string salva (ou [corPadrao] em caso de falha).
  static Future<String> atualizarCorBanner({
    required SupabaseClient supabase,
    required int idPerfil,
    Uint8List? fotoBytes,
    String? fotoUrl,
  }) async {
    String cor = corPadrao;
    if (fotoBytes != null && fotoBytes.isNotEmpty) {
      cor = extrair(fotoBytes);
    } else if (fotoUrl != null &&
        fotoUrl.trim().isNotEmpty &&
        fotoUrl.trim() != 'null') {
      cor = await extrairDaUrl(fotoUrl);
    }
    try {
      await supabase
          .from('perfil')
          .update({'cor_banner': cor})
          .eq('id_perfil', idPerfil);
    } catch (_) {
      // Mantém a cor calculada localmente mesmo se o update falhar.
    }
    return cor;
  }

  static Color paraColor(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty || texto.toLowerCase() == 'null') {
      return corPadraoColor;
    }
    final normalizado = texto.startsWith('#')
        ? texto.substring(1)
        : texto.startsWith('0x') || texto.startsWith('0X')
            ? texto.substring(2)
            : texto;
    final numero = int.tryParse(normalizado, radix: 16);
    if (numero == null) return corPadraoColor;
    if (normalizado.length == 6) return Color(0xFF000000 | numero);
    if (normalizado.length == 8) return Color(numero);
    return corPadraoColor;
  }
}

