import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Importação do Google adicionada
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tela_home.dart';
import 'tela_home_profissional.dart';
import 'esqueci_senha.dart';
import 'services/auth_navigation.dart';

// ================= TELA: LOGIN =================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    if (_emailController.text.isEmpty || _senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha email e senha para entrar.')),
      );
      return;
    }

    setState(() => _carregando = true);

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );

      if (response.user != null) {
        if (mounted) {
          // Verificar se o usuário é um profissional
          final supabase = Supabase.instance.client;
          final usuarioResponse = await supabase
              .from('usuarios')
              .select('tipo_conta')
              .eq('auth_id', response.user!.id)
              .maybeSingle();

          final isProfissional = usuarioResponse?['tipo_conta'] == 'Profissional';

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => isProfissional
                    ? TelaHomeProfissional(isVisitante: false)
                    : TelaHome(isVisitante: false),
              ),
              (route) => false,
            );
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String mensagem = 'Email ou senha incorretos.';
        if (e.message.contains('Email not confirmed')) {
          mensagem = 'Confirme seu email antes de fazer login.';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagem)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao fazer login: $e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  // ================= FLUXO DE LOGIN COM O GOOGLE =================
  Future<void> _fazerLoginComGoogle() async {
    setState(() => _carregando = true);

    try {
      final supabase = Supabase.instance.client;

      // LEMBRETE: Cole o seu Client ID da Web aqui dentro
      const webClientId =
          '558968043989-4od8kobfna5a0art52usjpo7sjk8joao.apps.googleusercontent.com';

      // Na web, usa apenas clientId (serverClientId não é suportado na web)
      final googleSignIn = GoogleSignIn(
        clientId: webClientId,
      );
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _carregando = false);
        return; // Usuário cancelou o login
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        throw 'Não foi possível obter o ID Token do Google.';
      }

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      // Salva a foto nos metadados do Supabase para uso posterior
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        final metadataAtual = currentUser.userMetadata ?? {};
        final nome = googleUser.displayName;
        final foto = googleUser.photoUrl;

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
          } catch (_) {}
        }
      }

      if (mounted) {
        // Captura a foto do Google
        final fotoUrlGoogle = googleUser.photoUrl;
        
        // Verificar se o usuário é um profissional
        final supabase = Supabase.instance.client;
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null) {
          final usuarioResponse = await supabase
              .from('usuarios')
              .select('tipo_conta')
              .eq('auth_id', currentUser.id)
              .maybeSingle();

          final isProfissional = usuarioResponse?['tipo_conta'] == 'Profissional';

          if (mounted) {
            if (isProfissional) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => TelaHomeProfissional(isVisitante: false)),
                (route) => false,
              );
            } else if (usuarioResponse == null) {
              // Usuário não tem perfil, redireciona para escolher tipo de conta
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => TelaEscolhaContaCompletar(
                    authId: currentUser.id,
                    emailGoogle: currentUser.email ?? '',
                    nomeGoogle: googleUser.displayName,
                    fotoUrlGoogle: fotoUrlGoogle,
                  ),
                ),
                (route) => false,
              );
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => TelaHome(isVisitante: false)),
                (route) => false,
              );
            }
          }
        } else {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => TelaHome(isVisitante: false)),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao entrar com Google: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: Image.asset('assets/images/google_logo.png', height: 22),
          label: const Text(
            'Voltar',
            style: TextStyle(color: Color(0xFF00A2FF), fontSize: 16),
          ),
        ),
      ),
      body: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1.0 - value)),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 15),
              const Text(
                'Acesso à conta',
                style: TextStyle(
                  color: Color(0xFF00A2FF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),

              Image.asset(
                'assets/images/login_img.png',
                height: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),

              _InputFieldWithAnimation(
                label: 'Email',
                hint: 'exemplo@email.com',
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
              ),

              _InputFieldWithAnimation(
                label: 'Senha',
                hint: 'Digite sua senha',
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                suffixIcon: Icons.visibility_outlined,
                controller: _senhaController,
              ),

              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EsqueciSenhaPage(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00A2FF),
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Esqueceu a senha?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // BOTÃO ENTRAR ORIGINAL
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _carregando ? null : _fazerLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2FF),
                    disabledBackgroundColor: const Color(
                      0xFF00A2FF,
                    ).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: _carregando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Entrar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // SEPARADOR VISUAL "ou"
              Row(
                children: [
                  Expanded(
                    child: Divider(color: Colors.grey.shade300, thickness: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'ou',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: Colors.grey.shade300, thickness: 1),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // BOTÃO DO GOOGLE PERSONALIZADO ADICIONADO
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: _carregando ? null : _fazerLoginComGoogle,
                  icon: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                    height: 22,
                  ),
                  label: const Text(
                    'Entrar com o Google',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    elevation: 0,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Não tem uma conta? ',
                    style: TextStyle(color: Colors.black, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Cadastre-se.',
                      style: TextStyle(
                        color: Color(0xFF00A2FF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= COMPONENTE DE INPUT ORIGINAL INTACTO =================
class _InputFieldWithAnimation extends StatefulWidget {
  final String label;
  final String hint;
  final IconData? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final VoidCallback? onTap;
  final VoidCallback? onSuffixIconTap;

  const _InputFieldWithAnimation({
    required this.label,
    required this.hint,
    this.suffixIcon,
    this.inputFormatters,
    this.keyboardType,
    this.obscureText = false,
    this.controller,
    this.focusNode,
    this.readOnly = false,
    this.onTap,
    this.onSuffixIconTap,
  });

  @override
  State<_InputFieldWithAnimation> createState() =>
      _InputFieldWithAnimationState();
}

class _InputFieldWithAnimationState extends State<_InputFieldWithAnimation> {
  FocusNode? _localFocusNode;
  TextEditingController? _localController;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_localFocusNode ??= FocusNode());
  TextEditingController get _effectiveController =>
      widget.controller ?? (_localController ??= TextEditingController());

  bool _isFocused = false;
  late bool _obscureActive;

  @override
  void initState() {
    super.initState();
    _obscureActive = widget.obscureText;
    _effectiveFocusNode.addListener(_handleFocusChange);
    _effectiveController.addListener(_handleTextChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() => _isFocused = _effectiveFocusNode.hasFocus);
  }

  void _handleTextChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _effectiveController.removeListener(_handleTextChange);
    _localFocusNode?.dispose();
    _localController?.dispose();
    super.dispose();
  }

  IconData? get _dynamicIcon {
    if (widget.obscureText &&
        (widget.suffixIcon == Icons.visibility_outlined ||
            widget.suffixIcon == Icons.visibility)) {
      return _obscureActive
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined;
    }
    return widget.suffixIcon;
  }

  @override
  Widget build(BuildContext context) {
    final bool shouldFloat = _isFocused || _effectiveController.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        height: 56,
        decoration: BoxDecoration(
          color: _isFocused ? Colors.white : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFocused ? const Color(0xFF00A2FF) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isFocused
                  ? const Color(0xFF00A2FF).withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.015),
              blurRadius: _isFocused ? 8 : 4,
              offset: _isFocused ? const Offset(0, 4) : const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    left: 0,
                    right: 0,
                    top: shouldFloat ? 6 : 17,
                    child: IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              color: _isFocused
                                  ? const Color(0xFF00A2FF)
                                  : (shouldFloat
                                        ? Colors.grey.shade600
                                        : const Color(
                                            0xFF00A2FF,
                                          ).withValues(alpha: 0.5)),
                              fontSize: shouldFloat ? 11 : 16,
                              fontWeight: shouldFloat
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                            child: Text(widget.label),
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: shouldFloat ? 1.0 : 0.0,
                            child: const Text(
                              '*',
                              style: TextStyle(
                                color: Color(0xFF00A2FF),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    left: 0,
                    right: 0,
                    bottom: shouldFloat ? 4 : 0,
                    top: shouldFloat ? 22 : 0,
                    child: TextField(
                      controller: _effectiveController,
                      focusNode: _effectiveFocusNode,
                      inputFormatters: widget.inputFormatters,
                      keyboardType: widget.keyboardType,
                      obscureText: _obscureActive,
                      readOnly: widget.readOnly,
                      onTap: widget.onTap,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: shouldFloat ? widget.hint : '',
                        hintStyle: TextStyle(
                          color: const Color(0xFF00A2FF).withValues(alpha: 0.4),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: shouldFloat
                            ? EdgeInsets.zero
                            : const EdgeInsets.only(top: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_dynamicIcon != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap:
                    widget.onSuffixIconTap ??
                    (widget.obscureText
                        ? () => setState(() => _obscureActive = !_obscureActive)
                        : widget.onTap),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: _isFocused ? 1.05 : 1.0,
                  child: Icon(
                    _dynamicIcon,
                    color: _isFocused
                        ? const Color(0xFF00A2FF)
                        : Colors.grey.shade400,
                    size: 22,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
