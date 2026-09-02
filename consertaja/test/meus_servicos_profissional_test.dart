import 'package:consertaja/meus_servicos_profissional.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exibe a tela de meus serviços', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MeusServicosProfissionalPage()),
    );

    expect(find.text('Meus Serviços'), findsOneWidget);
  });
}
