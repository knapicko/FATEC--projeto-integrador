// Gera as camadas da animação da tela inicial com fundo TRANSPARENTE.
//
//   dart run tool/gerar_caixa_animacao.dart
//
// As artes originais (assets/images/caixa_animacao/*.png) vêm com fundo azul
// opaco (#1DB1F6), um pouco diferente do #0FB3FF da tela — sobre o fundo da
// tela apareceria um quadrado. Aqui o desenho branco vira branco sobre
// transparente (borda suave), em assets/images/caixa_animacao/transparente/.
import 'dart:io';
import 'dart:math' as math;

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
    // Arte que já vem com fundo transparente (Ferramentas.png, com borda
    // azul): vira só o preenchimento branco, com as chaves separadas.
    if (original.numChannels == 4 && original.getPixel(0, 0).a == 0) {
      final pronta = entrada.key == 'Ferramentas.png'
          ? _separarChaves(original)
          : original;
      File(
        '$_destino/${entrada.value}',
      ).writeAsBytesSync(img.encodePng(pronta));
      stdout.writeln('ok (borda da arte) $_destino/${entrada.value}');
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

/// Espessura (px na arte 500×500) do contorno das ferramentas: a mesma das
/// divisórias da caixa (ex.: entre o rosto e a lateral), que medem ~8 px de
/// um branco ao outro. O contorno tem a cor do fundo da tela, como elas.
const _espessuraContorno = 6.0;

/// Ferramentas.png → só o preenchimento branco das ferramentas (a borda azul
/// da arte é retirada; o contorno vem de ferramentas_mascara.png, pintada no
/// app com a cor do fundo — igual às linhas da caixa).
///
/// A chave ajustável e a chave de fenda se encostam embaixo (um "V" colado):
/// são cortadas no vértice do V e a chave ajustável é afastada um pouco.
img.Image _separarChaves(img.Image base) {
  final w = base.width, h = base.height;
  const deslocX = -12, deslocY = -4;

  // Par colado: flood fill a partir da chave ajustável.
  final par = List<bool>.filled(w * h, false);
  int? semente;
  for (var x = 100; x < 200 && semente == null; x++) {
    if (base.getPixel(x, 165).a > 20) semente = 165 * w + x;
  }
  if (semente != null) {
    final pilha = <int>[semente];
    par[semente] = true;
    while (pilha.isNotEmpty) {
      final i = pilha.removeLast();
      final x = i % w, y = i ~/ w;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx, yy = y + dy;
          if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
          final j = yy * w + xx;
          if (par[j] || base.getPixel(xx, yy).a <= 20) continue;
          par[j] = true;
          pilha.add(j);
        }
      }
    }
  }
  // Corte: acima de y=200 já estão separadas; abaixo, linha que sai do
  // vértice do V (~187, 250) e desce quase reta.
  bool ehChaveAjustavel(int x, int y) =>
      y < 200 ? x < 200 : x < 187 + (y - 250) * 0.15;

  final saida = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = base.getPixel(x, y);
      // Branco = preenchimento; azul da borda = fora.
      final branco = ((p.r - 30) / (240 - 30)).clamp(0.0, 1.0) * (p.a / 255);
      if (branco <= 0) continue;
      var xx = x, yy = y;
      if (par[y * w + x] && ehChaveAjustavel(x, y)) {
        xx += deslocX;
        yy += deslocY;
        if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
      }
      final a = (branco * 255).round();
      if (a > saida.getPixel(xx, yy).a) {
        saida.setPixelRgba(xx, yy, 255, 255, 255, a);
      }
    }
  }
  return saida;
}

/// Silhueta "engordada" das ferramentas (ferramentas_mascara.png), com borda
/// suave. No app é pintada com a cor do fundo e fica por baixo das
/// ferramentas: vira o contorno delas, igual às linhas da caixa.
void _contornarFerramentas() {
  final base = img.decodePng(
    File('$_destino/ferramentas.png').readAsBytesSync(),
  )!;
  final w = base.width, h = base.height;
  final cheio = List<bool>.generate(
    w * h,
    (i) => base.getPixel(i % w, i ~/ w).a >= 128,
  );
  final r = _espessuraContorno.ceil() + 1;
  final saida = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var dist = cheio[y * w + x] ? 0.0 : double.infinity;
      if (dist > 0) {
        for (var dy = -r; dy <= r; dy++) {
          final yy = y + dy;
          if (yy < 0 || yy >= h) continue;
          for (var dx = -r; dx <= r; dx++) {
            final xx = x + dx;
            if (xx < 0 || xx >= w || !cheio[yy * w + xx]) continue;
            final d = math.sqrt(dx * dx + dy * dy);
            if (d < dist) dist = d;
          }
        }
      }
      final a = (_espessuraContorno + 0.5 - dist).clamp(0.0, 1.0);
      if (a > 0) saida.setPixelRgba(x, y, 255, 255, 255, (a * 255).round());
    }
  }
  File(
    '$_destino/ferramentas_mascara.png',
  ).writeAsBytesSync(img.encodePng(saida));
  stdout.writeln('ok $_destino/ferramentas_mascara.png');
}

/// Borda de cima da FACE DA FRENTE da caixa aberta (medida na arte 500×500):
/// sobe da esquerda (101,232) até a quina (318,272) e desce até (407,236).
/// Trinco da caixa aberta (retângulo azul no meio da borda da frente), com
/// uma margem para pegar o contorno inteiro.
const _trinco = (left: 169, top: 231, right: 227, bottom: 287);

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

  bool azul(int x, int y) => !branco(x, y);

  for (var x = 0; x < original.width; x++) {
    final dentroDaCaixa = x >= 98 && x <= 410;
    var topo = dentroDaCaixa ? _bordaFrente(x).floor() - 1 : original.height;
    if (dentroDaCaixa) {
      // A divisória azul da borda de cima da frente fica INTEIRA na frente:
      // sobe até o fim da faixa azul, senão as ferramentas passavam por
      // cima da metade dela ao flutuar.
      var y = (_bordaFrente(x) + 8).floor().clamp(0, original.height - 1);
      while (y > 0 && branco(x, y)) {
        y--;
      }
      while (y > 0 && azul(x, y)) {
        y--;
      }
      if (y + 1 < topo) topo = y + 1;
    }
    // Trinco (retângulo no meio da borda): todo ele, contorno incluso, fica
    // na frente — as ferramentas passam por trás dele.
    final noTrinco = x >= _trinco.left && x <= _trinco.right;
    if (noTrinco && _trinco.top < topo) topo = _trinco.top;
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
