// =============================================================================
// Plano de Testes ConsertaJá — PT-CJ-01
// Arquivo: CT43 a CT48 — Avaliação, Histórico de Serviços e Notificações
// Requisitos: RF021 (avaliação), RF022 (histórico), RF024 (notificações),
//             RN006 (apenas serviços concluídos podem ser avaliados)
// Abordagem: Testes unitários
// =============================================================================
import 'package:consertaja/services/notificacoes/notificacao_app.dart';
import 'package:consertaja/services/notificacoes/notificacao_tipos.dart';
import 'package:consertaja/services/pedidos_cliente_service.dart';
import 'package:consertaja/utils/fluxo_solicitacao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PedidoResumo _pedido({int? status = 6, bool avaliado = false}) => PedidoResumo(
  id: 1,
  fkStatus: status,
  status: status == 6 ? 'Concluído' : 'Em andamento',
  titulo: 'Afiação de facas',
  prestador: 'Seu Zé',
  valor: 35,
  avaliado: avaliado,
);

void main() {
  group('RF021/RN006 — Avaliação de serviço', () {
    test('CT43 - Só pede avaliação de serviço concluído e ainda não avaliado', () {
      expect(_pedido().concluido, isTrue);
      expect(_pedido().precisaAvaliar, isTrue);
      expect(_pedido(avaliado: true).precisaAvaliar, isFalse);
      expect(_pedido(status: 4).concluido, isFalse);
      expect(_pedido(status: 4).precisaAvaliar, isFalse);
      expect(_pedido(status: null).precisaAvaliar, isFalse);
    });
  });

  group('RF022 — Histórico de serviços', () {
    test('CT44 - Pedido concluído aparece na etapa final "Concluído"', () {
      for (final tipo in [
        'Leva e Traz',
        'Atendimento em Domicílio',
        'Retirado no Local',
        'Receba em Casa',
      ]) {
        final fluxo = FluxoSolicitacao(
          tipoExecucao: tipo,
          fkStatus: StatusSolicitacao.concluido,
          etapa: 2,
        );
        final etapa = fluxo.etapaEfetiva;
        expect(fluxo.estaConcluido, isTrue, reason: tipo);
        expect(fluxo.modalidade.titulosEtapas[etapa - 1], 'Concluído', reason: tipo);
      }
    });
  });

  group('RF024 — Notificações', () {
    test('CT45 - Tipo da notificação a partir do valor do banco', () {
      expect(TipoNotificacao.deBanco('Conversa'), TipoNotificacao.conversa);
      expect(TipoNotificacao.deBanco('Solicitação'), TipoNotificacao.solicitacao);
      expect(TipoNotificacao.deBanco('radar_prof'), TipoNotificacao.radarProf);
      expect(TipoNotificacao.deBanco('inexistente'), TipoNotificacao.sistema);
      expect(TipoNotificacao.deBanco(null), TipoNotificacao.sistema);
      expect(TipoNotificacao.radarCliente.ehRadar, isTrue);
      expect(TipoNotificacao.conversa.ehRadar, isFalse);
      final bancos = TipoNotificacao.values.map((t) => t.banco).toSet();
      expect(bancos, hasLength(TipoNotificacao.values.length));
    });

    test('CT46 - Cor e ícone de cada status na notificação', () {
      expect(VisualStatus.de(6)?.cor, const Color(0xFF16A34A));
      expect(VisualStatus.de(6)?.icone, Icons.task_alt_rounded);
      expect(VisualStatus.de(7)?.icone, Icons.cancel_rounded);
      expect(VisualStatus.de(30)?.icone, Icons.cancel_rounded);
      expect(VisualStatus.de(33)?.icone, Icons.directions_car_rounded);
      expect(VisualStatus.de(999), isNull);
      expect(VisualStatus.de(null), isNull);
    });

    test('CT47 - Notificação recebida via push (campos em texto)', () {
      final n = NotificacaoApp.fromMap({
        'id_notificacao': '15',
        'tipo': 'Solicitação',
        'titulo': '',
        'conteudo': 'Pagamento confirmado',
        'data_criacao': '2026-11-18T13:00:00Z',
        'aberta': 'true',
        'tela_destino': 'null',
        'fk_solicitacao': '42',
        'fk_status': '3',
        'dados': '{"papel":"cliente","status":"Pago"}',
      });
      expect(n.id, 15);
      expect(n.tipo, TipoNotificacao.solicitacao);
      expect(n.titulo, 'ConsertaJá'); // título vazio usa o padrão
      expect(n.aberta, isTrue);
      expect(n.telaDestino, isNull);
      expect(n.fkSolicitacao, 42);
      expect(n.fkStatus, 3);
      expect(n.papel, 'cliente');
      expect(n.textoStatus, 'Pago');
      expect(n.corArgb, 0xFF16A34A); // cor do status "Pago"
      expect(
        n.dataCriacao.isAtSameMomentAs(DateTime.utc(2026, 11, 18, 13)),
        isTrue,
      );

      final semStatus = NotificacaoApp.fromMap({'tipo': 'Conversa'});
      expect(semStatus.corArgb, const Color(0xFF10B981).toARGB32());
      expect(semStatus.dados, isEmpty);
    });

    test('CT48 - Payload da notificação local vai e volta sem perdas', () {
      final original = NotificacaoApp(
        id: 7,
        tipo: TipoNotificacao.conversa,
        titulo: 'Nova mensagem',
        conteudo: 'Olá!',
        dataCriacao: DateTime.utc(2026, 11, 18, 10, 30),
        fkConversa: 3,
        dados: const {'papel': 'profissional'},
      );
      final volta = NotificacaoApp.dePayload(original.paraPayload())!;
      expect(volta.id, 7);
      expect(volta.tipo, TipoNotificacao.conversa);
      expect(volta.titulo, 'Nova mensagem');
      expect(volta.fkConversa, 3);
      expect(volta.papel, 'profissional');
      expect(volta.dataCriacao.isAtSameMomentAs(original.dataCriacao), isTrue);
      expect(volta.aberta, isFalse);

      final aberta = original.copiarAberta();
      expect(aberta.aberta, isTrue);
      expect(aberta.id, original.id);

      expect(NotificacaoApp.dePayload(null), isNull);
      expect(NotificacaoApp.dePayload(''), isNull);
      expect(NotificacaoApp.dePayload('{json quebrado'), isNull);
    });
  });
}
