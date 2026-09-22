import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding/conversational_onboarding_screen.dart';
import 'onboarding/onboarding_controller.dart';
import 'onboarding/onboarding_theme.dart';
import 'tela_home.dart';
import 'utils/app_navigation_util.dart';

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  static const _blue = Color(0xFF12AEEC);

  bool _transicionando = false;
  bool _aquecido = false;

  @override
  void initState() {
    super.initState();
    // Aquece em momento ocioso (após o primeiro frame) tudo que a primeira
    // transição precisa: imagens da caixa/logo e SharedPreferences.
    // Sem isso, esse custo cai no frame do toque e só a 1ª transição trava.
    WidgetsBinding.instance.addPostFrameCallback((_) => _aquecerTransicao());
  }

  Future<void> _aquecerTransicao() async {
    for (final asset in [
      CaixaAssets.normal,
      CaixaAssets.falandoFechado,
      CaixaAssets.falandoAberto,
      'assets/images/icone/google-logo.png',
    ]) {
      try {
        if (!mounted) return;
        await precacheImage(AssetImage(asset), context);
      } catch (_) {}
    }
    try {
      await SharedPreferences.getInstance();
    } catch (_) {}
    _aquecido = true;
  }

  Future<void> _abrirFluxo({required bool login}) async {
    if (_transicionando) return;
    setState(() => _transicionando = true);
    if (!mounted) return;
    // Na primeira transição, o build da tela de onboarding (+ shaders) é
    // pesado: espera o fade-out terminar e cede um frame antes de construir,
    // para não travar no toque. Nas próximas vezes já está tudo em cache.
    if (!_aquecido) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    unawaited(OnboardingController.instance.limparRascunho());
    if (login) {
      OnboardingController.instance.iniciarFluxoLogin();
    } else {
      OnboardingController.instance.iniciarFluxoCadastro();
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      _rotaComFade(
        () => ConversationalOnboardingScreen(
          iniciarLogin: login,
          iniciarCadastro: !login,
          onVoltarInicio: _voltarParaInicio,
        ),
      ),
      (route) => false,
    );
  }

  void _voltarParaInicio(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      _rotaComFade(() => const TelaInicial()),
      (route) => false,
    );
  }

  PageRouteBuilder<void> _rotaComFade(Widget Function() builder) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, animation, _) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        ),
        child: builder(),
      ),
      transitionDuration: const Duration(milliseconds: 520),
      reverseTransitionDuration: const Duration(milliseconds: 340),
    );
  }

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.sizeOf(context).height;
    final caixaSize = (altura * 0.22).clamp(160.0, 195.0);

    return AppBackHandler(
      isAuth: true,
      child: Scaffold(
        backgroundColor: _blue,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(5, 20, 5, 24),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'caixa-transicao-inicial',
                          child: SizedBox(
                            width: caixaSize,
                            height: caixaSize,
                            child: Image.asset(
                              'assets/images/caixa/caixa_normal.png',
                              width: caixaSize,
                              height: caixaSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: _transicionando ? 0 : 1,
                          duration: const Duration(milliseconds: 280),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text.rich(
                              TextSpan(
                                text: 'Conserta',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Já',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: AnimatedOpacity(
                        opacity: _transicionando ? 0 : 1,
                        duration: const Duration(milliseconds: 280),
                        child: IgnorePointer(
                          ignoring: _transicionando,
                          child: Column(
                            children: [
                              _BotaoInicial(
                                label: 'INICIAR CADASTRO',
                                background: Colors.white,
                                foreground: _blue,
                                onPressed: () => _abrirFluxo(login: false),
                              ),
                              const SizedBox(height: 10),
                              _BotaoInicial(
                                label: 'JÁ POSSUO UMA CONTA',
                                background: Colors.transparent,
                                foreground: Colors.white,
                                border: Colors.white,
                                onPressed: () => _abrirFluxo(login: true),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    _rotaComFade(
                                      () => const TelaHome(isVisitante: true),
                                    ),
                                    (route) => false,
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 4,
                                  ),
                                ),
                                child: const Text(
                                  'Quero visitar ›',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),);
  }
}

class _BotaoInicial extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback onPressed;

  const _BotaoInicial({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: background == Colors.white ? 2 : 0,
          shadowColor: Colors.black38,
          side: border == null ? null : BorderSide(color: border!, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foreground,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
