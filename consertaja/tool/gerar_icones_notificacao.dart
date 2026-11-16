// Gera os ícones de notificação do Android a partir da logo do app.
//
//   dart run tool/gerar_icones_notificacao.dart
//
// - ic_notificacao.png (drawable-*dpi): ícone PEQUENO da notificação. É a
//   própria logo (icone_consertaja.png), com o fundo #0FB3FF opaco.
//   Atenção: o Android (5+) usa só o canal alfa do ícone pequeno na barra de
//   status — um ícone todo opaco aparece ali como um quadrado preenchido.
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

  for (final entrada in _tamanhos.entries) {
    final dir = Directory('$_res/${entrada.key}')..createSync(recursive: true);
    final reduzido = img.copyResize(
      comFundo,
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
