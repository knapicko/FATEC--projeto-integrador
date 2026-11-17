// Gera os ícones de notificação do Android a partir da logo do app.
//
//   dart run tool/gerar_icones_notificacao.dart
//
// - ic_notificacao.png (drawable-*dpi): ícone PEQUENO da notificação. O
//   Android (5+) usa SÓ o canal alfa dele: precisa ser a silhueta branca da
//   logo sobre fundo transparente. A cor (azul #0FB3FF) vem de
//   notificacao_azul / AndroidNotificationDetails.color. Um ícone opaco vira
//   um quadrado preenchido (o "quadrado preto" que aparecia).
// - notif_logo.png (drawable-nodpi): logo colorida usada como ícone GRANDE
//   quando a notificação não tem foto.
import 'dart:io';

import 'package:image/image.dart' as img;

const _origem = 'assets/images/icone/icone_consertaja.png';
const _res = 'android/app/src/main/res';

const _tamanhos = <String, int>{
  'drawable-mdpi': 24,
  'drawable-hdpi': 36,
  'drawable-xhdpi': 48,
  'drawable-xxhdpi': 72,
  'drawable-xxxhdpi': 96,
};

void main() {
  final logo = img.decodePng(File(_origem).readAsBytesSync());
  if (logo == null) {
    stderr.writeln('Não consegui ler $_origem');
    exit(1);
  }

  // Fundo #0FB3FF opaco por baixo da logo (cobre qualquer transparência).
  final comFundo = img.Image(
    width: logo.width,
    height: logo.height,
    numChannels: 4,
  );
  img.fill(comFundo, color: img.ColorRgba8(0x0F, 0xB3, 0xFF, 255));
  img.compositeImage(comFundo, logo);

  // Silhueta: só o branco da logo, recortada no conteúdo, com respiro.
  final silhueta = _silhueta(logo);
  for (final entrada in _tamanhos.entries) {
    final dir = Directory('$_res/${entrada.key}')..createSync(recursive: true);
    final reduzido = img.copyResize(
      silhueta,
      width: entrada.value,
      height: entrada.value,
      interpolation: img.Interpolation.average,
    );
    File(
      '${dir.path}/ic_notificacao.png',
    ).writeAsBytesSync(img.encodePng(reduzido));
    stdout.writeln('ok ${dir.path}/ic_notificacao.png (${entrada.value}px)');
  }

  final nodpi = Directory('$_res/drawable-nodpi')..createSync(recursive: true);
  final grande = img.copyResize(
    comFundo,
    width: 192,
    height: 192,
    interpolation: img.Interpolation.average,
  );
  File('${nodpi.path}/notif_logo.png').writeAsBytesSync(img.encodePng(grande));
  stdout.writeln('ok ${nodpi.path}/notif_logo.png (192px)');
}

/// Branco sobre transparente, quadrado, com ~6% de margem.
img.Image _silhueta(img.Image logo) {
  var x0 = logo.width, y0 = logo.height, x1 = 0, y1 = 0;
  for (final p in logo) {
    if (p.a < 40) continue;
    if (p.x < x0) x0 = p.x.toInt();
    if (p.y < y0) y0 = p.y.toInt();
    if (p.x > x1) x1 = p.x.toInt();
    if (p.y > y1) y1 = p.y.toInt();
  }
  final lado = ((x1 - x0) > (y1 - y0) ? (x1 - x0) : (y1 - y0)) + 1;
  final margem = (lado * 0.06).round();
  final total = lado + margem * 2;
  final saida = img.Image(width: total, height: total, numChannels: 4);
  final ox = margem + (lado - (x1 - x0 + 1)) ~/ 2 - x0;
  final oy = margem + (lado - (y1 - y0 + 1)) ~/ 2 - y0;
  for (final p in logo) {
    if (p.a == 0) continue;
    saida.setPixelRgba(p.x + ox, p.y + oy, 255, 255, 255, p.a.toInt());
  }
  return saida;
}
