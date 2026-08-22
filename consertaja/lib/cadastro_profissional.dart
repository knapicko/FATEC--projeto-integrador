import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;

import 'login.dart';

import 'tela_home_profissional.dart';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:image_picker/image_picker.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'services/google_auth_service.dart';
import 'services/validacao_telefone.dart';
import 'services/formatacao_data.dart';
import 'widgets/seletor_ddi.dart';
import 'widgets/dialogo_documento.dart';
import 'termos_de_uso.dart';
import 'politica_de_privacidade.dart';
import 'completar_cadastro.dart';
import 'tela_home.dart';

// ================= TELA 01: CADASTRO DO PROFISSIONAL (ETAPA 1) =================
class CadastroProfissionalPage extends StatefulWidget {
  final String? nome;
  final String? cpf;
  final String? cnpj;
  final String? razaoSocial;
  final String? senha;
  final bool? isPessoaFisica;
  final bool? cnpjDeEmpresa;
  final String? fotoPerfilUrl;
  final String? idFacial;
  final String? email;

  const CadastroProfissionalPage({
    super.key,
    this.nome,
    this.cpf,
    this.cnpj,
    this.razaoSocial,
    this.senha,
    this.isPessoaFisica,
    this.cnpjDeEmpresa,
    this.fotoPerfilUrl,
    this.idFacial,
    this.email,
  });

  @override
  State<CadastroProfissionalPage> createState() =>
      _CadastroProfissionalPageState();
}

class _CadastroProfissionalPageState extends State<CadastroProfissionalPage> {
  late bool _isPessoaFisica;
  late bool _cnpjDeEmpresa;

  late TextEditingController _nomeController;
  late TextEditingController _cpfController;
  late TextEditingController _cnpjController;
  late TextEditingController _razaoSocialController;
  late TextEditingController _nomeFantasiaController;
  late TextEditingController _senhaController;
  late TextEditingController _confirmarSenhaController;
  late TextEditingController _dataFundacaoController;

  String? _fotoPerfilUrl;

  String? _idFacial;

  // Estados de erro para os inputs
  String? _erroNome;
  String? _erroNomeFantasia;
  String? _erroCpf;
  String? _erroCnpj;
  String? _erroRazaoSocial;
  String? _erroSenha;
  String? _erroConfirmarSenha;
  String? _erroDataFundacao;

  bool _validandoDocumento = false;
  bool _documentoValido = false;

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

      final fotoUrl =
          (user.userMetadata?['avatar_url'] as String?) ??
          GoogleAuthService.ultimaFotoUrl;

