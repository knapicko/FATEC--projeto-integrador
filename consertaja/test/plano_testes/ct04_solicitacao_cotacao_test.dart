// =============================================================================
// Plano de Testes ConsertaJá — PT-CJ-01
// Arquivo: CT20 a CT26 — Solicitação de Serviço e Cotação (propostas)
// Requisitos: RF008 (solicitação), RF009 (cotação), RF016 (método escolhido)
// Abordagem: Testes unitários (leitura dos dados vindos do Supabase)
// =============================================================================
import 'package:consertaja/models/servico_catalogo.dart';
import 'package:consertaja/models/servico_profissional.dart';
import 'package:consertaja/services/solicitacao_geografica_service.dart';
import 'package:consertaja/utils/fluxo_solicitacao.dart';
import 'package:consertaja/utils/funcao_servico.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RF008 — Abertura da solicitação', () {
    test('CT20 - Métodos de realização oferecidos ao cliente', () {
      expect(MetodoEntregaGeo.todos, hasLength(4));
      expect(MetodoEntregaGeo.todos.first.valor, 'Atendimento em Domicílio');
      expect(MetodoEntregaGeo.porValor('Leva e Traz')?.valor, 'Leva e Traz');
      expect(MetodoEntregaGeo.porValor('Entrega por drone'), isNull);
      expect(MetodoEntregaGeo.porValor(null), isNull);
      // todo valor oferecido já é o texto canônico aceito pelo banco
      for (final m in MetodoEntregaGeo.todos) {
        expect(normalizarTipoExecucao(m.valor), m.valor);
      }
    });

    test('CT21 - Normaliza o tipo de execução antes de gravar', () {
      expect(normalizarTipoExecucao('  retirada no local '), 'Retirado no Local');
      expect(normalizarTipoExecucao('RECEBA EM CASA'), 'Receba em Casa');
      expect(normalizarTipoExecucao('Presencial'), 'Atendimento em Domicílio');
      expect(normalizarTipoExecucao('leva e traz'), 'Leva e Traz');
      // valor desconhecido/nulo cai no padrão do banco
      expect(normalizarTipoExecucao(null), 'Leva e Traz');
    });

    test('CT22 - Solicitação geográfica recebida no Radar do profissional', () {
      final s = SolicitacaoGeoProxima.fromMap({
        'id_solicitacao_geografica': 10,
        'titulo': 'Panela de pressão vazando',
        'descricao': 'A borracha não veda mais',
        'img_solicitacao': ['a.jpg', '', 'b.jpg'],
        'funcao': 'Paneleiro',
        'latitude': -23.5,
        'longitude': -46.6,
        'distancia_km': 1.2,
        'nome_cliente': null,
        'data_criacao': '2026-11-18T10:00:00Z',
        'metodo_entrega': 'Leva e Traz',
      });
      expect(s.id, 10);
      expect(s.imagens, ['a.jpg', 'b.jpg']);
      expect(s.idStatus, StatusSolicitacaoGeo.solicitada);
      expect(s.nova, isTrue);
      expect(s.nomeCliente, 'Cliente');
      expect(s.dataCriacao, isNotNull);
      expect(s.metodoEntrega, 'Leva e Traz');

      final vista = SolicitacaoGeoProxima.fromMap({
        'id_solicitacao_geografica': 11,
        'fk_status': StatusSolicitacaoGeo.visualizada,
        'img_solicitacao': 'nao-e-lista',
      });
      expect(vista.nova, isFalse);
      expect(vista.imagens, isEmpty);
    });

    test('CT23 - Serviço do profissional lido e preparado para gravação', () {
      final s = ServicoProfissional.fromMap({
        'id_servico_prof': 5,
        'titulo': 'Afiação',
        'descricao': 'Afiar facas e tesouras',
        'valor': 35,
        'fk_funcao': 12,
        'funcoes': {'funcao': 'Afiador', 'fk_oficio': 2, 'cor': '#FF0000'},
        'ativo': true,
        'fk_profissional': 7,
        'data_criacao': '2026-10-01T12:00:00',
      });
      expect(s.valor, 35.0);
      expect(s.fkOficio, 2); // veio do join com `funcoes`
      expect(s.funcao, 'Afiador');
      expect(s.cor, '#FF0000');
      expect(s.tipoExecucao, 'Execução');
      expect(s.cargaServico, 'Médio');
      expect(s.dataCriacao, DateTime(2026, 10, 1, 12));

      final insert = s.toInsertMap();
      expect(insert['fk_oficios'], 2);
      expect(insert['fk_funcao'], 12);
      expect(insert['fk_grupo_empresa'], isNull);
      expect(insert.containsKey('id_servico_prof'), isFalse);

      // join pode vir como lista
      expect(
        nomeFuncao({
          'funcoes': [
            {'funcao': 'Chaveiro'},
          ],
        }),
        'Chaveiro',
      );
      expect(nomeFuncao({'funcoes': {'funcao': '  '}}), isNull);
      expect(extrairFuncao(null), isNull);
    });

    test('CT24 - Item do catálogo de serviços', () {
      final c = ServicoCatalogo.fromMap({
        'id_catalogo': 1,
        'titulo': 'Troca de cabo',
        'descricao': 'Cabo de panela',
        'fk_oficio': 3,
        'ativo': true,
        'funcoes': {'funcao': 'Paneleiro', 'cod_cor': '8b4513'},
      });
      expect(c.id, 1);
      expect(c.funcao, 'Paneleiro');
      expect(c.cor, '8b4513');
      expect(c.ativo, isTrue);
      expect(c.imagemUrl, isNull);
    });
  });

  group('RF009 — Cotação (proposta de preço)', () {
    test('CT25 - Cliente acompanha a proposta enviada pelo profissional', () {
      final p = AcompanhamentoGeo.fromMap({
        'id_proposta': 1,
        'valor_final': 120.5,
        'eh_empresa': true,
        'tag_empresa': 'loja',
        'nome': 'Loja do Afiador',
        'latitude': -23.0,
        'longitude': -46.0,
        'total_avaliacoes': 3,
      });
      expect(p.propostaPendente, isTrue);
      expect(p.valor, 120.5);
      expect(p.tagFormatada, '#LOJA');
      expect(p.posicao, isNotNull);
      expect(p.idSolicitacao, isNull); // ainda não aceita

      final autonomo = AcompanhamentoGeo.fromMap({
        'id_proposta': 2,
        'status_proposta': StatusPropostaGeo.aceita,
        'id_solicitacao': 99,
        'tag_empresa': 'xyz',
      });
      expect(autonomo.propostaPendente, isFalse);
      expect(autonomo.tagFormatada, isNull); // só empresa tem tag
      expect(autonomo.posicao, isNull);
      expect(autonomo.nome, 'Profissional');
      expect(autonomo.valor, 0);
    });

    test('CT26 - Profissional vê o resultado da proposta (aceita/recusada)', () {
      Map<String, dynamic> base(int status, {Object? finalV, Object? prop}) => {
        'id_proposta': 1,
        'id_solicitacao_geografica': 10,
        'status_proposta': status,
        'valor_final': finalV,
        'valor_proposta': prop,
      };

      final aceita = SolicitacaoGeoAceita.fromMap(
        base(StatusPropostaGeo.aceita, finalV: 100, prop: 90),
      );
      expect(aceita.aceita, isTrue);
      expect(aceita.valor, 100); // valor final prevalece

      final pendente = SolicitacaoGeoAceita.fromMap(
        base(StatusPropostaGeo.pendente, prop: 90),
      );
      expect(pendente.pendente, isTrue);
      expect(pendente.valor, 90); // sem valor final, usa o proposto

      final recusada = SolicitacaoGeoAceita.fromMap(
        base(StatusPropostaGeo.recusada),
      );
      expect(recusada.recusada, isTrue);
      expect(recusada.nomeCliente, 'Cliente');
    });
  });
}
