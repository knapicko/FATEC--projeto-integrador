import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

enum TipoContaCadastro { cliente, profissional }

class GoogleAuthException implements Exception {
  final String codigo;
  final String descricao;
  final Object? detalhes;

  const GoogleAuthException({
    required this.codigo,
    required this.descricao,
    this.detalhes,
  });

  @override
  String toString() {
    final complemento = detalhes == null ? '' : ' | detalhes: $detalhes';
    return 'Google [$codigo]: $descricao$complemento';
  }
}

class GoogleAuthService {
  static const webClientId =
      '558968043989-4od8kobfna5a0art52usjpo7sjk8joao.apps.googleusercontent.com';

  static bool _googleSignInInitialized = false;

  /// Armazena a URL da foto do último login do Google.
  /// Usado em telas que precisam da foto mas não têm acesso direto ao
  /// [GoogleSignInAccount].
  static String? ultimaFotoUrl;

  static Future<void> _initializeGoogleSignIn() async {
    if (_googleSignInInitialized) return;

    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? webClientId : null,
      serverClientId: webClientId,
    );

    _googleSignInInitialized = true;
  }

  static Future<User?> signInWithGoogle() async {
    final supabase = Supabase.instance.client;
    await _initializeGoogleSignIn();

    try {
      if (kIsWeb) {
        final googleUser =
            await GoogleSignIn.instance.attemptLightweightAuthentication() ??
            await GoogleSignIn.instance.authenticate();
        return await _processGoogleUser(googleUser, supabase);
      }

      final googleUser = await _authenticateOnAndroid();
      return await _processGoogleUser(googleUser, supabase);
    } on GoogleSignInException catch (e) {
      throw GoogleAuthException(
        codigo: e.code.name,
        descricao: e.description ?? 'O Google não informou a causa.',
        detalhes: e.details,
      );
    } catch (e) {
      throw GoogleAuthException(
        codigo: 'erro_aplicacao',
        descricao: 'Falha ao concluir a autenticação com o Google.',
        detalhes: e,
      );
    }
  }

  static Future<GoogleSignInAccount> _authenticateOnAndroid() async {
    try {
      return await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      final descricao = e.description?.toLowerCase() ?? '';
      final falhaDeReautenticacao =
          e.code == GoogleSignInExceptionCode.canceled &&
          descricao.contains('reauth');

      if (!falhaDeReautenticacao) rethrow;

      // O Credential Manager pode manter uma credencial inválida após uma
      // troca de conta. Limpa somente esse estado e permite uma nova tentativa.
      await GoogleSignIn.instance.signOut();
      return GoogleSignIn.instance.authenticate();
    }
  }

  static String mensagemErro(Object erro) {
    if (erro is GoogleAuthException) {
      final orientacao = erro.codigo == 'canceled'
          ? ' No Android, confirme no Google Cloud Console o cliente OAuth '
                'Android com pacote com.example.consertaja e o SHA-1 do APK.'
          : erro.codigo == 'clientConfigurationError' ||
                erro.codigo == 'providerConfigurationError'
          ? ' Confira a configuração do OAuth e do serverClientId.'
          : '';
      return '${erro.toString()}$orientacao';
    }
    return 'Google [erro_desconhecido]: $erro';
  }

  static Future<void> cancelarCadastroGoogle() async {
    final erros = <Object>[];
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      erros.add(e);
    }
    try {
      await GoogleSignIn.instance.signOut();
    } catch (e) {
      erros.add(e);
    }
    ultimaFotoUrl = null;
    if (erros.isNotEmpty) {
      throw GoogleAuthException(
        codigo: 'cancelamento_incompleto',
        descricao: 'Não foi possível encerrar completamente a sessão Google.',
        detalhes: erros,
      );
    }
  }

  // Nota: fluxo web está tratado em `signInWithGoogle`, este método não é mais
  // necessário com a API 7.x.

  static Future<User?> _processGoogleUser(
    GoogleSignInAccount googleUser,
    SupabaseClient supabase,
  ) async {
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception('Não foi possível obter o ID Token do Google.');
    }

    // Guarda a foto para uso posterior em outras telas
    ultimaFotoUrl = googleUser.photoUrl;

    // Tenta obter um accessToken para autorização (pode ser nulo)
    String? accessToken;
    try {
      final authz = await googleUser.authorizationClient.authorizationForScopes(
        ['email', 'profile'],
      );
      accessToken = authz?.accessToken;
    } catch (_) {
      accessToken = null;
    }

    final response = await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    // Persiste nome e foto nos metadados do usuário no Supabase,
    // permitindo acessar via: user.userMetadata?['avatar_url']
    if (response.user != null) {
      final metadataAtual = response.user!.userMetadata ?? {};
      final nome = googleUser.displayName;
      final foto = googleUser.photoUrl;

      // Só atualiza se houver algo novo para evitar chamadas desnecessárias
      if ((nome != null && metadataAtual['full_name'] != nome) ||
          (foto != null && metadataAtual['avatar_url'] != foto)) {
        try {
          await supabase.auth.updateUser(
            UserAttributes(
              data: {
                'full_name': nome ?? metadataAtual['full_name'],
                'avatar_url': foto ?? metadataAtual['avatar_url'],
              },
            ),
          );
        } catch (_) {
          // Se falhar, o usuário ainda está autenticado — seguimos sem metadados
        }
      }
    }

    return response.user;
  }

  static Future<Map<String, dynamic>?> buscarPerfil(String authId) async {
    return Supabase.instance.client
        .from('usuarios')
        .select('tipo_conta')
        .eq('auth_id', authId)
        .maybeSingle();
  }

  static Future<bool> perfilExiste(String authId) async {
    final perfil = await buscarPerfil(authId);
    return perfil != null;
  }

  static String? extrairNome(User user) {
    final metadata = user.userMetadata;
    if (metadata != null) {
      final fullName = metadata['full_name'] ?? metadata['name'];
      if (fullName is String && fullName.isNotEmpty) return fullName;
    }
    return null;
  }
}