      // >>> AQUI, no lugar do que ia pra CompletarCadastroClientePage <
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompletarCadastroProfissionalPage(
            authId: user.id,
            emailGoogle: user.email ?? '',
            nomeGoogle: user.userMetadata?['full_name'] as String?,
            fotoUrlGoogle: fotoUrl,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao entrar com Google: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _carregandoGoogle = false);
    }
  }

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

    _isPessoaFisica = widget.isPessoaFisica ?? true;
    _cnpjDeEmpresa = widget.cnpjDeEmpresa ?? true;
    _fotoPerfilUrl = widget.fotoPerfilUrl;
    _idFacial = widget.idFacial;

    _nomeController = TextEditingController(text: widget.nome ?? '');
    _nomeFantasiaController = TextEditingController(text: '');
    _cpfController = TextEditingController(text: widget.cpf ?? '');
    _cnpjController = TextEditingController(text: widget.cnpj ?? '');
    _razaoSocialController = TextEditingController(
      text: widget.razaoSocial ?? '',
    );
    _senhaController = TextEditingController(text: widget.senha ?? '');
    _confirmarSenhaController = TextEditingController(text: widget.senha ?? '');
    _dataFundacaoController = TextEditingController();

    _senhaController.addListener(() {
      if (_senhaController.text.isNotEmpty && _erroSenha != null) {
        _erroSenha = null;
      }
      if (mounted) setState(() {});
    });

    _nomeController.addListener(() {
      if (_nomeController.text.isNotEmpty && _erroNome != null) {
        setState(() => _erroNome = null);
      }
    });
    _cpfController.addListener(() {
      if (!_isPessoaFisica) return;
      setState(() {
        if (_erroCpf != null) _erroCpf = null;
        _documentoValido = false;
      });
      _validarDocumentoDigitado();
    });

    _cnpjController.addListener(() {
      if (_isPessoaFisica) return;
      setState(() {
        if (_erroCnpj != null) _erroCnpj = null;
        _documentoValido = false;
      });
      _validarDocumentoDigitado();
    });
    _razaoSocialController.addListener(() {
      if (_razaoSocialController.text.isNotEmpty && _erroRazaoSocial != null) {
        setState(() => _erroRazaoSocial = null);
      }
    });
    _confirmarSenhaController.addListener(() {
      if (_confirmarSenhaController.text.isNotEmpty &&
          _erroConfirmarSenha != null) {
        setState(() => _erroConfirmarSenha = null);
      }
    });
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _nomeFantasiaController.dispose();
    _cpfController.dispose();
    _cnpjController.dispose();
    _razaoSocialController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
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
        if (mounted) {
          setState(() => _documentoValido = false);
        }
        return false;
      }

      final valido = _validarCpfLocal(doc);

      if (mounted) {
        setState(() {
          _erroCpf = valido ? null : 'O CPF não corresponde a um CPF real.';
          _documentoValido = valido;
        });
      }

      return valido;
    }

    if (doc.length < 14) {
      if (mounted) {
        setState(() => _documentoValido = false);
      }
      return false;
    }

    final validoLocal = _validarCnpjLocal(doc);
    if (!validoLocal) {
      if (mounted) {
        setState(() {
          _erroCnpj = 'O CNPJ não corresponde a um CNPJ real.';
          _documentoValido = false;
        });
      }
      return false;
    }

    if (mounted) {
      setState(() => _validandoDocumento = true);
    }

    try {
      final response = await http.get(
        Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$doc'),
      );

      final encontrado = response.statusCode == 200;

      if (encontrado) {
        final data = json.decode(response.body);
        final razaoSocial = data['razao_social'] as String?;
        final nomeFantasia = data['nome_fantasia'] as String?;
        final telefone = data['ddd_telefone'] as String?;

        if (razaoSocial != null && razaoSocial.isNotEmpty) {
          _razaoSocialController.text = razaoSocial;
          _erroRazaoSocial = null;
        }
        if (nomeFantasia != null && nomeFantasia.isNotEmpty) {
          _nomeController.text = nomeFantasia;
          _erroNomeFantasia = null;
        }
      }

      if (mounted) {
        setState(() {
          _erroCnpj = encontrado
              ? null
              : 'O CNPJ não foi encontrado na BrasilAPI.';
          _documentoValido = encontrado;
        });
      }

      return encontrado;
    } catch (_) {
      if (mounted) {
        setState(() {
          _erroCnpj = 'Não foi possível validar o CNPJ agora.';
          _documentoValido = false;
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _validandoDocumento = false);
      }
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
        _dataFundacaoController.text = '$dia/$mes/$ano';
        _erroDataFundacao = null;
      });
    }
  }

  Future<void> _irParaEtapa2() async {
    setState(() {
      _erroNome = _nomeController.text.trim().isEmpty
          ? 'O nome é obrigatório'
          : null;

      if (!_isPessoaFisica) {
        _erroRazaoSocial = _razaoSocialController.text.trim().isEmpty
            ? 'A Razão Social é obrigatória'
            : null;
        // Pessoa Jurídica sempre exige data de fundação
        _erroDataFundacao = _dataFundacaoController.text.trim().isEmpty
            ? 'A data de fundação é obrigatória'
            : null;
      } else {
        _erroDataFundacao = null;
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

      if (_senhaController.text != _confirmarSenhaController.text) {
        _erroConfirmarSenha = 'As senhas não coincidem';
      } else {
        _erroConfirmarSenha = null;
      }
    });

    final documentoOk = await _validarDocumentoDigitado(obrigatorio: true);

    if (_erroNome != null ||
        _erroRazaoSocial != null ||
        _erroSenha != null ||
        _erroConfirmarSenha != null ||
        _erroDataFundacao != null ||
        !documentoOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor, preencha todos os campos obrigatórios corretamente.',
          ),
        ),
      );
      return;
    }

    // Verificar se CPF/CNPJ já existe no sistema
    if (_isPessoaFisica) {
      final doc = _somenteDigitos(_cpfController.text);
      try {
        final supabase = Supabase.instance.client;
        final result = await supabase
            .from('pessoa_fisica')
            .select('id_pessoa_fisica')
            .eq('cpf', doc)
            .maybeSingle();
        if (result != null && mounted) {
          setState(() => _erroCpf = 'O CPF já está cadastrado no sistema');
          return;
        }
      } catch (_) {
        // Silencia erro de verificação
      }
    } else {
      final doc = _somenteDigitos(_cnpjController.text);
      try {
        final supabase = Supabase.instance.client;
        final result = await supabase
            .from('pessoa_juridica')
            .select('id_pessoa_juridica')
            .eq('cnpj', doc)
            .maybeSingle();
        if (result != null && mounted) {
          setState(() => _erroCnpj = 'O CNPJ já está cadastrado no sistema');
          return;
        }
      } catch (_) {
        // Silencia erro de verificação
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroProfissionalEtapa2Page(
          nome: _nomeController.text.trim(),
          cpf: _isPessoaFisica ? _cpfController.text.trim() : null,
          cnpj: !_isPessoaFisica ? _cnpjController.text.trim() : null,
          razaoSocial: !_isPessoaFisica
              ? _razaoSocialController.text.trim()
              : null,
          senha: _senhaController.text,
          isPessoaFisica: _isPessoaFisica,
          cnpjDeEmpresa: _cnpjDeEmpresa,
          dataFundacao: converterDataParaIso(
            _dataFundacaoController.text.trim(),
          ),
          fotoPerfilUrl: _fotoPerfilUrl,
          idFacial: _idFacial,
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
                  GestureDetector(
                    onTap: () {},
                    child: _buildStepCircle('1', isActive: true),
                  ),
                  _buildStepLine(),
                  GestureDetector(
                    onTap: () => _irParaEtapa2(),
                    child: _buildStepCircle('2', isActive: false),
                  ),
                  _buildStepLine(),
                  GestureDetector(
                    onTap: () {
                      // Vai para etapa 3 com dados disponíveis (passa pela 2 vazia)
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CadastroProfissionalEtapa3Page(
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
                            email: '',
                            telefone: '',
                            dataNascimento: '',
                            areaAtuacao: '',
                            fotoPerfilUrl: _fotoPerfilUrl,
                            idFacial: _idFacial,
                          ),
                        ),
                      );
                    },
                    child: _buildStepCircle('3', isActive: false),
                  ),
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
                          _erroCpf = null;
                          _documentoValido = false;
                          _validandoDocumento = false;
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
                          _documentoValido = false;
                          _validandoDocumento = false;
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
                  suffixIcon: _documentoValido ? Icons.check_circle : null,
                  suffixIconColor: const Color(0xFF00A2FF),
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
                      _buildRequisitoItem('Pelo menos 1 número', _temNumero),
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
                  suffixIcon: _documentoValido ? Icons.check_circle : null,
                  suffixIconColor: const Color(0xFF00A2FF),
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
                  label: 'Nome Fantasia',
                  hint: 'Nome Fantasia',
                  keyboardType: TextInputType.name,
                  controller: _nomeController,
                  errorText: _erroNomeFantasia,
                ),
                _InputFieldWithAnimation(
                  label: 'Razão Social',
                  hint: 'Razão Social',
                  controller: _razaoSocialController,
                  errorText: _erroRazaoSocial,
                ),
                if (!_isPessoaFisica) ...[
                  _InputFieldWithAnimation(
                    label: 'Data de Fundação',
                    hint: 'DD/MM/AAAA',
                    suffixIcon: Icons.calendar_month,
                    controller: _dataFundacaoController,
                    readOnly: true,
                    onTap: _fazerUploadDataFundacao,
                    onSuffixIconTap: _fazerUploadDataFundacao,
                    errorText: _erroDataFundacao,
                  ),
                ],
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
                      _buildRequisitoItem('Pelo menos 1 número', _temNumero),
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
                  onPressed: _irParaEtapa2,
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
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ou',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  onPressed: _carregandoGoogle ? null : _continuarComGoogle,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDADCE0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: _carregandoGoogle
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.g_mobiledata,
                          size: 28,
                          color: Colors.black87,
                        ),
                  label: Text(
                    _carregandoGoogle
                        ? 'Conectando...'
                        : 'Continuar com Google',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
  final String dataFundacao;
  final String? fotoPerfilUrl;
  final String? idFacial;

  const CadastroProfissionalEtapa2Page({
    super.key,
    required this.nome,
    this.cpf,
    this.cnpj,
    this.razaoSocial,
    required this.senha,
    required this.isPessoaFisica,
    required this.cnpjDeEmpresa,
    this.dataFundacao = '',
    this.fotoPerfilUrl,
    this.idFacial,
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
  String? _idFacial;
  String _ddiSelecionado = '+55';
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _telefoneFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _idFacial = widget.idFacial;

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
    _dataNascimentoController.addListener(() {
      if (_dataNascimentoController.text.isNotEmpty &&
          _erroDataNascimento != null) {
        setState(() => _erroDataNascimento = null);
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
    _emailFocusNode.dispose();
    _telefoneFocusNode.dispose();
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
        _dataNascimentoController.text = '$dia/$mes/$ano';
        _erroDataNascimento = null;
      });
    }
  }

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

  Future<void> _verificarEmailDuplicado() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) return;

    try {
      final supabase = Supabase.instance.client;
      final list = await supabase
          .from('emails')
          .select('endereco_email')
          .eq('endereco_email', email);

      if (list.isNotEmpty && mounted) {
        setState(() => _erroEmail = 'Este e-mail já está em uso.');
      }
    } catch (e) {
      debugPrint('Erro ao verificar email: $e');
    }
  }

  Future<void> _verificarTelefoneDuplicado() async {
    final apenasNumeros = _telefoneController.text.replaceAll(
      RegExp(r'\D'),
      '',
    );
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

      if (list.isNotEmpty && mounted) {
        setState(() => _erroTelefone = 'Este telefone já está cadastrado.');
      }
    } catch (e) {
      debugPrint('Erro ao verificar telefone: $e');
    }
  }

  void _irParaEtapa3() async {
    setState(() {
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

      _erroDataNascimento =
          (widget.isPessoaFisica &&
              _dataNascimentoController.text.trim().isEmpty)
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
          content: Text('Por favor, preencha todos os campos obrigatórios.'),
        ),
      );
      return;
    }

    // Verificar se email já existe no sistema
    try {
      final supabase = Supabase.instance.client;
      final result = await supabase
          .from('emails')
          .select('id_email')
          .eq('endereco_email', _emailController.text.trim())
          .maybeSingle();
      if (result != null && mounted) {
        setState(() => _erroEmail = 'O E-mail já está cadastrado no sistema');
        return;
      }
    } catch (_) {
      // Silencia erro de verificação
    }

    if (!mounted) return;

    Navigator.pushReplacement(
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
          dataNascimento: converterDataParaIso(
            _dataNascimentoController.text.trim(),
          ),
          dataFundacao: widget.dataFundacao,
          areaAtuacao: _atuacaoController.text.trim(),
          oficiosSelecionados: _oficiosSelecionados
              .map((e) => (e['id_oficio'] as num).toInt())
              .toList(),
          fotoPerfilUrl: widget.fotoPerfilUrl,
          idFacial: _idFacial,
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
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CadastroProfissionalPage(
                            nome: widget.nome,
                            cpf: widget.cpf,
                            cnpj: widget.cnpj,
                            razaoSocial: widget.razaoSocial,
                            senha: widget.senha,
                            isPessoaFisica: widget.isPessoaFisica,
                            cnpjDeEmpresa: widget.cnpjDeEmpresa,
                            fotoPerfilUrl: widget.fotoPerfilUrl,
                            idFacial: _idFacial,
                          ),
                        ),
                      );
                    },
                    child: _buildStepCircle('1', isActive: false),
                  ),
                  _buildStepLine(),
                  GestureDetector(
                    onTap: () {},
                    child: _buildStepCircle('2', isActive: true),
                  ),
                  _buildStepLine(),
                  GestureDetector(
                    onTap: () => _irParaEtapa3(),
                    child: _buildStepCircle('3', isActive: false),
                  ),
                ],
              ),
              const SizedBox(height: 40),

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

              if (widget.isPessoaFisica) ...[
                _InputFieldWithAnimation(
                  label: 'Data de Nascimento',
                  hint: 'DD/MM/AAAA',
                  suffixIcon: Icons.calendar_month,
                  controller: _dataNascimentoController,
                  readOnly: true,
                  onTap: _fazerUploadDataNascimento,
                  onSuffixIconTap: _fazerUploadDataNascimento,
                  errorText: _erroDataNascimento,
                ),
              ],

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
                        color: Colors.black.withValues(alpha: 0.04),
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
                  onPressed: _irParaEtapa3,
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
  final String dataFundacao;
  final String areaAtuacao;
  final List<int> oficiosSelecionados;
  final String? fotoPerfilUrl;
  final String? idFacial;

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
    this.dataFundacao = '',
    required this.areaAtuacao,
    this.oficiosSelecionados = const [],
    this.fotoPerfilUrl,
    this.idFacial,
  });

  @override
  State<CadastroProfissionalEtapa3Page> createState() =>
      _CadastroProfissionalEtapa3PageState();
}

