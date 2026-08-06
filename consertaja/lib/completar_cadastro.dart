import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tela_home.dart';
import 'tela_home_profissional.dart';
import 'services/validacao_telefone.dart';
import 'widgets/seletor_ddi.dart';
import 'widgets/foto_perfil_google.dart';

// Reaproveita as telas de documento/facial que já existem no fluxo normal
// do profissional (não duplicamos essa lógica).
import 'cadastro_profissional.dart'
    show CadastroFacialInstrucoesPage, ValidacaoDocsPage;

// =========================================================================
// FUNÇÕES DE VALIDAÇÃO (mesma lógica usada em cadastro_cliente/profissional)
// =========================================================================
String _somenteDigitos(String valor) => valor.replaceAll(RegExp(r'\D'), '');

bool _validarCpfLocal(String cpf) {
  if (cpf.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;
  final numeros = cpf.split('').map(int.parse).toList();

  int soma = 0;
  for (int i = 0; i < 9; i++) {
    soma += numeros[i] * (10 - i);
  }
  int resto = soma % 11;
  int digito1 = resto < 2 ? 0 : 11 - resto;
  if (numeros[9] != digito1) return false;

  soma = 0;
  for (int i = 0; i < 10; i++) {
    soma += numeros[i] * (11 - i);
  }
  resto = soma % 11;
  int digito2 = resto < 2 ? 0 : 11 - resto;
  return numeros[10] == digito2;
}

bool _validarCnpjLocal(String cnpj) {
  if (cnpj.length != 14) return false;
  if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) return false;
  final numeros = cnpj.split('').map(int.parse).toList();

  const pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

  int soma = 0;
  for (int i = 0; i < 12; i++) {
    soma += numeros[i] * pesos1[i];
  }
  int resto = soma % 11;
  int digito1 = resto < 2 ? 0 : 11 - resto;
  if (numeros[12] != digito1) return false;

  soma = 0;
  for (int i = 0; i < 13; i++) {
    soma += numeros[i] * pesos2[i];
  }
  resto = soma % 11;
  int digito2 = resto < 2 ? 0 : 11 - resto;
  return numeros[13] == digito2;
}

// =========================================================================
// PÁGINA: COMPLETAR CADASTRO — CLIENTE (pós login Google)
// =========================================================================
class CompletarCadastroClientePage extends StatefulWidget {
  /// id do usuário já autenticado no Supabase (session.user.id)
  final String authId;
  final String emailGoogle;
  final String? nomeGoogle;
  final String? fotoUrlGoogle;

  const CompletarCadastroClientePage({
    super.key,
    required this.authId,
    required this.emailGoogle,
    this.nomeGoogle,
    this.fotoUrlGoogle,
  });

  @override
  State<CompletarCadastroClientePage> createState() =>
      _CompletarCadastroClientePageState();
}

