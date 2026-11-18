import 'package:flutter/material.dart';

import 'services/avaliacoes_pendentes.dart';
import 'services/pedidos_cliente_service.dart';
import 'utils/abrir_solicitacao.dart';
import 'widgets/card_pedido_resumo.dart';
import 'widgets/skeleton_loading.dart';

/// Histórico de todos os pedidos do cliente. Concluído e ainda sem avaliação
/// fica marcado com "!" e o toque abre a avaliação.
class HistoricoPedidosClientePage extends StatefulWidget {
  const HistoricoPedidosClientePage({super.key});

  @override
  State<HistoricoPedidosClientePage> createState() =>
      _HistoricoPedidosClientePageState();
}

class _HistoricoPedidosClientePageState
    extends State<HistoricoPedidosClientePage> {
  List<PedidoResumo>? _pedidos;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final l = await PedidosClienteService.listar();
      if (mounted)
        setState(() {
          _pedidos = l;
          _erro = null;
        });
    } catch (e) {
      debugPrint('[histórico] $e');
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar seus pedidos.');
      }
    }
  }

  Future<void> _tocar(PedidoResumo p) async {
    if (p.precisaAvaliar) {
      final ok = await AvaliacoesPendentes.avaliar(context, p.id);
      if (ok) _carregar();
      return;
    }
    await abrirSolicitacaoPorStatus(context, p.id, comoProfissional: false);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final l = _pedidos;
    final pendentes = l?.where((p) => p.precisaAvaliar).length ?? 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: appBarPerfil('Histórico de Pedidos'),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _erro != null
            ? listaVaziaPerfil(Icons.wifi_off_rounded, 'Ops!', _erro!)
            : l == null
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (var i = 0; i < 5; i++)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SkeletonBox(height: 96, borderRadius: 18),
                    ),
                ],
              )
            : l.isEmpty
            ? listaVaziaPerfil(
                Icons.inventory_2_outlined,
                'Nenhum pedido ainda',
                'Quando você pedir um serviço, ele aparece aqui.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (pendentes > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Text(
                        pendentes == 1
                            ? 'Você tem 1 serviço concluído para avaliar.'
                            : 'Você tem $pendentes serviços concluídos para avaliar.',
                        style: const TextStyle(
                          color: Color(0xFF9A3412),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    '${l.length} ${l.length == 1 ? 'pedido' : 'pedidos'}',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final p in l)
                    CardPedidoResumo(pedido: p, aoTocar: () => _tocar(p)),
                ],
              ),
      ),
    );
  }
}
