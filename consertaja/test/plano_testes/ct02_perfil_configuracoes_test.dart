// =============================================================================
// Plano de Testes ConsertaJá — PT-CJ-01
// Arquivo: CT09 a CT12 — Gerenciamento de Perfil e Configurações
// Requisitos: RF003 (perfil), RNF001/RNF007 (usabilidade e acessibilidade)
// Abordagem: Testes unitários
// =============================================================================
import 'package:consertaja/models/servico_profissional.dart';
import 'package:consertaja/services/app_settings_controller.dart';
import 'package:consertaja/services/postagens_profissional_service.dart';
import 'package:consertaja/utils/iniciais.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ServicoProfissional _servico() => ServicoProfissional(
  id: 1,
  titulo: 'Afiação de facas',
  descricao: 'Afiação profissional',
  valor: 30,
  fkOficio: 1,
  ativo: true,
  fkProfissional: 7,
  dataCriacao: DateTime(2026, 1, 1),
);

DetalheServicoPublico _detalhe({String tipo = 'cpf', bool ehLoja = false}) =>
    DetalheServicoPublico(
      servico: _servico(),
      nomePrestador: 'Prestador',
      ehLoja: ehLoja,
      tipoPrestador: tipo,
      idProfissional: 7,
      seguidores: 0,
      enderecoFormatado: 'Rua A, 10',
      latitude: 0,
      longitude: 0,
      temCoordenadas: false,
    );

void main() {
  group('RF003 — Exibição do perfil', () {
    test('CT09 - Iniciais do avatar a partir do nome do usuário', () {
      expect(obterIniciais('Luiz Knapick'), 'LK');
      expect(obterIniciais('gabriel'), 'GA');
      expect(obterIniciais('maria  da silva'), 'MD');
      expect(obterIniciais('A'), 'AA');
      expect(obterIniciais('   '), 'N');
      expect(obterIniciais('Nome não encontrado'), 'N');
    });

    test('CT10 - Rótulo do tipo de prestador (Loja, CNPJ ou CPF)', () {
      expect(_detalhe(tipo: 'empresa').rotuloTipoPrestador, 'Loja / Empresa');
      expect(_detalhe(ehLoja: true).rotuloTipoPrestador, 'Loja / Empresa');
      expect(
        _detalhe(tipo: 'independente').rotuloTipoPrestador,
        'Independente (CNPJ)',
      );
      expect(_detalhe().rotuloTipoPrestador, 'Autônomo (CPF)');
      expect(_detalhe().ehCpf, isTrue);
    });

    test('CT11 - Data das postagens do portfólio do profissional', () {
      expect(
        PostagensProfissionalService.formatarDataPostagem(DateTime(2026, 11, 18)),
        '18 Nov 2026',
      );
      expect(
        PostagensProfissionalService.formatarDataPostagem(DateTime(2026, 1, 5)),
        '5 Jan 2026',
      );
    });
  });

  group('RF003/RNF007 — Configurações de aparência e acessibilidade', () {
    final c = AppSettingsController.instance;

    setUp(() async {
      for (final e in AppSettingsController.padroes().entries) {
        await c.atualizar(e.key, e.value as Object, salvar: false);
      }
    });

    test('CT12 - Tema, tamanho de fonte e filtros são aplicados', () async {
      // Padrão: tema claro, sem filtros
      expect(c.temaEscolhido, 'Claro');
      expect(c.escuroAtivo(Brightness.dark), isFalse);
      expect(c.escalaFonte, 1.0);
      expect(c.matrizFiltro(Brightness.light), isNull);

      // Tema escuro
      await c.atualizar('appearance.theme', 'Escuro', salvar: false);
      expect(c.escuroAtivo(Brightness.light), isTrue);

      // Tema "Sistema" segue o brilho da plataforma
      await c.atualizar('appearance.theme', 'Sistema', salvar: false);
      expect(c.escuroAtivo(Brightness.dark), isTrue);
      expect(c.escuroAtivo(Brightness.light), isFalse);

      // Fonte: índice fora da faixa é limitado ao máximo
      await c.atualizar('accessibility.fontSize', 10, salvar: false);
      expect(c.escalaFonte, 1.3);

      // Alto contraste gera uma matriz de cor 4x5
      await c.atualizar('accessibility.highContrast', true, salvar: false);
      expect(c.altoContraste, isTrue);
      expect(c.matrizFiltro(Brightness.light), hasLength(20));

      // Filtro para daltônicos
      await c.atualizar('accessibility.highContrast', false, salvar: false);
      await c.atualizar('accessibility.colorFilter', 'Protanopia', salvar: false);
      expect(c.matrizFiltro(Brightness.light), hasLength(20));
    });
  });
}
