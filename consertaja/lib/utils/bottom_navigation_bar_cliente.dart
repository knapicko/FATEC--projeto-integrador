import 'package:flutter/material.dart';

class BottomNavigationBarCliente extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavigationBarCliente({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(
      icon: Icon(Icons.people_outline),
      label: 'Seguindo',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.chat_bubble_outline),
      label: 'Mensagens',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.inventory_2_outlined),
      label: 'Pedidos',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.account_circle_outlined),
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF0FB3FF),
      unselectedItemColor: Colors.grey,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      currentIndex: currentIndex,
      onTap: onTap,
      items: _items,
    );
  }
}
