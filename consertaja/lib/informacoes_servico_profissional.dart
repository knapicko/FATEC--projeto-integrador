import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'adicionar_servico_profissional.dart';
import 'meus_dados_financeiros_profissional.dart';
import 'metodo_entrega_profissional.dart';
import 'models/servico_profissional.dart';
import 'services/avaliacoes_servico_service.dart';
import 'services/conta_profissional_ativa.dart';
import 'services/servicos_profissional_service.dart';
import 'utils/cor_oficio.dart';
import 'utils/iniciais.dart';
import 'widgets/card_pedido_resumo.dart';
import 'widgets/formas_pagamento.dart';
import 'widgets/selo_conta_ativa.dart';
import 'widgets/skeleton_loading.dart';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';
import 'utils/movimento.dart';
import 'utils/abrir_video.dart';
import 'widgets/reativar_servico.dart';

/// Serviço do profissional (ou da loja) como o cliente vê na tela_servico:
/// imagem, preço, tags, métodos de realização, formas de pagamento e as
/// avaliações dos clientes (com busca e filtros). Cada seção tem um botão de
/// editar que leva à tela certa.
class InformacoesServicoProfissionalPage extends StatefulWidget {
  const InformacoesServicoProfissionalPage({
    super.key,
    required this.idServico,
  });

  final int idServico;

  @override
  State<InformacoesServicoProfissionalPage> createState() =>
      _InformacoesServicoProfissionalPageState();
}

enum _FiltroAvaliacao { todas, comFoto, comComentario }

