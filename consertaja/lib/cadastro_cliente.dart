import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'tela_home.dart';
import 'services/google_auth_service.dart';
import 'services/validacao_telefone.dart';
import 'widgets/seletor_ddi.dart';
import 'completar_cadastro.dart';
import 'tela_home_profissional.dart';
import 'login.dart';

// ================= TELA: CADASTRO DO CLIENTE (ETAPA 1) =================
class CadastroClientePage extends StatefulWidget {
  final String? nome;
  final String? cpf;
  final String? cnpj;
  final String? razaoSocial;
  final String? nomeFantasia;
  final bool? isPessoaFisica;
  final bool? cnpjDeEmpresa;
  final String? email;
  final String? fotoPerfilUrl;

  const CadastroClientePage({
    super.key,
    this.nome,
    this.cpf,
    this.cnpj,
    this.razaoSocial,
    this.nomeFantasia,
    this.isPessoaFisica,
    this.cnpjDeEmpresa,
    this.email,
    this.fotoPerfilUrl,
  });

  @override
  State<CadastroClientePage> createState() => _CadastroClientePageState();
}

class _CadastroClientePageState extends State<CadastroClientePage> {
  late bool _isPessoaFisica;
  late bool _cnpjDeEmpresa;

  late TextEditingController _nomeController;
  late TextEditingController _cpfController;
  late TextEditingController _cnpjController;
  late TextEditingController _razaoSocialController;
  late TextEditingController _nomeFantasiaController;
  late TextEditingController _emailController;
  late TextEditingController _telefoneController;
  late TextEditingController _dataNascimentoController;
  late TextEditingController _dataFundacaoController;

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _telefoneFocusNode = FocusNode();
  final FocusNode _cnpjFocusNode = FocusNode();
  String _ddiSelecionado = '+55';

  bool _validandoDocumento = false;
  bool _documentoValido = false;

  String? _erroNome;
  String? _erroNomeFantasia;
  String? _erroCpf;
  String? _erroCnpj;
  String? _erroRazaoSocial;
  String? _erroEmail;
  String? _erroTelefone;
  String? _erroDataNascimento;
  String? _erroDataFundacao;

  bool _carregandoGoogle = false;

Future<void> _continuarComGoogle() async {
  setState(() => _carregandoGoogle = true);
  try {
    final user = await GoogleAuthService.signInWithGoogle();
    if (user == null || !mounted) return;

    final perfil = await GoogleAuthService.buscarPerfil(user.id);
    if (!mounted) return;

    if (perfil != null) {
      final isProfissional = perfil['tipo_conta'] == 'Profissional';
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => isProfissional
              ? TelaHomeProfissional(isVisitante: false)
              : TelaHome(isVisitante: false),
        ),
        (route) => false,
      );
      return;
    }

