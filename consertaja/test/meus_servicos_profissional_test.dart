import 'package:consertaja/meus_servicos_profissional.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exibe o cabeçalho e os serviços do profissional', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MeusServicosProfissionalPage(),
      ),
    );

    expect(find.text('Meu Serviços Disponiveis'), findsOneWidget);
    expect(find.text('Buscar serviços...'), findsOneWidget);
    expect(find.text('Instalação de Ar Condicionado'), findsOneWidget);
    expect(find.text('Reparo de Fiação Elétrica'), findsOneWidget);
    expect(find.text('Conserto de Vazamentos'), findsOneWidget);
    expect(find.text('Novo Serviço'), findsOneWidget);
  });
}
