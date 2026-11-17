// Gera os quadros da caixa "falando" (onboarding conversacional).
//
//   dart run tool/gerar_caixa_fala.dart
//
// A partir de assets/images/caixa/{caixa_normal, caixa_falando_aberto,
// caixa_falando_fechado}.png (branco sobre transparente; olhos e boca são
// "furos" no rosto) monta 8 quadros em assets/images/caixa/fala/:
//   olhos_{abertos|fechados}_boca_{fechada|meia|aberta|o}.png
// - boca fechada: o sorriso da caixa_normal;
// - aberta: a boca da caixa_falando_aberto;
// - meia: a boca aberta achatada (55% da altura);
// - o: a boca aberta estreita e um pouco mais baixa (formato de "o").
// Olhos fechados: os "^ ^" da caixa_falando_fechado.
import 'dart:io';

import 'package:image/image.dart' as img;

const _pasta = 'assets/images/caixa';
const _destino = 'assets/images/caixa/fala';

img.Image _ler(String nome) =>
    img.decodePng(File('$_pasta/$nome.png').readAsBytesSync())!;

/// Pixels do "furo" (transparente) que contém [semente], já com 1 px de
/// borda suave em volta.
Set<int> _furo(img.Image im, int sx, int sy) {
  final w = im.width;
  final furo = <int>{};
  final pilha = <int>[sy * w + sx];
  while (pilha.isNotEmpty) {
    final k = pilha.removeLast();
    if (!furo.add(k)) continue;
    final x = k % w, y = k ~/ w;
    for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= w || ny >= im.height) continue;
      final nk = ny * w + nx;
      if (!furo.contains(nk) && im.getPixel(nx, ny).a <= 128) pilha.add(nk);
    }
  }
  // Borda antisserrilhada (alpha parcial) em volta do furo.
  final borda = <int>{};
  for (final k in furo) {
    final x = k % w, y = k ~/ w;
    for (var dy = -2; dy <= 2; dy++) {
      for (var dx = -2; dx <= 2; dx++) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= im.height) continue;
        if (im.getPixel(nx, ny).a < 255) borda.add(ny * w + nx);
      }
    }
  }
  return {...furo, ...borda};
}

/// Primeiro pixel transparente da linha [y] entre [x0] e [x1].
(int, int) _semente(img.Image im, int y, int x0, int x1) {
  for (var x = x0; x <= x1; x++) {
    if (im.getPixel(x, y).a <= 128) return (x, y);
  }
  throw StateError('semente não encontrada na linha $y');
}

/// Preenche [pixels] de branco opaco (tapa o furo).
void _tapar(img.Image im, Set<int> pixels) {
  for (final k in pixels) {
    im.setPixelRgba(k % im.width, k ~/ im.width, 255, 255, 255, 255);
  }
}

/// Aplica o alpha de [fonte] nos [pixels] (abre o furo de [fonte] em [im]).
void _furar(img.Image im, img.Image fonte, Set<int> pixels) {
  for (final k in pixels) {
    final x = k % im.width, y = k ~/ im.width;
    final a = fonte.getPixel(x, y).a.toInt();
    final atual = im.getPixel(x, y).a.toInt();
    if (a < atual) im.setPixelRgba(x, y, 255, 255, 255, a);
  }
}

/// Boca aberta transformada (escala [sx]×[sy], presa no topo, centrada em
/// x) aplicada como furo em [im].
void _bocaEscalada(
  img.Image im,
  img.Image fonte,
  Set<int> boca,
  double sx,
  double sy,
) {
  var x0 = 9999, x1 = 0, y0 = 9999, y1 = 0;
  for (final k in boca) {
    final x = k % fonte.width, y = k ~/ fonte.width;
    if (x < x0) x0 = x;
    if (x > x1) x1 = x;
    if (y < y0) y0 = y;
    if (y > y1) y1 = y;
  }
  final cx = (x0 + x1) / 2;
  final topo = y0.toDouble();
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      // Ponto da boca original que cai em (x, y) depois de escalar.
      final ox = cx + (x - cx) / sx;
      final oy = topo + (y - topo) / sy;
      final ix = ox.round(), iy = oy.round();
      if (ix < x0 || ix > x1 || iy < y0 || iy > y1) continue;
      if (!boca.contains(iy * fonte.width + ix)) continue;
      final a = fonte.getPixel(ix, iy).a.toInt();
      final atual = im.getPixel(x, y).a.toInt();
      if (a < atual) im.setPixelRgba(x, y, 255, 255, 255, a);
    }
  }
}

void main() {
  final normal = _ler('caixa_normal');
  final aberto = _ler('caixa_falando_aberto');
  final fechado = _ler('caixa_falando_fechado');

  // Furos (medidos na arte 500×500).
  final (sx1, sy1) = _semente(normal, 346, 162, 245);
  final sorriso = _furo(normal, sx1, sy1);
  final (bx, by) = _semente(aberto, 335, 167, 226);
  final bocaAberta = _furo(aberto, bx, by);
  final olhoEsq = _furo(normal, 151, 302);
  final olhoDir = _furo(normal, 245, 320);
  final (fe1x, fe1y) = _semente(fechado, 300, 131, 171);
  final (fe2x, fe2y) = _semente(fechado, 315, 226, 270);
  final olhoEsqFechado = _furo(fechado, fe1x, fe1y);
  final olhoDirFechado = _furo(fechado, fe2x, fe2y);

  Directory(_destino).createSync(recursive: true);
  for (final olhosFechados in [false, true]) {
    for (final boca in ['fechada', 'meia', 'aberta', 'o']) {
      final q = normal.clone();
      if (olhosFechados) {
        _tapar(q, {...olhoEsq, ...olhoDir});
        _furar(q, fechado, {...olhoEsqFechado, ...olhoDirFechado});
      }
      if (boca != 'fechada') {
        _tapar(q, sorriso);
        switch (boca) {
          case 'aberta':
            _furar(q, aberto, bocaAberta);
          case 'meia':
            _bocaEscalada(q, aberto, bocaAberta, 1.0, 0.55);
          case 'o':
            _bocaEscalada(q, aberto, bocaAberta, 0.6, 0.85);
        }
      }
      final nome =
          'olhos_${olhosFechados ? 'fechados' : 'abertos'}_boca_$boca.png';
      File('$_destino/$nome').writeAsBytesSync(img.encodePng(q));
      stdout.writeln('ok $_destino/$nome');
    }
  }
}
