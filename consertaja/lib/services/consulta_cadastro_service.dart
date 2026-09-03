import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'formatacao_data.dart';
import 'validacao_documento.dart';
import 'validacao_telefone.dart';

class DadosEmpresaCnpj {
  final String? razaoSocial;
  final String? nomeFantasia;
  final String? dataFundacaoBr;
  final String? telefone;

  const DadosEmpresaCnpj({
    this.razaoSocial,
    this.nomeFantasia,
    this.dataFundacaoBr,
    this.telefone,
  });
}

class ResultadoValidacaoDocumento {
  final bool valido;
  final String? erro;
  final DadosEmpresaCnpj? empresa;

  const ResultadoValidacaoDocumento({
    required this.valido,
    this.erro,
    this.empresa,
  });
}

class ResultadoLogin {
  final bool sucesso;
  final bool isProfissional;
  final bool perfilIncompleto;
  final String? mensagem;
  final String? authId;
  final String? email;
  final String? nomeGoogle;
  final String? fotoUrlGoogle;

  const ResultadoLogin({
    required this.sucesso,
    this.isProfissional = false,
    this.perfilIncompleto = false,
    this.mensagem,
    this.authId,
    this.email,
    this.nomeGoogle,
    this.fotoUrlGoogle,
  });
}

class ResultadoCadastroCliente {
  final bool sucesso;
  final bool precisaConfirmarEmail;
  final String? mensagem;

  const ResultadoCadastroCliente({
    required this.sucesso,
    this.precisaConfirmarEmail = false,
    this.mensagem,
  });
}

/// Consultas e cadastro já usados em [cadastro_cliente.dart], [cadastro_profissional.dart] e [login.dart].
class ConsultaCadastroService {
  ConsultaCadastroService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static final _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

  bool emailFormatoValido(String email) => _emailRegex.hasMatch(email.trim());

  /// Mesma regra local + BrasilAPI de [CadastroClientePage._validarDocumentoDigitado].
  Future<ResultadoValidacaoDocumento> validarDocumento(String documento) async {
    final doc = somenteDigitos(documento);

    if (doc.isEmpty) {
      return const ResultadoValidacaoDocumento(
        valido: false,
        erro: 'O CPF/CNPJ informado não é válido',
      );
    }

    if (doc.length <= 11) {
      if (doc.length < 11 || !validarCpf(doc)) {
        return const ResultadoValidacaoDocumento(
          valido: false,
          erro: 'O CPF/CNPJ informado não é válido',
        );
      }
      return const ResultadoValidacaoDocumento(valido: true);
    }

    if (doc.length < 14 || !validarCnpj(doc)) {
      return const ResultadoValidacaoDocumento(
        valido: false,
        erro: 'O CPF/CNPJ informado não é válido',
      );
    }

    try {
      final response = await http.get(
        Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$doc'),
      );

      if (response.statusCode != 200) {
        return const ResultadoValidacaoDocumento(
          valido: false,
          erro: 'O CPF/CNPJ informado não é válido',
        );
      }

      return ResultadoValidacaoDocumento(
        valido: true,
        empresa: _empresaFromBrasilApi(json.decode(response.body)),
      );
    } catch (_) {
      return const ResultadoValidacaoDocumento(
        valido: false,
        erro: 'Não foi possível validar o CNPJ agora.',
      );
    }
  }

  /// Auto-preenchimento de [CadastroClientePage._autoPreencherDadosCnpj] + data de fundação da mesma API.
  Future<DadosEmpresaCnpj?> buscarEmpresaPorCnpj(String documento) async {
    final doc = somenteDigitos(documento);
    if (doc.length < 14 || !validarCnpj(doc)) return null;

    try {
      final response = await http.get(
        Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$doc'),
      );
      if (response.statusCode != 200) return null;
      return _empresaFromBrasilApi(json.decode(response.body));
    } catch (e) {
      debugPrint('Erro ao auto-preencher dados do CNPJ: $e');
      return null;
    }
  }

  DadosEmpresaCnpj _empresaFromBrasilApi(Map<String, dynamic> data) {
    final razaoSocial = data['razao_social'] as String?;
    final nomeFantasia = data['nome_fantasia'] as String?;
    final telefone =
        (data['ddd_telefone_1'] as String?) ?? (data['ddd_telefone'] as String?);
    final dataIso =
        (data['data_inicio_atividade'] as String?) ??
        (data['data_inicio_atividades'] as String?);

    String? dataBr;
    if (dataIso != null && dataIso.isNotEmpty) {
      dataBr = formatarDataBrasileira(dataIso.split('T').first);
    }

    return DadosEmpresaCnpj(
      razaoSocial: razaoSocial,
      nomeFantasia: nomeFantasia,
      dataFundacaoBr: dataBr,
      telefone: telefone,
    );
  }

