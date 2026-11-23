// =============================================================================
// Plano de Testes ConsertaJá — PT-CJ-01
// Arquivo: CT27 a CT33 — Atualização de Status, Opção de Entrega e Rastreamento
// Requisitos: RF014 (status), RF016 (opção de entrega), RF017 (rastreamento)
// Abordagem: Testes unitários (tabela de decisão / transição de estados)
// =============================================================================
import 'package:consertaja/models/metodo_entrega.dart';
import 'package:consertaja/services/solicitacao_geografica_service.dart';
import 'package:consertaja/utils/fluxo_solicitacao.dart';
import 'package:flutter_test/flutter_test.dart';

const _leva = 'Leva e Traz';
const _domicilio = 'Atendimento em Domicílio';
const _retirada = 'Retirado no Local';
const _receba = 'Receba em Casa';

FluxoSolicitacao f(String tipo, int? status, int etapa, [String? texto]) =>
    FluxoSolicitacao(
      tipoExecucao: tipo,
      fkStatus: status,
      etapa: etapa,
      statusTexto: texto,
    );

void main() {
  group('RF016 — Opções de entrega', () {
    test('CT27 - As 4 opções de entrega batem com o texto gravado no banco', () {
      expect(metodosEntregaOpcoes, hasLength(4));
      for (final o in metodosEntregaOpcoes) {
        expect(ModalidadeExecucao.fromString(o.valor).valorBanco, o.valor);
      }
      final valores = metodosEntregaOpcoes.map((o) => o.valor).toSet();
      expect(valores, hasLength(4)); // sem duplicidade
    });

    test('CT28 - Regras de cada modalidade (quem leva, quem busca, etapas)', () {
      const leva = ModalidadeExecucao.levaETraz;
      expect(leva.profissionalBuscaNoCliente, isTrue);
      expect(leva.profissionalDevolveNoCliente, isTrue);
      expect(leva.clienteLevaProduto, isFalse);

      const retirada = ModalidadeExecucao.retiradaNoLocal;
      expect(retirada.clienteLevaProduto, isTrue);
      expect(retirada.clienteRetiraNoLocal, isTrue);
      expect(retirada.profissionalDevolveNoCliente, isFalse);

      const receba = ModalidadeExecucao.recebaEmCasa;
      expect(receba.clienteLevaProduto, isTrue);
      expect(receba.profissionalDevolveNoCliente, isTrue);

      const domicilio = ModalidadeExecucao.atendimentoDomicilio;
      expect(domicilio.ehDomicilio, isTrue);
      expect(domicilio.etapaFinal, 4);
      expect(domicilio.titulosEtapas, hasLength(4));

      for (final m in [leva, retirada, receba]) {
        expect(m.etapaFinal, 5);
        expect(m.titulosEtapas, hasLength(5));
      }
      for (final m in ModalidadeExecucao.values) {
        expect(m.titulosEtapas.first, 'Aceito');
        expect(m.titulosEtapas.last, 'Concluído');
        expect(m.titulosEtapas, hasLength(m.etapaFinal));
      }
    });
  });

  group('RF014 — Atualização de status', () {
    test('CT29 - Etapa exibida fica coerente com o status gravado', () {
      expect(f(_leva, 1, 3).etapaEfetiva, 0); // aberto
      expect(f(_leva, 3, 0).etapaEfetiva, 1); // pago
      expect(f(_leva, 33, 0).etapaEfetiva, 2); // profissional a caminho
      expect(f(_leva, 34, 2).etapaEfetiva, 2); // chegou para buscar
      expect(f(_leva, 4, 1).etapaEfetiva, 3); // em andamento
      expect(f(_leva, 35, 4).etapaEfetiva, 4); // aguardando devolução
      expect(f(_leva, 6, 2).etapaEfetiva, 5); // concluído
      expect(f(_domicilio, 34, 2).etapaEfetiva, 3); // no local
      expect(f(_domicilio, 6, 3).etapaEfetiva, 4); // concluído
      expect(f(_retirada, 35, 2).etapaEfetiva, 4); // aguardando retirada
      expect(f(_receba, 38, 1).etapaEfetiva, 2); // cliente levando
    });

    test('CT30 - Status pelo texto quando o id não vem (registros antigos)', () {
      final concluido = f(_leva, null, 0, 'Concluído');
      expect(concluido.estaConcluido, isTrue);
      expect(concluido.etapaEfetiva, 5);

      expect(f(_leva, null, 0, 'Pendente').estaAberto, isTrue);
      expect(f(_leva, null, 0, 'Em andamento').emAndamento, isTrue);
    });

    test('CT31 - Ações permitidas conforme modalidade e pagamento', () {
      expect(f(_leva, 3, 1).profissionalPodeIniciarBusca, isTrue);
      expect(f(_leva, 3, 1).clientePodeIniciarDeslocamento, isFalse);
      expect(f(_leva, 2, 1).profissionalPodeIniciarBusca, isFalse); // sem pagar

      expect(f(_receba, 3, 1).clientePodeIniciarDeslocamento, isTrue);
      expect(f(_receba, 3, 1).profissionalPodeIniciarBusca, isFalse);
      expect(f(_receba, 3, 1).profissionalAguardaCliente, isTrue);
      expect(f(_receba, 38, 2).profissionalAguardaCliente, isTrue);

      expect(f(_domicilio, 3, 1).profissionalPodeIniciarBusca, isTrue);
    });
  });

  group('RF017 — Rastreamento do pedido', () {
    test('CT32 - Tela de acompanhamento aberta para cliente e profissional', () {
      // Retirado no Local
      expect(f(_retirada, 38, 2).destinoCliente, DestinoCliente.deslocamentoCliente);
      expect(f(_retirada, 35, 4).destinoCliente, DestinoCliente.confirmarRetirada);
      expect(f(_retirada, 35, 4).destinoProfissional, DestinoProfissional.estado);

      // Receba em Casa — devolução
      expect(f(_receba, 36, 4).destinoCliente, DestinoCliente.acompanharDeslocamento);
      expect(f(_receba, 36, 4).destinoProfissional, DestinoProfissional.deslocamento);
      expect(f(_receba, 37, 4).destinoProfissional, DestinoProfissional.devolucaoNoLocal);

      // Registro legado: 34 na etapa de devolução = devolução chegou
      final legado = f(_leva, 34, 4);
      expect(legado.profissionalChegou, isFalse);
      expect(legado.devolucaoChegou, isTrue);
      expect(legado.destinoProfissional, DestinoProfissional.devolucaoNoLocal);

      // Domicílio a caminho
      expect(f(_domicilio, 33, 2).destinoCliente, DestinoCliente.acompanharDeslocamento);
      expect(f(_domicilio, 33, 2).destinoProfissional, DestinoProfissional.deslocamento);

      // Em andamento e concluído
      expect(f(_leva, 4, 3).destinoProfissional, DestinoProfissional.emAndamento);
      expect(f(_leva, 6, 5).destinoCliente, DestinoCliente.detalhes);
      expect(f(_leva, 6, 5).destinoProfissional, DestinoProfissional.estado);
    });

    test('CT33 - Rótulos de status por modalidade e liberação do acompanhamento', () {
      expect(f(_retirada, 38, 2).rotuloPorModalidade, 'Cliente levando o produto');
      expect(f(_receba, 38, 2).rotuloPorModalidade, 'Cliente Deslocando');
      expect(
        f(_retirada, 35, 4).rotuloPorModalidade,
        'Aguardando retirada pelo cliente',
      );
      expect(f(_receba, 37, 4).rotuloPorModalidade, 'Devolução Chegou');
      expect(f(_leva, 1, 0).rotuloPorModalidade, 'Aberto');
      expect(f(_leva, 4, 3).rotuloPorModalidade, isNull);

      // acompanhamento em tempo real só depois do pagamento
      expect(StatusSolicitacaoVinculada.podeAcompanhar(null), isFalse);
      expect(StatusSolicitacaoVinculada.podeAcompanhar(1), isFalse);
      expect(StatusSolicitacaoVinculada.podeAcompanhar(2), isFalse);
      expect(StatusSolicitacaoVinculada.podeAcompanhar(3), isTrue);
      expect(StatusSolicitacaoVinculada.podeAcompanhar(4), isTrue);
    });
  });
}
