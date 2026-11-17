import 'package:flutter/material.dart';

import '../services/home_cliente_service.dart';
import 'imagem_servico.dart';

/// Card de serviço da home ("Serviços Populares") e de "Todos os serviços":
/// foto grande com a nota, nome, descrição, preço e "Agendar".
class CardServicoPopular extends StatelessWidget {
  const CardServicoPopular({
    super.key,
    required this.item,
    required this.aoTocar,
  });

  final ServicoAvaliado item;
  final VoidCallback aoTocar;

  static const _azul = Color(0xFF0FB3FF);

  String _preco(double v) {
    final txt = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    return 'R\$ ${txt.replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = item.servico;
    final descricao = s.descricao.trim().isNotEmpty
        ? s.descricao.trim()
        : (s.funcao ?? 'Serviço');
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ImagemServico(
                    imagemUrl: s.imagemUrl,
                    funcao: s.funcao,
                    cor: s.cor,
                    height: 172,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 16,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.nota == null
                                ? 'Novo'
                                : item.nota!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      descricao,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFEDEFF2)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Preço médio',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'A partir de ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                TextSpan(
                                  text: _preco(s.valor),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(color: _azul),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: aoTocar,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDDEFFD),
                        foregroundColor: const Color(0xFF1E6FB8),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Agendar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
