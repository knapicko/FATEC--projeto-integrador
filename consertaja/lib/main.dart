import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'tela_home.dart';
import 'tela_home_profissional.dart';
import 'cadastro_profissional.dart';
import 'cadastro_cliente.dart';
import 'login.dart';
import 'atualizar_senha.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://woqhicdlnkoksypipyoz.supabase.co',
    anonKey: 'sb_publishable_RFFTWcp3nJ8vEG0hACjwfA_b2thYfaw',
  );
  // 3. CONFIGURAR O LISTENER DIRETAMENTE NO MAIN
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final AuthChangeEvent event = data.event;
    
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

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = navigatorKey;
  Widget _homeWidget = const TelaEscolhaConta();
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _determinarHome();
  }

  Future<void> _determinarHome() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session != null && session.user != null) {
      try {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('usuarios')
            .select('tipo_conta')
            .eq('auth_id', session.user!.id)
            .maybeSingle();

        final isProfissional = response?['tipo_conta'] == 'Profissional';

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
            _homeWidget = TelaHome(isVisitante: false);
            _carregando = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _homeWidget = const TelaEscolhaConta();
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'ConsertaJá',
      theme: ThemeData(
        primaryColor: const Color(0xFF00A3FF),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      locale: const Locale('pt', 'BR'),

      home: _carregando
          ? const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00A3FF),
                ),
              ),
            )
          : _homeWidget,
    );
  }
}

// PASSO 2: A Tela de Escolha de Conta
class TelaEscolhaConta extends StatelessWidget {
  const TelaEscolhaConta({super.key});

  @override
  Widget build(BuildContext context) {
    double alturaDaTela = MediaQuery.of(context).size.height;
    double larguraDaTela = MediaQuery.of(context).size.width;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(larguraDaTela * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              
              SizedBox(height: alturaDaTela * 0.01),

              Image.asset(
                'assets/images/Logo.png',
                height: alturaDaTela * 0.12,
              ),
              SizedBox(height: alturaDaTela * 0.02),

              const Text(
                'ConsertaJá',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00A3FF),
                ),
              ),
              const Text(
                'Escolha o seu tipo de conta',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: alturaDaTela * 0.03),

              BotaoSelecaoConta(
                titulo: 'Sou um Cliente',
                subtitulo: 'Procuro profissionais para resolverem meus problemas domésticos',
                corBorda: const Color(0xFF00A2FF),
                icone: Icons.people_alt_outlined, 
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CadastroClientePage(),
                    ),
                  );
                },
              ),
              SizedBox(height: alturaDaTela * 0.015),

              BotaoSelecaoConta(
                titulo: 'Sou um Profissional',
                subtitulo: 'Ofereço meus serviços e quero receber pedidos de cliente',
                corBorda: const Color(0xFFF2994A),
                icone: Icons.handyman_outlined, 
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CadastroProfissionalPage(),
                    ),
                  );
                },
              ),
              SizedBox(height: alturaDaTela * 0.015),

              BotaoSelecaoConta(
                titulo: 'Quero Visitar',
                subtitulo: 'Quero conhecer o aplicativo antes de criar uma conta',
                corBorda: const Color(0xFF828282),
                icone: Icons.badge_outlined,  
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TelaHome(isVisitante: true),
                    ),
                  );
                },
              ),
              SizedBox(height: alturaDaTela * 0.02),

              BotaoSelecaoConta(
                titulo: 'Já possuo uma conta',
                subtitulo: 'Quero entrar em uma conta criada anteriormente',
                corBorda: const Color(0xFF004A7C), 
                icone: Icons.login,  
                fundoPreenchido: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// PASSO 3: O Componente Reutilizável do Botão (ATUALIZADO PARA SUPORTAR ÍCONES)
class BotaoSelecaoConta extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Color corBorda;
  final IconData icone; 
  final VoidCallback onTap;
  final bool fundoPreenchido;

  const BotaoSelecaoConta({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.corBorda,
    required this.icone, 
    required this.onTap,
    this.fundoPreenchido = false,
  });

  @override
  Widget build(BuildContext context) {
    Color corDoFundo = fundoPreenchido ? corBorda : Colors.white;
    Brightness brilhoDoFundo = ThemeData.estimateBrightnessForColor(corDoFundo);
    Color corDoTextoPrincipal;
    Color corDoTextoSubtitulo;
    Color corDoIcone;

    if (fundoPreenchido) {
      if (brilhoDoFundo == Brightness.dark) {
        corDoTextoPrincipal = Colors.white;
        corDoTextoSubtitulo = Colors.white70;
        corDoIcone = Colors.white; 
      } else {
        corDoTextoPrincipal = Colors.black87;
        corDoTextoSubtitulo = Colors.black54;
        corDoIcone = Colors.black87;
      }
    } else {
      corDoTextoPrincipal = corBorda;
      corDoTextoSubtitulo = Colors.black54;
      corDoIcone = corBorda; 
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: corDoFundo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: corBorda, width: 2),
        ),
        child: Row(
          children: [
            // COMPONENTE DE ÍCONE CUSTOMIZADO SUBSTITUINDO O IMAGE.ASSET
            Icon(
              icone,
              size: 36, 
              color: corDoIcone,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: corDoTextoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: TextStyle(fontSize: 13, color: corDoTextoSubtitulo),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}