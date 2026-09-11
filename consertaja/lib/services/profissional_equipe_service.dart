import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfissionalEquipeService {
  ProfissionalEquipeService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> criarConta({
    required String cpf,
    required String senha,
    required int idGrupoEmpresa,
  }) async {
    final sessaoAtual = _client.auth.currentSession;
    if (sessaoAtual == null) {
      throw Exception('Sua sessão expirou. Faça login novamente.');
    }

    String accessToken = sessaoAtual.accessToken;
    try {
      final respostaAtualizada = await _client.auth.refreshSession();
      accessToken =
          respostaAtualizada.session?.accessToken ?? accessToken;
    } on AuthException {
      throw Exception('Sua sessão expirou. Faça login novamente.');
    }

    final response = await _client.functions.invoke(
      'criar-profissional-equipe',
      headers: {'Authorization': 'Bearer $accessToken'},
      body: {
        'cpf': cpf,
        'senha': senha,
        'id_grupo_empresa': idGrupoEmpresa,
      },
    );
    if (response.data is Map && response.data['error'] != null) {
      throw Exception(response.data['error']);
    }
  }
}

class DadosNovoProfissional {
  const DadosNovoProfissional(this.senha);

  final String senha;
}

class CriarProfissionalPopover extends StatefulWidget {
  const CriarProfissionalPopover({super.key, required this.cpf});

  final String cpf;

  @override
    State<CriarProfissionalPopover> createState() =>
      _CriarProfissionalPopoverState();
}

class _CriarProfissionalPopoverState extends State<CriarProfissionalPopover> {
  final _senhaController = TextEditingController();
  final _confirmacaoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _ocultarSenha = true;
  bool _ocultarConfirmacao = true;

  static const _azulPrimario = Color(0xFF0FB3FF);

  bool get _temOitoCaracteres => _senhaController.text.length >= 8;
  bool get _temMaiuscula => _senhaController.text.contains(RegExp(r'[A-Z]'));
  bool get _temMinuscula => _senhaController.text.contains(RegExp(r'[a-z]'));
  bool get _temNumero => _senhaController.text.contains(RegExp(r'[0-9]'));
  bool get _temSimbolo =>
      _senhaController.text.contains(RegExp(r'[^A-Za-z0-9\s]'));

  @override
  void initState() {
    super.initState();
    _senhaController.addListener(_atualizarRequisitosSenha);
  }

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmacaoController.dispose();
    super.dispose();
  }

  Widget _requisitoSenha(String texto, bool concluido) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          Icon(
            concluido ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: concluido ? Colors.green : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 7),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              color: concluido ? Colors.green.shade700 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoracaoSenha({
    required String label,
    required IconData icone,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      floatingLabelStyle: const TextStyle(color: _azulPrimario),
      prefixIcon: Icon(icone),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _azulPrimario, width: 1.8),
      ),
    );
  }

  String? _validarSenha(String? value) {
    final senha = value ?? '';
    if (senha.length < 8 ||
        !senha.contains(RegExp(r'[A-Z]')) ||
        !senha.contains(RegExp(r'[a-z]')) ||
        !senha.contains(RegExp(r'[0-9]')) ||
        !senha.contains(RegExp(r'[^A-Za-z0-9\s]'))) {
      return 'Use 8 caracteres, maiúscula, minúscula, número e símbolo.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Color(0xFF0FB3FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Criar conta do funcionário',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Defina uma senha provisória. No primeiro acesso, o funcionário completará email, telefone, rosto e documento.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, color: Color(0xFF64748B)),
                      const SizedBox(width: 10),
                      Text(
                        'CPF: ${widget.cpf}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senhaController,
                  obscureText: _ocultarSenha,
                  decoration: _decoracaoSenha(
                    label: 'Senha provisória',
                    icone: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _ocultarSenha ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha),
                    ),
                  ),
                  validator: _validarSenha,
                ),
                _requisitoSenha('Pelo menos 8 caracteres', _temOitoCaracteres),
                _requisitoSenha('Uma letra maiúscula', _temMaiuscula),
                _requisitoSenha('Uma letra minúscula', _temMinuscula),
                _requisitoSenha('Um número', _temNumero),
                _requisitoSenha('Um símbolo', _temSimbolo),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmacaoController,
                  obscureText: _ocultarConfirmacao,
                  decoration: _decoracaoSenha(
                    label: 'Confirmar senha',
                    icone: Icons.lock_reset_outlined,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _ocultarConfirmacao
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _ocultarConfirmacao = !_ocultarConfirmacao,
                      ),
                    ),
                  ),
                  validator: (value) => value != _senhaController.text
                      ? 'As senhas não coincidem.'
                      : null,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        Navigator.pop(
                          context,
                          DadosNovoProfissional(_senhaController.text),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Criar conta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0FB3FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _atualizarRequisitosSenha() {
    if (mounted) setState(() {});
  }
}