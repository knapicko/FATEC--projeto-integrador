import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Observer responsável por registrar a pilha de rotas ativas na aplicação.
class AppRouteObserver extends NavigatorObserver {
  static final AppRouteObserver instance = AppRouteObserver._();
  AppRouteObserver._();

  final List<Route<dynamic>> _history = [];

  List<Route<dynamic>> get history => List.unmodifiable(_history);

  Route<dynamic>? get currentRoute => _history.isNotEmpty ? _history.last : null;

  Route<dynamic>? get previousRoute =>
      _history.length >= 2 ? _history[_history.length - 2] : null;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _history.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _history.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _history.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) {
      final index = _history.indexOf(oldRoute);
      if (index != -1) {
        if (newRoute != null) {
          _history[index] = newRoute;
        } else {
          _history.removeAt(index);
        }
        return;
      }
    }
    if (newRoute != null) {
      _history.add(newRoute);
    }
  }
}

/// Utilitário central de navegação e controle do botão 'Voltar' do sistema (Android/iOS).
class AppNavigationUtil {
  /// Conjunto de rotas que pertencem ao fluxo de autenticação/login/cadastro/onboarding.
  static final Set<Route<dynamic>> _authRoutes = {};

  /// Nomes conhecidos de rotas de autenticação/saída da conta conectada.
  static const Set<String> _authRouteNames = {
    'TelaInicial',
    'TelaEscolhaConta',
    'ConversationalOnboardingScreen',
    'LoginPage',
    'CadastroClientePage',
    'CadastroProfissionalPage',
    'CompletarCadastroClientePage',
    'CompletarCadastroProfissionalPage',
    'TelaEscolhaContaCompletar',
    'EsqueciSenhaPage',
    'AtualizarSenhaPage',
  };

  /// Registra a rota atual como rota de autenticação.
  static void registrarRotaComoAuth(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null) {
      _authRoutes.add(route);
    }
  }

  /// Remove o registro de rota de autenticação.
  static void desregistrarRotaComoAuth(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route != null) {
      _authRoutes.remove(route);
    }
  }

  /// Verifica se uma rota específica é de autenticação.
  static bool isRotaAuth(Route<dynamic>? route) {
    if (route == null) return false;
    if (_authRoutes.contains(route)) return true;
    final name = route.settings.name;
    if (name != null && _authRouteNames.contains(name)) return true;
    return false;
  }

  /// Verifica se o destino do 'Voltar' (a rota anterior na pilha) é uma tela de autenticação.
  static bool isDestinoAuth(BuildContext context) {
    final prev = AppRouteObserver.instance.previousRoute;
    if (prev == null) return false;
    return isRotaAuth(prev);
  }

  /// Fecha o aplicativo imediatamente.
  static void fecharApp() {
    SystemNavigator.pop();
  }

  /// Trata o evento de voltar do sistema ou da interface.
  static void tratarBotaoVoltar(
    BuildContext context, {
    bool isHome = false,
    bool isAuth = false,
  }) {
    // 1. Se estiver na Home, fecha o aplicativo imediatamente
    if (isHome) {
      fecharApp();
      return;
    }

    // 2. Se não houver telas anteriores na pilha de navegação, fecha o aplicativo
    if (!Navigator.of(context).canPop()) {
      fecharApp();
      return;
    }

    // 3. Se a tela atual NÃO for de autenticação (usuário está conectado/navegando no app),
    // mas a tela anterior for de login/cadastro/inicial (o que significaria "sair" da conta conectada):
    // Fecha o aplicativo ao invés de exibir a tela de autenticação.
    if (!isAuth && isDestinoAuth(context)) {
      fecharApp();
      return;
    }

    // 4. Caso comum: volta normalmente para a última tela que o usuário estava
    Navigator.of(context).pop();
  }

  /// Cria uma transição sem animação entre telas mantendo o histórico de rota.
  static PageRouteBuilder<T> rotaSemAnimacao<T>(Widget pagina, {String? nome}) {
    final routeName = nome ?? pagina.runtimeType.toString();
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: routeName),
      pageBuilder: (context, animation, secondaryAnimation) => pagina,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  /// Navega entre as abas da barra de navegação preservando o histórico para o botão voltar.
  static void navegarAba(
    BuildContext context,
    Widget novaTela, {
    required bool isHome,
  }) {
    // Se estiver navegando para a Home, retorna até a Home raiz mantendo a pilha limpa
    if (isHome) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        Navigator.of(context).pushReplacement(
          rotaSemAnimacao(novaTela),
        );
      }
      return;
    }

    final routeName = novaTela.runtimeType.toString();
    final currentRoute = AppRouteObserver.instance.currentRoute;
    // Se já estiver na mesma aba/tela, não faz nada para evitar reload
    if (currentRoute?.settings.name == routeName) {
      return;
    }

    // Se a aba anterior imediata for a tela para onde o usuário quer ir, apenas dá pop
    final prevRoute = AppRouteObserver.instance.previousRoute;
    if (prevRoute?.settings.name == routeName) {
      Navigator.of(context).pop();
      return;
    }

    // Caso contrário, empilha a nova aba preservando o histórico de navegação
    Navigator.of(context).push(
      rotaSemAnimacao(novaTela, nome: routeName),
    );
  }
}

/// Widget envolvente que intercepta o botão voltar do celular (barra de navegação do sistema ou gestos).
class AppBackHandler extends StatefulWidget {
  final Widget child;
  final bool isHome;
  final bool isAuth;
  final VoidCallback? onCustomBack;

  const AppBackHandler({
    super.key,
    required this.child,
    this.isHome = false,
    this.isAuth = false,
    this.onCustomBack,
  });

  @override
  State<AppBackHandler> createState() => _AppBackHandlerState();
}

class _AppBackHandlerState extends State<AppBackHandler> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isAuth) {
      AppNavigationUtil.registrarRotaComoAuth(context);
    }
  }

  @override
  void dispose() {
    if (widget.isAuth && mounted) {
      AppNavigationUtil.desregistrarRotaComoAuth(context);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.onCustomBack != null) {
          widget.onCustomBack!();
          return;
        }
        AppNavigationUtil.tratarBotaoVoltar(
          context,
          isHome: widget.isHome,
          isAuth: widget.isAuth,
        );
      },
      child: widget.child,
    );
  }
}
