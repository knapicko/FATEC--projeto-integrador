import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/consulta_cadastro_service.dart';
import '../services/formatacao_data.dart';
import '../services/validacao_documento.dart';
import '../services/validacao_telefone.dart';
import '../services/google_auth_service.dart';
import '../services/auth_navigation.dart';
import '../cadastro_profissional.dart';
import '../tela_home.dart';
import '../tela_home_profissional.dart';
import 'onboarding_step.dart';
import 'onboarding_theme.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingController._();
  static final OnboardingController instance = OnboardingController._();

  static const _prefsKey = 'onboarding_draft_v1';

  final ConsultaCadastroService _service = ConsultaCadastroService();

  final documento = TextEditingController();
  final identificadorLogin = TextEditingController();
  final senhaLogin = TextEditingController();
  final nome = TextEditingController();
  final dataNascimento = TextEditingController();
  final email = TextEditingController();
  final telefone = TextEditingController();
  final senha = TextEditingController();
  final confirmarSenha = TextEditingController();
  final cnpj = TextEditingController();
  final nomeFantasia = TextEditingController();
  final razaoSocial = TextEditingController();
  final dataFundacao = TextEditingController();

  OnboardingStep step = OnboardingStep.splash;
  final List<OnboardingStep> _historico = [];

  CaixaPose pose = CaixaPose.normal;
  String? historicoFala;
  String falaAtual = '';
  bool contentVisible = true;
  bool carregando = false;
  bool splashTitleVisible = true;
  bool documentoCadastrado = false;
  TipoContaOnboarding tipoConta = TipoContaOnboarding.nenhum;
  String ddi = '+55';
  bool aceitouTermos = false;
  bool aceitouPrivacidade = false;
  bool cnpjDeEmpresa = true;
  String? erroCampo;
  String? erroFala;
  bool _started = false;
  bool _hydrated = false;

  bool get isCnpj => somenteDigitos(documento.text).length > 11;
  bool get isCpf => somenteDigitos(documento.text).length == 11;

  bool get senhaTemOito => senha.text.length >= 8;
  bool get senhaMaiuscula => senha.text.contains(RegExp(r'[A-Z]'));
  bool get senhaMinuscula => senha.text.contains(RegExp(r'[a-z]'));
  bool get senhaSimbolo => senha.text.contains(RegExp(r'[^A-Za-z0-9\s]'));
  bool get senhaNumero => senha.text.contains(RegExp(r'[0-9]'));

  Future<void> ensureStarted() async {
    if (_started) return;
    _started = true;
    _bindPersist();
    await _hydrate();
    if (!_hydrated || step == OnboardingStep.splash) {
      splashTitleVisible = true;
      pose = CaixaPose.normal;
      _applyVisuals();
      notifyListeners();
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (step == OnboardingStep.splash) avancarPorToque();
      });
    } else {
      _applyVisuals();
      notifyListeners();
    }
  }

  void _bindPersist() {
    for (final c in [
      documento,
      identificadorLogin,
      senhaLogin,
      nome,
      dataNascimento,
      email,
      telefone,
      senha,
      confirmarSenha,
      cnpj,
      nomeFantasia,
      razaoSocial,
      dataFundacao,
    ]) {
      c.addListener(_persistDebounced);
    }
  }

  Timer? _persistTimer;
  void _persistDebounced() {
    notifyListeners();
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 250), persist);
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'step': step.name,
        'historico': _historico.map((e) => e.name).toList(),
        'documento': documento.text,
        'identificadorLogin': identificadorLogin.text,
        'senhaLogin': senhaLogin.text,
        'nome': nome.text,
        'dataNascimento': dataNascimento.text,
        'email': email.text,
        'telefone': telefone.text,
        'senha': senha.text,
        'confirmarSenha': confirmarSenha.text,
        'cnpj': cnpj.text,
        'nomeFantasia': nomeFantasia.text,
        'razaoSocial': razaoSocial.text,
        'dataFundacao': dataFundacao.text,
        'documentoCadastrado': documentoCadastrado,
        'tipoConta': tipoConta.name,
        'ddi': ddi,
        'aceitouTermos': aceitouTermos,
        'aceitouPrivacidade': aceitouPrivacidade,
        'cnpjDeEmpresa': cnpjDeEmpresa,
        'historicoFala': historicoFala,
        'falaAtual': falaAtual,
      }),
    );
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      step = OnboardingStep.values.firstWhere(
        (e) => e.name == map['step'],
        orElse: () => OnboardingStep.splash,
      );
      _historico
        ..clear()
        ..addAll(
          ((map['historico'] as List?) ?? [])
              .map(
                (n) => OnboardingStep.values.firstWhere(
                  (e) => e.name == n,
                  orElse: () => OnboardingStep.splash,
                ),
              )
              .where((e) => e != OnboardingStep.splash),
        );
      documento.text = map['documento'] as String? ?? '';
      identificadorLogin.text = map['identificadorLogin'] as String? ?? '';
      senhaLogin.text = map['senhaLogin'] as String? ?? '';
      nome.text = map['nome'] as String? ?? '';
      dataNascimento.text = map['dataNascimento'] as String? ?? '';
      email.text = map['email'] as String? ?? '';
      telefone.text = map['telefone'] as String? ?? '';
      senha.text = map['senha'] as String? ?? '';
      confirmarSenha.text = map['confirmarSenha'] as String? ?? '';
      cnpj.text = map['cnpj'] as String? ?? '';
      nomeFantasia.text = map['nomeFantasia'] as String? ?? '';
      razaoSocial.text = map['razaoSocial'] as String? ?? '';
      dataFundacao.text = map['dataFundacao'] as String? ?? '';
      documentoCadastrado = map['documentoCadastrado'] as bool? ?? false;
      tipoConta = TipoContaOnboarding.values.firstWhere(
        (e) => e.name == map['tipoConta'],
        orElse: () => TipoContaOnboarding.nenhum,
      );
      ddi = map['ddi'] as String? ?? '+55';
      aceitouTermos = map['aceitouTermos'] as bool? ?? false;
      aceitouPrivacidade = map['aceitouPrivacidade'] as bool? ?? false;
      cnpjDeEmpresa = map['cnpjDeEmpresa'] as bool? ?? true;
      historicoFala = map['historicoFala'] as String?;
      falaAtual = map['falaAtual'] as String? ?? '';
      _hydrated = step != OnboardingStep.splash;
    } catch (_) {}
  }

  Future<void> limparRascunho() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _historico.clear();
    for (final c in [
      documento,
      identificadorLogin,
      senhaLogin,
      nome,
      dataNascimento,
      email,
      telefone,
      senha,
      confirmarSenha,
      cnpj,
      nomeFantasia,
      razaoSocial,
      dataFundacao,
    ]) {
      c.clear();
    }
    step = OnboardingStep.splash;
    documentoCadastrado = false;
    tipoConta = TipoContaOnboarding.nenhum;
    aceitouTermos = false;
    aceitouPrivacidade = false;
    erroCampo = null;
    erroFala = null;
    historicoFala = null;
    falaAtual = '';
    splashTitleVisible = true;
    pose = CaixaPose.normal;
    _hydrated = false;
    _applyVisuals();
    notifyListeners();
  }

  Future<void> _transicionar(
    OnboardingStep next, {
    bool empilhar = true,
  }) async {
    if (empilhar && step != next) {
      _historico.add(step);
    }
    contentVisible = false;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 280));
    step = next;
    erroCampo = null;
    erroFala = null;
    _applyVisuals();
    contentVisible = true;
    notifyListeners();
    await persist();
  }

  void _applyVisuals() {
    switch (step) {
      case OnboardingStep.splash:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
        splashTitleVisible = true;
      case OnboardingStep.welcome:
        pose = CaixaPose.falandoFechado;
        historicoFala = null;
        falaAtual = 'Bem vindo(a) ao ConsertaJá';
        splashTitleVisible = false;
      case OnboardingStep.askDocument:
        pose = CaixaPose.falandoFechado;
        historicoFala = 'Bem vindo(a) ao ConsertaJá';
        falaAtual = 'Primeiro, nos informe o seu CPF ou o seu CNPJ';
      case OnboardingStep.documentInput:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.documentResult:
        pose = CaixaPose.falandoFechado;
        historicoFala = null;
        final docFmt = formatarCpfOuCnpj(documento.text);
        final tipo = rotuloDocumento(documento.text);
        falaAtual = documentoCadastrado
            ? 'Identifiquei que o $tipo $docFmt já está cadastrado no sistema'
            : 'Identifiquei que o $tipo $docFmt não está cadastrado no sistema';
      case OnboardingStep.loginOrOther:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual =
            'Gostaria de entrar na conta existente ou informar outro CPF/CNPJ?';
      case OnboardingStep.loginForm:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.continueOrLogin:
        pose = CaixaPose.normal;
        historicoFala =
            'Identifiquei que o ${rotuloDocumento(documento.text)} ${formatarCpfOuCnpj(documento.text)} não está cadastrado no sistema';
        falaAtual = 'Gostaria de continuar o cadastro ou entrar em outra conta?';
      case OnboardingStep.perfect:
        pose = CaixaPose.falandoFechado;
        historicoFala = null;
        falaAtual = 'Perfeito!';
      case OnboardingStep.chooseAccountPrompt:
        pose = CaixaPose.falandoFechado;
        historicoFala = 'Perfeito!';
        falaAtual = 'Agora escolha o tipo de conta que você quer criar.';
      case OnboardingStep.chooseAccount:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.clientPfPrompt:
        pose = CaixaPose.falandoFechado;
        historicoFala = null;
        falaAtual = 'Certo, agora me informe os seguintes dados:';
      case OnboardingStep.clientPfForm:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.contactPrompt:
        pose = CaixaPose.falandoFechado;
        historicoFala = null;
        falaAtual = 'Perfeito, agora me informe um email ou um telefone de contato';
      case OnboardingStep.contactForm:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.passwordPrompt:
        pose = CaixaPose.falandoFechado;
        historicoFala = null;
        falaAtual = 'Certo, agora defina uma senha para sua conta';
      case OnboardingStep.passwordForm:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.clientPjPrompt:
        pose = CaixaPose.falandoFechado;
        historicoFala = null;
        falaAtual =
            'Pelo CNPJ informado, consegui buscar as seguintes informações sobre sua empresa';
      case OnboardingStep.clientPjReviewPrompt:
        pose = CaixaPose.falandoFechado;
        historicoFala =
            'Pelo CNPJ informado, consegui buscar as seguintes informações sobre sua empresa';
        falaAtual = 'Revise as informações e faça alterações caso necessário';
      case OnboardingStep.clientPjForm:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.professionalHandoff:
        pose = CaixaPose.falandoFechado;
        historicoFala = null;
        falaAtual =
            'Vamos continuar o cadastro de profissional com os dados que você já informou.';
    }
  }

  Future<void> avancarPorToque() async {
    if (carregando) return;
    switch (step) {
      case OnboardingStep.splash:
        await _transicionar(OnboardingStep.welcome);
      case OnboardingStep.welcome:
        await _transicionar(OnboardingStep.askDocument);
      case OnboardingStep.askDocument:
        await _transicionar(OnboardingStep.documentInput);
      case OnboardingStep.documentResult:
        await _transicionar(
          documentoCadastrado
              ? OnboardingStep.loginOrOther
              : OnboardingStep.continueOrLogin,
        );
      case OnboardingStep.perfect:
        await _transicionar(OnboardingStep.chooseAccountPrompt);
      case OnboardingStep.chooseAccountPrompt:
        await _transicionar(OnboardingStep.chooseAccount);
      case OnboardingStep.clientPfPrompt:
        await _transicionar(OnboardingStep.clientPfForm);
      case OnboardingStep.contactPrompt:
        await _transicionar(OnboardingStep.contactForm);
      case OnboardingStep.passwordPrompt:
        await _transicionar(OnboardingStep.passwordForm);
      case OnboardingStep.clientPjPrompt:
        await _transicionar(OnboardingStep.clientPjReviewPrompt);
      case OnboardingStep.clientPjReviewPrompt:
        await _transicionar(OnboardingStep.clientPjForm);
      default:
        break;
    }
  }

  Future<void> voltar() async {
    if (_historico.isEmpty) return;
    final anterior = _historico.removeLast();
    contentVisible = false;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 250));
    step = anterior;
    erroCampo = null;
    erroFala = null;
    _applyVisuals();
    contentVisible = true;
    notifyListeners();
    await persist();
  }

  Future<void> continuarDocumento() async {
    erroFala = null;
    carregando = true;
    notifyListeners();
    final resultado = await _service.validarDocumento(documento.text);
    if (!resultado.valido) {
      carregando = false;
      erroFala = resultado.erro ?? 'O CPF/CNPJ informado não é válido';
      pose = CaixaPose.falandoAberto;
      notifyListeners();
      return;
    }

    if (resultado.empresa != null) {
      _aplicarEmpresa(resultado.empresa!);
    }

    documentoCadastrado = await _service.documentoJaCadastrado(documento.text);
    identificadorLogin.text = formatarCpfOuCnpj(documento.text);
    carregando = false;
    await _transicionar(OnboardingStep.documentResult);
  }

  void _aplicarEmpresa(DadosEmpresaCnpj empresa) {
    cnpj.text = formatarCnpj(somenteDigitos(documento.text));
    if ((empresa.razaoSocial ?? '').isNotEmpty) {
      razaoSocial.text = empresa.razaoSocial!;
    }
    if ((empresa.nomeFantasia ?? '').isNotEmpty) {
      nomeFantasia.text = empresa.nomeFantasia!;
    }
    if ((empresa.dataFundacaoBr ?? '').isNotEmpty) {
      dataFundacao.text = empresa.dataFundacaoBr!;
    }
    if ((empresa.telefone ?? '').isNotEmpty && telefone.text.isEmpty) {
      final limpo = empresa.telefone!.replaceAll(RegExp(r'\D'), '');
      if (limpo.length >= 10) {
        final ddd = limpo.substring(0, 2);
        final numero = limpo.substring(2);
        telefone.text = '($ddd) $numero';
      }
    }
  }

  Future<void> escolherEntrar() => _transicionar(OnboardingStep.loginForm);

  Future<void> escolherOutroDocumento() async {
    while (_historico.isNotEmpty &&
        _historico.last != OnboardingStep.documentInput) {
      _historico.removeLast();
    }
    if (_historico.isNotEmpty && _historico.last == OnboardingStep.documentInput) {
      _historico.removeLast();
    }
    await _transicionar(OnboardingStep.documentInput, empilhar: false);
  }

  Future<ResultadoLogin> entrar([BuildContext? context]) async {
    carregando = true;
    notifyListeners();
    final result = await _service.fazerLogin(
      identificador: identificadorLogin.text,
      senha: senhaLogin.text,
    );
    carregando = false;
    if (!result.sucesso) {
      erroCampo = result.mensagem;
      notifyListeners();
    } else {
      await limparRascunho();
      if (context != null && context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => result.isProfissional
                ? TelaHomeProfissional(isVisitante: false)
                : TelaHome(isVisitante: false),
          ),
          (_) => false,
        );
      }
    }
    notifyListeners();
    return result;
  }

  Future<void> loginComGoogle(BuildContext context) async {
    carregando = true;
    notifyListeners();
    try {
      final user = await GoogleAuthService.signInWithGoogle();
      if (user != null && context.mounted) {
        await navegarPosAutenticacaoGoogle(
          context,
          tipoContaEsperado: tipoConta == TipoContaOnboarding.cliente
              ? TipoContaCadastro.cliente
              : (tipoConta == TipoContaOnboarding.profissional
                  ? TipoContaCadastro.profissional
                  : null),
        );
      }
    } catch (e) {
      erroCampo = 'Erro ao entrar com Google: $e';
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  void navegarParaProfissional(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CadastroProfissionalPage(
          cpf: isCpf ? documento.text : null,
          cnpj: isCnpj ? (cnpj.text.isEmpty ? documento.text : cnpj.text) : null,
          nome: isCpf ? nome.text : null,
          razaoSocial: isCnpj ? razaoSocial.text : null,
          isPessoaFisica: isCpf,
          cnpjDeEmpresa: cnpjDeEmpresa,
        ),
      ),
    );
  }

  Future<void> continuarCadastro() => _transicionar(OnboardingStep.perfect);

  Future<void> irParaLogin() => _transicionar(OnboardingStep.loginForm);

  Future<void> selecionarTipoConta(TipoContaOnboarding tipo) async {
    tipoConta = tipo;
    notifyListeners();
    await persist();
    if (tipo == TipoContaOnboarding.profissional) {
      await _transicionar(OnboardingStep.professionalHandoff);
      return;
    }
    if (isCnpj) {
      carregando = true;
      notifyListeners();
      final empresa = await _service.buscarEmpresaPorCnpj(documento.text);
      if (empresa != null) _aplicarEmpresa(empresa);
      cnpj.text = formatarCnpj(somenteDigitos(documento.text));
      carregando = false;
      await _transicionar(OnboardingStep.clientPjPrompt);
    } else {
      await _transicionar(OnboardingStep.clientPfPrompt);
    }
  }

  Future<void> continuarDadosPf() async {
    erroCampo = null;
    if (nome.text.trim().isEmpty) {
      erroCampo = 'O nome é obrigatório';
      notifyListeners();
      return;
    }
    if (dataNascimento.text.trim().isEmpty) {
      erroCampo = 'A data de nascimento é obrigatória';
      notifyListeners();
      return;
    }
    await _transicionar(OnboardingStep.contactPrompt);
  }

  Future<void> continuarDadosPj() async {
    erroCampo = null;
    if (nomeFantasia.text.trim().isEmpty) {
      erroCampo = 'O Nome Fantasia é obrigatório';
      notifyListeners();
      return;
    }
    if (razaoSocial.text.trim().isEmpty) {
      erroCampo = 'A Razão Social é obrigatória';
      notifyListeners();
      return;
    }
    if (dataFundacao.text.trim().isEmpty) {
      erroCampo = 'A data de fundação é obrigatória';
      notifyListeners();
      return;
    }
    await _transicionar(OnboardingStep.contactPrompt);
  }

  Future<void> continuarContato() async {
    erroCampo = null;
    final emailVazio = email.text.trim().isEmpty;
    final telefoneVazio = telefone.text.trim().isEmpty;
    if (emailVazio && telefoneVazio) {
      erroCampo = 'Informe email ou telefone';
      notifyListeners();
      return;
    }
    if (!emailVazio && !_service.emailFormatoValido(email.text)) {
      erroCampo = 'Informe um e-mail válido';
      notifyListeners();
      return;
    }
    if (!telefoneVazio) {
      final validacao = validarTelefoneCompleto(telefone.text);
      if (!validacao.valido) {
        erroCampo = validacao.erro;
        notifyListeners();
        return;
      }
    }
    carregando = true;
    notifyListeners();
    if (!emailVazio) {
      final dup = await _service.verificarEmailDuplicado(email.text);
      if (dup != null) {
        carregando = false;
        erroFala = dup;
        pose = CaixaPose.falandoFechado;
        notifyListeners();
        return;
      }
    }
    if (!telefoneVazio) {
      final dup = await _service.verificarTelefoneDuplicado(telefone.text);
      if (dup != null) {
        carregando = false;
        erroFala = dup;
        pose = CaixaPose.falandoFechado;
        notifyListeners();
        return;
      }
    }
    carregando = false;
    await _transicionar(OnboardingStep.passwordPrompt);
  }

  Future<ResultadoCadastroCliente?> finalizarCadastro([BuildContext? context]) async {
    erroCampo = null;
    if (!senhaTemOito ||
        !senhaMaiuscula ||
        !senhaMinuscula ||
        !senhaSimbolo ||
        !senhaNumero) {
      erroCampo = 'Por favor, preencha todos os requisitos de segurança da senha.';
      notifyListeners();
      return null;
    }
    if (senha.text != confirmarSenha.text) {
      erroCampo = 'As senhas digitadas não coincidem.';
      notifyListeners();
      return null;
    }
    if (!aceitouTermos || !aceitouPrivacidade) {
      erroCampo = 'Aceite os Termos de Uso e a Política de Privacidade.';
      notifyListeners();
      return null;
    }

    carregando = true;
    notifyListeners();
    final result = await _service.finalizarCadastroCliente(
      nome: isCnpj ? nomeFantasia.text.trim() : nome.text.trim(),
      cpf: isCpf ? documento.text.trim() : null,
      cnpj: isCnpj ? (cnpj.text.trim().isEmpty ? documento.text.trim() : cnpj.text.trim()) : null,
      razaoSocial: isCnpj ? razaoSocial.text.trim() : null,
      nomeFantasia: isCnpj ? nomeFantasia.text.trim() : null,
      isPessoaFisica: isCpf,
      cnpjDeEmpresa: cnpjDeEmpresa,
      email: email.text.trim(),
      telefone: telefone.text.trim(),
      dataNascimentoIso: converterDataParaIso(dataNascimento.text.trim()),
      dataFundacaoIso: converterDataParaIso(dataFundacao.text.trim()),
      senha: senha.text,
    );
    carregando = false;
    if (!result.sucesso) {
      erroCampo = result.mensagem;
      notifyListeners();
      return result;
    }
    await limparRascunho();
    if (context != null && context.mounted) {
      if (result.precisaConfirmarEmail) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cadastro realizado! Confirme seu e-mail para continuar.'),
          ),
        );
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => TelaHome(isVisitante: false)),
        (_) => false,
      );
    }
    return result;
  }

  void setDdi(String value) {
    ddi = value;
    notifyListeners();
    persist();
  }

  void toggleTermos() {
    aceitouTermos = !aceitouTermos;
    notifyListeners();
    persist();
  }

  void togglePrivacidade() {
    aceitouPrivacidade = !aceitouPrivacidade;
    notifyListeners();
    persist();
  }
}
