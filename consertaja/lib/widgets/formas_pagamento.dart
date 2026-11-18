import 'package:flutter/material.dart';

/// Nome bonito de uma forma de pagamento salva pelo profissional
/// (`pagamento_aceito`).
String rotuloPagamento(String bruto) {
  final t = bruto.trim().toLowerCase();
  if (t.contains('pix')) return 'Pix';
  if (t.contains('credito') || t.contains('crédito')) {
    return 'Cartão de crédito';
  }
  if (t.contains('debito') || t.contains('débito')) return 'Cartão de débito';
  if (t.contains('cart')) return 'Cartão';
  if (t.contains('boleto')) return 'Boleto';
  if (t.contains('dinheiro')) return 'Dinheiro';
  final b = bruto.trim();
  return b.isEmpty ? b : b[0].toUpperCase() + b.substring(1);
}

/// Ícone de cada forma de pagamento.
IconData iconePagamento(String rotulo) {
  final t = rotulo.toLowerCase();
  if (t.contains('pix')) return Icons.pix_rounded;
  if (t.contains('cart')) return Icons.credit_card_rounded;
  if (t.contains('boleto')) return Icons.receipt_long_rounded;
  if (t.contains('dinheiro')) return Icons.payments_rounded;
  return Icons.account_balance_wallet_outlined;
}

/// Converte o valor do banco (lista ou "a, b") em rótulos únicos.
List<String> formasDePagamento(Object? valor) {
  final brutos = valor is List
      ? valor.map((e) => e.toString())
      : (valor?.toString() ?? '').split(',');
  return brutos
      .map(rotuloPagamento)
      .where((p) => p.isNotEmpty)
      .toSet()
      .toList();
}

/// Chips com ícone + nome das formas de pagamento aceitas.
class ChipsPagamento extends StatelessWidget {
  const ChipsPagamento({super.key, required this.formas, this.compacto = false});

  final List<String> formas;

  /// Só os ícones (com dica ao segurar).
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    if (formas.isEmpty) {
      return const Text(
        'A combinar',
        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final f in formas)
          compacto
              ? Tooltip(
                  message: f,
                  child: Icon(
                    iconePagamento(f),
                    size: 18,
                    color: f == 'Pix'
                        ? const Color(0xFF32BCAD)
                        : const Color(0xFF475569),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      width: 0.9,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconePagamento(f),
                        size: 14,
                        color: f == 'Pix'
                            ? const Color(0xFF32BCAD)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        f,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
      ],
    );
  }
}
