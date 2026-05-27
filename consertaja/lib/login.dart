import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ================= TELA: LOGIN =================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
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
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 18,
            color: Color(0xFF00A2FF),
          ),
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

              // Imagem Central
              Image.asset(
                'assets/images/login_img.png',
                height: 150, // Altura ajustada para o tamanho ideal em tela
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),

              // Inputs de Email e Senha
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

              const SizedBox(height: 15),

              // Botão Entrar
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    // Lógica para realizar o Login
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Entrar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Rodapé de Cadastro
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Não tem uma conta? ',
                    style: TextStyle(color: Colors.black, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Retorna para escolher a conta
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

// ================= COMPONENTE DE INPUT CUSTOMIZADO E ANIMADO REUTILIZADO =================
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
    if (mounted) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  void _handleTextChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _effectiveController.removeListener(_handleTextChange);
    _localFocusNode?.dispose();
    _localController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool shouldFloat = _isFocused || _effectiveController.text.isNotEmpty;

    IconData? dynamicIcon = widget.suffixIcon;
    if (widget.obscureText &&
        (widget.suffixIcon == Icons.visibility_outlined ||
            widget.suffixIcon == Icons.visibility)) {
      dynamicIcon = _obscureActive
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined;
    }

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
                  ? const Color(0xFF00A2FF).withOpacity(0.08)
                  : Colors.black.withOpacity(0.015),
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
                                      : const Color(0xFF00A2FF)
                                          .withOpacity(0.5)),
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
                          color: const Color(0xFF00A2FF).withOpacity(0.4),
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
            if (dynamicIcon != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: widget.onSuffixIconTap ??
                    (widget.obscureText
                        ? () => setState(() => _obscureActive = !_obscureActive)
                        : widget.onTap),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: _isFocused ? 1.05 : 1.0,
                  child: Icon(
                    dynamicIcon,
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