class _CadastroProfissionalEtapa3PageState
    extends State<CadastroProfissionalEtapa3Page> {
  bool _documentoIdentidadeConcluido = false;
  bool _termosDeUso = false;
  bool _politicaPrivacidade = false;
  bool _carregando = false;
  String? _idFacial;
  File? _fotoIdentidade;
  // Dados dos documentos validados para salvar no banco
  List<Map<String, dynamic>> _documentosValidados = [];

  bool get _cadastroFacialConcluido =>
      _idFacial != null && _idFacial!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _idFacial = widget.idFacial;
  }

  Future<void> _mostrarCadastroFacialJaFeito() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cadastro facial'),
          content: const Text('Você já realizou o cadastro facial.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _tirarFotoIdentidade() async {
    final picker = ImagePicker();
    try {
      final XFile? fotoCapturada = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality:
            80, // Reduz o tamanho da imagem para o upload ser mais rápido
      );

      if (fotoCapturada != null) {
        setState(() {
          _fotoIdentidade = File(fotoCapturada.path);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto do documento capturada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao abrir a câmera: $e')));
      }
    }
  }

  Future<void> _finalizarCadastroBanco() async {
    if (_documentosValidados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anexe e valide pelo menos 1 documento de identidade!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
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
      final precisaConfirmarEmail = authResponse.session == null;

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
              'nome_fantasia': widget.nome,
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
              'tipo': 'Jurídica',
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

      if (_idFacial == null || _idFacial!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Faça o cadastro facial antes de finalizar.'),
            ),
          );
        }
        setState(() => _carregando = false);
        return;
      }

      final dadosProfResponse = await supabase
          .from('dados_profissionais')
          .insert({
            'fk_usuario': usuarioId,
            'id_facial': _idFacial,
            'rosto_validado': true,
            'data_admissao': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();

      final profissionalIdCorreto = dadosProfResponse['id_profissional'];

      // Salvar associações de ofícios selecionados (se houver)
      if (widget.oficiosSelecionados.isNotEmpty) {
        for (final oficioId in widget.oficiosSelecionados) {
          try {
            final res = await supabase
                .from('ass_oficio_profissional')
                .insert({
                  'fk_profissional': profissionalIdCorreto,
                  'fk_oficio': oficioId,
                })
                .select()
                .maybeSingle();
            debugPrint('ass_oficio_profissional insert res: $res');
          } catch (e) {
            debugPrint(
              'Falha ao inserir ass_oficio_profissional (oficio $oficioId): $e',
            );
          }
        }
      }

      // Salvar TODOS os documentos validados no banco
      for (final doc in _documentosValidados) {
        final insertData = <String, dynamic>{
          'tipo_documento': doc['tipo'],
          'fk_profissional': profissionalIdCorreto,
          'validacao_documento': true,
        };
        await supabase.from('documentos_profissionais').insert(insertData);
      }

      if (mounted) {
        if (precisaConfirmarEmail) {
          // "Confirmar e-mail" está ativo no Supabase: o usuário já foi criado no
          // auth, mas ainda precisa confirmar o e-mail antes de conseguir entrar.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Quase lá! Enviamos um link de confirmação para o seu e-mail. '
                'Clique nele para ativar sua conta e depois faça login.',
              ),
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => TelaHomeProfissional(isVisitante: false),
            ),
            (route) => false,
          );
        }
      }
    } on AuthException catch (e) {
      String mensagemAmigavel = 'Ocorreu um erro ao registrar.';

      final errorMsg = e.message.toLowerCase();

      if (errorMsg.contains('already registered') ||
          errorMsg.contains('already exists') ||
          errorMsg.contains('duplicate') ||
          errorMsg.contains('email already')) {
        mensagemAmigavel =
            'Este e-mail já está cadastrado em nossa plataforma.';
      } else if (errorMsg.contains('password should be at least') ||
          errorMsg.contains('weak password')) {
        // Lê do servidor quantos caracteres ele exige de verdade (o Supabase pode
        // pedir um mínimo maior do que as regras locais do app).
        final match = RegExp(
          r'at least (\d{1,3})',
          caseSensitive: false,
        ).firstMatch(e.message);
        final requerido = match != null ? int.parse(match.group(1)!) : 8;
        mensagemAmigavel =
            'Senha muito fraca para o servidor! Ela precisa ter no mínimo '
            '$requerido caracteres, combinando letras maiúsculas, minúsculas, '
            'números e símbolos.';
      } else if (errorMsg.contains('invalid email') ||
          errorMsg.contains('email format')) {
        mensagemAmigavel = 'O e-mail informado não é válido.';
      } else {
        mensagemAmigavel = e.message;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(mensagemAmigavel)));
      }
    } catch (e) {
      String mensagemErro = e.toString().replaceAll('Exception: ', '');

      // Verificar se é erro de CPF/CNPJ duplicado
      final erroLower = mensagemErro.toLowerCase();
      if (erroLower.contains('cpf') &&
          (erroLower.contains('duplicate') ||
              erroLower.contains('already exists') ||
              erroLower.contains('unique'))) {
        mensagemErro = 'O CPF já está cadastrado no sistema.';
      } else if (erroLower.contains('cnpj') &&
          (erroLower.contains('duplicate') ||
              erroLower.contains('already exists') ||
              erroLower.contains('unique'))) {
        mensagemErro = 'O CNPJ já está cadastrado no sistema.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao registrar: $mensagemErro')),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _voltarParaEtapa2() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroProfissionalEtapa2Page(
          nome: widget.nome,
          cpf: widget.cpf,
          cnpj: widget.cnpj,
          razaoSocial: widget.razaoSocial,
          senha: widget.senha,
          isPessoaFisica: widget.isPessoaFisica,
          cnpjDeEmpresa: widget.cnpjDeEmpresa,
          fotoPerfilUrl: widget.fotoPerfilUrl,
          idFacial: _idFacial,
        ),
      ),
    );
  }

  void _voltarParaEtapa1() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CadastroProfissionalPage(
          nome: widget.nome,
          cpf: widget.cpf,
          cnpj: widget.cnpj,
          razaoSocial: widget.razaoSocial,
          senha: widget.senha,
          isPessoaFisica: widget.isPessoaFisica,
          cnpjDeEmpresa: widget.cnpjDeEmpresa,
          fotoPerfilUrl: widget.fotoPerfilUrl,
          idFacial: _idFacial,
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
                  GestureDetector(
                    onTap: _voltarParaEtapa1,
                    child: _buildStepCircle('1', isActive: false),
                  ),
                  _buildStepLine(),
                  GestureDetector(
                    onTap: _voltarParaEtapa2,
                    child: _buildStepCircle('2', isActive: false),
                  ),
                  _buildStepLine(),
                  GestureDetector(
                    onTap: () {},
                    child: _buildStepCircle('3', isActive: true),
                  ),
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
                borderColor: _cadastroFacialConcluido
                    ? const Color(0xFF2EAD5B)
                    : const Color(0xFF00A2FF),
                textColor: _cadastroFacialConcluido
                    ? const Color(0xFF2EAD5B)
                    : const Color(0xFF00A2FF),
                iconColor: _cadastroFacialConcluido
                    ? const Color(0xFF2EAD5B)
                    : const Color(0xFF00A2FF),
                onTap: () async {
                  if (_cadastroFacialConcluido) {
                    await _mostrarCadastroFacialJaFeito();
                    return;
                  }

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
              _buildDocumentButton(
                label: 'Documento de Identidade',
                icon: _documentoIdentidadeConcluido
                    ? Icons.check_circle
                    : Icons.arrow_forward,
                borderColor: _documentoIdentidadeConcluido
                    ? const Color(0xFF2EAD5B)
                    : const Color(0xFF00A2FF),
                textColor: _documentoIdentidadeConcluido
                    ? const Color(0xFF2EAD5B)
                    : const Color(0xFF00A2FF),
                iconColor: _documentoIdentidadeConcluido
                    ? const Color(0xFF2EAD5B)
                    : const Color(0xFF00A2FF),
                onTap: () async {
                  final resultado = await Navigator.push<Map<String, dynamic>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ValidacaoDocsPage(
                        cpf: widget.cpf,
                        cnpj: widget.cnpj,
                        dataNascimento: widget.dataNascimento,
                        isPessoaJuridica: !widget.isPessoaFisica,
                      ),
                    ),
                  );

                  if (resultado != null &&
                      resultado['validado'] == true &&
                      mounted) {
                    setState(() {
                      _documentoIdentidadeConcluido = true;
                      _documentosValidados = List<Map<String, dynamic>>.from(
                        resultado['docsData'] ?? [],
                      );
                    });
                  }
                },
              ),

              const SizedBox(height: 20),

              _buildCheckboxRow(
                value: _termosDeUso,
                onChanged: (val) => setState(() => _termosDeUso = val ?? false),
                fullText: 'Li e aceito os Termos de Uso',
                highlightText: 'Termos de Uso',
                onTapLink: () {
                  mostrarDialogoDocumento(
                    context,
                    titulo: 'Termos de Uso',
                    conteudo: TermosDeUsoPage.conteudo,
                  );
                },
              ),
              const SizedBox(height: 14),
              _buildCheckboxRow(
                value: _politicaPrivacidade,
                onChanged: (val) =>
                    setState(() => _politicaPrivacidade = val ?? false),
                fullText: 'Li e aceito a Política de Privacidade',
                highlightText: 'Política de Privacidade',
                onTapLink: () {
                  mostrarDialogoDocumento(
                    context,
                    titulo: 'Política de Privacidade',
                    conteudo: PoliticaDePrivacidadePage.conteudo,
                  );
                },
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed:
                      (_termosDeUso &&
                          _politicaPrivacidade &&
                          _cadastroFacialConcluido &&
                          _documentoIdentidadeConcluido &&
                          !_carregando)
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
    Color borderColor = const Color(0xFF00A2FF),
    Color textColor = const Color(0xFF00A2FF),
    Color iconColor = const Color(0xFF00A2FF),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
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
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(icon, color: iconColor, size: 22),
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

class CadastroFacialInstrucoesPage extends StatelessWidget {
  const CadastroFacialInstrucoesPage({super.key});

  static const Color _blue = Color(0xFF0FB3FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cadastro Facial',
          style: TextStyle(
            color: _blue,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),

              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: _blue, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(Icons.face_rounded, color: _blue, size: 70),
                ),
              ),

              const SizedBox(height: 32),

              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    height: 1.5,
                  ),
                  children: [
                    TextSpan(
                      text:
                          'Seu rosto será utilizado exclusivamente para autenticação de identidade dentro da plataforma. Para mais informações consulte nossa ',
                    ),
                    TextSpan(
                      text: 'Política de Privacidade',
                      style: TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: '.'),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Instruções',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              const _InstructionItem(
                text:
                    'Segure o celular na altura do rosto e mantenha os braços firmes.',
              ),
              const _InstructionItem(
                text:
                    'Posicione seu rosto completamente dentro do círculo de enquadramento.',
              ),
              const _InstructionItem(
                text:
                    'Remova chapéus, bonés, máscaras e óculos que possam cobrir seu rosto.',
              ),
              const _InstructionItem(
                text:
                    'Utilize um ambiente bem iluminado e prefira fundos neutros.',
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () async {
                    final resultado = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CadastroFacialPage(),
                      ),
                    );

                    if (resultado != null && context.mounted) {
                      Navigator.pop(context, resultado);
                    }
                  },
                  child: const Text(
                    'Iniciar Cadastro Facial',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionItem extends StatelessWidget {
  final String text;

  const _InstructionItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF0FB3FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class CadastroFacialPage extends StatefulWidget {
  const CadastroFacialPage({super.key});

  @override
  State<CadastroFacialPage> createState() => _CadastroFacialPageState();
}

class _CadastroFacialPageState extends State<CadastroFacialPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _red = Color(0xFFFF0000);

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  FaceDetector? _faceDetector;

  bool _usandoFrontal = true;
  bool _carregandoCamera = true;
  bool _processando = false;
  bool _finalizado = false;

  String _status = 'Nenhum rosto detectado';
  double _progresso = 0.0;
  Timer? _timer;
  int _semRostoCount = 0;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableClassification: true,
          enableLandmarks: true,
          enableTracking: true,
        ),
      );
    }

    _initCamera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de câmera negada.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    _cameras = await availableCameras();
    await _startSelectedCamera();
  }

  Future<void> _startSelectedCamera() async {
    _timer?.cancel();
    await _controller?.dispose();

    if (_cameras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma câmera encontrada.')),
        );
        Navigator.pop(context);
      }
      return;
    }

    final CameraDescription camera = _cameras.firstWhere(
      (c) => _usandoFrontal
          ? c.lensDirection == CameraLensDirection.front
          : c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;

      setState(() {
        _carregandoCamera = false;
        _processando = false;
      });

      if (!kIsWeb) {
        _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
          _avaliarRosto();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregandoCamera = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao iniciar a câmera: $e')),
        );
      }
    }
  }

  Future<void> _trocarCamera() async {
    if (_cameras.isEmpty) return;
    setState(() => _usandoFrontal = !_usandoFrontal);
    await _startSelectedCamera();
  }

  Future<void> _avaliarRosto() async {
    if (kIsWeb || _faceDetector == null) {
      return;
    }

    if (_processando ||
        _carregandoCamera ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    if (_controller!.value.isTakingPicture) {
      return;
    }

    _processando = true;

    try {
      final picture = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(picture.path);
      final faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        _semRostoCount++;

        setState(() {
          _status = _semRostoCount >= 3
              ? 'Vá para um lugar com mais iluminação'
              : 'Nenhum rosto detectado';
          _progresso = 0.0;
        });

        return;
      }

      _semRostoCount = 0;

      if (faces.length > 1) {
        setState(() {
          _status = 'Apenas um rosto por vez';
          _progresso = 0.15;
        });
        return;
      }

      final face = faces.first;
      final preview = _controller!.value.previewSize;
      final w = (preview?.height ?? 1).toDouble();
      final h = (preview?.width ?? 1).toDouble();
      final box = face.boundingBox;

      final faceW = box.width / w;
      final faceH = box.height / h;
      final faceRatio = math.max(faceW, faceH);

      final yaw = (face.headEulerAngleY ?? 0).abs();
      final roll = (face.headEulerAngleZ ?? 0).abs();

      if (yaw > 15 || roll > 15) {
        setState(() {
          _status = 'Centralize o rosto';
          _progresso = 0.45;
        });
        return;
      }

      final leftEye = face.leftEyeOpenProbability;
      final rightEye = face.rightEyeOpenProbability;

      if ((leftEye != null && leftEye < 0.25) ||
          (rightEye != null && rightEye < 0.25)) {
        setState(() {
          _status = 'Mantenha os olhos abertos';
          _progresso = 0.6;
        });
        return;
      }

      if (faceRatio < 0.18) {
        setState(() {
          _status = 'Afaste mais a câmera';
          _progresso = 0.35;
        });
        return;
      }

      if (faceRatio > 0.65) {
        setState(() {
          _status = 'Afaste o rosto da câmera';
          _progresso = 0.5;
        });
        return;
      }

      setState(() {
        _status = 'Rosto validado com sucesso';
        _progresso = 1.0;
      });

      final idFacial = await _gerarIdFacial(File(picture.path));

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 400));

      _finalizado = true;
      _timer?.cancel();

      await _controller?.dispose();
      _controller = null;

      if (!mounted) return;

      final resultado = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => CadastroFacialSucessoPage(idFacial: idFacial),
        ),
      );

      if (resultado != null && mounted) {
        Navigator.pop(context, resultado);
      }
    } catch (e, stackTrace) {
      debugPrint('====================');
      debugPrint('ERRO FACIAL: $e');
      debugPrint('$stackTrace');
      debugPrint('====================');

      if (mounted) {
        setState(() {
          _status = 'Não foi possível processar agora';
          _progresso = 0.0;
        });
      }
    } finally {
      _processando = false;
    }
  }

  Future<String> _gerarIdFacial(File file) async {
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();

    if (await file.exists()) {
      await file.delete();
    }

    return hash;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Color.lerp(_red, _blue, _progresso) ?? _red;
    final double circleSize = MediaQuery.sizeOf(context).width * 0.82;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _blue),
        ),
        title: const Text(
          'Tire sua foto',
          style: TextStyle(
            color: _blue,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE6E6E6)),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            if (_status.startsWith('Falha:'))
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            const SizedBox(height: 42),

            if (kIsWeb)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'A validação facial automática funciona apenas em Android/iOS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0FB3FF),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: circleSize,
                      height: circleSize,
                      child:
                          _carregandoCamera ||
                              _controller == null ||
                              !_controller!.value.isInitialized ||
                              _controller!.value.previewSize == null
                          ? const Center(child: CircularProgressIndicator())
                          : FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.previewSize!.height,
                                height: _controller!.value.previewSize!.width,
                                child: CameraPreview(_controller!),
                              ),
                            ),
                    ),
                  ),
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 3),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: _trocarCamera,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.switch_camera, color: _blue, size: 40),
                  const SizedBox(height: 6),
                  const Text(
                    'Virar câmera',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
          ],
        ),
      ),
    );
  }
}

