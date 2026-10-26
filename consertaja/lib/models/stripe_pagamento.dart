class StripePagamentoCriado {
  final int idSolicitacao;
  final String paymentIntentId;
  final String status;
  final String? pixCopiaECola;
  final String? pixQrCodeUrl;
  final int valorCentavos;
  final String moeda;

  const StripePagamentoCriado({
    required this.idSolicitacao,
    required this.paymentIntentId,
    required this.status,
    required this.pixCopiaECola,
    required this.pixQrCodeUrl,
    required this.valorCentavos,
    required this.moeda,
  });

  factory StripePagamentoCriado.fromMap(Map<String, dynamic> map) {
    return StripePagamentoCriado(
      idSolicitacao: (map['id_solicitacao'] as num?)?.toInt() ?? 0,
      paymentIntentId: map['payment_intent_id']?.toString() ?? '',
      status: map['status']?.toString() ?? 'requires_action',
      pixCopiaECola: map['pix_copia_cola']?.toString(),
      pixQrCodeUrl: map['pix_qr_code_url']?.toString(),
      valorCentavos: (map['valor_centavos'] as num?)?.toInt() ?? 0,
      moeda: map['moeda']?.toString() ?? 'brl',
    );
  }
}

class StripePagamentoStatus {
  final String status;
  final String? paymentIntentId;
  final int? idSolicitacao;
  final String? metodoPagamento;
  final String? pixCopiaECola;
  final String? pixQrCodeUrl;

  const StripePagamentoStatus({
    required this.status,
    this.paymentIntentId,
    this.idSolicitacao,
    this.metodoPagamento,
    this.pixCopiaECola,
    this.pixQrCodeUrl,
  });

  factory StripePagamentoStatus.fromMap(Map<String, dynamic> map) {
    return StripePagamentoStatus(
      status: map['status']?.toString() ?? 'unknown',
      paymentIntentId: map['stripe_payment_intent_id']?.toString(),
      idSolicitacao: (map['id_solicitacao'] as num?)?.toInt(),
      metodoPagamento: map['metodo_pagamento']?.toString(),
      pixCopiaECola: map['pix_copia_cola']?.toString(),
      pixQrCodeUrl: map['pix_qr_code_url']?.toString(),
    );
  }
}
