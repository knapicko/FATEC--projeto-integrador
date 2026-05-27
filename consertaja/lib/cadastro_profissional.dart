import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login.dart';

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

              // Indicador de Etapas
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

              // Slider de escolha entre Pessoa Física ou Jurídica
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
                        onTap: () => setState(() => _isPessoaFisica = true),
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
                        onTap: () => setState(() => _isPessoaFisica = false),
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

              // FORMULÁRIO DINÂMICO DA ETAPA 1
              if (_isPessoaFisica) ...[
                const _InputFieldWithAnimation(
                  label: 'Nome',
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
                  label: 'Senha',
                  hint: 'Senha',
                  suffixIcon: Icons.visibility_outlined,
                  obscureText: true,
                ),
                const _InputFieldWithAnimation(
                  label: 'Confirmar Senha',
                  hint: 'Confirmar Senha',
                  suffixIcon: Icons.visibility_outlined,
                  obscureText: true,
                ),
              ] else ...[
                const _InputFieldWithAnimation(
                  label: 'Nome',
                  hint: 'Nome completo',
                  keyboardType: TextInputType.name,
                ),
                _InputFieldWithAnimation(
                  label: 'CNPJ',
                  hint: '__.___.___/____-__',
                  keyboardType: TextInputType.number,
                  inputFormatters: [MaskedInputFormatter('##.###.###/####-##')],
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

                const _InputFieldWithAnimation(
                  label: 'Razão Social',
                  hint: 'Razão Social',
                ),
                const _InputFieldWithAnimation(
                  label: 'Senha',
                  hint: 'Senha',
                  suffixIcon: Icons.visibility_outlined,
                  obscureText: true,
                ),
                const _InputFieldWithAnimation(
                  label: 'Confirmar Senha',
                  hint: 'Confirmar Senha',
                  suffixIcon: Icons.visibility_outlined,
                  obscureText: true,
                ),
              ],

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const CadastroProfissionalEtapa2Page(),
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
  const CadastroProfissionalEtapa2Page({super.key});

  @override
  State<CadastroProfissionalEtapa2Page> createState() =>
      _CadastroProfissionalEtapa2PageState();
}

class _CadastroProfissionalEtapa2PageState
    extends State<CadastroProfissionalEtapa2Page> {
  final TextEditingController _dataNascimentoController =
      TextEditingController();
  final TextEditingController _atuacaoController = TextEditingController();
  final FocusNode _atuacaoFocusNode = FocusNode();

  bool _showAtuacaoDropdown = false;
  final List<String> _areasDeAtuacaoExemplo = [
    'Assistência Técnica',
    'Aulas e Treinamentos',
    'Construção e Reformas',
    'Design e Tecnologia',
    'Eventos e Festas',
    'Serviços Domésticos',
    'Saúde e Beleza',
  ];

  @override
  void initState() {
    super.initState();
    _atuacaoFocusNode.addListener(() {
      setState(() {
        _showAtuacaoDropdown = _atuacaoFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _dataNascimentoController.dispose();
    _atuacaoController.dispose();
    _atuacaoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fazerUploadDataNascimento() async {
    DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 18),
      ),
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
                readOnly: true,
                onTap: _fazerUploadDataNascimento,
                onSuffixIconTap: _fazerUploadDataNascimento,
              ),

              Stack(
                children: [
                  _InputFieldWithAnimation(
                    label: 'Área de Atuação',
                    hint: 'Selecione sua área principal',
                    suffixIcon: Icons.keyboard_arrow_down,
                    controller: _atuacaoController,
                    focusNode: _atuacaoFocusNode,
                    readOnly: true,
                  ),
                ],
              ),

              if (_showAtuacaoDropdown) ...[
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    maxHeight: 220,
                  ),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00A2FF),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _areasDeAtuacaoExemplo.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFEFEFEF)),
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                          _areasDeAtuacaoExemplo[index],
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _atuacaoController.text =
                                _areasDeAtuacaoExemplo[index];
                            _showAtuacaoDropdown = false;
                            _atuacaoFocusNode.unfocus();
                          });
                        },
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CadastroProfissionalEtapa3Page(),
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
  const CadastroProfissionalEtapa3Page({super.key});

  @override
  State<CadastroProfissionalEtapa3Page> createState() =>
      _CadastroProfissionalEtapa3PageState();
}

