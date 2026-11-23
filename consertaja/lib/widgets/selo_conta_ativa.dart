import 'package:flutter/material.dart';

import '../services/conta_profissional_ativa.dart';
import '../utils/iniciais.dart';
import 'imagem_app.dart';

/// Faixa que mostra de qual conta são os dados da tela: profissional
/// independente ou loja.
class SeloContaAtiva extends StatelessWidget {
  const SeloContaAtiva({super.key, required this.conta, this.texto});

  final ContaProfissionalAtiva conta;

  /// Complemento (ex.: "Serviços da loja").
  final String? texto;

  @override
  Widget build(BuildContext context) {
    final loja = conta.empresa;
    final cor = loja ? const Color(0xFF7C3AED) : const Color(0xFF0FB3FF);
    final foto = conta.fotoExibicao;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CorOriginal(child: CircleAvatar(
            radius: 17,
            backgroundColor: cor,
            backgroundImage: foto != null ? NetworkImage(foto) : null,
            child: foto == null
                ? Text(
                    obterIniciais(conta.nomeExibicao),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          )),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conta.nomeExibicao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (texto != null)
                  Text(
                    texto!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  loja ? Icons.storefront_rounded : Icons.person_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  conta.rotulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