  /// Mesma consulta de [CadastroProfissionalPage] em pessoa_fisica / pessoa_juridica.
  Future<bool> documentoJaCadastrado(String documento) async {
    final doc = somenteDigitos(documento);
    try {
      if (doc.length == 11) {
        final result = await _supabase
            .from('pessoa_fisica')
            .select('id_pessoa_fisica')
            .eq('cpf', doc)
            .maybeSingle();
        return result != null;
      }
      if (doc.length == 14) {
        final result = await _supabase
            .from('pessoa_juridica')
            .select('id_pessoa_juridica')
            .eq('cnpj', doc)
            .maybeSingle();
        return result != null;
      }
    } catch (_) {}
    return false;
  }

  /// [CadastroClientePage._verificarEmailDuplicado]
  Future<String?> verificarEmailDuplicado(String email) async {
    final trimmed = email.trim();
    if (!_emailRegex.hasMatch(trimmed)) return null;
    try {
      final list = await _supabase
          .from('emails')
          .select('endereco_email')
          .eq('endereco_email', trimmed);
      if (list.isNotEmpty) return 'Este e-mail já está em uso.';
    } catch (e) {
      debugPrint('Erro ao verificar email: $e');
    }
    return null;
  }

  /// [CadastroClientePage._verificarTelefoneDuplicado]
  Future<String?> verificarTelefoneDuplicado(String telefone) async {
    final apenasNumeros = telefone.replaceAll(RegExp(r'\D'), '');
    if (apenasNumeros.length < 10) return null;

    final validacao = validarTelefoneCompleto(telefone);
    if (!validacao.valido) return validacao.erro;

    final dddDigitado = apenasNumeros.substring(0, 2);
    final numeroDigitado = apenasNumeros.substring(2);

    try {
      final list = await _supabase
          .from('telefones')
          .select('numero')
          .eq('ddd', dddDigitado)
          .eq('numero', numeroDigitado);
      if (list.isNotEmpty) return 'Este telefone já está cadastrado.';
    } catch (e) {
      debugPrint('Erro ao verificar telefone: $e');
    }
    return null;
  }

  Future<String?> _emailPorDocumento(String digits) async {
    try {
      int? tipoPessoaId;
      if (digits.length == 11) {
        final pf = await _supabase
            .from('pessoa_fisica')
            .select('id_pessoa_fisica')
            .eq('cpf', digits)
            .maybeSingle();
        final pfId = pf?['id_pessoa_fisica'];
        if (pfId == null) return null;
        final ass = await _supabase
            .from('ass_tipo_pessoa')
            .select('id_tipo_pessoa')
            .eq('fk_pessoa_fisica', pfId)
            .maybeSingle();
        tipoPessoaId = (ass?['id_tipo_pessoa'] as num?)?.toInt();
      } else if (digits.length == 14) {
        final pj = await _supabase
            .from('pessoa_juridica')
            .select('id_pessoa_juridica')
            .eq('cnpj', digits)
            .maybeSingle();
        final pjId = pj?['id_pessoa_juridica'];
        if (pjId == null) return null;
        final ass = await _supabase
            .from('ass_tipo_pessoa')
            .select('id_tipo_pessoa')
            .eq('fk_pessoa_juridica', pjId)
            .maybeSingle();
        tipoPessoaId = (ass?['id_tipo_pessoa'] as num?)?.toInt();
      }
      if (tipoPessoaId == null) return null;

      final usuario = await _supabase
          .from('usuarios')
          .select('fk_email')
          .eq('fk_tipo_pessoa', tipoPessoaId)
          .maybeSingle();
      final emailId = usuario?['fk_email'];
      if (emailId == null) return null;

      final emailRow = await _supabase
          .from('emails')
          .select('endereco_email')
          .eq('id_email', emailId)
          .maybeSingle();
      return emailRow?['endereco_email'] as String?;
    } catch (e) {
      debugPrint('Erro ao resolver e-mail do documento: $e');
      return null;
    }
  }

  /// Login de [LoginPage._fazerLogin], aceitando e-mail ou CPF/CNPJ no identificador.
  Future<ResultadoLogin> fazerLogin({
    required String identificador,
    required String senha,
  }) async {
    if (identificador.trim().isEmpty || senha.isEmpty) {
      return const ResultadoLogin(
        sucesso: false,
        mensagem: 'Preencha email e senha para entrar.',
      );
    }

    var email = identificador.trim();
    if (!_emailRegex.hasMatch(email)) {
      final digits = somenteDigitos(identificador);
      final resolvido = await _emailPorDocumento(digits);
      if (resolvido == null || resolvido.isEmpty) {
        return const ResultadoLogin(
          sucesso: false,
          mensagem: 'Não foi possível localizar o e-mail desta conta. Use o e-mail de cadastro.',
        );
      }
      email = resolvido;
    }

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: senha,
      );

      if (response.user == null) {
        return const ResultadoLogin(
          sucesso: false,
          mensagem: 'Email ou senha incorretos.',
        );
      }

      final usuarioResponse = await _supabase
          .from('usuarios')
          .select('tipo_conta')
          .eq('auth_id', response.user!.id)
          .maybeSingle();

