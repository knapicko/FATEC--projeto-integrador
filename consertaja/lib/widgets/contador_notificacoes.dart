import 'package:flutter/material.dart';

import '../minhas_notificacoes.dart';
import '../services/notificacoes/notificacao_service.dart';
import '../services/notificacoes/notificacao_tipos.dart';

/// Bolinha com número (99+) sobre um ícone.
class BadgeContador extends StatelessWidget {
  const BadgeContador({
    super.key,
    required this.child,
    required this.quantidade,
    this.cor = const Color(0xFFEF4444),
    this.deslocamento = const Offset(-2, -4),
  });

  final Widget child;
  final int quantidade;
  final Color cor;

  /// Posição da bolinha em relação ao canto superior direito.
  final Offset deslocamento;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: deslocamento.dx,
          top: deslocamento.dy,
          child: AnimatedScale(
            scale: quantidade > 0 ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutBack,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cor,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                quantidade > 99 ? '99+' : '$quantidade',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Sininho com o número de notificações não lidas (Realtime). Tocar abre
/// minhas_notificacoes.dart (ou [aoTocar], se informado).
class SinoNotificacoes extends StatelessWidget {
  const SinoNotificacoes({
    super.key,
    this.cor = kAzulNotificacao,
    this.tamanho = 26,
    this.extra = 0,
    this.aoTocar,
    this.icone = Icons.notifications_none_outlined,
  });

  final Color cor;
  final double tamanho;

  /// Soma ao contador (ex.: convites de empresa pendentes).
  final int extra;
  final VoidCallback? aoTocar;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificacaoService.instance,
      builder: (context, _) {
        final total = NotificacaoService.instance.naoLidas + extra;
        return Semantics(
          button: true,
          label: total > 0 ? 'Notificações, $total não lidas' : 'Notificações',
          child: InkResponse(
            radius: 24,
            onTap:
                aoTocar ??
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MinhasNotificacoesPage(),
                  ),
                ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: BadgeContador(
                quantidade: total,
                child: Icon(
                  total > 0 ? Icons.notifications_active_outlined : icone,
                  color: cor,
                  size: tamanho,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Número de não lidas (para colocar ao lado de um item de menu).
class ContadorNaoLidas extends StatelessWidget {
  const ContadorNaoLidas({super.key, this.mensagens = false});

  /// true = mensagens não lidas; false = notificações.
  final bool mensagens;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificacaoService.instance,
      builder: (context, _) {
        final s = NotificacaoService.instance;
        final total = mensagens ? s.mensagensNaoLidas : s.naoLidas;
        if (total <= 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: kAzulNotificacao,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            total > 99 ? '99+' : '$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

/// Ícone da aba Mensagens com o número de mensagens não lidas.
class IconeMensagensComContador extends StatelessWidget {
  const IconeMensagensComContador({super.key, required this.icone});

  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificacaoService.instance,
      builder: (context, _) => BadgeContador(
        quantidade: NotificacaoService.instance.mensagensNaoLidas,
        deslocamento: const Offset(-8, -5),
        child: Icon(icone),
      ),
    );
  }
}
