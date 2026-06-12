import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';

class AtualizarSenhaPage extends StatefulWidget {
  const AtualizarSenhaPage({super.key});

  @override
  State<AtualizarSenhaPage> createState() => _AtualizarSenhaPageState();
}

class _AtualizarSenhaPageState extends State<AtualizarSenhaPage> {
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();

  bool _carregando = false;
  String? _erroSenha;
  String? _erroConfirmarSenha;

  // Getters para verificar os requisitos em tempo real idênticos ao Cadastro
  bool get _temOitoCaracteres => _senhaController.text.length >= 8;
  bool get _temMaiuscula => _senhaController.text.contains(RegExp(r'[A-Z]'));
  bool get _temMinuscula => _senhaController.text.contains(RegExp(r'[a-z]'));
  bool get _temSimbolo => _senhaController.text.contains(RegExp(r'[^A-Za-z0-9\s]'));
  bool get _temNumero => _senhaController.text.contains(RegExp(r'[0-9]'));

  @override
  void initState() {
    super.initState();
    // Escuta os controllers para limpar mensagens de erro e atualizar requisitos
    _senhaController.addListener(_atualizarInterface);
    _confirmarSenhaController.addListener(_atualizarInterface);
  }

  void _atualizarInterface() {
    if (mounted) {
      setState(() {
        if (_senhaController.text.isNotEmpty && _erroSenha != null) {
          _erroSenha = null;
        }
        if (_confirmarSenhaController.text.isNotEmpty && _erroConfirmarSenha != null) {
          _erroConfirmarSenha = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _senhaController.removeListener(_atualizarInterface);
    _confirmarSenhaController.removeListener(_atualizarInterface);
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _atualizarSenha() async {
    // Limpa erros anteriores antes de validar
    setState(() {
      _erroSenha = null;
      _erroConfirmarSenha = null;
    });
    
    if (!_temOitoCaracteres || !_temMaiuscula || !_temMinuscula || !_temSimbolo || !_temNumero) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os requisitos de segurança.')),
      );
      return;
    }

    if (_senhaController.text != _confirmarSenhaController.text) {
      setState(() {
        _erroConfirmarSenha = 'As senhas digitadas não coincidem.';
      });
      return;
    }

    setState(() => _carregando = true);

    try {
      final supabase = Supabase.instance.client;
      
      // 1. Pega o e-mail do usuário logado na sessão temporária de recuperação
      final emailUsuario = supabase.auth.currentUser?.email;

      if (emailUsuario != null) {
        bool ehAMesmaSenha = false;
        
        try {
          // 2. TESTE DE SEGURANÇA: Tenta logar usando a NOVA senha digitada
          await supabase.auth.signInWithPassword(
            email: emailUsuario,
            password: _senhaController.text.trim(),
          );
          // Se o login funcionou sem disparar erro, significa que a senha nova é IGUAL à atual!
          ehAMesmaSenha = true;
        } catch (_) {
          // Se caiu no catch, o login falhou. Ótimo! Significa que a senha digitada é diferente da atual.
        }

        // 3. Se o teste deu positivo para senha igual, barra aqui!
        if (ehAMesmaSenha) {
          setState(() {
            _erroSenha = 'A nova senha não pode ser igual à senha atual.';
          });
          setState(() => _carregando = false);
          return; // Para a execução do código aqui
        }
      }

      // 4. Se a senha for realmente inédita, atualiza no Supabase de verdade
      await supabase.auth.updateUser(
        UserAttributes(password: _senhaController.text.trim()),
      );

      // 5. Desloga para limpar os tokens temporários
      await supabase.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Senha atualizada com sucesso! Faça login.')),
        );
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar senha: ${e.toString()}')),
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
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF00A2FF)),
          label: const Text('Voltar', style: TextStyle(color: Color(0xFF00A2FF), fontSize: 16)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 15),
            const Text(
              'Criar Nova Senha',
              style: TextStyle(
                color: Color(0xFF00A2FF),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 35),

            // INPUT DA NOVA SENHA (Usando o componente idêntico)
            InputFieldWithAnimation(
              label: 'Nova Senha',
              hint: 'Digite sua nova senha',
              keyboardType: TextInputType.visiblePassword,
              obscureText: true,
              suffixIcon: Icons.visibility_outlined,
              controller: _senhaController,
              errorText: _erroSenha,
            ),

            // LISTA DE REQUISITOS DINÂMICOS
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequisitoItem('No mínimo 8 caracteres', _temOitoCaracteres),
                  _buildRequisitoItem('Pelo menos 1 letra maiúscula', _temMaiuscula),
                  _buildRequisitoItem('Pelo menos 1 letra minúscula', _temMinuscula),
                  _buildRequisitoItem('Pelo menos 1 símbolo (ex: @, #, \$, %)', _temSimbolo),
                  _buildRequisitoItem('Pelo menos 1 número', _temNumero),
                ],
              ),
            ),

            // INPUT DE CONFIRMAR SENHA
            InputFieldWithAnimation(
              label: 'Confirmar nova senha',
              hint: 'Confirme sua nova senha',
              keyboardType: TextInputType.visiblePassword,
              obscureText: true,
              suffixIcon: Icons.visibility_outlined,
              controller: _confirmarSenhaController,
              errorText: _erroConfirmarSenha,
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _carregando ? null : _atualizarSenha,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: _carregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Salvar Senha',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRequisitoItem(String texto, bool valido) {
    final cor = valido ? const Color(0xFF00A2FF) : Colors.grey.shade400;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.check, size: 16, color: cor),
          const SizedBox(width: 8),
          Text(
            texto,
            style: TextStyle(
              color: cor,
              fontSize: 13,
              fontWeight: valido ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ================= COMPONENTE DE INPUT EXPORTADO DO SEU CADASTRO =================
class InputFieldWithAnimation extends StatefulWidget {
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
  final String? errorText;

  const InputFieldWithAnimation({
    super.key,
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
    this.errorText,
  });

  @override
  State<InputFieldWithAnimation> createState() => _InputFieldWithAnimationState();
}

class _InputFieldWithAnimationState extends State<InputFieldWithAnimation> {
  FocusNode? _localFocusNode;
  TextEditingController? _localController;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? (_localFocusNode ??= FocusNode());
  TextEditingController get _effectiveController => widget.controller ?? (_localController ??= TextEditingController());

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

  @override
  Widget build(BuildContext context) {
    final bool shouldFloat = _isFocused || _effectiveController.text.isNotEmpty;
    final bool hasError = widget.errorText != null;

    IconData? dynamicIcon = widget.suffixIcon;
    if (widget.obscureText && (widget.suffixIcon == Icons.visibility_outlined || widget.suffixIcon == Icons.visibility)) {
      dynamicIcon = _obscureActive ? Icons.visibility_outlined : Icons.visibility_off_outlined;
    }

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
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
                        top: shouldFloat ? 6 : 17,
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
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: shouldFloat ? 1.0 : 0.0,
                                child: Text(
                                  '*',
                                  style: TextStyle(
                                    color: hasError ? Colors.red : const Color(0xFF00A2FF),
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
                              color: hasError
                                  ? Colors.red.withAlpha(102)
                                  : const Color(0xFF00A2FF).withAlpha(102),
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
                        color: hasError
                            ? Colors.red
                            : (_isFocused ? const Color(0xFF00A2FF) : Colors.grey.shade400),
                        size: 22,
                      ),
                    ),
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
      ),
    );
  }
}