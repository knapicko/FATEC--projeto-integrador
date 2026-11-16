// Gera as camadas da animação da tela inicial com fundo TRANSPARENTE.
//
//   dart run tool/gerar_caixa_animacao.dart
//
// As artes originais (assets/images/caixa_animacao/*.png) vêm com fundo azul
// opaco (#1DB1F6), um pouco diferente do #0FB3FF da tela — sobre o fundo da
// tela apareceria um quadrado. Aqui o desenho branco vira branco sobre
// transparente (borda suave), em assets/images/caixa_animacao/transparente/.
import 'dart:io';

import 'package:image/image.dart' as img;

const _origem = 'assets/images/caixa_animacao';
const _destino = 'assets/images/caixa_animacao/transparente';

const _arquivos = {
  'Caixa_fechada.png': 'caixa_fechada.png',
  'Caixa_aberta.png': 'caixa_aberta.png',
  'Ferramentas.png': 'ferramentas.png',
};

void main() {
  Directory(_destino).createSync(recursive: true);
  for (final entrada in _arquivos.entries) {
    final original = img.decodePng(
      File('$_origem/${entrada.key}').readAsBytesSync(),
    );
    if (original == null) {
      stderr.writeln('Não consegui ler ${entrada.key}');
      exit(1);
    }
    // Arte que já vem com fundo transparente (ex.: Ferramentas.png com a
    // borda azul) é usada como está: a conversão abaixo apagaria o azul.
    if (original.numChannels == 4 && original.getPixel(0, 0).a == 0) {
      File(
        '$_destino/${entrada.value}',
      ).writeAsBytesSync(img.encodePng(original));
      stdout.writeln('ok (como está) $_destino/${entrada.value}');
      continue;
    }
    final saida = img.Image(
      width: original.width,
      height: original.height,
      numChannels: 4,
    );
    for (final p in original) {
      final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
      final minimo = [r, g, b].reduce((a, c) => a < c ? a : c);
      final maximo = [r, g, b].reduce((a, c) => a > c ? a : c);
      // Branco → opaco; azul do fundo → transparente; antialias suave.
      final brancura =
          ((minimo - 40) / (235 - 40)).clamp(0.0, 1.0) *
          (1 - ((maximo - minimo) / 255).clamp(0.0, 1.0) * 0.6);
      saida.setPixelRgba(p.x, p.y, 255, 255, 255, (brancura * 255).round());
    }
    File('$_destino/${entrada.value}').writeAsBytesSync(img.encodePng(saida));
    stdout.writeln('ok $_destino/${entrada.value}');
  }
  _separarCaixaAberta();
  _contornarFerramentas();
}

/// Silhueta "engordada" das ferramentas (ferramentas_mascara.png). No app ela
/// é pintada com a cor do fundo e fica por baixo das ferramentas, formando um
/// contorno: sem ele, onde elas passam na frente da tampa (branco sobre
/// branco) tudo vira uma mancha só.
void _contornarFerramentas() {
  final base = img.decodePng(
    File('$_destino/ferramentas.png').readAsBytesSync(),
  )!;
  const raio = 9;
  final w = base.width, h = base.height;
  final alfa = List<int>.generate(
    w * h,
    (i) => base.getPixel(i % w, i ~/ w).a.toInt(),
  );
  // Dilatação separável (máximo em x, depois em y).
  final horizontal = List<int>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var m = 0;
      for (var d = -raio; d <= raio; d++) {
        final xx = x + d;
        if (xx < 0 || xx >= w) continue;
        final v = alfa[y * w + xx];
        if (v > m) m = v;
      }
      horizontal[y * w + x] = m;
    }
  }
  final saida = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var m = 0;
      for (var d = -raio; d <= raio; d++) {
        final yy = y + d;
        if (yy < 0 || yy >= h) continue;
        final v = horizontal[yy * w + x];
        if (v > m) m = v;
      }
      saida.setPixelRgba(x, y, 255, 255, 255, m);
    }
  }
  File(
    '$_destino/ferramentas_mascara.png',
  ).writeAsBytesSync(img.encodePng(saida));
  stdout.writeln('ok $_destino/ferramentas_mascara.png');
}

