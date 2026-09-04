import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/consulta_cadastro_service.dart';
import '../services/formatacao_data.dart';
import '../services/validacao_documento.dart';
import '../services/validacao_telefone.dart';
import '../services/google_auth_service.dart';
import '../services/auth_navigation.dart';
import '../cadastro_profissional.dart';
import '../login.dart';
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

  // ── Estado exclusivo do fluxo Profissional ──────────────────────────────────
  List<Map<String, dynamic>> oficios = [];
  final List<Map<String, dynamic>> oficiosSelecionados = [];
  bool carregandoOficios = false;

  bool cadastroFacialConcluido = false;
  bool documentoIdentidadeConcluido = false;
  String? idFacial;
  String? fotoPerfilUrl;
  List<Map<String, dynamic>> documentosValidados = [];

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
        // Profissional
        'oficiosSelecionados': oficiosSelecionados,
        'cadastroFacialConcluido': cadastroFacialConcluido,
        'documentoIdentidadeConcluido': documentoIdentidadeConcluido,
        'idFacial': idFacial,
        'fotoPerfilUrl': fotoPerfilUrl,
        'documentosValidados': documentosValidados,
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
      // Profissional
      cadastroFacialConcluido = map['cadastroFacialConcluido'] as bool? ?? false;
      documentoIdentidadeConcluido = map['documentoIdentidadeConcluido'] as bool? ?? false;
      idFacial = map['idFacial'] as String?;
      fotoPerfilUrl = map['fotoPerfilUrl'] as String?;
      final rawOficios = map['oficiosSelecionados'];
      if (rawOficios is List) {
        oficiosSelecionados
          ..clear()
          ..addAll(rawOficios.whereType<Map<String, dynamic>>());
      }
      final rawDocs = map['documentosValidados'];
      if (rawDocs is List) {
        documentosValidados
          ..clear()
          ..addAll(rawDocs.whereType<Map<String, dynamic>>());
      }
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
    // Profissional
    oficios.clear();
    oficiosSelecionados.clear();
    carregandoOficios = false;
    cadastroFacialConcluido = false;
    documentoIdentidadeConcluido = false;
    idFacial = null;
    fotoPerfilUrl = null;
    documentosValidados.clear();
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
        pose = CaixaPose.falandoAberto;
        historicoFala = null;
        falaAtual = 'Certo, agora me informe os seguintes dados:';
      case OnboardingStep.profDataForm:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.profPjReviewPrompt:
        pose = CaixaPose.falandoAberto;
        historicoFala = null;
        falaAtual =
            'Pelo CNPJ informado, consegui buscar as seguintes informações sobre sua empresa';
      case OnboardingStep.profPjReviewPrompt2:
        pose = CaixaPose.falandoFechado;
        historicoFala =
            'Pelo CNPJ informado, consegui buscar as seguintes informações sobre sua empresa';
        falaAtual = 'Revise as informações e faça alterações caso necessário';
      case OnboardingStep.profPjForm:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.profContactPrompt:
        pose = CaixaPose.falandoFechado;
        historicoFala = null;
        falaAtual = 'Perfeito, agora me informe um email ou um telefone de contato';
      case OnboardingStep.profContactForm:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.profPasswordPrompt:
        pose = CaixaPose.falandoFechado;
        historicoFala = null;
        falaAtual = 'Certo, agora defina uma senha para sua conta';
      case OnboardingStep.profPasswordForm:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.profAreaPrompt1:
        pose = CaixaPose.falandoAberto;
        historicoFala = null;
        falaAtual = 'Certo, agora preciso que você escolha até 3 áreas de atuação';
      case OnboardingStep.profAreaPrompt2:
        pose = CaixaPose.falandoAberto;
        historicoFala = 'Certo, agora preciso que você escolha até 3 áreas de atuação';
        falaAtual = 'Essas são as áreas que você atua no seu dia a dia';
      case OnboardingStep.profAreaPrompt3:
        pose = CaixaPose.falandoFechado;
        historicoFala = 'Essas são as áreas que você atua no seu dia a dia';
        falaAtual =
            'Não se preocupe, você poderá modificar as áreas escolhidas a qualquer momento durante o uso do app.';
      case OnboardingStep.profAreaForm:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
      case OnboardingStep.profDocsPrompt1:
        pose = CaixaPose.falandoAberto;
        historicoFala = null;
        falaAtual = 'Agora só preciso de alguns documentos para finalizar seu cadastro';
      case OnboardingStep.profDocsPrompt2:
        pose = CaixaPose.falandoFechado;
        historicoFala = 'Agora só preciso de alguns documentos para finalizar seu cadastro';
        falaAtual = 'E não se preocupe, nós não salvamos nenhum documento no nosso banco de dados';
      case OnboardingStep.profDocsForm:
        pose = CaixaPose.normal;
        historicoFala = null;
        falaAtual = '';
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
      case OnboardingStep.professionalHandoff:
        await _transicionar(OnboardingStep.profDataForm);
      case OnboardingStep.profPjReviewPrompt:
        await _transicionar(OnboardingStep.profPjReviewPrompt2);
      case OnboardingStep.profPjReviewPrompt2:
        await _transicionar(OnboardingStep.profPjForm);
      case OnboardingStep.profContactPrompt:
        await _transicionar(OnboardingStep.profContactForm);
      case OnboardingStep.profPasswordPrompt:
        await _transicionar(OnboardingStep.profPasswordForm);
      case OnboardingStep.profAreaPrompt1:
        await _transicionar(OnboardingStep.profAreaPrompt2);
      case OnboardingStep.profAreaPrompt2:
        await _transicionar(OnboardingStep.profAreaPrompt3);
      case OnboardingStep.profAreaPrompt3:
        if (oficios.isEmpty) await carregarOficios();
        await _transicionar(OnboardingStep.profAreaForm);
      case OnboardingStep.profDocsPrompt1:
        await _transicionar(OnboardingStep.profDocsPrompt2);
      case OnboardingStep.profDocsPrompt2:
        await _transicionar(OnboardingStep.profDocsForm);
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

  // ── Profissional: Áreas de Atuação ─────────────────────────────────────────

  Future<void> carregarOficios() async {
    if (oficios.isNotEmpty) return; // Já carregados
    carregandoOficios = true;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('oficios')
          .select('id_oficio, funcao')
          .order('funcao');
      oficios = List<Map<String, dynamic>>.from(response);
    } catch (_) {}
    carregandoOficios = false;
    notifyListeners();
  }

  void toggleOficio(Map<String, dynamic> oficio) {
    final isSelected = oficiosSelecionados.any(
      (e) => e['id_oficio'] == oficio['id_oficio'],
    );
    if (isSelected) {
      oficiosSelecionados.removeWhere((e) => e['id_oficio'] == oficio['id_oficio']);
    } else {
      if (oficiosSelecionados.length >= 3) return; // Limite de 3
      oficiosSelecionados.add(oficio);
    }
    notifyListeners();
    persist();
  }

  // ── Profissional: Callbacks de retorno de sub-telas ─────────────────────────

  void setCadastroFacial(String idFacialResultado) {
    idFacial = idFacialResultado;
    cadastroFacialConcluido = true;
    notifyListeners();
    persist();
  }

  void setDocumentoIdentidade(List<Map<String, dynamic>> docs) {
    documentosValidados
      ..clear()
      ..addAll(docs);
    documentoIdentidadeConcluido = true;
    notifyListeners();
    persist();
  }

  // ── Profissional: Navegação por step ────────────────────────────────────────

  Future<void> continuarDadosProf() async {
    erroCampo = null;
    if (isCpf) {
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
    }
    await _transicionar(OnboardingStep.profContactPrompt);
  }

  Future<void> continuarDadosPjProf() async {
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
    await _transicionar(OnboardingStep.profContactPrompt);
  }

  Future<void> continuarContatoProf() async {
    erroCampo = null;
    erroFala = null;
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
    await _transicionar(OnboardingStep.profPasswordPrompt);
  }

  Future<void> continuarSenhaProf() async {
    erroCampo = null;
    if (!senhaTemOito || !senhaMaiuscula || !senhaMinuscula || !senhaSimbolo || !senhaNumero) {
      erroCampo = 'Por favor, preencha todos os requisitos de segurança da senha.';
      notifyListeners();
      return;
    }
    if (senha.text != confirmarSenha.text) {
      erroCampo = 'As senhas digitadas não coincidem.';
      notifyListeners();
      return;
    }
    if (oficios.isEmpty) await carregarOficios();
    await _transicionar(OnboardingStep.profAreaPrompt1);
  }

  Future<void> continuarAreasProf() async {
    erroCampo = null;
    if (oficiosSelecionados.isEmpty) {
      erroCampo = 'Selecione pelo menos 1 área de atuação';
      notifyListeners();
      return;
    }
    await _transicionar(OnboardingStep.profDocsPrompt1);
  }

  Future<void> finalizarCadastroProfissional(BuildContext context) async {
    erroCampo = null;
    if (!aceitouTermos || !aceitouPrivacidade) {
      erroCampo = 'Aceite os Termos de Uso e a Política de Privacidade.';
      notifyListeners();
      return;
    }
    if (!cadastroFacialConcluido) {
      erroCampo = 'Faça o cadastro facial antes de finalizar.';
      notifyListeners();
      return;
    }
    if (!documentoIdentidadeConcluido) {
      erroCampo = 'Valide seu documento de identidade antes de finalizar.';
      notifyListeners();
      return;
    }
    carregando = true;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;

      final authResponse = await supabase.auth.signUp(
        email: email.text.trim(),
        password: senha.text,
      );
      final authUser = authResponse.user;
      if (authUser == null) throw Exception('Falha ao criar conta de autenticação.');
      final authId = authUser.id;
      final precisaConfirmarEmail = authResponse.session == null;

      final emailResponse = await supabase
          .from('emails')
          .insert({'endereco_email': email.text.trim(), 'fk_status': 1})
          .select()
          .single();
      final emailId = emailResponse['id_email'];

      final telefoneLimpo = telefone.text.replaceAll(RegExp(r'\D'), '');
      final ddd2 = telefoneLimpo.length >= 2 ? telefoneLimpo.substring(0, 2) : '';
      final numero = telefoneLimpo.length > 2 ? telefoneLimpo.substring(2) : telefoneLimpo;
      final telefoneResponse = await supabase
          .from('telefones')
          .insert({'ddd': ddd2, 'numero': numero, 'fk_status': 1})
          .select()
          .single();
      final telefoneId = telefoneResponse['id_telefone'];

      int assTipoPessoaId;
      if (isCpf) {
        final cpfLimpo = somenteDigitos(documento.text);
        final pfResponse = await supabase
            .from('pessoa_fisica')
            .insert({'cpf': cpfLimpo.isNotEmpty ? cpfLimpo : null})
            .select()
            .single();
        final pfId = pfResponse['id_pessoa_fisica'];
        final assResponse = await supabase
            .from('ass_tipo_pessoa')
            .insert({'tipo': 'Física', 'fk_pessoa_fisica': pfId, 'fk_pessoa_juridica': null})
            .select()
            .single();
        assTipoPessoaId = assResponse['id_tipo_pessoa'];
      } else {
        final cnpjLimpo = somenteDigitos(cnpj.text.isEmpty ? documento.text : cnpj.text);
        final pjResponse = await supabase
            .from('pessoa_juridica')
            .insert({
              'cnpj': cnpjLimpo.isNotEmpty ? cnpjLimpo : null,
              'razao_social': razaoSocial.text.trim(),
              'nome_fantasia': nomeFantasia.text.trim(),
              'tem_imovel': !cnpjDeEmpresa,
              'data_fundacao': converterDataParaIso(dataFundacao.text.trim()).isNotEmpty
                  ? converterDataParaIso(dataFundacao.text.trim())
                  : null,
            })
            .select()
            .single();
        final pjId = pjResponse['id_pessoa_juridica'];
        final assResponse = await supabase
            .from('ass_tipo_pessoa')
            .insert({'tipo': 'Jurídica', 'fk_pessoa_fisica': null, 'fk_pessoa_juridica': pjId})
            .select()
            .single();
        assTipoPessoaId = assResponse['id_tipo_pessoa'];
      }

      final dataNasc = converterDataParaIso(dataNascimento.text.trim());
      final usuarioResponse = await supabase
          .from('usuarios')
          .insert({
            'nome': isCpf ? nome.text.trim() : nomeFantasia.text.trim(),
            'data_nascimento': dataNasc.isNotEmpty ? dataNasc : null,
            'data_criacao': DateTime.now().toUtc().toIso8601String(),
            'tipo_conta': 'Profissional',
            'fk_email': emailId,
            'fk_telefone': telefoneId,
            'fk_tipo_pessoa': assTipoPessoaId,
            'foto_perfil_url': fotoPerfilUrl,
            'auth_id': authId,
          })
          .select()
          .single();
      final usuarioId = usuarioResponse['id_usuario'];

      final dadosProfResponse = await supabase
          .from('dados_profissionais')
          .insert({
            'fk_usuario': usuarioId,
            'id_facial': idFacial,
            'rosto_validado': true,
            'data_admissao': DateTime.now().toIso8601String().split('T').first,
          })
          .select()
          .single();
      final profissionalId = dadosProfResponse['id_profissional'];

      for (final oficio in oficiosSelecionados) {
        try {
          await supabase
              .from('ass_oficio_profissional')
              .insert({'fk_profissional': profissionalId, 'fk_oficio': oficio['id_oficio']})
              .select()
              .maybeSingle();
        } catch (e) {
          debugPrint('Falha ao inserir ofício ${oficio['id_oficio']}: $e');
        }
      }

      for (final doc in documentosValidados) {
        await supabase.from('documentos_profissionais').insert({
          'tipo_documento': doc['tipo'],
          'fk_profissional': profissionalId,
          'validacao_documento': true,
        });
      }

      carregando = false;
      await limparRascunho();
      if (context.mounted) {
        if (precisaConfirmarEmail) {
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
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (_) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => TelaHomeProfissional(isVisitante: false)),
            (_) => false,
          );
        }
      }
    } on AuthException catch (e) {
      carregando = false;
      erroCampo = e.message.toLowerCase().contains('already') ||
              e.message.toLowerCase().contains('duplicate')
          ? 'Este e-mail já está cadastrado em nossa plataforma.'
          : e.message;
      notifyListeners();
    } catch (e) {
      carregando = false;
      erroCampo = e.toString().replaceAll('Exception: ', '');
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
      if (isCnpj) {
        // PJ profissional: reutiliza dados já buscados via BrasilAPI
        cnpj.text = formatarCnpj(somenteDigitos(documento.text));
        await _transicionar(OnboardingStep.profPjReviewPrompt);
      } else {
        await _transicionar(OnboardingStep.professionalHandoff);
      }
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
