import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

enum TipoContaCadastro { cliente, profissional }

class GoogleAuthService {
  static const webClientId =
      '558968043989-4od8kobfna5a0art52usjpo7sjk8joao.apps.googleusercontent.com';

  /// Armazena a URL da foto do último login do Google.
  /// Usado em telas que precisam da foto mas não têm acesso direto ao
  /// [GoogleSignInAccount].
  static String? ultimaFotoUrl;

  static Future<User?> signInWithGoogle() async {
    final supabase = Supabase.instance.client;
    
    if (kIsWeb) {
      // Na web, usamos signInSilently que retorna idToken de forma confiável
      final googleSignIn = GoogleSignIn(clientId: webClientId);
      
      // Tenta fazer login silencioso primeiro
      final googleUser = await googleSignIn.signInSilently();
      
      // Se não houver usuário logado, faz login normal
      if (googleUser == null) {
        return await _signInWithGoogleWeb(googleSignIn, supabase);
      }
      
      return await _processGoogleUser(googleUser, supabase);
    } else {
      // Em mobile/desktop, usa o método tradicional
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) return null;

      return await _processGoogleUser(googleUser, supabase);
    }
  }
  
  static Future<User?> _signInWithGoogleWeb(
    GoogleSignIn googleSignIn,
    SupabaseClient supabase,
  ) async {
    try {
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;
      return await _processGoogleUser(googleUser, supabase);
    } catch (e) {
      throw Exception('Erro ao fazer login com Google: $e');
    }
  }
  
  static Future<User?> _processGoogleUser(
    GoogleSignInAccount googleUser,
    SupabaseClient supabase,
  ) async {
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception('Não foi possível obter o ID Token do Google.');
    }

    // Guarda a foto para uso posterior em outras telas
    ultimaFotoUrl = googleUser.photoUrl;

    final response = await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
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