import 'package:flutter/material.dart';

import '../lista_servicos.dart';
import '../services/lista_servicos_service.dart';

class BarraListaServicosWidget extends StatefulWidget {
  const BarraListaServicosWidget({super.key});

  @override
  State<BarraListaServicosWidget> createState() => _BarraListaServicosWidgetState();
}

class _BarraListaServicosWidgetState extends State<BarraListaServicosWidget> {
  static const Color _azul = Color(0xFF0FB3FF);

  @override
  void initState() {
    super.initState();
    // Dispara atualização ao inicializar o widget
    ListaServicosService.instance.atualizar();
  }

  String _formatarPreco(double valor) {
    return 'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ListaServicosService.instance,
      builder: (context, _) {
        final service = ListaServicosService.instance;
        final quantidade = service.quantidade;
        final valorTotal = service.valorTotal;

        if (quantidade <= 0) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ListaServicos(),
                ),
              ).then((_) {
                // Ao retornar da tela de lista de serviços, atualiza os dados
                ListaServicosService.instance.atualizar();
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: _azul,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Ícone de Carrinho de Compras Branco
                  const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 30,
                  ),
                  const SizedBox(width: 14),

                  // Coluna QUANTIDADE
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'QUANTIDADE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$quantidade',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            quantidade == 1 ? ' Serviço' : ' Serviços',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Coluna VALOR TOTAL
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'VALOR TOTAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _formatarPreco(valorTotal),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
