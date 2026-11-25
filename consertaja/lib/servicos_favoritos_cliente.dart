import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/servico_profissional.dart';
import 'services/home_cliente_service.dart';
import 'services/pedidos_cliente_service.dart';
import 'tela_servico.dart';
import 'utils/funcao_servico.dart';
import 'widgets/card_pedido_resumo.dart';
import 'widgets/card_servico_popular.dart';
import 'widgets/skeleton_loading.dart';
import 'tutorial/botao_ajuda.dart';

/// Serviços que o cliente favoritou (coração na tela do serviço).
class ServicosFavoritosClientePage extends StatefulWidget {
  const ServicosFavoritosClientePage({super.key});

  @override
  State<ServicosFavoritosClientePage> createState() =>
      _ServicosFavoritosClientePageState();
}

class _ServicosFavoritosClientePageState
    extends State<ServicosFavoritosClientePage> {
  List<ServicoProfissional>? _servicos;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final ids = await FavoritosService.meusIds();
      var lista = <ServicoProfissional>[];
      if (ids.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('servicos_profissional')
            .select('*, $kSelectFuncao')
            .inFilter('id_servico_prof', ids)
            // Desativado/excluído some dos favoritos (não pode ser pedido).
            .eq('ativo', true);
        final porId = {
          for (final r in rows)
            (r['id_servico_prof'] as num).toInt(): ServicoProfissional.fromMap(
              r,
            ),
        };
        // Mantém a ordem (mais recente primeiro).
        lista = [for (final id in ids) ?porId[id]];
      }
      if (mounted)
        setState(() {
          _servicos = lista;
          _erro = null;
        });
    } catch (e) {
      debugPrint('[favoritos] $e');
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar seus favoritos.');
      }
    }
  }

  Future<void> _remover(ServicoProfissional s) async {
    setState(() => _servicos = [..._servicos!]..remove(s));
    try {
      await FavoritosService.alternar(s.id, favoritar: false);
    } catch (_) {
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _servicos;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: appBarPerfil(
        'Serviços Favoritados',
        acoes: [
          BotaoAjuda(
            passos: () => explicacaoDaTela(
              context,
              tela: 'Aqui ficam os serviços que você favoritou.',
              conteudo: [
                'Toque em um serviço para ver os detalhes e pedir. Para tirar dos favoritos, use o coração.',
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
                      child: SkeletonBox(height: 120, borderRadius: 18),
                    ),
                ],
              )
            : l.isEmpty
            ? listaVaziaPerfil(
                Icons.favorite_border_rounded,
                'Nenhum favorito ainda',
                'Toque no coração na página de um serviço para guardá-lo aqui.',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: l.length,
                itemBuilder: (_, i) {
                  final s = l[i];
                  return Stack(
                    children: [
                      CardServicoPopular(
                        item: ServicoAvaliado(servico: s),
                        aoTocar: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => TelaServico(
                                  idServico: s.id,
                                  servicoInicial: s,
                                ),
                              ),
                            )
                            .then((_) => _carregar()),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: IconButton(
                            tooltip: 'Remover dos favoritos',
                            onPressed: () => _remover(s),
                            icon: const Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
