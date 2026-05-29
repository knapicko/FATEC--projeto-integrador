import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';
import 'login.dart';
import 'tela_home.dart';

// ================= TELA 01: CADASTRO DO PROFISSIONAL (ETAPA 1) =================
class CadastroProfissionalPage extends StatefulWidget {
  const CadastroProfissionalPage({super.key});

  @override
  State<CadastroProfissionalPage> createState() =>
      _CadastroProfissionalPageState();
}

class _CadastroProfissionalPageState extends State<CadastroProfissionalPage> {
  bool _isPessoaFisica = true;
  bool _cnpjDeEmpresa = true;

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _cnpjController = TextEditingController();
  final TextEditingController _razaoSocialController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController =TextEditingController();

  String? _fotoPerfilUrl;

  // Estados de erro para os inputs
  String? _erroNome;
  String? _erroCpf;
  String? _erroCnpj;
  String? _erroRazaoSocial;
  String? _erroSenha;
  String? _erroConfirmarSenha;

  // Getters para os requisitos da senha
  bool get _temOitoCaracteres => _senhaController.text.length >= 8;
  bool get _temMaiuscula => _senhaController.text.contains(RegExp(r'[A-Z]'));
  bool get _temMinuscula => _senhaController.text.contains(RegExp(r'[a-z]'));
  bool get _temSimbolo =>
      _senhaController.text.contains(RegExp(r'[^A-Za-z0-9\s]'));
  bool get _temNumero => _senhaController.text.contains(RegExp(r'[0-9]'));

