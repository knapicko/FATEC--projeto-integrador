import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

      // 1. INVERTE A BUSCA: Procura direto na tabela de e-mails
      // AJUSTE AQUI: Se a sua tabela de e-mails não se chamar 'emails', mude o nome abaixo
      final respostaContagem = await supabase
          .from('emails') 
          .select('endereco_email') 
          .eq('endereco_email', email)
          .count(CountOption.exact); // Conta quantas vezes esse e-mail exato aparece

      final int quantidadeEncontrada = respostaContagem.count;

      // 2. Se a contagem for igual a 0, o e-mail não existe no sistema
      if (quantidadeEncontrada == 0) {
        setState(() {
          _erroEmail = 'Este e-mail não está cadastrado no ConsertaJá.';
        });
        setState(() => _enviando = false);
        return; // Bloqueia o envio do e-mail de recuperação
      }

      // 3. Se passou pela checagem, o e-mail existe! Dispara o reset normal
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'consertaja://reset-password',
      );

      if (mounted) {
        setState(() {
          _emailEnviado = true; // Ativa a tela de sucesso com o Icone.png
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar solicitação: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
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
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF00A2FF)),
          label: const Text('Voltar', style: TextStyle(color: Color(0xFF00A2FF), fontSize: 16)),
        ),
      ),
      body: _emailEnviado ? _buildTelaSucesso() : _buildFormularioEmail(),
    );
  }

  // input do email
  Widget _buildFormularioEmail() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Recuperar Senha',
            style: TextStyle(
              color: Color(0xFF00A2FF),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Informe seu e-mail para continuar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 40),
          InputFieldWithAnimation(
            label: 'E-mail',
            hint: 'Digite seu e-mail',
            keyboardType: TextInputType.emailAddress,
            suffixIcon: null,
            controller: _emailController,
            errorText: _erroEmail,
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _enviando ? null : _enviarEmailRecuperacao,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A2FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: _enviando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Enviar Link',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // tela de sucesso
Widget _buildTelaSucesso() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/check.png',
              height: 110,
              width: 110,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 35),
            const Text(
              'Enviamos um link para o e-mail informado',
              style: TextStyle(
                color: Color(0xFF00A2FF),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  height: 1.5,
                ),
                children: const [
                  TextSpan(text: 'Confira na sua caixa de entrada,'),
                  TextSpan(
                    text: ' caso não encontre o  e-mail olhe na caixa de spam.',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 45),
            // Botão para voltar ao login
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Voltar para o Login',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//input
class InputFieldWithAnimation extends StatefulWidget {
  final String label;
  final String hint;
  final IconData? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextEditingController? controller;
  final String? errorText;

  const InputFieldWithAnimation({
    super.key,
    required this.label,
    required this.hint,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.controller,
    this.errorText,
  });

  @override
  State<InputFieldWithAnimation> createState() => _InputFieldWithAnimationState();
}

class _InputFieldWithAnimationState extends State<InputFieldWithAnimation> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  late bool _obscureActive;

  @override
  void initState() {
    super.initState();
    _obscureActive = widget.obscureText;
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
    widget.controller?.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool shouldFloat = _isFocused || (widget.controller?.text.isNotEmpty ?? false);
    final bool hasError = widget.errorText != null;

    Color borderColor = Colors.transparent;
    Color labelColor = const Color(0xFF00A2FF).withAlpha(128);
    Color backgroundColor = const Color(0xFFFAFAFA);

    if (hasError) {
      borderColor = Colors.red;
      labelColor = Colors.red;
      backgroundColor = Colors.red.withAlpha(5);
    } else if (_isFocused) {
      borderColor = const Color(0xFF00A2FF);
      labelColor = const Color(0xFF00A2FF);
      backgroundColor = Colors.white;
    } else if (shouldFloat) {
      labelColor = Colors.grey.shade600;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _isFocused
                    ? const Color(0xFF00A2FF).withAlpha(20)
                    : Colors.black.withAlpha(4),
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
                      top: shouldFloat ? 4 : 17,
                      child: IgnorePointer(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                color: labelColor,
                                fontSize: shouldFloat ? 11 : 16,
                                fontWeight: shouldFloat ? FontWeight.bold : FontWeight.w500,
                              ),
                              child: Text(widget.label),
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
                      bottom: shouldFloat ? 2 : 0,
                      top: shouldFloat ? 24 : 0,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        keyboardType: widget.keyboardType,
                        obscureText: _obscureActive,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: shouldFloat ? widget.hint : '',
                          hintStyle: TextStyle(
                            color: const Color(0xFF00A2FF).withAlpha(102),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: shouldFloat ? EdgeInsets.zero : const EdgeInsets.only(top: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.suffixIcon != null) ...[
                const SizedBox(width: 12),
                Icon(
                  widget.suffixIcon,
                  color: hasError
                      ? Colors.red
                      : (_isFocused ? const Color(0xFF00A2FF) : Colors.grey.shade400),
                  size: 22,
                ),
              ],
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Text(
              widget.errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}