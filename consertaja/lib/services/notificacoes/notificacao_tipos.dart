// =============================================================================
// ConsertaJá — Tipos de notificação e identidade visual
//
// Um lugar só para: nome no banco (`notificacoes.tipo`), canal Android, cor,
// ícone e rótulo de cada tipo, e a cor/ícone de cada status. Para criar um
// tipo novo: acrescente no enum (e no CHECK da tabela) e, se precisar de
// destino próprio, em notificacao_destinos.dart.
// =============================================================================
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Azul oficial das notificações do ConsertaJá.
const Color kAzulNotificacao = Color(0xFF0FB3FF);

enum TipoNotificacao {
  sistema(
    banco: 'Sistema',
    rotulo: 'ConsertaJá',
    canalId: 'consertaja_conta',
    canalNome: 'Sua conta',
    canalDescricao: 'Lembretes para completar o seu cadastro.',
    icone: Icons.manage_accounts_rounded,
    cor: kAzulNotificacao,
    importancia: Importance.defaultImportance,
  ),
  solicitacao(
    banco: 'Solicitação',
    rotulo: 'Pedidos',
    canalId: 'consertaja_pedidos',
    canalNome: 'Pedidos',
    canalDescricao: 'Novos pedidos e mudanças de status.',
    icone: Icons.receipt_long_rounded,
    cor: Color(0xFF0284C7),
    importancia: Importance.high,
  ),
  global(
    banco: 'Global',
    rotulo: 'Novidades',
    canalId: 'consertaja_novidades',
    canalNome: 'Novidades',
    canalDescricao: 'Avisos gerais do ConsertaJá.',
    icone: Icons.campaign_rounded,
    cor: Color(0xFF7C3AED),
    importancia: Importance.defaultImportance,
  ),
  conversa(
    banco: 'Conversa',
    rotulo: 'Mensagens',
    canalId: 'consertaja_mensagens',
    canalNome: 'Mensagens',
    canalDescricao: 'Novas mensagens nas suas conversas.',
    icone: Icons.chat_bubble_rounded,
    cor: Color(0xFF10B981),
    importancia: Importance.high,
  ),
  radarProf(
    banco: 'radar_prof',
    rotulo: 'Radar',
    canalId: 'consertaja_radar',
    canalNome: 'Radar',
    canalDescricao: 'Pedidos perto de você e respostas às propostas.',
    icone: Icons.sensors_rounded,
    cor: kAzulNotificacao,
    importancia: Importance.high,
  ),
  radarCliente(
    banco: 'radar_cliente',
    rotulo: 'Radar',
    canalId: 'consertaja_radar',
    canalNome: 'Radar',
    canalDescricao: 'Pedidos perto de você e respostas às propostas.',
    icone: Icons.sensors_rounded,
    cor: kAzulNotificacao,
    importancia: Importance.high,
  ),
  feedback(
    banco: 'feedback',
    rotulo: 'ConsertaJá',
    canalId: 'consertaja_feedback',
    canalNome: 'Confirmações',
    canalDescricao: 'Confirmações das ações que você faz no app.',
    icone: Icons.check_circle_rounded,
    cor: Color(0xFF16A34A),
    importancia: Importance.high,
  );

  const TipoNotificacao({
    required this.banco,
    required this.rotulo,
    required this.canalId,
    required this.canalNome,
    required this.canalDescricao,
    required this.icone,
    required this.cor,
    required this.importancia,
  });

  /// Valor gravado em `notificacoes.tipo`.
  final String banco;

  /// Texto curto mostrado na notificação e nos filtros.
  final String rotulo;
  final String canalId;
  final String canalNome;
  final String canalDescricao;
  final IconData icone;
  final Color cor;
  final Importance importancia;

  static TipoNotificacao deBanco(String? valor) {
    for (final t in TipoNotificacao.values) {
      if (t.banco == valor) return t;
    }
    return TipoNotificacao.sistema;
  }

  bool get ehRadar => this == radarProf || this == radarCliente;
}

/// Cor e ícone de um status (`status.id_status`) para estilizar a notificação.
class VisualStatus {
  const VisualStatus(this.cor, this.icone);

  final Color cor;
  final IconData icone;

  static const _verde = Color(0xFF16A34A);
  static const _ambar = Color(0xFFF59E0B);
  static const _vermelho = Color(0xFFDC2626);
  static const _roxo = Color(0xFF7C3AED);
  static const _teal = Color(0xFF0D9488);
  static const _laranja = Color(0xFFEA580C);

  static VisualStatus? de(int? idStatus) {
    switch (idStatus) {
      case 1:
        return const VisualStatus(kAzulNotificacao, Icons.send_rounded);
      case 2:
        return const VisualStatus(_ambar, Icons.payments_rounded);
      case 3:
        return const VisualStatus(_verde, Icons.paid_rounded);
      case 4:
        return const VisualStatus(Color(0xFF0284C7), Icons.handyman_rounded);
      case 5:
        return const VisualStatus(_laranja, Icons.hourglass_top_rounded);
      case 6:
        return const VisualStatus(_verde, Icons.task_alt_rounded);
      case 7:
      case 30:
        return const VisualStatus(_vermelho, Icons.cancel_rounded);
      case 31:
        return const VisualStatus(_verde, Icons.thumb_up_alt_rounded);
      case 32:
      case 33:
      case 36:
        return const VisualStatus(_roxo, Icons.directions_car_rounded);
      case 34:
      case 37:
        return const VisualStatus(_teal, Icons.location_on_rounded);
      case 35:
        return const VisualStatus(_ambar, Icons.inventory_2_rounded);
      case 38:
        return const VisualStatus(_roxo, Icons.directions_walk_rounded);
      // Solicitação geográfica / propostas
      case 39:
        return const VisualStatus(kAzulNotificacao, Icons.sensors_rounded);
      case 40:
        return const VisualStatus(_verde, Icons.task_alt_rounded);
      case 41:
        return const VisualStatus(kAzulNotificacao, Icons.visibility_rounded);
      case 42:
      case 46:
        return const VisualStatus(_verde, Icons.handshake_rounded);
      case 43:
      case 45:
        return const VisualStatus(_vermelho, Icons.cancel_rounded);
      case 44:
        return const VisualStatus(_ambar, Icons.local_offer_rounded);
    }
    return null;
  }
}
