import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/notificacoes/notificacao_app.dart';
import 'services/notificacoes/notificacao_destinos.dart';
import 'services/notificacoes/notificacao_repositorio.dart';
import 'services/notificacoes/notificacao_service.dart';
import 'services/notificacoes/notificacao_tipos.dart';
import 'widgets/skeletons_telas.dart';

enum _Filtro { todas, novas, vistas, conta, pedidos, mensagens, radar }

extension on _Filtro {
  String get rotulo => switch (this) {
    _Filtro.todas => 'Todas',
    _Filtro.novas => 'Novas',
    _Filtro.vistas => 'Vistas',
    _Filtro.conta => 'ConsertaJá',
    _Filtro.pedidos => 'Pedidos',
    _Filtro.mensagens => 'Mensagens',
    _Filtro.radar => 'Radar',
  };

  bool aceita(NotificacaoApp n) => switch (this) {
    _Filtro.todas => true,
    _Filtro.novas => !n.aberta,
    _Filtro.vistas => n.aberta,
    _Filtro.conta =>
      n.tipo == TipoNotificacao.sistema || n.tipo == TipoNotificacao.global,
    _Filtro.pedidos => n.tipo == TipoNotificacao.solicitacao,
    _Filtro.mensagens => n.tipo == TipoNotificacao.conversa,
    _Filtro.radar => n.tipo.ehRadar,
  };
}

/// Central de notificações (cliente e profissional). Lê `notificacoes` do
/// Supabase e atualiza sozinha pelo Realtime.
class MinhasNotificacoesPage extends StatefulWidget {
  const MinhasNotificacoesPage({
    super.key,
    this.totalConvites = 0,
    this.aoAbrirConvites,
  });

  /// Profissional: convites de empresa pendentes (aparecem num card no topo).
  final int totalConvites;
  final VoidCallback? aoAbrirConvites;

  @override
  State<MinhasNotificacoesPage> createState() => _MinhasNotificacoesPageState();
}

class _MinhasNotificacoesPageState extends State<MinhasNotificacoesPage> {
  static const Color _azul = kAzulNotificacao;
  static const Color _fundo = Color(0xFFF9F8F6);
  static const Color _texto = Color(0xFF1D2430);
  static const Color _textoSec = Color(0xFF6B7280);
  static const Color _naoLidaFundo = Color(0xFFE0F2FC);
  static const Color _divisor = Color(0xFFE5E7EB);

  final TextEditingController _busca = TextEditingController();
  StreamSubscription<void>? _sub;
  Timer? _debounce;

  List<NotificacaoApp> _todas = [];
  _Filtro _filtro = _Filtro.todas;
  bool _carregando = true;
  bool _buscando = false;
  String? _erro;

  /// Modo seleção (botão "Selecionar" ou segurar uma notificação): mostra uma
  /// barra fixa embaixo com "Marcar como lida" e "Excluir".
  bool _modoSelecao = false;
  final Set<int> _selecionadas = {};