class _CadastroProfissionalEtapa3PageState extends State<CadastroProfissionalEtapa3Page> {
  bool _termosDeUso = false;
  bool _politicaPrivacidade = false;

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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CadastroFacialPage(),
                    ),
                  );
                },
              ),
              
              // Modificado: Agora direciona para a tela exata de Cadastro do Documento de Identidade
              _buildDocumentButton(
                label: 'Documento de Identidade',
                icon: Icons.arrow_forward,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CadastroDocumentoIdentidadePage(),
                    ),
                  );
                },
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
                textNormal: 'Li e aceito os ',
                textBlue: 'Termos de Uso',
                onBlueTextTap: () {},
              ),
              const SizedBox(height: 10),

              _buildCheckboxRow(
                value: _politicaPrivacidade,
                onChanged: (val) => setState(() => _politicaPrivacidade = val ?? false),
                textNormal: 'Li e aceito a ',
                textBlue: 'Política de Privacidade',
                onBlueTextTap: () {},
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: (_termosDeUso && _politicaPrivacidade) ? () {} : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2FF),
                    disabledBackgroundColor: const Color(0xFF00A2FF).withValues(alpha:0.5),
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
        border: Border.all(
          color: const Color(0xFF00A2FF),
          width: 1.2,
        ),
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
              Icon(
                icon,
                color: const Color(0xFF00A2FF),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String textNormal,
    required String textBlue,
    required VoidCallback onBlueTextTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 30,
          height: 30,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF00A2FF),
            side: const BorderSide(
              color: Color(0xFF00A2FF),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Color(0xFF4F4F4F),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(text: textNormal),
                TextSpan(
                  text: textBlue,
                  style: const TextStyle(
                    color: Color(0xFF00A2FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ================= TELA: CADASTRO FACIAL =================
class CadastroFacialPage extends StatelessWidget {
  const CadastroFacialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00A2FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cadastro Facial',
          style: TextStyle(
            color: Color(0xFF00A2FF),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            height: 1,
            width: double.infinity,
            color: Colors.grey.withValues(alpha:0.2),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),

                  Image.asset(
                    'assets/images/cadastro_facial_img.png',
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 30),

                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        color: Color(0xFF00A2FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: 'O seu rosto é utilizado exclusivamente para autenticação no aplicativo. Para mais informações confira a ',
                        ),
                        TextSpan(
                          text: 'Política de Privacidade.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Instruções',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildInstructionItem([
                    const TextSpan(text: 'Deixe o celular na altura do rosto. '),
                    const TextSpan(
                      text: 'Se quiser mantenha os braços apoiados.',
                      style: TextStyle(color: Color(0xFF00A2FF)),
                    ),
                  ]),
                  _buildInstructionItem([
                    const TextSpan(text: 'Mantenha o rosto dentro do círculo '),
                    const TextSpan(
                      text: 'durante todo o processo.',
                      style: TextStyle(color: Color(0xFF00A2FF)),
                    ),
                  ]),
                  _buildInstructionItem([
                    const TextSpan(
                      text: 'Retire chapéu, óculos de sol ou qualquer coisa que ',
                      style: TextStyle(color: Color(0xFF00A2FF)),
                    ),
                    const TextSpan(text: 'cubra parte do seu rosto.'),
                  ]),
                  _buildInstructionItem([
                    const TextSpan(text: 'Se mantenha em um '),
                    const TextSpan(
                      text: 'ambiente iluminado',
                      style: TextStyle(color: Color(0xFF00A2FF)),
                    ),
                    const TextSpan(text: ' e de preferência com '),
                    const TextSpan(
                      text: 'fundo branco.',
                      style: TextStyle(color: Color(0xFF00A2FF)),
                    ),
                  ]),

                  const SizedBox(height: 50),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CadastroFacialLeituraFacialPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A2FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                  ),
                      child: const Text(
                        'Iniciar Cadastro Facial',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(List<TextSpan> textSpans) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2.0, right: 6.0),
            child: Icon(
              Icons.arrow_right,
              color: Color(0xFF00A2FF),
              size: 18,
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
                children: textSpans,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= TELA: CADASTRO FACIAL - LEITURA FACIAL =================
class CadastroFacialLeituraFacialPage extends StatefulWidget {
  const CadastroFacialLeituraFacialPage({super.key});

  @override
  State<CadastroFacialLeituraFacialPage> createState() =>
      _CadastroFacialLeituraFacialPageState();
}

class _CadastroFacialLeituraFacialPageState extends State<CadastroFacialLeituraFacialPage> {
  bool _temPermissao = false;
  bool _mostrarIconeErro = false;
  bool _cameraFrontalAtiva = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _solicitarPermissaoCamera();
    });
  }

  void _solicitarPermissaoCamera() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Permissão de Câmera',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'O aplicativo precisa de acesso à câmera do celular para realizar a verificação e captura do seu Cadastro Facial.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _temPermissao = false;
                  _mostrarIconeErro = true;
                });
              },
              child: const Text(
                'Negar',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _temPermissao = true;
                  _mostrarIconeErro = false;
                });
              },
              child: const Text(
                'Permitir',
                style: TextStyle(color: Color(0xFF00A2FF), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00A2FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cadastro Facial',
          style: TextStyle(
            color: Color(0xFF00A2FF),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_mostrarIconeErro)
            IconButton(
              icon: const Icon(Icons.error, color: Colors.red, size: 26),
              onPressed: _solicitarPermissaoCamera,
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 1,
            width: double.infinity,
            color: Colors.grey.withValues(alpha:0.2),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A2FF).withValues(alpha:0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Nenhum Rosto Detectado',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF00A2FF),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 60),

                  Container(
                    width: 270,
                    height: 270,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red, width: 4),
                      color: const Color(0xFFF2F2F2),
                    ),
                    child: ClipOval(
                      child: _temPermissao
                          ? Center(
                              child: Text(
                                _cameraFrontalAtiva 
                                    ? '[ Câmera Frontal Ativa ]' 
                                    : '[ Câmera Traseira Ativa ]',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Corrigido de Icons.camera_alt_disabled para Icons.no_photography para compilar estavelmente
                                  Icon(Icons.no_photography, color: Colors.grey, size: 42),
                                  SizedBox(height: 8),
                                  Text(
                                    'Sem permissão',
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 45),

                  GestureDetector(
                    onTap: () {
                      if (_temPermissao) {
                        setState(() {
                          _cameraFrontalAtiva = !_cameraFrontalAtiva;
                        });
                      }
                    },
                    child: Image.asset(
                      'assets/images/virar_camera_img.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF2F2F2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.flip_camera_android,
                            color: Color(0xFF00A2FF),
                            size: 30,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= TELA: ANEXAR DOCUMENTOS DE IDENTIDADE (NOVA) =================
class CadastroDocumentoIdentidadePage extends StatefulWidget {
  const CadastroDocumentoIdentidadePage({super.key});

  @override
  State<CadastroDocumentoIdentidadePage> createState() =>
      _CadastroDocumentoIdentidadePageState();
}

class _CadastroDocumentoIdentidadePageState extends State<CadastroDocumentoIdentidadePage> {
  // Controle de estado de envio para cada documento individualmente
  bool _rgEnexado = false;
  bool _cinEnexado = false;
  bool _cnhEnexado = false;
  bool _passaporteEnexado = false;

  // Lógica genérica do Pop-up Simulador de Upload
  void _mostrarPopupAnexar(String nomeDocumento, Function() onSuccess) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Anexar $nomeDocumento',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Selecione uma imagem ou documento do seu dispositivo (PNG, JPG, JPEG) correspondente.',
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00A2FF).withValues(alpha:0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF00A2FF)),
                    SizedBox(width: 8),
                    Text(
                      'Selecionar Arquivo...',
                      style: TextStyle(color: Color(0xFF00A2FF), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onSuccess(); // Executa o callback atualizando o estado do documento para verde
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A2FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Enviar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // Seta azul para retornar para a Etapa 3
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00A2FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Anexe os Documentos',
          style: TextStyle(
            color: Color(0xFF00A2FF),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Divisória cinza claro de pouca opacidade abaixo da AppBar
          Container(
            height: 1,
            width: double.infinity,
            color: Colors.grey.withValues(alpha:0.2),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  Image.asset(
                    'assets/images/Documentos_img.png',
                    height: 140,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        alignment: Alignment.center,
                        child: const Icon(Icons.folder_shared, size: 90, color: Color(0xFF00A2FF)),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      style: TextStyle(
                        color: Color(0xFF00A2FF),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: 'O seu documento de identidade é utilizado exclusivamente para a verificação da sua conta.\nPara mais informações confira a ',
                        ),
                        TextSpan(
                          text: 'Política de Privacidade.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),

                  // Título da seção: Escolha o tipo documento
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Escolha o tipo documento',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botões retangulares longos com alteração dinâmica de cor baseada no anexo
                  _buildSelectableDocButton(
                    title: 'Registro Geral (RG)',
                    isAttached: _rgEnexado,
                    onTap: () => _mostrarPopupAnexar('RG', () => setState(() => _rgEnexado = true)),
                  ),
                  _buildSelectableDocButton(
                    title: 'Carteira de Identidade Nacional (CIN)',
                    isAttached: _cinEnexado,
                    onTap: () => _mostrarPopupAnexar('CIN', () => setState(() => _cinEnexado = true)),
                  ),
                  _buildSelectableDocButton(
                    title: 'Carteira Nacional de Habilitação (CNH)',
                    isAttached: _cnhEnexado,
                    onTap: () => _mostrarPopupAnexar('CNH', () => setState(() => _cnhEnexado = true)),
                  ),
                  _buildSelectableDocButton(
                    title: 'Passaporte',
                    isAttached: _passaporteEnexado,
                    onTap: () => _mostrarPopupAnexar('Passaporte', () => setState(() => _passaporteEnexado = true)),
                  ),

                  const SizedBox(height: 40),

                  // Botão Enviar Documentos que retorna para a tela anterior
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A2FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Enviar Documentos',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget builder exclusivo para criar botões com estado dinâmico (Azul -> Verde ao anexar)
  Widget _buildSelectableDocButton({
    required String title,
    required bool isAttached,
    required VoidCallback onTap,
  }) {
    final Color currentColor = isAttached ? Colors.green : const Color(0xFF00A2FF);
    final IconData currentIcon = isAttached ? Icons.check_circle : Icons.attach_file;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 14),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: currentColor,
          width: isAttached ? 1.8 : 1.2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: currentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                currentIcon,
                color: currentColor,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= COMPONENTE DE INPUT CUSTOMIZADO E ANIMADO REFACTORIZADO =================
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
                  ? const Color(0xFF00A2FF).withValues(alpha:0.08)
                  : Colors.black.withValues(alpha:0.015),
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
                                        ).withValues(alpha:0.5)),
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
                          color: const Color(0xFF00A2FF).withValues(alpha:0.4),
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

// Classe Utilitária de Máscara de Input
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