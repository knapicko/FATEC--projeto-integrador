import 'package:flutter/material.dart';

import '../widgets/barra_lista_servicos.dart';

class BottomNavigationBarCliente extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Chamado quando o usuário toca na aba em que já está
  /// (ex: tocar em "Home" estando na Home). As telas usam para
  /// recarregar os dados em vez de ignorar o toque.
  /// Se null, o toque na aba atual apenas re-executa [onTap].
  final ValueChanged<int>? onReselecionarAbaAtual;

  const BottomNavigationBarCliente({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onReselecionarAbaAtual,
  });

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.star_outline), label: 'Seguindo'),
    BottomNavigationBarItem(
      icon: Icon(Icons.message_outlined),
      label: 'Mensagens',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.receipt_long_outlined),
      label: 'Pedidos',
    ),
    BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BarraListaServicosWidget(),
        BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0FB3FF),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          currentIndex: currentIndex,
          // Tocar na aba atual recarrega a página em vez de ser ignorado.
          onTap: (index) {
            if (index == currentIndex) {
              if (onReselecionarAbaAtual != null) {
                onReselecionarAbaAtual!(index);
              } else {
                onTap(index);
              }
              return;
            }
            onTap(index);
          },
          items: _items,
        ),
      ],
    );
  }
}