      final isProfissional = usuarioResponse?['tipo_conta'] == 'Profissional';
      return ResultadoLogin(
        sucesso: true,
        isProfissional: isProfissional,
        perfilIncompleto: usuarioResponse == null,
      );
    } on AuthException catch (e) {
      var mensagem = 'Email ou senha incorretos.';
      if (e.message.contains('Email not confirmed')) {
        mensagem = 'Confirme seu email antes de fazer login.';
      }
      return ResultadoLogin(sucesso: false, mensagem: mensagem);
    } catch (e) {
      return ResultadoLogin(sucesso: false, mensagem: 'Erro ao fazer login: $e');
    }
  }

  /// [CadastroClienteEtapa2Page._finalizarCadastroBanco]
  Future<ResultadoCadastroCliente> finalizarCadastroCliente({
    required String nome,
    String? cpf,
    String? cnpj,
    String? razaoSocial,
    String? nomeFantasia,
    required bool isPessoaFisica,
    required bool cnpjDeEmpresa,
    required String email,
    required String telefone,
    required String dataNascimentoIso,
    required String dataFundacaoIso,
    required String senha,
    String fotoPerfilUrl = 'null',
  }) async {
    try {
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: senha,
      );

      final authUser = authResponse.user;
      if (authUser == null) {
        throw Exception('Falha ao criar conta de autenticação.');
      }

      final authId = authUser.id;
      final precisaConfirmarEmail = authResponse.session == null;

      int? emailId;
      if (email.isNotEmpty) {
        final emailResponse = await _supabase
            .from('emails')
            .insert({'endereco_email': email, 'fk_status': 1})
            .select()
            .single();
        emailId = emailResponse['id_email'];
      }

      int? telefoneId;
      if (telefone.isNotEmpty) {
        final telefoneLimpo = telefone.replaceAll(RegExp(r'\D'), '');
        final ddd = telefoneLimpo.length >= 2
            ? telefoneLimpo.substring(0, 2)
            : '';
        final numero = telefoneLimpo.length > 2
            ? telefoneLimpo.substring(2)
            : telefoneLimpo;

        final telefoneResponse = await _supabase
            .from('telefones')
            .insert({'ddd': ddd, 'numero': numero, 'fk_status': 1})
            .select()
            .single();
        telefoneId = telefoneResponse['id_telefone'];
      }

      late int assTipoPessoaId;

      if (isPessoaFisica) {
        final cpfLimpo = cpf?.replaceAll(RegExp(r'\D'), '') ?? '';
        final pfResponse = await _supabase
            .from('pessoa_fisica')
            .insert({'cpf': cpfLimpo.isNotEmpty ? cpfLimpo : null})
            .select()
            .single();
        final pfId = pfResponse['id_pessoa_fisica'];

        final assResponse = await _supabase
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
        final cnpjLimpo = cnpj?.replaceAll(RegExp(r'\D'), '') ?? '';
        final pjResponse = await _supabase
            .from('pessoa_juridica')
            .insert({
              'cnpj': cnpjLimpo.isNotEmpty ? cnpjLimpo : null,
              'razao_social': razaoSocial,
              'nome_fantasia': nomeFantasia,
              'tem_imovel': !cnpjDeEmpresa,
              'data_fundacao': dataFundacaoIso.isNotEmpty ? dataFundacaoIso : null,
            })
            .select()
            .single();
        final pjId = pjResponse['id_pessoa_juridica'];

        final assResponse = await _supabase
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

      await _supabase.from('usuarios').insert({
        'nome': nome,
        'data_nascimento': dataNascimentoIso.isNotEmpty
            ? dataNascimentoIso
            : null,
        'data_criacao': DateTime.now().toUtc().toIso8601String(),
        'tipo_conta': 'Cliente',
        'fk_email': emailId,
        'fk_telefone': telefoneId,
        'fk_tipo_pessoa': assTipoPessoaId,
        'foto_perfil_url': fotoPerfilUrl,
        'auth_id': authId,
      });

      return ResultadoCadastroCliente(
        sucesso: true,
        precisaConfirmarEmail: precisaConfirmarEmail,
      );
    } on AuthException catch (e) {
      var mensagemAmigavel = 'Ocorreu um erro ao registrar.';

      if (e.toString().contains('AuthWeakPasswordException') ||
          e.message.toLowerCase().contains('password should be at least') ||
          e.statusCode == '422') {
        final match = RegExp(
          r'at least (\d{1,3})',
          caseSensitive: false,
        ).firstMatch(e.message);
        final requerido = match != null ? int.parse(match.group(1)!) : 8;
        mensagemAmigavel =
            'Senha muito fraca para o servidor! Ela precisa ter no mínimo '
            '$requerido caracteres, combinando letras maiúsculas, minúsculas, '
            'números e símbolos.';
      } else if (e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('already exists')) {
        mensagemAmigavel =
            'Este e-mail já está cadastrado em nossa plataforma.';
      } else {
        mensagemAmigavel = e.message;
      }
      return ResultadoCadastroCliente(sucesso: false, mensagem: mensagemAmigavel);
    } catch (e) {
      return ResultadoCadastroCliente(
        sucesso: false,
        mensagem:
            'Falha ao registrar: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }
}
