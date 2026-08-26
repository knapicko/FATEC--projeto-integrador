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
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.people_alt_outlined),
      label: 'Seguindo',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.message_outlined),
      label: 'Mensagens',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.assignment_outlined),
      label: 'Pedidos',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
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
