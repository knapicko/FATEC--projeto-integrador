import 'package:flutter/material.dart';

class IconeOficio {
  IconeOficio._();

  static const String _pasta = 'assets/images/oficios';

  static const Map<String, String> _iconesPorCategoria = {
    'reparos domésticos': '$_pasta/reparos_domesticos.png',
    'móveis e interiores': '$_pasta/moveis_e_interiores.png',
    'segurança': '$_pasta/seguranca.png',
    'vidros e estruturas': '$_pasta/vidros_e_estruturas.png',
    'reparos pessoais': '$_pasta/reparos_pessoais.png',
    'limpeza especializada': '$_pasta/limpeza_especializada.png',
    'serviços tradicionais': '$_pasta/servicos_tradicionais.png',
  };

  static String? caminhoPara(String? categoria) {
    if (categoria == null || categoria.trim().isEmpty) return null;
    return _iconesPorCategoria[categoria.trim().toLowerCase()];
  }

  static Widget imagem(String? categoria, {double tamanho = 30}) {
    final caminho = caminhoPara(categoria);
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
