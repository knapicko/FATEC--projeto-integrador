import 'package:flutter/material.dart';

/// Amarelo de "importante": dados obrigatórios que ainda faltam.
const Color corObrigatorio = Color(0xFFF59E0B);
const Color _fundoObrigatorio = Color(0xFFFFFBEB);
const Color _textoObrigatorio = Color(0xFF92400E);

/// Borda amarela para destacar um campo/cartão obrigatório não preenchido.
BoxBorder? bordaObrigatoria(bool pendente, {double largura = 1.6}) =>
    pendente ? Border.all(color: corObrigatorio, width: largura) : null;

/// Selo amarelo com "!" (mesmo da home).
class SeloObrigatorio extends StatelessWidget {
  const SeloObrigatorio({super.key, this.tamanho = 20});

  final double tamanho;

  @override
  Widget build(BuildContext context) => Container(
    width: tamanho,
    height: tamanho,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: corObrigatorio,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Text(
      '!',
      style: TextStyle(
        color: Colors.white,
        fontSize: tamanho * 0.55,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    ),
  );
}

/// Faixa amarela com ícone de alerta explicando o que falta preencher.
class AvisoObrigatorio extends StatelessWidget {
  const AvisoObrigatorio({
    super.key,
    required this.titulo,
    required this.texto,
    this.margem = const EdgeInsets.fromLTRB(16, 12, 16, 4),
  });

  final String titulo;
  final String texto;
  final EdgeInsets margem;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margem,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _fundoObrigatorio,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: corObrigatorio, width: 1.6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SeloObrigatorio(tamanho: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: _textoObrigatorio,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  texto,
                  style: const TextStyle(
                    color: _textoObrigatorio,
                    fontSize: 12.5,
                    height: 1.35,
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
