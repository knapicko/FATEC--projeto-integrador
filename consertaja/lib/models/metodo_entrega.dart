import 'package:flutter/material.dart';

class MetodoEntregaOpcao {
  const MetodoEntregaOpcao({
    required this.valor,
    required this.titulo,
    required this.descricao,
    required this.icone,
  });

  final String valor;
  final String titulo;
  final String descricao;
  final IconData icone;
}

const List<MetodoEntregaOpcao> metodosEntregaOpcoes = [
  MetodoEntregaOpcao(
    valor: 'Leva e Traz',
    titulo: 'Leva e Traz',
    descricao: 'Busco no cliente e entrego de volta.',
    icone: Icons.local_shipping_outlined,
  ),
  MetodoEntregaOpcao(
    valor: 'Retirado no Local',
    titulo: 'Retirada no Local',
    descricao: 'O cliente traz o item até mim e vem buscar depois.',
    icone: Icons.storefront_outlined,
  ),
  MetodoEntregaOpcao(
    valor: 'Receba em Casa',
    titulo: 'Receba em Casa',
    descricao: 'O cliente traz o item até mim, mas eu faço a entrega final.',
    icone: Icons.home_outlined,
  ),
  MetodoEntregaOpcao(
    valor: 'Atendimento em Domicílio',
    titulo: 'Atendimento em Domicílio',
    descricao: 'Vou até o endereço do cliente para realizar o serviço.',
    icone: Icons.home_repair_service_outlined,
  ),
];
