import 'package:flutter/material.dart';

class IconeOficio {
  IconeOficio._();

  static const String _pastaCategorias = 'assets/images/oficios/categorias';
  static const String _pastaFuncao = 'assets/images/oficios/funcao';
  static const String _pastaAzul = 'assets/images/oficios/funcao_azul';

  static const Map<String, String> _iconesPorFuncao = {
    'afiador': '$_pastaFuncao/Afiador.png',
    'chaveiro': '$_pastaFuncao/Chaveiro.png',
    'costureira': '$_pastaFuncao/Costureira.png',
    'desentupidor': '$_pastaFuncao/Desentupidor.png',
    'eletricista': '$_pastaFuncao/Eletricista.png',
    'encanador': '$_pastaFuncao/Encanador.png',
    'funileiro': '$_pastaFuncao/Funileiro.png',
    'instalador de fechadura': '$_pastaFuncao/Instalador de fechadura.png',
    'lavador de colchão': '$_pastaFuncao/Lavador de colchão.png',
    'lavador de tapete': '$_pastaFuncao/Lavador de tapete.png',
    'marceneiro': '$_pastaFuncao/Marceneiro.png',
    'montador de móveis': '$_pastaFuncao/Montador de móveis.png',
    'paneleiro': '$_pastaFuncao/Paneleiro.png',
    'reparador geral': '$_pastaFuncao/Reparador geral.png',
    'sapateiro': '$_pastaFuncao/Sapateiro.png',
    'serralheiro': '$_pastaFuncao/Serralheiro.png',
    'soldador de utensílios': '$_pastaFuncao/Soldador de utensílios.png',
    'tapeceiro': '$_pastaFuncao/Tapeceiro.png',
    'vidraceiro': '$_pastaFuncao/Vidraceiro.png',
  };

  static const Map<String, String> _iconesPorFuncaoAzul = {
    'afiador': '$_pastaAzul/Afiador_azul_claro.png',
    'chaveiro': '$_pastaAzul/Chaveiro_azul_claro.png',
    'costureira': '$_pastaAzul/Costureira_azul_claro.png',
    'desentupidor': '$_pastaAzul/Desentupidor_azul_claro.png',
    'eletricista': '$_pastaAzul/Eletricista_azul_claro.png',
    'encanador': '$_pastaAzul/Encanador_azul_claro.png',
    'funileiro': '$_pastaAzul/Funileiro_azul_claro.png',
    'instalador de fechadura':
        '$_pastaAzul/Instalador de fechadura_azul_claro.png',
    'lavador de colchão': '$_pastaAzul/Lavador de colchão_azul_claro.png',
    'lavador de tapete': '$_pastaAzul/Lavador de tapete_azul_claro.png',
    'marceneiro': '$_pastaAzul/Marceneiro_azul_claro.png',
    'montador de móveis': '$_pastaAzul/Montador de móveis_azul_claro.png',
    'paneleiro': '$_pastaAzul/Paneleiro_azul_claro.png',
    'reparador geral': '$_pastaAzul/Reparador geral_azul_claro.png',
    'sapateiro': '$_pastaAzul/Sapateiro_azul_claro.png',
    'serralheiro': '$_pastaAzul/Serralheiro_azul_claro.png',
    'soldador de utensílios':
        '$_pastaAzul/Soldador de utensílios_azul_claro.png',
    'tapeceiro': '$_pastaAzul/Tapeceiro_azul_claro.png',
    'vidraceiro': '$_pastaAzul/Vidraceiro_azul_claro.png',
  };

  static const Map<String, String> _iconesPorCategoria = {
    'reparos domésticos': '$_pastaCategorias/reparos_domesticos.png',
    'móveis e interiores': '$_pastaCategorias/moveis_e_interiores.png',
    'segurança': '$_pastaCategorias/seguranca.png',
    'vidros e estruturas': '$_pastaCategorias/vidros_e_estruturas.png',
    'reparos pessoais': '$_pastaCategorias/reparos_pessoais.png',
    'limpeza especializada': '$_pastaCategorias/limpeza_especializada.png',
    'serviços tradicionais': '$_pastaCategorias/servicos_tradicionais.png',
  };

  static String? caminhoParaCategoria(String? categoria) {
    if (categoria == null || categoria.trim().isEmpty) return null;
    return _iconesPorCategoria[categoria.trim().toLowerCase()];
  }

  static String? caminhoParaFuncao(String? funcao) {
    final chave = (funcao ?? '').trim().toLowerCase();
    return _iconesPorFuncao[chave];
  }

  static String? caminhoParaFuncaoAzul(String? funcao) {
    final chave = (funcao ?? '').trim().toLowerCase();
    return _iconesPorFuncaoAzul[chave];
  }

  static Widget imagem(String? categoria, {double tamanho = 30}) {
    final caminho = caminhoParaCategoria(categoria);
    if (caminho == null) {
      return Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho);
    }
    return Image.asset(
      caminho,
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho),
    );
  }

  static Widget imagemPorFuncao(String? funcao, {double tamanho = 30}) {
    final caminho = caminhoParaFuncao(funcao);
    if (caminho == null) {
      return Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho);
    }
    return Image.asset(
      caminho,
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho),
    );
  }

  static Widget imagemPorFuncaoAzul(String? funcao, {double tamanho = 30}) {
    final caminho = caminhoParaFuncaoAzul(funcao);
    if (caminho == null) {
      return Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho);
    }
    return Image.asset(
      caminho,
      width: tamanho,
      height: tamanho,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Icon(Icons.handyman_outlined, color: Colors.white, size: tamanho),
    );
  }
}
