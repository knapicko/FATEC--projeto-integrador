import 'package:flutter/material.dart';

import 'onboarding_controller.dart';
import 'onboarding_step.dart';
import 'onboarding_theme.dart';
import 'onboarding_widgets.dart';
import '../cadastro_profissional.dart';
import '../services/validacao_documento.dart';

class ConversationalOnboardingScreen extends StatefulWidget {
  const ConversationalOnboardingScreen({super.key});

  @override
  State<ConversationalOnboardingScreen> createState() =>
      _ConversationalOnboardingScreenState();
}

class _ConversationalOnboardingScreenState
    extends State<ConversationalOnboardingScreen> {
  final OnboardingController _controller = OnboardingController.instance;
  bool _senhaOculta = true;
  bool _confirmarSenhaOculta = true;
  bool _senhaLoginOculta = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.ensureStarted();
    });
  }

  Future<void> _selecionarData(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final agora = DateTime.now();
    final selecionada = await showDatePicker(
      context: context,
      initialDate: DateTime(agora.year - 20, 1, 1),
      firstDate: DateTime(1900),
      lastDate: agora,
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: OnboardingColors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (selecionada != null) {
      final dia = selecionada.day.toString().padLeft(2, '0');
      final mes = selecionada.month.toString().padLeft(2, '0');
      final ano = selecionada.year.toString();
      controller.text = '$dia/$mes/$ano';
    }
  }

  bool _isBubbleStep(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.welcome:
      case OnboardingStep.askDocument:
      case OnboardingStep.documentResult:
      case OnboardingStep.loginOrOther:
      case OnboardingStep.continueOrLogin:
      case OnboardingStep.perfect:
      case OnboardingStep.chooseAccountPrompt:
      case OnboardingStep.clientPfPrompt:
      case OnboardingStep.contactPrompt:
      case OnboardingStep.passwordPrompt:
      case OnboardingStep.clientPjPrompt:
      case OnboardingStep.clientPjReviewPrompt:
      case OnboardingStep.professionalHandoff:
      case OnboardingStep.profPjReviewPrompt:
      case OnboardingStep.profPjReviewPrompt2:
      case OnboardingStep.profContactPrompt:
      case OnboardingStep.profPasswordPrompt:
      case OnboardingStep.profAreaPrompt1:
      case OnboardingStep.profAreaPrompt2:
      case OnboardingStep.profAreaPrompt3:
      case OnboardingStep.profDocsPrompt1:
      case OnboardingStep.profDocsPrompt2:
        return true;
      default:
        return false;
    }
  }

  double _caixaSizeForStep(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.splash:
        return 230;
      case OnboardingStep.welcome:
      case OnboardingStep.askDocument:
      case OnboardingStep.documentResult:
      case OnboardingStep.loginOrOther:
      case OnboardingStep.continueOrLogin:
      case OnboardingStep.perfect:
      case OnboardingStep.chooseAccountPrompt:
      case OnboardingStep.clientPfPrompt:
      case OnboardingStep.contactPrompt:
      case OnboardingStep.passwordPrompt:
      case OnboardingStep.clientPjPrompt:
      case OnboardingStep.clientPjReviewPrompt:
      case OnboardingStep.professionalHandoff:
      case OnboardingStep.profPjReviewPrompt:
      case OnboardingStep.profPjReviewPrompt2:
      case OnboardingStep.profContactPrompt:
      case OnboardingStep.profPasswordPrompt:
      case OnboardingStep.profAreaPrompt1:
      case OnboardingStep.profAreaPrompt2:
      case OnboardingStep.profAreaPrompt3:
      case OnboardingStep.profDocsPrompt1:
      case OnboardingStep.profDocsPrompt2:
        return 220;
      case OnboardingStep.documentInput:
      case OnboardingStep.loginForm:
      case OnboardingStep.chooseAccount:
      case OnboardingStep.clientPfForm:
      case OnboardingStep.contactForm:
      case OnboardingStep.passwordForm:
      case OnboardingStep.clientPjForm:
      case OnboardingStep.profDataForm:
      case OnboardingStep.profPjForm:
      case OnboardingStep.profContactForm:
      case OnboardingStep.profPasswordForm:
      case OnboardingStep.profAreaForm:
      case OnboardingStep.profDocsForm:
        return 195;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final step = _controller.step;
        final mostraProgresso = stepMostraProgresso(step);
        final podeAvancarPorToque = stepPermiteToqueAvancar(step);
        final isSplash = step == OnboardingStep.splash;
        final isBubble = _isBubbleStep(step);

        return Scaffold(
          backgroundColor: OnboardingColors.blue,
          body: SafeArea(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                FocusScope.of(context).unfocus();
                if (podeAvancarPorToque) {
                  _controller.avancarPorToque();
                }
              },
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Top bar com transição suave de tamanho e fade (Morphing)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeInOutCubic,
                        child: _buildTopBar(mostraProgresso),
                      ),

                      // Título opcional de seção ("Email e telefone", "Dados da empresa") com Morphing
                      AnimatedSize(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeInOutCubic,
                        child: _buildHeaderTitle(step),
                      ),

                      // Balões usam uma área de altura estável para que o histórico
                      // possa subir sem deslocar a caixa de ferramentas.
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 300,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: AnimatedSize(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeInOutCubic,
                                      alignment: Alignment.bottomCenter,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 350),
                                        reverseDuration: const Duration(milliseconds: 240),
                                        layoutBuilder: (currentChild, previousChildren) {
                                          return Stack(
                                            alignment: Alignment.bottomCenter,
                                            clipBehavior: Clip.none,
                                            children: [
                                              ...previousChildren,
                                              ?currentChild,
                                            ],
                                          );
                                        },
                                        transitionBuilder: (child, animation) =>
                                            FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0, 0.08),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        ),
                                        child: isSplash
                                            ? const SizedBox.shrink()
                                            : isBubble
                                                ? KeyedSubtree(
                                                    key: ValueKey(
                                                      'bubble-${step.name}-${_controller.falaAtual}',
                                                    ),
                                                    child: _buildUpperContent(step),
                                                  )
                                                : SingleChildScrollView(
                                                    key: ValueKey(
                                                      'form-${step.name}-${_controller.erroFala}',
                                                    ),
                                                    physics:
                                                        const BouncingScrollPhysics(),
                                                    child: _buildUpperContent(step),
                                                  ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                CaixaCharacter(
                                  asset: _controller.pose.asset,
                                  size: _caixaSizeForStep(step),
                                ),
                                if (isSplash) ...[
                                  const SizedBox(height: 22),
                                  _buildSplashLogo(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Rodapé com botões contextuais: morpha de altura ao aparecer/sumir
                      AnimatedSize(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeInOutCubic,
                        child: _buildFooterActions(step),
                      ),
                    ],
                  ),

                  // Indicador de carregamento
                  if (_controller.carregando)
                    Container(
                      color: Colors.black26,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(bool mostraProgresso) {
    if (!mostraProgresso) {
      return const SizedBox(height: 18);
    }

    final progresso = progressoDoPasso(_controller.step);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            onPressed: _controller.voltar,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 28,
            ),
            splashRadius: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOutCubic,
                    widthFactor: progresso.clamp(0.05, 1.0),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildHeaderTitle(OnboardingStep step) {
    String? title;
    if (step == OnboardingStep.contactForm) {
      title = 'Email e telefone';
    } else if (step == OnboardingStep.clientPjForm ||
        step == OnboardingStep.profPjForm) {
      title = 'Dados da empresa';
    } else if (step == OnboardingStep.profContactForm) {
      title = 'Email e telefone';
    }

    if (title == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSplashLogo() {
    return const Text.rich(
      TextSpan(
        style: TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
        ),
        children: [
          TextSpan(text: 'Conserta'),
          TextSpan(
            text: 'Já',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  /// Constrói o conteúdo superior acima da caixa de ferramentas
  Widget _buildUpperContent(OnboardingStep step) {
    if (_isBubbleStep(step)) {
      return _buildBubbleContent(step);
    }
    return _buildFormContent(step);
  }

  /// Conteúdo dos passos com balão de fala (com proximidade da caixa)
  Widget _buildBubbleContent(OnboardingStep step) {
    final isWelcome = step == OnboardingStep.welcome;
    final temSeta = step != OnboardingStep.loginOrOther &&
        step != OnboardingStep.continueOrLogin;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Balão histórico (sobe suavemente e fica acima do balão atual)
        if (_controller.historicoFala != null) ...[
          AnimatedHistoricalBubble(
            key: ValueKey('hist-${_controller.historicoFala}'),
            text: _controller.historicoFala!,
          ),
          const SizedBox(height: 8),
        ],

        // Balão de fala ativo com engrandecer/encolher
        BubbleTransitionSwitcher(
          key: ValueKey('active-${_controller.falaAtual}'),
          child: isWelcome
              ? TypingBubble(
                  key: ValueKey('typing-${_controller.falaAtual}'),
                  text: _controller.falaAtual,
                  comSeta: true,
                )
              : SpeechBubble(
                  key: ValueKey('bubble-${_controller.falaAtual}'),
                  text: _controller.falaAtual,
                  historico: false,
                  comSeta: temSeta,
                ),
        ),

        // Botões que ficam logo abaixo do balão (Passo 7 e Passo 10)
        if (step == OnboardingStep.loginOrOther) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Entrar',
                  background: Colors.white,
                  foreground: OnboardingColors.blue,
                  onTap: _controller.escolherEntrar,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: PillButton(
                  label: 'Outro',
                  outlined: true,
                  onTap: _controller.escolherOutroDocumento,
                ),
              ),
            ],
          ),
        ],

        if (step == OnboardingStep.continueOrLogin) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Continuar',
                  background: Colors.white,
                  foreground: OnboardingColors.blue,
                  onTap: _controller.continuarCadastro,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: PillButton(
                  label: 'Login',
                  outlined: true,
                  onTap: _controller.irParaLogin,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Conteúdo dos passos com formulários ou cards
  Widget _buildFormContent(OnboardingStep step) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Balão de erro se houver
        if (_controller.erroFala != null) ...[
          BubbleTransitionSwitcher(
            key: ValueKey('err-${_controller.erroFala}'),
            child: SpeechBubble(
              text: _controller.erroFala!,
              historico: false,
              comSeta: true,
            ),
          ),
          const SizedBox(height: 12),
        ],

        _buildFormFields(step),
      ],
    );
  }

  Future<void> _selecionarOficio() async {
    if (_controller.oficios.isEmpty) {
      await _controller.carregarOficios();
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.65,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const Text(
                  'Área de atuação',
                  style: TextStyle(
                    color: OnboardingColors.blue,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final oficio in _controller.oficios)
                  ListTile(
                    title: Text(oficio['funcao']?.toString() ?? ''),
                    trailing: _controller.oficiosSelecionados.any(
                      (item) => item['id_oficio'] == oficio['id_oficio'],
                    )
                        ? const Icon(Icons.check_circle, color: OnboardingColors.blue)
                        : null,
                    onTap: () {
                      _controller.toggleOficio(oficio);
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfessionalDocumentForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildProfessionalDocumentButton(
          label: 'Cadastro facial',
          completed: _controller.cadastroFacialConcluido,
          onTap: () async {
            if (_controller.cadastroFacialConcluido) return;
            final resultado = await Navigator.push<String>(
              context,
              MaterialPageRoute(
                builder: (_) => const CadastroFacialInstrucoesPage(),
              ),
            );
            if (resultado != null && mounted) {
              _controller.setCadastroFacial(resultado);
            }
          },
        ),
        _buildProfessionalDocumentButton(
          label: 'Documento de identidade',
          completed: _controller.documentoIdentidadeConcluido,
          onTap: () async {
            final resultado = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(
                builder: (_) => ValidacaoDocsPage(
                  cpf: _controller.isCpf ? _controller.documento.text : null,
                  cnpj: _controller.isCnpj ? _controller.documento.text : null,
                  dataNascimento: _controller.dataNascimento.text,
                  isPessoaJuridica: _controller.isCnpj,
                ),
              ),
            );
            if (resultado != null && resultado['validado'] == true && mounted) {
              _controller.setDocumentoIdentidade(
                List<Map<String, dynamic>>.from(resultado['docsData'] ?? []),
              );
            }
          },
        ),
        TermsAndPrivacyCheckboxes(
          aceitouTermos: _controller.aceitouTermos,
          aceitouPrivacidade: _controller.aceitouPrivacidade,
          onToggleTermos: _controller.toggleTermos,
          onTogglePrivacidade: _controller.togglePrivacidade,
        ),
      ],
    );
  }

  Widget _buildProfessionalDocumentButton({
    required String label,
    required bool completed,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(
            completed ? Icons.check_circle : Icons.arrow_forward_rounded,
            color: Colors.white,
          ),
          label: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFields(OnboardingStep step) {
    switch (step) {
      // 4° Imagem: Input de CPF/CNPJ com máscara dinâmica
      case OnboardingStep.documentInput:
        return DocumentInputField(
          controller: _controller.documento,
          errorText: _controller.erroCampo,
          onSubmitted: _controller.continuarDocumento,
        );

      // 8° Imagem: Formulário de login
      case OnboardingStep.loginForm:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingWhiteField(
              label: rotuloDocumento(_controller.identificadorLogin.text),
              controller: _controller.identificadorLogin,
              filledValue: true,
            ),
            OnboardingWhiteField(
              label: 'Senha',
              controller: _controller.senhaLogin,
              obscure: _senhaLoginOculta,
              suffixIcon: _senhaLoginOculta
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              onSuffix: () {
                setState(() => _senhaLoginOculta = !_senhaLoginOculta);
              },
            ),
            if (_controller.erroCampo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  _controller.erroCampo!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );

      // 13° Imagem: Cards Cliente / Profissional
      case OnboardingStep.chooseAccount:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AccountTypeCard(
              selected: _controller.tipoConta == TipoContaOnboarding.cliente,
              profissional: false,
              title: 'Conta de cliente',
              subtitle:
                  'Procuro profissionais para resolverem meus problemas domésticos',
              onTap: () => _controller.selecionarTipoConta(
                TipoContaOnboarding.cliente,
              ),
            ),
            AccountTypeCard(
              selected: _controller.tipoConta == TipoContaOnboarding.profissional,
              profissional: true,
              title: 'Conta de Profissional',
              subtitle:
                  'Ofereço meus serviços e quero receber pedidos de cliente',
              onTap: () => _controller.selecionarTipoConta(
                TipoContaOnboarding.profissional,
              ),
            ),
          ],
        );

      // 15° Imagem: Nome completo + Data de nascimento
      case OnboardingStep.clientPfForm:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingWhiteField(
              label: 'Nome completo',
              controller: _controller.nome,
              requiredMark: true,
              errorText: _controller.nome.text.isEmpty ? _controller.erroCampo : null,
            ),
            OnboardingWhiteField(
              label: 'Data de Nascimento',
              controller: _controller.dataNascimento,
              requiredMark: true,
              readOnly: true,
              suffixIcon: Icons.calendar_today_rounded,
              onTap: () => _selecionarData(context, _controller.dataNascimento),
              errorText: _controller.dataNascimento.text.isEmpty
                  ? _controller.erroCampo
                  : null,
            ),
          ],
        );

      // 17° Imagem: Email e Telefone
      case OnboardingStep.contactForm:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingWhiteField(
              label: 'E-mail',
              controller: _controller.email,
              requiredMark: true,
              keyboardType: TextInputType.emailAddress,
              errorText: _controller.erroCampo,
            ),
            OnboardingPhoneField(
              controller: _controller.telefone,
              ddi: _controller.ddi,
              onDdiChanged: _controller.setDdi,
              errorText: _controller.erroCampo,
            ),
          ],
        );

      // 19° Imagem: Senha + Requisitos + Confirme a senha + Termos
      case OnboardingStep.passwordForm:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingWhiteField(
              label: 'Senha',
              controller: _controller.senha,
              requiredMark: true,
              obscure: _senhaOculta,
              suffixIcon: _senhaOculta
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              onSuffix: () => setState(() => _senhaOculta = !_senhaOculta),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Column(
                children: [
                  PasswordRequirementItem(
                    text: 'No mínimo 8 caracteres',
                    valid: _controller.senhaTemOito,
                  ),
                  PasswordRequirementItem(
                    text: 'Pelo menos 1 letra maiúscula',
                    valid: _controller.senhaMaiuscula,
                  ),
                  PasswordRequirementItem(
                    text: 'Pelo menos 1 letra minúscula',
                    valid: _controller.senhaMinuscula,
                  ),
                  PasswordRequirementItem(
                    text: 'Pelo menos 1 número',
                    valid: _controller.senhaNumero,
                  ),
                  PasswordRequirementItem(
                    text: 'Pelo menos 1 caractere especial',
                    valid: _controller.senhaSimbolo,
                  ),
                ],
              ),
            ),
            OnboardingWhiteField(
              label: 'Confirme a senha',
              controller: _controller.confirmarSenha,
              requiredMark: true,
              obscure: _confirmarSenhaOculta,
              suffixIcon: _confirmarSenhaOculta
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              onSuffix: () => setState(
                () => _confirmarSenhaOculta = !_confirmarSenhaOculta,
              ),
            ),
            TermsAndPrivacyCheckboxes(
              aceitouTermos: _controller.aceitouTermos,
              aceitouPrivacidade: _controller.aceitouPrivacidade,
              onToggleTermos: _controller.toggleTermos,
              onTogglePrivacidade: _controller.togglePrivacidade,
            ),
            if (_controller.erroCampo != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _controller.erroCampo!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        );

      // 22° Imagem: Dados da empresa
      case OnboardingStep.clientPjForm:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingWhiteField(
              label: 'CNPJ',
              controller: _controller.cnpj,
              requiredMark: true,
              suffixIcon: Icons.edit_outlined,
            ),
            OnboardingWhiteField(
              label: 'Nome fantasia',
              controller: _controller.nomeFantasia,
              requiredMark: true,
              suffixIcon: Icons.edit_outlined,
            ),
            OnboardingWhiteField(
              label: 'Razão Social',
              controller: _controller.razaoSocial,
              requiredMark: true,
              suffixIcon: Icons.edit_outlined,
            ),
            OnboardingWhiteField(
              label: 'Data de Fundação',
              controller: _controller.dataFundacao,
              requiredMark: true,
              readOnly: true,
              suffixIcon: Icons.calendar_today_rounded,
              onTap: () => _selecionarData(context, _controller.dataFundacao),
            ),
            if (_controller.erroCampo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _controller.erroCampo!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        );

      case OnboardingStep.profDataForm:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingWhiteField(
              label: 'Nome completo',
              controller: _controller.nome,
              requiredMark: true,
              errorText: _controller.erroCampo,
            ),
            OnboardingWhiteField(
              label: 'Data de Nascimento',
              controller: _controller.dataNascimento,
              requiredMark: true,
              readOnly: true,
              suffixIcon: Icons.calendar_today_rounded,
              onTap: () => _selecionarData(context, _controller.dataNascimento),
              errorText: _controller.erroCampo,
            ),
          ],
        );

      case OnboardingStep.profPjForm:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingWhiteField(
              label: 'CNPJ',
              controller: _controller.cnpj,
              requiredMark: true,
            ),
            OnboardingWhiteField(
              label: 'Nome fantasia',
              controller: _controller.nomeFantasia,
              requiredMark: true,
            ),
            OnboardingWhiteField(
              label: 'Razão Social',
              controller: _controller.razaoSocial,
              requiredMark: true,
            ),
            OnboardingWhiteField(
              label: 'Data de Fundação',
              controller: _controller.dataFundacao,
              requiredMark: true,
              readOnly: true,
              suffixIcon: Icons.calendar_today_rounded,
              onTap: () => _selecionarData(context, _controller.dataFundacao),
              errorText: _controller.erroCampo,
            ),
          ],
        );

      case OnboardingStep.profContactForm:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnboardingWhiteField(
              label: 'E-mail',
              controller: _controller.email,
              keyboardType: TextInputType.emailAddress,
              errorText: _controller.erroCampo,
            ),
            OnboardingPhoneField(
              controller: _controller.telefone,
              ddi: _controller.ddi,
              onDdiChanged: _controller.setDdi,
              errorText: _controller.erroCampo,
            ),
          ],
        );

      case OnboardingStep.profPasswordForm:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingWhiteField(
              label: 'Senha',
              controller: _controller.senha,
              requiredMark: true,
              obscure: _senhaOculta,
              suffixIcon: _senhaOculta
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              onSuffix: () => setState(() => _senhaOculta = !_senhaOculta),
            ),
            PasswordRequirementItem(
              text: 'No mínimo 8 caracteres',
              valid: _controller.senhaTemOito,
            ),
            PasswordRequirementItem(
              text: 'Pelo menos 1 letra maiúscula',
              valid: _controller.senhaMaiuscula,
            ),
            PasswordRequirementItem(
              text: 'Pelo menos 1 letra minúscula',
              valid: _controller.senhaMinuscula,
            ),
            PasswordRequirementItem(
              text: 'Pelo menos 1 número',
              valid: _controller.senhaNumero,
            ),
            PasswordRequirementItem(
              text: 'Pelo menos 1 caractere especial',
              valid: _controller.senhaSimbolo,
            ),
            const SizedBox(height: 8),
            OnboardingWhiteField(
              label: 'Confirme a senha',
              controller: _controller.confirmarSenha,
              requiredMark: true,
              obscure: _confirmarSenhaOculta,
              suffixIcon: _confirmarSenhaOculta
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              onSuffix: () => setState(
                () => _confirmarSenhaOculta = !_confirmarSenhaOculta,
              ),
              errorText: _controller.erroCampo,
            ),
          ],
        );

      case OnboardingStep.profAreaForm:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 3; index++)
              AreaSlotCard(
                label: index == 0
                    ? 'Área de atuação'
                    : 'Área de atuação ${index + 1}',
                value: index < _controller.oficiosSelecionados.length
                    ? _controller.oficiosSelecionados[index]['funcao']?.toString()
                    : null,
                requiredMark: index == 0,
                onTap: _selecionarOficio,
              ),
            if (_controller.erroCampo != null)
              Text(
                _controller.erroCampo!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        );

      case OnboardingStep.profDocsForm:
        return _buildProfessionalDocumentForm();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFooterActions(OnboardingStep step) {
    switch (step) {
      // 4° Imagem: Continuar ->
      case OnboardingStep.documentInput:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: PillButton(
            label: 'Continuar ->',
            outlined: true,
            loading: _controller.carregando,
            onTap: _controller.continuarDocumento,
          ),
        );

      // 8° Imagem: Entrar ->
      case OnboardingStep.loginForm:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: PillButton(
            label: 'Entrar ->',
            background: Colors.white,
            foreground: OnboardingColors.blue,
            loading: _controller.carregando,
            onTap: () => _controller.entrar(context),
          ),
        );

      // 14° Imagem: Continuar com Google
      case OnboardingStep.clientPfPrompt:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: GoogleButton(
            loading: _controller.carregando,
            onTap: () => _controller.loginComGoogle(context),
          ),
        );

      // 15° Imagem: Continuar -> e Continuar com Google
      case OnboardingStep.clientPfForm:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PillButton(
                label: 'Continuar ->',
                outlined: true,
                loading: _controller.carregando,
                onTap: _controller.continuarDadosPf,
              ),
              const SizedBox(height: 10),
              GoogleButton(
                loading: _controller.carregando,
                onTap: () => _controller.loginComGoogle(context),
              ),
            ],
          ),
        );

      // 17° Imagem: Continuar -> e Continuar com Google
      case OnboardingStep.contactForm:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PillButton(
                label: 'Continuar ->',
                outlined: true,
                loading: _controller.carregando,
                onTap: _controller.continuarContato,
              ),
              const SizedBox(height: 10),
              GoogleButton(
                loading: _controller.carregando,
                onTap: () => _controller.loginComGoogle(context),
              ),
            ],
          ),
        );

      // 19° Imagem: Finalizar Cadastro
      case OnboardingStep.passwordForm:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: PillButton(
            label: 'Finalizar Cadastro',
            outlined: true,
            loading: _controller.carregando,
            onTap: () => _controller.finalizarCadastro(context),
          ),
        );

      // 20° e 21° Imagem: Continuar com Google
      case OnboardingStep.clientPjPrompt:
      case OnboardingStep.clientPjReviewPrompt:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: GoogleButton(
            loading: _controller.carregando,
            onTap: () => _controller.loginComGoogle(context),
          ),
        );

      // 22° Imagem: Continuar -> e Continuar com Google
      case OnboardingStep.clientPjForm:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PillButton(
                label: 'Continuar ->',
                outlined: true,
                loading: _controller.carregando,
                onTap: _controller.continuarDadosPj,
              ),
              const SizedBox(height: 10),
              GoogleButton(
                loading: _controller.carregando,
                onTap: () => _controller.loginComGoogle(context),
              ),
            ],
          ),
        );

      // Transição para cadastro de profissional
      case OnboardingStep.professionalHandoff:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: GoogleButton(
            loading: _controller.carregando,
            onTap: () => _controller.loginComGoogle(context),
          ),
        );

      case OnboardingStep.profPjReviewPrompt:
      case OnboardingStep.profPjReviewPrompt2:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: GoogleButton(
            loading: _controller.carregando,
            onTap: () => _controller.loginComGoogle(context),
          ),
        );

      case OnboardingStep.profDataForm:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: PillButton(
            label: 'Continuar ->',
            outlined: true,
            loading: _controller.carregando,
            onTap: _controller.continuarDadosProf,
          ),
        );

      case OnboardingStep.profPjForm:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: PillButton(
            label: 'Continuar ->',
            outlined: true,
            loading: _controller.carregando,
            onTap: _controller.continuarDadosPjProf,
          ),
        );

      case OnboardingStep.profContactForm:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: PillButton(
            label: 'Continuar ->',
            outlined: true,
            loading: _controller.carregando,
            onTap: _controller.continuarContatoProf,
          ),
        );

      case OnboardingStep.profPasswordForm:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: PillButton(
            label: 'Continuar ->',
            outlined: true,
            loading: _controller.carregando,
            onTap: _controller.continuarSenhaProf,
          ),
        );

      case OnboardingStep.profAreaForm:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: PillButton(
            label: 'Continuar ->',
            outlined: true,
            loading: _controller.carregando,
            onTap: _controller.oficiosSelecionados.isEmpty
                ? null
                : _controller.continuarAreasProf,
          ),
        );

      case OnboardingStep.profDocsForm:
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: PillButton(
            label: 'Finalizar Cadastro',
            outlined: true,
            loading: _controller.carregando,
            onTap: () => _controller.finalizarCadastroProfissional(context),
          ),
        );

      default:
        return const SizedBox(height: 10);
    }
  }
}