class CadastroFacialSucessoPage extends StatelessWidget {
  final String idFacial;

  const CadastroFacialSucessoPage({super.key, required this.idFacial});

  static const Color _blue = Color(0xFF0FB3FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.pop(context, idFacial),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _blue,
                ),
              ),
            ),
            const Spacer(),
            Center(
              child: Image.asset(
                'assets/images/certo_icone.png',
                width: 260,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Cadastro Facial concluído com sucesso',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _blue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, idFacial),
                  child: const Text(
                    'Voltar',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double squareSize = 18.0;
    final Paint lightPaint = Paint()..color = const Color(0xFFF1F1F1);
    final Paint whitePaint = Paint()..color = Colors.white;

    final int columns = (size.width / squareSize).ceil();
    final int rows = (size.height / squareSize).ceil();

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < columns; x++) {
        final bool isLight = (x + y) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x * squareSize, y * squareSize, squareSize, squareSize),
          isLight ? lightPaint : whitePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================= COMPONENTE DE INPUT CUSTOMIZADO E ANIMADO =================
class _InputFieldWithAnimation extends StatefulWidget {
  final String label;
  final String hint;
  final IconData? suffixIcon;
  final Color? suffixIconColor;
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
    this.suffixIconColor,
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
                        ? const Color(0xFF00A2FF).withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.015),
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
                                    : const Color(
                                        0xFF00A2FF,
                                      ).withValues(alpha: 0.4),
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
                          color:
                              widget.suffixIconColor ??
                              (hasError
                                  ? Colors.red
                                  : (_isFocused
                                        ? const Color(0xFF00A2FF)
                                        : Colors.grey.shade400)),
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

// ================= VALIDAÇÃO DE DOCUMENTOS (TELA NOVA) =================
/// Retorna um Map com: 'validado' (bool), 'tiposValidados' (List<String>),
/// 'docsData' (List<Map<String,dynamic>> com tipo, caminho_arquivo)
class ValidacaoDocsPage extends StatefulWidget {
  final String? cpf;
  final String? cnpj;
  final String? dataNascimento;
  final bool isPessoaJuridica;
  final String? tipoDocumentoInicial;

  const ValidacaoDocsPage({
    super.key,
    this.cpf,
    this.cnpj,
    this.dataNascimento,
    this.isPessoaJuridica = false,
    this.tipoDocumentoInicial,
  });

  @override
  State<ValidacaoDocsPage> createState() => _ValidacaoDocsPageState();
}

class _ValidacaoDocsPageState extends State<ValidacaoDocsPage> {
  late final List<_DocType> _docTypes;

  // Tipos de documentos para pessoa física
  static final List<_DocType> _docTypesPF = [
    _DocType(label: 'Registro Geral (RG)', type: 'RG'),
    _DocType(label: 'Carteira de Identidade Nacional (CIN)', type: 'CIN'),
    _DocType(label: 'Carteira Nacional de Habilitação (CNH)', type: 'CNH'),
    _DocType(label: 'Passaporte', type: 'PASSAPORTE'),
  ];

  // Tipos de documentos para pessoa jurídica
  static final List<_DocType> _docTypesPJ = [
    _DocType(label: 'Cartão CNPJ', type: 'CARTAO_CNPJ'),
    _DocType(
      label: 'Contrato Social / Estatuto Social / Requerimento Empresário',
      type: 'CONTRATO_SOCIAL',
    ),
    _DocType(label: 'Notas Fiscais (DANFE)', type: 'DANFE'),
    _DocType(label: 'Alvará de Funcionamento', type: 'ALVARA'),
  ];

  bool _carregando = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.isPessoaJuridica) {
      _docTypes = _docTypesPJ;
    } else {
      _docTypes = _docTypesPF;
    }

    // Se um tipo de documento foi pré-selecionado (ex: vindo de "Meus Documentos"),
    // inicia automaticamente o fluxo de captura frente/verso sem mostrar a lista.
    if (widget.tipoDocumentoInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final doc = _docTypes
            .where((d) => d.type == widget.tipoDocumentoInicial)
            .firstOrNull;
        if (doc != null) {
          _selecionarDocumento(doc);
        }
      });
    }
  }

  // UFs e Órgãos Emissores válidos do Brasil
  static const List<String> _ufsValidas = [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];

  static const List<String> _orgaosValidos = [
    'SSP',
    'SESP',
    'SDS',
    'DETRAN',
    'POLÍCIA CIVIL',
    'PC',
    'SECRETARIA DE SEGURANÇA PÚBLICA',
    'INSTITUTO DE IDENTIFICAÇÃO',
    'IFP',
    'II',
    'DIC',
    'DPC',
    'MTB',
    'CREA',
    'CRC',
    'OAB',
    'CRM',
    'SSP-SP',
    'SSP-RJ',
    'SSP-MG',
    'SSP-BA',
    'SSP-RS',
    'SSP-PR',
    'SSP-PE',
    'SSP-CE',
    'SSP-PA',
    'SSP-MA',
    'SSP-SC',
    'SSP-GO',
    'SSP-DF',
    'SESP-PI',
    'SDS-PE',
  ];

  String _somenteDigitos(String valor) {
    return valor.replaceAll(RegExp(r'\D'), '');
  }

  /// Valida CPF localmente (mesmo método da classe de cadastro)
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

  /// Extrai CPF do texto (formato com ou sem pontuação)
  /// Reconhece: XXX.XXX.XXX-XX, XXXXXXXXXXX, XXXXXXXXX/XX, XXX.XXXXXX/XX, e variações
  String? _extrairCpf(String texto) {
    // Normaliza o texto para melhorar reconhecimento
    var textoNormalizado = texto.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

    // Tentativa 1: Formato padrão XXX.XXX.XXX-XX ou sem formatação
    final regex1 = RegExp(r'\d{3}\.?\d{3}\.?\d{3}-?\d{2}');
    var match = regex1.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(0)!);
    }

    // Tentativa 2: Formato com barra (9-11 dígitos + barra + 2 dígitos) - CPF/DV comum em RG
    final regex2 = RegExp(r'\d{9,11}/\d{2}');
    match = regex2.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(0)!);
    }

    // Tentativa 3: Formato XXX.XXXXXX/XX
    final regex3 = RegExp(r'\d{3}\.\d{6}/\d{2}');
    match = regex3.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(0)!);
    }

    // Tentativa 4: Padrão com "CPF:" no texto
    final regex4 = RegExp(
      r'CPF[:\s]*(\d{3}[\s\.]?\d{3}[\s\.]?\d{3}[\s\-]?\d{2})',
    );
    match = regex4.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(1)!);
    }

    // Tentativa 5: Busca por sequências de 11 caracteres que pareçam CPF
    // Captura dígitos e possíveis letras confundidas com números (X, I, L, O)
    final regex5 = RegExp(r'[0-9XIL]{11,14}');
    final matches = regex5.allMatches(textoNormalizado);
    for (final m in matches) {
      final candidato = _somenteDigitos(m.group(0)!);
      if (candidato.length == 11 && _validarCpfLocal(candidato)) {
        return candidato;
      }
    }

    // Tentativa 6: Busca por qualquer sequência de 11 dígitos consecutivos
    final apenasDigitos = _somenteDigitos(texto);
    if (apenasDigitos.length >= 11) {
      for (int i = 0; i <= apenasDigitos.length - 11; i++) {
        final candidato = apenasDigitos.substring(i, i + 11);
        if (!RegExp(r'^(\d)\1{10}$').hasMatch(candidato)) {
          if (_validarCpfLocal(candidato)) {
            return candidato;
          }
        }
      }
    }

    return null;
  }

  /// Extrai datas no formato DD/MM/AAAA ou AAAA-MM-DD
  List<DateTime> _extrairDatas(String texto) {
    final datas = <DateTime>[];
    final regex1 = RegExp(r'\d{2}/\d{2}/\d{4}');
    final regex2 = RegExp(r'\d{4}-\d{2}-\d{2}');

    for (final match in regex1.allMatches(texto)) {
      final partes = match.group(0)!.split('/');
      final dia = int.tryParse(partes[0]) ?? 0;
      final mes = int.tryParse(partes[1]) ?? 0;
      final ano = int.tryParse(partes[2]) ?? 0;
      if (ano >= 1920 &&
          ano <= 2050 &&
          mes >= 1 &&
          mes <= 12 &&
          dia >= 1 &&
          dia <= 31) {
        datas.add(DateTime(ano, mes, dia));
      }
    }

    for (final match in regex2.allMatches(texto)) {
      final partes = match.group(0)!.split('-');
      final ano = int.tryParse(partes[0]) ?? 0;
      final mes = int.tryParse(partes[1]) ?? 0;
      final dia = int.tryParse(partes[2]) ?? 0;
      if (ano >= 1920 &&
          ano <= 2050 &&
          mes >= 1 &&
          mes <= 12 &&
          dia >= 1 &&
          dia <= 31) {
        datas.add(DateTime(ano, mes, dia));
      }
    }

    return datas;
  }

  /// Extrai número de RG tentando encontrar padrões
  String? _extrairRg(String texto) {
    // Padrões comuns: XX.XXX.XXX-X, X.XXX.XXX, XXXXXXXX-X
    final regex = RegExp(r'\d{1,2}\.?\d{3}\.?\d{3}-?[\dxX]');
    final match = regex.firstMatch(texto);
    return match?.group(0);
  }

  /// Extrai a UF do texto (sigla de 2 letras maiúsculas comum em docs)
  String? _extrairUf(String texto) {
    for (final uf in _ufsValidas) {
      if (texto.contains(uf)) return uf;
    }
    return null;
  }

  /// Extrai órgão emissor do texto
  String? _extrairOrgaoEmissor(String texto) {
    for (final orgao in _orgaosValidos) {
      if (texto.toUpperCase().contains(orgao)) return orgao;
    }
    return null;
  }

  /// Verifica se formato de RG é válido para a UF
  bool _validarFormatoRg(String? rg, String? uf) {
    if (rg == null) return false;
    final digitos = _somenteDigitos(rg);
    // RG geralmente tem entre 7 e 11 dígitos
    return digitos.length >= 7 && digitos.length <= 11;
  }

  /// Extrai nacionalidade do texto
  bool _verificarNacionalidadeBrasileira(String texto) {
    final textoUp = texto.toUpperCase();
    return textoUp.contains('BRASILEIRO') ||
        textoUp.contains('BRASILEIRA') ||
        textoUp.contains('BRAZIL') ||
        textoUp.contains('NACIONALIDADE') ||
        textoUp.contains('REPÚBLICA FEDERATIVA DO BRASIL') ||
        textoUp.contains('REPUBLICA FEDERATIVA DO BRASIL');
  }

  /// Processa OCR da imagem usando Google ML Kit
  Future<String> _processarOcr(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      await textRecognizer.close();
      return recognizedText.text;
    } catch (e) {
      debugPrint('Erro no OCR: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF0FB3FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Anexe os Documentos',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 100,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0FB3FF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.credit_card,
                          size: 50,
                          color: Color(0xFF0FB3FF),
                        ),
                      ),
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.check_circle,
                          color: Color(0xFF0FB3FF),
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'O seu documento de identidade é utilizado exclusivamente para a verificação da sua conta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, height: 1.4),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Para mais informações confira a Política de Privacidade.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0FB3FF),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            const Text(
              'Escolha o tipo documento',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            ..._docTypes.map((doc) => _buildDocButton(doc)),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _podeEnviar() ? _enviarDocumentos : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0FB3FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _carregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Enviar Documentos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocButton(_DocType doc) {
    final isValid = doc.isValid;
    final isInvalid = doc.isInvalid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => _selecionarDocumento(doc),
          child: Container(
            margin: EdgeInsets.only(bottom: doc.errorMessage != null ? 2 : 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: isValid
                    ? Colors.green
                    : isInvalid
                    ? Colors.red
                    : const Color(0xFF0FB3FF),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    doc.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isValid
                          ? Colors.green
                          : isInvalid
                          ? Colors.red
                          : const Color(0xFF0FB3FF),
                    ),
                  ),
                ),
                if (isValid)
                  const Icon(Icons.check_circle, color: Colors.green, size: 28)
                else if (isInvalid)
                  const Icon(Icons.error_outline, color: Colors.red, size: 28)
                else
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFF0FB3FF),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
        if (doc.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              doc.errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _selecionarDocumento(_DocType doc) async {
    if (doc.isValid) {
      _mostrarOpcoesDocumentoValido(doc);
      return;
    }

    // Se estiver invalidado, permite anexar novamente sem mensagem extra
    if (doc.isInvalid) {
      setState(() {
        doc.isInvalid = false;
        doc.errorMessage = null;
      });
    }

    // Inicia o fluxo de captura: frente -> verso
    await _capturarFrente(doc);
  }

  Future<void> _capturarFrente(_DocType doc) async {
    final source = await _mostrarOpcoesOrigem('Frente do Documento');
    if (source == null) return;

    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 100, // Máxima qualidade para OCR preciso
    );

    if (file == null) return;

    setState(() {
      _carregando = true;
      doc.errorMessage = null;
      doc.isInvalid = false;
      doc.isValid = false;
    });

    // Armazena a frente
    doc.filePathFrente = file.path;

    // Agora pede o verso
    await _capturarVerso(doc);
  }

  Future<void> _capturarVerso(_DocType doc) async {
    final source = await _mostrarOpcoesOrigem('Verso do Documento');
    if (source == null) {
      // Se cancelou o verso, limpa a frente já capturada
      setState(() {
        _carregando = false;
        doc.filePathFrente = null;
      });
      return;
    }

    final XFile? file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (file == null) {
      setState(() {
        _carregando = false;
        doc.filePathFrente = null;
      });
      return;
    }

    // Armazena o verso
    doc.filePathVerso = file.path;

    // Processa OCR da frente (onde estão os dados principais)
    String fullText;
    try {
      fullText = await _processarOcr(File(doc.filePathFrente!));
    } catch (e) {
      fullText = '';
    }

    // Se OCR falhou completamente, tentar ler como texto simples
    if (fullText.isEmpty) {
      fullText = 'OCR_EMPTY';
    }

    debugPrint('=== TEXTO EXTRAÍDO DO DOCUMENTO ${doc.type} ===');
    debugPrint(fullText);
    debugPrint('==============================================');

    // Combina os textos da frente e verso
    String fullTextVerso = '';
    try {
      fullTextVerso = await _processarOcr(File(doc.filePathVerso!));
    } catch (e) {
      fullTextVerso = '';
    }
    fullText = '$fullText\n$fullTextVerso';

    await _validarDocumento(doc, fullText);

    setState(() => _carregando = false);
  }

  Future<ImageSource?> _mostrarOpcoesOrigem(String titulo) async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF0FB3FF)),
                title: const Text('Tirar Foto'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF0FB3FF),
                ),
                title: const Text('Galeria'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  /// Extrai CNPJ do texto
  String? _extrairCnpj(String texto) {
    var textoNormalizado = texto.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

    // Tentativa 1: Formato padrão XX.XXX.XXX/XXXX-XX
    final regex1 = RegExp(r'\d{2}\.?\d{3}\.?\d{3}\/?\d{4}-?\d{2}');
    var match = regex1.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(0)!);
    }

    // Tentativa 2: CNPJ puro de 14 dígitos
    final apenasDigitos = _somenteDigitos(texto);
    if (apenasDigitos.length >= 14) {
      for (int i = 0; i <= apenasDigitos.length - 14; i++) {
        final candidato = apenasDigitos.substring(i, i + 14);
        if (!RegExp(r'^(\d)\1{13}$').hasMatch(candidato)) {
          if (_validarCnpjLocal(candidato)) {
            return candidato;
          }
        }
      }
    }

    // Tentativa 3: Padrão com "CNPJ:" no texto
    final regex3 = RegExp(
      r'CNPJ[:\s]*(\d{2}[\s\.]?\d{3}[\s\.]?\d{3}[\s\/]?\d{4}[\s\-]?\d{2})',
    );
    match = regex3.firstMatch(textoNormalizado);
    if (match != null) {
      return _somenteDigitos(match.group(1)!);
    }

    return null;
  }

  Future<void> _validarDocumento(_DocType doc, String texto) async {
    final erros = <String>[];
    bool valido = true;

    if (widget.isPessoaJuridica) {
      // Validação para documentos de Pessoa Jurídica
      final cnpjDigitado = widget.cnpj != null
          ? _somenteDigitos(widget.cnpj!)
          : null;
      final cnpjEncontrado = _extrairCnpj(texto);

      switch (doc.type) {
        case 'CARTAO_CNPJ':
          if (cnpjDigitado == null) {
            erros.add('CNPJ não preenchido na etapa 1.');
            valido = false;
          } else if (cnpjEncontrado == null) {
            erros.add('Não foi possível identificar o CNPJ no documento.');
            valido = false;
          } else if (cnpjEncontrado != cnpjDigitado) {
            erros.add('CNPJ do documento não corresponde ao CNPJ cadastrado.');
            valido = false;
          }
          break;

        case 'CONTRATO_SOCIAL':
          if (cnpjDigitado == null) {
            erros.add('CNPJ não preenchido na etapa 1.');
            valido = false;
          } else if (cnpjEncontrado == null) {
            erros.add('Não foi possível identificar o CNPJ no documento.');
            valido = false;
          } else if (cnpjEncontrado != cnpjDigitado) {
            erros.add('CNPJ do documento não corresponde ao CNPJ cadastrado.');
            valido = false;
          }

          // Verificar palavras-chave de contrato social no texto
          final textoUp = texto.toUpperCase();
          if (!textoUp.contains('CONTRATO SOCIAL') &&
              !textoUp.contains('ESTATUTO SOCIAL') &&
              !textoUp.contains('REQUERIMENTO') &&
              !textoUp.contains('EMPRESÁRIO') &&
              !textoUp.contains('EMPRESARIO')) {
            // Não é um erro crítico - apenas informativo
          }
          break;

        case 'DANFE':
          if (cnpjDigitado == null) {
            erros.add('CNPJ não preenchido na etapa 1.');
            valido = false;
          } else if (cnpjEncontrado == null) {
            erros.add('Não foi possível identificar o CNPJ na DANFE.');
            valido = false;
          } else if (cnpjEncontrado != cnpjDigitado) {
            erros.add('CNPJ da DANFE não corresponde ao CNPJ cadastrado.');
            valido = false;
          }

          // Verificar se tem "DANFE" ou "NOTA FISCAL" no texto
          final textoUp = texto.toUpperCase();
          if (!textoUp.contains('DANFE') && !textoUp.contains('NOTA FISCAL')) {
            erros.add(
              'Não foi possível identificar como uma DANFE/Nota Fiscal.',
            );
            valido = false;
          }
          break;

        case 'ALVARA':
          if (cnpjDigitado == null) {
            erros.add('CNPJ não preenchido na etapa 1.');
            valido = false;
          } else if (cnpjEncontrado == null) {
            erros.add('Não foi possível identificar o CNPJ no Alvará.');
            valido = false;
          } else if (cnpjEncontrado != cnpjDigitado) {
            erros.add('CNPJ do Alvará não corresponde ao CNPJ cadastrado.');
            valido = false;
          }

          // Verificar se tem "ALVARÁ" ou "ALVARA" no texto
          final textoUp = texto.toUpperCase();
          if (!textoUp.contains('ALVARÁ') &&
              !textoUp.contains('ALVARA') &&
              !textoUp.contains('FUNCIONAMENTO')) {
            erros.add(
              'Não foi possível identificar como um Alvará de Funcionamento.',
            );
            valido = false;
          }
          break;

        default:
          // Caso não reconhecido, validar pelo menos o CNPJ
          if (cnpjDigitado != null &&
              cnpjEncontrado != null &&
              cnpjEncontrado == cnpjDigitado) {
            valido = true;
          } else {
            erros.add(
              'Não foi possível validar os dados da empresa no documento.',
            );
            valido = false;
          }
      }
    } else {
      // Validação original para documentos de Pessoa Física
      final cpfDigitado = widget.cpf != null
          ? _somenteDigitos(widget.cpf!)
          : null;
      final cpfEncontrado = _extrairCpf(texto);
      final datas = _extrairDatas(texto);
      final dataNascimentoStr = widget.dataNascimento;

      switch (doc.type) {
        case 'RG':
          // 1. Validar CPF
          if (cpfDigitado == null) {
            erros.add('CPF não preenchido na etapa 1.');
            valido = false;
          } else if (cpfEncontrado == null) {
            erros.add('Não foi possível identificar o CPF no documento.');
            valido = false;
          } else if (cpfEncontrado != cpfDigitado) {
            erros.add('CPF do documento não corresponde ao CPF cadastrado.');
            valido = false;
          }

          // 2. Validar número do RG
          final rg = _extrairRg(texto);
          final uf = _extrairUf(texto);
          if (!_validarFormatoRg(rg, uf)) {
            erros.add(
              'Número do RG não identificado ou formato inválido para a UF.',
            );
            valido = false;
          }

          // 3. Validar data de validade (RG não pode estar vencido - maior de idade)
          final dataNascimentoDoc = _encontrarDataNascimento(
            datas,
            dataNascimentoStr,
          );
          if (dataNascimentoDoc != null &&
              dataNascimentoStr != null &&
              dataNascimentoStr.isNotEmpty) {
            final hoje = DateTime.now();
            if (dataNascimentoDoc.isAfter(hoje)) {
              erros.add('Data de nascimento inválida (futura).');
              valido = false;
            }
          }

          // 4. Bater data de nascimento
          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(
                datas,
                dataNascimentoStr,
              );
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no documento.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add(
                  'Data de nascimento do documento não confere com a cadastrada.',
                );
                valido = false;
              }
            }
          }

          // 5. Verificar órgão emissor / UF
          final orgao = _extrairOrgaoEmissor(texto);
          if (orgao == null) {
            erros.add('Órgão emissor não identificado.');
            valido = false;
          }
          if (uf == null) {
            erros.add('UF do documento não identificada.');
            valido = false;
          } else if (!_ufsValidas.contains(uf)) {
            erros.add('UF "$uf" não é válida.');
            valido = false;
          }
          break;

        case 'CIN':
          if (cpfDigitado == null) {
            erros.add('CPF não preenchido na etapa 1.');
            valido = false;
          } else if (cpfEncontrado == null) {
            erros.add('Não foi possível identificar o CPF no documento.');
            valido = false;
          } else if (cpfEncontrado != cpfDigitado) {
            erros.add('CPF do documento não corresponde ao CPF cadastrado.');
            valido = false;
          }
          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(
                datas,
                dataNascimentoStr,
              );
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no documento.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add(
                  'Data de nascimento do documento não confere com a cadastrada.',
                );
                valido = false;
              }
            }
          }
          final orgao = _extrairOrgaoEmissor(texto);
          if (orgao == null) {
            erros.add('Órgão emissor não identificado.');
            valido = false;
          }
          final uf = _extrairUf(texto);
          if (uf == null) {
            erros.add('UF do documento não identificada.');
            valido = false;
          } else if (!_ufsValidas.contains(uf)) {
            erros.add('UF "$uf" não é válida.');
            valido = false;
          }
          break;

        case 'CNH':
          if (cpfDigitado == null) {
            erros.add('CPF não preenchido na etapa 1.');
            valido = false;
          } else if (cpfEncontrado == null) {
            erros.add('Não foi possível identificar o CPF no documento.');
            valido = false;
          } else if (cpfEncontrado != cpfDigitado) {
            erros.add('CPF do documento não corresponde ao CPF cadastrado.');
            valido = false;
          }
          final hojeCNH = DateTime.now();
          bool temDataValida = false;
          for (final data in datas) {
            if (data.isAfter(hojeCNH) ||
                (data.year == hojeCNH.year &&
                    data.month == hojeCNH.month &&
                    data.day == hojeCNH.day)) {
              temDataValida = true;
              break;
            }
          }
          if (!temDataValida && datas.isNotEmpty) {
            erros.add(
              'Documento parece estar vencido (data de validade expirada).',
            );
            valido = false;
          }
          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(
                datas,
                dataNascimentoStr,
              );
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no documento.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add(
                  'Data de nascimento do documento não confere com a cadastrada.',
                );
                valido = false;
              }
            }
          }
          break;

        case 'PASSAPORTE':
          final hojePass = DateTime.now();
          bool temDataValidaPass = false;
          for (final data in datas) {
            if (data.isAfter(hojePass)) {
              temDataValidaPass = true;
              break;
            }
          }
          if (!temDataValidaPass) {
            erros.add(
              'Passaporte parece estar vencido ou data de validade não identificada.',
            );
            valido = false;
          }
          if (dataNascimentoStr != null && dataNascimentoStr.isNotEmpty) {
            final dataNascEsperada = _parseData(dataNascimentoStr);
            if (dataNascEsperada != null) {
              final dataEncontrada = _encontrarDataNascimento(
                datas,
                dataNascimentoStr,
              );
              if (dataEncontrada == null) {
                erros.add('Data de nascimento não encontrada no passaporte.');
                valido = false;
              } else if (dataEncontrada.year != dataNascEsperada.year ||
                  dataEncontrada.month != dataNascEsperada.month ||
                  dataEncontrada.day != dataNascEsperada.day) {
                erros.add(
                  'Data de nascimento do passaporte não confere com a cadastrada.',
                );
                valido = false;
              }
            }
          }
          if (!_verificarNacionalidadeBrasileira(texto)) {
            erros.add(
              'Nacionalidade brasileira não identificada no passaporte.',
            );
            valido = false;
          }
          for (final data in datas) {
            final dataFuturaLimite = hojePass.add(
              const Duration(days: 365 * 15),
            );
            if (data.isAfter(dataFuturaLimite)) {
              erros.add('Data de emissão inválida (futura demais).');
              valido = false;
              break;
            }
          }
          break;
      }
    }

    setState(() {
      doc.isValid = valido;
      doc.isInvalid = !valido;
      doc.errorMessage = valido
          ? null
          : erros.isNotEmpty
          ? erros.join('\n')
          : 'Não foi possível identificar seus dados no documento anexado. Tente novamente com outro anexo.';
    });
  }

  /// Tenta encontrar a data de nascimento no documento comparando com a esperada
  DateTime? _encontrarDataNascimento(
    List<DateTime> datas,
    String? dataNascimentoEsperada,
  ) {
    if (datas.isEmpty) return null;

    final dataEsperada = _parseData(dataNascimentoEsperada);
    if (dataEsperada != null) {
      // Tenta encontrar data igual à esperada
      for (final data in datas) {
        if (data.year == dataEsperada.year &&
            data.month == dataEsperada.month &&
            data.day == dataEsperada.day) {
          return data;
        }
      }
    }

    // Se não encontrou pela data exata, retorna a primeira data que parece de nascimento
    // (geralmente a mais antiga)
    if (datas.length == 1) return datas.first;

    datas.sort((a, b) => a.compareTo(b));
    return datas.first;
  }

  DateTime? _parseData(String? dataStr) {
    if (dataStr == null || dataStr.isEmpty) return null;
    try {
      // Formato AAAA-MM-DD
      if (dataStr.contains('-')) {
        final partes = dataStr.split('-');
        return DateTime(
          int.parse(partes[0]),
          int.parse(partes[1]),
          int.parse(partes[2]),
        );
      }
      // Formato DD/MM/AAAA
      if (dataStr.contains('/')) {
        final partes = dataStr.split('/');
        return DateTime(
          int.parse(partes[2]),
          int.parse(partes[1]),
          int.parse(partes[0]),
        );
      }
    } catch (_) {}
    return null;
  }

  void _mostrarOpcoesDocumentoValido(_DocType doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          doc.label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (doc.filePathFrente != null) ...[
              const Text(
                'Frente:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: doc.filePathFrente!.toLowerCase().endsWith('.pdf')
                    ? const Icon(
                        Icons.picture_as_pdf,
                        size: 100,
                        color: Colors.red,
                      )
                    : Image.file(
                        File(doc.filePathFrente!),
                        height: 150,
                        fit: BoxFit.contain,
                      ),
              ),
            ],
            if (doc.filePathVerso != null) ...[
              const SizedBox(height: 12),
              const Text(
                'Verso:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: doc.filePathVerso!.toLowerCase().endsWith('.pdf')
                    ? const Icon(
                        Icons.picture_as_pdf,
                        size: 100,
                        color: Colors.red,
                      )
                    : Image.file(
                        File(doc.filePathVerso!),
                        height: 150,
                        fit: BoxFit.contain,
                      ),
              ),
            ],
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text(
                  'Documento validado com sucesso.',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Abrir seleção para trocar
              _selecionarDocumento(doc);
            },
            child: const Text('Trocar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                doc.isValid = false;
                doc.isInvalid = false;
                doc.filePathFrente = null;
                doc.filePathVerso = null;
                doc.errorMessage = null;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Remover', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  bool _podeEnviar() => _docTypes.any((d) => d.isValid);

  Future<void> _enviarDocumentos() async {
    if (!_podeEnviar()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'É necessário enviar pelo menos 1 documento anexado e validado.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Coletar tipos dos documentos validados
    final docsData = _docTypes
        .where((d) => d.isValid)
        .map((d) => {'tipo': d.type})
        .toList();

    if (mounted) {
      Navigator.pop(context, {'validado': true, 'docsData': docsData});
    }
  }
}

class _DocType {
  final String label;
  final String type;
  bool isValid = false;
  bool isInvalid = false;
  String? filePathFrente;
  String? filePathVerso;
  String? errorMessage;

  _DocType({required this.label, required this.type});
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
