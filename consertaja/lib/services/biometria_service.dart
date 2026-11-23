import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Login por biometria (digital / Face ID do próprio celular).
///
/// Ao ativar, o e-mail e a senha da conta ficam guardados no cofre seguro do
/// aparelho (Keystore no Android, Keychain no iOS). Na tela de login, a
/// biometria libera esse cofre e o app entra na ÚLTIMA conta que ativou a
/// opção neste celular. Nada vai para o servidor.
class BiometriaService {
  BiometriaService._();

  static final LocalAuthentication _auth = LocalAuthentication();
  static const FlutterSecureStorage _cofre = FlutterSecureStorage();

  static const _chaveId = 'biometria_identificador';
  static const _chaveSenha = 'biometria_senha';
  static const _chaveUsuario = 'biometria_auth_id';
  static const _chaveNome = 'biometria_nome';

  /// O aparelho tem biometria (ou bloqueio de tela) configurada.
  static Future<bool> disponivel() async {
    if (kIsWeb) return false;
    try {
      final suportado = await _auth.isDeviceSupported();
      if (!suportado) return false;
      final tipos = await _auth.getAvailableBiometrics();
      return tipos.isNotEmpty;
    } catch (e) {
      debugPrint('Biometria: $e');
      return false;
    }
  }

  /// Pede a digital / o rosto. true = confirmado.
  static Future<bool> autenticar(String motivo) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('Biometria: $e');
      return false;
    }
  }

  static Future<void> salvar({
    required String identificador,
    required String senha,
    required String authId,
    String? nome,
  }) async {
    await _cofre.write(key: _chaveId, value: identificador);
    await _cofre.write(key: _chaveSenha, value: senha);
    await _cofre.write(key: _chaveUsuario, value: authId);
    await _cofre.write(key: _chaveNome, value: nome ?? '');
  }

  static Future<void> apagar() async {
    for (final k in [_chaveId, _chaveSenha, _chaveUsuario, _chaveNome]) {
      try {
        await _cofre.delete(key: k);
      } catch (_) {}
    }
  }

  /// Dono da conta guardada (auth id), ou null.
  static Future<String?> contaGuardada() async {
    try {
      return await _cofre.read(key: _chaveUsuario);
    } catch (_) {
      return null;
    }
  }

  /// Primeiro nome da conta guardada (para o botão do login).
  static Future<String?> nomeGuardado() async {
    try {
      final n = (await _cofre.read(key: _chaveNome))?.trim() ?? '';
      return n.isEmpty ? null : n.split(' ').first;
    } catch (_) {
      return null;
    }
  }

  /// Identificador e senha guardados (só depois de [autenticar]).
  static Future<(String, String)?> credenciais() async {
    try {
      final id = await _cofre.read(key: _chaveId);
      final senha = await _cofre.read(key: _chaveSenha);
      if (id == null || senha == null || id.isEmpty || senha.isEmpty) {
        return null;
      }
      return (id, senha);
    } catch (_) {
      return null;
    }
  }
}
