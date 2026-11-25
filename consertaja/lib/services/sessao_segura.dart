import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Guarda a sessão do Supabase (access + refresh token) no cofre do aparelho
/// (Android Keystore / iOS Keychain) em vez das SharedPreferences, que ficam
/// em texto puro. Na primeira vez, traz a sessão antiga das SharedPreferences
/// e apaga de lá — ninguém precisa entrar de novo depois da atualização.
class SessaoSeguraStorage extends LocalStorage {
  SessaoSeguraStorage({required this.chave});

  final String chave;

  static const FlutterSecureStorage _cofre = FlutterSecureStorage();
  String? _cache;

  @override
  Future<void> initialize() async {
    try {
      _cache = await _cofre.read(key: chave);
      // Migração da versão antiga (SharedPreferences).
      final prefs = await SharedPreferences.getInstance();
      final antiga = prefs.getString(chave);
      if (antiga != null) {
        if (_cache == null) {
          await _cofre.write(key: chave, value: antiga);
          _cache = antiga;
        }
        await prefs.remove(chave);
      }
    } catch (e) {
      debugPrint('SessaoSegura: $e');
    }
  }

  @override
  Future<bool> hasAccessToken() async => _cache != null;

  @override
  Future<String?> accessToken() async => _cache;

  @override
  Future<void> persistSession(String persistSessionString) async {
    _cache = persistSessionString;
    try {
      await _cofre.write(key: chave, value: persistSessionString);
    } catch (e) {
      debugPrint('SessaoSegura: $e');
    }
  }

  @override
  Future<void> removePersistedSession() async {
    _cache = null;
    try {
      await _cofre.delete(key: chave);
    } catch (e) {
      debugPrint('SessaoSegura: $e');
    }
  }
}
