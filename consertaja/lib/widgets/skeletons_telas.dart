import 'package:flutter/material.dart';

import 'skeleton_loading.dart';

/// Skeletons no formato de cada tela (em vez de um círculo girando): o
/// usuário já vê onde cada coisa vai aparecer.

Widget _card(
  List<Widget> filhos, {
  EdgeInsets margin = const EdgeInsets.only(bottom: 14),
  double raio = 18,
}) {
  return Container(
    margin: margin,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(raio),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: filhos,
    ),
  );
}

Widget _linhaPerfil({double avatar = 48}) => Row(
  children: [
    SkeletonBox(width: avatar, height: avatar, borderRadius: avatar / 2),
    const SizedBox(width: 12),
    const Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 150, height: 15),
          SizedBox(height: 8),
          SkeletonBox(width: 100, height: 12),
        ],
      ),
    ),
  ],
);

/// minhas_notificacoes.dart: avatar + título + texto + data/pílula.
class SkeletonNotificacoes extends StatelessWidget {
  const SkeletonNotificacoes({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (_, i) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 54, height: 54, borderRadius: i.isEven ? 27 : 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: i.isEven ? 170 : 130, height: 15),
                const SizedBox(height: 8),
                const SkeletonBox(height: 12),
                const SizedBox(height: 6),
                SkeletonBox(width: i.isEven ? 200 : 150, height: 12),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    SkeletonBox(width: 70, height: 11),
                    SizedBox(width: 8),
                    SkeletonBox(width: 64, height: 16, borderRadius: 8),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// detalhes_pedido.dart: status + linha do tempo, profissional, serviço,
/// endereço e valores.
class SkeletonDetalhesPedido extends StatelessWidget {
  const SkeletonDetalhesPedido({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _card([
          const SkeletonBox(width: 140, height: 22, borderRadius: 11),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              5,
              (_) => const SkeletonBox(width: 26, height: 26, borderRadius: 13),
            ),
          ),
          const SizedBox(height: 10),
          const SkeletonBox(height: 10),
        ]),
        _card([_linhaPerfil(avatar: 52)]),
        _card(const [
          SkeletonBox(height: 150, borderRadius: 14),
          SizedBox(height: 14),
          SkeletonBox(width: 190, height: 16),
          SizedBox(height: 8),
          SkeletonBox(height: 12),
          SizedBox(height: 6),
          SkeletonBox(width: 220, height: 12),
        ]),
        _card(const [
          SkeletonBox(width: 120, height: 14),
          SizedBox(height: 12),
          SkeletonBox(height: 12),
          SizedBox(height: 8),
          SkeletonBox(height: 12),
          SizedBox(height: 14),
          SkeletonBox(width: 140, height: 22),
        ]),
      ],
    );
  }
}

/// Telas de etapa do fluxo (deslocamento, retirada, atendimento no local,
/// profissional no local): mapa/topo, card do outro lado, card da etapa e
/// botão no rodapé.
class SkeletonEtapaFluxo extends StatelessWidget {
  const SkeletonEtapaFluxo({super.key, this.comMapa = true});

  final bool comMapa;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (comMapa) ...[
                const SkeletonBox(height: 220, borderRadius: 20),
                const SizedBox(height: 16),
              ],
              _card([_linhaPerfil()]),
              _card(const [
                SkeletonBox(width: 160, height: 16),
                SizedBox(height: 12),
                SkeletonBox(height: 12),
                SizedBox(height: 6),
                SkeletonBox(width: 230, height: 12),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 56, borderRadius: 12)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 56, borderRadius: 12)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 56, borderRadius: 12)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 56, borderRadius: 12)),
                  ],
                ),
              ]),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: SkeletonBox(height: 52, borderRadius: 26),
        ),
      ],
    );
  }
}

/// meus_documentos.dart: cards de documento (ícone, nome, status).
class SkeletonDocumentos extends StatelessWidget {
  const SkeletonDocumentos({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, _) => _card(const [
        Row(
          children: [
            SkeletonBox(width: 44, height: 44, borderRadius: 12),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 150, height: 15),
                  SizedBox(height: 8),
                  SkeletonBox(width: 90, height: 12),
                ],
              ),
            ),
            SkeletonBox(width: 76, height: 24, borderRadius: 12),
          ],
        ),
      ]),
    );
  }
}

/// meus_dados_financeiros_profissional.dart: documento, formas de
/// pagamento (chaves) e campo PIX.
class SkeletonFinanceiro extends StatelessWidget {
  const SkeletonFinanceiro({super.key});

  @override
  Widget build(BuildContext context) {
    Widget opcao() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SkeletonBox(width: 36, height: 36, borderRadius: 10),
          SizedBox(width: 12),
          Expanded(child: SkeletonBox(height: 14)),
          SizedBox(width: 40),
          SkeletonBox(width: 44, height: 24, borderRadius: 12),
        ],
      ),
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _card(const [
          SkeletonBox(width: 130, height: 13),
          SizedBox(height: 10),
          SkeletonBox(width: 200, height: 20),
        ]),
        _card([
          const SkeletonBox(width: 170, height: 15),
          const SizedBox(height: 8),
          opcao(),
          opcao(),
          opcao(),
        ]),
        _card(const [
          SkeletonBox(width: 110, height: 13),
          SizedBox(height: 10),
          SkeletonBox(height: 48, borderRadius: 12),
        ]),
      ],
    );
  }
}

/// pedido_pago.dart: selo de confirmação, resumo e botão.
class SkeletonPedidoPago extends StatelessWidget {
  const SkeletonPedidoPago({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 24),
        const Center(
          child: SkeletonBox(width: 96, height: 96, borderRadius: 48),
        ),
        const SizedBox(height: 18),
        const Center(child: SkeletonBox(width: 210, height: 22)),
        const SizedBox(height: 10),
        const Center(child: SkeletonBox(width: 250, height: 13)),
        const SizedBox(height: 28),
        _card(const [
          SkeletonBox(width: 120, height: 14),
          SizedBox(height: 14),
          SkeletonBox(height: 12),
          SizedBox(height: 8),
          SkeletonBox(height: 12),
          SizedBox(height: 8),
          SkeletonBox(width: 180, height: 12),
        ]),
        const SizedBox(height: 8),
        const SkeletonBox(height: 52, borderRadius: 26),
      ],
    );
  }
}

/// alterar_tema_chat.dart: prévia do chat + grade de temas.
class SkeletonTemasChat extends StatelessWidget {
  const SkeletonTemasChat({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const SkeletonBox(height: 230, borderRadius: 20),
        const SizedBox(height: 18),
        Row(
          children: List.generate(
            4,
            (_) => const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SkeletonBox(width: 72, height: 30, borderRadius: 15),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
          children: List.generate(
            6,
            (_) => const SkeletonBox(height: double.infinity, borderRadius: 14),
          ),
        ),
      ],
    );
  }
}

/// Radar do profissional (lista de solicitações próximas no sheet).
class SkeletonCardsRadar extends StatelessWidget {
  const SkeletonCardsRadar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                const SkeletonBox(width: 64, height: 64, borderRadius: 14),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, height: 15),
                      SizedBox(height: 8),
                      SkeletonBox(height: 12),
                      SizedBox(height: 8),
                      SkeletonBox(width: 110, height: 12),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const SkeletonBox(width: 54, height: 24, borderRadius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
