import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/pedidos_cliente_service.dart';
import 'servico_concluido_cliente.dart';
import 'widgets/card_pedido_resumo.dart';
import 'widgets/skeleton_loading.dart';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';

/// Avaliações que o cliente fez dos serviços. Toque → serviço concluído.
class MeusServicosAvaliadosClientePage extends StatefulWidget {
  const MeusServicosAvaliadosClientePage({super.key});

  @override
  State<MeusServicosAvaliadosClientePage> createState() =>
      _MeusServicosAvaliadosClientePageState();
}

class _MeusServicosAvaliadosClientePageState
    extends State<MeusServicosAvaliadosClientePage> {
  static const _texto = Color(0xFF111827);
  static const _sec = Color(0xFF6B7280);

  List<AvaliacaoFeita>? _lista;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final l = await PedidosClienteService.minhasAvaliacoes();
      if (mounted)
        setState(() {
          _lista = l;
          _erro = null;
        });
    } catch (e) {
      debugPrint('[avaliados] $e');
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar suas avaliações.');
      }
    }
  }

  bool _video(String u) {
    final x = u.toLowerCase().split('?').first;
    return ['.mp4', '.mov', '.m4v', '.3gp', '.webm'].any(x.endsWith);
  }

  void _abrirMidia(String url) {
    if (_video(url)) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(child: InteractiveViewer(child: ImagemApp(child: Image.network(url)))),
        ),
      ),
    );
  }

  Widget _card(AvaliacaoFeita a) {
    final p = a.pedido;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => ServicoConcluidoClientePage(idSolicitacao: p.id),
            ),
          )
          .then((_) => _carregar()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDEFF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                imagemPedido(p.imagem, p.titulo, tamanho: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _texto,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      prestadorPedido(p),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _sec),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Icon(
                    i < a.nota
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 20,
                    color: const Color(0xFFF59E0B),
                  ),
                const Spacer(),
                if (a.data != null)
                  Text(
                    dataPedido(a.data!),
                    style: const TextStyle(color: _sec, fontSize: 12),
                  ),
              ],
            ),
            if (a.comentario.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                a.comentario,
                style: const TextStyle(color: Color(0xFF334155), height: 1.4),
              ),
            ],
            if (a.midias.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: a.midias.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final m = a.midias[i];
                    return GestureDetector(
                      onTap: () => _abrirMidia(m),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: _video(m)
                              ? Container(
                                  color: const Color(0xFF1F2937),
                                  child: const Icon(
                                    Icons.play_circle_outline_rounded,
                                    color: Colors.white,
                                  ),
                                )
                              : ImagemApp(child: Image.network(m, fit: BoxFit.cover)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = _lista;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: appBarPerfil(
        'Avaliações de Serviços',
        acoes: [
          BotaoAjuda(
            passos: () => explicacaoDaTela(
              context,
              tela: 'Aqui ficam as avaliações que você fez.',
              conteudo: [
                'Cada card mostra a nota, o comentário e as fotos. Toque para abrir o serviço.',
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _erro != null
            ? listaVaziaPerfil(Icons.wifi_off_rounded, 'Ops!', _erro!)
            : l == null
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (var i = 0; i < 4; i++)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SkeletonBox(height: 140, borderRadius: 18),
                    ),
                ],
              )
            : l.isEmpty
            ? listaVaziaPerfil(
                Icons.star_outline_rounded,
                'Nenhuma avaliação ainda',
                'Quando você avaliar um serviço concluído, ele aparece aqui.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [for (final a in l) _card(a)],
              ),
      ),
    );
  }
}
