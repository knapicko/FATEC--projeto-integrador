import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'services/solicitacao_geografica_service.dart';
import 'tela_home.dart';
import 'utils/app_navigation_util.dart';
import 'utils/cor_oficio.dart';
import 'utils/icone_oficio.dart';
import 'utils/iniciais.dart';
import 'widgets/carregamento_segmentado.dart';

/// Mesmo filtro preto e branco do mapa de meus_enderecos.dart.
const List<double> _matrizMapaCinza = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

enum _Etapa { formulario, solicitando, aguardando }

/// Aba "Radar" do cliente: cria uma solicitação geográfica que vai para os
/// profissionais/empresas com a função escolhida num raio de 5 km.
class SolicitacaoGeograficaClientePage extends StatefulWidget {
  const SolicitacaoGeograficaClientePage({super.key, this.isVisitante = false});

  final bool isVisitante;

  @override
  State<SolicitacaoGeograficaClientePage> createState() =>
      _SolicitacaoGeograficaClientePageState();
}

class _SolicitacaoGeograficaClientePageState
    extends State<SolicitacaoGeograficaClientePage> {
  // ── Paleta (designs) ──────────────────────────────────────────────────────
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _texto = Color(0xFF1D2430);
  static const Color _textoSec = Color(0xFF6B7280);
  static const Color _borda = Color(0xFFE5E7EB);
  static const Color _fundoSheet = Color(0xFFFAFAFA);
  static const Color _cinzaCard = Color(0xFFF3F4F6);
  static const Color _vermelho = Color(0xFFDC2626);

  static const Duration _dur = Duration(milliseconds: 420);
  static const Curve _curva = Curves.easeInOutCubic;
  static const int _maxDescricao = 500;

  final MapController _mapa = MapController();
  final TextEditingController _titulo = TextEditingController();
  final TextEditingController _descricao = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // ── Estado ────────────────────────────────────────────────────────────────
  _Etapa _etapa = _Etapa.formulario;
  bool _expandido = false;
  bool _mapaPronto = false;

  LatLng? _centro;
  List<FuncaoPedido> _funcoes = [];
  FuncaoPedido? _funcao;
  final List<XFile> _imagens = [];

  /// URLs das imagens de uma solicitação já criada (reaberta do banco).
  List<String> _imagensSalvas = [];

  List<PerfilProximo> _perfis = [];

  int? _idSolicitacao;
  bool _criacaoConcluida = false;
  String? _erroCriacao;

  String? _erroTitulo;
  String? _erroArea;
  String? _erroDescricao;
  String? _erroImagem;

  @override
  void initState() {
    super.initState();
    _descricao.addListener(() => setState(() {}));
    _titulo.addListener(() {
      if (_erroTitulo != null && _titulo.text.trim().isNotEmpty) {
        setState(() => _erroTitulo = null);
      }
    });
    _iniciar();
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    final centroFuture = SolicitacaoGeograficaService.localizacaoAtual();
    try {
      final funcoes = await SolicitacaoGeograficaService.carregarFuncoes();
      if (mounted) setState(() => _funcoes = funcoes);
    } catch (e) {
      _mensagem('Não foi possível carregar as áreas: $e');
    }
    final centro = await centroFuture;
    if (!mounted) return;
    setState(() => _centro = centro);
    _enquadrarMapa();
    await _restaurarSolicitacaoAtiva();
    if (_etapa == _Etapa.formulario) await _carregarPerfis();
  }

  /// Se o cliente já tem uma solicitação criada (fk_usuario = ele, não
  /// cancelada), a tela abre direto nela, com os dados carregados.
  Future<void> _restaurarSolicitacaoAtiva() async {
    try {
      final minha = await SolicitacaoGeograficaService.minhaSolicitacaoAtiva();
      if (minha == null || !mounted) return;
      setState(() {
        _idSolicitacao = minha.id;
        _titulo.text = minha.titulo;
        _descricao.text = minha.descricao;
        _funcao = _funcoes.where((f) => f.id == minha.fkFuncao).firstOrNull;
        _imagensSalvas = minha.imagens;
        if (minha.centro != null) _centro = minha.centro;
        _etapa = _Etapa.aguardando;
        _criacaoConcluida = true;
      });
      _enquadrarMapa();
      await _carregarPerfis();
    } catch (e) {
      // Tabela ainda não criada: segue no formulário.
      debugPrint('[SolicGeo] restaurar: $e');
    }
  }

  Future<void> _carregarPerfis() async {
    final centro = _centro;
    if (centro == null) return;
    try {
      final perfis = await SolicitacaoGeograficaService.buscarProximos(
        centro,
        fkFuncao: _funcao?.id,
      );
      if (mounted) setState(() => _perfis = perfis);
    } catch (e) {
      debugPrint('[SolicGeo] perfis próximos: $e');
    }
  }

  // ── Mapa ──────────────────────────────────────────────────────────────────

  /// Enquadra o círculo de 5 km na parte do mapa que fica visível acima do
  /// bottom sheet.
  void _enquadrarMapa() {
    final c = _centro;
    if (c == null || !_mapaPronto) return;
    final altura = MediaQuery.of(context).size.height;
    final ocupadoPeloSheet = switch (_etapa) {
      _Etapa.formulario => altura * 0.62,
      _ => altura * 0.34,
    };
    const raio = SolicitacaoGeograficaService.raioKm;
    final dLat = raio / 111.32;
    final dLng = raio / (111.32 * math.cos(c.latitude * math.pi / 180));
    _mapa.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(c.latitude - dLat, c.longitude - dLng),
          LatLng(c.latitude + dLat, c.longitude + dLng),
        ),
        padding: EdgeInsets.fromLTRB(20, 70, 20, ocupadoPeloSheet + 12),
      ),
    );
  }

  Widget _buildMapa() {
    final c = _centro;
    if (c == null) {
      return Container(
        color: const Color(0xFFE5E7EB),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: _azul),
      );
    }
    return FlutterMap(
      mapController: _mapa,
      options: MapOptions(
        initialCenter: c,
        initialZoom: 12.5,
        onMapReady: () {
          _mapaPronto = true;
          _enquadrarMapa();
        },
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
        CircleLayer(
          circles: [
            CircleMarker(
              point: c,
              radius: SolicitacaoGeograficaService.raioKm * 1000,
              useRadiusInMeter: true,
              color: _azul.withValues(alpha: 0.18),
              borderColor: _azul.withValues(alpha: 0.55),
              borderStrokeWidth: 1.5,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final p in _perfis)
              Marker(
                point: p.posicao,
                width: 44,
                height: 44,
                child: _avatarMapa(p),
              ),
            Marker(point: c, width: 52, height: 52, child: _marcadorCliente()),
          ],
        ),
      ],
    );
  }

  Widget _marcadorCliente() {
    return Container(
      decoration: BoxDecoration(
        color: _azul,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: [
          BoxShadow(
            color: _azul.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(
        Icons.person_pin_circle_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  /// Círculo com a foto (ou iniciais) do profissional, com borda.
  Widget _avatarMapa(PerfilProximo p) {
    final corBorda = p.ehEmpresa && (p.corTagEmpresa?.isNotEmpty ?? false)
        ? CorOficio.parse(p.corTagEmpresa)
        : _azul;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: corBorda, width: 2.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: _fotoOuIniciais(p, 36),
    );
  }

  Widget _fotoOuIniciais(PerfilProximo p, double tamanho) {
    final url = p.fotoUrl?.trim() ?? '';
    final iniciais = Container(
      width: tamanho,
      height: tamanho,
      decoration: const BoxDecoration(color: _azul, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(p.nome),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: tamanho * 0.36,
        ),
      ),
    );
    if (url.isEmpty || url == 'null') return iniciais;
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

  // ── Ações ─────────────────────────────────────────────────────────────────

  Future<void> _voltar() async {
    if (_expandido) {
      setState(() => _expandido = false);
      return;
    }
    if (_etapa == _Etapa.solicitando) return; // aguarda terminar de criar
    // Com a solicitação criada, voltar só sai da tela (não cancela): ao
    // reabrir o Radar, ela é carregada de novo.
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      AppNavigationUtil.navegarAba(
        context,
        TelaHome(isVisitante: widget.isVisitante),
        isHome: true,
      );
    }
  }

  Future<void> _escolherArea() async {
    FocusScope.of(context).unfocus();
    final escolhida = await showModalBottomSheet<FuncaoPedido>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              _alca(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Text(
                  'Área do Pedido',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _texto,
                  ),
                ),
              ),
              Flexible(
                child: _funcoes.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma área disponível.',
                          style: TextStyle(color: _textoSec),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _funcoes.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (_, i) {
                          final f = _funcoes[i];
                          final sel = f.id == _funcao?.id;
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _azul,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconeOficio.imagemPorFuncao(
                                f.funcao,
                                tamanho: 26,
                              ),
                            ),
                            title: Text(
                              f.funcao,
                              style: TextStyle(
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _texto,
                              ),
                            ),
                            subtitle: (f.descricao?.isNotEmpty ?? false)
                                ? Text(
                                    f.descricao!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _textoSec,
                                    ),
                                  )
                                : null,
                            trailing: sel
                                ? const Icon(Icons.check_circle, color: _azul)
                                : null,
                            onTap: () => Navigator.pop(ctx, f),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (escolhida == null || !mounted) return;
    setState(() {
      _funcao = escolhida;
      _erroArea = null;
    });
    await _carregarPerfis();
  }

  Future<void> _anexarImagens() async {
    try {
      final novas = await _picker.pickMultiImage(
        imageQuality: 75,
        maxWidth: 1600,
      );
      if (novas.isEmpty || !mounted) return;
      setState(() {
        _imagens.addAll(novas.take(6 - _imagens.length));
        _erroImagem = null;
      });
    } catch (e) {
      _mensagem('Não foi possível abrir a galeria: $e');
    }
  }

  bool _validar() {
    setState(() {
      _erroTitulo = _titulo.text.trim().isEmpty
          ? 'Dê um título ao pedido.'
          : null;
      _erroArea = _funcao == null ? 'Selecione a área do pedido.' : null;
      _erroDescricao = _descricao.text.trim().isEmpty
          ? 'Descreva o que você precisa.'
          : null;
      _erroImagem = _imagens.isEmpty ? 'Anexe pelo menos uma imagem.' : null;
    });
    return _erroTitulo == null &&
        _erroArea == null &&
        _erroDescricao == null &&
        _erroImagem == null;
  }

  Future<void> _selecionarProfissionais() async {
    FocusScope.of(context).unfocus();
    if (!_validar()) return;
    final centro = _centro;
    final funcao = _funcao;
    if (centro == null || funcao == null) return;

    HapticFeedback.lightImpact();
    setState(() {
      _etapa = _Etapa.solicitando;
      _criacaoConcluida = false;
      _erroCriacao = null;
    });
    _enquadrarMapa();

    try {
      final urls = await SolicitacaoGeograficaService.enviarImagens(_imagens);
      final id = await SolicitacaoGeograficaService.criar(
        titulo: _titulo.text,
        descricao: _descricao.text,
        fkFuncao: funcao.id,
        imagens: urls,
        centro: centro,
      );
      _idSolicitacao = id;
      _imagensSalvas = urls;
      // A troca de tela só acontece quando a 3ª reticência aparecer
      // (ver _aoCompletarReticencias).
      _criacaoConcluida = true;
    } catch (e) {
      _erroCriacao = e.toString().replaceFirst('Exception: ', '');
      _criacaoConcluida = true;
    }
  }

  /// Chamado a cada vez que as reticências chegam em "...".
  void _aoCompletarReticencias() {
    if (!_criacaoConcluida || _etapa != _Etapa.solicitando) return;
    if (_erroCriacao != null) {
      final erro = _erroCriacao!;
      setState(() => _etapa = _Etapa.formulario);
      _enquadrarMapa();
      _mensagem('Não foi possível solicitar: $erro');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _etapa = _Etapa.aguardando);
    _enquadrarMapa();
  }

  Future<void> _cancelarSolicitacao({bool manterDados = false}) async {
    final id = _idSolicitacao;
    try {
      if (id != null) await SolicitacaoGeograficaService.cancelar(id);
    } catch (e) {
      _mensagem('Não foi possível cancelar: $e');
      return;
    }
    if (!mounted) return;
    setState(() {
      _idSolicitacao = null;
      _imagensSalvas = [];
      _expandido = false;
      _etapa = _Etapa.formulario;
      if (!manterDados) {
        _titulo.clear();
        _descricao.clear();
        _imagens.clear();
        _funcao = null;
      }
    });
    _enquadrarMapa();
    await _carregarPerfis();
    if (!manterDados) _mensagem('Solicitação cancelada.');
  }

  Future<bool?> _confirmar({
    required String titulo,
    required String texto,
    required String botao,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _vermelho),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(botao),
          ),
        ],
      ),
    );
  }

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final altura = MediaQuery.of(context).size.height;
    return PopScope(
      // Voltar sai da tela (formulário ou solicitação criada); só é
      // interceptado para recolher o painel ou durante a criação.
      canPop: _etapa != _Etapa.solicitando && !_expandido,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _voltar();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              Positioned.fill(child: _buildMapa()),
              // Blur no pedacinho de mapa que sobra com o sheet expandido.
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_expandido,
                  child: GestureDetector(
                    onTap: () => setState(() => _expandido = false),
                    child: AnimatedOpacity(
                      opacity: _expandido ? 1 : 0,
                      duration: _dur,
                      curve: _curva,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _botaoVoltar(),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _buildSheet(altura),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoVoltar() {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _voltar,
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back, color: _azul, size: 22),
        ),
      ),
    );
  }

  Widget _alca() => Container(
    width: 42,
    height: 5,
    decoration: BoxDecoration(
      color: const Color(0xFFD1D5DB),
      borderRadius: BorderRadius.circular(4),
    ),
  );

  Widget _buildSheet(double altura) {
    final ehFormulario = _etapa == _Etapa.formulario;
    final Widget conteudo = switch (_etapa) {
      _Etapa.formulario => _conteudoFormulario(altura),
      _Etapa.solicitando => _conteudoSolicitando(),
      _Etapa.aguardando =>
        _expandido ? _conteudoExpandido(altura) : _conteudoAguardando(),
    };
    final chave = switch (_etapa) {
      _Etapa.formulario => 'form',
      _Etapa.solicitando => 'solicitando',
      _Etapa.aguardando => _expandido ? 'expandido' : 'aguardando',
    };

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ehFormulario ? _fundoSheet : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: _dur,
        curve: _curva,
        alignment: Alignment.bottomCenter,
        child: AnimatedSwitcher(
          duration: _dur,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          // Sai com fade out e entra com fade in (+ leve subida).
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          layoutBuilder: (atual, anteriores) => Stack(
            alignment: Alignment.bottomCenter,
            children: [...anteriores, ?atual],
          ),
          child: KeyedSubtree(key: ValueKey(chave), child: conteudo),
        ),
      ),
    );
  }

  // ── Etapa 1: formulário (1º design) ───────────────────────────────────────

  Widget _conteudoFormulario(double altura) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: math.max(260, altura * 0.64 - teclado * 0.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _rotulo('Título do pedido'),
                  const SizedBox(height: 8),
                  _campoTitulo(),
                  _textoErro(_erroTitulo),
                  const SizedBox(height: 18),
                  _rotulo('Área do Pedido'),
                  const SizedBox(height: 8),
                  _seletorArea(),
                  _textoErro(_erroArea),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _rotulo('Descrição do pedido'),
                      const Spacer(),
                      Text(
                        '${_descricao.text.length}/$_maxDescricao',
                        style: const TextStyle(
                          color: _textoSec,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _campoDescricao(),
                  _textoErro(_erroDescricao),
                  const SizedBox(height: 18),
                  _rotulo('Anexar Imagens'),
                  const SizedBox(height: 8),
                  _areaAnexo(),
                  _textoErro(_erroImagem),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _selecionarProfissionais,
                  style: FilledButton.styleFrom(
                    backgroundColor: _azul,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Selecionar Profissionais',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.send_outlined, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rotulo(String texto) => Text(
    texto,
    style: const TextStyle(
      color: _texto,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _textoErro(String? erro) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    child: erro == null
        ? const SizedBox.shrink()
        : Padding(
            key: ValueKey(erro),
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              erro,
              style: const TextStyle(color: _vermelho, fontSize: 12),
            ),
          ),
  );

  Widget _seletorArea() {
    final f = _funcao;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _escolherArea,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _erroArea != null ? _vermelho : _borda),
          ),
          child: Row(
            children: [
              if (f != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _azul,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconeOficio.imagemPorFuncao(f.funcao, tamanho: 20),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  f?.funcao ?? 'Selecione uma área...',
                  style: TextStyle(
                    color: f == null ? _texto : _texto,
                    fontSize: 15,
                    fontWeight: f == null ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: _texto),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campoTitulo() {
    return TextField(
      controller: _titulo,
      maxLength: 80,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        counterText: '',
        hintText: 'Ex.: Instalação de ar-condicionado',
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: _erroTitulo != null ? _vermelho : _borda,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _azul, width: 1.4),
        ),
      ),
    );
  }

  Widget _campoDescricao() {
    return TextField(
      controller: _descricao,
      maxLength: _maxDescricao,
      minLines: 4,
      maxLines: 6,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) {
        if (_erroDescricao != null) setState(() => _erroDescricao = null);
      },
      decoration: InputDecoration(
        counterText: '',
        hintText: 'Descreva com detalhes o que você precisa...',
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: _erroDescricao != null ? _vermelho : _borda,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _azul, width: 1.4),
        ),
      ),
    );
  }

  Widget _areaAnexo() {
    return Column(
      children: [
        GestureDetector(
          onTap: _imagens.length >= 6 ? null : _anexarImagens,
          child: CustomPaint(
            painter: _BordaTracejada(
              cor: _erroImagem != null ? _vermelho : const Color(0xFFC7CDD6),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 22),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5E7EB),
                      shape: BoxShape.circle,
                    ),
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: const Icon(
                        Icons.attach_file,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Clique para anexar ou arraste',
                    style: TextStyle(color: _texto, fontSize: 14.5),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_imagens.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _imagens.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? Image.network(
                            _imagens[i].path,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_imagens[i].path),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Positioned(
                    top: 3,
                    right: 3,
                    child: GestureDetector(
                      onTap: () => setState(() => _imagens.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Etapa 2: solicitando (sonar + reticências) ─────────────────────────────

  Widget _conteudoSolicitando() {
    const estilo = TextStyle(
      color: _texto,
      fontSize: 21,
      fontWeight: FontWeight.w700,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _alca(),
            const SizedBox(height: 26),
            const CarregamentoSegmentado(icone: Icons.sensors, sonar: true),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Solicitando Serviço', style: estilo),
                ReticenciasAnimadas(
                  estilo: estilo,
                  intervalo: const Duration(milliseconds: 560),
                  aoCompletar: _aoCompletarReticencias,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Etapa 3: aguardando (2º design) ───────────────────────────────────────

  Widget _cabecalhoAguardando() {
    return Column(
      children: [
        const CarregamentoSegmentado(icone: Icons.search),
        const SizedBox(height: 16),
        const Text(
          'Aguardando profissionais próximos',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _texto,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'O serviço foi solicitado, aguarde até que um profissional te '
          'contate para avaliar o serviço.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textoSec, fontSize: 14.5, height: 1.4),
        ),
      ],
    );
  }

  Widget _conteudoAguardando() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expandido = true),
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -150) setState(() => _expandido = true);
      },
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _alca(),
              const SizedBox(height: 22),
              _cabecalhoAguardando(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Expandido (3º design) ─────────────────────────────────────────────────

  Widget _conteudoExpandido(double altura) {
    final qtd = _perfis.length;
    final aviso = qtd == 0
        ? 'Sua solicitação está visível para os profissionais desta área '
              'num raio de 5 km.'
        : (qtd == 1
              ? '1 profissional próximo pode ver sua solicitação.'
              : '$qtd profissionais próximos podem ver sua solicitação.');
    return SizedBox(
      height: altura * 0.84,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expandido = false),
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 150) {
                  setState(() => _expandido = false);
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
                child: Center(child: _alca()),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                children: [
                  _cabecalhoAguardando(),
                  const SizedBox(height: 18),
                  _cardServico(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sensors, color: _azul, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            aviso,
                            style: const TextStyle(
                              color: Color(0xFF0369A1),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () async {
                    final ok = await _confirmar(
                      titulo: 'Cancelar solicitação?',
                      texto:
                          'Os profissionais deixarão de ver o seu pedido. '
                          'Essa ação não pode ser desfeita.',
                      botao: 'Cancelar solicitação',
                    );
                    if (ok == true) await _cancelarSolicitacao();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _texto,
                    side: const BorderSide(
                      color: Color(0xFFD1D5DB),
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Cancelar Solicitação',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resumo do pedido criado: título, área, descrição e imagens.
  Widget _cardServico() {
    final area = _funcao?.funcao ?? 'Serviço';
    final titulo = _titulo.text.trim().isNotEmpty ? _titulo.text.trim() : area;
    final descricao = _descricao.text.trim();
    final usarSalvas = _imagensSalvas.isNotEmpty;
    final qtdImagens = usarSalvas ? _imagensSalvas.length : _imagens.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cinzaCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _azul,
                  shape: BoxShape.circle,
                ),
                child: IconeOficio.imagemPorFuncao(area, tamanho: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      area,
                      style: const TextStyle(color: _textoSec, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (descricao.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              descricao,
              style: const TextStyle(
                color: _texto,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
          if (qtdImagens > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: qtdImagens,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: usarSalvas
                      ? Image.network(
                          _imagensSalvas[i],
                          width: 74,
                          height: 74,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 74,
                            height: 74,
                            color: _borda,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: _textoSec,
                            ),
                          ),
                        )
                      : (kIsWeb
                            ? Image.network(
                                _imagens[i].path,
                                width: 74,
                                height: 74,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_imagens[i].path),
                                width: 74,
                                height: 74,
                                fit: BoxFit.cover,
                              )),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Borda tracejada da área "Anexar Imagens".
class _BordaTracejada extends CustomPainter {
  _BordaTracejada({required this.cor});

  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final caminho = ui.Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );
    for (final metrica in caminho.computeMetrics()) {
      var d = 0.0;
      while (d < metrica.length) {
        canvas.drawPath(metrica.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordaTracejada old) => old.cor != cor;
}
