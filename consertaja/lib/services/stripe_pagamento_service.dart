import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stripe_pagamento.dart';

class StripePagamentoService {
  StripePagamentoService._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<StripePagamentoCriado> criarPagamentoPix({
    required int idSolicitacao,
  }) async {
    final response = await _supabase.functions.invoke(
      'criar-pagamento-stripe',
      body: {'id_solicitacao': idSolicitacao, 'metodo_pagamento': 'pix'},
    );
    final data = _mapResponse(response.data);
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    return StripePagamentoCriado.fromMap(data);
  }

  static Future<StripePagamentoCriado> criarPagamentoCartao({
    required int idSolicitacao,
    required String numero,
    required int mesExpiracao,
    required int anoExpiracao,
    required String cvc,
    required bool credito,
  }) async {
    final response = await _supabase.functions.invoke(
      'criar-pagamento-stripe',
      body: {
        'id_solicitacao': idSolicitacao,
        'metodo_pagamento': credito ? 'card_credit' : 'card_debit',
        'cartao': {
          'number': numero.replaceAll(RegExp(r'\D'), ''),
          'exp_month': mesExpiracao,
          'exp_year': anoExpiracao,
          'cvc': cvc,
        },
      },
    );
    final data = _mapResponse(response.data);
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    return StripePagamentoCriado.fromMap(data);
  }

  static Future<StripePagamentoStatus> consultarStatus({
    required int idSolicitacao,
  }) async {
    final response = await _supabase.functions.invoke(
      'consultar-pagamento-stripe',
      body: {'id_solicitacao': idSolicitacao},
    );
    final data = _mapResponse(response.data);
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    return StripePagamentoStatus.fromMap(data);
  }

  static Map<String, dynamic> _mapResponse(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw Exception('Resposta inválida do servidor de pagamentos.');
  }
}
