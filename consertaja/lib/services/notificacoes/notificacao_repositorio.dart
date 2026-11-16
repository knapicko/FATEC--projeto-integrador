import 'package:supabase_flutter/supabase_flutter.dart';

import 'notificacao_app.dart';

/// Acesso à tabela `notificacoes` (RLS: só as do próprio usuário).
class NotificacaoRepositorio {
  NotificacaoRepositorio._();

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<int?> meuIdUsuario() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    final row = await _db
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', user.id)
        .maybeSingle();
    return (row?['id_usuario'] as num?)?.toInt();
  }

  static Future<List<NotificacaoApp>> listar({int limite = 150}) async {
    final rows = await _db
        .from('notificacoes')
        .select(
          'id_notificacao, tipo, titulo, conteudo, data_criacao, aberta, '
          'tela_destino, imagem_url, fk_solicitacao, fk_conversa, '
          'fk_solicitacao_geografica, fk_status, dados',
        )
        .neq('tipo', 'feedback')
        .order('data_criacao', ascending: false)
        .limit(limite);
    return rows.map(NotificacaoApp.fromMap).toList();
  }

  static Future<void> marcarAberta(int idNotificacao) async {
    await _db.rpc(
      'marcar_notificacoes_abertas',
      params: {
        'p_ids': [idNotificacao],
      },
    );
  }

  static Future<int> marcarTodasAbertas() async {
    final r = await _db.rpc('marcar_notificacoes_abertas');
    return (r as num?)?.toInt() ?? 0;
  }

  static Future<void> excluir(int idNotificacao) async {
    await _db.from('notificacoes').delete().eq('id_notificacao', idNotificacao);
  }

  /// (notificações não lidas sem Conversa, mensagens não lidas)
  static Future<(int, int)> contadores() async {
    final r = await _db.rpc('contadores_notificacoes');
    if (r is Map) {
      return (
        (r['nao_lidas'] as num?)?.toInt() ?? 0,
        (r['mensagens_nao_lidas'] as num?)?.toInt() ?? 0,
      );
    }
    return (0, 0);
  }

  static Future<void> registrarDispositivo({
    required String token,
    required String plataforma,
    required String perfilAtivo,
  }) async {
    await _db.rpc(
      'registrar_dispositivo_notificacao',
      params: {
        'p_token': token,
        'p_plataforma': plataforma,
        'p_perfil_ativo': perfilAtivo,
      },
    );
  }
}
