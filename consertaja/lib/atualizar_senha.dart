import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'onboarding/onboarding_theme.dart';
import 'onboarding/onboarding_widgets.dart';
import 'services/validacao_senha.dart';
import 'tela_inicial.dart' show abrirEntradaVisitante;
import 'widgets/imagem_app.dart';

/// Tela aberta pelo link de "Esqueci minha senha" (evento passwordRecovery).
/// Mesmo visual do onboarding e, no fim, volta para o login do onboarding.
class AtualizarSenhaPage extends StatefulWidget {
  const AtualizarSenhaPage({super.key});

  @override
  State<AtualizarSenhaPage> createState() => _AtualizarSenhaPageState();
}

class _AtualizarSenhaPageState extends State<AtualizarSenhaPage> {
  final TextEditingController _senha = TextEditingController();
  final TextEditingController _confirmar = TextEditingController();

  bool _carregando = false;
  bool _senhaOculta = true;
  bool _confirmarOculta = true;
  String? _erroSenha;
  String? _erroConfirmar;

  String get _texto => _senha.text;
  bool get _temTamanho => senhaTemOitoCaracteres(_texto);
  bool get _temMaiuscula => senhaTemMaiuscula(_texto);
  bool get _temMinuscula => senhaTemMinuscula(_texto);
  bool get _temNumero => senhaTemNumero(_texto);
  bool get _temSimbolo => senhaTemSimbolo(_texto);
  bool get _requisitosOk =>
      _temTamanho && _temMaiuscula && _temMinuscula && _temNumero && _temSimbolo;

  @override
  void initState() {
    super.initState();
    _senha.addListener(_mudou);
    _confirmar.addListener(_mudou);
  }

  void _mudou() {
    if (!mounted) return;
    setState(() {
      _erroSenha = null;
      _erroConfirmar = null;
    });
  }

  @override
  void dispose() {
    _senha.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  /// Sai da sessão temporária de recuperação e abre o login do onboarding.
  Future<void> _irParaLogin({String? aviso}) async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    final mensageiro = ScaffoldMessenger.maybeOf(context);
    abrirEntradaVisitante(context, login: true);
    if (aviso != null) {
      mensageiro?.showSnackBar(SnackBar(content: Text(aviso)));
    }
  }

  Future<void> _salvar() async {
    if (_carregando) return;
    if (!_requisitosOk) {
      setState(
        () => _erroSenha = 'A senha ainda não cumpre todos os requisitos.',
      );
      return;
    }
    if (_senha.text != _confirmar.text) {
      setState(() => _erroConfirmar = 'As senhas digitadas não coincidem.');
      return;
    }

    setState(() => _carregando = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _senha.text),
      );
      await _irParaLogin(
        aviso: 'Senha atualizada! Entre com a sua nova senha.',
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (!mounted) return;
      setState(() {
        if (e.code == 'same_password' || msg.contains('different from')) {
          _erroSenha = 'A nova senha não pode ser igual à senha atual.';
        } else if (e.code == 'weak_password' || msg.contains('weak')) {
          _erroSenha = 'Essa senha é fraca demais. Tente outra.';
        } else if (msg.contains('session') || msg.contains('jwt')) {
          _erroSenha =
              'O link de recuperação expirou. Peça um novo em "Esqueci minha senha".';
        } else {
          _erroSenha = 'Não foi possível salvar: ${e.message}';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _erroSenha = 'Não foi possível salvar. Tente de novo.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_carregando) _irParaLogin();
      },
      child: Scaffold(
        backgroundColor: OnboardingColors.blue,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: _carregando ? null : () => _irParaLogin(),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ImagemApp(
                      child: Image.asset(
                        CaixaAssets.normal,
                        width: 130,
                        height: 130,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Criar nova senha',
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
                      'Escolha uma senha nova para a sua conta. '
                      'Ela precisa ser diferente da anterior.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 26),
                    OnboardingWhiteField(
                      label: 'Nova senha',
                      controller: _senha,
                      obscure: _senhaOculta,
                      keyboardType: TextInputType.visiblePassword,
                      errorText: _erroSenha,
                      suffixIcon: _senhaOculta
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      onSuffix: () =>
                          setState(() => _senhaOculta = !_senhaOculta),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
                      child: Column(
                        children: [
                          PasswordRequirementItem(
                            text: 'No mínimo 12 caracteres',
                            valid: _temTamanho,
                          ),
                          PasswordRequirementItem(
                            text: 'Pelo menos 1 letra maiúscula',
                            valid: _temMaiuscula,
                          ),
                          PasswordRequirementItem(
                            text: 'Pelo menos 1 letra minúscula',
                            valid: _temMinuscula,
                          ),
                          PasswordRequirementItem(
                            text: 'Pelo menos 1 número',
                            valid: _temNumero,
                          ),
                          PasswordRequirementItem(
                            text: 'Pelo menos 1 caractere especial',
                            valid: _temSimbolo,
                          ),
                        ],
                      ),
                    ),
                    OnboardingWhiteField(
                      label: 'Confirmar nova senha',
                      controller: _confirmar,
                      obscure: _confirmarOculta,
                      keyboardType: TextInputType.visiblePassword,
                      errorText: _erroConfirmar,
                      suffixIcon: _confirmarOculta
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      onSuffix: () =>
                          setState(() => _confirmarOculta = !_confirmarOculta),
                    ),
                    const SizedBox(height: 12),
                    PillButton(
                      label: 'Salvar senha',
                      background: Colors.white,
                      foreground: OnboardingColors.blue,
                      loading: _carregando,
                      bloqueado:
                          !_requisitosOk || _confirmar.text.isEmpty,
                      onTap: _salvar,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
