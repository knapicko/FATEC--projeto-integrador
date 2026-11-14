import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'detalhes_pedido.dart';
import 'pagamento_pedido.dart';
import 'perfil_loja.dart';
import 'perfil_profissional.dart';
import 'services/solicitacao_geografica_service.dart';
import 'tela_chat_profissional.dart';
import 'tela_home.dart';
import 'utils/app_navigation_util.dart';
import 'utils/cor_oficio.dart';
import 'utils/icone_oficio.dart';
import 'utils/iniciais.dart';
import 'widgets/camada_mapa.dart';
import 'widgets/carregamento_segmentado.dart';
import 'widgets/sonar_pulso.dart';

/// formulario → solicitando → aguardando → encontrado (profissional aceitou).
enum _Etapa { formulario, solicitando, aguardando, encontrado }

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
  static const Color _azulClaro = Color(0xFFE6F7FF);
  static const Color _fundoCampo = Color(0xFFF7F9FC);
  static const Color _bordaCampo = Color(0xFFE3E8EF);
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

  /// Sheet arrastado para baixo: só uma barrinha, mapa em tela cheia.
  bool _minimizado = false;
  bool _mapaPronto = false;

  LatLng? _centro;
  List<FuncaoPedido> _funcoes = [];
  FuncaoPedido? _funcao;
  MetodoEntregaGeo? _metodo;
  final List<XFile> _imagens = [];

  /// Profissional que aceitou + solicitação vinculada (etapa encontrado).
  AcompanhamentoGeo? _acomp;

  /// Consulta periódica: aguardando → detecta o aceite; encontrado →
  /// atualiza o status (pagamento, andamento...).
  Timer? _consulta;
  bool _consultando = false;

  /// URLs das imagens de uma solicitação já criada (reaberta do banco).
  List<String> _imagensSalvas = [];

  List<PerfilProximo> _perfis = [];

  /// Perfil com o popover aberto no mapa ([PerfilProximo.chave]).
  String? _perfilAberto;

  /// Aviso no topo do mapa quando não há ninguém no raio (ou deu erro).
  String? _avisoMapa;

  int? _idSolicitacao;
  bool _criacaoConcluida = false;
  String? _erroCriacao;

  String? _erroTitulo;
  String? _erroArea;
  String? _erroMetodo;
  String? _erroDescricao;
  String? _erroImagem;

  @override
  void initState() {
    super.initState();
    _descricao.addListener(() => setState(() {}));
    // Redesenha a cada letra: o botão "Enviar" libera/bloqueia na hora.
    _titulo.addListener(() {
      setState(() {
        if (_titulo.text.trim().isNotEmpty) _erroTitulo = null;
      });
    });
    _iniciar();
  }

  @override
  void dispose() {
    _consulta?.cancel();
    _titulo.dispose();
    _descricao.dispose();
    super.dispose();
  }

  /// Liga a consulta periódica conforme a etapa (aguardando/encontrado).
  void _agendarConsulta() {
    _consulta?.cancel();
    if (_idSolicitacao == null) return;
    if (_etapa == _Etapa.aguardando) {
      _consulta = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _verificarAceite(),
      );
    } else if (_etapa == _Etapa.encontrado) {
      _consulta = Timer.periodic(
        const Duration(seconds: 15),
        (_) => _atualizarAcompanhamento(),
      );
    }
  }

  /// Aguardando: se algum profissional aceitou, troca para "encontrado".
  Future<void> _verificarAceite() async {
    final id = _idSolicitacao;
    if (id == null || _consultando || _etapa != _Etapa.aguardando) return;
    _consultando = true;
    try {
      final status = await SolicitacaoGeograficaService.statusDa(id);
      if (!mounted) return;
      if (status == StatusSolicitacaoGeo.aceita) {
        await _atualizarAcompanhamento(forcar: true);
      } else if (status == StatusSolicitacaoGeo.concluida ||
          status == StatusSolicitacaoGeo.cancelada) {
        _voltarAoFormulario();
      }
    } catch (e) {
      debugPrint('[SolicGeo] verificar aceite: $e');
    } finally {
      _consultando = false;
    }
  }

  /// Carrega o profissional que aceitou e o status da solicitação vinculada.
  Future<void> _atualizarAcompanhamento({bool forcar = false}) async {
    final id = _idSolicitacao;
    if (id == null) return;
    if (!forcar && _etapa != _Etapa.encontrado) return;
    try {
      final acomp = await SolicitacaoGeograficaService.acompanhamento(id);
      if (!mounted) return;
      if (acomp == null) return;
      final concluida =
          acomp.idStatus == StatusSolicitacaoVinculada.concluido ||
          acomp.idStatus == StatusSolicitacaoVinculada.cancelado;
      if (concluida) {
        _voltarAoFormulario();
        _mensagem(
          acomp.idStatus == StatusSolicitacaoVinculada.concluido
              ? 'Serviço concluído! Você já pode fazer um novo pedido.'
              : 'A solicitação foi cancelada.',
        );
        return;
      }
      final mudouEtapa = _etapa != _Etapa.encontrado;
      if (mudouEtapa) HapticFeedback.mediumImpact();
      setState(() {
        _acomp = acomp;
        _etapa = _Etapa.encontrado;
        _expandido = false;
      });
      if (mudouEtapa) {
        _enquadrarMapa();
        _agendarConsulta();
      }
    } catch (e) {
      debugPrint('[SolicGeo] acompanhamento: $e');
    }
  }

  /// Limpa tudo e volta ao formulário (concluída / cancelada).
  void _voltarAoFormulario() {
    _consulta?.cancel();
    if (!mounted) return;
    setState(() {
      _idSolicitacao = null;
      _acomp = null;
      _imagensSalvas = [];
      _expandido = false;
      _minimizado = false;
      _etapa = _Etapa.formulario;
      _titulo.clear();
      _descricao.clear();
      _imagens.clear();
      _funcao = null;
      _metodo = null;
    });
    _enquadrarMapa();
    _carregarPerfis();
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
    if (!SolicitacaoGeograficaService.ultimaLocalizacaoFoiGps) {
      _mensagem(
        'Não conseguimos o GPS do aparelho; o Radar está usando o seu '
        'endereço cadastrado. Ative a localização para mais precisão.',
      );
    }
    // Endereços do cliente sem coordenada são geocodificados em segundo
    // plano: é com eles que o pedido acha o endereço a até 100 m.
    unawaited(SolicitacaoGeograficaService.garantirCoordenadasDoCliente());
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
        _metodo = MetodoEntregaGeo.porValor(minha.metodoEntrega);
        _imagensSalvas = minha.imagens;
        if (minha.centro != null) _centro = minha.centro;
        _etapa = _Etapa.aguardando;
        _criacaoConcluida = true;
      });
      _enquadrarMapa();
      if (minha.aceita) {
        // Já aceita: abre direto no "Profissional Encontrado".
        await _atualizarAcompanhamento(forcar: true);
      } else {
        _agendarConsulta();
      }
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
      if (!mounted) return;
      setState(() {
        _perfis = perfis;
        if (!perfis.any((p) => p.chave == _perfilAberto)) _perfilAberto = null;
        _avisoMapa = null;
      });
      if (perfis.isEmpty) await _explicarMapaVazio(centro);
    } catch (e) {
      debugPrint('[SolicGeo] perfis próximos: $e');
      if (mounted) {
        setState(
          () => _avisoMapa =
              'Erro ao buscar profissionais: '
              '${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  /// Sem ninguém no raio: diz por quê (via diagnostico_radar).
  Future<void> _explicarMapaVazio(LatLng centro) async {
    final d = await SolicitacaoGeograficaService.diagnostico(centro);
    if (!mounted || _perfis.isNotEmpty) return;
    String texto;
    if (d == null) {
      texto = 'Nenhum profissional a até 5 km.';
    } else {
      final total = (d['perfis_com_coordenadas'] as num?)?.toInt() ?? 0;
      final noRaio = (d['perfis_no_raio'] as num?)?.toInt() ?? 0;
      final maisPerto = (d['perfil_mais_proximo_km'] as num?)?.toDouble();
      if (total == 0) {
        texto = 'Nenhum profissional tem endereço com localização no mapa.';
      } else if (noRaio > 0 && _funcao != null) {
        texto =
            'Há $noRaio profissional(is) a até 5 km, mas nenhum atende '
            '"${_funcao!.funcao}".';
      } else if (maisPerto != null) {
        texto =
            'Nenhum profissional a até 5 km. O mais próximo está a '
            '${maisPerto.toStringAsFixed(1).replaceAll('.', ',')} km.';
      } else {
        texto = 'Nenhum profissional a até 5 km.';
      }
    }
    setState(() => _avisoMapa = texto);
  }

  void _abrirPerfilProximo(PerfilProximo p) {
    HapticFeedback.selectionClick();
    setState(() => _perfilAberto = _perfilAberto == p.chave ? null : p.chave);
  }

  void _verPerfil(PerfilProximo p) {
    final Widget pagina = p.ehEmpresa
        ? PerfilLoja(
            idGrupoEmpresa: p.idGrupoEmpresa,
            nomeEmpresa: p.nome,
            fotoUrlEmpresa: p.fotoUrl,
            tagEmpresa: p.tagEmpresa,
            corTagEmpresa: p.corTagEmpresa,
          )
        : PerfilProfissionalPage(
            nomeInicial: p.nome,
            imagemInicial: p.fotoUrl ?? '',
            idProfissional: p.idProfissional,
            avaliacao: p.nota,
          );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pagina));
  }

  // ── Mapa ──────────────────────────────────────────────────────────────────

  /// Enquadra o círculo de 5 km na parte do mapa que fica visível acima do
  /// bottom sheet.
  void _enquadrarMapa() {
    final c = _centro;
    if (c == null || !_mapaPronto) return;
    final altura = MediaQuery.of(context).size.height;
    final ocupadoPeloSheet = _minimizado
        ? 96.0
        : switch (_etapa) {
            _Etapa.formulario => altura * 0.62,
            _Etapa.encontrado => altura * 0.56,
            _ => altura * 0.34,
          };
    // Profissional encontrado: enquadra você + o endereço dele.
    final prof = _etapa == _Etapa.encontrado ? _acomp?.posicao : null;
    if (prof != null) {
      _mapa.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints([c, prof]),
          padding: EdgeInsets.fromLTRB(60, 110, 60, ocupadoPeloSheet + 40),
          maxZoom: 16,
        ),
      );
      return;
    }
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
        minZoom: 3,
        maxZoom: 19,
        onMapReady: () {
          _mapaPronto = true;
          _enquadrarMapa();
        },
        onTap: (_, _) => _aoTocarMapa(),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        const CamadaMapaCinza(),
        if (_etapa == _Etapa.encontrado)
          // Halo em volta de você (1º design: círculo azul-claro).
          CircleLayer(
            circles: [
              CircleMarker(
                point: c,
                radius: 54,
                color: _azul.withValues(alpha: 0.16),
                borderColor: Colors.transparent,
                borderStrokeWidth: 0,
              ),
            ],
          )
        else
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
            if (_etapa == _Etapa.encontrado && _acomp?.posicao != null)
              Marker(
                point: _acomp!.posicao!,
                width: 170,
                height: 74,
                alignment: Alignment.topCenter,
                child: _marcadorProfissionalEncontrado(),
              )
            else if (_etapa != _Etapa.encontrado) ...[
              // Perfis no mesmo lugar viram um grupo, lado a lado.
              for (final grupo in _gruposDePerfis())
                Marker(
                  point: grupo.first.posicao,
                  width: _ladoSonar + (grupo.length - 1) * _passoGrupo,
                  height: _ladoSonar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final (j, p) in grupo.indexed)
                        if (p.chave != _perfilAberto)
                          Positioned(
                            left: j * _passoGrupo,
                            top: 0,
                            width: _ladoSonar,
                            height: _ladoSonar,
                            child: GestureDetector(
                              onTap: () => _abrirPerfilProximo(p),
                              child: SonarPulso(
                                cor: _corPerfil(p),
                                tamanho: 44,
                                // Defasados para não pulsarem todos juntos.
                                atraso: Duration(
                                  milliseconds: _perfis.indexOf(p) * 370,
                                ),
                                child: _avatarMapa(p),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
            ],
            Marker(point: c, width: 52, height: 52, child: _marcadorCliente()),
            // Popover por último: fica por cima de tudo.
            for (final p in _perfis)
              if (p.chave == _perfilAberto && _etapa != _Etapa.encontrado)
                Marker(
                  point: p.posicao,
                  // Mais largo quando deslocado no grupo: o toque no botão
                  // só chega dentro da caixa do marcador.
                  width: 236 + 2 * _deslocamentoNoGrupo(p).abs(),
                  height: 230,
                  alignment: Alignment.topCenter,
                  child: _popoverPerfil(p, dx: _deslocamentoNoGrupo(p)),
                ),
          ],
        ),
      ],
    );
  }

  /// Caixa do sonar de cada bolinha (44 × alcance 2,2).
  static const double _ladoSonar = 98;

  /// Distância entre os centros das bolinhas de um mesmo lugar.
  static const double _passoGrupo = 50;

  /// Chave do "lugar" no mapa: ~11 m (4 casas decimais).
  String _lugar(PerfilProximo p) =>
      '${p.posicao.latitude.toStringAsFixed(4)},'
      '${p.posicao.longitude.toStringAsFixed(4)}';

  List<List<PerfilProximo>> _gruposDePerfis() {
    final grupos = <String, List<PerfilProximo>>{};
    for (final p in _perfis) {
      grupos.putIfAbsent(_lugar(p), () => []).add(p);
    }
    return grupos.values.toList();
  }

  /// Deslocamento horizontal da bolinha dentro do grupo (centralizado).
  double _deslocamentoNoGrupo(PerfilProximo p) {
    final grupo = _perfis.where((x) => _lugar(x) == _lugar(p)).toList();
    final j = grupo.indexWhere((x) => x.chave == p.chave);
    return (j - (grupo.length - 1) / 2) * _passoGrupo;
  }

  Color _corPerfil(PerfilProximo p) =>
      p.ehEmpresa && (p.corTagEmpresa?.isNotEmpty ?? false)
      ? CorOficio.parse(p.corTagEmpresa)
      : _azul;

  /// Popover "Interactive Map Marker with Profile Preview": nome, tag (se for
  /// empresa) e "Ver perfil". A bolinha continua embaixo, no ponto exato.
  Widget _popoverPerfil(PerfilProximo p, {double dx = 0}) {
    final tag = p.ehEmpresa ? p.tagFormatada : null;
    final cor = _corPerfil(p);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.translate(
        // A bolinha (44) fica no ponto do mapa (deslocada se estiver em grupo).
        offset: Offset(dx, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.85 + 0.15 * t,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => setState(() => _perfilAberto = null),
              child: _avatarMapa(p, destacado: true),
            ),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 228,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _fotoOuIniciais(p, 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _texto,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (tag != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      color: cor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  '${p.ehEmpresa ? 'Empresa' : 'Profissional'}'
                                  ' • ${p.distanciaKm.toStringAsFixed(1).replaceAll('.', ',')} km',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textoSec,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: FilledButton.icon(
                    onPressed: () => _verPerfil(p),
                    icon: Icon(
                      p.ehEmpresa
                          ? Icons.storefront_outlined
                          : Icons.person_outline_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'Ver perfil',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _azul,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Setinha apontando para a bolinha.
          CustomPaint(size: const Size(18, 9), painter: _SetaPopover()),
        ],
      ),
    );
  }

  /// Pin do profissional que aceitou, com o rótulo do status (1º design).
  Widget _marcadorProfissionalEncontrado() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            _rotuloStatus(_acomp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _texto,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Icon(Icons.location_on, color: Color(0xFF4B5563), size: 34),
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
  Widget _avatarMapa(PerfilProximo p, {bool destacado = false}) {
    final corBorda = _corPerfil(p);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: corBorda, width: destacado ? 3 : 2.5),
        boxShadow: [
          BoxShadow(
            color: destacado
                ? corBorda.withValues(alpha: 0.45)
                : const Color(0x33000000),
            blurRadius: destacado ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: _fotoOuIniciais(p, 35),
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
    _bloquearEnvioPorUmInstante();
    if (escolhida == null || !mounted) return;
    setState(() {
      _funcao = escolhida;
      _erroArea = null;
    });
    await _carregarPerfis();
  }

  /// Bottom sheet estilizado com os 4 métodos de realização.
  Future<void> _escolherMetodo() async {
    FocusScope.of(context).unfocus();
    final escolhido = await showModalBottomSheet<MetodoEntregaGeo>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
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
                Center(child: _alca()),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _iconeRedondo(Icons.route_outlined, tamanho: 42),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Método de realização',
                            style: TextStyle(
                              color: _texto,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Como você quer que o serviço seja feito?',
                            style: TextStyle(color: _textoSec, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final m in MetodoEntregaGeo.todos) ...[
                  _opcaoMetodo(
                    m,
                    selecionado: m.valor == _metodo?.valor,
                    aoTocar: () => Navigator.pop(ctx, m),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    _bloquearEnvioPorUmInstante();
    if (escolhido == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _metodo = escolhido;
      _erroMetodo = null;
    });
  }

  Widget _opcaoMetodo(
    MetodoEntregaGeo m, {
    required bool selecionado,
    required VoidCallback aoTocar,
  }) {
    return Material(
      color: selecionado ? _azulClaro : _fundoCampo,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: aoTocar,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selecionado ? _azul : _bordaCampo,
              width: selecionado ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selecionado ? _azul : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selecionado
                      ? [
                          BoxShadow(
                            color: _azul.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  m.icone,
                  color: selecionado ? Colors.white : _azul,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.valor,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      m.descricao,
                      style: const TextStyle(
                        color: _textoSec,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selecionado
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  key: ValueKey(selecionado),
                  color: selecionado ? _azul : const Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Ações do "Profissional Encontrado" ──────────────────────────────────

  String _rotuloStatus(AcompanhamentoGeo? a) {
    switch (a?.idStatus) {
      case StatusSolicitacaoVinculada.aberto:
        return 'Aguardando confirmação';
      case StatusSolicitacaoVinculada.aguardandoPagamento:
        return 'Aguardando pagamento';
      case 3:
        return 'Pago';
      case null:
        return 'Aguardando profissional';
    }
    final s = a?.status?.trim() ?? '';
    return s.isNotEmpty ? s : 'Em andamento';
  }

  double? _distanciaKm() {
    final c = _centro;
    final p = _acomp?.posicao;
    if (c == null || p == null) return null;
    return const Distance().as(LengthUnit.Meter, c, p) / 1000;
  }

  String _formatarValor(double v) {
    final partes = v.toStringAsFixed(2).split('.');
    final inteiro = partes[0];
    final b = StringBuffer();
    for (var i = 0; i < inteiro.length; i++) {
      if (i > 0 && (inteiro.length - i) % 3 == 0) b.write('.');
      b.write(inteiro[i]);
    }
    return 'R\$ $b,${partes[1]}';
  }

  Future<void> _abrirPagamento() async {
    final a = _acomp;
    if (a == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PagamentoPedidoPage(
          idSolicitacao: a.idSolicitacao,
          tituloServico: _titulo.text.trim().isNotEmpty
              ? _titulo.text.trim()
              : (_funcao?.funcao ?? 'Serviço'),
          profissional: a.nome,
          valor: a.valor,
        ),
      ),
    );
    if (mounted) await _atualizarAcompanhamento();
  }

  Future<void> _abrirAcompanhamento() async {
    final a = _acomp;
    if (a == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalhesPedidoPage(idSolicitacao: a.idSolicitacao),
      ),
    );
    if (mounted) await _atualizarAcompanhamento();
  }

  void _abrirChat({String? mensagemInicial}) {
    final a = _acomp;
    if (a == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaChatProfissional(
          nomeProfissional: a.nome,
          fotoProfissional: a.fotoUrl ?? '',
          oficioPrincipal: _funcao?.funcao ?? 'Atendimento',
          idProfissional: a.ehEmpresa ? null : a.idProfissional,
          idGrupoEmpresa: a.ehEmpresa ? a.idGrupoEmpresa : null,
          idSolicitacao: a.idSolicitacao,
          mensagemInicial: mensagemInicial,
        ),
      ),
    );
  }

  /// Mensagens rápidas: abre o chat com o texto já digitado.
  Future<void> _notificar() async {
    const opcoes = <(IconData, String, String)>[
      (
        Icons.home_outlined,
        'Estou em casa',
        'Olá! Já estou em casa, pode vir quando quiser.',
      ),
      (
        Icons.schedule_outlined,
        'Combinar horário',
        'Olá! Qual o melhor horário para fazermos o serviço?',
      ),
      (
        Icons.help_outline_rounded,
        'Dúvida sobre o orçamento',
        'Olá! Tenho uma dúvida sobre o valor do serviço.',
      ),
    ];
    final texto = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _alca()),
              const SizedBox(height: 16),
              Text(
                'Notificar ${_acomp?.nome ?? 'profissional'}',
                style: const TextStyle(
                  color: _texto,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Escolha uma mensagem rápida; ela abre no chat pronta para enviar.',
                style: TextStyle(color: _textoSec, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              for (final (icone, titulo, mensagem) in opcoes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _iconeRedondo(icone, tamanho: 38),
                  title: Text(
                    titulo,
                    style: const TextStyle(
                      color: _texto,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    mensagem,
                    style: const TextStyle(color: _textoSec, fontSize: 12.5),
                  ),
                  onTap: () => Navigator.pop(ctx, mensagem),
                ),
            ],
          ),
        ),
      ),
    );
    if (texto != null && mounted) _abrirChat(mensagemInicial: texto);
  }

  Future<void> _cancelarAposAceite() async {
    final ok = await _confirmar(
      titulo: 'Cancelar solicitação?',
      texto:
          'O profissional já aceitou o seu pedido. Se cancelar agora, o '
          'serviço não será realizado.',
      botao: 'Cancelar solicitação',
    );
    if (ok == true) await _cancelarSolicitacao();
  }

  Future<void> _anexarImagens() async {
    _desfocar();
    try {
      final novas = await _picker.pickMultiImage(
        imageQuality: 75,
        maxWidth: 1600,
      );
      _bloquearEnvioPorUmInstante();
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
      _erroMetodo = _metodo == null ? 'Escolha o método de realização.' : null;
      _erroDescricao = _descricao.text.trim().isEmpty
          ? 'Descreva o que você precisa.'
          : null;
      _erroImagem = _imagens.isEmpty ? 'Anexe pelo menos uma imagem.' : null;
    });
    return _erroTitulo == null &&
        _erroArea == null &&
        _erroMetodo == null &&
        _erroDescricao == null &&
        _erroImagem == null;
  }

  /// Todos os campos e pelo menos uma imagem: só então o botão libera.
  bool get _formularioCompleto =>
      _titulo.text.trim().isNotEmpty &&
      _funcao != null &&
      _metodo != null &&
      _descricao.text.trim().isNotEmpty &&
      _imagens.isNotEmpty;

  /// Enquanto um bottom sheet (área / método) ou a galeria fecha, o Flutter
  /// deixa os toques passarem para a tela de baixo. O botão "Enviar" fica bem
  /// embaixo das opções, então um 2º toque rápido enviava o pedido. Toques
  /// no botão até este instante são ignorados.
  DateTime _ignorarEnvioAte = DateTime.fromMillisecondsSinceEpoch(0);

  void _bloquearEnvioPorUmInstante() {
    _ignorarEnvioAte = DateTime.now().add(const Duration(milliseconds: 700));
  }

  void _desfocar() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _enviarSolicitacao() async {
    if (DateTime.now().isBefore(_ignorarEnvioAte)) return;
    if (_etapa != _Etapa.formulario || !_formularioCompleto) return;
    _desfocar();
    if (!_validar()) return;
    final centro = _centro;
    final funcao = _funcao;
    final metodo = _metodo;
    if (centro == null || funcao == null || metodo == null) return;

    HapticFeedback.lightImpact();
    setState(() {
      _etapa = _Etapa.solicitando;
      _minimizado = false;
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
        metodoEntrega: metodo.valor,
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
    _agendarConsulta();
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
    _consulta?.cancel();
    setState(() {
      _idSolicitacao = null;
      _acomp = null;
      _imagensSalvas = [];
      _expandido = false;
      _minimizado = false;
      _etapa = _Etapa.formulario;
      if (!manterDados) {
        _titulo.clear();
        _descricao.clear();
        _imagens.clear();
        _funcao = null;
        _metodo = null;
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

  void _minimizar() {
    if (_etapa == _Etapa.solicitando || _minimizado) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      _minimizado = true;
      _expandido = false;
    });
    _enquadrarDepoisDaAnimacao();
  }

  void _restaurar() {
    if (!_minimizado) return;
    HapticFeedback.selectionClick();
    setState(() => _minimizado = false);
    _enquadrarDepoisDaAnimacao();
  }

  void _enquadrarDepoisDaAnimacao() {
    Future.delayed(_dur, () {
      if (mounted) _enquadrarMapa();
    });
  }

  /// Deslocamento do sheet enquanto o dedo arrasta (positivo = para baixo).
  double _arraste = 0;
  bool _arrastando = false;

  void _aoComecarArraste(DragStartDetails _) {
    // Sem isso o cursor do campo em edição "sobe" junto com o sheet.
    _desfocar();
    setState(() => _arrastando = true);
  }

  void _aoAtualizarArraste(DragUpdateDetails d) {
    if (_etapa == _Etapa.solicitando) return;
    setState(() => _arraste = math.max(-80, _arraste + d.delta.dy));
  }

  /// Soltou: para baixo minimiza (ou recolhe o painel); para cima restaura
  /// (ou expande o "aguardando"). Decide pela distância ou pela velocidade.
  void _aoArrastarSheet(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final desceu = v > 150 || _arraste > 70;
    final subiu = v < -150 || _arraste < -35;
    setState(() {
      _arrastando = false;
      _arraste = 0;
    });
    if (desceu) {
      if (_expandido) {
        setState(() => _expandido = false);
      } else {
        _minimizar();
      }
    } else if (subiu) {
      if (_minimizado) {
        _restaurar();
      } else if (_etapa == _Etapa.aguardando) {
        setState(() => _expandido = true);
      }
    }
  }

  /// Área que responde ao arraste do sheet (alça, cabeçalho, barra mínima).
  Widget _areaArrastavel({required Widget child, VoidCallback? aoTocar}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      onVerticalDragStart: _aoComecarArraste,
      onVerticalDragUpdate: _aoAtualizarArraste,
      onVerticalDragEnd: _aoArrastarSheet,
      child: child,
    );
  }

  /// Toque no mapa: fecha o popover; se não houver, minimiza o sheet.
  void _aoTocarMapa() {
    _desfocar();
    if (_perfilAberto != null) {
      setState(() => _perfilAberto = null);
      return;
    }
    if (_expandido) {
      setState(() => _expandido = false);
      return;
    }
    if (!_minimizado &&
        (_etapa == _Etapa.formulario || _etapa == _Etapa.aguardando)) {
      _minimizar();
    }
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
              const SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CreditoMapa(),
                  ),
                ),
              ),
              if (_avisoMapa != null &&
                  _etapa != _Etapa.encontrado &&
                  !_expandido)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(64, 16, 16, 0),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: _azul,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _avisoMapa!,
                                style: const TextStyle(
                                  color: _texto,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
    width: 44,
    height: 5,
    decoration: BoxDecoration(
      color: const Color(0xFFD5DCE4),
      borderRadius: BorderRadius.circular(4),
    ),
  );

  /// Alça com área de toque generosa: arrastar para baixo minimiza.
  Widget _alcaArrastavel({VoidCallback? aoTocar}) {
    return _areaArrastavel(
      aoTocar: aoTocar,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Center(child: _alca()),
      ),
    );
  }

  Widget _buildSheet(double altura) {
    final Widget conteudo;
    final String chave;
    if (_minimizado && _etapa != _Etapa.solicitando) {
      conteudo = _conteudoMinimizado();
      chave = 'minimizado';
    } else {
      conteudo = switch (_etapa) {
        _Etapa.formulario => _conteudoFormulario(altura),
        _Etapa.solicitando => _conteudoSolicitando(),
        _Etapa.aguardando =>
          _expandido ? _conteudoExpandido(altura) : _conteudoAguardando(),
        _Etapa.encontrado => _conteudoEncontrado(altura),
      };
      chave = switch (_etapa) {
        _Etapa.formulario => 'form',
        _Etapa.solicitando => 'solicitando',
        _Etapa.aguardando => _expandido ? 'expandido' : 'aguardando',
        _Etapa.encontrado => 'encontrado',
      };
    }

    // Acompanha o dedo durante o arraste; para cima com resistência.
    final dy = _arraste > 0 ? _arraste : _arraste * 0.35;
    return AnimatedContainer(
      duration: _arrastando ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, dy, 0),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color(0x290FB3FF),
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Stack(
          children: [
            // Faixa azul fina no topo do sheet.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0FB3FF), Color(0xFF6FD3FF)],
                  ),
                ),
              ),
            ),
            AnimatedSize(
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
          ],
        ),
      ),
    );
  }

  /// Sheet minimizado: só uma barra; o mapa ocupa a tela inteira.
  Widget _conteudoMinimizado() {
    final aguardando = _etapa == _Etapa.aguardando;
    final encontrado = _etapa == _Etapa.encontrado;
    return _areaArrastavel(
      aoTocar: _restaurar,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _alca(),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (encontrado)
                    _iconeRedondo(Icons.verified_rounded)
                  else if (aguardando)
                    const CarregamentoSegmentado(
                      icone: Icons.search,
                      tamanho: 40,
                    )
                  else
                    _iconeRedondo(Icons.sensors),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          encontrado
                              ? 'Profissional Encontrado!'
                              : aguardando
                              ? 'Aguardando profissionais próximos'
                              : 'Novo pedido no Radar',
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
                          encontrado
                              ? '${_acomp?.nome ?? 'Profissional'} • ${_rotuloStatus(_acomp)}'
                              : aguardando
                              ? (_titulo.text.trim().isNotEmpty
                                    ? _titulo.text.trim()
                                    : 'Toque para ver o seu pedido')
                              : 'Toque ou arraste para cima para continuar',
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
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: _azulClaro,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: _azul,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconeRedondo(IconData icone, {double tamanho = 40}) => Container(
    width: tamanho,
    height: tamanho,
    decoration: const BoxDecoration(color: _azulClaro, shape: BoxShape.circle),
    child: Icon(icone, color: _azul, size: tamanho * 0.52),
  );

  // ── Etapa 1: formulário (1º design) ───────────────────────────────────────

  Widget _conteudoFormulario(double altura) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: math.max(280, altura * 0.66 - teclado * 0.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Alça + cabeçalho "Novo pedido no Radar": arrastar sobe/desce.
          _areaArrastavel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Center(child: _alca()),
                ),
                _cabecalhoFormulario(),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _rotulo('Título do pedido', Icons.edit_note_rounded),
                  const SizedBox(height: 8),
                  _campoTitulo(),
                  _textoErro(_erroTitulo),
                  const SizedBox(height: 18),
                  _rotulo('Área do Pedido', Icons.handyman_outlined),
                  const SizedBox(height: 8),
                  _seletorArea(),
                  _textoErro(_erroArea),
                  const SizedBox(height: 18),
                  _rotulo('Método de realização', Icons.route_outlined),
                  const SizedBox(height: 8),
                  _seletorMetodo(),
                  _textoErro(_erroMetodo),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _rotulo('Descrição do pedido', Icons.notes_rounded),
                      const Spacer(),
                      _contador(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _campoDescricao(),
                  _textoErro(_erroDescricao),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _rotulo('Anexar Imagens', Icons.photo_library_outlined),
                      const Spacer(),
                      Text(
                        '${_imagens.length}/6',
                        style: TextStyle(
                          color: _imagens.isEmpty ? _textoSec : _azul,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _areaAnexo(),
                  _textoErro(_erroImagem),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEFF2F6))),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: _botaoPrincipal(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecalhoFormulario() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(
        children: [
          _iconeRedondo(Icons.sensors, tamanho: 44),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Novo pedido no Radar',
                  style: TextStyle(
                    color: _texto,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Profissionais da área perto de você vão ver o pedido',
                  style: TextStyle(color: _textoSec, fontSize: 12.5),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _azul,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radar, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  '5 km',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Cinza e bloqueado até preencher tudo e anexar pelo menos uma imagem.
  Widget _botaoPrincipal() {
    final liberado = _formularioCompleto;
    final corTexto = liberado ? Colors.white : const Color(0xFF9CA3AF);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: liberado ? null : const Color(0xFFE5E7EB),
        gradient: liberado
            ? const LinearGradient(
                colors: [Color(0xFF0FB3FF), Color(0xFF0A98E0)],
              )
            : null,
        boxShadow: liberado
            ? [
                BoxShadow(
                  color: _azul.withValues(alpha: 0.38),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: liberado ? _enviarSolicitacao : null,
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!liberado) ...[
                  Icon(Icons.lock_outline_rounded, color: corTexto, size: 17),
                  const SizedBox(width: 8),
                ],
                Text(
                  'Enviar Solicitação',
                  style: TextStyle(
                    color: corTexto,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (liberado) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rotulo(String texto, IconData icone) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icone, color: _azul, size: 18),
      const SizedBox(width: 6),
      Text(
        texto,
        style: const TextStyle(
          color: _texto,
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );

  Widget _contador() {
    final n = _descricao.text.length;
    final cor = n >= _maxDescricao - 20
        ? _vermelho
        : (n > 0 ? _azul : _textoSec);
    return Text(
      '$n/$_maxDescricao',
      style: TextStyle(color: cor, fontSize: 12.5, fontWeight: FontWeight.w600),
    );
  }

  Widget _textoErro(String? erro) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    child: erro == null
        ? const SizedBox.shrink()
        : Padding(
            key: ValueKey(erro),
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: _vermelho, size: 14),
                const SizedBox(width: 4),
                Text(
                  erro,
                  style: const TextStyle(color: _vermelho, fontSize: 12),
                ),
              ],
            ),
          ),
  );

  /// Decoração comum dos campos (fundo suave, foco em #0FB3FF).
  InputDecoration _decoracaoCampo({
    required String dica,
    required bool erro,
    EdgeInsets? padding,
  }) {
    OutlineInputBorder borda(Color cor, [double largura = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cor, width: largura),
        );
    return InputDecoration(
      counterText: '',
      hintText: dica,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14.5),
      filled: true,
      fillColor: _fundoCampo,
      contentPadding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: borda(erro ? _vermelho : _bordaCampo),
      focusedBorder: borda(_azul, 1.6),
    );
  }

  Widget _seletorArea() {
    final f = _funcao;
    final selecionada = f != null;
    return Material(
      color: selecionada ? _azulClaro : _fundoCampo,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _escolherArea,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _erroArea != null
                  ? _vermelho
                  : (selecionada ? _azul : _bordaCampo),
              width: selecionada ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selecionada ? _azul : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: selecionada
                    ? IconeOficio.imagemPorFuncao(f.funcao, tamanho: 22)
                    : const Icon(
                        Icons.category_outlined,
                        color: _textoSec,
                        size: 19,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  f?.funcao ?? 'Selecione uma área...',
                  style: TextStyle(
                    color: selecionada ? _texto : const Color(0xFF6B7280),
                    fontSize: 15,
                    fontWeight: selecionada ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: selecionada ? _azul : _textoSec,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seletorMetodo() {
    final m = _metodo;
    final selecionado = m != null;
    return Material(
      color: selecionado ? _azulClaro : _fundoCampo,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _escolherMetodo,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _erroMetodo != null
                  ? _vermelho
                  : (selecionado ? _azul : _bordaCampo),
              width: selecionado ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selecionado ? _azul : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  m?.icone ?? Icons.route_outlined,
                  color: selecionado ? Colors.white : _textoSec,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  m?.valor ?? 'Selecione como será feito...',
                  style: TextStyle(
                    color: selecionado ? _texto : const Color(0xFF6B7280),
                    fontSize: 15,
                    fontWeight: selecionado ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: selecionado ? _azul : _textoSec,
              ),
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
      // Tocar fora do campo tira o foco (o cursor não fica "preso").
      onTapOutside: (_) => _desfocar(),
      decoration: _decoracaoCampo(
        dica: 'Ex.: Instalação de ar-condicionado',
        erro: _erroTitulo != null,
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
      onTapOutside: (_) => _desfocar(),
      onChanged: (_) {
        if (_erroDescricao != null) setState(() => _erroDescricao = null);
      },
      decoration: _decoracaoCampo(
        dica: 'Descreva com detalhes o que você precisa...',
        erro: _erroDescricao != null,
        padding: const EdgeInsets.all(14),
      ),
    );
  }

  Widget _areaAnexo() {
    final cheio = _imagens.length >= 6;
    return Column(
      children: [
        Material(
          color: _erroImagem != null
              ? const Color(0xFFFEF2F2)
              : const Color(0xFFF0FAFF),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: cheio ? null : _anexarImagens,
            child: CustomPaint(
              painter: _BordaTracejada(
                cor: _erroImagem != null
                    ? _vermelho
                    : _azul.withValues(alpha: 0.55),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _azul.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: math.pi / 4,
                        child: const Icon(Icons.attach_file, color: _azul),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      cheio
                          ? 'Limite de 6 imagens'
                          : 'Toque para anexar imagens',
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Fotos do problema ajudam o profissional a avaliar',
                      style: TextStyle(color: _textoSec, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_imagens.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _imagens.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _azul, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: kIsWeb
                          ? Image.network(
                              _imagens[i].path,
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_imagens[i].path),
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
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
    return _areaArrastavel(
      aoTocar: () => setState(() => _expandido = true),
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

  // ── Profissional encontrado (design "Profissional Encontrado!") ─────────

  Widget _conteudoEncontrado(double altura) {
    final a = _acomp;
    if (a == null) return const SizedBox(height: 160);
    final podeAcompanhar = StatusSolicitacaoVinculada.podeAcompanhar(
      a.idStatus,
    );
    final aguardandoPagamento =
        a.idStatus == StatusSolicitacaoVinculada.aguardandoPagamento;
    final podeCancelar =
        a.idStatus == StatusSolicitacaoVinculada.aberto || aguardandoPagamento;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: altura * 0.8),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _alcaArrastavel(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cabecalhoEncontrado(a),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Divider(height: 1, color: _borda),
                    ),
                    _cardProfissionalEncontrado(a),
                    const SizedBox(height: 12),
                    _cardServicoEncontrado(a),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _botaoContorno(
                            icone: Icons.chat_outlined,
                            texto: 'Conversar no Chat',
                            aoTocar: _abrirChat,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _botaoContorno(
                            icone: Icons.phone_in_talk_outlined,
                            texto: 'Notificar',
                            aoTocar: _notificar,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (aguardandoPagamento)
                      _botaoCheio(
                        icone: Icons.payments_outlined,
                        texto: 'Pagar Solicitação',
                        aoTocar: _abrirPagamento,
                      )
                    else if (podeAcompanhar)
                      _botaoCheio(
                        icone: Icons.navigation_rounded,
                        texto: 'Acompanhar em Tempo Real',
                        aoTocar: _abrirAcompanhamento,
                      )
                    else
                      _botaoCheio(
                        icone: Icons.hourglass_top_rounded,
                        texto: 'Aguardando confirmação',
                        aoTocar: null,
                      ),
                    if (podeCancelar) ...[
                      const SizedBox(height: 14),
                      Center(
                        child: GestureDetector(
                          onTap: _cancelarAposAceite,
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(color: _textoSec, fontSize: 13),
                              children: [
                                TextSpan(text: 'Precisa cancelar? '),
                                TextSpan(
                                  text: 'Cancelar Solicitação',
                                  style: TextStyle(
                                    color: _texto,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecalhoEncontrado(AcompanhamentoGeo a) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: _azulClaro,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: _azul,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profissional Encontrado!',
                style: TextStyle(
                  color: _texto,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Serviço aceito • ${_rotuloStatus(a)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _textoSec, fontSize: 12.5),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD1D5DB)),
          ),
          child: const Text(
            'ConsertaJá',
            style: TextStyle(
              color: _texto,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardProfissionalEncontrado(AcompanhamentoGeo a) {
    final tag = a.tagFormatada;
    final corTag = (a.corTagEmpresa?.isNotEmpty ?? false)
        ? CorOficio.parse(a.corTagEmpresa)
        : _azul;
    final dist = _distanciaKm();
    final foto = a.fotoUrl?.trim() ?? '';
    final iniciais = Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(color: _azul, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(a.nome),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cinzaCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  foto.isEmpty || foto == 'null'
                      ? iniciais
                      : ClipOval(
                          child: Image.network(
                            foto,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => iniciais,
                          ),
                        ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: _azul,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          a.ehEmpresa
                              ? Icons.storefront_rounded
                              : Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF59E0B),
                          size: 16,
                        ),
                        Text(
                          a.nota != null ? a.nota!.toStringAsFixed(1) : 'Novo',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '(${a.totalAvaliacoes} '
                          '${a.totalAvaliacoes == 1 ? 'avaliação' : 'avaliações'})',
                          style: const TextStyle(
                            color: _textoSec,
                            fontSize: 12.5,
                          ),
                        ),
                        // Tag só para empresa (grupo_empresa), com a cor dela.
                        if (tag != null) ...[
                          const Text(
                            '•',
                            style: TextStyle(color: _textoSec, fontSize: 12.5),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: corTag.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: corTag,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE2E5EA)),
          ),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: _azul, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _rotuloStatus(a),
                  style: const TextStyle(color: _textoSec, fontSize: 13),
                ),
              ),
              if (dist != null)
                Text(
                  '${dist.toStringAsFixed(1).replaceAll('.', ',')} km de distância',
                  style: const TextStyle(
                    color: _texto,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardServicoEncontrado(AcompanhamentoGeo a) {
    final area = _funcao?.funcao ?? 'Serviço';
    final titulo = _titulo.text.trim().isNotEmpty ? _titulo.text.trim() : area;
    final metodo = _metodo?.valor ?? a.tipoExecucao;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cinzaCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _texto,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    area,
                    if (metodo != null && metodo.isNotEmpty) metodo,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textoSec, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatarValor(a.valor),
                style: const TextStyle(
                  color: _azul,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Valor estimado',
                style: TextStyle(color: _textoSec, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _botaoContorno({
    required IconData icone,
    required String texto,
    required VoidCallback aoTocar,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: aoTocar,
        icon: Icon(icone, size: 18, color: _azul),
        label: Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _texto,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Widget _botaoCheio({
    required IconData icone,
    required String texto,
    required VoidCallback? aoTocar,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: aoTocar,
        icon: Icon(icone, size: 20),
        label: Text(
          texto,
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _azul,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _azul.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
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
                      [area, if (_metodo != null) _metodo!.valor].join(' • '),
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

/// Setinha branca embaixo do popover do perfil.
class _SetaPopover extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final caminho = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(caminho, Colors.black26, 2, false);
    canvas.drawPath(caminho, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SetaPopover old) => false;
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
