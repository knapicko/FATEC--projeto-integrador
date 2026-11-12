import 'package:supabase_flutter/supabase_flutter.dart';

class SolicitacoesService {
  SolicitacoesService._();

  static final _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> buscarParaProfissional(
    int idProfissional,
  ) async {
    final dados = await _supabase
        .from('dados_profissionais')
        .select('fk_grupo_empresa')
        .eq('id_profissional', idProfissional)
        .maybeSingle();
    final idGrupo = (dados?['fk_grupo_empresa'] as num?)?.toInt();

    final pedidosIndividuais = await _supabase
        .from('solicitacoes')
        .select('*, servicos_profissional(titulo, valor, tipo_execucao, carga_servico)')
        .eq('fk_profissional', idProfissional)
        .order('data_solicitacao', ascending: false);

    if (idGrupo == null) {
      return List<Map<String, dynamic>>.from(pedidosIndividuais);
    }

    final pedidosLoja = await _supabase
        .from('solicitacoes')
        .select('*, servicos_profissional(titulo, valor, tipo_execucao, carga_servico)')
        .eq('fk_grupo_empresa', idGrupo)
        .order('data_solicitacao', ascending: false);

    final porId = <int, Map<String, dynamic>>{};
    for (final pedido in [
      ...pedidosIndividuais,
      ...pedidosLoja,
    ]) {
      final id = (pedido['id_solicitacao'] as num?)?.toInt();
      if (id != null) porId[id] = Map<String, dynamic>.from(pedido);
    }
    final resultado = porId.values.toList()
      ..sort((a, b) => (b['data_solicitacao']?.toString() ?? '')
          .compareTo(a['data_solicitacao']?.toString() ?? ''));
    return resultado;
  }

  static Future<Map<String, dynamic>> aceitar({
    required int idSolicitacao,
    required int idProfissional,
  }) async {
    final resposta = await _supabase.rpc(
      'aceitar_solicitacao',
      params: {
        'p_id_solicitacao': idSolicitacao,
        'p_id_profissional': idProfissional,
      },
    );
    Map<String, dynamic>? pedido;
    if (resposta is List && resposta.isNotEmpty) {
      pedido = Map<String, dynamic>.from(resposta.first);
    } else if (resposta is Map) {
      pedido = Map<String, dynamic>.from(resposta);
    }
    if (pedido == null) {
      throw Exception('A solicitação já foi aceita ou não está disponível.');
    }

    // A RPC grava o status "Aceito", mas não avança a etapa. Pelo fluxo,
    // o aceite leva a solicitação da etapa 0 para a etapa 1 (pagamento).
    await marcarEtapaAceite(idSolicitacao);
    pedido['etapa_solicitacao'] = 1;
    return pedido;
  }

  /// Garante `etapa_solicitacao = 1` após o aceite (sem retroceder etapas).
  static Future<void> marcarEtapaAceite(int idSolicitacao) async {
    await _supabase
        .from('solicitacoes')
        .update({'etapa_solicitacao': 1})
        .eq('id_solicitacao', idSolicitacao)
        .lt('etapa_solicitacao', 1);
  }
}
