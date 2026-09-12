import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cadastro_profissional.dart'
    show CadastroFacialInstrucoesPage, ValidacaoDocsPage;

class CompletarCadastroEquipeDialog extends StatefulWidget {
  const CompletarCadastroEquipeDialog({super.key});

  static Future<bool> deveCompletar() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return false;
    if (user.userMetadata?['conta_criada_pela_empresa'] != true) return false;
    try {
      final usuario = await client
          .from('usuarios')
          .select('id_usuario, fk_email, data_nascimento')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (usuario == null) return false;
      final idUsuario = (usuario['id_usuario'] as num).toInt();
      final profissional = await client
          .from('dados_profissionais')
          .select('id_facial, rosto_validado')
          .eq('fk_usuario', idUsuario)
          .maybeSingle();
      return usuario['fk_email'] == null ||
          usuario['data_nascimento'] == null ||
          profissional?['id_facial'] == null ||
          profissional?['rosto_validado'] != true;
    } catch (_) {
      return false;
    }
  }

  @override
  State<CompletarCadastroEquipeDialog> createState() =>
      _CompletarCadastroEquipeDialogState();
}

class _CompletarCadastroEquipeDialogState
    extends State<CompletarCadastroEquipeDialog> {
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _dataNascimento = TextEditingController();
  final _focoNome = FocusNode();
  final _focoEmail = FocusNode();
  final _focoNascimento = FocusNode();
  DateTime? _dataNascimentoValue;
  String? _cpf;
  String? _idFacial;
  List<Map<String, dynamic>> _documentos = [];
  bool _salvando = false;

  @override
  void dispose() {
    _focoNome.dispose();
    _focoEmail.dispose();
    _focoNascimento.dispose();
    _nome.dispose();
    _email.dispose();
    _dataNascimento.dispose();
    super.dispose();
  }

  bool get _documentoConcluido => _documentos.isNotEmpty;

  static const Color _primaria = Color(0xFF0FB3FF);
  static const Color _bordaCampo = Color(0xFFE2E8F0);
  static const Color _textoMuted = Color(0xFF64748B);

  InputDecoration _decoracaoCampo({
    required String label,
    required FocusNode foco,
    bool readOnly = false,
    Widget? suffixIcon,
  }) {
    final focada = foco.hasFocus;
    return InputDecoration(
      labelText: label,
      hintText: readOnly ? 'DD/MM/AAAA' : null,
      suffixIcon: suffixIcon,
      labelStyle: const TextStyle(color: _textoMuted),
      floatingLabelStyle: TextStyle(
        color: focada ? _primaria : _textoMuted,
        fontSize: 13,
      ),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _bordaCampo),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _bordaCampo),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaria, width: 1.5),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _focoNome.addListener(_aoMudarFoco);
    _focoEmail.addListener(_aoMudarFoco);
    _focoNascimento.addListener(_aoMudarFoco);
    _carregarCpf();
  }

  void _aoMudarFoco() {
    if (mounted) setState(() {});
  }

  Future<void> _carregarCpf() async {
    try {
      final client = Supabase.instance.client;
      final usuario = await client
          .from('usuarios')
          .select('fk_tipo_pessoa, nome, data_nascimento')
          .eq('auth_id', client.auth.currentUser!.id)
          .single();
      final tipo = await client
          .from('ass_tipo_pessoa')
          .select('fk_pessoa_fisica')
          .eq('id_tipo_pessoa', usuario['fk_tipo_pessoa'])
          .single();
      final pessoa = await client
          .from('pessoa_fisica')
          .select('cpf')
          .eq('id_pessoa_fisica', tipo['fk_pessoa_fisica'])
          .single();

      final nomeAtual = usuario['nome']?.toString().trim();
      final nascimentoRaw = usuario['data_nascimento'];
      DateTime? nascimento;
      if (nascimentoRaw is DateTime) {
        nascimento = nascimentoRaw;
      } else if (nascimentoRaw is String && nascimentoRaw.trim().isNotEmpty) {
        nascimento = DateTime.tryParse(nascimentoRaw.trim());
      }

      if (!mounted) return;
      setState(() {
        _cpf = pessoa['cpf']?.toString();
        if (nomeAtual != null && nomeAtual.isNotEmpty) {
          _nome.text = nomeAtual;
        }
        if (nascimento != null) {
          _dataNascimentoValue = nascimento;
          _dataNascimento.text =
              '${nascimento.day.toString().padLeft(2, '0')}/'
              '${nascimento.month.toString().padLeft(2, '0')}/'
              '${nascimento.year}';
        }
      });
    } catch (_) {}
  }

  Future<void> _selecionarDataNascimento() async {
    final agora = DateTime.now();
    final inicial =
        _dataNascimentoValue ?? DateTime(agora.year - 25, agora.month, agora.day);
    final selecionada = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(1920),
      lastDate: agora,
      helpText: 'Data de nascimento',
      fieldLabelText: 'Data de nascimento',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0FB3FF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
            datePickerTheme: const DatePickerThemeData(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: Color(0xFF0FB3FF),
              headerForegroundColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (selecionada == null || !mounted) return;
    setState(() {
      _dataNascimentoValue = selecionada;
      _dataNascimento.text =
          '${selecionada.day.toString().padLeft(2, '0')}/'
          '${selecionada.month.toString().padLeft(2, '0')}/'
          '${selecionada.year}';
    });
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final email = _email.text.trim();
    final dataNascimento = _dataNascimentoValue;

    if (nome.isEmpty) {
      _avisar('Informe seu nome completo.');
      return;
    }
    if (dataNascimento == null) {
      _avisar('Informe sua data de nascimento.');
      return;
    }
    final agora = DateTime.now();
    if (dataNascimento.isAfter(DateTime(agora.year, agora.month, agora.day))) {
      _avisar('Data de nascimento inválida (futura).');
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _avisar('Informe um email válido.');
      return;
    }
    if (_idFacial == null || !_documentoConcluido) {
      _avisar('Conclua a validação facial e documental.');
      return;
    }

    setState(() => _salvando = true);
    try {
      final client = Supabase.instance.client;
      final authUser = client.auth.currentUser!;
      final usuario = await client
          .from('usuarios')
          .select('id_usuario, fk_email')
          .eq('auth_id', authUser.id)
          .single();
      final idUsuario = (usuario['id_usuario'] as num).toInt();

      final emailRow = await client
          .from('emails')
          .update({'endereco_email': email, 'fk_status': 1})
          .eq('id_email', usuario['fk_email'] as num)
          .select('id_email')
          .maybeSingle();
      final emailId = emailRow?['id_email'] ?? usuario['fk_email'];

      final dataNascimentoIso =
          '${dataNascimento.year.toString().padLeft(4, '0')}-'
          '${dataNascimento.month.toString().padLeft(2, '0')}-'
          '${dataNascimento.day.toString().padLeft(2, '0')}';

      await client.from('usuarios').update({
        'nome': nome,
        'data_nascimento': dataNascimentoIso,
        'fk_email': emailId,
      }).eq('id_usuario', idUsuario);

      final profissional = await client
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', idUsuario)
          .single();
      final idProfissional = profissional['id_profissional'];
      await client.from('dados_profissionais').update({
        'id_facial': _idFacial,
        'rosto_validado': true,
      }).eq('id_profissional', idProfissional);

      for (final documento in _documentos) {
        await client.from('documentos_profissionais').insert({
          'tipo_documento': documento['tipo'],
          'fk_profissional': idProfissional,
          'validacao_documento': true,
        });
      }
      await client.auth.updateUser(UserAttributes(email: email));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _avisar('Não foi possível salvar o cadastro: $e');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle de arraste
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Cabeçalho
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      color: Color(0xFF0FB3FF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finalize seu cadastro',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'Ative sua conta profissional com seus dados',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nome,
                focusNode: _focoNome,
                textCapitalization: TextCapitalization.words,
                decoration: _decoracaoCampo(
                  label: 'Nome completo',
                  foco: _focoNome,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                focusNode: _focoEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: _decoracaoCampo(
                  label: 'Email',
                  foco: _focoEmail,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dataNascimento,
                focusNode: _focoNascimento,
                readOnly: true,
                onTap: _selecionarDataNascimento,
                decoration: _decoracaoCampo(
                  label: 'Data de Nascimento',
                  foco: _focoNascimento,
                  readOnly: true,
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF0FB3FF),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _botaoValidacao(
                'Cadastro facial',
                _idFacial != null,
                () async {
                  final resultado = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CadastroFacialInstrucoesPage(),
                    ),
                  );
                  if (resultado != null && mounted) {
                    setState(() => _idFacial = resultado);
                  }
                },
              ),
              _botaoValidacao(
                'Documento de identidade',
                _documentoConcluido,
                () async {
                  final resultado = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ValidacaoDocsPage(cpf: _cpf),
                    ),
                  );
                  if (resultado?['validado'] == true && mounted) {
                    setState(() {
                      _documentos = List<Map<String, dynamic>>.from(
                        resultado?['docsData'] ?? [],
                      );
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0FB3FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Finalizar cadastro',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoValidacao(String label, bool concluido, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        concluido ? Icons.check_circle : Icons.radio_button_unchecked,
        color: concluido ? Colors.green : const Color(0xFF0FB3FF),
      ),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}