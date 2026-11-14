import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cliente_settings_storage.dart';

/// Fonte única das configurações do cliente para o app inteiro.
///
/// Lê o arquivo de sistema `consertaja_settings_cliente.json` (via
/// [ClienteSettingsStorage]) do usuário logado e notifica o `MaterialApp`
/// sempre que algo muda, para que tema, fonte, negrito, contraste, filtro para
/// daltônicos, animações e legibilidade valham em todas as telas — não só na
/// tela de configurações.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController._();

  static final AppSettingsController instance = AppSettingsController._();

  static const List<double> escalasFonte = [0.9, 1.0, 1.1, 1.2, 1.3];

  static Map<String, dynamic> padroes() => {
    'notifications.enabled': true,
    'notifications.orders': true,
    'notifications.messages': true,
    'notifications.payments': true,
    'notifications.reminders': true,
    'notifications.promotions': false,
    'notifications.sound': true,
    'notifications.vibration': true,
    'accessibility.fontSize': 1,
    'accessibility.boldText': false,
    'accessibility.highContrast': false,
    'accessibility.colorFilter': 'Desativado',
    'accessibility.reduceMotion': false,
    'accessibility.reduceTransparency': false,
    'accessibility.readability': true,
    'appearance.theme': 'Claro',
    'privacy.personalizedOffers': true,
    'privacy.analytics': false,
    'security.biometrics': true,
    'security.requireAuthentication': true,
    'security.autoLock': 'Imediatamente',
    'security.showNotificationContent': false,
    'preferences.useCurrentLocation': true,
    'preferences.confirmRequest': true,
    'preferences.confirmCancel': true,
    'preferences.showTips': false,
    'network.dataSaver': false,
    'network.imageLoading': 'Somente Wi-Fi',
    'network.videoAutoplay': true,
  };

  final ClienteSettingsStorage _storage = ClienteSettingsStorage();
  Map<String, dynamic> _settings = padroes();
  String _userId = 'anonymous';
  Future<void> _gravacaoPendente = Future<void>.value();
  StreamSubscription<AuthState>? _authSub;
  bool _iniciado = false;

  Map<String, dynamic> get settings => Map.unmodifiable(_settings);
  String get userId => _userId;

  /// Carrega o arquivo do usuário atual e passa a recarregar a cada
  /// login/logout. Chamar uma vez no `main()`.
  Future<void> iniciar() async {
    if (_iniciado) return;
    _iniciado = true;
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut ||
          data.event == AuthChangeEvent.initialSession) {
        unawaited(recarregar());
      }
    });
    await recarregar();
  }

  /// Relê o arquivo de configurações do usuário logado.
  Future<void> recarregar() async {
    final user = Supabase.instance.client.auth.currentUser;
    final id = user?.id ?? 'anonymous';
    Map<String, dynamic> salvo = const {};
    try {
      salvo = await _storage.load(id);
    } catch (e) {
      debugPrint('AppSettingsController: falha ao ler configurações: $e');
    }
    _userId = id;
    _settings = {...padroes(), ...salvo};
    notifyListeners();
  }

  /// Altera uma configuração, notifica o app e grava no arquivo.
  /// Com [salvar] = false só atualiza em memória (ex.: arrastando o slider).
  Future<void> atualizar(String chave, Object valor, {bool salvar = true}) {
    _settings = {..._settings, chave: valor};
    notifyListeners();
    return salvar ? salvarAgora() : Future<void>.value();
  }

  Future<void> salvarAgora() {
    final snapshot = Map<String, dynamic>.from(_settings);
    final id = _userId;
    final escrita = _gravacaoPendente.then((_) => _storage.save(id, snapshot));
    _gravacaoPendente = escrita.catchError((Object e) {
      debugPrint('AppSettingsController: falha ao salvar configurações: $e');
    });
    return escrita;
  }

  // ---------------------------------------------------------------- Getters

  bool _bool(String chave) => _settings[chave] == true;

  String get temaEscolhido =>
      (_settings['appearance.theme'] as String?) ?? 'Claro';

  /// O modo escuro está ativo considerando a opção "Sistema".
  bool escuroAtivo(Brightness brilhoPlataforma) =>
      temaEscolhido == 'Escuro' ||
      (temaEscolhido == 'Sistema' && brilhoPlataforma == Brightness.dark);

  double get escalaFonte {
    final i = ((_settings['accessibility.fontSize'] as num?)?.toInt() ?? 1)
        .clamp(0, escalasFonte.length - 1);
    return escalasFonte[i];
  }

  bool get textoNegrito => _bool('accessibility.boldText');
  bool get altoContraste => _bool('accessibility.highContrast');
  bool get reduzirAnimacoes => _bool('accessibility.reduceMotion');
  bool get reduzirTransparencias => _bool('accessibility.reduceTransparency');
  bool get melhorarLegibilidade => _bool('accessibility.readability');
  String get filtroCor =>
      (_settings['accessibility.colorFilter'] as String?) ?? 'Desativado';

  /// Matriz 4x5 aplicada sobre o app inteiro (modo escuro + filtro para
  /// daltônicos + alto contraste). `null` quando nenhum filtro está ativo.
  ///
  /// O modo escuro é uma "inversão inteligente": inverte a luminosidade e
  /// gira o matiz 180°, então branco vira cinza-escuro e o azul do app
  /// continua azul. É feito por filtro porque as telas usam cores fixas
  /// (Colors.white etc.) em vez do Theme — um ThemeData escuro deixaria
  /// texto claro sobre fundo branco.
  List<double>? matrizFiltro(Brightness brilhoPlataforma) {
    List<double>? resultado = escuroAtivo(brilhoPlataforma)
        ? _matrizEscura
        : null;
    final dalton = _matrizDaltonismo;
    if (dalton != null) {
      resultado = resultado == null ? dalton : _combinar(dalton, resultado);
    }
    if (altoContraste) {
      resultado = resultado == null
          ? _matrizContraste
          : _combinar(_matrizContraste, resultado);
    }
    return resultado;
  }

  static final List<double> _matrizEscura = () {
    // Inversão + rotação de matiz 180° (linhas de H somam 1), comprimida
    // para que o branco vire #151619 em vez de preto puro.
    const h = [
      [-0.574, 1.43, 0.144],
      [0.426, 0.43, 0.144],
      [0.426, 1.43, -0.856],
    ];
    const piso = 21.0;
    const k = (255 - piso) / 255;
    return <double>[
      for (var i = 0; i < 3; i++) ...[
        -k * h[i][0], -k * h[i][1], -k * h[i][2], 0, 255 * k + piso, //
      ],
      0, 0, 0, 1, 0, //
    ];
  }();

  static const double _c = 1.25;
  static const List<double> _matrizContraste = <double>[
    _c, 0, 0, 0, 128 * (1 - _c), //
    0, _c, 0, 0, 128 * (1 - _c), //
    0, 0, _c, 0, 128 * (1 - _c), //
    0, 0, 0, 1, 0, //
  ];

  List<double>? get _matrizDaltonismo {
    List<double>? base;
    switch (filtroCor) {
      // Correção (daltonização): realça as diferenças que cada tipo de
      // daltonismo perde, deslocando-as para canais que a pessoa enxerga.
      case 'Protanopia':
        base = _rgb([
          [1.0, 0.0, 0.0],
          [-0.255, 1.255, 0.0],
          [0.303, -0.545, 1.242],
        ]);
      case 'Deuteranopia':
        base = _rgb([
          [1.0, 0.0, 0.0],
          [-0.438, 1.438, 0.0],
          [0.262, -0.562, 1.3],
        ]);
      case 'Tritanopia':
        base = _rgb([
          [1.0, 0.0, 0.0],
          [0.035, 1.532, -0.567],
          [0.035, -0.51, 1.475],
        ]);
    }
    return base;
  }

  static List<double> _rgb(List<List<double>> m) => [
    m[0][0], m[0][1], m[0][2], 0, 0, //
    m[1][0], m[1][1], m[1][2], 0, 0, //
    m[2][0], m[2][1], m[2][2], 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  /// Retorna a matriz equivalente a aplicar [b] e depois [a].
  static List<double> _combinar(List<double> a, List<double> b) {
    final r = List<double>.filled(20, 0);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 5; j++) {
        var soma = 0.0;
        for (var k = 0; k < 4; k++) {
          soma += a[i * 5 + k] * b[k * 5 + j];
        }
        if (j == 4) soma += a[i * 5 + 4];
        r[i * 5 + j] = soma;
      }
    }
    return r;
  }

  // ----------------------------------------------------------------- Temas

  static const Color _primaria = Color(0xFF00A3FF);

  ThemeData _aplicarComuns(ThemeData base) {
    var textTheme = base.textTheme;
    if (melhorarLegibilidade) {
      TextStyle? esp(TextStyle? s) =>
          s?.copyWith(letterSpacing: (s.letterSpacing ?? 0) + 0.3);
      textTheme = textTheme.copyWith(
        displayLarge: esp(textTheme.displayLarge),
        displayMedium: esp(textTheme.displayMedium),
        displaySmall: esp(textTheme.displaySmall),
        headlineLarge: esp(textTheme.headlineLarge),
        headlineMedium: esp(textTheme.headlineMedium),
        headlineSmall: esp(textTheme.headlineSmall),
        titleLarge: esp(textTheme.titleLarge),
        titleMedium: esp(textTheme.titleMedium),
        titleSmall: esp(textTheme.titleSmall),
        bodyLarge: esp(textTheme.bodyLarge),
        bodyMedium: esp(textTheme.bodyMedium),
        bodySmall: esp(textTheme.bodySmall),
        labelLarge: esp(textTheme.labelLarge),
        labelMedium: esp(textTheme.labelMedium),
        labelSmall: esp(textTheme.labelSmall),
      );
    }
    return base.copyWith(
      textTheme: textTheme,
      pageTransitionsTheme: reduzirAnimacoes
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: _SemTransicao(),
                TargetPlatform.iOS: _SemTransicao(),
                TargetPlatform.windows: _SemTransicao(),
                TargetPlatform.macOS: _SemTransicao(),
                TargetPlatform.linux: _SemTransicao(),
              },
            )
          : null,
    );
  }

  /// Tema do app (o mesmo de antes) + ajustes de legibilidade e animação.
  ThemeData get tema => _aplicarComuns(
    ThemeData(
      primaryColor: _primaria,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    ),
  );

  /// Envolve todas as rotas do app (usado em `MaterialApp.builder`).
  Widget envolverApp(BuildContext context, Widget? child) {
    final mq = MediaQuery.of(context);
    Widget resultado = MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(escalaFonte),
        boldText: textoNegrito || mq.boldText,
        highContrast: altoContraste || mq.highContrast,
        disableAnimations: reduzirAnimacoes || mq.disableAnimations,
      ),
      child: child ?? const SizedBox.shrink(),
    );
    final matriz = matrizFiltro(mq.platformBrightness);
    if (matriz != null) {
      resultado = ColorFiltered(
        colorFilter: ColorFilter.matrix(matriz),
        child: resultado,
      );
    }
    return resultado;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

class _SemTransicao extends PageTransitionsBuilder {
  const _SemTransicao();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