    final fotoUrl = (user.userMetadata?['avatar_url'] as String?) ??
        GoogleAuthService.ultimaFotoUrl;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CompletarCadastroClientePage(
          authId: user.id,
          emailGoogle: user.email ?? '',
          nomeGoogle: user.userMetadata?['full_name'] as String?,
          fotoUrlGoogle: fotoUrl,
        ),
      ),
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao entrar com Google: $e')));
    }
  } finally {
    if (mounted) setState(() => _carregandoGoogle = false);
  }
}

  @override
  void initState() {
    super.initState();

    _isPessoaFisica = widget.isPessoaFisica ?? true;
    _cnpjDeEmpresa = widget.cnpjDeEmpresa ?? true;

    _nomeController = TextEditingController(text: widget.nome ?? '');
    _cpfController = TextEditingController(text: widget.cpf ?? '');
    _cnpjController = TextEditingController(text: widget.cnpj ?? '');
    _razaoSocialController = TextEditingController(text: widget.razaoSocial ?? '');
    _nomeFantasiaController = TextEditingController(text: widget.nomeFantasia ?? '');
    _emailController = TextEditingController();
    _telefoneController = TextEditingController();
    _dataNascimentoController = TextEditingController();
    _dataFundacaoController = TextEditingController();

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
    _cnpjController.addListener(() {
      if (_cnpjController.text.isNotEmpty && _erroCnpj != null) {
        setState(() => _erroCnpj = null);
      }
    });
    _razaoSocialController.addListener(() {
      if (_razaoSocialController.text.isNotEmpty && _erroRazaoSocial != null) {
        setState(() => _erroRazaoSocial = null);
      }
    });
    _nomeFantasiaController.addListener(() {
      if (_nomeFantasiaController.text.isNotEmpty && _erroNomeFantasia != null) {
        setState(() => _erroNomeFantasia = null);
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

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && _emailController.text.isNotEmpty) {
        _verificarEmailDuplicado();
      }
    });

    _telefoneFocusNode.addListener(() {
      if (!_telefoneFocusNode.hasFocus && _telefoneController.text.isNotEmpty) {
        _verificarTelefoneDuplicado();
      }
    });

    // Auto-preencher dados quando o CNPJ perder o foco e for válido
    _cnpjFocusNode.addListener(() {
      if (!_cnpjFocusNode.hasFocus && !_isPessoaFisica) {
        _autoPreencherDadosCnpj();
      }
    });
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _telefoneFocusNode.dispose();
    _cnpjFocusNode.dispose();
    _nomeController.dispose();
    _cpfController.dispose();
    _cnpjController.dispose();
    _razaoSocialController.dispose();
    _nomeFantasiaController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    _dataNascimentoController.dispose();
    _dataFundacaoController.dispose();
    super.dispose();
  }

  String _somenteDigitos(String valor) {
    return valor.replaceAll(RegExp(r'\D'), '');
  }

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

  Future<bool> _validarDocumentoDigitado({bool obrigatorio = false}) async {
    final documento = _isPessoaFisica
        ? _cpfController.text
        : _cnpjController.text;
    final doc = _somenteDigitos(documento);

    if (doc.isEmpty) {
      if (obrigatorio) {
        setState(() {
          if (_isPessoaFisica) {
            _erroCpf = 'O CPF é obrigatório';
          } else {
            _erroCnpj = 'O CNPJ é obrigatório';
          }
          _documentoValido = false;
        });
      }
      return false;
    }

    if (_isPessoaFisica) {
      if (doc.length < 11) {
        setState(() => _documentoValido = false);
        return false;
      }

      final valido = _validarCpfLocal(doc);

      setState(() {
        _erroCpf = valido ? null : 'O CPF não corresponde a um CPF real.';
        _documentoValido = valido;
      });

      return valido;
    }

    // Para CNPJ, valida localmente e depois consulta BrasilAPI
    if (doc.length < 14) {
      setState(() => _documentoValido = false);
      return false;
    }

    final validoLocal = _validarCnpjLocal(doc);
    if (!validoLocal) {
      setState(() {
        _erroCnpj = 'O CNPJ não corresponde a um CNPJ real.';
        _documentoValido = false;
      });
      return false;
    }

    setState(() => _validandoDocumento = true);

    try {
      final response = await http.get(
        Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$doc'),
      );

      final encontrado = response.statusCode == 200;

      if (encontrado) {
        final data = json.decode(response.body);
        final razaoSocial = data['razao_social'] as String?;
        final nomeFantasia = data['nome_fantasia'] as String?;

        if (razaoSocial != null && razaoSocial.isNotEmpty) {
          _razaoSocialController.text = razaoSocial;
          _erroRazaoSocial = null;
        }
        if (nomeFantasia != null && nomeFantasia.isNotEmpty) {
          _nomeFantasiaController.text = nomeFantasia;
          _erroNomeFantasia = null;
        }
      }

      setState(() {
        _erroCnpj = encontrado
            ? null
            : 'O CNPJ não foi encontrado na BrasilAPI.';
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
      setState(() => _validandoDocumento = false);
    }
  }

  // Função para verificar se o email já existe
  Future<void> _verificarEmailDuplicado() async {
    final email = _emailController.text.trim();

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      final list = await supabase
          .from('emails')
          .select('endereco_email')
          .eq('endereco_email', email);

      if (list.isNotEmpty) {
        setState(() {
          _erroEmail = 'Este e-mail já está em uso.';
        });
      }
    } catch (e) {
      debugPrint('Erro ao verificar email: $e');
    }
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

    final dddDigitado = apenasNumeros.substring(0, 2);
    final numeroDigitado = apenasNumeros.substring(2);

    try {
      final supabase = Supabase.instance.client;

      final list = await supabase
          .from('telefones')
          .select('numero')
          .eq('ddd', dddDigitado)
          .eq('numero', numeroDigitado);
      if (list.isNotEmpty) {
        setState(() {
          _erroTelefone = 'Este telefone já está cadastrado.';
        });
      }
    } catch (e) {
      debugPrint('Erro ao verificar telefone: $e');
    }
  }

  Future<void> _autoPreencherDadosCnpj() async {
    final doc = _somenteDigitos(_cnpjController.text);

    if (doc.length < 14) return;

    final valido = _validarCnpjLocal(doc);
    if (!valido) return;

    try {
      final response = await http.get(
        Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$doc'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final razaoSocial = data['razao_social'] as String?;
        final nomeFantasia = data['nome_fantasia'] as String?;
        final telefone = data['ddd_telefone'] as String?;

        if (razaoSocial != null && razaoSocial.isNotEmpty) {
          _razaoSocialController.text = razaoSocial;
        }
        if (nomeFantasia != null && nomeFantasia.isNotEmpty) {
          _nomeFantasiaController.text = nomeFantasia;
        }
        if (telefone != null && telefone.isNotEmpty) {
          final telefoneLimpo = telefone.replaceAll(RegExp(r'\D'), '');
          if (telefoneLimpo.length >= 10) {
            final ddd = telefoneLimpo.substring(0, 2);
            final numero = telefoneLimpo.substring(2);
            _telefoneController.text = '($ddd) $numero';
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao auto-preencher dados do CNPJ: $e');
    }
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

  Future<void> _fazerUploadDataFundacao() async {
    DateTime? dataSelecionada = await showDatePicker(
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
      String dia = dataSelecionada.day.toString().padLeft(2, '0');
      String mes = dataSelecionada.month.toString().padLeft(2, '0');
      String ano = dataSelecionada.year.toString();

      setState(() {
        _dataFundacaoController.text = '$ano-$mes-$dia';
        _erroDataFundacao = null;
      });
    }
  }

  Future<void> _continuarCadastro() async {
    setState(() {
      if (_isPessoaFisica) {
        _erroNome = _nomeController.text.trim().isEmpty
            ? 'O nome é obrigatório'
            : null;
        _erroCpf = _cpfController.text.trim().isEmpty
            ? 'O CPF é obrigatório'
            : null;
        _erroCnpj = null;
        _erroRazaoSocial = null;
        _erroNomeFantasia = null;
        _erroDataNascimento = _dataNascimentoController.text.trim().isEmpty
            ? 'A data de nascimento é obrigatória'
            : null;
        _erroDataFundacao = null;
      } else {
        _erroNomeFantasia = _nomeFantasiaController.text.trim().isEmpty
            ? 'O Nome Fantasia é obrigatório'
            : null;
        _erroCnpj = _cnpjController.text.trim().isEmpty
            ? 'O CNPJ é obrigatório'
            : null;
        _erroRazaoSocial = _razaoSocialController.text.trim().isEmpty
            ? 'A Razão Social é obrigatória'
            : null;
        _erroCpf = null;
        _erroNome = null;
        _erroDataNascimento = null;
        // Pessoa Jurídica sempre exige data de fundação
        _erroDataFundacao = _dataFundacaoController.text.trim().isEmpty
            ? 'A data de fundação é obrigatória'
            : null;
      }

      // Email OU Telefone: pelo menos 1 é obrigatório
      final emailVazio = _emailController.text.trim().isEmpty;
      final telefoneVazio = _telefoneController.text.trim().isEmpty;

      if (emailVazio && telefoneVazio) {
        _erroEmail = 'Informe email ou telefone';
        _erroTelefone = 'Informe email ou telefone';
      } else if (!telefoneVazio) {
        // Valida estrutura do telefone
        final validacao = validarTelefoneCompleto(_telefoneController.text);
        _erroTelefone = validacao.valido ? null : validacao.erro;
        _erroEmail = null;
      } else {
        _erroEmail = null;
        _erroTelefone = null;
      }
    });

    if (_erroNome != null ||
        _erroCpf != null ||
        _erroCnpj != null ||
        _erroRazaoSocial != null ||
        _erroNomeFantasia != null ||
        _erroEmail != null ||
        _erroTelefone != null ||
        _erroDataNascimento != null ||
        _erroDataFundacao != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, preencha todos os campos obrigatórios.',
          ),
        ),
      );
      return;
    }

    // Valida CPF ou CNPJ antes de continuar
    final documentoValido = await _validarDocumentoDigitado(obrigatorio: true);

    if (!documentoValido) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroClienteEtapa2Page(
          nome: _isPessoaFisica
              ? _nomeController.text.trim()
              : _nomeFantasiaController.text.trim(),
          cpf: _isPessoaFisica ? _cpfController.text.trim() : null,
          cnpj: !_isPessoaFisica ? _cnpjController.text.trim() : null,
          razaoSocial: !_isPessoaFisica ? _razaoSocialController.text.trim() : null,
          nomeFantasia: !_isPessoaFisica ? _nomeFantasiaController.text.trim() : null,
          isPessoaFisica: _isPessoaFisica,
          cnpjDeEmpresa: _cnpjDeEmpresa,
          email: _emailController.text.trim(),
          telefone: _telefoneController.text.trim(),
          dataNascimento: _dataNascimentoController.text.trim(),
          dataFundacao: _dataFundacaoController.text.trim(),
          fotoPerfilUrl: widget.fotoPerfilUrl ?? 'null',
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

            // Slider container for pessoa física/juridica
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
                        _erroCpf = null;
                        _erroNomeFantasia = null;
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
                        _erroRazaoSocial = null;
                        _erroNomeFantasia = null;
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
            ] else ...[
              _InputFieldWithAnimation(
                label: 'CNPJ',
                hint: '__.___.___/____-__',
                keyboardType: TextInputType.number,
                inputFormatters: [MaskedInputFormatter('##.###.###/####-##')],
                controller: _cnpjController,
                errorText: _erroCnpj,
                focusNode: _cnpjFocusNode,
              ),
              const SizedBox(height: 10),
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
            ],

            if (_isPessoaFisica) ...[
              _InputFieldWithAnimation(
                label: 'Nome completo',
                hint: 'Nome completo',
                keyboardType: TextInputType.name,
                controller: _nomeController,
                errorText: _erroNome,
              ),
            ] else ...[
              _InputFieldWithAnimation(
                label: 'Nome Fantasia',
                hint: 'Nome Fantasia',
                keyboardType: TextInputType.name,
                controller: _nomeFantasiaController,
                errorText: _erroNomeFantasia,
              ),
            ],

            if (!_isPessoaFisica) ...[
              _InputFieldWithAnimation(
                label: 'Razão Social',
                hint: 'Razão Social',
                controller: _razaoSocialController,
                errorText: _erroRazaoSocial,
              ),
            ],

            if (!_isPessoaFisica) ...[
              _InputFieldWithAnimation(
                label: 'Data de Fundação',
                hint: 'AAAA-MM-DD',
                suffixIcon: Icons.calendar_month,
                controller: _dataFundacaoController,
                readOnly: true,
                onTap: _fazerUploadDataFundacao,
                onSuffixIconTap: _fazerUploadDataFundacao,
                errorText: _erroDataFundacao,
              ),
            ],

            _InputFieldWithAnimation(
              label: 'Email',
              hint: 'exemplo@email.com',
              keyboardType: TextInputType.emailAddress,
              controller: _emailController,
              errorText: _erroEmail,
              focusNode: _emailFocusNode,
            ),
            _InputFieldWithAnimation(
              label: 'Telefone',
              hint: '(__) _____-____',
              keyboardType: TextInputType.phone,
              inputFormatters: [MaskedInputFormatter('(##) #####-####')],
              controller: _telefoneController,
              errorText: _erroTelefone,
              focusNode: _telefoneFocusNode,
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
            
            if (_isPessoaFisica) ...[
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
            ],

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _continuarCadastro,
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
            Row(children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou', style: TextStyle(color: Colors.grey.shade500)),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: _carregandoGoogle ? null : _continuarComGoogle,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDADCE0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: _carregandoGoogle
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.g_mobiledata, size: 28, color: Colors.black87),
                label: Text(
                  _carregandoGoogle ? 'Conectando...' : 'Continuar com Google',
                  style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
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

// ================= COMPONENTE DE INPUT CUSTOMIZADO E ANIMADO =================
class _InputFieldWithAnimation extends StatefulWidget {
  final String label;
  final String hint;
  final IconData? suffixIcon;
  final Widget? prefixWidget;
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
    this.prefixWidget,
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
    Color labelColor = const Color(0xFF00A2FF).withValues(alpha: 0.5);
    Color backgroundColor = const Color(0xFFFAFAFA);

    if (hasError) {
      borderColor = Colors.red;
      labelColor = Colors.red;
      backgroundColor = Colors.red.withValues(alpha: 0.02);
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
                      ? const Color(0xFF00A2FF).withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.015),
                  blurRadius: _isFocused ? 8 : 4,
                  offset: _isFocused ? const Offset(0, 4) : const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (widget.prefixWidget != null) ...[
                  widget.prefixWidget!,
                  const SizedBox(width: 8),
                ],
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
                                  ? Colors.red.withValues(alpha: 0.4)
                                  : const Color(0xFF00A2FF).withValues(alpha: 0.4),
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
  final String? cpf;
  final String? cnpj;
  final String? razaoSocial;
  final String? nomeFantasia;
  final bool isPessoaFisica;
  final bool cnpjDeEmpresa;
  final String email;
  final String telefone;
  final String dataNascimento;
  final String dataFundacao;
  final String fotoPerfilUrl;

  const CadastroClienteEtapa2Page({
    super.key,
    required this.nome,
    this.cpf,
    this.cnpj,
    this.razaoSocial,
    this.nomeFantasia,
    required this.isPessoaFisica,
    required this.cnpjDeEmpresa,
    required this.email,
    required this.telefone,
    required this.dataNascimento,
    this.dataFundacao = '',
    required this.fotoPerfilUrl,
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
  bool get _temSimbolo => _senhaController.text.contains(RegExp(r'[^A-Za-z0-9\s]'));
  bool get _temNumero => _senhaController.text.contains(RegExp(r'[0-9]'));

  @override
  void initState() {
    super.initState();
    _senhaController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _finalizarCadastroBanco() async {
    // Validação local prévia dos requisitos da senha antes de mandar para o banco
    if (!_temOitoCaracteres ||
        !_temMaiuscula ||
        !_temMinuscula ||
        !_temSimbolo ||
        !_temNumero) {
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

      int? emailId;
      if (widget.email.isNotEmpty) {
        final emailResponse = await supabase
            .from('emails')
            .insert({'endereco_email': widget.email, 'fk_status': 1})
            .select()
            .single();
        emailId = emailResponse['id_email'];
      }

      int? telefoneId;
      if (widget.telefone.isNotEmpty) {
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
        telefoneId = telefoneResponse['id_telefone'];
      }

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
              'tipo': 'Física',
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
              'razao_social': widget.razaoSocial,
              'nome_fantasia': widget.nomeFantasia,
              'tem_imovel': !widget.cnpjDeEmpresa,
              'data_fundacao': widget.dataFundacao.isNotEmpty
                  ? widget.dataFundacao
                  : null,
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
        'foto_perfil_url': widget.fotoPerfilUrl,
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
      String mensagemAmigavel = 'Ocorreu um erro ao registrar.';

      if (e.toString().contains('AuthWeakPasswordException') ||
          e.message.toLowerCase().contains('password should be at least') ||
          e.statusCode == '422') {
        mensagemAmigavel =
            'Senha muito fraca! Garanta que ela possua no mínimo 8 caracteres, 1 maiúscula, 1 minúscula e 1 símbolo.';
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
                  _buildRequisitoItem(
                    'Pelo menos 1 número',
                    _temNumero,
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
                  ).withValues(alpha: 0.35),
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