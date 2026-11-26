import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'onboarding/onboarding_theme.dart';
import 'onboarding/onboarding_widgets.dart';
import 'services/biometria_service.dart';
import 'services/requisitos_conta.dart';
import 'services/validacao_senha.dart';
import 'tela_inicial.dart' show abrirEntradaVisitante;
import 'widgets/imagem_app.dart';

/// Tela de senha com o visual do onboarding. Dois usos:
///
/// - [recuperacao] = true: aberta pelo link de "Esqueci minha senha"
///   (evento passwordRecovery). Ao salvar, sai da sessão temporária e volta
///   para o login do onboarding.
/// - [recuperacao] = false: pessoa logada alterando a senha (Editar dados,
///   Configurações) ou CRIANDO uma senha (conta feita com o Google). Pede a
///   senha atual quando a conta já tem uma; ao salvar, volta com `true`.
class AtualizarSenhaPage extends StatefulWidget {
  const AtualizarSenhaPage({super.key, this.recuperacao = true});

  final bool recuperacao;

  @override
  State<AtualizarSenhaPage> createState() => _AtualizarSenhaPageState();
}

class _AtualizarSenhaPageState extends State<AtualizarSenhaPage> {
  final TextEditingController _atual = TextEditingController();
  final TextEditingController _senha = TextEditingController();
  final TextEditingController _confirmar = TextEditingController();

  bool _carregando = false;
  bool _atualOculta = true;
  bool _senhaOculta = true;
  bool _confirmarOculta = true;
  String? _erroAtual;
  String? _erroSenha;
  String? _erroConfirmar;

  /// Conta criada com o Google ainda sem senha: é "criar", não "alterar".
  late final bool _criando =
      !widget.recuperacao && !RequisitosConta.contaTemSenha();
  bool get _pedeAtual => !widget.recuperacao && !_criando;

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
    _atual.addListener(_mudou);
    _senha.addListener(_mudou);
    _confirmar.addListener(_mudou);
  }

  void _mudou() {
    if (!mounted) return;
    setState(() {
      _erroAtual = null;
      _erroSenha = null;
      _erroConfirmar = null;
    });
  }

  @override
  void dispose() {
    _atual.dispose();
    _senha.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  /// Recuperação: sai da sessão temporária e abre o login do onboarding.
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

  void _voltar() {
    if (_carregando) return;
    if (widget.recuperacao) {
      _irParaLogin();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _salvar() async {
    if (_carregando) return;
    if (_pedeAtual && _atual.text.isEmpty) {
      setState(() => _erroAtual = 'Digite a sua senha atual.');
      return;
    }
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
    if (_pedeAtual && _atual.text == _senha.text) {
      setState(
        () => _erroSenha = 'A nova senha não pode ser igual à senha atual.',
      );
      return;
    }

    setState(() => _carregando = true);
    final auth = Supabase.instance.client.auth;
    try {
      // Confere a senha atual (quem está logado e já tem senha).
      if (_pedeAtual) {
        final email = auth.currentUser?.email;
        if (email == null || email.isEmpty) {
          throw const AuthException('sem e-mail');
        }
        try {
          await auth.signInWithPassword(email: email, password: _atual.text);
        } on AuthException {
          if (mounted) {
            setState(() {
              _carregando = false;
              _erroAtual = 'Senha atual incorreta.';
            });
          }
          return;
        }
      }

      await auth.updateUser(
        UserAttributes(
          password: _senha.text,
          // Marca a conta como "tem senha" (contas do Google).
          data: {'senha_definida': true},
        ),
      );

      if (widget.recuperacao) {
        await _irParaLogin(
          aviso: 'Senha atualizada! Entre com a sua nova senha.',
        );
        return;
      }

      // Biometria guardada para esta conta: atualiza a senha do cofre.
      final user = auth.currentUser;
      if (user != null &&
          await BiometriaService.contaGuardada() == user.id) {
        final cred = await BiometriaService.credenciais();
        await BiometriaService.salvar(
          identificador: cred?.$1 ?? user.email ?? '',
          senha: _senha.text,
          authId: user.id,
          nome: await BiometriaService.nomeGuardado(),
        );
      }
      await RequisitosConta.atualizarAbaPendente(
        profissional: false,
        forcar: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            _criando
                ? 'Senha criada! Agora você também pode entrar com e-mail e senha.'
                : 'Senha alterada com sucesso!',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (!mounted) return;
      setState(() {
        if (e.code == 'same_password' || msg.contains('different from')) {
          _erroSenha = 'A nova senha não pode ser igual à senha atual.';
        } else if (e.code == 'weak_password' || msg.contains('weak')) {
          _erroSenha = 'Essa senha é fraca demais. Tente outra.';
        } else if (e.code == 'reauthentication_needed' ||
            msg.contains('reauthenticat')) {
          _erroSenha =
              'Por segurança, saia e entre de novo na conta antes de trocar a senha.';
        } else if (msg.contains('session') || msg.contains('jwt')) {
          _erroSenha = widget.recuperacao
              ? 'O link de recuperação expirou. Peça um novo em "Esqueci minha senha".'
              : 'Sua sessão expirou. Entre de novo na conta.';
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
    final titulo = widget.recuperacao
        ? 'Criar nova senha'
        : _criando
        ? 'Crie uma senha'
        : 'Alterar senha';
    final subtitulo = widget.recuperacao
        ? 'Escolha uma senha nova para a sua conta. Ela precisa ser diferente da anterior.'
        : _criando
        ? 'Sua conta foi criada com o Google. Crie uma senha para também entrar '
              'com e-mail e senha — ela é obrigatória para pedir serviços.'
        : 'Confirme a sua senha atual e escolha a nova.';
    return PopScope(
      canPop: !widget.recuperacao,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.recuperacao && !_carregando) _irParaLogin();
      },
      child: Scaffold(
        backgroundColor: OnboardingColors.blue,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: _carregando ? null : _voltar,
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
                        semanticLabel: 'Mascote do ConsertaJá, uma caixa de ferramentas sorridente',
                        width: 130,
                        height: 130,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitulo,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 26),
                    if (_pedeAtual)
                      OnboardingWhiteField(
                        label: 'Senha atual',
                        controller: _atual,
                        obscure: _atualOculta,
                        keyboardType: TextInputType.visiblePassword,
                        errorText: _erroAtual,
                        suffixIcon: _atualOculta
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        onSuffix: () =>
                            setState(() => _atualOculta = !_atualOculta),
                      ),
                    OnboardingWhiteField(
                      label: _criando ? 'Senha' : 'Nova senha',
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
                      label: _criando ? 'Confirmar senha' : 'Confirmar nova senha',
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
                      label: _criando ? 'Criar senha' : 'Salvar senha',
                      background: Colors.white,
                      foreground: OnboardingColors.blue,
                      loading: _carregando,
                      bloqueado: !_requisitosOk ||
                          _confirmar.text.isEmpty ||
                          (_pedeAtual && _atual.text.isEmpty),
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
