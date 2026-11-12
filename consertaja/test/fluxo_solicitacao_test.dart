import 'package:consertaja/utils/fluxo_solicitacao.dart';
import 'package:flutter_test/flutter_test.dart';

FluxoSolicitacao f(String tipo, int status, int etapa, [String? texto]) =>
    FluxoSolicitacao(
      tipoExecucao: tipo,
      fkStatus: status,
      etapa: etapa,
      statusTexto: texto,
    );

void main() {
  group('ModalidadeExecucao.fromString', () {
    test('reconhece os valores salvos no banco', () {
      expect(
        ModalidadeExecucao.fromString('Leva e Traz'),
        ModalidadeExecucao.levaETraz,
      );
      expect(
        ModalidadeExecucao.fromString('Retirado no Local'),
        ModalidadeExecucao.retiradaNoLocal,
      );
      expect(
        ModalidadeExecucao.fromString('Receba em Casa'),
        ModalidadeExecucao.recebaEmCasa,
      );
      expect(
        ModalidadeExecucao.fromString('Atendimento em Domicílio'),
        ModalidadeExecucao.atendimentoDomicilio,
      );
    });
  });

  group('Leva e Traz', () {
    const t = 'Leva e Traz';
    test('cliente acompanha busca e devolução', () {
      expect(f(t, 33, 2).destinoCliente, DestinoCliente.acompanharDeslocamento);
      expect(f(t, 34, 2).destinoCliente, DestinoCliente.acompanharDeslocamento);
      expect(f(t, 4, 3).destinoCliente, DestinoCliente.detalhes);
      expect(f(t, 37, 4).destinoCliente, DestinoCliente.acompanharDeslocamento);
    });
    test('profissional: chegada abre recebimento; 35 abre deslocamento', () {
      expect(f(t, 34, 2).destinoProfissional, DestinoProfissional.recebimento);
      expect(f(t, 35, 4).destinoProfissional, DestinoProfissional.deslocamento);
      expect(
        f(t, 37, 4).destinoProfissional,
        DestinoProfissional.devolucaoNoLocal,
      );
    });
  });

  group('Atendimento em Domicílio', () {
    const t = 'Atendimento em Domicílio';
    test('status 34 / etapa 3 abre o atendimento no local (cliente e prof.)', () {
      expect(f(t, 34, 3).destinoCliente, DestinoCliente.atendimentoNoLocal);
      expect(
        f(t, 34, 3).destinoProfissional,
        DestinoProfissional.atendimentoNoLocal,
      );
      expect(f(t, 34, 3).rotuloPorModalidade, 'Atendimento no local');
    });
  });

  group('Retirado no Local', () {
    const t = 'Retirado no Local';
    test('profissional nunca inicia deslocamento', () {
      expect(f(t, 3, 1, 'Pago').profissionalPodeIniciarBusca, isFalse);
      expect(f(t, 3, 1, 'Pago').clientePodeIniciarDeslocamento, isTrue);
    });
    test('38 abre o trajeto do cliente', () {
      expect(f(t, 38, 2).destinoCliente, DestinoCliente.deslocamentoCliente);
      expect(f(t, 38, 2).rotuloPorModalidade, 'Cliente levando o produto');
    });
    test('35 significa aguardando retirada, sem devolução', () {
      final fluxo = f(t, 35, 4);
      expect(fluxo.aguardandoRetirada, isTrue);
      expect(fluxo.aguardandoDevolucao, isFalse);
      expect(fluxo.destinoCliente, DestinoCliente.confirmarRetirada);
      expect(fluxo.destinoProfissional, DestinoProfissional.estado);
      expect(fluxo.rotuloPorModalidade, 'Aguardando retirada pelo cliente');
    });
  });

  group('Receba em Casa', () {
    const t = 'Receba em Casa';
    test('cliente leva o produto e o profissional devolve', () {
      expect(f(t, 3, 1, 'Pago').profissionalPodeIniciarBusca, isFalse);
      expect(f(t, 38, 2).destinoCliente, DestinoCliente.deslocamentoCliente);
      expect(f(t, 35, 4).destinoProfissional, DestinoProfissional.deslocamento);
      expect(f(t, 37, 4).destinoCliente, DestinoCliente.acompanharDeslocamento);
    });
    test('registro antigo 34 / etapa 4 é tratado como devolução chegou', () {
      final fluxo = f(t, 34, 4);
      expect(fluxo.devolucaoChegou, isTrue);
      expect(fluxo.profissionalChegou, isFalse);
      expect(fluxo.destinoProfissional, DestinoProfissional.devolucaoNoLocal);
    });
  });

  test('status 1 é exibido como "Aberto" e fica na etapa 0', () {
    final fluxo = f('Leva e Traz', 1, 0, 'Aguardando Profissional');
    expect(fluxo.rotuloPorModalidade, 'Aberto');
    expect(fluxo.etapaEfetiva, 0);
  });
}
