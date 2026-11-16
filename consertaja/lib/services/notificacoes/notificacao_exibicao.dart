// =============================================================================
// ConsertaJá — Desenho das notificações no celular (flutter_local_notifications)
//
// Usado em 3 situações, sempre pelo mesmo código (sem duplicar):
//   • app aberto: o FCM chega em onMessage e mostramos aqui;
//   • app em segundo plano/fechado (Android): a Edge Function manda só `data`
//     e o handler de segundo plano chama [mostrar] (outro isolate);
//   • feedbacks locais (NotificacaoFeedback).
// =============================================================================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'notificacao_app.dart';
import 'notificacao_tipos.dart';

class NotificacaoExibicao {
  NotificacaoExibicao._();

  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  static bool _iniciado = false;

  /// Ícone pequeno (silhueta branca) gerado por tool/gerar_icones_notificacao.dart.
  static const String iconePequeno = 'ic_notificacao';

  /// Prepara o plugin e os canais. [aoTocar] recebe o toque na notificação.
  static Future<void> inicializar({
    DidReceiveNotificationResponseCallback? aoTocar,
  }) async {
    if (_iniciado || kIsWeb) return;
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(iconePequeno),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: aoTocar,
    );

    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final vistos = <String>{};
      for (final t in TipoNotificacao.values) {
        if (!vistos.add(t.canalId)) continue;
        await android.createNotificationChannel(
          AndroidNotificationChannel(
            t.canalId,
            t.canalNome,
            description: t.canalDescricao,
            importance: t.importancia,
            ledColor: kAzulNotificacao,
            enableLights: true,
          ),
        );
      }
    }
    _iniciado = true;
  }

  /// Pede permissão de notificação (Android 13+ / iOS).
  static Future<bool> pedirPermissao() async {
    if (kIsWeb) return false;
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  /// Notificação tocada com o app fechado (para abrir a tela certa).
  static Future<NotificacaoApp?> notificacaoQueAbriuOApp() async {
    if (kIsWeb) return null;
    final detalhes = await plugin.getNotificationAppLaunchDetails();
    if (detalhes == null || !detalhes.didNotificationLaunchApp) return null;
    return NotificacaoApp.dePayload(detalhes.notificationResponse?.payload);
  }

  static int _idAndroid(NotificacaoApp n) {
    // Conversa: o mesmo id por conversa → a nova substitui a anterior.
    if (n.tipo == TipoNotificacao.conversa && n.fkConversa != null) {
      return 900000000 + (n.fkConversa! % 90000000);
    }
    if (n.id != null) return n.id! % 0x7FFFFFFF;
    return DateTime.now().millisecondsSinceEpoch % 0x7FFFFFFF;
  }

  /// Baixa a foto e recorta em círculo (ícone grande). Falhou → null.
  static Future<Uint8List?> _fotoRedonda(String? url) async {
    if (url == null || url.isEmpty || !url.startsWith('http')) return null;
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;
      final original = img.decodeImage(resp.bodyBytes);
      if (original == null) return null;
      final lado = original.width < original.height
          ? original.width
          : original.height;
      final quadrado = img.copyCrop(
        original,
        x: (original.width - lado) ~/ 2,
        y: (original.height - lado) ~/ 2,
        width: lado,
        height: lado,
      );
      final pequeno = img.copyResize(quadrado, width: 192, height: 192);
      return Uint8List.fromList(img.encodePng(img.copyCropCircle(pequeno)));
    } catch (e) {
      debugPrint('[Notificacoes] foto: $e');
      return null;
    }
  }

  static Future<void> mostrar(NotificacaoApp n) async {
    if (kIsWeb) return;
    await inicializar();

    final cor = Color(n.corArgb);
    final foto = await _fotoRedonda(n.imagemUrl);
    final AndroidBitmap<Object> iconeGrande = foto != null
        ? ByteArrayAndroidBitmap(foto)
        : const DrawableResourceAndroidBitmap('notif_logo');
    final resumo = n.textoStatus ?? n.tipo.rotulo;

    StyleInformation estilo;
    if (n.tipo == TipoNotificacao.conversa) {
      final remetente = Person(
        name: n.titulo,
        key: 'conversa_${n.fkConversa}',
        icon: foto != null ? ByteArrayAndroidIcon(foto) : null,
      );
      estilo = MessagingStyleInformation(
        const Person(name: 'Você'),
        groupConversation: false,
        messages: [Message(n.conteudo, n.dataCriacao, remetente)],
      );
    } else {
      estilo = BigTextStyleInformation(
        n.conteudo,
        contentTitle: n.titulo,
        summaryText: resumo,
      );
    }

    final android = AndroidNotificationDetails(
      n.tipo.canalId,
      n.tipo.canalNome,
      channelDescription: n.tipo.canalDescricao,
      importance: n.tipo.importancia,
      priority: n.tipo.importancia == Importance.high
          ? Priority.high
          : Priority.defaultPriority,
      icon: iconePequeno,
      color: cor,
      largeIcon: iconeGrande,
      styleInformation: estilo,
      subText: n.tipo.rotulo,
      groupKey: 'consertaja_${n.tipo.banco}',
      tag: n.tipo == TipoNotificacao.conversa && n.fkConversa != null
          ? 'conversa_${n.fkConversa}'
          : null,
      category: n.tipo == TipoNotificacao.conversa
          ? AndroidNotificationCategory.message
          : AndroidNotificationCategory.status,
      when: n.dataCriacao.millisecondsSinceEpoch,
      ticker: n.titulo,
    );

    await plugin.show(
      id: _idAndroid(n),
      title: n.titulo,
      body: n.conteudo,
      notificationDetails: NotificationDetails(
        android: android,
        iOS: DarwinNotificationDetails(
          threadIdentifier: n.tipo.banco,
          subtitle: n.tipo.rotulo,
        ),
      ),
      payload: n.paraPayload(),
    );
  }

  /// Some com a notificação da conversa (ao abrir o chat).
  static Future<void> limparConversa(int idConversa) async {
    if (kIsWeb) return;
    try {
      await plugin.cancel(
        id: 900000000 + (idConversa % 90000000),
        tag: 'conversa_$idConversa',
      );
    } catch (_) {}
  }
}
