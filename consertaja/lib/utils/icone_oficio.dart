import 'package:flutter/material.dart';
import '../widgets/imagem_app.dart';

class IconeOficio {
  IconeOficio._();

  static const String _pastaCategorias = 'assets/images/oficios/categorias';
  static const String _pastaFuncao = 'assets/images/oficios/funcao';
  static const String _pastaAzul = 'assets/images/oficios/funcao_azul';

  /// Função (nome em minúsculas, como está em `funcoes.funcao`) → nome do
  /// arquivo do ícone. Os arquivos têm o MESMO nome da função:
  /// `funcao/<Nome>.png` (branco) e `funcao_azul/<Nome>_azul_claro.png`.
  static const Map<String, String> _arquivoPorFuncao = {
    'afiação': 'Afiação',
    'alfaiataria': 'Alfaiataria',
    'chaves e aberturas': 'Chaves e aberturas',
    'costura': 'Costura',
    'desentupimento': 'Desentupimento',
    'elétrica': 'Elétrica',
    'encanamento': 'Encanamento',
    'ferraria': 'Ferraria',
    'funilaria': 'Funilaria',
    'hidráulica': 'Hidráulica',
    'higienização de colchões': 'Higienização de colchões',
    'instalação de fechaduras': 'Instalação de fechaduras',
    'lavagem de tapetes': 'Lavagem de tapetes',
    'marcenaria': 'Marcenaria',
    'montagem de móveis': 'Montagem de móveis',
    'panelaria': 'Panelaria',
    'pintura': 'Pintura',
    'reparos gerais': 'Reparos gerais',
    'sapataria': 'Sapataria',
    'selaria e couro': 'Selaria e couro',
    'serralheria': 'Serralheria',
    'solda de utensílios': 'Solda de utensílios',
    'tapeçaria': 'Tapeçaria',
    'vidraçaria': 'Vidraçaria',
  };

  /// Nomes antigos (do profissional) e funções parecidas → função com ícone.
  static const Map<String, String> _apelidos = {
    'afiador': 'afiação',
    'chaveiro': 'chaves e aberturas',
    'costureira': 'costura',
    'bordado': 'costura',
    'desentupidor': 'desentupimento',
    'eletricista': 'elétrica',
    'encanador': 'encanamento',
    'funileiro': 'funilaria',
    'instalador de fechadura': 'instalação de fechaduras',
    'lavador de colchão': 'higienização de colchões',
    'lavador de tapete': 'lavagem de tapetes',
    'marceneiro': 'marcenaria',
    'montador de móveis': 'montagem de móveis',
    'paneleiro': 'panelaria',
    'conserto de panelas': 'panelaria',
    'reparador geral': 'reparos gerais',
    'sapateiro': 'sapataria',
    'serralheiro': 'serralheria',
    'soldador de utensílios': 'solda de utensílios',
    'tapeceiro': 'tapeçaria',
    'vidraceiro': 'vidraçaria',
    'pintor': 'pintura',
    'encanador hidráulico': 'hidráulica',
    'alfaiate': 'alfaiataria',
    'seleiro': 'selaria e couro',
    'ferreiro': 'ferraria',
  };

  static const Map<String, String> _iconesPorCategoria = {
    'reparos domésticos': '$_pastaCategorias/reparos_domesticos.png',
    'móveis e interiores': '$_pastaCategorias/moveis_e_interiores.png',
    'segurança': '$_pastaCategorias/seguranca.png',
    'vidros e estruturas': '$_pastaCategorias/vidros_e_estruturas.png',
    'reparos pessoais': '$_pastaCategorias/reparos_pessoais.png',
    'limpeza especializada': '$_pastaCategorias/limpeza_especializada.png',
    'serviços tradicionais': '$_pastaCategorias/servicos_tradicionais.png',
    'eletrodomésticos e eletrônicos':
        '$_pastaCategorias/eletrodomesticos_e_eletronicos.png',
  };

  static String? caminhoParaCategoria(String? categoria) {
    if (categoria == null || categoria.trim().isEmpty) return null;
    return _iconesPorCategoria[categoria.trim().toLowerCase()];
  }

  static String? _arquivo(String? funcao) {
    final c = (funcao ?? '').trim().toLowerCase();
    return _arquivoPorFuncao[_apelidos[c] ?? c];
  }

  static String? caminhoParaFuncao(String? funcao) {
    final a = _arquivo(funcao);
    return a == null ? null : '$_pastaFuncao/$a.png';
  }

  static String? caminhoParaFuncaoAzul(String? funcao) {
    final a = _arquivo(funcao);
    return a == null ? null : '$_pastaAzul/${a}_azul_claro.png';
  }

  static Widget imagem(String? categoria, {double tamanho = 30}) {
    final caminho = caminhoParaCategoria(categoria);
    if (caminho == null) {
      return Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho);
    }
    return ImagemApp(child: Image.asset(
      caminho,
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho),
    ));
  }

  /// Ícone da CATEGORIA (ofício). Os arquivos são brancos; [cor] pinta.
  static Widget imagemCategoria(
    String? categoria, {
    double tamanho = 30,
    Color cor = Colors.white,
  }) {
    final caminho = caminhoParaCategoria(categoria);
    if (caminho == null) {
      return Icon(Icons.handyman_outlined, color: cor, size: tamanho);
    }
    return ImagemApp(child: Image.asset(
      caminho,
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      color: cor == Colors.white ? null : cor,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, _, _) =>
          Icon(Icons.handyman_outlined, color: cor, size: tamanho),
    ));
  }

  static Widget imagemPorFuncao(String? funcao, {double tamanho = 30}) {
    final caminho = caminhoParaFuncao(funcao);
    // A área de atuação agora é o OFÍCIO (categoria): usa o ícone dela.
    if (caminho == null && caminhoParaCategoria(funcao) != null) {
      return imagemCategoria(funcao, tamanho: tamanho);
    }
    if (caminho == null) {
      return Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho);
    }
    return ImagemApp(child: Image.asset(
      caminho,
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho),
    ));
  }

  static Widget imagemPorFuncaoAzul(String? funcao, {double tamanho = 30}) {
    final caminho = caminhoParaFuncaoAzul(funcao);
    if (caminho == null && caminhoParaCategoria(funcao) != null) {
      return imagemCategoria(
        funcao,
        tamanho: tamanho,
        cor: const Color(0xFF0FB3FF),
      );
    }
    if (caminho == null) {
      return Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho);
    }
    return ImagemApp(child: Image.asset(
      caminho,
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho),
    ));
  }
}