  @override
  void initState() {
    super.initState();
    _carregar();
    // Realtime: nova notificação / abertura em outro aparelho.
    _sub = NotificacaoService.instance.alteracoes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), _carregar);
    });
    _busca.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final lista = await NotificacaoRepositorio.listar();
      if (!mounted) return;
      setState(() {
        _todas = lista;
        _carregando = false;
        _erro = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = 'Não foi possível carregar as notificações.';
      });
    }
  }

  List<NotificacaoApp> get _visiveis {
    final termo = _busca.text.trim().toLowerCase();
    return _todas.where((n) {
      if (!_filtro.aceita(n)) return false;
      if (termo.isEmpty) return true;
      return n.titulo.toLowerCase().contains(termo) ||
          n.conteudo.toLowerCase().contains(termo);
    }).toList();
  }

  int get _naoLidas => _todas.where((n) => !n.aberta).length;

  // ── Ações ────────────────────────────────────────────────────────────────

  void _marcarLocalAberta(int id) {
    setState(() {
      _todas = [for (final n in _todas) n.id == id ? n.copiarAberta() : n];
    });
  }

  Future<void> _abrir(NotificacaoApp n) async {
    HapticFeedback.selectionClick();
    if (n.id != null && !n.aberta) {
      _marcarLocalAberta(n.id!);
      unawaited(NotificacaoService.instance.marcarAberta(n.id!));
    }
    final tela = NotificacaoDestinos.telaDe(n);
    if (tela == null || tela is MinhasNotificacoesPage) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela));
    if (mounted) _carregar();
  }

  Future<void> _marcarComoLida(NotificacaoApp n) async {
    if (n.id == null || n.aberta) return;
    _marcarLocalAberta(n.id!);
    await NotificacaoService.instance.marcarAberta(n.id!);
  }

  Future<void> _marcarTodas() async {
    if (_naoLidas == 0) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _todas = [for (final n in _todas) n.aberta ? n : n.copiarAberta()];
    });
    await NotificacaoService.instance.marcarTodasAbertas();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todas as notificações foram marcadas como lidas.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _excluir(NotificacaoApp n) async {
    if (n.id == null) return;
    final antes = _todas;
    setState(() => _todas = _todas.where((x) => x.id != n.id).toList());
    try {
      await NotificacaoRepositorio.excluir(n.id!);
      await NotificacaoService.instance.atualizarContadores();
    } catch (_) {
      if (mounted) setState(() => _todas = antes);
    }
  }

  // ── Seleção ──────────────────────────────────────────────────────────────

  void _entrarSelecao([NotificacaoApp? n]) {
    HapticFeedback.selectionClick();
    setState(() {
      _modoSelecao = true;
      if (n?.id != null) _selecionadas.add(n!.id!);
    });
  }

  void _sairSelecao() => setState(() {
    _modoSelecao = false;
    _selecionadas.clear();
  });

  void _alternar(NotificacaoApp n) {
    if (n.id == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selecionadas.remove(n.id)) _selecionadas.add(n.id!);
    });
  }

  void _selecionarTodas() {
    final ids = _visiveis.map((n) => n.id).whereType<int>().toSet();
    setState(() {
      if (_selecionadas.containsAll(ids)) {
        _selecionadas.clear();
      } else {
        _selecionadas.addAll(ids);
      }
    });
  }

  Future<void> _marcarSelecionadasLidas() async {
    final ids = _todas
        .where((n) => n.id != null && _selecionadas.contains(n.id) && !n.aberta)
        .map((n) => n.id!)
        .toList();
    setState(() {
      _todas = [
        for (final n in _todas)
          _selecionadas.contains(n.id) ? n.copiarAberta() : n,
      ];
      _modoSelecao = false;
      _selecionadas.clear();
    });
    try {
      await NotificacaoRepositorio.marcarAbertas(ids);
      await NotificacaoService.instance.atualizarContadores();
    } catch (_) {
      if (mounted) _carregar();
    }
  }

  Future<void> _excluirSelecionadas() async {
    final ids = _selecionadas.toList();
    if (ids.isEmpty) return;
    final antes = _todas;
    setState(() {
      _todas = _todas.where((n) => !_selecionadas.contains(n.id)).toList();
      _modoSelecao = false;
      _selecionadas.clear();
    });
    try {
      await NotificacaoRepositorio.excluirVarias(ids);
      await NotificacaoService.instance.atualizarContadores();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ids.length == 1
                ? 'Notificação excluída.'
                : '${ids.length} notificações excluídas.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _todas = antes);
    }
  }

  /// Barra fixa embaixo no modo seleção (a lista continua rolando).
  Widget _barraSelecao() {
    final qtd = _selecionadas.length;
    final temNaoLida = _todas.any(
      (n) => _selecionadas.contains(n.id) && !n.aberta,
    );
    Widget acao({
      required IconData icone,
      required String texto,
      required Color cor,
      required VoidCallback? aoTocar,
    }) {
      final ativo = aoTocar != null;
      return Expanded(
        child: Material(
          color: ativo ? cor : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: aoTocar,
            child: SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icone,
                    size: 20,
                    color: ativo ? Colors.white : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    texto,
                    style: TextStyle(
                      color: ativo ? Colors.white : const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedSlide(
      offset: _modoSelecao ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              acao(
                icone: Icons.visibility_outlined,
                texto: 'Marcar como lida',
                cor: _azul,
                aoTocar: qtd > 0 && temNaoLida
                    ? _marcarSelecionadasLidas
                    : null,
              ),
              const SizedBox(width: 10),
              acao(
                icone: Icons.delete_outline_rounded,
                texto: 'Excluir',
                cor: const Color(0xFFDC2626),
                aoTocar: qtd > 0 ? _excluirSelecionadas : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _menuFiltros() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _alca()),
              const SizedBox(height: 14),
              const Text(
                'Mostrar',
                style: TextStyle(
                  color: _texto,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in _Filtro.values)
                    _chip(
                      f,
                      aoTocar: () {
                        Navigator.pop(ctx);
                        setState(() => _filtro = f);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: _divisor),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: _naoLidas > 0,
                leading: const Icon(Icons.done_all_rounded, color: _azul),
                title: Text(
                  _naoLidas > 0
                      ? 'Marcar todas como lidas ($_naoLidas)'
                      : 'Nenhuma notificação nova',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _marcarTodas();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: !_modoSelecao,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _modoSelecao) _sairSelecao();
        },
        child: Scaffold(
          backgroundColor: _fundo,
          bottomNavigationBar: _modoSelecao ? _barraSelecao() : null,
          body: Column(
            children: [
              _barraVoltar(),
              _cabecalho(),
              _chipsFiltro(),
              const SizedBox(height: 6),
              Expanded(child: _corpo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraVoltar() {
    return Container(
      color: _azul,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: _modoSelecao
              ? Row(
                  children: [
                    IconButton(
                      tooltip: 'Cancelar seleção',
                      onPressed: _sairSelecao,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _selecionadas.isEmpty
                            ? 'Selecione notificações'
                            : _selecionadas.length == 1
                            ? '1 selecionada'
                            : '${_selecionadas.length} selecionadas',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _selecionarTodas,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.select_all_rounded, size: 20),
                      label: const Text(
                        'Todas',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                )
              : Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 24),
                      label: const Text(
                        'Voltar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_naoLidas > 0)
                      TextButton.icon(
                        onPressed: _marcarTodas,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        label: const Text(
                          'Ler todas',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(width: 6),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _cabecalho() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 10),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _buscando
            ? Row(
                key: const ValueKey('busca'),
                children: [
                  Expanded(
                    child: TextField(
                      controller: _busca,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        hintText: 'Buscar notificações',
                        prefixIcon: const Icon(Icons.search, color: _textoSec),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _divisor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _divisor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _azul),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar busca',
                    onPressed: () => setState(() {
                      _buscando = false;
                      _busca.clear();
                    }),
                    icon: const Icon(Icons.close_rounded, color: _texto),
                  ),
                ],
              )
            : Row(
                key: const ValueKey('titulo'),
                children: [
                  const Expanded(
                    child: Text(
                      'Notificações',
                      style: TextStyle(
                        color: _texto,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Buscar',
                    onPressed: () => setState(() => _buscando = true),
                    icon: const Icon(Icons.search, color: _texto, size: 26),
                  ),
                  IconButton(
                    tooltip: 'Selecionar',
                    onPressed: _todas.isEmpty ? null : () => _entrarSelecao(),
                    icon: const Icon(
                      Icons.checklist_rounded,
                      color: _texto,
                      size: 26,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Filtros e opções',
                    onPressed: _menuFiltros,
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: _texto,
                      size: 26,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _chipsFiltro() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _Filtro.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _chip(_Filtro.values[i]),
      ),
    );
  }

  Widget _chip(_Filtro f, {VoidCallback? aoTocar}) {
    final ativo = _filtro == f;
    final novas = f == _Filtro.novas ? _naoLidas : 0;
    return Material(
      color: ativo ? const Color(0xFFE0F2FC) : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: ativo ? _azul : const Color(0xFFD1D5DB),
          width: ativo ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: aoTocar ?? () => setState(() => _filtro = f),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                f.rotulo,
                style: TextStyle(
                  color: ativo ? _azul : const Color(0xFF374151),
                  fontSize: 14.5,
                  fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (novas > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: _azul,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$novas',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const SkeletonNotificacoes();
    }
    final lista = _visiveis;
    final naoLidas = lista.where((n) => !n.aberta).toList();
    final lidas = lista.where((n) => n.aberta).toList();

    return RefreshIndicator(
      color: _azul,
      onRefresh: _carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (widget.totalConvites > 0 && widget.aoAbrirConvites != null)
            _cardConvites(),
          if (_erro != null)
            _vazio(Icons.cloud_off_rounded, _erro!)
          else if (lista.isEmpty)
            _vazio(
              Icons.notifications_off_outlined,
              _busca.text.trim().isNotEmpty
                  ? 'Nenhuma notificação encontrada.'
                  : 'Você não tem notificações aqui ainda.',
            )
          else ...[
            if (naoLidas.isNotEmpty) ...[
              _secao('Não lidas', naoLidas.length),
              for (final n in naoLidas) _item(n),
            ],
            if (lidas.isNotEmpty) ...[
              _secao(naoLidas.isEmpty ? 'Notificações' : 'Anteriores', null),
              for (final n in lidas) _item(n),
            ],
          ],
        ],
      ),
    );
  }

  Widget _cardConvites() {
    final n = widget.totalConvites;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.aoAbrirConvites,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _azul.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                _iconeTipo(Icons.mail_outline_rounded, _azul),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    n == 1
                        ? 'Você tem 1 convite de empresa'
                        : 'Você tem $n convites de empresa',
                    style: const TextStyle(
                      color: _texto,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _textoSec),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _secao(String titulo, int? quantidade) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Text(
            titulo.toUpperCase(),
            style: const TextStyle(
              color: _textoSec,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          if (quantidade != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _azul,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$quantidade',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _item(NotificacaoApp n) {
    final naoLida = !n.aberta;
    final visual = n.visualStatus;
    final cor = visual?.cor ?? n.tipo.cor;

    final selecionada = _selecionadas.contains(n.id);
    final conteudo = InkWell(
      onTap: () => _modoSelecao ? _alternar(n) : _abrir(n),
      onLongPress: () => _modoSelecao ? _alternar(n) : _entrarSelecao(n),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        color: selecionada
            ? const Color(0xFFCDEBFB)
            : naoLida
            ? _naoLidaFundo
            : Colors.transparent,
        padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seleção (caixinha) ou bolinha azul = não lida.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: _modoSelecao
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(8, 15, 10, 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: selecionada ? _azul : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selecionada
                                ? _azul
                                : const Color(0xFFB8C2CC),
                            width: 2,
                          ),
                        ),
                        child: selecionada
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            SizedBox(
              width: 12,
              child: naoLida && !_modoSelecao
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: _azul,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            _avatar(n, cor, visual),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.titulo,
                    style: TextStyle(
                      color: _texto,
                      fontSize: 15.5,
                      fontWeight: naoLida ? FontWeight.w800 : FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  if (n.conteudo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      n.conteudo,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        _data(n.dataCriacao),
                        style: const TextStyle(color: _textoSec, fontSize: 13),
                      ),
                      _pilula(
                        n.textoStatus != null &&
                                (n.tipo == TipoNotificacao.solicitacao ||
                                    n.tipo.ehRadar)
                            ? n.textoStatus!
                            : n.tipo.rotulo,
                        cor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        Dismissible(
          key: ValueKey('notif_${n.id}'),
          direction: _modoSelecao
              ? DismissDirection.none
              : naoLida
              ? DismissDirection.horizontal
              : DismissDirection.endToStart,
          // Arrastar para a direita = marcar como lida (o item fica).
          background: Container(
            color: _azul,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.done_all_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Marcar como lida',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Arrastar para a esquerda = excluir.
          secondaryBackground: Container(
            color: const Color(0xFFDC2626),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
          ),
          confirmDismiss: (direcao) async {
            if (direcao == DismissDirection.startToEnd) {
              await _marcarComoLida(n);
              return false;
            }
            return true;
          },
          onDismissed: (_) => _excluir(n),
          child: conteudo,
        ),
        const Divider(height: 1, thickness: 1, color: _divisor),
      ],
    );
  }

  /// Foto (cliente/remetente) com selo do tipo, ou o ícone do tipo/status.
  Widget _avatar(NotificacaoApp n, Color cor, VisualStatus? visual) {
    final icone = visual?.icone ?? n.tipo.icone;
    final url = n.imagemUrl ?? n.dados['foto_remetente']?.toString();
    // Mensagem: a foto de quem mandou (ou a inicial do nome), sem ícone.
    if (n.tipo == TipoNotificacao.conversa) {
      final nome = (n.dados['nome_remetente']?.toString() ?? n.titulo).trim();
      final inicial = Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: _azul, shape: BoxShape.circle),
        child: Text(
          nome.isEmpty ? '?' : nome.characters.first.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      if (url == null || url.isEmpty || url == 'null') return inicial;
      return ClipOval(
        child: Image.network(
          url,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => inicial,
        ),
      );
    }
    if (url == null || url.isEmpty || url == 'null') {
      return _iconeTipo(icone, cor);
    }
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: Image.network(
              url,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _iconeTipo(icone, cor),
            ),
          ),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(icone, color: Colors.white, size: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconeTipo(IconData icone, Color cor) {
    return Container(
      width: 54,
      height: 54,
      // Cor sólida, sem degradê nem sombra.
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icone, color: Colors.white, size: 28),
    );
  }

  Widget _pilula(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: Color.lerp(cor, Colors.black, 0.15),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _vazio(IconData icone, String texto) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2FC),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: _azul, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textoSec, fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _alca() => Container(
    width: 44,
    height: 5,
    decoration: BoxDecoration(
      color: const Color(0xFFD5DCE4),
      borderRadius: BorderRadius.circular(4),
    ),
  );

  String _data(DateTime d) {
    String dois(int v) => v.toString().padLeft(2, '0');
    final hora = '${dois(d.hour)}:${dois(d.minute)}';
    final agora = DateTime.now();
    final diff = agora.difference(d);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = DateTime(d.year, d.month, d.day);
    if (dia == hoje) return 'Hoje, $hora';
    if (dia == hoje.subtract(const Duration(days: 1))) return 'Ontem, $hora';
    return '${dois(d.day)}/${dois(d.month)}/${d.year} $hora';
  }
}
