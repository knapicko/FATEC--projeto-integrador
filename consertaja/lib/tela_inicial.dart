import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding/conversational_onboarding_screen.dart';
import 'onboarding/onboarding_controller.dart';
import 'onboarding/onboarding_theme.dart';
import 'services/auth_navigation.dart';
import 'services/google_auth_service.dart';
import 'tela_home.dart';
import 'utils/app_navigation_util.dart';
import 'widgets/avisos_bottom_sheet.dart';
import 'widgets/caixa_flutuante.dart';
import 'widgets/imagem_app.dart';
import 'utils/movimento.dart';

/// Visitante escolheu entrar/cadastrar (bottom sheet de visitante): vai
/// para o onboarding e, ao voltar, para a tela inicial.
void abrirEntradaVisitante(BuildContext context, {required bool login}) {
  SessaoVisitante.ativo = false;
  unawaited(OnboardingController.instance.limparRascunho());
  if (login) {
    OnboardingController.instance.iniciarFluxoLogin();
  } else {
    OnboardingController.instance.iniciarFluxoCadastro();
  }
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => ConversationalOnboardingScreen(
        iniciarLogin: login,
        iniciarCadastro: !login,
        onVoltarInicio: (ctx) => Navigator.of(ctx).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const TelaInicial()),
          (route) => false,
        ),
      ),
    ),
    (route) => false,
  );
}

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial>
    with TickerProviderStateMixin {
  static const _blue = Color(0xFF12AEEC);

  /// A abertura da caixa só roda na primeira vez que a tela aparece (nesta
  /// execução do app). Ao voltar para cá, ela já está aberta e flutuando.
  static bool _introJaExibida = false;

  /// Tamanho da caixa no começo da intro (centro da tela) em relação ao final.
  static const double _escalaInicial = 1.55;

  bool _transicionando = false;
  bool _autenticandoGoogle = false;
  bool _aquecido = false;

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: duracao(const Duration(milliseconds: 2400)),
    value: _introJaExibida ? 1 : 0,
  );
  late final AnimationController _flutuar = AnimationController(
    vsync: this,
    duration: duracao(const Duration(milliseconds: 3200)),
  );

  // Etapas da intro (frações de _intro).
  late final _aparecer = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.16, curve: Curves.easeOutBack),
  );
  late final _respirar = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.16, 0.30, curve: Curves.easeInOut),
  );
  late final _abrir = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.26, 0.36, curve: Curves.easeOutCubic),
  );
  late final _ferramentas = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.32, 0.60, curve: Curves.easeOutBack),
  );
  late final _mover = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.54, 0.80, curve: Curves.easeInOutCubic),
  );
  late final _flutuacaoEntra = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.40, 0.85, curve: Curves.easeInOut),
  );
  late final _titulo = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.76, 0.92, curve: Curves.easeOutCubic),
  );
  late final _botoes = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.82, 1, curve: Curves.easeOutCubic),
  );

  /// Lugar final da caixa e área da tela: medem o deslocamento até o centro.
  final GlobalKey _chaveCaixa = GlobalKey();
  final GlobalKey _chaveTela = GlobalKey();
  Offset? _ateOCentro;

  @override
  void initState() {
    super.initState();
    aoEscolherEntrarVisitante = abrirEntradaVisitante;
    SessaoVisitante.ativo = false;
    // Aquece em momento ocioso (após o primeiro frame) tudo que a primeira
    // transição precisa: imagens da caixa/logo e SharedPreferences.
    // Sem isso, esse custo cai no frame do toque e só a 1ª transição trava.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _iniciarAnimacoes();
      _aquecerTransicao();
    });
  }

  Future<void> _iniciarAnimacoes() async {
    final semMovimento = MediaQuery.of(context).disableAnimations;
    if (!semMovimento) _flutuar.repetir();
    if (_introJaExibida || semMovimento) {
      _intro.value = 1;
      _introJaExibida = true;
      return;
    }
    // Camadas carregadas antes de começar: nada "pisca" no meio da intro.
    for (final asset in CaixaAnimacaoAssets.todas) {
      try {
        if (!mounted) return;
        await precacheImage(AssetImage(asset), context);
      } catch (_) {}
    }
    if (!mounted) return;
    _medirCentro();
    _introJaExibida = true;
    await _intro.forward();
  }

  /// Distância do lugar final da caixa até o centro da tela.
  void _medirCentro() {
    final caixa = _chaveCaixa.currentContext?.findRenderObject() as RenderBox?;
    final tela = _chaveTela.currentContext?.findRenderObject() as RenderBox?;
    if (caixa == null || tela == null || !caixa.hasSize || !tela.hasSize) {
      setState(() => _ateOCentro = Offset.zero);
      return;
    }
    final centroCaixa = caixa.localToGlobal(caixa.size.center(Offset.zero));
    final centroTela = tela.localToGlobal(tela.size.center(Offset.zero));
    setState(() => _ateOCentro = centroTela - centroCaixa);
  }

  @override
  void dispose() {
    _intro.dispose();
    _flutuar.dispose();
    super.dispose();
  }

  /// Caixa animada: grande no centro → abre → ferramentas sobem → vai para
  /// o lugar e segue flutuando.
  Widget _caixaAnimada(double tamanho) {
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _flutuar]),
      builder: (context, _) {
        final fase = _flutuar.value * 2 * math.pi;
        final mover = _mover.value;
        final centro = _ateOCentro ?? Offset.zero;
        // Antes de medir o centro nada aparece (evita um quadro no lugar
        // errado).
        final visivel = _intro.value >= 1 || _ateOCentro != null;

        final escala =
            (0.7 + 0.3 * _aparecer.value) *
            (_escalaInicial + (1 - _escalaInicial) * mover);
        // "Respira" antes de abrir: achata e estica um pouco.
        final respiro = math.sin(_respirar.value * math.pi);
        final flutuacao = math.sin(fase) * 7 * _flutuacaoEntra.value;

        return Opacity(
          opacity: visivel ? _aparecer.value.clamp(0.0, 1.0) : 0,
          child: Transform.translate(
            offset: Offset(
              centro.dx * (1 - mover),
              centro.dy * (1 - mover) + flutuacao,
            ),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(
                escala * (1 + 0.05 * respiro),
                escala * (1 - 0.07 * respiro),
                1,
              ),
              child: CaixaFlutuante(
                tamanho: tamanho,
                corFundo: _blue,
                abertura: _abrir.value,
                ferramentas: _ferramentas.value,
                fase: fase,
                intensidadeFlutuacao: _flutuacaoEntra.value,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _surgir(Animation<double> a, Widget filho) {
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - a.value)),
          child: child,
        ),
      ),
      child: filho,
    );
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
    if (_transicionando || _autenticandoGoogle) return;
    setState(() => _transicionando = true);
    if (!mounted) return;
    // A caixa para de flutuar: assim a tela inicial não redesenha a cada
    // quadro enquanto a de login é montada (disputava o mesmo frame).
    _flutuar.stop();
    // Montar a tela de onboarding (ainda mais a de login, com os campos) é
    // pesado. Sempre deixa o fade dos botões acontecer primeiro e cede um
    // frame: o quadro mais caro cai com a tela parada, e não no meio de uma
    // animação (era a "travadinha" às vezes no "Já possuo uma conta").
    await Future.delayed(Duration(milliseconds: _aquecido ? 200 : 300));
    if (!mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
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

  Future<void> _entrarComGoogle() async {
    if (_transicionando || _autenticandoGoogle) return;
    setState(() => _autenticandoGoogle = true);
    try {
      final usuario = await GoogleAuthService.signInWithGoogle();
      if (usuario == null || !mounted) return;
      final perfil = await GoogleAuthService.buscarPerfil(usuario.id);
      if (!mounted) return;

      if (perfil == null) {
        OnboardingController.instance.iniciarFluxoCadastroGoogle(usuario);
        Navigator.of(context).pushAndRemoveUntil(
          _rotaComFade(
            () => ConversationalOnboardingScreen(
              onVoltarInicio: _voltarParaInicio,
            ),
          ),
          (route) => false,
        );
      } else {
        await navegarPosAutenticacaoGoogle(context);
      }
    } catch (erro) {
      debugPrint(GoogleAuthService.mensagemErro(erro));
      if (mounted) await mostrarErroGoogle(context, erro);
    } finally {
      if (mounted) setState(() => _autenticandoGoogle = false);
    }
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
        body: Stack(
          children: [
            // Aquecimento: um campo de texto e um botão desenhados fora da
            // tela. O primeiro desenho de um TextField (cursor, fonte,
            // seleção) é caro; feito aqui, em tempo ocioso, não pesa mais no
            // primeiro quadro do login.
            if (_aquecido)
              const Positioned(
                left: -2000,
                top: 0,
                width: 320,
                child: IgnorePointer(child: _AquecimentoCampos()),
              ),
            SafeArea(
              key: _chaveTela,
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
                              SizedBox(
                                key: _chaveCaixa,
                                width: caixaSize,
                                height: caixaSize,
                                child: Hero(
                                  tag: 'caixa-transicao-inicial',
                                  flightShuttleBuilder: caixaHeroShuttle,
                                  child: SizedBox(
                                    width: caixaSize,
                                    height: caixaSize,
                                    child: RepaintBoundary(
                                      child: _caixaAnimada(caixaSize),
                                    ),
                                  ),
                                ),
                              ),
                              _surgir(
                                _titulo,
                                AnimatedOpacity(
                                  opacity:
                                      _transicionando || _autenticandoGoogle
                                      ? 0
                                      : 1,
                                  duration: duracao(const Duration(milliseconds: 280)),
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
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: _surgir(
                              _botoes,
                              AnimatedBuilder(
                                animation: _intro,
                                // Sem toque durante a intro.
                                builder: (context, child) => IgnorePointer(
                                  ignoring: _intro.value < 0.9,
                                  child: child,
                                ),
                                child: AnimatedOpacity(
                                  opacity:
                                      _transicionando || _autenticandoGoogle
                                      ? 0
                                      : 1,
                                  duration: duracao(const Duration(milliseconds: 280)),
                                  child: IgnorePointer(
                                    ignoring:
                                        _transicionando || _autenticandoGoogle,
                                    child: Column(
                                      children: [
                                        _BotaoInicial(
                                          label: 'INICIAR CADASTRO',
                                          background: Colors.white,
                                          foreground: _blue,
                                          onPressed: () =>
                                              _abrirFluxo(login: false),
                                        ),
                                        const SizedBox(height: 14),
                                        _BotaoInicial(
                                          label: 'JÁ POSSUO UMA CONTA',
                                          background: Colors.transparent,
                                          foreground: Colors.white,
                                          border: Colors.white,
                                          onPressed: () =>
                                              _abrirFluxo(login: true),
                                        ),
                                        const SizedBox(height: 14),
                                        BotaoGoogleCircular(
                                          carregando: _autenticandoGoogle,
                                          onPressed: _entrarComGoogle,
                                        ),
                                        const SizedBox(height: 10),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(
                                              context,
                                            ).pushAndRemoveUntil(
                                              _rotaComFade(
                                                () => const TelaHome(
                                                  isVisitante: true,
                                                ),
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
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campos desenhados fora da tela só para "aquecer" o primeiro desenho de
/// TextField/botão antes de abrir o login.
class _AquecimentoCampos extends StatelessWidget {
  const _AquecimentoCampos();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: TextEditingController(text: 'aquecimento'),
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const TextField(obscureText: true),
          FilledButton(onPressed: () {}, child: const Text('Entrar')),
        ],
      ),
    );
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

class BotaoGoogleCircular extends StatelessWidget {
  final bool carregando;
  final VoidCallback onPressed;

  const BotaoGoogleCircular({
    super.key,
    required this.carregando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Tooltip(
        message: 'Entrar com Google',
        child: SizedBox(
          width: 52,
          height: 52,
          child: ElevatedButton(
            onPressed: carregando ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              elevation: 2,
              shadowColor: Colors.black38,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
            ),
            child: carregando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0FB3FF),
                    ),
                  )
                : ImagemApp(child: Image.asset(
                    'assets/images/icone/google-logo.png',
                    width: 26,
                    height: 26,
                  )),
          ),
        ),
      ),
    );
  }
}
