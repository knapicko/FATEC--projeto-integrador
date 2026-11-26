import 'package:flutter/material.dart';

import '../utils/fluxo_solicitacao.dart';

/// Lê `solicitacoes.prazo_entrega` (v0_19) já no horário local.
DateTime? lerPrazoEntrega(Map<String, dynamic>? solicitacao) {
  final bruto = solicitacao?['prazo_entrega']?.toString();
  if (bruto == null || bruto.isEmpty) return null;
  return DateTime.tryParse(bruto)?.toLocal();
}

String formatarPrazo(DateTime d) {
  const meses = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];
  return '${d.day.toString().padLeft(2, '0')} de ${meses[d.month - 1]} '
      'de ${d.year}';
}

/// Aviso do prazo de entrega do serviço, com a regra explicada para quem
/// está vendo (cliente ou profissional):
///
/// - antes do prazo: até quando o serviço precisa ficar pronto e o que
///   acontece se passar;
/// - cancelado por prazo: o produto volta ao cliente (o profissional
///   devolve ou o cliente busca, conforme a modalidade) e o valor é
///   estornado ao cliente.
class AvisoPrazoEntrega extends StatelessWidget {
  const AvisoPrazoEntrega({
    super.key,
    required this.prazo,
    required this.canceladoPorPrazo,
    required this.souCliente,
    required this.tipoExecucao,
    this.estornado = false,
  });

  final DateTime? prazo;
  final bool canceladoPorPrazo;
  final bool souCliente;
  final String? tipoExecucao;
  final bool estornado;

  @override
  Widget build(BuildContext context) {
    if (prazo == null && !canceladoPorPrazo) return const SizedBox.shrink();
    final modalidade = ModalidadeExecucao.fromString(tipoExecucao);
    final clienteBusca = modalidade.clienteRetiraNoLocal;
    final data = prazo == null ? '' : formatarPrazo(prazo!);

    final String titulo;
    final String texto;
    final Color cor;
    final IconData icone;
    if (canceladoPorPrazo) {
      cor = const Color(0xFFDC2626);
      icone = Icons.event_busy_rounded;
      titulo = 'Cancelado: prazo de entrega vencido';
      final devolucao = souCliente
          ? (clienteBusca
                ? 'Busque o seu produto no estabelecimento do profissional.'
                : 'O profissional vai devolver o seu produto.')
          : (clienteBusca
                ? 'O cliente vai buscar o produto no seu estabelecimento.'
                : 'Devolva o produto ao cliente.');
      final valor = souCliente
          ? (estornado
                ? 'O valor já foi estornado para você.'
                : 'O valor será estornado para você quando o produto for '
                      'devolvido.')
          : 'O valor do serviço volta para o cliente.';
      texto = 'O serviço não ficou pronto até $data. $devolucao $valor';
    } else {
      final vencido = prazo!.isBefore(DateTime.now());
      cor = vencido ? const Color(0xFFDC2626) : const Color(0xFFF59E0B);
      icone = Icons.event_available_rounded;
      titulo = 'Prazo de entrega: $data';
      final consequencia = clienteBusca
          ? (souCliente
                ? 'você busca o produto no estabelecimento'
                : 'o cliente busca o produto no seu estabelecimento')
          : (souCliente
                ? 'o profissional devolve o produto'
                : 'você precisa devolver o produto ao cliente');
      texto = souCliente
          ? 'Se o serviço não ficar pronto até essa data, ele é cancelado, '
                '$consequencia e você recebe o valor de volta. O valor só é '
                'liberado ao profissional depois que o serviço for concluído.'
          : 'Se o serviço não ficar pronto até essa data, ele é cancelado, '
                '$consequencia e o valor volta para o cliente. O pagamento é '
                'liberado para você só depois da conclusão.';
    }

    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: HSLColor.fromColor(cor)
                          .withLightness(0.32)
                          .toColor(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
