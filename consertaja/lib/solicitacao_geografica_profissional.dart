import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'gestao_equipe.dart';
import 'meus_enderecos.dart';
import 'meus_servicos_solicitados.dart';
import 'services/solicitacao_geografica_service.dart';
import 'solicitacao_estado.dart';
import 'tela_home_profissional.dart';
import 'tela_mensagens.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/app_navigation_util.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'utils/icone_oficio.dart';
import 'utils/iniciais.dart';
import 'widgets/camada_mapa.dart';
import 'widgets/sonar_pulso.dart';

enum _Aba { proximas, aceitas }

/// Aba "Radar" do profissional: mostra o ENDEREÇO cadastrado dele (perfil ou
/// empresa, conforme a conta ativa — não o GPS) e as solicitações
/// geográficas abertas que alcançam esse endereço, com a função dele.
/// Ao aceitar, nasce a `solicitacoes` (Aguardando Pagamento) e o pedido
/// passa para a aba "Aceitas".
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

  /// Conta sem endereço com coordenadas cadastrado.
  bool _semEndereco = false;

  /// Centro mostrado quando não há endereço (São Paulo).
  static const LatLng _centroPadrao = LatLng(-23.5505, -46.6333);
  List<SolicitacaoGeoProxima> _solicitacoes = [];
  int? _selecionada;

  _Aba _aba = _Aba.proximas;
  List<SolicitacaoGeoAceita> _aceitas = [];

  /// Aceita aberta em detalhe (id da solicitação geográfica).
  int? _aceitaAberta;
  bool _aceitando = false;
  Timer? _atualizacao;

  /// Por que a lista de próximas veio vazia (diagnostico_radar).
  String? _motivoVazio;

  Future<void> _explicarListaVazia(LatLng posicao) async {
    final d = await SolicitacaoGeograficaService.diagnostico(posicao);
    if (!mounted || d == null || _solicitacoes.isNotEmpty) return;
    int n(String k) => (d[k] as num?)?.toInt() ?? 0;
    final oficios = n('meus_oficios');
    final total = n('abertas_total');
    final minhas = n('abertas_minhas');
    final daArea = n('abertas_da_area');
    final maisPerto = (d['aberta_area_mais_proxima_km'] as num?)?.toDouble();
    String km(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    String texto;
    if (oficios == 0) {
      texto =
          'Sua conta não tem nenhuma área de atuação cadastrada, então '
          'nenhum pedido combina com você. Cadastre em Área de Atuação.';
    } else if (daArea > 0 && maisPerto != null) {
      texto =
          'Há $daArea pedido(s) da sua área aberto(s), mas fora do alcance: '
          'o mais próximo está a ${km(maisPerto)} km do seu endereço (o '
          'pedido alcança 5 km a partir do cliente).';
    } else if (total > 0) {
      texto =
          'Há $total pedido(s) aberto(s) no Radar, mas nenhum da sua área '
          'de atuação.';
      if (minhas > 0) {
        texto +=
            ' $minhas deles é(são) seu(s): o próprio pedido não aparece '
            'para quem o criou.';
      }
    } else {
      texto = 'Nenhum pedido aberto no Radar agora.';
    }
    setState(() => _motivoVazio = texto);
  }

  bool get _contaEmpresa =>
      BottomNavigationBarProfissional.leituraSincronaContaEmpresa();

  SolicitacaoGeoAceita? get _aceitaDetalhe =>
      _aceitas.where((a) => a.id == _aceitaAberta).firstOrNull;

  @override
  void initState() {
    super.initState();
    _carregar();
    // Mantém o status das aceitas em dia (pagamento, andamento...).
    _atualizacao = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _carregarAceitas(),
    );
  }

  @override
  void dispose() {
    _atualizacao?.cancel();
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _carregarAceitas() async {
    try {
      final lista = await SolicitacaoGeograficaService.aceitas(
        contaEmpresa: _contaEmpresa,
      );
      if (!mounted) return;
      setState(() {
        _aceitas = lista;
        if (!lista.any((a) => a.id == _aceitaAberta)) _aceitaAberta = null;
      });
    } catch (e) {
      debugPrint('[RadarProf] aceitas: $e');
    }
  }

  Future<void> _carregar({bool atualizarPosicao = true}) async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    unawaited(_carregarAceitas());
    try {
      if (atualizarPosicao || _posicao == null) {
        // Endereço da conta ativa (empresa ou independente), nunca o GPS.
        final pos =
            await SolicitacaoGeograficaService.localizacaoEnderecoProfissional(
              contaEmpresa:
                  BottomNavigationBarProfissional.leituraSincronaContaEmpresa(),
            );
        if (!mounted) return;
        setState(() {
          _semEndereco = pos == null;
          _posicao = pos ?? _centroPadrao;
        });
        _centralizar(_posicao!, zoom: pos == null ? 11 : 14);
      }
      if (_semEndereco) {
        if (mounted) setState(() => _solicitacoes = []);
        return;
      }
      final lista = await SolicitacaoGeograficaService.solicitacoesProximas(
        _posicao!,
      );
      if (!mounted) return;
      setState(() {
        _solicitacoes = lista;
        if (!lista.any((s) => s.id == _selecionada)) _selecionada = null;
        _motivoVazio = null;
      });
      if (lista.isEmpty) await _explicarListaVazia(_posicao!);
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

  // ── Aceite ────────────────────────────────────────────────────────────────

  void _trocarAba(_Aba aba) {
    if (_aba == aba) return;
    HapticFeedback.selectionClick();
    setState(() {
      _aba = aba;
      _selecionada = null;
      _aceitaAberta = null;
    });
  }

  /// Sheet de confirmação com o valor; aceita pela RPC e abre a aceita.
  Future<void> _aceitar(SolicitacaoGeoProxima s) async {
    if (_aceitando) return;
    final valor = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetAceitar(solicitacao: s),
    );
    if (valor == null || !mounted) return;

    setState(() => _aceitando = true);
    try {
      await SolicitacaoGeograficaService.aceitar(
        idSolicitacaoGeo: s.id,
        valor: valor,
        contaEmpresa: _contaEmpresa,
      );
      HapticFeedback.mediumImpact();
      await _carregarAceitas();
      if (!mounted) return;
      setState(() {
        _solicitacoes.removeWhere((x) => x.id == s.id);
        _selecionada = null;
        _aba = _Aba.aceitas;
        _aceitaAberta = s.id;
      });
      _focarAceita(_aceitaDetalhe);
      _mensagem(
        'Serviço aceito! Agora é só aguardar o pagamento do cliente.',
        sucesso: true,
      );
    } catch (e) {
      _mensagem(e.toString().replaceFirst('Exception: ', ''));
      _carregar(atualizarPosicao: false);
    } finally {
      if (mounted) setState(() => _aceitando = false);
    }
  }

  void _abrirAceita(SolicitacaoGeoAceita a) {
    HapticFeedback.selectionClick();
    setState(() => _aceitaAberta = a.id);
    _focarAceita(a);
  }

  void _focarAceita(SolicitacaoGeoAceita? a) {
    if (a == null) return;
    final deslocamento = 0.0035 * math.pow(2, 14 - _mapa.camera.zoom);
    _centralizar(
      LatLng(a.posicao.latitude - deslocamento, a.posicao.longitude),
    );
    if (_sheet.isAttached && _sheet.size < 0.5) {
      _sheet.animateTo(
        0.55,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Mesmo critério do cliente: até o pagamento (1/2) o botão mostra que está
  /// aguardando; depois vira "Acompanhar". Os dois abrem a solicitação.
  Future<void> _abrirSolicitacao(SolicitacaoGeoAceita a) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SolicitacaoEstadoPage(
          idSolicitacao: a.idSolicitacao,
          nomeClienteInicial: a.nomeCliente,
          fotoClienteInicial: a.fotoCliente,
        ),
      ),
    );
    if (mounted) await _carregarAceitas();
  }

  void _mensagem(String texto, {bool sucesso = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          behavior: SnackBarBehavior.floating,
          backgroundColor: sucesso ? const Color(0xFF16A34A) : null,
        ),
      );
  }

  static String formatarValor(double v) {
    final partes = v.toStringAsFixed(2).split('.');
    final inteiro = partes[0];
    final b = StringBuffer();
    for (var i = 0; i < inteiro.length; i++) {
      if (i > 0 && (inteiro.length - i) % 3 == 0) b.write('.');
      b.write(inteiro[i]);
    }
    return 'R\$ $b,${partes[1]}';
  }

  /// Rótulo e cor do status da solicitação vinculada.
  static (String, Color) statusAceita(SolicitacaoGeoAceita a) {
    switch (a.idStatus) {
      case StatusSolicitacaoVinculada.aberto:
        return ('Aguardando confirmação', const Color(0xFFF59E0B));
      case StatusSolicitacaoVinculada.aguardandoPagamento:
        return ('Aguardando pagamento', const Color(0xFFF59E0B));
      case 3:
        return ('Pago', const Color(0xFF16A34A));
    }
    final s = a.status?.trim() ?? '';
    return (s.isNotEmpty ? s : 'Em andamento', _azul);
  }

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
              const Positioned(top: 6, right: 6, child: CreditoMapa()),
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
        minZoom: 3,
        maxZoom: 19,
        onMapReady: () {
          _mapaPronto = true;
          _centralizar(pos, zoom: 14);
        },
        onTap: (_, _) => setState(() {
          _selecionada = null;
          _aceitaAberta = null;
        }),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        const CamadaMapaCinza(),
        if (_aba == _Aba.aceitas)
          MarkerLayer(
            markers: [
              if (!_semEndereco)
                Marker(
                  point: pos,
                  width: 140,
                  height: 74,
                  child: _marcadorProfissional(),
                ),
              for (final a in _aceitas)
                Marker(
                  point: a.posicao,
                  width: a.id == _aceitaAberta ? 200 : 150,
                  height: 70,
                  alignment: Alignment.topCenter,
                  child: _marcadorAceita(a, aberta: a.id == _aceitaAberta),
                ),
            ],
          )
        else
          MarkerLayer(
            markers: [
              // Bolinha com sonar na latitude/longitude do CLIENTE (onde ele
              // pediu), não no endereço cadastrado.
              for (final (i, s) in _solicitacoes.indexed)
                if (s.id != _selecionada)
                  Marker(
                    point: s.posicao,
                    width: 160,
                    height: 140,
                    child: _marcadorPedido(s, indice: i),
                  ),
              if (!_semEndereco)
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
                    width: 240,
                    height: 160,
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
            'Seu endereço',
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

  /// Bolinha do pedido com efeito sonar (centrada no ponto do cliente) e,
  /// acima dela, a etiqueta com a função e o número do pedido.
  Widget _marcadorPedido(SolicitacaoGeoProxima s, {required int indice}) {
    return GestureDetector(
      onTap: () => _selecionar(s, doMapa: true),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          SonarPulso(
            cor: _azul,
            tamanho: 28,
            alcance: 3.2,
            atraso: Duration(milliseconds: indice * 430),
            child: _bolinhaPedido(s),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 70 + 18,
            child: Center(child: _etiquetaPedido(s)),
          ),
        ],
      ),
    );
  }

  Widget _bolinhaPedido(SolicitacaoGeoProxima s, {bool selecionada = false}) {
    final cor = selecionada ? _azulSelecionado : _azul;
    final tamanho = selecionada ? 34.0 : 28.0;
    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: cor.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: IconeOficio.imagemPorFuncao(s.funcao, tamanho: tamanho * 0.55),
    );
  }

  Widget _etiquetaPedido(SolicitacaoGeoProxima s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      constraints: const BoxConstraints(maxWidth: 150),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
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
    );
  }

  Widget _marcadorPedidoSelecionado(SolicitacaoGeoProxima s) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        SonarPulso(
          cor: _azulSelecionado,
          tamanho: 34,
          alcance: 3.2,
          duracao: const Duration(milliseconds: 1600),
          child: _bolinhaPedido(s, selecionada: true),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 80 + 20,
          child: Center(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              constraints: const BoxConstraints(maxWidth: 230),
              decoration: BoxDecoration(
                color: _azulSelecionado,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
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
                  Text(
                    (s.enderecoCliente ?? '').isNotEmpty
                        ? s.enderecoCliente!
                        : 'Localização atual do cliente',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Pin das aceitas: verde/âmbar conforme o status, com o título.
  Widget _marcadorAceita(SolicitacaoGeoAceita a, {required bool aberta}) {
    final (rotulo, cor) = statusAceita(a);
    return GestureDetector(
      onTap: () => _abrirAceita(a),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(6, 4, 9, 4),
            decoration: BoxDecoration(
              color: aberta ? cor : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cor, width: 1.4),
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
                Icon(
                  Icons.check_circle_rounded,
                  color: aberta ? Colors.white : cor,
                  size: 15,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        a.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: aberta ? Colors.white : _texto,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        rotulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: aberta ? Colors.white70 : _textoSec,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.location_on, color: cor, size: 24),
        ],
      ),
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
              Text(
                _aba == _Aba.aceitas
                    ? 'Solicitações Aceitas'
                    : 'Solicitações Próximas',
                style: const TextStyle(
                  color: _texto,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_aba == _Aba.proximas && _novas > 0)
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
          const SizedBox(height: 12),
          _abas(),
        ],
      ),
    );
  }

  /// Segmentado "Próximas | Aceitas".
  Widget _abas() {
    Widget aba(_Aba valor, String texto, int qtd) {
      final ativa = _aba == valor;
      return Expanded(
        child: GestureDetector(
          onTap: () => _trocarAba(valor),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ativa ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: ativa
                  ? const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  texto,
                  style: TextStyle(
                    color: ativa ? _azul : _textoSec,
                    fontSize: 13.5,
                    fontWeight: ativa ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (qtd > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: ativa ? _azul : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$qtd',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          aba(_Aba.proximas, 'Próximas', _solicitacoes.length),
          const SizedBox(width: 4),
          aba(_Aba.aceitas, 'Aceitas', _aceitas.length),
        ],
      ),
    );
  }

  List<Widget> _conteudoSheet() {
    if (_aba == _Aba.aceitas) return _conteudoAceitas();
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
    if (_semEndereco) {
      return [
        SliverToBoxAdapter(
          child: _aviso(
            Icons.location_off_outlined,
            'Cadastre o endereço do seu perfil (ou da sua empresa) para ver '
            'as solicitações da sua área. O Radar usa o endereço cadastrado, '
            'não a sua localização atual.',
            acao: 'Cadastrar endereço',
            aoTocar: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MeusEnderecosPage(
                    isVisitante: widget.isVisitante,
                    isProfissional: true,
                  ),
                ),
              );
              if (mounted) _carregar();
            },
          ),
        ),
      ];
    }
    if (_solicitacoes.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _aviso(
            Icons.sensors,
            _motivoVazio ??
                'Nenhuma solicitação na sua área por enquanto. Quando um '
                    'cliente próximo pedir um serviço da sua área de atuação, '
                    'ele aparece aqui.',
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

  Widget _aviso(
    IconData icone,
    String texto, {
    String? acao,
    VoidCallback? aoTocar,
  }) {
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
            if (acao != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: aoTocar,
                style: FilledButton.styleFrom(
                  backgroundColor: _azul,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(acao),
              ),
            ],
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
                    if ((s.metodoEntrega ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _chipMetodo(s.metodoEntrega!),
                    ],
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
                        onPressed: _aceitando ? null : () => _aceitar(s),
                        style: FilledButton.styleFrom(
                          backgroundColor: _azul,
                          disabledBackgroundColor: _azul.withValues(alpha: 0.5),
                          disabledForegroundColor: Colors.white,
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

  Widget _chipMetodo(String metodo) {
    final m = MetodoEntregaGeo.porValor(metodo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(m?.icone ?? Icons.route_outlined, size: 14, color: _azul),
          const SizedBox(width: 4),
          Text(
            metodo,
            style: const TextStyle(
              color: Color(0xFF0284C7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Aba "Aceitas" ─────────────────────────────────────────────────────────

  List<Widget> _conteudoAceitas() {
    final detalhe = _aceitaDetalhe;
    if (detalhe != null) {
      return [SliverToBoxAdapter(child: _detalheAceita(detalhe))];
    }
    if (_aceitas.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _aviso(
            Icons.task_alt_rounded,
            'Você ainda não aceitou nenhuma solicitação do Radar. Aceite um '
            'pedido na aba "Próximas" e ele aparece aqui até ser concluído.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        sliver: SliverList.separated(
          itemCount: _aceitas.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _cardAceitaResumo(_aceitas[i]),
        ),
      ),
    ];
  }

  Widget _chipStatus(SolicitacaoGeoAceita a) {
    final (rotulo, cor) = statusAceita(a);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            rotulo,
            style: TextStyle(
              color: cor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardAceitaResumo(SolicitacaoGeoAceita a) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _abrirAceita(a),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borda),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _azul,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconeOficio.imagemPorFuncao(a.funcao, tamanho: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${a.nomeCliente} • ${formatarValor(a.valor)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _textoSec, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    _chipStatus(a),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _textoSec),
            ],
          ),
        ),
      ),
    );
  }

  /// Visão da aceita: dados da solicitação geográfica + status + botão.
  Widget _detalheAceita(SolicitacaoGeoAceita a) {
    final aguardando = !StatusSolicitacaoVinculada.podeAcompanhar(a.idStatus);
    final distancia = _posicao == null || _semEndereco
        ? null
        : const Distance().as(LengthUnit.Meter, _posicao!, a.posicao) / 1000;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _aceitaAberta = null),
            style: TextButton.styleFrom(
              foregroundColor: _textoSec,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Todas as aceitas'),
          ),
          const SizedBox(height: 4),
          // Cabeçalho com gradiente: status + título + valor.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0FB3FF), Color(0xFF0A8FD6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _azul.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusAceita(a).$1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Radar #${a.id}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  a.titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    a.funcao,
                    if ((a.metodoEntrega ?? '').isNotEmpty) a.metodoEntrega!,
                  ].join(' • '),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Valor do serviço',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                        Text(
                          formatarValor(a.valor),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (distancia != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${distancia.toStringAsFixed(1).replaceAll('.', ',')} km',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Cliente
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borda),
            ),
            child: Row(
              children: [
                _avatar(a.nomeCliente, a.fotoCliente),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.nomeCliente,
                        style: const TextStyle(
                          color: _texto,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((a.enderecoCliente ?? '').isNotEmpty)
                        Text(
                          a.enderecoCliente!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textoSec,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Pedido do cliente',
            style: TextStyle(
              color: _texto,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (a.imagens.isNotEmpty) ...[
            _imagensSolicitacao(a.imagens),
            const SizedBox(height: 10),
          ],
          Text(
            a.descricao,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          _linhaData(Icons.event_note_outlined, 'Pedido criado', a.dataCriacao),
          _linhaData(Icons.task_alt_rounded, 'Você aceitou', a.dataAceite),
          if (aguardando) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'O cliente precisa pagar para o serviço começar. Você '
                      'será avisado aqui quando o pagamento cair.',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: aguardando
                ? OutlinedButton.icon(
                    onPressed: () => _abrirSolicitacao(a),
                    icon: const Icon(Icons.payments_outlined, size: 19),
                    label: const Text(
                      'Aguardando Pagamento',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _azul,
                      side: const BorderSide(color: _azul, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: () => _abrirSolicitacao(a),
                    icon: const Icon(Icons.navigation_rounded, size: 19),
                    label: const Text(
                      'Acompanhar em Tempo Real',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _azul,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _linhaData(IconData icone, String rotulo, DateTime? data) {
    if (data == null) return const SizedBox.shrink();
    final d = data.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icone, size: 15, color: _textoSec),
          const SizedBox(width: 6),
          Text(
            '$rotulo em ${dois(d.day)}/${dois(d.month)} às '
            '${dois(d.hour)}:${dois(d.minute)}',
            style: const TextStyle(color: _textoSec, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _avatarCliente(SolicitacaoGeoProxima s) =>
      _avatar(s.nomeCliente, s.fotoCliente);

  Widget _avatar(String nome, String? foto) {
    const tamanho = 46.0;
    final iniciais = Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _azul, shape: BoxShape.circle),
      child: Text(
        obterIniciais(nome),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
    final url = foto?.trim() ?? '';
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

/// Confirmação do aceite: resumo do pedido + valor do serviço (obrigatório,
/// vira valor_final da solicitação e o valor que o cliente paga).
class _SheetAceitar extends StatefulWidget {
  const _SheetAceitar({required this.solicitacao});

  final SolicitacaoGeoProxima solicitacao;

  @override
  State<_SheetAceitar> createState() => _SheetAceitarState();
}

class _SheetAceitarState extends State<_SheetAceitar> {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _texto = Color(0xFF1D2430);
  static const Color _textoSec = Color(0xFF6B7280);

  final TextEditingController _valor = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  /// "1.234,56" / "180" / "180,5" → 180.5
  double? get _valorNumerico {
    final limpo = _valor.text
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return double.tryParse(limpo);
  }

  void _confirmar() {
    final v = _valorNumerico;
    if (v == null || v <= 0) {
      setState(() => _erro = 'Informe o valor do serviço.');
      return;
    }
    Navigator.pop(context, double.parse(v.toStringAsFixed(2)));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitacao;
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: teclado),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5DCE4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Aceitar serviço',
                  style: TextStyle(
                    color: _texto,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Defina o valor. O cliente recebe o pedido para pagamento e '
                  'o serviço segue o fluxo normal depois disso.',
                  style: TextStyle(
                    color: _textoSec,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _azul,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconeOficio.imagemPorFuncao(
                          s.funcao,
                          tamanho: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _texto,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              [
                                s.nomeCliente,
                                if ((s.metodoEntrega ?? '').isNotEmpty)
                                  s.metodoEntrega!,
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textoSec,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Valor do serviço',
                  style: TextStyle(
                    color: _texto,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _valor,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) {
                    if (_erro != null) setState(() => _erro = null);
                  },
                  onSubmitted: (_) => _confirmar(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _texto,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'R\$ ',
                    hintText: '0,00',
                    errorText: _erro,
                    filled: true,
                    fillColor: const Color(0xFFF7F9FC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE3E8EF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _azul, width: 1.6),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFDC2626)),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFDC2626),
                        width: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _confirmar,
                    icon: const Icon(Icons.check_circle_outline, size: 19),
                    label: const Text(
                      'Confirmar e aceitar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _azul,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
