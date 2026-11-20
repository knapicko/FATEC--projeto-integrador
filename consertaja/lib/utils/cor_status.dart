import 'package:flutter/material.dart';

import 'fluxo_solicitacao.dart';

/// Cor, ícone e rótulo de cada status de solicitação — a MESMA regra em
/// meus_pedidos.dart, meus_servicos_solicitados.dart e tela_mensagens.dart.
///
/// Base: as cores de meus_servicos_solicitados (azul = em curso, laranja =
/// esperando alguém agir), com verde para pago/concluído e vermelho para
/// cancelado/recusado.
class EstiloStatus {
  const EstiloStatus(this.cor, this.icone, this.rotulo);

  final Color cor;
  final IconData icone;
  final String rotulo;

  /// Fundo claro para pills.
  Color get fundo => cor.withValues(alpha: 0.13);

  /// Borda suave para pills.
  Color get borda => cor.withValues(alpha: 0.35);

  /// Versão mais escura para texto sobre o fundo claro.
  Color get texto {
    final hsl = HSLColor.fromColor(cor);
    return hsl.withLightness((hsl.lightness * 0.72).clamp(0.2, 0.5)).toColor();
  }

  static const Color azul = Color(0xFF0FB3FF);
  static const Color laranja = Color(0xFFF59E0B);
  static const Color verde = Color(0xFF16A34A);
  static const Color vermelho = Color(0xFFDC2626);
  static const Color cinza = Color(0xFF64748B);

  /// Estilo de uma solicitação a partir de status + modalidade + etapa.
  static EstiloStatus de({
    required int? fkStatus,
    String? tipoExecucao,
    int etapa = 0,
    String? statusTexto,
  }) {
    final f = FluxoSolicitacao(
      tipoExecucao: tipoExecucao,
      fkStatus: fkStatus,
      etapa: etapa,
      statusTexto: statusTexto,
    );
    final s = (statusTexto ?? '').toLowerCase();
    if (f.estaConcluido) {
      return const EstiloStatus(verde, Icons.check_circle_rounded, 'Concluído');
    }
    if (fkStatus == 7 || s.contains('cancel')) {
      return const EstiloStatus(vermelho, Icons.cancel_rounded, 'Cancelado');
    }
    if (fkStatus == 30 || s.contains('recus')) {
      return const EstiloStatus(vermelho, Icons.block_rounded, 'Recusado');
    }
    if (f.estaAberto) {
      return const EstiloStatus(
        laranja,
        Icons.hourglass_top_rounded,
        'Aguardando resposta',
      );
    }
    if (f.aguardandoPagamento) {
      return const EstiloStatus(
        laranja,
        Icons.payments_outlined,
        'Aguardando pagamento',
      );
    }
    if (f.estaPago) {
      return const EstiloStatus(verde, Icons.verified_rounded, 'Pago');
    }
    if (f.clienteDeslocando) {
      return const EstiloStatus(
        azul,
        Icons.directions_walk_rounded,
        'Cliente a caminho',
      );
    }
    if (f.profissionalDeslocando || f.devolucaoDeslocando) {
      return const EstiloStatus(
        azul,
        Icons.navigation_rounded,
        'Em deslocamento',
      );
    }
    if (f.profissionalChegou || f.devolucaoChegou) {
      return EstiloStatus(
        azul,
        Icons.place_rounded,
        f.modalidade.ehDomicilio && f.profissionalChegou
            ? 'Atendimento no local'
            : 'No local',
      );
    }
    if (f.emAndamento) {
      return const EstiloStatus(
        azul,
        Icons.build_circle_outlined,
        'Em andamento',
      );
    }
    if (f.aguardandoRetirada) {
      return const EstiloStatus(
        laranja,
        Icons.storefront_outlined,
        'Aguardando retirada',
      );
    }
    if (f.aguardandoDevolucao) {
      return const EstiloStatus(
        laranja,
        Icons.inventory_2_outlined,
        'Aguardando devolução',
      );
    }
    return EstiloStatus(
      azul,
      Icons.info_outline_rounded,
      statusTexto?.trim().isNotEmpty == true ? statusTexto!.trim() : 'Ativo',
    );
  }
}
