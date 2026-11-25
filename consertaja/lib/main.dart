import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'tela_home.dart';
import 'tela_home_profissional.dart';
import 'atualizar_senha.dart';
import 'services/app_settings_controller.dart';
import 'services/google_auth_service.dart';
import 'services/notificacoes/notificacao_service.dart';
import 'onboarding/onboarding_controller.dart';
import 'tela_inicial.dart';
import 'services/verificacao_online.dart';
import 'utils/app_navigation_util.dart';
import 'widgets/codigo_flutuante.dart';
import 'package:flutter/services.dart';
import 'widgets/imagem_app.dart';
import 'services/rede_service.dart';
import 'services/sessao_segura.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // O app funciona só em retrato (virar o celular não gira a tela).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Versão de produção: nada de logs no logcat (podem conter dados do
  // usuário, ids e respostas do servidor).
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // A chave publicável é pública por natureza (vai dentro de qualquer APK);
  // quem protege os dados são as policies (RLS) do banco.
  await Supabase.initialize(
    url: 'https://woqhicdlnkoksypipyoz.supabase.co',
    publishableKey: 'sb_publishable_RFFTWcp3nJ8vEG0hACjwfA_b2thYfaw',
    authOptions: FlutterAuthClientOptions(
      // PKCE: o código do link de e-mail (recuperar senha) não serve para
      // outro app que intercepte o link.
      authFlowType: AuthFlowType.pkce,
      // Sessão no cofre do aparelho, não em texto puro.
      localStorage: SessaoSeguraStorage(
        chave: 'sb-woqhicdlnkoksypipyoz-auth-token',
      ),
    ),
  );
  // 3. CONFIGURAR O LISTENER DIRETAMENTE NO MAIN
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final AuthChangeEvent event = data.event;

    if (event == AuthChangeEvent.signedIn) {
      VerificacaoOnline.instance.iniciar();
    } else if (event == AuthChangeEvent.signedOut) {
      VerificacaoOnline.instance.parar();
    }

    if (event == AuthChangeEvent.passwordRecovery) {
      // O Future.microtask espera o Flutter terminar de carregar o MaterialApp
      // antes de chamar o navegador, garantindo que a tela apareça
      Future.microtask(() {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const AtualizarSenhaPage()),
        );
      });
    }
  });

  // Lê o arquivo de configurações do cliente antes de desenhar o app, para que
  // fonte/tema/filtros já abram aplicados em todas as telas.
  await AppSettingsController.instance.iniciar();
  unawaited(RedeService.instance.iniciar());

  // Notificações: Firebase (só FCM), canais, permissão, token e Realtime.
  // Sem o google-services.json o app abre normalmente, só sem push.
  try {
    await NotificacaoService.instance.inicializar(navegador: navigatorKey);
  } catch (e) {
    debugPrint('[Notificacoes] inicializar: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = navigatorKey;
  Widget _homeWidget = const TelaInicial();
  bool _carregando = true;
  bool _rascunhoLimpoAoEncerrar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _determinarHome();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      VerificacaoOnline.instance.iniciar();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      VerificacaoOnline.instance.parar();
    }
    if (state == AppLifecycleState.detached && !_rascunhoLimpoAoEncerrar) {
      _rascunhoLimpoAoEncerrar = true;
      OnboardingController.instance.limparRascunho();
    }
  }

  @override
  void dispose() {
    VerificacaoOnline.instance.parar();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _determinarHome() async {
    try {
      await _escolherHome();
    } finally {
      // Home montada: abre a notificação que trouxe o usuário (app fechado).
      NotificacaoService.instance.appPronto();
    }
  }

  Future<void> _escolherHome() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      VerificacaoOnline.instance.iniciar();
      try {
        // Confere a sessão NO SERVIDOR antes de abrir qualquer home. Uma
        // sessão restaurada (ex.: reinstalou o app) pode estar vencida ou
        // ser de um usuário que não existe mais; aí abria a home com o
        // usuário "não reconhecido". Sem conta válida → tela inicial.
        try {
          final valido = await Supabase.instance.client.auth.getUser().timeout(
            const Duration(seconds: 8),
          );
          if (valido.user == null) throw const AuthException('sem usuário');
        } on AuthException {
          // Sessão recusada pelo servidor: sai da conta guardada.
          await Supabase.instance.client.auth.signOut(
            scope: SignOutScope.local,
          );
          rethrow;
        }
        final response = await GoogleAuthService.buscarPerfil(session.user.id);

        if (response == null) {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            setState(() {
              _homeWidget = const TelaInicial();
              _carregando = false;
            });
          }
          return;
        }

        final isProfissional = response['tipo_conta'] == 'Profissional';

        if (mounted) {
          setState(() {
            _homeWidget = isProfissional
                ? TelaHomeProfissional(isVisitante: false)
                : TelaHome(isVisitante: false);
            _carregando = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _homeWidget = const TelaInicial();
            _carregando = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _homeWidget = const TelaInicial();
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsController.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        navigatorObservers: [AppRouteObserver.instance],
        debugShowCheckedModeBanner: false,
        title: 'ConsertaJá',
        theme: settings.tema,
        // Aplica as configurações do cliente (fonte, negrito, contraste,
        // daltonismo, modo escuro, animações) em todas as rotas.
        // Código de entrega/recebimento flutuante por cima de todas as telas.
        builder: (context, child) => settings.envolverApp(
          context,
          Stack(
            children: [
              child ?? const SizedBox.shrink(),
              const CodigoFlutuante(),
            ],
          ),
        ),

        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('pt', 'BR')],
        locale: const Locale('pt', 'BR'),

        home: _carregando ? const _StartupSplash() : _homeWidget,
      ),
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0FB3FF),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ImagemApp(child: Image.asset(
              'assets/images/icone/icone_consertaja.png',
              width: 92,
              height: 92,
              fit: BoxFit.contain,
            )),
            SizedBox(height: 16),
            Text(
              'ConsertaJá',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
