import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Presença online com base em `usuarios.ultima_conexao`.
///
/// Quem está com o app em primeiro plano atualiza o timestamp a cada
/// [_intervaloHeartbeat]. Quem visualiza considera online se a última
/// conexão ocorreu há no máximo [janelaOnline].
class VerificacaoOnline {
  VerificacaoOnline._();
  static final VerificacaoOnline instance = VerificacaoOnline._();

  static const Duration janelaOnline = Duration(seconds: 45);
  static const Duration _intervaloHeartbeat = Duration(seconds: 20);

  final _supabase = Supabase.instance.client;
  Timer? _timer;
  bool _atualizando = false;

  /// True se [ultimaConexao] está dentro da janela de presença.
  static bool estaOnline(DateTime? ultimaConexao) {
    if (ultimaConexao == null) return false;
    final local =
        ultimaConexao.isUtc ? ultimaConexao.toLocal() : ultimaConexao;
    return DateTime.now().difference(local) <= janelaOnline;
  }

  /// Inicia o heartbeat do usuário logado (idempotente).
  Future<void> iniciar() async {
    if (_supabase.auth.currentUser == null) {
      parar();
      return;
    }
    await registrarPresenca();
    _timer?.cancel();
    _timer = Timer.periodic(_intervaloHeartbeat, (_) {
      registrarPresenca();
    });
  }

  /// Para de atualizar e marca offline imediatamente no banco.
  void parar() {
    _timer?.cancel();
    _timer = null;
    marcarOffline();
  }

  /// Marca explicitamente o usuário como offline no Supabase.
  Future<void> marcarOffline() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return;

    try {
      // Grava uma data antiga (10 minutos atrás) para que 'estaOnline' retorne false na hora
      await _supabase
          .from('usuarios')
          .update({
            'ultima_conexao': DateTime.now()
                .toUtc()
                .subtract(const Duration(minutes: 10))
                .toIso8601String(),
          })
          .eq('auth_id', authUser.id);
    } catch (e) {
      debugPrint('VerificacaoOnline: falha ao marcar offline: $e');
    }
  }

  /// Grava `now()` em `usuarios.ultima_conexao` do usuário autenticado.
  Future<void> registrarPresenca() async {
    if (_atualizando) return;
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) return;

    _atualizando = true;
    try {
      await _supabase
          .from('usuarios')
          .update({'ultima_conexao': DateTime.now().toUtc().toIso8601String()})
          .eq('auth_id', authUser.id);
    } catch (e) {
      debugPrint('VerificacaoOnline: falha ao atualizar ultima_conexao: $e');
    } finally {
      _atualizando = false;
    }
  }
}
