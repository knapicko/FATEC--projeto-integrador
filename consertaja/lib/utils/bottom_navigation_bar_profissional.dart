import 'package:flutter/material.dart';

class BottomNavigationBarProfissional extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavigationBarProfissional({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    BottomNavigationBarItem(icon: Icon(Icons.sensors), label: 'Radar'),
    BottomNavigationBarItem(
      icon: Icon(Icons.chat_bubble_outline),
      label: 'Mensagens',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.archive_outlined),
      label: 'Pedidos',
    ),
    BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF0FB3FF),
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      currentIndex: currentIndex,
      onTap: onTap,
      items: _items,
    );
  }
}
