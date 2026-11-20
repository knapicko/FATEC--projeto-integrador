import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Conclui o cadastro do profissional pelo servidor (RPC
/// `concluir_cadastro_profissional`, docs/sql/v0_8_ajustes.sql): cria
/// dados_profissionais, os ofícios e os documentos de uma vez. Gravar direto
/// nessas tabelas era recusado pela regra de acesso (RLS).
///
/// Sem sessão (conta que ainda precisa confirmar o e-mail), os dados ficam
/// guardados no aparelho e são concluídos no primeiro login
/// ([concluirPendente], chamado pela home do profissional).
class ConclusaoCadastroProfissional {
  ConclusaoCadastroProfissional._();

  static const _chave = 'cadastro_profissional_pendente_v1';

  static SupabaseClient get _db => Supabase.instance.client;

  /// Devolve o id_profissional, ou null se ficou pendente (sem sessão).
  static Future<int?> concluir({
    required String? idFacial,
    required List<int> funcoes,
    required List<String> documentos,
    String? authId,
  }) async {
    if (_db.auth.currentSession == null) {
      await _guardar(authId, idFacial, funcoes, documentos);
      return null;
    }
    try {
      final id = await _db.rpc(
        'concluir_cadastro_profissional',
        params: {
          'p_id_facial': idFacial,
          'p_funcoes': funcoes,
          'p_documentos': documentos,
        },
      );
      await _limpar();
      return (id as num?)?.toInt();
    } catch (_) {
      // Fica guardado: o próximo login conclui.
      await _guardar(authId, idFacial, funcoes, documentos);
      rethrow;
    }
  }

  /// Conclui o que ficou pendente de um cadastro anterior (se houver).
  static Future<void> concluirPendente() async {
    try {
      if (_db.auth.currentSession == null) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chave);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['auth_id'] != null && m['auth_id'] != _db.auth.currentUser?.id) {
        return;
      }
      await concluir(
        idFacial: m['id_facial'] as String?,
        funcoes: [
          for (final f in (m['funcoes'] as List? ?? [])) (f as num).toInt(),
        ],
        documentos: [
          for (final d in (m['documentos'] as List? ?? [])) d.toString(),
        ],
      );
    } catch (e) {
      debugPrint('[cadastro profissional] pendente: $e');
    }
  }

  static Future<void> _guardar(
    String? authId,
    String? idFacial,
    List<int> funcoes,
    List<String> documentos,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chave,
      jsonEncode({
        'auth_id': authId ?? _db.auth.currentUser?.id,
        'id_facial': idFacial,
        'funcoes': funcoes,
        'documentos': documentos,
      }),
    );
  }

  static Future<void> _limpar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chave);
  }
}
