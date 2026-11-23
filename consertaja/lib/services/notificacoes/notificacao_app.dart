import 'dart:convert';

import 'notificacao_tipos.dart';

/// Uma linha de `notificacoes` (ou o `data` de uma mensagem FCM, que traz os
/// mesmos campos como texto).
class NotificacaoApp {
  const NotificacaoApp({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.conteudo,
    required this.dataCriacao,
    this.aberta = false,
    this.telaDestino,
    this.imagemUrl,
    this.fkSolicitacao,
    this.fkConversa,
    this.fkSolicitacaoGeografica,
    this.fkStatus,
    this.dados = const {},
    this.perfilDestino,
  });

  /// null para feedbacks locais (não ficam no banco).
  final int? id;
  final TipoNotificacao tipo;
  final String titulo;
  final String conteudo;
  final DateTime dataCriacao;
  final bool aberta;
  final String? telaDestino;
  final String? imagemUrl;
  final int? fkSolicitacao;
  final int? fkConversa;
  final int? fkSolicitacaoGeografica;
  final int? fkStatus;
  final Map<String, dynamic> dados;

  /// Conta de quem recebe: 'cliente' | 'independente' | 'empresa'; null =
  /// geral (gravado pelo servidor, docs/sql/v0_10_ajustes.sql).
  final String? perfilDestino;

  VisualStatus? get visualStatus => VisualStatus.de(fkStatus);

  /// Cor de destaque: a do status (quando há) ou a do tipo.
  int get corArgb => (visualStatus?.cor ?? tipo.cor).toARGB32();

  /// Papel de quem recebeu ('cliente' | 'profissional'), gravado pelo servidor.
  String? get papel => dados['papel']?.toString();

  String? get textoStatus => dados['status']?.toString();

  NotificacaoApp copiarAberta() => NotificacaoApp(
    id: id,
    tipo: tipo,
    titulo: titulo,
    conteudo: conteudo,
    dataCriacao: dataCriacao,
    aberta: true,
    telaDestino: telaDestino,
    imagemUrl: imagemUrl,
    fkSolicitacao: fkSolicitacao,
    fkConversa: fkConversa,
    fkSolicitacaoGeografica: fkSolicitacaoGeografica,
    fkStatus: fkStatus,
    dados: dados,
    perfilDestino: perfilDestino,
  );

  static int? _int(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String? _texto(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty || s == 'null' ? null : s;
  }

  static Map<String, dynamic> _mapa(Object? v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String && v.isNotEmpty) {
      try {
        final decodificado = jsonDecode(v);
        if (decodificado is Map) return Map<String, dynamic>.from(decodificado);
      } catch (_) {}
    }
    return const {};
  }

  /// Linha do banco ou `data` do FCM (tudo string).
  factory NotificacaoApp.fromMap(Map<String, dynamic> m) {
    return NotificacaoApp(
      id: _int(m['id_notificacao']),
      tipo: TipoNotificacao.deBanco(m['tipo']?.toString()),
      titulo: _texto(m['titulo']) ?? 'ConsertaJá',
      conteudo: m['conteudo']?.toString() ?? '',
      dataCriacao:
          DateTime.tryParse(m['data_criacao']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      aberta: m['aberta'] == true || m['aberta'] == 'true',
      telaDestino: _texto(m['tela_destino']),
      imagemUrl: _texto(m['imagem_url']),
      fkSolicitacao: _int(m['fk_solicitacao']),
      fkConversa: _int(m['fk_conversa']),
      fkSolicitacaoGeografica: _int(m['fk_solicitacao_geografica']),
      fkStatus: _int(m['fk_status']),
      dados: _mapa(m['dados']),
      perfilDestino: _texto(m['perfil_destino']),
    );
  }

  /// Payload salvo na notificação local (volta no toque).
  String paraPayload() => jsonEncode({
    'id_notificacao': id,
    'tipo': tipo.banco,
    'titulo': titulo,
    'conteudo': conteudo,
    'data_criacao': dataCriacao.toUtc().toIso8601String(),
    'tela_destino': telaDestino,
    'imagem_url': imagemUrl,
    'fk_solicitacao': fkSolicitacao,
    'fk_conversa': fkConversa,
    'fk_solicitacao_geografica': fkSolicitacaoGeografica,
    'fk_status': fkStatus,
    'dados': dados,
    'perfil_destino': perfilDestino,
  });

  static NotificacaoApp? dePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final m = jsonDecode(payload);
      if (m is Map) return NotificacaoApp.fromMap(Map<String, dynamic>.from(m));
    } catch (_) {}
    return null;
  }
}
