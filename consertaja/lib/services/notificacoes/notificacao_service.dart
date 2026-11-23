// =============================================================================
// ConsertaJá — Serviço central de notificações (lado do app)
//
// Responsável por:
//   • iniciar o Firebase (só FCM; banco e login continuam no Supabase);
//   • pedir permissão e registrar/atualizar o token FCM em
//     `dispositivos_notificacao` (RPC registrar_dispositivo_notificacao),
//     junto com o perfil ativo (cliente / independente / empresa);
//   • receber push com o app aberto, em segundo plano e fechado;
//   • abrir a tela certa ao tocar (inclusive com o app fechado);
//   • manter os contadores (sininho e aba Mensagens) via Supabase Realtime.
//
// O app NÃO cria notificações (exceto `feedback`, em notificacao_feedback.dart):
// todos os outros tipos nascem no servidor (triggers / pg_cron).
//
// Sobre getToken/onTokenRefresh/deleteToken: o firebase_messaging 17 marca
// esses métodos como obsoletos em favor de register()/onRegistered, que
// devolvem um Firebase Installation ID para outro modo de envio. A Edge
// Function usa a API HTTP v1 com o TOKEN de registro, que continua sendo o
// formato suportado — por isso os métodos clássicos são mantidos.
// =============================================================================
// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/bottom_navigation_bar_profissional.dart';
import 'notificacao_app.dart';
import 'notificacao_destinos.dart';
import 'notificacao_exibicao.dart';
import 'notificacao_repositorio.dart';
import 'notificacao_tipos.dart';

/// Push recebido com o app em segundo plano ou FECHADO (Android).
/// Roda em outro isolate: não acessa o estado do app.
@pragma('vm:entry-point')
Future<void> notificacaoEmSegundoPlano(RemoteMessage mensagem) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  // Se veio com `notification`, o próprio sistema já mostrou (iOS ou modo
  // "notificacao" da Edge Function). Mostrar de novo duplicaria.
  if (mensagem.notification != null) return;
  if (mensagem.data.isEmpty) return;
  final n = NotificacaoApp.fromMap(Map<String, dynamic>.from(mensagem.data));
  await NotificacaoExibicao.mostrar(n);
}

class NotificacaoService extends ChangeNotifier {
  NotificacaoService._();
  static final NotificacaoService instance = NotificacaoService._();

  GlobalKey<NavigatorState>? _navegador;
  bool _iniciado = false;
  bool _firebaseOk = false;
  bool _appPronto = false;

  int? _idUsuario;
  String? _tipoConta;
  RealtimeChannel? _canal;
  StreamSubscription<AuthState>? _authSub;
  final List<StreamSubscription<dynamic>> _subsFcm = [];
  NotificacaoApp? _aberturaPendente;

  /// Notificações não abertas (sem as de Conversa).
  int naoLidas = 0;

  /// Mensagens recebidas ainda não lidas (aba Mensagens).
  int mensagensNaoLidas = 0;

  /// Conversa aberta na tela: push dela não é mostrado (o chat já mostra).
  int? conversaEmTela;

  /// Avisa a tela de notificações quando chega/muda alguma (Realtime).
  final StreamController<void> _alteracoes = StreamController.broadcast();
  Stream<void> get alteracoes => _alteracoes.stream;

  bool get firebaseDisponivel => _firebaseOk;

  // ── Inicialização ────────────────────────────────────────────────────────

