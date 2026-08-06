import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'google_auth_service.dart';
import '../tela_home.dart';
import '../tela_home_profissional.dart';
import '../cadastro_cliente.dart';
import '../cadastro_profissional.dart';
import '../tela_escolha_conta.dart';

/// Após login/cadastro com Google, redireciona para home ou cadastro incompleto.
Future<void> navegarPosAutenticacaoGoogle(
  BuildContext context, {
  TipoContaCadastro? tipoContaEsperado,
}) async {
  if (!context.mounted) return;

  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;

  final perfil = await GoogleAuthService.buscarPerfil(user.id);

  if (perfil != null) {
    final isProfissional = perfil['tipo_conta'] == 'Profissional';
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => isProfissional
            ? TelaHomeProfissional(isVisitante: false)
            : TelaHome(isVisitante: false),
      ),
      (_) => false,
    );
    return;
  }

  final nome = GoogleAuthService.extrairNome(user);
  final email = user.email ?? '';

  if (!context.mounted) return;

  final fotoUrl = GoogleAuthService.ultimaFotoUrl;

  if (tipoContaEsperado == TipoContaCadastro.cliente) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CadastroClientePage(
          nome: nome,
          email: email,
          fotoPerfilUrl: fotoUrl ?? 'null',
        ),
      ),
    );
  } else if (tipoContaEsperado == TipoContaCadastro.profissional) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CadastroProfissionalPage(
          nome: nome,
          fotoPerfilUrl: fotoUrl ?? 'null',
        ),
      ),
    );
  } else {
    final user = Supabase.instance.client.auth.currentUser;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => TelaEscolhaContaCompletar(
          authId: user?.id ?? '',
          emailGoogle: user?.email ?? '',
          nomeGoogle: nome,
          fotoUrlGoogle: fotoUrl,
        ),
      ),
      (_) => false,
    );
  }
}

/// Tela exibida quando o usuário fez login com Google mas ainda não completou o cadastro.
class TelaEscolhaContaCompletar extends StatelessWidget {
  final String authId;
  final String emailGoogle;
  final String? nomeGoogle;
  final String? fotoUrlGoogle;

  const TelaEscolhaContaCompletar({
    super.key,
    required this.authId,
    required this.emailGoogle,
    this.nomeGoogle,
    this.fotoUrlGoogle,
  });

  @override
  Widget build(BuildContext context) {
    final nome = nomeGoogle;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              if (fotoUrlGoogle != null)
                CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(fotoUrlGoogle!),
                ),
              const SizedBox(height: 12),
              Image.asset('assets/images/Logo.png', height: 80),
              const SizedBox(height: 16),
              const Text(
                'Complete seu cadastro',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00A3FF),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nome != null
                    ? 'Olá, $nome! Escolha o tipo de conta para continuar.'
                    : 'Escolha o tipo de conta para completar seu cadastro.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Você precisará informar CPF/CNPJ e demais dados obrigatórios.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              _BotaoTipoConta(
                titulo: 'Sou um Cliente',
                subtitulo: 'Complete seu cadastro como cliente',
                cor: const Color(0xFF00A2FF),
                icone: Icons.people_alt_outlined,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CadastroClientePage(
                        nome: nome,
                        email: emailGoogle,
                        fotoPerfilUrl: fotoUrlGoogle ?? 'null',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _BotaoTipoConta(
                titulo: 'Sou um Profissional',
                subtitulo: 'Complete seu cadastro como profissional',
                cor: const Color(0xFFF2994A),
                icone: Icons.handyman_outlined,
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CadastroProfissionalPage(
                        nome: nome,
                        fotoPerfilUrl: fotoUrlGoogle ?? 'null',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TelaEscolhaConta(),
                      ),
                      (_) => false,
                    );
                  }
                },
                child: const Text(
                  'Sair e voltar ao início',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BotaoTipoConta extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Color cor;
  final IconData icone;
  final VoidCallback onTap;

  const _BotaoTipoConta({
    required this.titulo,
    required this.subtitulo,
    required this.cor,
    required this.icone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cor, width: 2),
        ),
        child: Row(
          children: [
            Icon(icone, size: 36, color: cor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}