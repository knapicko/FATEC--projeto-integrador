import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding/onboarding_theme.dart';
import 'onboarding/onboarding_widgets.dart';

class EsqueciSenhaPage extends StatefulWidget {
  const EsqueciSenhaPage({super.key});

  @override
  State<EsqueciSenhaPage> createState() => _EsqueciSenhaPageState();
}

class _EsqueciSenhaPageState extends State<EsqueciSenhaPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _enviando = false;
  bool _emailEnviado = false;
  String? _erroEmail;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      if (_emailController.text.isNotEmpty && _erroEmail != null) {
        setState(() => _erroEmail = null);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviarEmailRecuperacao() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _erroEmail = 'Por favor, digite o seu e-mail.');
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _erroEmail = 'Por favor, insira um e-mail válido.');
      return;
    }

    setState(() => _enviando = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Procura direto na tabela de e-mails
      final respostaContagem = await supabase
          .from('emails')
          .select('endereco_email')
          .eq('endereco_email', email)
          .count(CountOption.exact);

      final int quantidadeEncontrada = respostaContagem.count;

      // 2. Se a contagem for igual a 0, o e-mail não existe no sistema
      if (quantidadeEncontrada == 0) {
        setState(() {
          _erroEmail = 'Este e-mail não está cadastrado no ConsertaJá.';
        });
        setState(() => _enviando = false);
        return;
      }

      // 3. Dispara o reset de senha
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'consertaja://reset-password',
      );

      if (mounted) {
        setState(() {
          _emailEnviado = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao processar solicitação: ${e.toString()}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OnboardingColors.blue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 28,
          ),
          splashRadius: 24,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: _emailEnviado ? _buildTelaSucesso() : _buildFormularioEmail(),
          ),
        ),
      ),
    );
  }

  // Formulário do email
  Widget _buildFormularioEmail() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Hero(
            tag: 'caixa-transicao-inicial',
            child: SizedBox(
              width: 150,
              height: 150,
              child: Image.asset(
                'assets/images/caixa/caixa_normal.png',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recuperar Senha',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Informe seu e-mail cadastrado para receber o link de recuperação.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
          OnboardingWhiteField(
            label: 'E-mail',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            errorText: _erroEmail,
          ),
          const SizedBox(height: 16),
          PillButton(
            label: 'Enviar Link',
            background: Colors.white,
            foreground: OnboardingColors.blue,
            loading: _enviando,
            onTap: _enviarEmailRecuperacao,
          ),
        ],
      ),
    );
  }

  // Tela de sucesso
  Widget _buildTelaSucesso() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.mark_email_read_rounded,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Link enviado com sucesso!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enviamos um link de recuperação para o e-mail informado.\n\nConfira na sua caixa de entrada ou na caixa de spam.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 36),
          PillButton(
            label: 'Voltar para o Login',
            background: Colors.white,
            foreground: OnboardingColors.blue,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}