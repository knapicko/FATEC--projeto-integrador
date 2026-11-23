// =============================================================================
// Plano de Testes ConsertaJá — PT-CJ-01
// Arquivo: CT34 a CT36 — Pagamento Integrado (Stripe / Pix)
// Requisitos: RF018 (pagamento), RN001 (liberação após conclusão)
// Abordagem: Testes unitários
// =============================================================================
import 'package:consertaja/models/stripe_pagamento.dart';
import 'package:consertaja/utils/fluxo_solicitacao.dart';
import 'package:flutter_test/flutter_test.dart';

FluxoSolicitacao f(int? status, int etapa, [String? texto]) => FluxoSolicitacao(
  tipoExecucao: 'Leva e Traz',
  fkStatus: status,
  etapa: etapa,
  statusTexto: texto,
);

void main() {
  group('RF018 — Pagamento integrado', () {
    test('CT34 - Cobrança Pix criada é lida corretamente (e com padrões)', () {
      final pix = StripePagamentoCriado.fromMap({
        'id_solicitacao': 42,
        'payment_intent_id': 'pi_123',
        'status': 'requires_action',
        'pix_copia_cola': '00020126...',
        'pix_qr_code_url': 'https://qr.exemplo/pi_123.png',
        'valor_centavos': 12050,
        'moeda': 'brl',
      });
      expect(pix.idSolicitacao, 42);
      expect(pix.paymentIntentId, 'pi_123');
      expect(pix.pixCopiaECola, startsWith('000201'));
      expect(pix.valorCentavos, 12050);
      expect(pix.valorCentavos / 100, 120.5);

      final vazio = StripePagamentoCriado.fromMap(const {});
      expect(vazio.idSolicitacao, 0);
      expect(vazio.paymentIntentId, '');
      expect(vazio.status, 'requires_action');
      expect(vazio.moeda, 'brl');
      expect(vazio.valorCentavos, 0);
      expect(vazio.pixCopiaECola, isNull);
    });

    test('CT35 - Consulta de status do pagamento', () {
      final pago = StripePagamentoStatus.fromMap({
        'status': 'succeeded',
        'stripe_payment_intent_id': 'pi_123',
        'id_solicitacao': 42,
        'metodo_pagamento': 'pix',
      });
      expect(pago.status, 'succeeded');
      expect(pago.paymentIntentId, 'pi_123');
      expect(pago.idSolicitacao, 42);
      expect(pago.metodoPagamento, 'pix');

      final desconhecido = StripePagamentoStatus.fromMap(const {});
      expect(desconhecido.status, 'unknown');
      expect(desconhecido.idSolicitacao, isNull);
    });

    test('CT36 - Pedido só avança depois do pagamento confirmado', () {
      // aceito, aguardando pagamento
      expect(f(2, 1).aguardandoPagamento, isTrue);
      expect(f(31, 1).aguardandoPagamento, isTrue);
      expect(f(null, 1, 'Aceito').aguardandoPagamento, isTrue);
      expect(f(2, 0).etapaEfetiva, 1);
      expect(f(2, 1).estaPago, isFalse);
      expect(f(2, 1).profissionalPodeIniciarBusca, isFalse);

      // pago
      expect(f(3, 1).estaPago, isTrue);
      expect(f(null, 1, 'Pago').estaPago, isTrue);
      expect(f(3, 1).profissionalPodeIniciarBusca, isTrue);
    });
  });
}
