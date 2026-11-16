// Ícone do app (launcher) a partir da logo com fundo transparente.
//
//   dart run tool/gerar_icone_app.dart
//   dart run flutter_launcher_icons
//
// assets/images/icone/icone_consertaja.png agora é branca sobre transparente
// (ótimo para o splash e para o ícone adaptativo do Android). Ícone "comum"
// do Android antigo e o do iOS precisam de fundo opaco: esta versão aplica o
// azul #0FB3FF por baixo.
import 'dart:io';

import 'package:image/image.dart' as img;

const _origem = 'assets/images/icone/icone_consertaja.png';
const _destino = 'assets/images/icone/icone_consertaja_fundo_azul.png';

void main() {
  final logo = img.decodePng(File(_origem).readAsBytesSync());
  if (logo == null) {
    stderr.writeln('Não consegui ler $_origem');
    exit(1);
  }
  final comFundo = img.Image(
    width: logo.width,
    height: logo.height,
    numChannels: 4,
  );
  img.fill(comFundo, color: img.ColorRgba8(0x0F, 0xB3, 0xFF, 255));
  img.compositeImage(comFundo, logo);
  File(_destino).writeAsBytesSync(img.encodePng(comFundo));
  stdout.writeln('ok $_destino');
}