  /// Chame no main(), depois do Supabase.initialize e antes do runApp.
  Future<void> inicializar({
    required GlobalKey<NavigatorState> navegador,
  }) async {
    if (_iniciado || kIsWeb) return;
    _iniciado = true;
    _navegador = navegador;

    await NotificacaoExibicao.inicializar(aoTocar: _aoTocarLocal);
    _aberturaPendente ??= await NotificacaoExibicao.notificacaoQueAbriuOApp();

    try {
      await Firebase.initializeApp();
      _firebaseOk = true;
    } catch (e) {
      // Sem google-services.json: app segue normal, só sem push.
      debugPrint('[Notificacoes] Firebase indisponível: $e');
    }

    if (_firebaseOk) {
      FirebaseMessaging.onBackgroundMessage(notificacaoEmSegundoPlano);
      // iOS: com o app aberto, quem mostra somos nós (evita duplicar).
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );
      _subsFcm.add(FirebaseMessaging.onMessage.listen(_aoReceberAberto));
      _subsFcm.add(
        FirebaseMessaging.onMessageOpenedApp.listen(
          (m) =>
              abrir(NotificacaoApp.fromMap(Map<String, dynamic>.from(m.data))),
        ),
      );
      _subsFcm.add(
        FirebaseMessaging.instance.onTokenRefresh.listen(
          (token) => _enviarToken(token),
        ),
      );
      final inicial = await FirebaseMessaging.instance.getInitialMessage();
      if (inicial != null && inicial.data.isNotEmpty) {
        _aberturaPendente = NotificacaoApp.fromMap(
          Map<String, dynamic>.from(inicial.data),
        );
      }
    }

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((d) {
      switch (d.event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
          if (d.session != null) unawaited(_aoEntrar());
        case AuthChangeEvent.signedOut:
          unawaited(_aoSair());
        default:
          break;
      }
    });
    if (Supabase.instance.client.auth.currentSession != null) {
      unawaited(_aoEntrar());
    }
  }

  /// O main chama quando a primeira tela (home) já está montada: abre a
  /// notificação que trouxe o usuário para o app (app estava fechado).
  void appPronto() {
    _appPronto = true;
    final pendente = _aberturaPendente;
    if (pendente == null) return;
    _aberturaPendente = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => abrir(pendente));
  }

  // ── Sessão ───────────────────────────────────────────────────────────────

  Future<void> _aoEntrar() async {
    try {
      final idUsuario = await NotificacaoRepositorio.meuIdUsuario();
      if (idUsuario == null) return;
      final mudou = idUsuario != _idUsuario;
      _idUsuario = idUsuario;
      if (mudou) {
        _tipoConta = null;
        _iniciarRealtime(idUsuario);
      }
      await atualizarContadores();
      await registrarDispositivo();
    } catch (e) {
      debugPrint('[Notificacoes] entrar: $e');
    }
  }

  Future<void> _aoSair() async {
    _idUsuario = null;
    _tipoConta = null;
    if (_canal != null) {
      await Supabase.instance.client.removeChannel(_canal!);
      _canal = null;
    }
    naoLidas = 0;
    mensagensNaoLidas = 0;
    notifyListeners();
    // Invalida o token deste aparelho: o servidor apaga o registro antigo no
    // próximo envio (UNREGISTERED) e o próximo login gera outro.
    if (_firebaseOk) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
  }

  // ── Token / dispositivo ──────────────────────────────────────────────────

  /// Pede permissão e registra o token FCM (chamado ao entrar).
  Future<void> registrarDispositivo() async {
    if (!_firebaseOk || _idUsuario == null) return;
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await NotificacaoExibicao.pedirPermissao();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _enviarToken(token);
    } catch (e) {
      debugPrint('[Notificacoes] registrar dispositivo: $e');
    }
  }

  Future<void> _enviarToken(String token) async {
    if (_idUsuario == null) return;
    try {
      await NotificacaoRepositorio.registrarDispositivo(
        token: token,
        plataforma: _plataforma(),
        perfilAtivo: await _perfilAtivo(),
      );
    } catch (e) {
      debugPrint('[Notificacoes] salvar token: $e');
    }
  }

  /// Chamado na troca de conta (independente ↔ empresa): o servidor usa o
  /// perfil ativo para escolher as pendências diárias do "Sistema".
  Future<void> atualizarPerfilAtivo() async {
    // Sino e aba de mensagens passam a contar só o perfil novo.
    unawaited(atualizarContadores());
    if (!_firebaseOk || _idUsuario == null) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _enviarToken(token);
    } catch (_) {}
  }

  String _plataforma() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'outro';
  }

  /// 'cliente' | 'independente' | 'empresa' (conta ativa neste aparelho).
  Future<String> perfilAtivo() async {
    if (_idUsuario == null) return 'cliente';
    return _perfilAtivo();
  }

  /// A notificação é da outra conta do profissional (independente x loja)?
  Future<bool> ehDeOutroPerfil(NotificacaoApp n) async {
    final destino = n.perfilDestino;
    if (destino != 'independente' && destino != 'empresa') return false;
    final ativo = await perfilAtivo();
    return ativo != 'cliente' && ativo != destino;
  }

  Future<String> _perfilAtivo() async {
    if (_tipoConta == null) {
      try {
        final row = await Supabase.instance.client
            .from('usuarios')
            .select('tipo_conta')
            .eq('id_usuario', _idUsuario!)
            .maybeSingle();
        _tipoConta = row?['tipo_conta']?.toString();
      } catch (_) {}
    }
    if (_tipoConta != 'Profissional') return 'cliente';
    final empresa =
        await BottomNavigationBarProfissional.precarregarContaEmpresa();
    return empresa ? 'empresa' : 'independente';
  }

  // ── Recebimento ──────────────────────────────────────────────────────────

  /// Push com o app ABERTO: o FCM não mostra nada sozinho, então mostramos
  /// aqui (uma única vez).
  Future<void> _aoReceberAberto(RemoteMessage mensagem) async {
    if (mensagem.data.isEmpty) return;
    final n = NotificacaoApp.fromMap(Map<String, dynamic>.from(mensagem.data));
    final daConversaAberta =
        n.tipo == TipoNotificacao.conversa &&
        n.fkConversa != null &&
        n.fkConversa == conversaEmTela;
    // Aviso da outra conta (independente x loja): não aparece agora.
    if (!daConversaAberta && !await ehDeOutroPerfil(n)) {
      await NotificacaoExibicao.mostrar(n);
    }
    unawaited(atualizarContadores());
  }

  void _aoTocarLocal(NotificationResponse resposta) {
    final n = NotificacaoApp.dePayload(resposta.payload);
    if (n != null) abrir(n);
  }

  /// Marca como aberta e navega para a tela da notificação.
  Future<void> abrir(NotificacaoApp n) async {
    final nav = _navegador?.currentState;
    if (nav == null || !_appPronto) {
      _aberturaPendente = n;
      return;
    }
    if (Supabase.instance.client.auth.currentSession == null) return;
    if (n.id != null && !n.aberta) {
      unawaited(marcarAberta(n.id!));
    }
    await NotificacaoDestinos.abrir(nav, n);
  }

  Future<void> marcarAberta(int idNotificacao) async {
    try {
      await NotificacaoRepositorio.marcarAberta(idNotificacao);
    } catch (e) {
      debugPrint('[Notificacoes] marcar aberta: $e');
    }
    await atualizarContadores();
  }

  Future<void> marcarTodasAbertas() async {
    try {
      await NotificacaoRepositorio.marcarTodasAbertas();
    } catch (e) {
      debugPrint('[Notificacoes] marcar todas: $e');
    }
    await atualizarContadores();
  }

  // ── Contadores + Realtime ────────────────────────────────────────────────

  Future<void> atualizarContadores() async {
    if (_idUsuario == null) return;
    try {
      final (gerais, mensagens) = await NotificacaoRepositorio.contadores(
        perfil: await _perfilAtivo(),
      );
      if (gerais != naoLidas || mensagens != mensagensNaoLidas) {
        naoLidas = gerais;
        mensagensNaoLidas = mensagens;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Notificacoes] contadores: $e');
    }
  }

  void _iniciarRealtime(int idUsuario) {
    final client = Supabase.instance.client;
    if (_canal != null) client.removeChannel(_canal!);
    _canal = client
        .channel('notificacoes_$idUsuario')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificacoes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'fk_usuario',
            value: idUsuario,
          ),
          callback: (_) {
            _alteracoes.add(null);
            unawaited(atualizarContadores());
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    for (final s in _subsFcm) {
      s.cancel();
    }
    _authSub?.cancel();
    _alteracoes.close();
    super.dispose();
  }
}