class _InformacoesServicoProfissionalPageState
    extends State<InformacoesServicoProfissionalPage> {
  static const _azul = Color(0xFF0FB3FF);
  static const _azulEscuro = Color(0xFF0A6E9D);
  static const _texto = Color(0xFF111827);
  static const _sec = Color(0xFF6B7280);
  static const _estrela = Color(0xFFF59E0B);

  bool _carregando = true;
  bool _mudou = false;
  DetalheServicoPublico? _detalhe;
  ContaProfissionalAtiva? _conta;
  List<String> _metodos = const [];
  List<String> _pagamentos = const [];
  List<AvaliacaoCliente>? _avaliacoes;

  final _busca = TextEditingController();
  int? _filtroNota;
  _FiltroAvaliacao _filtro = _FiltroAvaliacao.todas;
  String _ordem = 'recentes';

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
    final resultados = await Future.wait<Object?>([
      // O profissional vê também o serviço DESATIVADO (para reativar).
      ServicosProfissionalService.buscarDetalhePublico(
        widget.idServico,
        incluirDesativado: true,
      ),
      ContaProfissionalAtiva.carregar(),
    ]);
    final detalhe = resultados[0] as DetalheServicoPublico?;
    final conta = resultados[1] as ContaProfissionalAtiva?;
    if (!mounted) return;
    setState(() {
      _detalhe = detalhe;
      _conta = conta;
      _carregando = false;
    });
    if (detalhe == null) return;
    _carregarConta(detalhe.servico);
    _carregarAvaliacoes();
  }

  /// Métodos de realização e formas de pagamento são da conta que oferece o
  /// serviço (igual à tela_servico).
  Future<void> _carregarConta(ServicoProfissional s) async {
    final loja = s.fkGrupoEmpresa != null;
    final campoEntrega = loja ? 'metodo_entrega_empresa' : 'metodo_entrega';
    final metodos = <String>[];
    var pagamentos = <String>[];
    try {
      final conta = await Supabase.instance.client
          .from(loja ? 'grupo_empresa' : 'dados_profissionais')
          .select('$campoEntrega, pagamento_aceito')
          .eq(
            loja ? 'id_grupo_empresa' : 'id_profissional',
            s.fkGrupoEmpresa ?? s.fkProfissional,
          )
          .maybeSingle();
      final m = conta?[campoEntrega];
      for (final x in m is List ? m : (m?.toString() ?? '').split(',')) {
        final t = x.toString().trim();
        if (t.isNotEmpty && !metodos.contains(t)) metodos.add(t);
      }
      pagamentos = formasDePagamento(conta?['pagamento_aceito']);
    } catch (_) {}
    if (metodos.isEmpty && s.tipoExecucao.isNotEmpty) {
      for (final m in s.tipoExecucao.split(',')) {
        if (m.trim().isNotEmpty) metodos.add(m.trim());
      }
    }
    if (mounted) {
      setState(() {
        _metodos = metodos;
        _pagamentos = pagamentos;
      });
    }
  }

  Future<void> _carregarAvaliacoes() async {
    try {
      final l = await AvaliacoesServicoService.doServico(widget.idServico);
      if (mounted) setState(() => _avaliacoes = l);
    } catch (e) {
      debugPrint('[info serviço] avaliações: $e');
      if (mounted) setState(() => _avaliacoes = const []);
    }
  }

  bool get _podeEditar => _conta?.podeEditar ?? false;

  // ── Edição ──────────────────────────────────────────────────────────────

  Future<void> _editarServico() async {
    final s = _detalhe?.servico;
    if (s == null) return;
    final mudou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdicionarServicoProfissionalPage(
          servicoParaEditar: s,
          associacaoEmpresaInicial: s.fkGrupoEmpresa != null,
          forcarContaAtiva: true,
        ),
      ),
    );
    if (mudou == true) {
      _mudou = true;
      setState(() => _carregando = true);
      await _carregar();
    }
  }

  Future<void> _abrirEditar(Widget pagina) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));
    final s = _detalhe?.servico;
    if (s != null) _carregarConta(s);
  }

  Widget _botaoEditar(VoidCallback aoTocar, {bool claro = false}) {
    if (!_podeEditar) return const SizedBox.shrink();
    return Material(
      color: claro ? Colors.white : _azul.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      elevation: claro ? 2 : 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          aoTocar();
        },
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.edit_rounded, size: 17, color: _azul),
        ),
      ),
    );
  }

  Widget _tituloSecao(String titulo, {VoidCallback? editar}) => Row(
    children: [
      Expanded(
        child: Text(
          titulo,
          style: const TextStyle(
            color: _texto,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (editar != null) _botaoEditar(editar),
    ],
  );

  // ── Seções (visão do cliente) ──────────────────────────────────────────

  Widget _cabecalho(String titulo) => CorOriginal(interface: true, child: Container(
    color: _azul,
    child: SafeArea(
      bottom: false,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context, _mudou),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            Expanded(
              child: Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            BotaoAjuda(
              cor: Colors.white,
              passos: () => explicacaoDaTela(
                context,
                tela: 'É assim que o cliente vê o seu serviço.',
                conteudo: [
                  'Use os lápis para editar cada parte. Lá embaixo ficam as avaliações, com busca e filtros.',
                ],
              ),
            ),
            if (_podeEditar)
              IconButton(
                tooltip: 'Editar serviço',
                onPressed: _editarServico,
                icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
              ),
          ],
        ),
      ),
    ),
  ));

  Widget _avisoVisaoCliente() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    color: const Color(0xFFE0F2FE),
    child: Row(
      children: [
        const Icon(Icons.visibility_outlined, size: 17, color: _azulEscuro),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _podeEditar
                ? 'É assim que o cliente vê este serviço. Toque no lápis '
                      'para editar.'
                : 'É assim que o cliente vê este serviço.',
            style: const TextStyle(
              color: _azulEscuro,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _imagem(ServicoProfissional s) {
    final url = s.imagemUrl?.trim() ?? '';
    return SizedBox(
      height: 250,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          url.startsWith('http')
              ? ImagemApp(child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _semImagem(),
                ))
              : _semImagem(),
          if (_podeEditar)
            Positioned(
              top: 12,
              right: 12,
              child: _botaoEditar(_editarServico, claro: true),
            ),
        ],
      ),
    );
  }

  Widget _semImagem() => Container(
    color: const Color(0xFFEAF4FB),
    child: const Center(
      child: Icon(
        Icons.home_repair_service_rounded,
        color: _azulEscuro,
        size: 56,
      ),
    ),
  );

  Widget _tag(String texto, Color base, {bool contorno = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: CorOficio.corFundo(base),
      borderRadius: BorderRadius.circular(6),
      border: contorno ? Border.all(color: base, width: 1.2) : null,
    ),
    child: Text(
      texto,
      style: TextStyle(
        color: CorOficio.corTexto(base),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _precoETags(DetalheServicoPublico d) {
    final s = d.servico;
    final tagEmpresa = d.tagEmpresa?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.titulo.trim().isEmpty ? 'Serviço' : s.titulo.trim(),
                style: const TextStyle(
                  color: _texto,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _botaoEditar(_editarServico),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          s.valor > 0 ? realPedido(s.valor) : 'Sob consulta',
          style: const TextStyle(
            color: Color(0xFF0B4F7C),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (s.funcao?.trim().isNotEmpty == true)
              _tag(s.funcao!.trim(), CorOficio.parse(s.cor)),
            if (d.ehLoja && tagEmpresa.isNotEmpty)
              _tag(
                tagEmpresa.startsWith('#') ? tagEmpresa : '#$tagEmpresa',
                CorOficio.parse(d.corTagEmpresa),
                contorno: true,
              ),
            _tag(s.cargaServico, const Color(0xFF64748B)),
          ],
        ),
      ],
    );
  }

  IconData _iconeMetodo(String m) {
    final t = m.toLowerCase();
    if (t.contains('leva')) return Icons.local_shipping_outlined;
    if (t.contains('retirad')) return Icons.storefront_outlined;
    if (t.contains('receba')) return Icons.home_outlined;
    if (t.contains('domic')) return Icons.home_repair_service_outlined;
    return Icons.handyman_outlined;
  }

  Widget _cartao({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFEDEFF2)),
    ),
    child: child,
  );

  Widget _metodosEPagamentos() => Column(
    children: [
      _cartao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSecao(
              'Métodos de realização',
              editar: () => _abrirEditar(const MetodoEntregaProfissionalPage()),
            ),
            const SizedBox(height: 8),
            if (_metodos.isEmpty)
              const Text(
                'A combinar com o profissional',
                style: TextStyle(color: _sec, fontSize: 13),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in _metodos)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_iconeMetodo(m), size: 15, color: _azul),
                          const SizedBox(width: 5),
                          Text(
                            m,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _cartao(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloSecao(
              'Formas de pagamento',
              editar: () =>
                  _abrirEditar(const MeusDadosFinanceirosProfissionalPage()),
            ),
            const SizedBox(height: 8),
            ChipsPagamento(formas: _pagamentos),
          ],
        ),
      ),
    ],
  );

  Widget _detalhes(ServicoProfissional s) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _tituloSecao('Detalhes do Serviço', editar: _editarServico),
      const SizedBox(height: 6),
      Text(
        s.descricao.trim().isNotEmpty
            ? s.descricao.trim()
            : 'Você ainda não escreveu detalhes sobre este serviço.',
        style: const TextStyle(
          fontSize: 15,
          height: 1.5,
          color: Color(0xFF334155),
        ),
      ),
    ],
  );

  // ── Avaliações ─────────────────────────────────────────────────────────

  List<AvaliacaoCliente> get _avaliacoesFiltradas {
    final termo = _busca.text.trim().toLowerCase();
    final l = [
      for (final a in _avaliacoes ?? const <AvaliacaoCliente>[])
        if ((_filtroNota == null || a.nota == _filtroNota) &&
            (_filtro != _FiltroAvaliacao.comFoto || a.midias.isNotEmpty) &&
            (_filtro != _FiltroAvaliacao.comComentario ||
                a.comentario.isNotEmpty) &&
            (termo.isEmpty ||
                a.comentario.toLowerCase().contains(termo) ||
                a.autor.toLowerCase().contains(termo)))
          a,
    ];
    final antiga = DateTime(1970);
    l.sort(
      (a, b) => switch (_ordem) {
        'antigas' => (a.data ?? antiga).compareTo(b.data ?? antiga),
        'maior' => b.nota.compareTo(a.nota),
        'menor' => a.nota.compareTo(b.nota),
        _ => (b.data ?? antiga).compareTo(a.data ?? antiga),
      },
    );
    return l;
  }

  Widget _resumoAvaliacoes(List<AvaliacaoCliente> todas) {
    final media = todas.isEmpty
        ? 0.0
        : todas.map((a) => a.nota).reduce((x, y) => x + y) / todas.length;
    final porNota = {
      for (var n = 1; n <= 5; n++) n: todas.where((a) => a.nota == n).length,
    };
    return _cartao(
      child: Row(
        children: [
          Column(
            children: [
              Text(
                todas.isEmpty ? '–' : media.toStringAsFixed(1),
                style: const TextStyle(
                  color: _texto,
                  fontSize: 36,
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
                      size: 15,
                      color: _estrela,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${todas.length} '
                '${todas.length == 1 ? 'avaliação' : 'avaliações'}',
                style: const TextStyle(color: _sec, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (var n = 5; n >= 1; n--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: Text(
                            '$n',
                            style: const TextStyle(
                              color: _sec,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: _estrela,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: todas.isEmpty
                                  ? 0
                                  : porNota[n]! / todas.length,
                              minHeight: 7,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: const AlwaysStoppedAnimation(
                                _estrela,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 22,
                          child: Text(
                            '${porNota[n]}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: _sec, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String rotulo,
    bool ativo,
    VoidCallback aoTocar, {
    IconData? icone,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onTap: aoTocar,
      child: CorOriginal(interface: true, ativo: ativo, child: AnimatedContainer(
        duration: duracao(const Duration(milliseconds: 160)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: ativo ? _azul : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ativo ? _azul : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 14, color: ativo ? Colors.white : _estrela),
              const SizedBox(width: 4),
            ],
            Text(
              rotulo,
              style: TextStyle(
                color: ativo ? Colors.white : const Color(0xFF334155),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      )),
    ),
  );

  Widget _buscaEFiltros() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: TextField(
                controller: _busca,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Buscar nos comentários ou cliente',
                  hintStyle: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13.5,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: _sec),
                  suffixIcon: _busca.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(_busca.clear),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
              PopupMenuItem(value: 'recentes', child: Text('Mais recentes')),
              PopupMenuItem(value: 'antigas', child: Text('Mais antigas')),
              PopupMenuItem(value: 'maior', child: Text('Maior nota')),
              PopupMenuItem(value: 'menor', child: Text('Menor nota')),
            ],
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(Icons.sort_rounded, color: _azul),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _chip(
              'Todas',
              _filtroNota == null && _filtro == _FiltroAvaliacao.todas,
              () => setState(() {
                _filtroNota = null;
                _filtro = _FiltroAvaliacao.todas;
              }),
            ),
            _chip(
              'Com fotos',
              _filtro == _FiltroAvaliacao.comFoto,
              () => setState(
                () => _filtro = _filtro == _FiltroAvaliacao.comFoto
                    ? _FiltroAvaliacao.todas
                    : _FiltroAvaliacao.comFoto,
              ),
            ),
            _chip(
              'Com comentário',
              _filtro == _FiltroAvaliacao.comComentario,
              () => setState(
                () => _filtro = _filtro == _FiltroAvaliacao.comComentario
                    ? _FiltroAvaliacao.todas
                    : _FiltroAvaliacao.comComentario,
              ),
            ),
            for (var n = 5; n >= 1; n--)
              _chip(
                '$n',
                _filtroNota == n,
                () => setState(() => _filtroNota = _filtroNota == n ? null : n),
                icone: Icons.star_rounded,
              ),
          ],
        ),
      ),
    ],
  );

  bool _video(String u) {
    final x = u.toLowerCase().split('?').first;
    return ['.mp4', '.mov', '.m4v', '.3gp', '.webm'].any(x.endsWith);
  }

  void _abrirMidia(String url) {
    if (_video(url)) {
      abrirVideo(context, url);
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

  Widget _itemAvaliacao(AvaliacaoCliente a) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFEDEFF2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CorOriginal(child: CircleAvatar(
              radius: 20,
              backgroundColor: _azul,
              backgroundImage: a.foto != null ? NetworkImage(a.foto!) : null,
              child: a.foto == null
                  ? Text(
                      obterIniciais(a.autor),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            )),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.autor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _texto,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Icon(
                          i < a.nota
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 15,
                          color: _estrela,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (a.data != null)
              Text(
                dataPedido(a.data!),
                style: const TextStyle(color: _sec, fontSize: 12),
              ),
          ],
        ),
        if (a.comentario.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            a.comentario,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
        if (a.midias.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: a.midias.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = a.midias[i];
                return InkWell(
                  onTap: () => _abrirMidia(m),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: _video(m)
                          ? Container(
                              color: const Color(0xFF1F2937),
                              child: const Icon(
                                Icons.play_circle_outline_rounded,
                                color: Colors.white,
                              ),
                            )
                          : ImagemApp(child: Image.network(
                              m,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFFE5E7EB),
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: _sec,
                                ),
                              ),
                            )),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    ),
  );

  Widget _secaoAvaliacoes() {
    final todas = _avaliacoes;
    if (todas == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloSecao('Avaliações'),
          const SizedBox(height: 12),
          const SkeletonBox(height: 120, borderRadius: 16),
          const SizedBox(height: 12),
          const SkeletonBox(height: 110, borderRadius: 16),
        ],
      );
    }
    final lista = _avaliacoesFiltradas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSecao('Avaliações dos clientes'),
        const SizedBox(height: 12),
        _resumoAvaliacoes(todas),
        if (todas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(
              child: Text(
                'Este serviço ainda não recebeu avaliações.',
                style: TextStyle(color: _sec),
              ),
            ),
          )
        else ...[
          const SizedBox(height: 14),
          _buscaEFiltros(),
          const SizedBox(height: 14),
          if (lista.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'Nenhuma avaliação com esses filtros.',
                  style: TextStyle(color: _sec),
                ),
              ),
            )
          else
            for (final a in lista) _itemAvaliacao(a),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _detalhe;
    final conta = _conta;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _mudou);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: _carregando
              ? const SkeletonServiceDetail()
              : d == null
              ? Column(
                  children: [
                    _cabecalho('Serviço'),
                    Expanded(
                      child: listaVaziaPerfil(
                        Icons.search_off_rounded,
                        'Serviço não encontrado',
                        'Ele pode ter sido removido ou desativado.',
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _cabecalho(
                      d.servico.titulo.trim().isEmpty
                          ? 'Serviço'
                          : d.servico.titulo.trim(),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        color: _azul,
                        onRefresh: _carregar,
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            if (d.servico.desativado)
                              FaixaServicoDesativado(
                                aoReativar: () async {
                                  if (await reativarServico(
                                    context,
                                    d.servico,
                                  )) {
                                    _mudou = true;
                                    await _carregar();
                                  }
                                },
                              ),
                            _avisoVisaoCliente(),
                            _imagem(d.servico),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                32,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _precoETags(d),
                                  const SizedBox(height: 16),
                                  if (conta != null) ...[
                                    SeloContaAtiva(
                                      conta: conta,
                                      texto: 'Oferecido por esta conta',
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  _metodosEPagamentos(),
                                  const SizedBox(height: 22),
                                  _detalhes(d.servico),
                                  const SizedBox(height: 26),
                                  _secaoAvaliacoes(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
