import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'tela_home.dart';

// ================= TELA: CADASTRO DO CLIENTE (ETAPA 1) =================
class CadastroClientePage extends StatefulWidget {
  const CadastroClientePage({super.key});

  @override
  State<CadastroClientePage> createState() => _CadastroClientePageState();
}

class _CadastroClientePageState extends State<CadastroClientePage> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _dataNascimentoController =
      TextEditingController();

  String? _erroNome;
  String? _erroCpf;
  String? _erroEmail;
  String? _erroTelefone;
  String? _erroDataNascimento;

  @override
  void initState() {
    super.initState();

    // Quando digita algo, o erro limpa e volta ao azul
    _nomeController.addListener(() {
      if (_nomeController.text.isNotEmpty && _erroNome != null) {
        setState(() => _erroNome = null);
      }
    });
    _cpfController.addListener(() {
      if (_cpfController.text.isNotEmpty && _erroCpf != null) {
        setState(() => _erroCpf = null);
      }
    });
    _emailController.addListener(() {
      if (_emailController.text.isNotEmpty && _erroEmail != null) {
        setState(() => _erroEmail = null);
      }
    });
    _telefoneController.addListener(() {
      if (_telefoneController.text.isNotEmpty && _erroTelefone != null) {
        setState(() => _erroTelefone = null);
      }
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _dataNascimentoController.dispose();
    super.dispose();
  }

  Future<void> _fazerUploadDataNascimento() async {
    DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
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
        _dataNascimentoController.text = '$ano-$mes-$dia';
        _erroDataNascimento = null;
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
      body: SingleChildScrollView(
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

            _InputFieldWithAnimation(
              label: 'Nome completo',
              hint: 'Nome completo',
              keyboardType: TextInputType.name,
              controller: _nomeController,
              errorText: _erroNome,
            ),
            _InputFieldWithAnimation(
              label: 'CPF',
              hint: '___.___.___-__',
              keyboardType: TextInputType.number,
              inputFormatters: [MaskedInputFormatter('###.###.###-##')],
              controller: _cpfController,
              errorText: _erroCpf,
            ),
            _InputFieldWithAnimation(
              label: 'Email',
              hint: 'exemplo@email.com',
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
              errorText: _erroEmail,
            ),
            _InputFieldWithAnimation(
              label: 'Telefone',
              hint: '(__) _____-____',
              keyboardType: TextInputType.phone,
              inputFormatters: [MaskedInputFormatter('(##) #####-####')],
              controller: _telefoneController,
              errorText: _erroTelefone,
            ),
            _InputFieldWithAnimation(
              label: 'Data de Nascimento',
              hint: 'DD-MM-AAAA',
              suffixIcon: Icons.calendar_month,
              controller: _dataNascimentoController,
              readOnly: true,
              onTap: _fazerUploadDataNascimento,
              onSuffixIconTap: _fazerUploadDataNascimento,
              errorText: _erroDataNascimento,
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _erroNome = _nomeController.text.trim().isEmpty
                        ? 'O nome é obrigatório'
                        : null;
                    _erroCpf = _cpfController.text.trim().isEmpty
                        ? 'O CPF é obrigatório'
                        : null;
                    _erroEmail = _emailController.text.trim().isEmpty
                        ? 'O e-mail é obrigatório'
                        : null;
                    _erroTelefone = _telefoneController.text.trim().isEmpty
                        ? 'O telefone é obrigatório'
                        : null;
                    _erroDataNascimento =
                        _dataNascimentoController.text.trim().isEmpty
                        ? 'A data de nascimento é obrigatória'
                        : null;
                  });

                  if (_erroNome != null ||
                      _erroCpf != null ||
                      _erroEmail != null ||
                      _erroTelefone != null ||
                      _erroDataNascimento != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Por favor, preencha todos os campos obrigatórios.',
                        ),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CadastroClienteEtapa2Page(
                        nome: _nomeController.text.trim(),
                        cpf: _cpfController.text.trim(),
                        email: _emailController.text.trim(),
                        telefone: _telefoneController.text.trim(),
                        dataNascimento: _dataNascimentoController.text.trim(),
                      ),
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
          ],
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

// ================= COMPONENTE DE INPUT CUSTOMIZADO E ANIMADO =================
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
  final String? errorText;

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
    this.errorText,
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

  @override
  Widget build(BuildContext context) {
    final bool shouldFloat = _isFocused || _effectiveController.text.isNotEmpty;

    final bool hasError = widget.errorText != null;

    IconData? dynamicIcon = widget.suffixIcon;
    if (widget.obscureText &&
        (widget.suffixIcon == Icons.visibility_outlined ||
            widget.suffixIcon == Icons.visibility)) {
      dynamicIcon = _obscureActive
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined;
    }

    Color borderColor = Colors.transparent;
    Color labelColor = const Color(0xFF00A2FF).withOpacity(0.5);
    Color backgroundColor = const Color(0xFFFAFAFA);

    if (hasError) {
      borderColor = Colors.red;
      labelColor = Colors.red;
      backgroundColor = Colors.red.withOpacity(0.02);
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
                                  color: labelColor,
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
                                child: Text(
                                  '*',
                                  style: TextStyle(
                                    color: hasError
                                        ? Colors.red
                                        : const Color(0xFF00A2FF),
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
                                  ? Colors.red.withOpacity(0.4)
                                  : const Color(0xFF00A2FF).withOpacity(0.4),
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
                            ? () => setState(
                                () => _obscureActive = !_obscureActive,
                              )
                            : widget.onTap),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: _isFocused ? 1.05 : 1.0,
                      child: Icon(
                        dynamicIcon,
                        color: hasError
                            ? Colors.red
                            : (_isFocused
                                  ? const Color(0xFF00A2FF)
                                  : Colors.grey.shade400),
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

// ================= MASK INPUT FORMATTER =================
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
  final String nome;
  final String cpf;
  final String email;
  final String telefone;
  final String dataNascimento;

  const CadastroClienteEtapa2Page({
    super.key,
    required this.nome,
    required this.cpf,
    required this.email,
    required this.telefone,
    required this.dataNascimento,
  });

  @override
  State<CadastroClienteEtapa2Page> createState() =>
      _CadastroClienteEtapa2PageState();
}

class _CadastroClienteEtapa2PageState extends State<CadastroClienteEtapa2Page> {
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =
      TextEditingController();

  bool _aceitouTermos = false;
  bool _aceitouPrivacidade = false;
  bool _carregando = false;

  // Getters para verificar os requisitos em tempo real
  bool get _temOitoCaracteres => _senhaController.text.length >= 8;
  bool get _temMaiuscula => _senhaController.text.contains(RegExp(r'[A-Z]'));
  bool get _temMinuscula => _senhaController.text.contains(RegExp(r'[a-z]'));
  bool get _temSimbolo => _senhaController.text.contains(
    RegExp(r'[^A-Za-z0-9\s]'),
  ); // Qualquer caractere que não seja letra, número ou espaço vazio

  @override
  void initState() {
    super.initState();
    // Adiciona o ouvinte para reconstruir a lista de requisitos conforme digita
    _senhaController.addListener(_atualizarInterface);
  }

  void _atualizarInterface() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _senhaController.removeListener(_atualizarInterface);
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _finalizarCadastroBanco() async {
    // Validação local prévia dos requisitos da senha antes de mandar para o banco
    if (!_temOitoCaracteres ||
        !_temMaiuscula ||
        !_temMinuscula ||
        !_temSimbolo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, preencha todos os requisitos de segurança da senha.',
          ),
        ),
      );
      return;
    }

    if (_senhaController.text != _confirmarSenhaController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas digitadas não coincidem.')),
      );
      return;
    }

    setState(() => _carregando = true);
    final supabase = Supabase.instance.client;

    try {
      final authResponse = await supabase.auth.signUp(
        email: widget.email,
        password: _senhaController.text,
      );

      final authUser = authResponse.user;
      if (authUser == null) {
        throw Exception('Falha ao criar conta de autenticação.');
      }

      final authId = authUser.id;

      final emailResponse = await supabase
          .from('emails')
          .insert({'endereco_email': widget.email, 'fk_status': 1})
          .select()
          .single();
      final emailId = emailResponse['id_email'];

      final telefoneLimpo = widget.telefone.replaceAll(RegExp(r'\D'), '');
      final ddd = telefoneLimpo.length >= 2
          ? telefoneLimpo.substring(0, 2)
          : '';
      final numero = telefoneLimpo.length > 2
          ? telefoneLimpo.substring(2)
          : telefoneLimpo;

      final telefoneResponse = await supabase
          .from('telefones')
          .insert({'ddd': ddd, 'numero': numero, 'fk_status': 1})
          .select()
          .single();
      final telefoneId = telefoneResponse['id_telefone'];

      final cpfLimpo = widget.cpf.replaceAll(RegExp(r'\D'), '');
      final pfResponse = await supabase
          .from('pessoa_fisica')
          .insert({'cpf': cpfLimpo.isNotEmpty ? cpfLimpo : null})
          .select()
          .single();
      final pfId = pfResponse['id_pessoa_fisica'];

      final assResponse = await supabase
          .from('ass_tipo_pessoa')
          .insert({
            'tipo': 'Pessoa Física',
            'fk_pessoa_fisica': pfId,
            'fk_pessoa_juridica': null,
          })
          .select()
          .single();
      final assTipoPessoaId = assResponse['id_tipo_pessoa'];

      await supabase.from('usuarios').insert({
        'nome': widget.nome,
        'data_nascimento': widget.dataNascimento.isNotEmpty
            ? widget.dataNascimento
            : null,
        'data_criacao': DateTime.now().toUtc().toIso8601String(),
        'tipo_conta': 'Cliente',
        'fk_email': emailId,
        'fk_telefone': telefoneId,
        'fk_tipo_pessoa': assTipoPessoaId,
        'fk_imagem': null,
        'auth_id': authId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadastro finalizado com sucesso!')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => TelaHome(isVisitante: false)),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      // Captura o erro específico de Autenticação do Supabase
      String mensagemAmigavel = 'Ocorreu um erro ao registrar.';

      if (e.toString().contains('AuthWeakPasswordException') ||
          e.message.toLowerCase().contains('password should be at least') ||
          e.statusCode == '422') {
        mensagemAmigavel =
            'Senha muito fraca! Garanta que ela possua 6 caracteres, 1 maiúscula, 1 minúscula e 1 símbolo.';
      } else if (e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('already exists')) {
        mensagemAmigavel =
            'Este e-mail já está cadastrado em nossa plataforma.';
      } else {
        mensagemAmigavel = e.message;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao registrar: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
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
      body: SingleChildScrollView(
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

            _InputFieldWithAnimation(
              label: 'Senha',
              hint: 'Digite sua senha',
              keyboardType: TextInputType.visiblePassword,
              obscureText: true,
              suffixIcon: Icons.visibility_outlined,
              controller: _senhaController,
            ),

            // LISTA DE REQUISITOS ABAIXO DO INPUT DE CRIAR SENHA
            Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRequisitoItem(
                    'No mínimo 8 caracteres',
                    _temOitoCaracteres,
                  ),
                  _buildRequisitoItem(
                    'Pelo menos 1 letra maiúscula',
                    _temMaiuscula,
                  ),
                  _buildRequisitoItem(
                    'Pelo menos 1 letra minúscula',
                    _temMinuscula,
                  ),
                  _buildRequisitoItem(
                    'Pelo menos 1 símbolo (ex: @, #, \$, %)',
                    _temSimbolo,
                  ),
                ],
              ),
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
            _buildCheckboxRow(
              fullText: 'Li e aceito os Termos de Uso',
              highlightText: 'Termos de Uso',
              value: _aceitouTermos,
              onTapCheckbox: () =>
                  setState(() => _aceitouTermos = !_aceitouTermos),
              onTapLink: () {},
            ),
            const SizedBox(height: 14),
            _buildCheckboxRow(
              fullText: 'Li e aceito a Política de Privacidade',
              highlightText: 'Política de Privacidade',
              value: _aceitouPrivacidade,
              onTapCheckbox: () =>
                  setState(() => _aceitouPrivacidade = !_aceitouPrivacidade),
              onTapLink: () {},
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed:
                    (_aceitouTermos && _aceitouPrivacidade && !_carregando)
                    ? _finalizarCadastroBanco
                    : null,
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
                child: _carregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
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
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para renderizar cada linha de requisito da senha
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

  Widget _buildCheckboxRow({
    required String fullText,
    required String highlightText,
    required bool value,
    required VoidCallback onTapCheckbox,
    required VoidCallback onTapLink,
  }) {
    final int targetIndex = fullText.indexOf(highlightText);
    final String prefixText = targetIndex != -1
        ? fullText.substring(0, targetIndex)
        : fullText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(text: prefixText),
                TextSpan(
                  text: highlightText,
                  style: const TextStyle(
                    color: Color(0xFF00A2FF),
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
