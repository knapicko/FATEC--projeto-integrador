import 'package:flutter/material.dart';

import '../services/app_settings_controller.dart';
import '../services/rede_service.dart';

/// URLs que o usuário mandou carregar nesta sessão (tocando no espaço da
/// imagem quando o carregamento automático estava desligado).
final Set<String> _liberadas = <String>{};

/// Mantém as cores reais de [child] no modo escuro.
///
/// O modo escuro do app é um filtro sobre a tela inteira; aqui aplicamos o
/// filtro inverso, então fotos, avatares e ilustrações não ficam com as cores
/// invertidas — só textos e elementos da interface mudam de cor.
///
/// Também é usado nas áreas com FUNDO AZUL (cabeçalhos, botões, chips,
/// ícones em caixa azul) com [interface] = true: o azul continua vivo e o
/// texto/ícone branco continua branco (o filtro deixaria o branco escuro).
/// [ativo] = false desliga sem mudar a árvore (ex.: chip não selecionado).
class CorOriginal extends StatelessWidget {
  const CorOriginal({
    super.key,
    required this.child,
    this.ativo = true,
    this.interface = false,
  });

  final Widget child;
  final bool ativo;
  final bool interface;

  static const List<double> _identidade = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    // Já está dentro de outro CorOriginal ativo: aplicar de novo inverteria.
    final pai = context.dependOnInheritedWidgetOfExactType<_JaOriginal>();
    if (pai != null && pai.ativo) return child;
    final brilho = MediaQuery.platformBrightnessOf(context);
    return ListenableBuilder(
      listenable: AppSettingsController.instance,
      builder: (context, _) {
        final matriz = AppSettingsController.instance.matrizCorOriginal(
          brilho,
          escurecer: !interface,
        );
        if (matriz == null) return child;
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(ativo ? matriz : _identidade),
          child: _JaOriginal(ativo: ativo, child: child),
        );
      },
    );
  }
}

/// [AppBar] com fundo azul que mantém as cores no modo escuro.
class BarraCorOriginal extends StatelessWidget implements PreferredSizeWidget {
  const BarraCorOriginal({super.key, required this.child});

  final PreferredSizeWidget child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) =>
      CorOriginal(interface: true, child: child);
}

class _JaOriginal extends InheritedWidget {
  const _JaOriginal({required this.ativo, required super.child});

  final bool ativo;

  @override
  bool updateShouldNotify(_JaOriginal oldWidget) => oldWidget.ativo != ativo;
}

/// Toda imagem do app passa por aqui:
/// • no modo escuro mantém as cores reais ([CorOriginal]);
/// • imagens da internet seguem "Rede e dados" (carregar sempre, só no
///   Wi-Fi, nunca, economia de dados). Quando não carrega, mostra um espaço
///   com "Toque para carregar".
class ImagemApp extends StatelessWidget {
  const ImagemApp({super.key, required this.child});

  final Image child;

  static String? _urlDe(ImageProvider p) {
    if (p is NetworkImage) return p.url;
    if (p is ResizeImage) return _urlDe(p.imageProvider);
    return null;
  }

  /// Se a imagem da internet pode ser baixada agora.
  static bool podeCarregar(String url) {
    if (_liberadas.contains(url)) return true;
    final cfg = AppSettingsController.instance;
    final rede = RedeService.instance;
    // Já está na memória: não gasta dados.
    if (PaintingBinding.instance.imageCache.containsKey(NetworkImage(url))) {
      return true;
    }
    switch (cfg.carregamentoImagens) {
      case 'Nunca':
        return false;
      case 'Somente Wi-Fi':
        return rede.emWifi;
    }
    if (cfg.economiaDados && !rede.emWifi) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final url = _urlDe(child.image);
    if (url == null) return CorOriginal(child: child);
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppSettingsController.instance,
        RedeService.instance,
      ]),
      builder: (context, _) {
        if (podeCarregar(url)) return CorOriginal(child: child);
        return _EspacoImagem(
          largura: child.width,
          altura: child.height,
          aoTocar: () {
            _liberadas.add(url);
            // Reconstrói (o ListenableBuilder escuta as configurações).
            (context as Element).markNeedsBuild();
          },
        );
      },
    );
  }
}

class _EspacoImagem extends StatelessWidget {
  const _EspacoImagem({this.largura, this.altura, required this.aoTocar});

  final double? largura;
  final double? altura;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: aoTocar,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = largura ?? (c.hasBoundedWidth ? c.maxWidth : 120.0);
          final h = altura ?? (c.hasBoundedHeight ? c.maxHeight : w * 0.6);
          final pequeno = w < 90 || h < 60;
          return Container(
            width: w,
            height: h,
            color: const Color(0xFFE4E8ED),
            alignment: Alignment.center,
            child: pequeno
                ? const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF8A939C),
                    size: 20,
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_rounded,
                        color: Color(0xFF6B7580),
                        size: 22,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Toque para carregar',
                        style: TextStyle(
                          color: Color(0xFF6B7580),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
