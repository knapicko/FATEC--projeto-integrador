import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Quais tutoriais o usuário já viu. Fica no aparelho (por conta) e no
/// servidor (usuarios.tutoriais_vistos — docs/sql/v0_11_ajustes.sql), para
/// não repetir ao trocar de aparelho. Sem a coluna, vale só o aparelho.
class TutorialVisto {
  TutorialVisto._();

  static Set<String>? _cache;
  static String? _uidCache;

  static String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  static Future<Set<String>> _vistos() async {
    final uid = _uid;
    if (uid == null) return {};
    if (_cache != null && _uidCache == uid) return _cache!;
    final vistos = <String>{};
    var doServidor = false;
    // O servidor manda (limpar lá reseta o tutorial em todos os aparelhos);
    // o aparelho só vale quando o servidor não responde.
    try {
      final r = await Supabase.instance.client.rpc('meus_tutoriais_vistos');
      if (r is List) {
        vistos.addAll(r.map((e) => e.toString()));
        doServidor = true;
      }
    } catch (e) {
      debugPrint('[tutorial] vistos no servidor (rode a v0_11): $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (doServidor) {
        await prefs.setStringList('tutoriais_vistos_$uid', vistos.toList());
      } else {
        vistos.addAll(prefs.getStringList('tutoriais_vistos_$uid') ?? const []);
      }
    } catch (_) {}
    _cache = vistos;
    _uidCache = uid;
    return vistos;
  }

  /// Conta nova que ainda vai confirmar o e-mail abre a home sem sessão:
  /// espera a sessão chegar (enquanto a tela existir) para mostrar o
  /// tutorial do primeiro acesso.
  static Future<bool> esperarSessao(bool Function() aberta) async {
    while (aberta() && _uid == null) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return aberta() && _uid != null;
  }

  /// Sem conta (visitante) conta como visto: não mostra tutorial.
  static Future<bool> jaViu(String chave) async {
    if (_uid == null) return true;
    return (await _vistos()).contains(chave);
  }

  static Future<void> marcar(String chave) async {
    final uid = _uid;
    if (uid == null) return;
    final vistos = await _vistos();
    vistos.add(chave);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tutoriais_vistos_$uid', vistos.toList());
    } catch (_) {}
    try {
      await Supabase.instance.client.rpc(
        'marcar_tutorial_visto',
        params: {'p_chave': chave},
      );
    } catch (_) {}
  }
}
