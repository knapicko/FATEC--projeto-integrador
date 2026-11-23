// =============================================================================
// Plano de Testes ConsertaJá — PT-CJ-01
// Arquivo: CT13 a CT19 — Busca por Profissionais e Filtros Avançados
// Requisitos: RF005 (busca), RF006 (filtros de busca avançados)
// Abordagem: Testes unitários (partição de equivalência e valor-limite)
// =============================================================================
import 'package:consertaja/services/solicitacao_geografica_service.dart';
import 'package:consertaja/utils/cor_oficio.dart';
import 'package:consertaja/utils/texto_busca.dart';
import 'package:consertaja/widgets/filtros_busca.dart';
import 'package:flutter_test/flutter_test.dart';

bool _aceita(
  FiltrosBusca f, {
  String? funcao = 'Eletricista',
  String tipoExecucao = 'Atendimento em Domicílio',
  double preco = 80,
  bool ehLoja = false,
  int idProfissional = 7,
  int? idGrupoEmpresa,
}) => f.aceitaServico(
  funcao: funcao,
  tipoExecucao: tipoExecucao,
  preco: preco,
  ehLoja: ehLoja,
  idProfissional: idProfissional,
  idGrupoEmpresa: idGrupoEmpresa,
  categoriaDaFuncao: (fn) => fn == 'eletricista' ? 'Reparos Domésticos' : null,
);

const _oficios = [
  OficioInfo(funcao: 'Eletricista', categoria: 'Reparos Domésticos'),
  OficioInfo(funcao: 'Encanador', categoria: 'Reparos Domésticos'),
];

