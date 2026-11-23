import 'package:flutter/material.dart';

import 'informacoes_servico_profissional.dart';
import 'models/servico_profissional.dart';
import 'services/avaliacoes_servico_service.dart';
import 'services/conta_profissional_ativa.dart';
import 'services/servicos_profissional_service.dart';
import 'utils/cor_oficio.dart';
import 'widgets/card_pedido_resumo.dart';
import 'widgets/selo_conta_ativa.dart';
import 'widgets/skeleton_loading.dart';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';

/// Avaliações dos serviços do profissional (ou da loja, com a conta de loja
/// ativa): um card por serviço com a nota média e a quantidade. Toque →
/// informações do serviço como o cliente vê, com todas as avaliações.
class MinhasAvaliacoesProfissionalPage extends StatefulWidget {
  const MinhasAvaliacoesProfissionalPage({super.key});

  @override
  State<MinhasAvaliacoesProfissionalPage> createState() =>
      _MinhasAvaliacoesProfissionalPageState();
}

class _MinhasAvaliacoesProfissionalPageState
    extends State<MinhasAvaliacoesProfissionalPage> {
  static const _azul = Color(0xFF0FB3FF);
  static const _texto = Color(0xFF111827);
  static const _sec = Color(0xFF6B7280);
  static const _estrela = Color(0xFFF59E0B);

  ContaProfissionalAtiva? _conta;
  List<ServicoProfissional>? _servicos;
  Map<int, ResumoAvaliacoes> _resumos = {};
  String? _erro;
  final _busca = TextEditingController();
  String _ordem = 'avaliacoes';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final conta = await ContaProfissionalAtiva.carregar();
      List<ServicoProfissional> servicos = const [];
      if (conta != null) {
        if (conta.empresa) {
          servicos = conta.idGrupoEmpresa == null
              ? const []
              : (await ServicosProfissionalService.buscarServicosEmpresa(
                      conta.idGrupoEmpresa!,
                    ))
                    .where((s) => s.fkGrupoEmpresa == conta.idGrupoEmpresa)
                    .toList();
        } else if (conta.idProfissional != null) {
          servicos = (await ServicosProfissionalService.buscarServicos(
            idProfissional: conta.idProfissional,
          )).where((s) => s.fkGrupoEmpresa == null).toList();
        }
      }
      final resumos = await AvaliacoesServicoService.resumoPorServico([
        for (final s in servicos) s.id,
      ]);
      if (!mounted) return;
      setState(() {
        _conta = conta;
        _servicos = servicos;
        _resumos = resumos;
        _erro = conta == null
            ? 'Não foi possível identificar sua conta.'
            : null;
      });
    } catch (e) {
      debugPrint('[minhas avaliações prof] $e');
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar suas avaliações.');
      }
    }
  }

  ResumoAvaliacoes _resumo(int id) => _resumos[id] ?? ResumoAvaliacoes.vazio;

  List<ServicoProfissional> get _filtrados {
    final termo = _busca.text.trim().toLowerCase();
    final l = [
      for (final s in _servicos ?? const <ServicoProfissional>[])
        if (termo.isEmpty ||
            s.titulo.toLowerCase().contains(termo) ||
            s.descricao.toLowerCase().contains(termo) ||
            (s.funcao ?? '').toLowerCase().contains(termo))
          s,
    ];
    l.sort(
      (a, b) => switch (_ordem) {
        'nota' => _resumo(b.id).media.compareTo(_resumo(a.id).media),
        'nome' => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()),
        _ => _resumo(b.id).total.compareTo(_resumo(a.id).total),
      },
    );
    return l;
  }

  Future<void> _abrir(ServicoProfissional s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InformacoesServicoProfissionalPage(idServico: s.id),
      ),
    );
    _carregar();
  }

  Widget _estrelas(double media, {double tamanho = 15}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          media >= i
              ? Icons.star_rounded
              : media >= i - 0.5
              ? Icons.star_half_rounded
              : Icons.star_outline_rounded,
          size: tamanho,
          color: _estrela,
        ),
    ],
  );

  Widget _resumoGeral() {
    var total = 0;
    var soma = 0.0;
    for (final r in _resumos.values) {
      total += r.total;
      soma += r.media * r.total;
    }
    final media = total == 0 ? 0.0 : soma / total;
    return CorOriginal(interface: true, child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0FB3FF), Color(0xFF0A8FD6)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                total == 0 ? '–' : media.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      media >= i
                          ? Icons.star_rounded
                          : media >= i - 0.5
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nota média geral',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total ${total == 1 ? 'avaliação' : 'avaliações'} em '
                  '${_servicos?.length ?? 0} '
                  '${(_servicos?.length ?? 0) == 1 ? 'serviço' : 'serviços'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _barraBusca() => Row(
    children: [
      Expanded(
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar serviço',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.search_rounded, color: _sec),
              suffixIcon: _busca.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(_busca.clear),
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      PopupMenuButton<String>(
        tooltip: 'Ordenar',
        initialValue: _ordem,
        onSelected: (v) => setState(() => _ordem = v),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'avaliacoes', child: Text('Mais avaliados')),
          PopupMenuItem(value: 'nota', child: Text('Maior nota')),
          PopupMenuItem(value: 'nome', child: Text('Nome (A–Z)')),
        ],
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Icon(Icons.sort_rounded, color: _azul),
        ),
      ),
    ],
  );

  Widget _card(ServicoProfissional s) {
    final r = _resumo(s.id);
    final corFuncao = CorOficio.parse(s.cor);
    final img = s.imagemUrl?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _abrir(s),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDEFF2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      img.startsWith('http')
                          ? ImagemApp(child: Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _semImagem(),
                            ))
                          : _semImagem(),
                      if (s.funcao?.trim().isNotEmpty == true)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: corFuncao.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.funcao!.trim().toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFACC15),
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                r.total == 0
                                    ? 'Novo'
                                    : r.media.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              s.titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _texto,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            s.valor > 0 ? realPedido(s.valor) : 'Sob consulta',
                            style: const TextStyle(
                              color: _azul,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      if (s.descricao.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          s.descricao.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _sec,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _estrelas(r.media),
                            const SizedBox(width: 8),
                            Text(
                              r.total == 0
                                  ? 'Sem avaliações ainda'
                                  : '${r.media.toStringAsFixed(1)} · '
                                        '${r.total} '
                                        '${r.total == 1 ? 'avaliação' : 'avaliações'}',
                              style: const TextStyle(
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'Ver',
                              style: TextStyle(
                                color: _azul,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _azul,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _semImagem() => Container(
    color: const Color(0xFFE0F2FE),
    alignment: Alignment.center,
    child: const Icon(Icons.handyman_rounded, color: _azul, size: 40),
  );

  @override
  Widget build(BuildContext context) {
    final l = _servicos;
    final conta = _conta;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: appBarPerfil(
        'Minhas Avaliações',
        acoes: [
          BotaoAjuda(
            passos: () => explicacaoDaTela(
              context,
              tela: 'Aqui ficam as avaliações dos seus serviços.',
              conteudo: [
                'No topo fica a sua nota média geral. Use a busca e a ordenação para achar um serviço.',
                'Toque em um serviço para ver todas as avaliações dele, do jeito que o cliente vê.',
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _azul,
        onRefresh: _carregar,
        child: _erro != null
            ? listaVaziaPerfil(Icons.wifi_off_rounded, 'Ops!', _erro!)
            : l == null || conta == null
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const SkeletonBox(height: 58, borderRadius: 14),
                  const SizedBox(height: 12),
                  const SkeletonBox(height: 96, borderRadius: 18),
                  const SizedBox(height: 12),
                  for (var i = 0; i < 3; i++)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: SkeletonBox(height: 230, borderRadius: 18),
                    ),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  SeloContaAtiva(
                    conta: conta,
                    texto: conta.empresa
                        ? 'Avaliações dos serviços da loja'
                        : 'Avaliações dos seus serviços',
                  ),
                  const SizedBox(height: 12),
                  if (l.isEmpty)
                    SizedBox(
                      height: 420,
                      child: listaVaziaPerfil(
                        Icons.home_repair_service_outlined,
                        'Nenhum serviço ainda',
                        conta.empresa
                            ? 'Quando a loja tiver serviços, as avaliações '
                                  'deles aparecem aqui.'
                            : 'Quando você cadastrar serviços, as avaliações '
                                  'deles aparecem aqui.',
                      ),
                    )
                  else ...[
                    _resumoGeral(),
                    const SizedBox(height: 14),
                    _barraBusca(),
                    const SizedBox(height: 14),
                    if (_filtrados.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: Text(
                          'Nenhum serviço encontrado.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _sec),
                        ),
                      )
                    else
                      for (final s in _filtrados) _card(s),
                  ],
                ],
              ),
      ),
    );
  }
}