class _CompletarCadastroClientePageState
    extends State<CompletarCadastroClientePage> {
  bool _isPessoaFisica = true;
  final bool _cnpjDeEmpresa = true;
  bool _carregando = false;
  bool _validandoDocumento = false;
  bool _documentoValido = false;

  late final TextEditingController _nomeController;
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _cnpjController = TextEditingController();
  final TextEditingController _razaoSocialController = TextEditingController();
  final TextEditingController _nomeFantasiaController =
      TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _dataNascimentoController =
      TextEditingController();
  final TextEditingController _dataFundacaoController = TextEditingController();

  final FocusNode _telefoneFocusNode = FocusNode();
  final FocusNode _cnpjFocusNode = FocusNode();
  String _ddiSelecionado = '+55';

  String? _erroNome;
  String? _erroCpf;
  String? _erroCnpj;
  String? _erroRazaoSocial;
  String? _erroTelefone;
  String? _erroDataNascimento;
  String? _erroDataFundacao;

  bool _aceitouTermos = false;
  bool _aceitouPrivacidade = false;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.nomeGoogle ?? '');

    _telefoneFocusNode.addListener(() {
      if (!_telefoneFocusNode.hasFocus && _telefoneController.text.isNotEmpty) {
        _verificarTelefoneDuplicado();
      }
    });
    _cnpjFocusNode.addListener(() {
      if (!_cnpjFocusNode.hasFocus && !_isPessoaFisica) {
        _autoPreencherDadosCnpj();
      }
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _cpfController.dispose();
    _cnpjController.dispose();
    _razaoSocialController.dispose();
    _nomeFantasiaController.dispose();
    _telefoneController.dispose();
    _dataNascimentoController.dispose();
    _dataFundacaoController.dispose();
    _telefoneFocusNode.dispose();
    _cnpjFocusNode.dispose();
    super.dispose();
  }

  Future<void> _verificarTelefoneDuplicado() async {
    final apenasNumeros = _telefoneController.text.replaceAll(RegExp(r'\D'), '');
    if (apenasNumeros.length < 10) return;

    // Valida estrutura do telefone antes de verificar duplicidade
    final validacao = validarTelefoneCompleto(_telefoneController.text);
    if (!validacao.valido) {
      if (mounted) {
        setState(() => _erroTelefone = validacao.erro);
      }
      return;
    }

    final ddd = apenasNumeros.substring(0, 2);
    final numero = apenasNumeros.substring(2);
    try {
      final list = await Supabase.instance.client
          .from('telefones')
          .select('numero')
          .eq('ddd', ddd)
          .eq('numero', numero);
      if (list.isNotEmpty && mounted) {
        setState(() => _erroTelefone = 'Este telefone já está cadastrado.');
      }
    } catch (_) {}
  }

  Future<void> _autoPreencherDadosCnpj() async {
    final doc = _somenteDigitos(_cnpjController.text);
    if (doc.length < 14 || !_validarCnpjLocal(doc)) return;
    try {
      final response =
          await http.get(Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$doc'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final razaoSocial = data['razao_social'] as String?;
        final nomeFantasia = data['nome_fantasia'] as String?;
        if (razaoSocial != null && razaoSocial.isNotEmpty) {
          _razaoSocialController.text = razaoSocial;
        }
        if (nomeFantasia != null && nomeFantasia.isNotEmpty) {
          _nomeFantasiaController.text = nomeFantasia;
        }
      }
    } catch (_) {}
  }

  Future<bool> _validarDocumento() async {
    final doc = _somenteDigitos(
      _isPessoaFisica ? _cpfController.text : _cnpjController.text,
    );

    if (doc.isEmpty) {
      setState(() {
        if (_isPessoaFisica) {
          _erroCpf = 'O CPF é obrigatório';
        } else {
          _erroCnpj = 'O CNPJ é obrigatório';
        }
      });
      return false;
    }

    if (_isPessoaFisica) {
      final valido = _validarCpfLocal(doc);
      setState(() {
        _erroCpf = valido ? null : 'O CPF não corresponde a um CPF real.';
        _documentoValido = valido;
      });
      return valido;
    }

    if (!_validarCnpjLocal(doc)) {
      setState(() {
        _erroCnpj = 'O CNPJ não corresponde a um CNPJ real.';
        _documentoValido = false;
      });
      return false;
    }

    setState(() => _validandoDocumento = true);
    try {
      final response =
          await http.get(Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$doc'));
      final encontrado = response.statusCode == 200;
      setState(() {
        _erroCnpj = encontrado ? null : 'O CNPJ não foi encontrado na BrasilAPI.';
        _documentoValido = encontrado;
      });
      return encontrado;
    } catch (_) {
      setState(() {
        _erroCnpj = 'Não foi possível validar o CNPJ agora.';
        _documentoValido = false;
      });
      return false;
    } finally {
      if (mounted) setState(() => _validandoDocumento = false);
    }
  }

  Future<void> _fazerUploadDataNascimento() async {
    final dataSelecionada = await showDatePicker(
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
      final dia = dataSelecionada.day.toString().padLeft(2, '0');
      final mes = dataSelecionada.month.toString().padLeft(2, '0');
      final ano = dataSelecionada.year.toString();
      setState(() {
        _dataNascimentoController.text = '$ano-$mes-$dia';
        _erroDataNascimento = null;
      });
    }
  }

  Future<void> _fazerUploadDataFundacao() async {
    final dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      firstDate: DateTime(1900),
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
      final dia = dataSelecionada.day.toString().padLeft(2, '0');
      final mes = dataSelecionada.month.toString().padLeft(2, '0');
      final ano = dataSelecionada.year.toString();
      setState(() {
        _dataFundacaoController.text = '$ano-$mes-$dia';
        _erroDataFundacao = null;
      });
    }
  }

  Future<void> _finalizarCadastro() async {
    setState(() {
      _erroNome = _nomeController.text.trim().isEmpty ? 'O nome é obrigatório' : null;
      
      // Email OU Telefone: pelo menos 1 é obrigatório
      final emailVazio = widget.emailGoogle.trim().isEmpty;
      final telefoneVazio = _telefoneController.text.trim().isEmpty;
      if (emailVazio && telefoneVazio) {
        _erroTelefone = 'Informe email ou telefone';
      } else if (!telefoneVazio) {
        // Valida estrutura do telefone
        final validacao = validarTelefoneCompleto(_telefoneController.text);
        _erroTelefone = validacao.valido ? null : validacao.erro;
      } else {
        _erroTelefone = null;
      }

      if (_isPessoaFisica) {
        _erroDataNascimento = _dataNascimentoController.text.trim().isEmpty
            ? 'A data de nascimento é obrigatória'
            : null;
        _erroRazaoSocial = null;
        _erroDataFundacao = null;
      } else {
        _erroRazaoSocial = _razaoSocialController.text.trim().isEmpty
            ? 'A Razão Social é obrigatória'
            : null;
        _erroDataNascimento = null;
        // Se for PJ com imóvel, exige data de fundação
        _erroDataFundacao = (!_cnpjDeEmpresa &&
                _dataFundacaoController.text.trim().isEmpty)
            ? 'A data de fundação é obrigatória'
            : null;
      }
    });

    if (!_aceitouTermos || !_aceitouPrivacidade) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aceite os Termos de Uso e a Política de Privacidade.'),
        ),
      );
      return;
    }

    if (_erroNome != null ||
        _erroTelefone != null ||
        _erroDataNascimento != null ||
        _erroRazaoSocial != null ||
        _erroDataFundacao != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios.')),
      );
      return;
    }

    final documentoOk = await _validarDocumento();
    if (!documentoOk) return;

    setState(() => _carregando = true);
    final supabase = Supabase.instance.client;

    try {
      final emailResponse = await supabase
          .from('emails')
          .insert({'endereco_email': widget.emailGoogle, 'fk_status': 1})
          .select()
          .single();
      final emailId = emailResponse['id_email'];

      final telefoneLimpo = _telefoneController.text.replaceAll(RegExp(r'\D'), '');
      final ddd = telefoneLimpo.length >= 2 ? telefoneLimpo.substring(0, 2) : '';
      final numero =
          telefoneLimpo.length > 2 ? telefoneLimpo.substring(2) : telefoneLimpo;

      final telefoneResponse = await supabase
          .from('telefones')
          .insert({'ddd': ddd, 'numero': numero, 'fk_status': 1})
          .select()
          .single();
      final telefoneId = telefoneResponse['id_telefone'];

      int assTipoPessoaId;
      if (_isPessoaFisica) {
        final cpfLimpo = _somenteDigitos(_cpfController.text);
        final pfResponse = await supabase
            .from('pessoa_fisica')
            .insert({'cpf': cpfLimpo})
            .select()
            .single();
        final assResponse = await supabase
            .from('ass_tipo_pessoa')
            .insert({
              'tipo': 'Física',
              'fk_pessoa_fisica': pfResponse['id_pessoa_fisica'],
              'fk_pessoa_juridica': null,
            })
            .select()
            .single();
        assTipoPessoaId = assResponse['id_tipo_pessoa'];
      } else {
        final cnpjLimpo = _somenteDigitos(_cnpjController.text);
        final pjResponse = await supabase
            .from('pessoa_juridica')
            .insert({
              'cnpj': cnpjLimpo,
              'razao_social': _razaoSocialController.text.trim(),
              'nome_fantasia': _nomeFantasiaController.text.trim(),
              'tem_imovel': !_cnpjDeEmpresa,
              'data_fundacao': _dataFundacaoController.text.trim().isNotEmpty
                  ? _dataFundacaoController.text.trim()
                  : null,
            })
            .select()
            .single();
        final assResponse = await supabase
            .from('ass_tipo_pessoa')
            .insert({
              'tipo': 'Pessoa Jurídica',
              'fk_pessoa_fisica': null,
              'fk_pessoa_juridica': pjResponse['id_pessoa_juridica'],
            })
            .select()
            .single();
        assTipoPessoaId = assResponse['id_tipo_pessoa'];
      }

      await supabase.from('usuarios').insert({
        'nome': _isPessoaFisica
            ? _nomeController.text.trim()
            : _nomeFantasiaController.text.trim(),
        'data_nascimento': _dataNascimentoController.text.trim().isNotEmpty
            ? _dataNascimentoController.text.trim()
            : null,
        'data_criacao': DateTime.now().toUtc().toIso8601String(),
        'tipo_conta': 'Cliente',
        'fk_email': emailId,
        'fk_telefone': telefoneId,
        'fk_tipo_pessoa': assTipoPessoaId,
        'foto_perfil_url': widget.fotoUrlGoogle ?? 'null',
        'auth_id': widget.authId,
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => TelaHome(isVisitante: false)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao concluir cadastro: ${e.toString().replaceAll('Exception: ', '')}',
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
        title: const Text(
          'Complete seu cadastro',
          style: TextStyle(
            color: Color(0xFF00A2FF),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.fotoUrlGoogle != null)
              Center(
                child: FotoPerfilGoogle(
                  fotoUrl: widget.fotoUrlGoogle,
                  radius: 40,
                ),
              ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                widget.emailGoogle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Só precisamos de mais alguns dados pra finalizar sua conta de Cliente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 28),

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
                          'Física',
                          style: TextStyle(
                            color: _isPessoaFisica
                                ? Colors.white
                                : const Color(0xFF828282),
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
                          'Jurídica',
                          style: TextStyle(
                            color: !_isPessoaFisica
                                ? Colors.white
                                : const Color(0xFF828282),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isPessoaFisica) ...[
              _CampoTexto(
                label: 'CPF',
                controller: _cpfController,
                keyboardType: TextInputType.number,
                inputFormatters: [_MaskedInputFormatter('###.###.###-##')],
                errorText: _erroCpf,
              ),
              _CampoTexto(label: 'Nome completo', controller: _nomeController, errorText: _erroNome),
              _CampoTexto(
                label: 'Data de Nascimento',
                controller: _dataNascimentoController,
                readOnly: true,
                onTap: _fazerUploadDataNascimento,
                suffixIcon: Icons.calendar_month,
                errorText: _erroDataNascimento,
              ),
            ] else ...[
              _CampoTexto(
                label: 'CNPJ',
                controller: _cnpjController,
                keyboardType: TextInputType.number,
                inputFormatters: [_MaskedInputFormatter('##.###.###/####-##')],
                focusNode: _cnpjFocusNode,
                errorText: _erroCnpj,
              ),
              _CampoTexto(
                label: 'Nome Fantasia',
                controller: _nomeFantasiaController,
              ),
              _CampoTexto(
                label: 'Razão Social',
                controller: _razaoSocialController,
                errorText: _erroRazaoSocial,
              ),
              if (!_cnpjDeEmpresa) ...[
                _CampoTexto(
                  label: 'Data de Fundação',
                  controller: _dataFundacaoController,
                  readOnly: true,
                  onTap: _fazerUploadDataFundacao,
                  suffixIcon: Icons.calendar_month,
                  errorText: _erroDataFundacao,
                ),
              ],
            ],

            _CampoTexto(
              label: 'Telefone',
              controller: _telefoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [_MaskedInputFormatter('(##) #####-####')],
              focusNode: _telefoneFocusNode,
              errorText: _erroTelefone,
              prefixWidget: SeletorDDI(
                ddiInicial: _ddiSelecionado,
                corPrimaria: const Color(0xFF00A2FF),
                onChanged: (ddi) {
                  setState(() => _ddiSelecionado = ddi);
                  if (_erroTelefone != null) {
                    setState(() => _erroTelefone = null);
                  }
                },
              ),
            ),

            const SizedBox(height: 12),
            CheckboxListTile(
              value: _aceitouTermos,
              onChanged: (v) => setState(() => _aceitouTermos = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Li e aceito os Termos de Uso'),
            ),
            CheckboxListTile(
              value: _aceitouPrivacidade,
              onChanged: (v) => setState(() => _aceitouPrivacidade = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Li e aceito a Política de Privacidade'),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: (_carregando || _validandoDocumento) ? null : _finalizarCadastro,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _carregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Finalizar Cadastro',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// PÁGINA: COMPLETAR CADASTRO — PROFISSIONAL, ETAPA 1 (dados pessoais)
// =========================================================================
class CompletarCadastroProfissionalPage extends StatefulWidget {
  final String authId;
  final String emailGoogle;
  final String? nomeGoogle;
  final String? fotoUrlGoogle;

  const CompletarCadastroProfissionalPage({
    super.key,
    required this.authId,
    required this.emailGoogle,
    this.nomeGoogle,
    this.fotoUrlGoogle,
  });

  @override
  State<CompletarCadastroProfissionalPage> createState() =>
      _CompletarCadastroProfissionalPageState();
}

class _CompletarCadastroProfissionalPageState
    extends State<CompletarCadastroProfissionalPage> {
  bool _isPessoaFisica = true;
  final bool _cnpjDeEmpresa = true;
  bool _documentoValido = false;

  late final TextEditingController _nomeController;
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _cnpjController = TextEditingController();
  final TextEditingController _razaoSocialController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _dataNascimentoController = TextEditingController();
  final TextEditingController _atuacaoController = TextEditingController();

  bool _carregandoOficios = true;
  List<Map<String, dynamic>> _oficios = [];
  final List<Map<String, dynamic>> _oficiosSelecionados = [];
  bool _showAtuacaoDropdown = false;

  String? _erroNome, _erroCpf, _erroCnpj, _erroRazaoSocial, _erroTelefone,
      _erroDataNascimento, _erroAtuacao;
  String _ddiSelecionado = '+55';

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.nomeGoogle ?? '');
    _carregarOficios();
  }

  Future<void> _carregarOficios() async {
    try {
      final response = await Supabase.instance.client
          .from('oficios')
          .select('id_oficio, funcao')
          .order('funcao');
      if (mounted) {
        setState(() {
          _oficios = List<Map<String, dynamic>>.from(response);
          _carregandoOficios = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregandoOficios = false);
    }
  }

  void _atualizarTextoAtuacao() {
    _atuacaoController.text =
        _oficiosSelecionados.map((e) => e['funcao']).join(', ');
    if (_oficiosSelecionados.isNotEmpty) _erroAtuacao = null;
  }

  Future<bool> _validarDocumento() async {
    final doc = _somenteDigitos(_isPessoaFisica ? _cpfController.text : _cnpjController.text);
    if (doc.isEmpty) {
      setState(() {
        if (_isPessoaFisica) {
          _erroCpf = 'O CPF é obrigatório';
        } else {
          _erroCnpj = 'O CNPJ é obrigatório';
        }
      });
      return false;
    }
    if (_isPessoaFisica) {
      final valido = _validarCpfLocal(doc);
      setState(() {
        _erroCpf = valido ? null : 'O CPF não corresponde a um CPF real.';
        _documentoValido = valido;
      });
      return valido;
    }
    final valido = _validarCnpjLocal(doc);
    setState(() {
      _erroCnpj = valido ? null : 'O CNPJ não corresponde a um CNPJ real.';
      _documentoValido = valido;
    });
    return valido;
  }

  Future<void> _fazerUploadDataNascimento() async {
    final dataSelecionada = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );
    if (dataSelecionada != null) {
      final dia = dataSelecionada.day.toString().padLeft(2, '0');
      final mes = dataSelecionada.month.toString().padLeft(2, '0');
      final ano = dataSelecionada.year.toString();
      setState(() {
        _dataNascimentoController.text = '$ano-$mes-$dia';
        _erroDataNascimento = null;
      });
    }
  }

  Future<void> _continuar() async {
    setState(() {
      _erroNome = _nomeController.text.trim().isEmpty ? 'O nome é obrigatório' : null;
      _erroTelefone = _telefoneController.text.trim().isEmpty
          ? 'O telefone é obrigatório'
          : (validarTelefoneCompleto(_telefoneController.text).valido
                ? null
                : validarTelefoneCompleto(_telefoneController.text).erro);
      _erroDataNascimento =
          _dataNascimentoController.text.trim().isEmpty ? 'A data de nascimento é obrigatória' : null;
      _erroAtuacao = _oficiosSelecionados.isEmpty ? 'Selecione pelo menos 1 área de atuação' : null;
      if (!_isPessoaFisica) {
        _erroRazaoSocial =
            _razaoSocialController.text.trim().isEmpty ? 'A Razão Social é obrigatória' : null;
      } else {
        _erroRazaoSocial = null;
      }
    });

    final documentoOk = await _validarDocumento();

    if (_erroNome != null ||
        _erroTelefone != null ||
        _erroDataNascimento != null ||
        _erroAtuacao != null ||
        _erroRazaoSocial != null ||
        !documentoOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos obrigatórios corretamente.')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompletarCadastroProfissionalDocumentosPage(
          authId: widget.authId,
          emailGoogle: widget.emailGoogle,
          fotoUrlGoogle: widget.fotoUrlGoogle,
          nome: _isPessoaFisica ? _nomeController.text.trim() : _nomeController.text.trim(),
          cpf: _isPessoaFisica ? _cpfController.text.trim() : null,
          cnpj: !_isPessoaFisica ? _cnpjController.text.trim() : null,
          razaoSocial: !_isPessoaFisica ? _razaoSocialController.text.trim() : null,
          isPessoaFisica: _isPessoaFisica,
          cnpjDeEmpresa: _cnpjDeEmpresa,
          telefone: _telefoneController.text.trim(),
          dataNascimento: _dataNascimentoController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Complete seu cadastro',
          style: TextStyle(color: Color(0xFF00A2FF), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.fotoUrlGoogle != null)
              Center(
                child: FotoPerfilGoogle(
                  fotoUrl: widget.fotoUrlGoogle,
                  radius: 40,
                ),
              ),
            const SizedBox(height: 12),
            Center(
              child: Text(widget.emailGoogle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            ),
            const SizedBox(height: 24),

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
                          color: _isPessoaFisica ? const Color(0xFF00A2FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text('Física',
                            style: TextStyle(
                                color: _isPessoaFisica ? Colors.white : const Color(0xFF828282),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isPessoaFisica = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: !_isPessoaFisica ? const Color(0xFF00A2FF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text('Pessoa Jurídica',
                            style: TextStyle(
                                color: !_isPessoaFisica ? Colors.white : const Color(0xFF828282),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isPessoaFisica) ...[
              _CampoTexto(
                label: 'CPF',
                controller: _cpfController,
                keyboardType: TextInputType.number,
                inputFormatters: [_MaskedInputFormatter('###.###.###-##')],
                errorText: _erroCpf,
              ),
              _CampoTexto(label: 'Nome completo', controller: _nomeController, errorText: _erroNome),
            ] else ...[
              _CampoTexto(
                label: 'CNPJ',
                controller: _cnpjController,
                keyboardType: TextInputType.number,
                inputFormatters: [_MaskedInputFormatter('##.###.###/####-##')],
                errorText: _erroCnpj,
              ),
              _CampoTexto(label: 'Nome Fantasia', controller: _nomeController, errorText: _erroNome),
              _CampoTexto(label: 'Razão Social', controller: _razaoSocialController, errorText: _erroRazaoSocial),
            ],

            _CampoTexto(
              label: 'Telefone',
              controller: _telefoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [_MaskedInputFormatter('(##) #####-####')],
              errorText: _erroTelefone,
              prefixWidget: SeletorDDI(
                ddiInicial: _ddiSelecionado,
                corPrimaria: const Color(0xFF00A2FF),
                onChanged: (ddi) {
                  setState(() => _ddiSelecionado = ddi);
                  if (_erroTelefone != null) {
                    setState(() => _erroTelefone = null);
                  }
                },
              ),
            ),

            _CampoTexto(
              label: 'Data de Nascimento',
              controller: _dataNascimentoController,
              readOnly: true,
              onTap: _fazerUploadDataNascimento,
              suffixIcon: Icons.calendar_month,
              errorText: _erroDataNascimento,
            ),

            _CampoTexto(
              label: 'Áreas de Atuação (até 3)',
              controller: _atuacaoController,
              readOnly: true,
              suffixIcon: _showAtuacaoDropdown ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              onTap: () => setState(() => _showAtuacaoDropdown = !_showAtuacaoDropdown),
              errorText: _erroAtuacao,
            ),

            if (_showAtuacaoDropdown)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 250),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00A2FF), width: 1.5),
                ),
                child: _carregandoOficios
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: Color(0xFF00A2FF)),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _oficios.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final oficio = _oficios[index];
                          final isSelected = _oficiosSelecionados
                              .any((e) => e['id_oficio'] == oficio['id_oficio']);
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(oficio['funcao'] ?? ''),
                            activeColor: const Color(0xFF00A2FF),
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  if (_oficiosSelecionados.length >= 3) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Máximo de 3 áreas.')),
                                    );
                                    return;
                                  }
                                  _oficiosSelecionados.add(oficio);
                                } else {
                                  _oficiosSelecionados
                                      .removeWhere((e) => e['id_oficio'] == oficio['id_oficio']);
                                }
                                _atualizarTextoAtuacao();
                              });
                            },
                          );
                        },
                      ),
              ),

            const SizedBox(height: 12),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _continuar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Continuar',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// PÁGINA: COMPLETAR CADASTRO — PROFISSIONAL, ETAPA 2 (documentos + facial)
// Equivalente à CadastroProfissionalEtapa3Page original, mas sem signUp
// (o usuário já está autenticado via Google).
// =========================================================================
class CompletarCadastroProfissionalDocumentosPage extends StatefulWidget {
  final String authId;
  final String emailGoogle;
  final String? fotoUrlGoogle;
  final String nome;
  final String? cpf;
  final String? cnpj;
  final String? razaoSocial;
  final bool isPessoaFisica;
  final bool cnpjDeEmpresa;
  final String telefone;
  final String dataNascimento;

  const CompletarCadastroProfissionalDocumentosPage({
    super.key,
    required this.authId,
    required this.emailGoogle,
    this.fotoUrlGoogle,
    required this.nome,
    this.cpf,
    this.cnpj,
    this.razaoSocial,
    required this.isPessoaFisica,
    required this.cnpjDeEmpresa,
    required this.telefone,
    required this.dataNascimento,
  });

  @override
  State<CompletarCadastroProfissionalDocumentosPage> createState() =>
      _CompletarCadastroProfissionalDocumentosPageState();
}

class _CompletarCadastroProfissionalDocumentosPageState
    extends State<CompletarCadastroProfissionalDocumentosPage> {
  bool _documentoIdentidadeConcluido = false;
  bool _termosDeUso = false;
  bool _politicaPrivacidade = false;
  bool _carregando = false;
  String? _idFacial;
  List<Map<String, dynamic>> _documentosValidados = [];

  bool get _cadastroFacialConcluido => _idFacial != null && _idFacial!.isNotEmpty;

  Future<void> _finalizarCadastroBanco() async {
    if (_documentosValidados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anexe e valide pelo menos 1 documento de identidade!')),
      );
      return;
    }

    setState(() => _carregando = true);
    final supabase = Supabase.instance.client;

    try {
      final emailResponse = await supabase
          .from('emails')
          .insert({'endereco_email': widget.emailGoogle, 'fk_status': 1})
          .select()
          .single();
      final emailId = emailResponse['id_email'];

      final telefoneLimpo = widget.telefone.replaceAll(RegExp(r'\D'), '');
      final ddd = telefoneLimpo.length >= 2 ? telefoneLimpo.substring(0, 2) : '';
      final numero = telefoneLimpo.length > 2 ? telefoneLimpo.substring(2) : telefoneLimpo;

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
            .insert({'cpf': cpfLimpo})
            .select()
            .single();
        final assResponse = await supabase
            .from('ass_tipo_pessoa')
            .insert({
              'tipo': 'Física',
              'fk_pessoa_fisica': pfResponse['id_pessoa_fisica'],
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
              'cnpj': cnpjLimpo,
              'razao_social': widget.razaoSocial,
              'nome_fantasia': widget.nome,
              'tem_imovel': !widget.cnpjDeEmpresa,
            })
            .select()
            .single();
        final assResponse = await supabase
            .from('ass_tipo_pessoa')
            .insert({
              'tipo': 'Pessoa Jurídica',
              'fk_pessoa_fisica': null,
              'fk_pessoa_juridica': pjResponse['id_pessoa_juridica'],
            })
            .select()
            .single();
        assTipoPessoaId = assResponse['id_tipo_pessoa'];
      }

      final usuarioResponse = await supabase
          .from('usuarios')
          .insert({
            'nome': widget.nome,
            'data_nascimento': widget.dataNascimento.isNotEmpty ? widget.dataNascimento : null,
            'data_criacao': DateTime.now().toUtc().toIso8601String(),
            'tipo_conta': 'Profissional',
            'fk_email': emailId,
            'fk_telefone': telefoneId,
            'fk_tipo_pessoa': assTipoPessoaId,
            'foto_perfil_url': widget.fotoUrlGoogle ?? 'null',
            'auth_id': widget.authId,
          })
          .select()
          .single();
      final usuarioId = usuarioResponse['id_usuario'];

      if (!_cadastroFacialConcluido) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Faça o cadastro facial antes de finalizar.')),
          );
        }
        setState(() => _carregando = false);
        return;
      }

      final dadosProfResponse = await supabase
          .from('dados_profissionais')
          .insert({'fk_usuario': usuarioId, 'id_facial': _idFacial})
          .select()
          .single();
      final profissionalId = dadosProfResponse['id_profissional'];

      for (final doc in _documentosValidados) {
        await supabase.from('documentos_profissionais').insert({
          'tipo_documento': doc['tipo'],
          'fk_profissional': profissionalId,
          'validacao_documento': true,
        });
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => TelaHomeProfissional(isVisitante: false)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao concluir cadastro: ${e.toString().replaceAll('Exception: ', '')}',
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
        title: const Text(
          'Documentos',
          style: TextStyle(color: Color(0xFF00A2FF), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.fotoUrlGoogle != null)
              Center(
                child: FotoPerfilGoogle(
                  fotoUrl: widget.fotoUrlGoogle,
                  radius: 40,
                ),
              ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                widget.emailGoogle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Agora só precisamos de alguns documentos para terminarmos o seu cadastro!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF00A2FF), fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),

            _botaoDocumento(
              label: 'Cadastro Facial',
              concluido: _cadastroFacialConcluido,
              onTap: () async {
                final resultado = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const CadastroFacialInstrucoesPage()),
                );
                if (resultado != null && mounted) setState(() => _idFacial = resultado);
              },
            ),
            _botaoDocumento(
              label: 'Documento de Identidade',
              concluido: _documentoIdentidadeConcluido,
              onTap: () async {
                final resultado = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ValidacaoDocsPage(
                      cpf: widget.cpf,
                      dataNascimento: widget.dataNascimento,
                    ),
                  ),
                );
                if (resultado != null && resultado['validado'] == true && mounted) {
                  setState(() {
                    _documentoIdentidadeConcluido = true;
                    _documentosValidados =
                        List<Map<String, dynamic>>.from(resultado['docsData'] ?? []);
                  });
                }
              },
            ),

            const SizedBox(height: 20),
            CheckboxListTile(
              value: _termosDeUso,
              onChanged: (v) => setState(() => _termosDeUso = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Li e aceito os Termos de Uso'),
            ),
            CheckboxListTile(
              value: _politicaPrivacidade,
              onChanged: (v) => setState(() => _politicaPrivacidade = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('Li e aceito a Política de Privacidade'),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: (_termosDeUso &&
                        _politicaPrivacidade &&
                        _cadastroFacialConcluido &&
                        _documentoIdentidadeConcluido &&
                        !_carregando)
                    ? _finalizarCadastroBanco
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2FF),
                  disabledBackgroundColor: const Color(0xFF00A2FF).withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _carregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Finalizar Cadastro',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _botaoDocumento({
    required String label,
    required bool concluido,
    required VoidCallback onTap,
  }) {
    final cor = concluido ? const Color(0xFF2EAD5B) : const Color(0xFF00A2FF);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor, width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: cor, fontSize: 16, fontWeight: FontWeight.bold)),
              Icon(concluido ? Icons.check_circle : Icons.arrow_forward, color: cor),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// WIDGETS AUXILIARES (privados deste arquivo, evitam conflito de nomes
// com as classes já existentes em cadastro_cliente.dart / cadastro_profissional.dart)
// =========================================================================
class _CampoTexto extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? suffixIcon;
  final Widget? prefixWidget;
  final FocusNode? focusNode;
  final String? errorText;

  const _CampoTexto({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.prefixWidget,
    this.focusNode,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          prefixIcon: prefixWidget,
          suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: const Color(0xFF00A2FF)) : null,
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00A2FF), width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _MaskedInputFormatter extends TextInputFormatter {
  final String mask;
  _MaskedInputFormatter(this.mask);

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
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
