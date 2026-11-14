import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'gestao_equipe.dart';
import 'meus_servicos_solicitados.dart';
import 'services/solicitacao_geografica_service.dart';
import 'tela_home_profissional.dart';
import 'tela_mensagens.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/app_navigation_util.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'utils/icone_oficio.dart';
import 'utils/iniciais.dart';

/// Mesmo filtro preto e branco dos outros mapas do app.
const List<double> _matrizMapaCinza = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Aba "Radar" do profissional: mostra onde ele está e as solicitações
/// geográficas abertas na área dele (com a função dele).
class SolicitacaoGeograficaProfissionalPage extends StatefulWidget {
  const SolicitacaoGeograficaProfissionalPage({
    super.key,
    this.isVisitante = false,
  });

  final bool isVisitante;

  @override
  State<SolicitacaoGeograficaProfissionalPage> createState() =>
      _SolicitacaoGeograficaProfissionalPageState();
}

class _SolicitacaoGeograficaProfissionalPageState
    extends State<SolicitacaoGeograficaProfissionalPage> {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _azulSelecionado = Color(0xFF1E5AA8);
  static const Color _texto = Color(0xFF1D2430);
  static const Color _textoSec = Color(0xFF6B7280);
  static const Color _borda = Color(0xFFE5E7EB);

  final MapController _mapa = MapController();
  final DraggableScrollableController _sheet = DraggableScrollableController();

  bool _mapaPronto = false;
  bool _carregando = true;
  String? _erro;
  LatLng? _posicao;
  List<SolicitacaoGeoProxima> _solicitacoes = [];
  int? _selecionada;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _carregar({bool atualizarPosicao = true}) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      if (atualizarPosicao || _posicao == null) {
        final pos = await SolicitacaoGeograficaService.localizacaoAtual();
        if (!mounted) return;
        setState(() => _posicao = pos);
        _centralizar(pos, zoom: 14);
      }
      final lista = await SolicitacaoGeograficaService.solicitacoesProximas(
        _posicao!,
      );
      if (!mounted) return;
      setState(() {
        _solicitacoes = lista;
        if (!lista.any((s) => s.id == _selecionada)) _selecionada = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _centralizar(LatLng ponto, {double? zoom}) {
    if (!_mapaPronto) return;
    _mapa.move(ponto, zoom ?? _mapa.camera.zoom);
  }

  void _selecionar(SolicitacaoGeoProxima s, {bool doMapa = false}) {
    HapticFeedback.selectionClick();
    setState(() => _selecionada = s.id);
    // Leva o pedido um pouco acima do centro (o sheet cobre a parte de baixo).
    final deslocamento = 0.0035 * math.pow(2, 14 - _mapa.camera.zoom);
    _centralizar(
      LatLng(s.posicao.latitude - deslocamento, s.posicao.longitude),
    );
    if (doMapa && _sheet.isAttached && _sheet.size < 0.4) {
      _sheet.animateTo(
        0.45,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Selecionada primeiro; o resto na ordem da RPC (mais recentes).
  List<SolicitacaoGeoProxima> get _ordenadas {
    final lista = [..._solicitacoes];
    final i = lista.indexWhere((s) => s.id == _selecionada);
    if (i > 0) lista.insert(0, lista.removeAt(i));
    return lista;
  }

  int get _novas => _solicitacoes.where((s) => s.nova).length;

  // ── Navegação (bottom nav) ────────────────────────────────────────────────

  void _onTapNav(int index) {
    switch (index) {
      case 0:
        AppNavigationUtil.navegarAba(
          context,
          TelaHomeProfissional(isVisitante: widget.isVisitante),
          isHome: true,
        );
      case 2:
        Navigator.of(context).push(
          AppNavigationUtil.rotaSemAnimacao(
            TelaMensagensPage(
              isVisitante: widget.isVisitante,
              isProfissional: true,
            ),
            nome: 'TelaMensagensPage',
          ),
        );
      case 3:
        Navigator.of(context).push(
          AppNavigationUtil.rotaSemAnimacao(
            const MeusServicosSolicitadosPage(),
            nome: 'MeusServicosSolicitadosPage',
          ),
        );
      case 4:
        if (BottomNavigationBarProfissional.leituraSincronaContaEmpresa()) {
          Navigator.of(context).push(
            AppNavigationUtil.rotaSemAnimacao(
              const GestaoEquipePage(),
              nome: 'GestaoEquipePage',
            ),
          );
        } else {
          AppNavigationUtil.navegarAba(
            context,
            TelaMeuPerfilProfissionalPage(isVisitante: widget.isVisitante),
            isHome: false,
          );
        }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: const Text(
            'Solicitação Geográfica',
            style: TextStyle(
              color: _azul,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: _azul),
              onSelected: (v) {
                if (v == 'atualizar') _carregar();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'atualizar', child: Text('Atualizar')),
              ],
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Positioned.fill(child: _buildMapa()),
              _buildBotaoLocalizacao(c.maxHeight),
              _buildSheet(),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBarProfissional(
          key: const ValueKey('bottomProfissional'),
          currentIndex: 1,
          onReselecionarAbaAtual: (_) => _carregar(),
          onTap: _onTapNav,
        ),
      ),
    );
  }

  // ── Mapa ──────────────────────────────────────────────────────────────────

  Widget _buildMapa() {
    final pos = _posicao;
    if (pos == null) {
      return Container(
        color: const Color(0xFFE5E7EB),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: _azul),
      );
    }
    return FlutterMap(
      mapController: _mapa,
      options: MapOptions(
        initialCenter: pos,
        initialZoom: 14,
        onMapReady: () {
          _mapaPronto = true;
          _centralizar(pos, zoom: 14);
        },
        onTap: (_, _) => setState(() => _selecionada = null),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(_matrizMapaCinza),
          child: TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'br.com.consertaja',
            maxNativeZoom: 19,
            maxZoom: 19,
          ),
        ),
        MarkerLayer(
          markers: [
            for (final s in _solicitacoes)
              if (s.id != _selecionada)
                Marker(
                  point: s.posicao,
                  width: 150,
                  height: 64,
                  alignment: Alignment.topCenter,
                  child: _marcadorPedido(s),
                ),
            Marker(
              point: pos,
              width: 140,
              height: 74,
              child: _marcadorProfissional(),
            ),
            // A selecionada por último: fica por cima das outras.
            for (final s in _solicitacoes)
              if (s.id == _selecionada)
                Marker(
                  point: s.posicao,
                  width: 230,
                  height: 74,
                  alignment: Alignment.topCenter,
                  child: _marcadorPedidoSelecionado(s),
                ),
          ],
        ),
      ],
    );
  }

  Widget _marcadorProfissional() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _azul,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: _azul.withValues(alpha: 0.45),
                blurRadius: 12,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Icon(Icons.sensors, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Sua posição atual',
            style: TextStyle(
              color: _texto,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Pin + etiqueta com função e número do pedido (como no design).
  Widget _marcadorPedido(SolicitacaoGeoProxima s) {
    return GestureDetector(
      onTap: () => _selecionar(s, doMapa: true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x29000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _azul,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: IconeOficio.imagemPorFuncao(s.funcao, tamanho: 15),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.funcao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _texto,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Pedido #${s.id}',
                        style: const TextStyle(color: _textoSec, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.location_on, color: _azul, size: 22),
        ],
      ),
    );
  }

  Widget _marcadorPedidoSelecionado(SolicitacaoGeoProxima s) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          decoration: BoxDecoration(
            color: _azulSelecionado,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pedido #${s.id}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${s.distanciaKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if ((s.enderecoCliente ?? '').isNotEmpty)
                      Text(
                        s.enderecoCliente!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.location_on, color: _azulSelecionado, size: 26),
      ],
    );
  }

  Widget _buildBotaoLocalizacao(double alturaDisponivel) {
    return AnimatedBuilder(
      animation: _sheet,
      builder: (context, child) {
        final fracao = _sheet.isAttached ? _sheet.size : 0.42;
        return Positioned(
          right: 14,
          bottom: alturaDisponivel * fracao + 14,
          child: child!,
        );
      },
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            final p = _posicao;
            if (p != null) _centralizar(p, zoom: 14);
            _carregar();
          },
          child: const SizedBox(
            width: 46,
            height: 46,
            child: Icon(Icons.my_location, color: _texto, size: 22),
          ),
        ),
      ),
    );
  }

  // ── Bottom sheet "Solicitações Próximas" ──────────────────────────────────

  Widget _buildSheet() {
    return DraggableScrollableSheet(
      controller: _sheet,
      initialChildSize: 0.42,
      minChildSize: 0.16,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.42],
      builder: (context, scroll) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFAFAFA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: CustomScrollView(
          controller: scroll,
          slivers: [
            SliverToBoxAdapter(child: _cabecalhoSheet()),
            ..._conteudoSheet(),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _cabecalhoSheet() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Solicitações Próximas',
                style: TextStyle(
                  color: _texto,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_novas > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _novas == 1 ? '1 Nova' : '$_novas Novas',
                    style: const TextStyle(
                      color: Color(0xFF0284C7),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _conteudoSheet() {
    if (_carregando && _solicitacoes.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: _azul)),
          ),
        ),
      ];
    }
    if (_erro != null) {
      return [SliverToBoxAdapter(child: _aviso(Icons.error_outline, _erro!))];
    }
    if (_solicitacoes.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _aviso(
            Icons.sensors,
            'Nenhuma solicitação na sua área por enquanto. Quando um '
            'cliente próximo pedir um serviço da sua área de atuação, ele '
            'aparece aqui.',
          ),
        ),
      ];
    }
    final lista = _ordenadas;
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverList.separated(
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _cardSolicitacao(lista[i]),
        ),
      ),
    ];
  }

  Widget _aviso(IconData icone, String texto) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borda),
        ),
        child: Column(
          children: [
            Icon(icone, color: _azul, size: 30),
            const SizedBox(height: 10),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textoSec, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardSolicitacao(SolicitacaoGeoProxima s) {
    final selecionada = s.id == _selecionada;
    return GestureDetector(
      onTap: () => _selecionar(s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selecionada ? _azul.withValues(alpha: 0.6) : _borda,
            width: selecionada ? 1.4 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _avatarCliente(s),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.nomeCliente,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _texto,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.directions_walk,
                                size: 13,
                                color: Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${s.distanciaKm.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  color: Color(0xFF0284C7),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.titulo,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (s.imagens.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _imagensSolicitacao(s.imagens),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      s.descricao,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                    if ((s.enderecoCliente ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: _textoSec,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              s.enderecoCliente!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textoSec,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: _borda),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        // Ainda sem ação: o fluxo de aceite vem depois.
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          backgroundColor: _azul,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 19),
                        label: const Text(
                          'Aceitar Serviço',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (s.nova)
                Positioned(
                  top: 0,
                  right: 0,
                  child: CustomPaint(
                    size: const Size(18, 18),
                    painter: _CantoNovo(cor: _azul),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarCliente(SolicitacaoGeoProxima s) {
    const tamanho = 46.0;
    final iniciais = Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _azul, shape: BoxShape.circle),
      child: Text(
        obterIniciais(s.nomeCliente),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
    final url = s.fotoCliente?.trim() ?? '';
    if (url.isEmpty) return iniciais;
    return ClipOval(
      child: Image.network(
        url,
        width: tamanho,
        height: tamanho,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => iniciais,
      ),
    );
  }

  /// Imagem(ns) anexadas pelo cliente, logo abaixo do título.
  Widget _imagensSolicitacao(List<String> imagens) {
    Widget imagem(String url) => Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFFF3F4F6),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, color: _textoSec),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: imagens.length == 1
            ? imagem(imagens.first)
            : Stack(
                children: [
                  PageView.builder(
                    itemCount: imagens.length,
                    itemBuilder: (_, i) => imagem(imagens[i]),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${imagens.length} fotos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Triângulo azul no canto do card (solicitação nova).
class _CantoNovo extends CustomPainter {
  _CantoNovo({required this.cor});

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(covariant _CantoNovo old) => old.cor != cor;
}