  @override
  void initState() {
    super.initState();

    _senhaController.addListener(() {
      if (_senhaController.text.isNotEmpty && _erroSenha != null) {
        _erroSenha = null;
      }
      if (mounted) setState(() {});
    });

    _nomeController.addListener(() {
      if (_nomeController.text.isNotEmpty && _erroNome != null)
        setState(() => _erroNome = null);
    });
    _cpfController.addListener(() {
      if (_cpfController.text.isNotEmpty && _erroCpf != null)
        setState(() => _erroCpf = null);
    });
    _cnpjController.addListener(() {
      if (_cnpjController.text.isNotEmpty && _erroCnpj != null)
        setState(() => _erroCnpj = null);
    });
    _razaoSocialController.addListener(() {
      if (_razaoSocialController.text.isNotEmpty && _erroRazaoSocial != null)
        setState(() => _erroRazaoSocial = null);
    });
    _confirmarSenhaController.addListener(() {
      if (_confirmarSenhaController.text.isNotEmpty &&
          _erroConfirmarSenha != null)
        setState(() => _erroConfirmarSenha = null);
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _cnpjController.dispose();
    _razaoSocialController.dispose();
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
                'Criar conta - Profissional',
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
                  _buildStepLine(),
                  _buildStepCircle('3', isActive: false),
                ],
              ),
              const SizedBox(height: 35),

              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isPessoaFisica = true;
                          _erroCnpj = null;
                          _erroRazaoSocial = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: _isPessoaFisica
                                ? const Color(0xFF00A2FF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Pessoa Física',
                            style: TextStyle(
                              color: _isPessoaFisica
                                  ? Colors.white
                                  : const Color(0xFF828282),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _isPessoaFisica = false;
                          _erroCpf = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: !_isPessoaFisica
                                ? const Color(0xFF00A2FF)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Pessoa Jurídica',
                            style: TextStyle(
                              color: !_isPessoaFisica
                                  ? Colors.white
                                  : const Color(0xFF828282),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 35),

              if (_isPessoaFisica) ...[
                _InputFieldWithAnimation(
                  label: 'CPF',
                  hint: '___.___.___-__',
                  keyboardType: TextInputType.number,
                  inputFormatters: [MaskedInputFormatter('###.###.###-##')],
                  controller: _cpfController,
                  errorText: _erroCpf,
                ),
                _InputFieldWithAnimation(
                  label: 'Nome',
                  hint: 'Nome completo',
                  keyboardType: TextInputType.name,
                  controller: _nomeController,
                  errorText: _erroNome,
                ),
                _InputFieldWithAnimation(
                  label: 'Senha',
                  hint: 'Digite sua senha',
                  suffixIcon: Icons.visibility_outlined,
                  obscureText: true,
                  controller: _senhaController,
                  errorText: _erroSenha,
                ),

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
                      _buildRequisitoItem(
                        'Pelo menos 1 número',
                        _temNumero,
                      ),
                    ],
                  ),
                ),

                _InputFieldWithAnimation(
                  label: 'Confirmar Senha',
                  hint: 'Confirme sua senha',
                  suffixIcon: Icons.visibility_outlined,
                  obscureText: true,
                  controller: _confirmarSenhaController,
                  errorText: _erroConfirmarSenha,
                ),
              ] else ...[
                _InputFieldWithAnimation(
                  label: 'CNPJ',
                  hint: '__.___.___/____-__',
                  keyboardType: TextInputType.number,
                  inputFormatters: [MaskedInputFormatter('##.###.###/####-##')],
                  controller: _cnpjController,
                  errorText: _erroCnpj,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 25, left: 4, top: 5),
                  child: Column(
                    children: [
                      _buildCustomRadioButton(
                        text: 'CNPJ de uma empresa',
                        isSelected: _cnpjDeEmpresa,
                        onTap: () => setState(() => _cnpjDeEmpresa = true),
                      ),
                      const SizedBox(height: 12),
                      _buildCustomRadioButton(
                        text: 'Tenho um imóvel registrado em CNPJ',
                        isSelected: !_cnpjDeEmpresa,
                        onTap: () => setState(() => _cnpjDeEmpresa = false),
                      ),
                    ],
                  ),
                ),
                _InputFieldWithAnimation(
                  label: 'Nome',
                  hint: 'Nome completo',
                  keyboardType: TextInputType.name,
                  controller: _nomeController,
                  errorText: _erroNome,
                ),
                _InputFieldWithAnimation(
                  label: 'Razão Social',
                  hint: 'Razão Social',
                  controller: _razaoSocialController,
                  errorText: _erroRazaoSocial,
                ),
                _InputFieldWithAnimation(
                  label: 'Senha',
                  hint: 'Digite sua senha',
                  suffixIcon: Icons.visibility_outlined,
                  obscureText: true,
                  controller: _senhaController,
                  errorText: _erroSenha,
                ),

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
                      _buildRequisitoItem(
                        'Pelo menos 1 número',
                        _temNumero,
                      ),
                    ],
                  ),
                ),

                _InputFieldWithAnimation(
                  label: 'Confirmar Senha',
                  hint: 'Confirme sua senha',
                  suffixIcon: Icons.visibility_outlined,
                  obscureText: true,
                  controller: _confirmarSenhaController,
                  errorText: _erroConfirmarSenha,
                ),
              ],

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _erroNome = _nomeController.text.trim().isEmpty
                          ? 'O nome é obrigatório'
                          : null;

                      if (_isPessoaFisica) {
                        _erroCpf = _cpfController.text.trim().isEmpty
                            ? 'O CPF é obrigatório'
                            : null;
                      } else {
                        _erroCnpj = _cnpjController.text.trim().isEmpty
                            ? 'O CNPJ é obrigatório'
                            : null;
                        _erroRazaoSocial =
                            _razaoSocialController.text.trim().isEmpty
                            ? 'A Razão Social é obrigatória'
                            : null;
                      }

                      if (!_temOitoCaracteres ||
                          !_temMaiuscula ||
                          !_temMinuscula ||
                          !_temSimbolo ||
                          !_temNumero) {
                        _erroSenha = 'A senha não atende aos requisitos';
                      } else {
                        _erroSenha = null;
                      }

                      if (_senhaController.text !=
                          _confirmarSenhaController.text) {
                        _erroConfirmarSenha = 'As senhas não coincidem';
                      } else {
                        _erroConfirmarSenha = null;
                      }
                    });

                    if (_erroNome != null ||
                        _erroCpf != null ||
                        _erroCnpj != null ||
                        _erroRazaoSocial != null ||
                        _erroSenha != null ||
                        _erroConfirmarSenha != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Por favor, preencha todos os campos obrigatórios corretamente.',
                          ),
                        ),
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CadastroProfissionalEtapa2Page(
                          nome: _nomeController.text.trim(),
                          cpf: _isPessoaFisica
                              ? _cpfController.text.trim()
                              : null,
                          cnpj: !_isPessoaFisica
                              ? _cnpjController.text.trim()
                              : null,
                          razaoSocial: !_isPessoaFisica
                              ? _razaoSocialController.text.trim()
                              : null,
                          senha: _senhaController.text,
                          isPessoaFisica: _isPessoaFisica,
                          cnpjDeEmpresa: _cnpjDeEmpresa,
                          fotoPerfilUrl: _fotoPerfilUrl,
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

  Widget _buildCustomRadioButton({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00A2FF)
                    : const Color(0xFFBDBDBD),
                width: 2,
              ),
              color: isSelected ? const Color(0xFF00A2FF) : Colors.transparent,
            ),
            child: isSelected
                ? const Center(
                    child: Icon(Icons.circle, size: 8, color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF00A2FF)
                    : const Color(0xFF828282),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= TELA 02: CADASTRO DO PROFISSIONAL (ETAPA 2) =================
class CadastroProfissionalEtapa2Page extends StatefulWidget {
  final String nome;
  final String? cpf;
  final String? cnpj;
  final String? razaoSocial;
  final String senha;
  final bool isPessoaFisica;
  final bool cnpjDeEmpresa;
  final String? fotoPerfilUrl;

  const CadastroProfissionalEtapa2Page({
    super.key,
    required this.nome,
    this.cpf,
    this.cnpj,
    this.razaoSocial,
    required this.senha,
    required this.isPessoaFisica,
    required this.cnpjDeEmpresa,
    this.fotoPerfilUrl,
  });

  @override
  State<CadastroProfissionalEtapa2Page> createState() =>
      _CadastroProfissionalEtapa2PageState();
}

class _CadastroProfissionalEtapa2PageState
    extends State<CadastroProfissionalEtapa2Page> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _dataNascimentoController =
      TextEditingController();
  final TextEditingController _atuacaoController = TextEditingController();

  bool _showAtuacaoDropdown = false;
  bool _carregandoOficios = true;
  List<Map<String, dynamic>> _oficios = [];

  // Lista para salvar os itens múltiplos selecionados
  final List<Map<String, dynamic>> _oficiosSelecionados = [];

  // Estados de erro para os inputs
  String? _erroEmail;
  String? _erroTelefone;
  String? _erroDataNascimento;
  String? _erroAtuacao;

  @override
  void initState() {
    super.initState();

    _emailController.addListener(() {
      if (_emailController.text.isNotEmpty && _erroEmail != null)
        setState(() => _erroEmail = null);
    });
    _telefoneController.addListener(() {
      if (_telefoneController.text.isNotEmpty && _erroTelefone != null)
        setState(() => _erroTelefone = null);
    });
    _dataNascimentoController.addListener(() {
      if (_dataNascimentoController.text.isNotEmpty &&
          _erroDataNascimento != null)
        setState(() => _erroDataNascimento = null);
    });

    _carregarOficios();
  }

  Future<void> _carregarOficios() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('oficios')
          .select('id_oficio, funcao')
          .order('funcao');
      if (mounted) {
        setState(() {
          _oficios = List<Map<String, dynamic>>.from(response);
          _carregandoOficios = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregandoOficios = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar ofícios: $e')));
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _telefoneController.dispose();
    _dataNascimentoController.dispose();
    _atuacaoController.dispose();
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

  // Atualiza dinamicamente o texto exibido no input principal
  void _atualizarTextoAtuacao() {
    if (_oficiosSelecionados.isEmpty) {
      _atuacaoController.text = '';
    } else {
      _atuacaoController.text = _oficiosSelecionados
          .map((e) => e['funcao'])
          .join(', ');
    }
    if (_oficiosSelecionados.isNotEmpty && _erroAtuacao != null) {
      _erroAtuacao = null;
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
                'Criar conta - Profissional',
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
                  _buildStepLine(),
                  _buildStepCircle('3', isActive: false),
                ],
              ),
              const SizedBox(height: 40),

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
                hint: 'AAAA-MM-DD',
                suffixIcon: Icons.calendar_month,
                controller: _dataNascimentoController,
                readOnly: true,
                onTap: _fazerUploadDataNascimento,
                onSuffixIconTap: _fazerUploadDataNascimento,
                errorText: _erroDataNascimento,
              ),

              _InputFieldWithAnimation(
                label: 'Áreas de Atuação (Selecione até 3)',
                hint: _carregandoOficios
                    ? 'Carregando...'
                    : 'Selecione de 1 a 3 áreas principais',
                suffixIcon: _showAtuacaoDropdown
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                controller: _atuacaoController,
                readOnly: true,
                errorText: _erroAtuacao,
                onTap: () {
                  setState(() {
                    _showAtuacaoDropdown = !_showAtuacaoDropdown;
                  });
                },
              ),

              if (_showAtuacaoDropdown) ...[
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 250),
                  margin: const EdgeInsets.only(bottom: 20, top: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00A2FF),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _carregandoOficios
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              color: Color(0xFF00A2FF),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _oficios.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: Color(0xFFEFEFEF),
                          ),
                          itemBuilder: (context, index) {
                            final oficio = _oficios[index];
                            final isSelected = _oficiosSelecionados.any(
                              (element) =>
                                  element['id_oficio'] == oficio['id_oficio'],
                            );

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _oficiosSelecionados.removeWhere(
                                      (element) =>
                                          element['id_oficio'] ==
                                          oficio['id_oficio'],
                                    );
                                  } else {
                                    if (_oficiosSelecionados.length >= 3) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Você só pode selecionar no máximo 3 áreas.',
                                          ),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      return;
                                    }
                                    _oficiosSelecionados.add(oficio);
                                  }
                                  _atualizarTextoAtuacao();
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: isSelected,
                                        activeColor: const Color(0xFF00A2FF),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: (bool? checked) {
                                          setState(() {
                                            if (checked == true) {
                                              if (_oficiosSelecionados.length >=
                                                  3) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Você só pode selecionar no máximo 3 áreas.',
                                                    ),
                                                    duration: Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              _oficiosSelecionados.add(oficio);
                                            } else {
                                              _oficiosSelecionados.removeWhere(
                                                (element) =>
                                                    element['id_oficio'] ==
                                                    oficio['id_oficio'],
                                              );
                                            }
                                            _atualizarTextoAtuacao();
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        oficio['funcao'] ?? '',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isSelected
                                              ? const Color(0xFF00A2FF)
                                              : Colors.black87,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _erroEmail = _emailController.text.trim().isEmpty
                          ? 'O E-mail é obrigatório'
                          : null;
                      _erroTelefone = _telefoneController.text.trim().isEmpty
                          ? 'O Telefone é obrigatório'
                          : null;
                      _erroDataNascimento =
                          _dataNascimentoController.text.trim().isEmpty
                          ? 'A Data de Nascimento é obrigatória'
                          : null;

                      if (_oficiosSelecionados.isEmpty) {
                        _erroAtuacao = 'Selecione pelo menos 1 área de atuação';
                      } else {
                        _erroAtuacao = null;
                      }
                    });

                    if (_erroEmail != null ||
                        _erroTelefone != null ||
                        _erroDataNascimento != null ||
                        _erroAtuacao != null) {
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
                        builder: (context) => CadastroProfissionalEtapa3Page(
                          nome: widget.nome,
                          cpf: widget.cpf,
                          cnpj: widget.cnpj,
                          razaoSocial: widget.razaoSocial,
                          senha: widget.senha,
                          isPessoaFisica: widget.isPessoaFisica,
                          cnpjDeEmpresa: widget.cnpjDeEmpresa,
                          email: _emailController.text.trim(),
                          telefone: _telefoneController.text.trim(),
                          dataNascimento: _dataNascimentoController.text.trim(),
                          areaAtuacao: _atuacaoController.text.trim(),
                          fotoPerfilUrl: widget.fotoPerfilUrl,
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
              const SizedBox(height: 30),

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

// ================= TELA 03: CADASTRO DO PROFISSIONAL (ETAPA 3) =================
class CadastroProfissionalEtapa3Page extends StatefulWidget {
  final String nome;
  final String? cpf;
  final String? cnpj;
  final String? razaoSocial;
  final String senha;
  final bool isPessoaFisica;
  final bool cnpjDeEmpresa;
  final String email;
  final String telefone;
  final String dataNascimento;
  final String areaAtuacao;
  final String? fotoPerfilUrl;

  const CadastroProfissionalEtapa3Page({
    super.key,
    required this.nome,
    this.cpf,
    this.cnpj,
    this.razaoSocial,
    required this.senha,
    required this.isPessoaFisica,
    required this.cnpjDeEmpresa,
    required this.email,
    required this.telefone,
    required this.dataNascimento,
    required this.areaAtuacao,
    this.fotoPerfilUrl,
  });

  @override
  State<CadastroProfissionalEtapa3Page> createState() =>
      _CadastroProfissionalEtapa3PageState();
}

class _CadastroProfissionalEtapa3PageState
    extends State<CadastroProfissionalEtapa3Page> {
  bool _termosDeUso = false;
  bool _politicaPrivacidade = false;
  bool _carregando = false;

  Future<void> _finalizarCadastroBanco() async {
    setState(() => _carregando = true);
    final supabase = Supabase.instance.client;

    try {
      final authResponse = await supabase.auth.signUp(
        email: widget.email,
        password: widget.senha,
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

      int assTipoPessoaId;

      if (widget.isPessoaFisica) {
        final cpfLimpo = widget.cpf?.replaceAll(RegExp(r'\D'), '') ?? '';
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
        assTipoPessoaId = assResponse['id_tipo_pessoa'];
      } else {
        final cnpjLimpo = widget.cnpj?.replaceAll(RegExp(r'\D'), '') ?? '';
        final pjResponse = await supabase
            .from('pessoa_juridica')
            .insert({
              'cnpj': cnpjLimpo.isNotEmpty ? cnpjLimpo : null,
              'tem_imovel': !widget.cnpjDeEmpresa,
            })
            .select()
            .single();
        final pjId = pjResponse['id_pessoa_juridica'];

        final assResponse = await supabase
            .from('ass_tipo_pessoa')
            .insert({
              'tipo': 'Pessoa Jurídica',
              'fk_pessoa_fisica': null,
              'fk_pessoa_juridica': pjId,
            })
            .select()
            .single();
        assTipoPessoaId = assResponse['id_tipo_pessoa'];
      }

      final usuarioResponse = await supabase
          .from('usuarios')
          .insert({
            'nome': widget.nome,
            'data_nascimento': widget.dataNascimento.isNotEmpty
                ? widget.dataNascimento
                : null,
            'data_criacao': DateTime.now().toUtc().toIso8601String(),
            'tipo_conta': 'Profissional',
            'fk_email': emailId,
            'fk_telefone': telefoneId,
            'fk_tipo_pessoa': assTipoPessoaId,
            'foto_perfil_url': widget.fotoPerfilUrl,
            'auth_id': authId,
          })
          .select()
          .single();
      final usuarioId = usuarioResponse['id_usuario'];

      await supabase.from('dados_profissionais').insert({
        'fk_usuario': usuarioId,
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
                'Criar conta - Profissional',
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
                  _buildStepCircle('2', isActive: false),
                  _buildStepLine(),
                  _buildStepCircle('3', isActive: true),
                ],
              ),
              const SizedBox(height: 35),

              const Text(
                'Agora só precisamos de alguns documentos para terminarmos o seu cadastro!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF00A2FF),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 30),

              _buildDocumentButton(
                label: 'Cadastro Facial',
                icon: Icons.arrow_forward,
                onTap: () {},
              ),
              _buildDocumentButton(
                label: 'Documento de Identidade',
                icon: Icons.arrow_forward,
                onTap: () {},
              ),
              _buildDocumentButton(
                label: 'Outros documentos',
                icon: Icons.keyboard_arrow_down,
                onTap: () {},
              ),
              const SizedBox(height: 20),

              _buildCheckboxRow(
                value: _termosDeUso,
                onChanged: (val) => setState(() => _termosDeUso = val ?? false),
                fullText: 'Li e aceito os Termos de Uso',
                highlightText: 'Termos de Uso',
                onTapLink: () {},
              ),
              const SizedBox(height: 14),
              _buildCheckboxRow(
                value: _politicaPrivacidade,
                onChanged: (val) =>
                    setState(() => _politicaPrivacidade = val ?? false),
                fullText: 'Li e aceito a Política de Privacidade',
                highlightText: 'Política de Privacidade',
                onTapLink: () {},
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed:
                      (_termosDeUso && _politicaPrivacidade && !_carregando)
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
              const SizedBox(height: 25),

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

  Widget _buildDocumentButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00A2FF), width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF00A2FF),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(icon, color: const Color(0xFF00A2FF), size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String fullText,
    required String highlightText,
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
          onTap: () => onChanged(!value),
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
          GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
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
                    offset: _isFocused
                        ? const Offset(0, 4)
                        : const Offset(0, 2),
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
