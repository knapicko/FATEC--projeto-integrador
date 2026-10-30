import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'gestao_equipe.dart';
import 'tela_chat_profissional.dart';
import 'tela_meu_perfil_profissional.dart';
import 'tela_recebe_devolucao_profissional.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'utils/iniciais.dart';

/// Configuração do Mapbox
class MapboxConfig {
  static const String mapboxAccessTokenPadrao =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  static const String estiloPadrao = 'navigation-day-v1';
}

class TelaDeslocamentoProfissionalPage extends StatefulWidget {
  const TelaDeslocamentoProfissionalPage({
    super.key,
    required this.idSolicitacao,
    required this.destino,
    required this.enderecoPrincipal,
    required this.enderecoComplementar,
    required this.nomeCliente,
    this.fotoCliente,
    required this.categoria,
    required this.codigoPedido,
  });

  final int idSolicitacao;
  final LatLng destino;
  final String enderecoPrincipal;
  final String enderecoComplementar;
  final String nomeCliente;
  final String? fotoCliente;
  final String categoria;
  final String codigoPedido;

  @override
  State<TelaDeslocamentoProfissionalPage> createState() =>
      _TelaDeslocamentoProfissionalPageState();
}

class _TelaDeslocamentoProfissionalPageState
    extends State<TelaDeslocamentoProfissionalPage> {
  static const Color azul = Color(0xFF0FB3FF);
  static const Color escuroTexto = Color(0xFF0F172A);
  static const Color cinzaTexto = Color(0xFF64748B);

  final supabase = Supabase.instance.client;
  final MapController mapa = MapController();

  StreamSubscription<Position>? _posicao;
  LatLng? _atual;
  DateTime? _ultimoMomentoGps;
  LatLng? _ultimaPosicaoGps;

  List<LatLng> _rota = [];
  double? _distancia;
  int? _duracao;
  double _velocidadeAtual = 0.0;
  double _bearing = 0.0;
  bool _pausada = false;

  // Persistent Bottom Sheet expandida/recolhida (inicia fechada conforme solicitado)
  bool _painelExpandido = false;

  // Mapbox Token e Estilo
  String _mapboxToken = MapboxConfig.mapboxAccessTokenPadrao;
  final String _mapboxStyleId = MapboxConfig.estiloPadrao;

  // Turn-by-Turn / Orientações Waze
  String _proximaManobraTexto = 'Siga em frente';
  IconData _proximaManobraIcone = Icons.straight_rounded;
  int _proximaManobraDistancia = 350;
  String _proximoLogradouro = '';

  // Dados reais da solicitação e do cliente
  late LatLng _destinoCoordenadas;
  late String _enderecoPrincipal;
  late String _enderecoComplementar;
  late String _nomeCliente;
  String? _fotoCliente;
  late String _categoriaServico;
  String _tituloServico = '';
  late String _codigoPedido;
  String _complemento = '';
  String _bairro = '';
  String _numero = '';
  String? _horaAgendada;
  String? _horaAgendadaFim;

  int? _idProfissional;
  int? _idGrupoEmpresa;

  // Distinção: Empresa/Loja vs Autônomo
  bool _isEmpresa = false;
  String? _fotoPerfilProfissional;
  String? _nomeProfissional;

  @override
  void initState() {
    super.initState();
    // Destino é rigorosamente o endereço do cliente
    _destinoCoordenadas = widget.destino;
    _enderecoPrincipal = widget.enderecoPrincipal;
    _enderecoComplementar = widget.enderecoComplementar;
    _nomeCliente = widget.nomeCliente;
    _fotoCliente = widget.fotoCliente;
    _categoriaServico = widget.categoria;
    _codigoPedido = widget.codigoPedido;
    _proximoLogradouro = widget.enderecoPrincipal.split(',').first.trim();

    _isEmpresa = BottomNavigationBarProfissional.leituraSincronaContaEmpresa();

    _carregarConfiguracoesMapbox();
    _carregarDadosProfissionalLogado();
    _carregarDadosSupabaseSolicitacao();
    _iniciarLocalizacao();
  }

  @override
  void dispose() {
    _posicao?.cancel();
    super.dispose();
  }

  Future<void> _carregarConfiguracoesMapbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tokenSalvo = prefs.getString('mapbox_access_token');
      if (tokenSalvo != null && tokenSalvo.trim().isNotEmpty) {
        _mapboxToken = tokenSalvo.trim();
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  /// Distingue se é Loja (grupo_empresa) ou Independente na tabela 'solicitacoes'
  Future<void> _carregarDadosProfissionalLogado() async {
    try {
      final sol = await supabase
          .from('solicitacoes')
          .select('fk_grupo_empresa, fk_profissional')
          .eq('id_solicitacao', widget.idSolicitacao)
          .maybeSingle();

      final fkGrupo = (sol?['fk_grupo_empresa'] as num?)?.toInt();
      final fkProf = (sol?['fk_profissional'] as num?)?.toInt();

      String? fotoProf;
      String? nomeProf;
      bool ehEmpresa = fkGrupo != null;

      // 1. Se tiver fk_grupo_empresa na tabela 'solicitacoes', é Empresa / Loja
      if (fkGrupo != null) {
        _idGrupoEmpresa = fkGrupo;
        ehEmpresa = true;
        final emp = await supabase
            .from('grupo_empresa')
            .select('nome_empresa, foto_url_empresa')
            .eq('id_grupo_empresa', fkGrupo)
            .maybeSingle();
        if (emp != null) {
          nomeProf = emp['nome_empresa']?.toString().trim();
          final f = emp['foto_url_empresa']?.toString().trim();
          if (f != null && f.isNotEmpty) fotoProf = f;
        }
      }

      // 2. Se for profissional independente (ou para pegar dados do autônomo logado)
      if (!ehEmpresa) {
        final user = supabase.auth.currentUser;
        if (user != null) {
          final u = await supabase
              .from('usuarios')
              .select('id_usuario, nome, foto_perfil_url')
              .eq('auth_id', user.id)
              .maybeSingle();
          if (u != null) {
            nomeProf ??= u['nome']?.toString().trim();
            final f = u['foto_perfil_url']?.toString().trim();
            if (f != null && f.isNotEmpty) fotoProf = f;
          }
        }

        // Caso ainda não tenha foto, busca pelo fk_profissional da solicitação
        if ((fotoProf == null || fotoProf.isEmpty) && fkProf != null) {
          _idProfissional = fkProf;
          final prof = await supabase
              .from('profissionais')
              .select('fk_usuario')
              .eq('id_profissional', fkProf)
              .maybeSingle();
          final idU = (prof?['fk_usuario'] as num?)?.toInt();
          if (idU != null) {
            final u = await supabase
                .from('usuarios')
                .select('nome, foto_perfil_url')
                .eq('id_usuario', idU)
                .maybeSingle();
            if (u != null) {
              nomeProf ??= u['nome']?.toString().trim();
              final f = u['foto_perfil_url']?.toString().trim();
              if (f != null && f.isNotEmpty) fotoProf = f;
            }
          }
        }
      }

      // 3. Fallback adicional se BottomNavigationBar indicar conta empresa
      if ((fotoProf == null || fotoProf.isEmpty) &&
          BottomNavigationBarProfissional.leituraSincronaContaEmpresa()) {
        final user = supabase.auth.currentUser;
        if (user != null) {
          final u = await supabase
              .from('usuarios')
              .select('id_usuario')
              .eq('auth_id', user.id)
              .maybeSingle();
          final idU = (u?['id_usuario'] as num?)?.toInt();
          if (idU != null) {
            final dp = await supabase
                .from('dados_profissionais')
                .select('fk_grupo_empresa')
                .eq('fk_usuario', idU)
                .maybeSingle();
            final idG = (dp?['fk_grupo_empresa'] as num?)?.toInt();
            if (idG != null) {
              _idGrupoEmpresa = idG;
              ehEmpresa = true;
              final grupo = await supabase
                  .from('grupo_empresa')
                  .select('nome_empresa, foto_url_empresa')
                  .eq('id_grupo_empresa', idG)
                  .maybeSingle();
              if (grupo != null) {
                nomeProf = grupo['nome_empresa']?.toString().trim();
                final f = grupo['foto_url_empresa']?.toString().trim();
                if (f != null && f.isNotEmpty) fotoProf = f;
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _isEmpresa = ehEmpresa;
          _fotoPerfilProfissional = fotoProf;
          _nomeProfissional = nomeProf;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do profissional logado: $e');
    }
  }

  /// Carrega dados reais da solicitação e dados do cliente / serviço
  Future<void> _carregarDadosSupabaseSolicitacao() async {
    try {
      final sol = await supabase
          .from('solicitacoes')
          .select(
            'id_solicitacao, data_solicitacao, valor_final, detalhes, '
            'data_agendada, hora_agendada, hora_agendada_fim, tipo_execucao, fk_grupo_empresa, '
            'fk_status, etapa_solicitacao, fk_profissional, fk_usuario, fk_endereco, fk_servico_prof, fk_servico_temp',
          )
          .eq('id_solicitacao', widget.idSolicitacao)
          .maybeSingle();

      if (sol == null) return;

      final idCliente = (sol['fk_usuario'] as num?)?.toInt();
      if (sol['fk_grupo_empresa'] != null) {
        _idGrupoEmpresa = (sol['fk_grupo_empresa'] as num?)?.toInt();
      }

      _horaAgendada = sol['hora_agendada']?.toString().trim();
      _horaAgendadaFim = sol['hora_agendada_fim']?.toString().trim();

      _codigoPedido =
          '#PED-2026-${widget.idSolicitacao.toString().padLeft(4, '0')}';

      // 1. Cliente
      if (idCliente != null) {
        final u = await supabase
            .from('usuarios')
            .select('nome, foto_perfil_url')
            .eq('id_usuario', idCliente)
            .maybeSingle();
        if (u != null) {
          final n = u['nome']?.toString().trim() ?? '';
          final f = u['foto_perfil_url']?.toString().trim() ?? '';
          if (n.isNotEmpty) _nomeCliente = n;
          if (f.isNotEmpty) _fotoCliente = f;
        }
      }

      // 2. Serviço / Título
      String nomeServico = '';
      final idServico = (sol['fk_servico_prof'] as num?)?.toInt();
      final idServicoTemp = (sol['fk_servico_temp'] as num?)?.toInt();
      if (idServico != null) {
        final s = await supabase
            .from('servicos_profissional')
            .select('titulo')
            .eq('id_servico_prof', idServico)
            .maybeSingle();
        if (s != null) {
          nomeServico = s['titulo']?.toString().trim() ?? '';
        }
      }
      if (nomeServico.isEmpty && idServicoTemp != null) {
        final st = await supabase
            .from('servicos_chat_temporarios')
            .select('titulo')
            .eq('id_servico_temp', idServicoTemp)
            .maybeSingle();
        if (st != null) {
          nomeServico = st['titulo']?.toString().trim() ?? '';
        }
      }
      if (nomeServico.isEmpty) {
        nomeServico = widget.categoria.isNotEmpty &&
                widget.categoria.toLowerCase() != 'eletricista'
            ? widget.categoria
            : 'Serviço Solicitado';
      }
      _tituloServico = nomeServico;
      _categoriaServico = nomeServico;

      // 3. Endereço completo do CLIENTE (Destino)
      final idEndereco = (sol['fk_endereco'] as num?)?.toInt();
      if (idEndereco != null) {
        final end = await supabase
            .from('enderecos')
            .select(
              'logradouro, numero, complemento, bairro, cidade, estado, cep, latitude, longitude',
            )
            .eq('id_endereco', idEndereco)
            .maybeSingle();

        if (end != null) {
          final rua = end['logradouro']?.toString().trim() ?? '';
          final numStr = end['numero']?.toString().trim() ?? '';
          final comp = end['complemento']?.toString().trim() ?? '';
          final bai = end['bairro']?.toString().trim() ?? '';
          final cid = end['cidade']?.toString().trim() ?? '';
          final uf = end['estado']?.toString().trim() ?? '';

          final lat = double.tryParse(end['latitude']?.toString() ?? '');
          final lon = double.tryParse(end['longitude']?.toString() ?? '');

          _complemento = comp;
          _bairro = bai;
          _numero = numStr;

          if (rua.isNotEmpty) {
            _enderecoPrincipal = numStr.isNotEmpty ? '$rua, $numStr' : rua;
          }
          final compList = <String>[];
          if (bai.isNotEmpty) compList.add(bai);
          if (cid.isNotEmpty) compList.add('$cid - $uf');
          if (comp.isNotEmpty) compList.add(comp);
          if (compList.isNotEmpty) {
            _enderecoComplementar = compList.join(' • ');
          }

          if (lat != null &&
              lon != null &&
              lat.abs() > 0.0001 &&
              lon.abs() > 0.0001) {
            _destinoCoordenadas = LatLng(lat, lon);
          }
        }
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  /// Inicia o monitoramento de localização em altíssima precisão
  Future<void> _iniciarLocalizacao() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Ative o GPS para iniciar a navegação.');
      }
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        throw Exception('Permissão de localização não concedida.');
      }

      // 1. Tenta posição mais recente imediatamente (sem delay)
      final ultimaConhecida = await Geolocator.getLastKnownPosition();
      if (ultimaConhecida != null && mounted) {
        _atualizarPosicao(ultimaConhecida);
      }

      // 2. Obtém a posição atual com precisão máxima para navegação
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );
      _atualizarPosicao(p);

      // Centraliza na posição do profissional
      mapa.move(LatLng(p.latitude, p.longitude), 16.5);

      // 3. Monitoramento contínuo em tempo real (1 metro de sensibilidade)
      _posicao = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1, // Atualiza constantemente a cada 1 metro
        ),
      ).listen(_atualizarPosicao);

      await _atualizarRota(LatLng(p.latitude, p.longitude));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _atualizarPosicao(Position p) {
    final atual = LatLng(p.latitude, p.longitude);
    if (!mounted) return;

    // Cálculo dinâmico e confiável de velocidade em km/h
    double speedKmH = 0.0;
    if (p.speed > 0) {
      speedKmH = p.speed * 3.6;
    } else if (_ultimaPosicaoGps != null && _ultimoMomentoGps != null) {
      final deltaMetros = Geolocator.distanceBetween(
        _ultimaPosicaoGps!.latitude,
        _ultimaPosicaoGps!.longitude,
        atual.latitude,
        atual.longitude,
      );
      final deltaSegundos =
          DateTime.now().difference(_ultimoMomentoGps!).inMilliseconds / 1000.0;
      if (deltaSegundos > 0.4 && deltaMetros > 0.5) {
        speedKmH = (deltaMetros / deltaSegundos) * 3.6;
      }
    }

    // Cálculo da orientação da seta (bearing) com base no heading ou deslocamento
    double bearingAtual = _bearing;
    if (p.heading > 0) {
      bearingAtual = p.heading;
    } else if (_ultimaPosicaoGps != null) {
      final calcB = Geolocator.bearingBetween(
        _ultimaPosicaoGps!.latitude,
        _ultimaPosicaoGps!.longitude,
        atual.latitude,
        atual.longitude,
      );
      if (calcB != 0.0) {
        bearingAtual = (calcB + 360) % 360;
      }
    }

    _ultimaPosicaoGps = atual;
    _ultimoMomentoGps = DateTime.now();

    setState(() {
      _atual = atual;
      _velocidadeAtual = speedKmH.clamp(0.0, 180.0);
      _bearing = bearingAtual;
    });

    if (!_pausada) {
      _atualizarRota(atual);
    }
  }

  /// Traça a rota da ORIGEM (localização do profissional) até o DESTINO (cliente)
  Future<void> _atualizarRota(LatLng origem) async {
    Uri uri;
    final temMapboxToken = _mapboxToken.trim().isNotEmpty;

    if (temMapboxToken) {
      // 1. Mapbox Directions API oficial
      uri = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '${origem.longitude},${origem.latitude};${_destinoCoordenadas.longitude},${_destinoCoordenadas.latitude}'
        '?steps=true&geometries=geojson&overview=full&language=pt&access_token=${_mapboxToken.trim()}',
      );
    } else {
      // 2. Fallback resiliente OSRM
      uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origem.longitude},${origem.latitude};${_destinoCoordenadas.longitude},${_destinoCoordenadas.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );
    }

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        if (temMapboxToken) {
          final uriFallback = Uri.parse(
            'https://router.project-osrm.org/route/v1/driving/'
            '${origem.longitude},${origem.latitude};${_destinoCoordenadas.longitude},${_destinoCoordenadas.latitude}'
            '?overview=full&geometries=geojson&steps=true',
          );
          final fallbackResp = await http.get(uriFallback);
          if (fallbackResp.statusCode != 200) return;
          _processarRespostaRota(jsonDecode(fallbackResp.body));
        }
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _processarRespostaRota(data);
    } catch (_) {}
  }

  void _processarRespostaRota(Map<String, dynamic> data) {
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return;

    final route = routes.first as Map<String, dynamic>;
    final geometry = route['geometry']['coordinates'] as List;
    final dist = (route['distance'] as num?)?.toDouble();
    final dur = (route['duration'] as num?)?.round();

    String manobraTexto = 'Siga em frente';
    IconData manobraIcone = Icons.straight_rounded;
    int manobraDistancia = 350;
    String proximoLogradouro = _proximoLogradouro;

    try {
      final legs = route['legs'] as List?;
      if (legs != null && legs.isNotEmpty) {
        final steps = legs.first['steps'] as List?;
        if (steps != null && steps.isNotEmpty) {
          Map<String, dynamic>? nextStep;
          for (final s in steps) {
            final d = (s['distance'] as num?)?.toDouble() ?? 0;
            if (d > 15) {
              nextStep = s as Map<String, dynamic>;
              break;
            }
          }
          nextStep ??= steps.length > 1
              ? steps[1] as Map<String, dynamic>
              : steps.first as Map<String, dynamic>;

          final stepDist = (nextStep['distance'] as num?)?.round() ?? 350;
          manobraDistancia = stepDist;
          final stepName = nextStep['name']?.toString().trim() ?? '';
          if (stepName.isNotEmpty) proximoLogradouro = stepName;

          final maneuver = nextStep['maneuver'] as Map<String, dynamic>?;
          final type = maneuver?['type']?.toString().toLowerCase() ?? '';
          final modifier =
              maneuver?['modifier']?.toString().toLowerCase() ?? '';
          final instruction = maneuver?['instruction']?.toString();

          if (instruction != null && instruction.trim().isNotEmpty) {
            manobraTexto = instruction.trim();
          }

          if (modifier.contains('sharp right')) {
            manobraIcone = Icons.turn_sharp_right_rounded;
            if (instruction == null) manobraTexto = 'Curva fechada à direita';
          } else if (modifier.contains('slight right')) {
            manobraIcone = Icons.turn_slight_right_rounded;
            if (instruction == null) manobraTexto = 'Curva suave à direita';
          } else if (modifier.contains('right')) {
            manobraIcone = Icons.turn_right_rounded;
            if (instruction == null) manobraTexto = 'Vire à direita';
          } else if (modifier.contains('sharp left')) {
            manobraIcone = Icons.turn_sharp_left_rounded;
            if (instruction == null) manobraTexto = 'Curva fechada à esquerda';
          } else if (modifier.contains('slight left')) {
            manobraIcone = Icons.turn_slight_left_rounded;
            if (instruction == null) manobraTexto = 'Curva suave à esquerda';
          } else if (modifier.contains('left')) {
            manobraIcone = Icons.turn_left_rounded;
            if (instruction == null) manobraTexto = 'Vire à esquerda';
          } else if (modifier.contains('uturn') || type.contains('uturn')) {
            manobraIcone = Icons.u_turn_left_rounded;
            if (instruction == null) manobraTexto = 'Faça o retorno';
          } else if (type.contains('roundabout') ||
              modifier.contains('roundabout')) {
            manobraIcone = Icons.roundabout_right_rounded;
            if (instruction == null) manobraTexto = 'Na rotatória, siga';
          } else if (type.contains('arrive')) {
            manobraIcone = Icons.flag_rounded;
            manobraTexto = 'Destino à frente';
          } else {
            manobraIcone = Icons.straight_rounded;
            if (instruction == null) manobraTexto = 'Siga em frente';
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _rota = geometry
          .map(
            (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
          )
          .toList();
      _distancia = dist;
      _duracao = dur;
      _proximaManobraTexto = manobraTexto;
      _proximaManobraIcone = manobraIcone;
      _proximaManobraDistancia = manobraDistancia;
      _proximoLogradouro = proximoLogradouro;
    });
  }

  Future<void> _aoClicarEstouNoLocal() async {
    final codigo = (1000 + Random().nextInt(9000)).toString();

    try {
      await supabase.from('solicitacoes').update({
        'codigo_rec_dev': codigo,
        'fk_status': 34,
        'etapa_solicitacao': 2,
      }).eq('id_solicitacao', widget.idSolicitacao);
    } catch (e) {
      debugPrint('Erro ao salvar codigo_rec_dev na solicitacao: $e');
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaRecebeDevolucaoProfissionalPage(
          idSolicitacao: widget.idSolicitacao,
          codigoPedido: _codigoPedido,
          nomeCliente: _nomeCliente,
          fotoCliente: _fotoCliente,
          nomeServico:
              _tituloServico.isNotEmpty ? _tituloServico : widget.categoria,
          modalidade:
              widget.categoria.isNotEmpty ? widget.categoria : 'Leva e Traz',
          enderecoPrincipal: _enderecoPrincipal,
          enderecoComplementar: _enderecoComplementar,
          isEmpresa: _isEmpresa,
          idGrupoEmpresa: _idGrupoEmpresa,
          fotoPerfilProfissional: _fotoPerfilProfissional,
          nomeProfissional: _nomeProfissional,
        ),
      ),
    );
  }

  void _aoClicarPerfil() {
    if (_isEmpresa) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const GestaoEquipePage(),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const TelaMeuPerfilProfissionalPage(isVisitante: false),
        ),
      );
    }
  }

  void _abrirChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaChatProfissional(
          nomeProfissional: _nomeCliente,
          fotoProfissional: _fotoCliente ?? '',
          oficioPrincipal: _categoriaServico,
          idProfissional: _isEmpresa ? null : _idProfissional,
          idGrupoEmpresa: _isEmpresa ? _idGrupoEmpresa : null,
          idSolicitacao: widget.idSolicitacao,
          somenteAbrirConversaExistente: false,
        ),
      ),
    );
  }

  /// Centraliza o mapa na seta do profissional
  void _centralizarProfissional() {
    if (_atual != null) {
      mapa.move(_atual!, 16.5);
    } else {
      mapa.move(_destinoCoordenadas, 16.0);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Centralizado na sua posição'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Envia mensagem rápida no chat do cliente
  Future<void> _enviarAvisoRapidoChat(String texto) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final dadosUsuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      final idUsuarioLogado = (dadosUsuario?['id_usuario'] as num?)?.toInt();

      final conversa = await supabase
          .from('conversas')
          .select('id_conversa')
          .eq('fk_solicitacao', widget.idSolicitacao)
          .maybeSingle();

      final int? idConversa = (conversa?['id_conversa'] as num?)?.toInt();

      if (idConversa != null && idUsuarioLogado != null) {
        await supabase.from('mensagens').insert({
          'fk_conversa': idConversa,
          'tipo_mensagem': 'Texto',
          'conteudo': texto,
          'fk_remitente_usuario': idUsuarioLogado,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aviso enviado ao cliente: "$texto"'),
            backgroundColor: azul,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aviso: "$texto"'),
            backgroundColor: azul,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Diálogo de avisar atraso
  void _mostrarDialogoAtraso() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Avisar Atraso ao Cliente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: escuroTexto,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...[
                'Estou com trânsito leve, devo atrasar cerca de 5 a 10 min.',
                'Trânsito intenso na região, previsão de atraso de 15 a 20 min.',
                'Tive um imprevisto no trajeto, atraso estimado de 30 min.',
              ].map(
                (msg) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    title: Text(msg, style: const TextStyle(fontSize: 13.5)),
                    trailing: const Icon(Icons.send_rounded, color: azul, size: 20),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _enviarAvisoRapidoChat(msg);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Formatações auxiliares
  String _duracaoMinutos() {
    if (_duracao == null) return '-- min';
    final m = (_duracao! / 60).round();
    return '$m min';
  }

  String _formatarDistancia(double? metros) {
    if (metros == null) return '-- km';
    if (metros < 1000) return '${metros.round()} m';
    return '${(metros / 1000).toStringAsFixed(1)} km';
  }

  String _formatarDistanciaManobra(int metros) {
    if (metros < 1000) return '$metros m';
    return '${(metros / 1000).toStringAsFixed(1)} km';
  }

  String _chegadaPrevistaHoraCalculada() {
    final durSec = _duracao ?? 600;
    final previsao = DateTime.now().add(Duration(seconds: durSec));
    final h = previsao.hour.toString().padLeft(2, '0');
    final m = previsao.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _janelaHorarioTexto() {
    String? inicio;
    String? fim;

    if (_horaAgendada != null && _horaAgendada!.trim().isNotEmpty) {
      final partes = _horaAgendada!.trim().split(':');
      if (partes.isNotEmpty) {
        final h = int.tryParse(partes[0]);
        if (h != null) {
          final m = partes.length > 1 ? partes[1] : '00';
          inicio = m == '00' ? '${h}h' : '$h:${m}h';
        }
      }
    }

    if (_horaAgendadaFim != null && _horaAgendadaFim!.trim().isNotEmpty) {
      final partes = _horaAgendadaFim!.trim().split(':');
      if (partes.isNotEmpty) {
        final h = int.tryParse(partes[0]);
        if (h != null) {
          final m = partes.length > 1 ? partes[1] : '00';
          fim = m == '00' ? '${h}h' : '$h:${m}h';
        }
      }
    }

    if (inicio != null && fim != null) {
      return '$inicio - $fim';
    } else if (inicio != null) {
      final h = int.tryParse(_horaAgendada!.split(':').first) ?? 14;
      return '$inicio - ${(h + 2) % 24}h';
    } else if (fim != null) {
      final h = int.tryParse(_horaAgendadaFim!.split(':').first) ?? 16;
      return '${(h - 2) % 24}h - $fim';
    }

    final now = DateTime.now();
    return '${now.hour}h - ${(now.hour + 2) % 24}h';
  }

  @override
  Widget build(BuildContext context) {
    final double distanciaAteDestino = _atual != null
        ? Geolocator.distanceBetween(
            _atual!.latitude,
            _atual!.longitude,
            _destinoCoordenadas.latitude,
            _destinoCoordenadas.longitude,
          )
        : 9999.0;

    final bool estaPerto = distanciaAteDestino <= 100;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _cabecalho(),
            Expanded(
              child: Stack(
                children: [
                  // 1. MAPA LEAFLET COM TILES MAPBOX
                  FlutterMap(
                    mapController: mapa,
                    options: MapOptions(
                      initialCenter: _atual ?? _destinoCoordenadas,
                      initialZoom: 16.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _mapboxToken.isNotEmpty
                            ? 'https://api.mapbox.com/styles/v1/mapbox/$_mapboxStyleId/tiles/256/{z}/{x}/{y}@2x?access_token=$_mapboxToken'
                            : 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                        userAgentPackageName: 'br.com.consertaja',
                        maxZoom: 20,
                        fallbackUrl:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      if (_rota.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            // 1. Glow suave da rota
                            Polyline(
                              points: _rota,
                              color: azul.withValues(alpha: 0.25),
                              strokeWidth: 12.0,
                            ),
                            // 2. Linha azul externa
                            Polyline(
                              points: _rota,
                              color: const Color(0xFF0284C7),
                              strokeWidth: 7.0,
                            ),
                            // 3. Linha primary blue brilhante
                            Polyline(
                              points: _rota,
                              color: azul,
                              strokeWidth: 4.5,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          // Marcador do Cliente (DESTINO)
                          Marker(
                            point: _destinoCoordenadas,
                            width: 140,
                            height: 95,
                            alignment: Alignment.center,
                            child: _marcadorDestinoCliente(),
                          ),
                          // Marcador do Veículo / Seta 3D (LOCALIZAÇÃO ATUAL DO PROFISSIONAL)
                          if (_atual != null)
                            Marker(
                              point: _atual!,
                              width: 54,
                              height: 54,
                              alignment: Alignment.center,
                              child: _WazeChevronMarker(
                                bearing: _bearing,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // 2. Banner Superior Waze (Curvado em azul primary)
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: _bannerNavegacaoSuperior(),
                  ),

                  // 3. HUD Esquerdo: Velocímetro funcional (espaçamento adequado do banner)
                  Positioned(
                    top: 125,
                    left: 14,
                    child: _painelVelocimetro(),
                  ),

                  // 4. HUD Direito: Chat e Centralizar no Profissional (espaçamento adequado do banner)
                  Positioned(
                    top: 125,
                    right: 14,
                    child: _painelAcoesDireita(),
                  ),

                  // 5. Badge Mapbox e Clima
                  Positioned(
                    bottom: _painelExpandido
                        ? MediaQuery.of(context).size.height * 0.76 + 10
                        : 124,
                    left: 14,
                    child: _logoMapboxBadge(),
                  ),
                  Positioned(
                    bottom: _painelExpandido
                        ? MediaQuery.of(context).size.height * 0.76 + 10
                        : 124,
                    right: 14,
                    child: _badgeClima(),
                  ),

                  // 6. Persistent Bottom Sheet (Design idêntico ao modelo)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _persistentBottomSheet(estaPerto),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cabeçalho branco com botão de voltar, status e avatar com distinção empresa/independente
  Widget _cabecalho() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: escuroTexto),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Voltar',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Em Deslocamento',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: escuroTexto,
                      ),
                    ),
                  ],
                ),
                Text(
                  _codigoPedido,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: cinzaTexto,
                  ),
                ),
              ],
            ),
          ),
          // Botão SOS
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Suporte de Emergência ConsertaJá acionado.'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emergency_rounded,
                      color: Color(0xFFDC2626), size: 16),
                  SizedBox(width: 4),
                  Text(
                    'sos',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar do Profissional / Empresa
          GestureDetector(
            onTap: _aoClicarPerfil,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: azul, width: 2),
                  ),
                  child: ClipOval(
                    child: _fotoPerfilProfissional != null &&
                            _fotoPerfilProfissional!.isNotEmpty
                        ? Image.network(
                            _fotoPerfilProfissional!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _avatarFallbackProfissional(),
                          )
                        : _avatarFallbackProfissional(),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isEmpresa ? Icons.business : Icons.person,
                      size: 11,
                      color: azul,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallbackProfissional() {
    final nome = _nomeProfissional ?? (_isEmpresa ? 'Loja' : 'Profissional');
    return Container(
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(nome),
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Banner Superior estilo Waze com cor primary blue (0xFF0FB3FF)
  Widget _bannerNavegacaoSuperior() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: azul,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: azul.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _proximaManobraIcone,
            color: Colors.white,
            size: 38,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatarDistanciaManobra(_proximaManobraDistancia),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _proximoLogradouro.isNotEmpty
                      ? (_proximaManobraTexto.toLowerCase().contains('siga')
                          ? _proximoLogradouro
                          : '$_proximaManobraTexto - $_proximoLogradouro')
                      : _proximaManobraTexto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Painel Velocímetro (único, sem botão extra embaixo)
  Widget _painelVelocimetro() {
    final speed = _velocidadeAtual.round();
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: azul, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$speed',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: escuroTexto,
              height: 1.0,
            ),
          ),
          const Text(
            'km/h',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: azul,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  /// Painel Lateral Direito: Chat e Centralizar Seta
  Widget _painelAcoesDireita() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Chat
        _botaoPillHUD(
          icon: Icons.chat_bubble_rounded,
          onTap: _abrirChat,
        ),
        const SizedBox(height: 10),
        // 2. Centralizar Seta do Profissional
        _botaoPillHUD(
          icon: Icons.my_location_rounded,
          iconColor: azul,
          onTap: _centralizarProfissional,
        ),
      ],
    );
  }

  Widget _botaoPillHUD({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor == Colors.white ? escuroTexto : iconColor, size: 21),
      ),
    );
  }

  /// Badge Mapbox
  Widget _logoMapboxBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public, color: Colors.white, size: 12),
          SizedBox(width: 4),
          Text(
            'mapbox',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge Clima
  Widget _badgeClima() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 15),
          SizedBox(width: 5),
          Text(
            '24°',
            style: TextStyle(
              color: escuroTexto,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// Marcador do Cliente no Destino
  Widget _marcadorDestinoCliente() {
    final foto = _fotoCliente?.trim() ?? '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: foto.isNotEmpty
                    ? Image.network(
                        foto,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _avatarFallbackCliente(),
                      )
                    : _avatarFallbackCliente(),
              ),
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: azul,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.home, color: Colors.white, size: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _nomeCliente,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                _etiquetaComplemento(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatarFallbackCliente() {
    return Container(
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(_nomeCliente),
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _etiquetaComplemento() {
    if (_complemento.trim().isNotEmpty) return _complemento.trim();
    if (_numero.trim().isNotEmpty) return 'Nº $_numero';
    if (_bairro.trim().isNotEmpty) return _bairro.trim();
    return 'Destino';
  }

  /// Persistent Bottom Sheet com design exatamente igual ao modelo anexado
  Widget _persistentBottomSheet(bool perto) {
    final double maxH = MediaQuery.of(context).size.height * 0.76;
    final double minH = 112.0;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! < -80) {
          if (!_painelExpandido) setState(() => _painelExpandido = true);
        } else if (details.primaryVelocity! > 80) {
          if (_painelExpandido) setState(() => _painelExpandido = false);
        }
      },
      onTap: () {
        if (!_painelExpandido) {
          setState(() => _painelExpandido = true);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        height: _painelExpandido ? maxH : minH,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag Handle
            GestureDetector(
              onTap: () => setState(() => _painelExpandido = !_painelExpandido),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),

            // Se estiver fechado: mostra APENAS tempo estimado e chegada prevista
            if (!_painelExpandido)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _cardTempoEChegadaPrevistaCompacto(),
              )
            else
              // Se estiver aberto: mostra todos os elementos roláveis completos
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Column(
                    children: [
                      // CARD 1: TEMPO ESTIMADO, CHEGADA PREVISTA, ETAPAS E ENDEREÇO
                      _cardTrajetoEEndereco(),
                      const SizedBox(height: 12),

                      // CARD 2: DADOS DO CLIENTE E AVISOS RÁPIDOS
                      _cardClienteEAvisosRapidos(),
                      const SizedBox(height: 14),

                      // BOTÃO PRINCIPAL: CHEGUEI NO LOCAL
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: perto ? _aoClicarEstouNoLocal : null,
                          icon: const Icon(Icons.check_circle_rounded, size: 22),
                          label: Text(
                            perto
                                ? 'Cheguei no Local'
                                : 'Cheguei no Local (${(_distancia ?? 0).round()}m restantes)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: azul,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE2E8F0),
                            disabledForegroundColor: const Color(0xFF94A3B8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // BOTÕES SECUNDÁRIOS: AVISAR ATRASO E PAUSAR ROTA
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _mostrarDialogoAtraso,
                              icon: const Icon(Icons.warning_amber_rounded,
                                  size: 18, color: Colors.orange),
                              label: const Text('Avisar Atraso'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: escuroTexto,
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _pausada = !_pausada);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_pausada
                                        ? 'Rota pausada.'
                                        : 'Rota retomada.'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: Icon(
                                _pausada
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_circle_outline_rounded,
                                size: 18,
                                color: cinzaTexto,
                              ),
                              label: Text(_pausada ? 'Retomar Rota' : 'Pausar Rota'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: escuroTexto,
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // SUPORTE OPERACIONAL CONSERTAJÁ
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Central de Suporte Operacional: 0800 123 4567'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.help_outline_rounded,
                                size: 15, color: cinzaTexto),
                            SizedBox(width: 5),
                            Text(
                              'Central de Suporte Operacional ConsertaJá',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cinzaTexto,
                              ),
                            ),
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
    );
  }

  /// Card compacto exibido quando a Persistent Bottom Sheet está FECHADA
  Widget _cardTempoEChegadaPrevistaCompacto() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tempo Estimado
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TEMPO ESTIMADO',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: cinzaTexto,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _duracaoMinutos(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: escuroTexto,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '(${_formatarDistancia(_distancia)} restantes)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cinzaTexto,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Chegada Prevista
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CHEGADA PREVISTA',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: cinzaTexto,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 15, color: cinzaTexto),
                  const SizedBox(width: 4),
                  Text(
                    _chegadaPrevistaHoraCalculada(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: escuroTexto,
                    ),
                  ),
                ],
              ),
              Text(
                'Janela: ${_janelaHorarioTexto()}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cinzaTexto,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card 1: Tempo Estimado, Chegada Prevista, Barra de Progresso e Endereço
  Widget _cardTrajetoEEndereco() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row de Tempos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tempo Estimado
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TEMPO ESTIMADO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cinzaTexto,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _duracaoMinutos(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: escuroTexto,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${_formatarDistancia(_distancia)} restantes)',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: cinzaTexto,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Chegada Prevista
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'CHEGADA PREVISTA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cinzaTexto,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 16, color: cinzaTexto),
                      const SizedBox(width: 4),
                      Text(
                        _chegadaPrevistaHoraCalculada(),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: escuroTexto,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Janela: ${_janelaHorarioTexto()}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cinzaTexto,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barra de Progresso com 3 pontos (Partida -> Em trânsito -> Destino)
          Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: cinzaTexto),
                      SizedBox(width: 4),
                      Text(
                        'Partida',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: cinzaTexto),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: azul),
                      SizedBox(width: 4),
                      Text(
                        'Em trânsito',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: azul),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Color(0xFFCBD5E1)),
                      SizedBox(width: 4),
                      Text(
                        'Destino',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Container(height: 5, color: azul),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 5,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Linha do Endereço do Cliente com botão Copiar
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: azul, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _enderecoPrincipal,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: escuroTexto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _enderecoComplementar,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cinzaTexto,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: '$_enderecoPrincipal, $_enderecoComplementar',
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Endereço copiado para a área de transferência!'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 14, color: cinzaTexto),
                      SizedBox(width: 4),
                      Text(
                        'Copiar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cinzaTexto,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card 2: Informações do Cliente e Carrossel de Avisos Rápidos para o Chat
  Widget _cardClienteEAvisosRapidos() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha do Cliente (foto, verificado, nome, serviço, código)
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: _fotoCliente != null && _fotoCliente!.isNotEmpty
                          ? Image.network(
                              _fotoCliente!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _avatarFallbackCliente(),
                            )
                          : _avatarFallbackCliente(),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: azul,
                        size: 15,
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
                      _nomeCliente,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: escuroTexto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tituloServico.isNotEmpty
                          ? _tituloServico
                          : widget.categoria,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cinzaTexto,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Pedido $_codigoPedido',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Texto "Avisos rápidos para o chat:"
          const Text(
            'Avisos rápidos para o chat:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cinzaTexto,
            ),
          ),
          const SizedBox(height: 8),

          // Carrossel horizontal de botões de aviso
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chipAvisoRapido(
                  icone: Icons.timer_outlined,
                  texto: 'Estou a 5 minutos!',
                ),
                const SizedBox(width: 8),
                _chipAvisoRapido(
                  icone: Icons.local_parking_rounded,
                  texto: 'Procurando vaga',
                ),
                const SizedBox(width: 8),
                _chipAvisoRapido(
                  icone: Icons.traffic_rounded,
                  texto: 'Trânsito intenso',
                ),
                const SizedBox(width: 8),
                _chipAvisoRapido(
                  icone: Icons.door_front_door_outlined,
                  texto: 'Chegando ao portão',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipAvisoRapido({
    required IconData icone,
    required String texto,
  }) {
    return InkWell(
      onTap: () => _enviarAvisoRapidoChat(texto),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 15, color: escuroTexto),
            const SizedBox(width: 6),
            Text(
              '"$texto"',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: escuroTexto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seta 3D estilo Chevron Waze apontando na orientação real
class _WazeChevronMarker extends StatelessWidget {
  final double bearing;

  const _WazeChevronMarker({required this.bearing});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: bearing * (pi / 180),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(42, 42),
            painter: _WazeArrowPainter(),
          ),
        ],
      ),
    );
  }
}

class _WazeArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.92, h * 0.88)
      ..lineTo(w * 0.5, h * 0.68)
      ..lineTo(w * 0.08, h * 0.88)
      ..close();

    // Borda branca
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);

    // Preenchimento gradiente primary blue
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF38BDF8), Color(0xFF0FB3FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
