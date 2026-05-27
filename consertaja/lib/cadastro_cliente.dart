import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'login.dart';

// ================= TELA: CADASTRO DO CLIENTE (ETAPA 1) =================
class CadastroClientePage extends StatefulWidget {
  const CadastroClientePage({super.key});

  @override
  State<CadastroClientePage> createState() => _CadastroClientePageState();
}

class _CadastroClientePageState extends State<CadastroClientePage> {
  final TextEditingController _dataNascimentoController =
      TextEditingController();

  @override
  void dispose() {
    _dataNascimentoController.dispose();
    super.dispose();
  }

  // Função para abrir o calendário nativo customizado com a cor do tema
  Future<void> _fazerUploadDataNascimento() async {
    DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 18),
      ), // Padrão maior de idade
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00A2FF),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (dataSelecionada != null) {
      String dia = dataSelecionada.day.toString().padLeft(2, '0');
      String mes = dataSelecionada.month.toString().padLeft(2, '0');
      String ano = dataSelecionada.year.toString();

      setState(() {
        _dataNascimentoController.text = '$dia / $mes / $ano';
      });
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
                'Criar conta - Cliente',
                style: TextStyle(
                  color: Color(0xFF00A2FF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),

              // Indicador de Etapas (Apenas 2 etapas conforme o design do cliente)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStepCircle('1', isActive: true),
                  _buildStepLine(),
                  _buildStepCircle('2', isActive: false),
                ],
              ),
              const SizedBox(height: 35),

              // FORMULÁRIO EXATAMENTE IGUAL AO DESIGN ANEXADO
              const _InputFieldWithAnimation(
                label: 'Nome completo',
                hint: 'Nome completo',
                keyboardType: TextInputType.name,
              ),
              _InputFieldWithAnimation(
                label: 'CPF',
                hint: '___.___.___-__',
                keyboardType: TextInputType.number,
                inputFormatters: [MaskedInputFormatter('###.###.###-##')],
              ),
              const _InputFieldWithAnimation(
                label: 'Email',
                hint: 'exemplo@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              _InputFieldWithAnimation(
                label: 'Telefone',
                hint: '(__) _____-____',
                keyboardType: TextInputType.phone,
                inputFormatters: [MaskedInputFormatter('(##) #####-####')],
              ),
              _InputFieldWithAnimation(
                label: 'Data de Nascimento',
                hint: 'DD / MM / AAAA',
                suffixIcon: Icons.calendar_month,
                controller: _dataNascimentoController,
                readOnly:
                    true, // Evita digitação inadequada abrindo o modal nativo
                onTap: _fazerUploadDataNascimento,
                onSuffixIconTap: _fazerUploadDataNascimento,
              ),

              const SizedBox(height: 40),

              // Botão Continuar
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CadastroClienteEtapa2Page(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Rodapé de Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Já tem uma conta? ',
                    style: TextStyle(color: Colors.black, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Faça login.',
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

  Widget _buildStepCircle(String step, {required bool isActive}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF00A2FF) : const Color(0xFFEFEFEF),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          step,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade400,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine() {
    return Container(width: 40, height: 4, color: const Color(0xFFEFEFEF));
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
                                        : const Color(
                                            0xFF00A2FF,
                                          ).withOpacity(0.5)),
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
                onTap:
                    widget.onSuffixIconTap ??
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

// Formatador de máscara customizado
class MaskedInputFormatter extends TextInputFormatter {
  final String mask;

  MaskedInputFormatter(this.mask);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final digits = text.replaceAll(RegExp(r'\D'), '');

    var formatted = '';
    var digitIndex = 0;
    for (var i = 0; i < mask.length; i++) {
      if (digitIndex >= digits.length) break;
      if (mask[i] == '#') {
        formatted += digits[digitIndex];
        digitIndex++;
      } else {
        formatted += mask[i];
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ================= TELA: CADASTRO DO CLIENTE (ETAPA 2) =================
class CadastroClienteEtapa2Page extends StatefulWidget {
  const CadastroClienteEtapa2Page({super.key});

  @override
  State<CadastroClienteEtapa2Page> createState() =>
      _CadastroClienteEtapa2PageState();
}

class _CadastroClienteEtapa2PageState extends State<CadastroClienteEtapa2Page> {
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =
      TextEditingController();

  // Estados dos quadrados de seleção (afirmação)
  bool _aceitouTermos = false;
  bool _aceitouPrivacidade = false;

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
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
                'Criar conta - Cliente',
                style: TextStyle(
                  color: Color(0xFF00A2FF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),

              // Indicador de Etapas (Etapa 2 Ativa)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStepCircle('1', isActive: false),
                  _buildStepLine(),
                  _buildStepCircle('2', isActive: true),
                ],
              ),
              const SizedBox(height: 35),

              // FORMULÁRIO DE SENHAS
              _InputFieldWithAnimation(
                label: 'Senha',
                hint: 'Digite sua senha',
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                suffixIcon: Icons.visibility_outlined,
                controller: _senhaController,
              ),
              _InputFieldWithAnimation(
                label: 'Confirmar senha',
                hint: 'Confirme sua senha',
                keyboardType: TextInputType.visiblePassword,
                obscureText: true,
                suffixIcon: Icons.visibility_outlined,
                controller: _confirmarSenhaController,
              ),

              const SizedBox(height: 5),

              // SEÇÃO DOS QUADRADOS DE SELEÇÃO (TERMOS E PRIVACIDADE)
              Column(
                children: [
                  _buildCheckboxRow(
                    fullText: 'Li e aceito os Termos de Uso',
                    highlightText: 'Termos de Uso',
                    value: _aceitouTermos,
                    onTapCheckbox: () {
                      setState(() {
                        _aceitouTermos = !_aceitouTermos;
                      });
                    },
                    onTapLink: () {
                      // Ação ao clicar APENAS em "Termos de Uso"
                      // Ex: Abrir uma nova tela ou modal com o texto dos termos
                      print('Abrir Termos de Uso');
                    },
                  ),
                  const SizedBox(height: 14),
                  _buildCheckboxRow(
                    fullText: 'Li e aceito a Política de Privacidade',
                    highlightText: 'Política de Privacidade',
                    value: _aceitouPrivacidade,
                    onTapCheckbox: () {
                      setState(() {
                        _aceitouPrivacidade = !_aceitouPrivacidade;
                      });
                    },
                    onTapLink: () {
                      // Ação ao clicar APENAS em "Política de Privacidade"
                      print('Abrir Política de Privacidade');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 35),

              // Botão Finalizar Cadastro
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: (_aceitouTermos && _aceitouPrivacidade)
                      ? () {
                          // Ação futura para finalizar o cadastro
                        }
                      : null, // Desabilita o botão se não aceitar ambos
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2FF),
                    disabledBackgroundColor: const Color(
                      0xFF00A2FF,
                    ).withOpacity(0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Finalizar Cadastro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Rodapé de Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Já tem uma conta? ',
                    style: TextStyle(color: Colors.black, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Ação de Login
                    },
                    child: const Text(
                      'Faça login.',
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

  // Widget construtor das linhas de seleção customizadas
  Widget _buildCheckboxRow({
    required String
    fullText, // Texto completo, ex: "Li e aceito os Termos de Uso"
    required String highlightText, // Texto a ser destacado, ex: "Termos de Uso"
    required bool value,
    required VoidCallback onTapCheckbox, // Clique no quadrado
    required VoidCallback onTapLink, // Clique específico no texto destacado
  }) {
    // Divide o texto para separar o que vem antes do termo destacado
    final int targetIndex = fullText.indexOf(highlightText);
    final String prefixText = targetIndex != -1
        ? fullText.substring(0, targetIndex)
        : fullText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Quadrado de Seleção Animado
        GestureDetector(
          onTap: onTapCheckbox,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? const Color(0xFF00A2FF) : const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? const Color(0xFF00A2FF) : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            child: value
                ? const Icon(Icons.check, color: Colors.white, size: 15)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        // Texto com trecho destacado em outra cor
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Roboto', // Ou a fonte padrão do seu app
              ),
              children: [
                TextSpan(text: prefixText),
                TextSpan(
                  text: highlightText,
                  style: const TextStyle(
                    color: Color(0xFF00A2FF), // Cor azul do seu tema
                    fontWeight: FontWeight.bold,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = onTapLink,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepCircle(String step, {required bool isActive}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF00A2FF) : const Color(0xFFEFEFEF),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          step,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade400,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStepLine() {
    return Container(width: 40, height: 4, color: const Color(0xFFEFEFEF));
  }
}

// Nota: O componente `_InputFieldWithAnimation` e o `MaskedInputFormatter` 
// permanecem idênticos aos que você já possui no seu arquivo original.