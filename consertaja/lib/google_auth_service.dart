import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Serviço responsável por autenticar o usuário com o Google e integrar
/// essa sessão com o Supabase Auth, além de consultar se o usuário já
/// possui um perfil completo na tabela `usuarios`.
///
/// ATENÇÃO (ajuste antes de rodar):
/// - `clientId` deve ser o "Web Client ID" (tipo OAuth 2.0 Client)
///   criado no Google Cloud Console, e o mesmo valor deve estar configurado
///   em Supabase > Authentication > Providers > Google.
/// - No Android, o SHA-1 do app precisa estar cadastrado no Google Cloud
///   Console para o login funcionar.
/// - No iOS, é necessário configurar o `CFBundleURLTypes` com o
///   REVERSED_CLIENT_ID no Info.plist.
class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '558968043989-4od8kobfna5a0art52usjpo7sjk8joao.apps.googleusercontent.com',
  );

  /// Dispara o fluxo nativo de login do Google e, com o idToken retornado,
  /// autentica (ou cadastra, se for a primeira vez) o usuário no Supabase.
  ///
  /// Retorna o [User] do Supabase autenticado, ou `null` se o usuário
  /// cancelou o fluxo de login do Google.
  static Future<User?> signInWithGoogle() async {
    // Garante que não fica sessão presa de uma tentativa anterior
    await _googleSignIn.signOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // Usuário cancelou o seletor de conta do Google
      return null;
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception(
        'Não foi possível obter as credenciais do Google. Tente novamente.',
      );
    }

    final response = await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    return response.user;
  }

  /// Realiza o login com o Google e já busca o perfil correspondente
  /// na tabela `usuarios` utilizando o `auth_id`.
  ///
  /// Retorna um registro contendo o [user] do Supabase e o [profile] (se existir).
  static Future<({User? user, Map<String, dynamic>? profile})> signInAndFetchProfile() async {
    final user = await signInWithGoogle();
    
    if (user == null) {
      return (user: null, profile: null);
    }

    final profile = await buscarPerfil(user.id);
    return (user: user, profile: profile);
  }

  /// Encerra a sessão do Google (útil ao fazer logout do app).
  static Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignora erro de signOut do Google (ex.: nunca logou)
    }
  }

  /// Busca o perfil (linha da tabela `usuarios`) vinculado ao [authId]
  /// (que é o `id` do usuário no Supabase Auth, salvo na coluna
  /// `usuarios.auth_id`).
  ///
  /// Retorna `null` se o usuário se autenticou (via Google, por exemplo)
  /// mas ainda não completou o cadastro (não existe linha em `usuarios`).
  static Future<Map<String, dynamic>?> buscarPerfil(String authId) async {
    try {
      final response = await Supabase.instance.client
          .from('usuarios')
          .select()
          .eq('auth_id', authId)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }
}