import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cadastro_profissional.dart'
    show CadastroFacialInstrucoesPage, ValidacaoDocsPage;
import 'validacao_telefone.dart';

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
          .select('id_usuario, fk_email, fk_telefone')
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
          usuario['fk_telefone'] == null ||
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
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  String? _cpf;
  String? _idFacial;
  List<Map<String, dynamic>> _documentos = [];
  bool _salvando = false;

  @override
  void dispose() {
    _email.dispose();
    _telefone.dispose();
    super.dispose();
  }

  bool get _documentoConcluido => _documentos.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _carregarCpf();
  }

  Future<void> _carregarCpf() async {
    try {
      final client = Supabase.instance.client;
      final usuario = await client
          .from('usuarios')
          .select('fk_tipo_pessoa')
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
      if (mounted) setState(() => _cpf = pessoa['cpf']?.toString());
    } catch (_) {}
  }

  Future<void> _salvar() async {
    final email = _email.text.trim();
    final telefone = _telefone.text.trim();
    final telefoneValidacao = validarTelefoneCompleto(telefone);
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _avisar('Informe um email válido.');
      return;
    }
    if (!telefoneValidacao.valido) {
      _avisar(telefoneValidacao.erro ?? 'Informe um telefone válido.');
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

      final digits = telefone.replaceAll(RegExp(r'\D'), '');
      final telefoneRow = await client
          .from('telefones')
          .insert({
            'ddd': digits.substring(0, 2),
            'numero': digits.substring(2),
            'fk_status': 1,
          })
          .select('id_telefone')
          .single();
      final telefoneId = telefoneRow['id_telefone'];

      await client.from('usuarios').update({
        'fk_email': emailId,
        'fk_telefone': telefoneId,
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
    return AlertDialog(
      title: const Text('Finalize seu cadastro'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Informe seus dados para ativar sua conta profissional.'),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _telefone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone'),
            ),
            const SizedBox(height: 12),
            _botaoValidacao(
              'Cadastro facial',
              _idFacial != null,
              () async {
                final resultado = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const CadastroFacialInstrucoesPage()),
                );
                if (resultado != null && mounted) setState(() => _idFacial = resultado);
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
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: _salvando ? null : _salvar,
          child: _salvando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator())
              : const Text('Finalizar cadastro'),
        ),
      ],
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