void main() {
  group('RF005 — Busca textual', () {
    test('CT13 - Normaliza acentos, maiúsculas e espaços', () {
      expect(normalizarBusca('  Elétrica   RESIDENCIAL '), 'eletrica residencial');
      expect(normalizarBusca('João'), 'joao');
      expect(normalizarBusca('Ação'), 'acao');
    });

    test('CT14 - Encontra termos em qualquer ordem e ignora vazios', () {
      expect(textoContem(['Eletricista', 'Instalação elétrica'], 'eletrica'), isTrue);
      expect(textoContem(['Conserto de panela'], 'panela conserto'), isTrue);
      expect(textoContem(['Sapateiro'], 'chaveiro'), isFalse);
      expect(textoContem(const [], 'chaveiro'), isFalse);
      // termo vazio não filtra nada
      expect(textoContem(['qualquer coisa'], '   '), isTrue);
    });

    test('CT15 - Profissionais próximos lidos do servidor (distância e tag)', () {
      final loja = PerfilProximo.fromMap({
        'tipo': 'empresa',
        'id_grupo_empresa': 3,
        'nome': '   ',
        'tag_empresa': 'caedss',
        'latitude': -23.55,
        'longitude': -46.63,
        'distancia_km': 2.4,
        'nota': 4.7,
      });
      expect(loja.ehEmpresa, isTrue);
      expect(loja.nome, 'Profissional');
      expect(loja.chave, 'e3');
      expect(loja.tagFormatada, '#CAEDSS');
      expect(loja.posicao.latitude, -23.55);
      expect(loja.distanciaKm, 2.4);
      expect(loja.nota, 4.7);

      final autonomo = PerfilProximo.fromMap({
        'tipo': 'profissional',
        'id_profissional': 9,
        'nome': 'Seu Zé',
      });
      expect(autonomo.ehEmpresa, isFalse);
      expect(autonomo.chave, 'p9');
      expect(autonomo.tagFormatada, isNull);
      expect(autonomo.distanciaKm, 0);
    });
  });

  group('RF006 — Filtros avançados', () {
    test('CT16 - Contagem de filtros ativos e cópia imutável', () {
      const vazio = FiltrosBusca();
      expect(vazio.quantidadeAtivos, 0);
      expect(vazio.ativo, isFalse);

      const cheio = FiltrosBusca(
        categoria: 'Reparos Domésticos',
        funcoes: {'Eletricista', 'Encanador'},
        loja: false,
        metodos: {'Leva e Traz'},
        precoMaximo: 100,
        notaMinima: 4,
        ordem: OrdemBusca.menorPreco,
      );
      expect(cheio.quantidadeAtivos, 8);
      expect(cheio.ativo, isTrue);

      expect(cheio.copiar().categoria, 'Reparos Domésticos');
      expect(cheio.copiar(categoria: null).categoria, isNull);
      expect(cheio.copiar(precoMaximo: 50.0).precoMaximo, 50.0);
      expect(cheio.copiar(ordem: OrdemBusca.relevancia).quantidadeAtivos, 7);
      // o original não muda
      expect(cheio.precoMaximo, 100);
    });

    test('CT17 - Serviço passa ou não nos filtros (categoria, preço, tipo, método)', () {
      const base = FiltrosBusca();
      expect(_aceita(base), isTrue);

      // categoria
      const cat = FiltrosBusca(categoria: 'reparos domésticos');
      expect(_aceita(cat), isTrue);
      expect(_aceita(cat, funcao: 'Sapateiro'), isFalse);

      // função
      const fn = FiltrosBusca(funcoes: {'Eletricista'});
      expect(_aceita(fn, funcao: 'eletricista'), isTrue);
      expect(_aceita(fn, funcao: 'Encanador'), isFalse);

      // preço máximo (valor-limite)
      const preco = FiltrosBusca(precoMaximo: 100);
      expect(_aceita(preco, preco: 100), isTrue);
      expect(_aceita(preco, preco: 100.01), isFalse);

      // loja x independente
      expect(_aceita(const FiltrosBusca(loja: false), ehLoja: true), isFalse);
      expect(_aceita(const FiltrosBusca(independente: false)), isFalse);

      // método de realização
      const metodo = FiltrosBusca(metodos: {'Leva e Traz'});
      expect(_aceita(metodo), isFalse);
      expect(_aceita(metodo, tipoExecucao: 'Leva e Traz'), isTrue);

      // profissional específico
      const prof = FiltrosBusca(
        profissional: ProfissionalFiltro(nome: 'Seu Zé', idProfissional: 7),
      );
      expect(_aceita(prof), isTrue);
      expect(_aceita(prof, idProfissional: 8), isFalse);
    });

    test('CT18 - Profissional passa ou não nos filtros (nota mínima e categoria)', () {
      bool aceita(FiltrosBusca f, {double? nota, bool ehLoja = false}) =>
          f.aceitaProfissional(
            oficios: _oficios,
            ehLoja: ehLoja,
            idProfissional: 7,
            idGrupoEmpresa: null,
            nota: nota,
          );

      const nota = FiltrosBusca(notaMinima: 4.5);
      expect(aceita(nota, nota: 4.8), isTrue);
      expect(aceita(nota, nota: 4.5), isTrue);
      expect(aceita(nota, nota: 4.0), isFalse);
      expect(aceita(nota), isFalse); // sem avaliação

      expect(aceita(const FiltrosBusca(categoria: 'Reparos Domésticos')), isTrue);
      expect(aceita(const FiltrosBusca(categoria: 'Segurança')), isFalse);
      expect(aceita(const FiltrosBusca(funcoes: {'encanador'})), isTrue);
      expect(aceita(const FiltrosBusca(independente: false)), isFalse);
    });

    test('CT19 - Rótulos de ordenação dos resultados', () {
      expect(OrdemBusca.relevancia.rotulo, 'Relevância');
      expect(OrdemBusca.menorPreco.rotulo, 'Menor preço');
      expect(OrdemBusca.maiorPreco.rotulo, 'Maior preço');
      expect(OrdemBusca.melhorAvaliados.rotulo, 'Melhor avaliados');
      expect(kMetodosRealizacao, hasLength(4));
    });
  });
}