/// Borda de cima da FACE DA FRENTE da caixa aberta (medida na arte 500×500):
/// sobe da esquerda (101,232) até a quina (318,272) e desce até (407,236).
double _bordaFrente(int x) {
  if (x <= 318) return 232 + (x - 101) * (272 - 232) / (318 - 101);
  return 272 + (x - 318) * (236 - 272) / (407 - 318);
}

/// Divide a caixa aberta em duas camadas para as ferramentas ficarem
/// "dentro" dela:
///   • caixa_aberta_fundo.png — tampa + interior (atrás das ferramentas);
///   • caixa_aberta_frente.png — traços brancos das faces da frente;
///   • caixa_aberta_frente_mascara.png — silhueta da frente (branco opaco).
///     No app ela é pintada com a cor do fundo da tela e desenhada por baixo
///     dos traços: cobre a parte de baixo das ferramentas sem perder olhos,
///     sorriso e contornos, e combina com qualquer azul de fundo.
void _separarCaixaAberta() {
  final original = img.decodePng(
    File('$_origem/Caixa_aberta.png').readAsBytesSync(),
  )!;
  final fundo = img.Image(
    width: original.width,
    height: original.height,
    numChannels: 4,
  );
  final frente = img.Image(
    width: original.width,
    height: original.height,
    numChannels: 4,
  );
  final mascara = img.Image(
    width: original.width,
    height: original.height,
    numChannels: 4,
  );

  bool branco(int x, int y) {
    final p = original.getPixel(x, y);
    return p.r > 200 && p.g > 200 && p.b > 200;
  }

  for (var x = 0; x < original.width; x++) {
    final dentroDaCaixa = x >= 98 && x <= 410;
    final topo = dentroDaCaixa ? _bordaFrente(x).floor() - 1 : original.height;
    // Pé da face nesta coluna (último branco de baixo para cima).
    var pe = -1;
    if (dentroDaCaixa) {
      for (var y = original.height - 1; y >= topo; y--) {
        if (branco(x, y)) {
          pe = y;
          break;
        }
      }
    }
    for (var y = 0; y < original.height; y++) {
      final p = original.getPixel(x, y);
      final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
      final minimo = [r, g, b].reduce((a, c) => a < c ? a : c);
      final maximo = [r, g, b].reduce((a, c) => a > c ? a : c);
      final brancura =
          ((minimo - 40) / (235 - 40)).clamp(0.0, 1.0) *
          (1 - ((maximo - minimo) / 255).clamp(0.0, 1.0) * 0.6);
      final alfa = (brancura * 255).round();

      if (dentroDaCaixa && pe >= topo && y >= topo && y <= pe) {
        frente.setPixelRgba(x, y, 255, 255, 255, alfa);
        mascara.setPixelRgba(x, y, 255, 255, 255, 255);
      } else if (!(dentroDaCaixa && y >= topo)) {
        fundo.setPixelRgba(x, y, 255, 255, 255, alfa);
      }
    }
  }

  File(
    '$_destino/caixa_aberta_fundo.png',
  ).writeAsBytesSync(img.encodePng(fundo));
  File(
    '$_destino/caixa_aberta_frente.png',
  ).writeAsBytesSync(img.encodePng(frente));
  File(
    '$_destino/caixa_aberta_frente_mascara.png',
  ).writeAsBytesSync(img.encodePng(mascara));
  stdout.writeln('ok $_destino/caixa_aberta_fundo.png');
  stdout.writeln('ok $_destino/caixa_aberta_frente.png');
  stdout.writeln('ok $_destino/caixa_aberta_frente_mascara.png');
}
