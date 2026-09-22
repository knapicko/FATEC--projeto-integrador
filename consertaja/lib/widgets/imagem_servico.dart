import 'package:flutter/material.dart';

import '../utils/cor_oficio.dart';
import '../utils/icone_oficio.dart';

/// Imagem de capa de um serviço: usa `imagemUrl` quando houver; senão exibe
/// o símbolo da função/ofício sobre a cor da categoria — mesmo padrão de
/// `meus_servicos_profissional.dart`.
class ImagemServico extends StatelessWidget {
  final String? imagemUrl;
  final String? funcao;
  final String? cor;
  final double height;
  final double? width;
  final BoxFit fit;
  final double tamanhoIcone;

  const ImagemServico({
    super.key,
    this.imagemUrl,
    this.funcao,
    this.cor,
    this.height = 100,
    this.width,
    this.fit = BoxFit.cover,
    this.tamanhoIcone = 48,
  });

  @override
  Widget build(BuildContext context) {
    final url = imagemUrl?.trim() ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        height: height,
        width: width ?? double.infinity,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    // Fundo = coluna `cor` de `oficios` (enum Cores Oficio, ex. 'vinho',
    // 'azul claro'); `CorOficio.parse` resolve o nome para a Color.
    final corBase = CorOficio.parse(cor);
    return Container(
      height: height,
      width: width ?? double.infinity,
      color: corBase,
      alignment: Alignment.center,
      child: IconeOficio.imagemPorFuncao(funcao, tamanho: tamanhoIcone),
    );
  }
}
