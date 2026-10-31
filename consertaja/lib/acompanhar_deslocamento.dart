import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tela_chat_profissional.dart';
import 'tela_meu_perfil_cliente.dart';
import 'utils/iniciais.dart';

class AcompanharDeslocamentoPage extends StatefulWidget {
  final int idSolicitacao;

  const AcompanharDeslocamentoPage({
    super.key,
    required this.idSolicitacao,
  });

  @override
  State<AcompanharDeslocamentoPage> createState() =>
      _AcompanharDeslocamentoPageState();
}

class _AcompanharDeslocamentoPageState extends State<AcompanharDeslocamentoPage>
    with SingleTickerProviderStateMixin {
  static const Color azul = Color(0xFF0FB3FF);
  static const Color escuro = Color(0xFF0F172A);
  static const Color cinzaTexto = Color(0xFF64748B);
  static const Color cinzaFundo = Color(0xFFF8FAFC);

  final SupabaseClient supabase = Supabase.instance.client;
  final MapController mapController = MapController();

  bool _carregando = true;
  Timer? _timerPolling;
  RealtimeChannel? _canalRealtime;
  RealtimeChannel? _canalRealtimeSolicitacao;
  late AnimationController _sonarController;
  int? _fkStatus;

  // Dados do Cliente logado
  String? _fotoPerfilCliente;
  String _nomeCliente = '';

  // Dados do Prestador (Profissional ou Loja)
  bool _ehEmpresa = false;
  int? _idProfissional;
  int? _idGrupoEmpresa;
  String _nomePrestador = 'Profissional ConsertaJá';
  String? _fotoPrestador;
  String _categoriaPrestador = 'Assistência Técnica';
  double _notaAvaliacao = 4.9;
  int _totalAtendimentos = 148;

  // Dados do Serviço e Pedido
  String _codigoPedido = '';
  String _tituloServico = 'Serviço Solicitado';
  double _valorFinal = 0.0;
  String _codigoRecDev = '----';

  // Endereço do Cliente (Destino)
  LatLng _destino = const LatLng(-23.55052, -46.633308);
  String _enderecoLinha1 = '';
  String _enderecoLinha2 = '';
  String _complementoOuObs = '';

  // Deslocamento em Tempo Real
  LatLng? _posicaoProfissional;
  List<LatLng> _rota = [];
  double _velocidadeKmH = 38.0;
  double _bearing = 0.0;
  String _ruaAtualProfissional = 'Rua da Mooca';
  double? _distanciaMetros;
  int? _duracaoSegundos;
  DateTime? _horarioInicioDeslocamento;

  @override
  void initState() {
    super.initState();
    _codigoPedido =
        '#PED-2026-${widget.idSolicitacao.toString().padLeft(4, '0')}';
    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
    _carregarDadosIniciais();
    _configurarRealtime();
    _iniciarPolling();
  }

  @override
  void dispose() {
    _timerPolling?.cancel();
    _sonarController.dispose();
    if (_canalRealtime != null) {
      supabase.removeChannel(_canalRealtime!);
    }
    if (_canalRealtimeSolicitacao != null) {
      supabase.removeChannel(_canalRealtimeSolicitacao!);
    }
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    try {
      await Future.wait([
        _carregarClienteLogado(),
        _carregarSolicitacao(),
      ]);
      await _carregarDadosDeslocamento();
    } catch (_) {} finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregarClienteLogado() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final usuario = await supabase
          .from('usuarios')
          .select('nome, foto_perfil_url')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (usuario != null) {
        _nomeCliente = usuario['nome']?.toString().trim() ?? '';
        _fotoPerfilCliente = usuario['foto_perfil_url']?.toString().trim();
      }
    } catch (_) {}
  }

  Future<void> _carregarSolicitacao() async {
    try {
      final row = await supabase
          .from('solicitacoes')
          .select(
            'id_solicitacao, valor_final, detalhes, data_agendada, hora_agendada, '
            'tipo_execucao, fk_grupo_empresa, fk_profissional, fk_usuario, '
            'fk_endereco, fk_servico_prof, fk_servico_temp, codigo_rec_dev, fk_status',
          )
          .eq('id_solicitacao', widget.idSolicitacao)
          .maybeSingle();

      if (row == null) return;

      _fkStatus = (row['fk_status'] as num?)?.toInt();
      final codigoBanco = row['codigo_rec_dev']?.toString().trim() ?? '';
      if (codigoBanco.isNotEmpty) {
        _codigoRecDev = codigoBanco;
      }

      final valor = row['valor_final'];
      if (valor != null) {
        _valorFinal = (valor as num).toDouble();
      }

      _idGrupoEmpresa = (row['fk_grupo_empresa'] as num?)?.toInt();
      _idProfissional = (row['fk_profissional'] as num?)?.toInt();
      _ehEmpresa = _idGrupoEmpresa != null;

      // 1. Prestador: Diferenciação Loja vs Profissional Independente
      if (_ehEmpresa) {
        final grupo = await supabase
            .from('grupo_empresa')
            .select('nome_empresa, foto_url_empresa, fk_perfil')
            .eq('id_grupo_empresa', _idGrupoEmpresa!)
            .maybeSingle();

        if (grupo != null) {
          _nomePrestador =
              grupo['nome_empresa']?.toString().trim() ?? 'Loja Especializada';
          _fotoPrestador = grupo['foto_url_empresa']?.toString().trim();
        }
      } else if (_idProfissional != null) {
        final prof = await supabase
            .from('dados_profissionais')
            .select('fk_usuario')
            .eq('id_profissional', _idProfissional!)
            .maybeSingle();

        final fkUserProf = (prof?['fk_usuario'] as num?)?.toInt();
        if (fkUserProf != null) {
          final uProf = await supabase
              .from('usuarios')
              .select('nome, foto_perfil_url')
              .eq('id_usuario', fkUserProf)
              .maybeSingle();

          if (uProf != null) {
            _nomePrestador =
                uProf['nome']?.toString().trim() ?? 'Profissional ConsertaJá';
            _fotoPrestador = uProf['foto_perfil_url']?.toString().trim();
          }
        }
      }

      // 2. Serviço / Título
      final idServico = (row['fk_servico_prof'] as num?)?.toInt();
      final idServicoTemp = (row['fk_servico_temp'] as num?)?.toInt();
      if (idServico != null) {
        final serv = await supabase
            .from('servicos_profissional')
            .select('titulo, oficios(funcao)')
            .eq('id_servico_prof', idServico)
            .maybeSingle();

        if (serv != null) {
          final t = serv['titulo']?.toString().trim() ?? '';
          if (t.isNotEmpty) _tituloServico = t;
          final dynamic of = serv['oficios'];
          if (of is Map && of['funcao'] != null) {
            _categoriaPrestador = of['funcao'].toString().trim();
          } else if (of is List && of.isNotEmpty && of.first is Map) {
            _categoriaPrestador = of.first['funcao']?.toString().trim() ?? '';
          }
        }
      } else if (idServicoTemp != null) {
        final serv = await supabase
            .from('servicos_chat_temporarios')
            .select('titulo, oficios(funcao)')
            .eq('id_servico_temp', idServicoTemp)
            .maybeSingle();

        if (serv != null) {
          final t = serv['titulo']?.toString().trim() ?? '';
          if (t.isNotEmpty) _tituloServico = t;
          final dynamic of = serv['oficios'];
          if (of is Map && of['funcao'] != null) {
            _categoriaPrestador = of['funcao'].toString().trim();
          } else if (of is List && of.isNotEmpty && of.first is Map) {
            _categoriaPrestador = of.first['funcao']?.toString().trim() ?? '';
          }
        }
      }

      // 3. Endereço do Cliente
      final idEndereco = (row['fk_endereco'] as num?)?.toInt();
      if (idEndereco != null) {
        final end = await supabase
            .from('enderecos')
            .select(
              'logradouro, numero, complemento, bairro, cep, fk_cidade, latitude, longitude',
            )
            .eq('id_endereco', idEndereco)
            .maybeSingle();

        if (end != null) {
          final log = end['logradouro']?.toString().trim() ?? 'Rua';
          final numStr = end['numero']?.toString().trim() ?? '';
          final comp = end['complemento']?.toString().trim() ?? '';
          final bai = end['bairro']?.toString().trim() ?? '';
          final lat = double.tryParse(end['latitude']?.toString() ?? '');
          final lng = double.tryParse(end['longitude']?.toString() ?? '');

          if (lat != null && lng != null && lat.abs() > 0.001) {
            _destino = LatLng(lat, lng);
          }

          _enderecoLinha1 = '$log${numStr.isNotEmpty ? ', $numStr' : ''}';
          if (bai.isNotEmpty) {
            _enderecoLinha1 = '$_enderecoLinha1 - $bai';
          }
          _complementoOuObs = comp.isNotEmpty
              ? comp
              : (bai.isNotEmpty ? bai : 'Endereço residencial');
        }
      }
    } catch (_) {}
  }

  Future<void> _carregarDadosDeslocamento() async {
    try {
      final solCheck = await supabase
          .from('solicitacoes')
          .select('fk_status, codigo_rec_dev')
          .eq('id_solicitacao', widget.idSolicitacao)
          .maybeSingle();
      if (solCheck != null) {
        final st = (solCheck['fk_status'] as num?)?.toInt();
        if (st != null && st != _fkStatus && mounted) {
          setState(() {
            _fkStatus = st;
          });
        }
        final cod = solCheck['codigo_rec_dev']?.toString().trim();
        if (cod != null && cod.isNotEmpty) {
          _codigoRecDev = cod;
        }
      }
    } catch (_) {}

    try {
      final desloc = await supabase
          .from('deslocamento_profissional')
          .select('*')
          .eq('fk_solicitacao', widget.idSolicitacao)
          .maybeSingle();

      if (desloc != null) {
        _aplicarDadosDeslocamento(desloc);
        return;
      }
    } catch (_) {}

    // Fallback caso a tabela ainda não possua o registro
    if (_posicaoProfissional == null) {
      _posicaoProfissional = LatLng(
        _destino.latitude - 0.018,
        _destino.longitude - 0.015,
      );
      _calcularRotaOSRM(_posicaoProfissional!, _destino);
    }
  }

  void _aplicarDadosDeslocamento(Map<String, dynamic> data) {
    final lat = (data['latitude'] as num?)?.toDouble();
    final lng = (data['longitude'] as num?)?.toDouble();
    final vel = (data['velocidade'] as num?)?.toDouble();
    final bg = (data['bearing'] as num?)?.toDouble();
    final rua = data['rua_atual']?.toString().trim();
    final dist = (data['distancia_metros'] as num?)?.toDouble();
    final dur = (data['duracao_segundos'] as num?)?.toInt();
    final dtIniStr = data['data_inicio']?.toString();

    if (lat != null && lng != null) {
      final novaPos = LatLng(lat, lng);
      _posicaoProfissional = novaPos;
      if (_rota.isEmpty) {
        _calcularRotaOSRM(novaPos, _destino);
      }
    }

    if (vel != null && vel > 0) _velocidadeKmH = vel;
    if (bg != null) _bearing = bg;
    if (rua != null && rua.isNotEmpty) _ruaAtualProfissional = rua;
    if (dist != null) _distanciaMetros = dist;
    if (dur != null) _duracaoSegundos = dur;
    if (dtIniStr != null) {
      _horarioInicioDeslocamento = DateTime.tryParse(dtIniStr);
    }

    if (mounted) setState(() {});
  }

  Future<void> _calcularRotaOSRM(LatLng origem, LatLng destino) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${origem.longitude},${origem.latitude};${destino.longitude},${destino.latitude}?overview=full&geometries=geojson',
    );
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry']['coordinates'] as List;
      final dist = (route['distance'] as num?)?.toDouble();
      final dur = (route['duration'] as num?)?.round();

      if (!mounted) return;
      setState(() {
        _rota = geometry
            .map(
              (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
            )
            .toList();
        if (_distanciaMetros == null) _distanciaMetros = dist;
        if (_duracaoSegundos == null) _duracaoSegundos = dur;
      });
    } catch (_) {}
  }

  void _configurarRealtime() {
    try {
      _canalRealtime = supabase
          .channel('public:deslocamento_profissional:${widget.idSolicitacao}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'deslocamento_profissional',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'fk_solicitacao',
              value: widget.idSolicitacao,
            ),
            callback: (payload) {
              final newRec = payload.newRecord;
              if (newRec.isNotEmpty) {
                _aplicarDadosDeslocamento(newRec);
              }
            },
          )
          .subscribe();

      _canalRealtimeSolicitacao = supabase
          .channel('public:solicitacoes_status:${widget.idSolicitacao}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'solicitacoes',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id_solicitacao',
              value: widget.idSolicitacao,
            ),
            callback: (payload) {
              final newRec = payload.newRecord;
              if (newRec.isNotEmpty) {
                final st = (newRec['fk_status'] as num?)?.toInt();
                if (st != null && mounted) {
                  setState(() {
                    _fkStatus = st;
                  });
                }
              }
            },
          )
          .subscribe();
    } catch (_) {}
  }

  void _iniciarPolling() {
    _timerPolling = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _carregarDadosDeslocamento();
    });
  }

  void _abrirChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaChatProfissional(
          nomeProfissional: _nomePrestador,
          fotoProfissional: _fotoPrestador ?? '',
          oficioPrincipal: _categoriaPrestador,
          idProfissional: _ehEmpresa ? null : _idProfissional,
          idGrupoEmpresa: _ehEmpresa ? _idGrupoEmpresa : null,
          idSolicitacao: widget.idSolicitacao,
        ),
      ),
    );
  }

  void _abrirMeuPerfilCliente() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TelaMeuPerfilClientePage(isVisitante: false),
      ),
    );
  }

  void _mostrarAjuda() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.help_outline, color: azul, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Acompanhamento em Tempo Real',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: escuro,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '• O mapa exibe a posição do profissional em tempo real enquanto ele se desloca até o seu local.\n'
                '• Mantenha seu telefone por perto para receber o profissional.\n'
                '• Forneça o código de confirmação apenas quando o prestador estiver pessoalmente no local com você.',
                style: TextStyle(fontSize: 13.5, color: cinzaTexto, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(backgroundColor: azul),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tempoEstimadoTexto() {
    if (_duracaoSegundos == null) return '8 - 12 minutos';
    final min = (_duracaoSegundos! / 60).ceil();
    if (min <= 3) return '1 - 3 minutos';
    return '${(min - 2).clamp(1, 99)} - ${min + 2} minutos';
  }

  String _horarioEstimadoTexto() {
    final agora = DateTime.now();
    final seg = _duracaoSegundos ?? 600;
    final previsao = agora.add(Duration(seconds: seg));
    final hora = previsao.hour.toString().padLeft(2, '0');
    final min = previsao.minute.toString().padLeft(2, '0');
    return 'Horário estimado: $hora:$min • Trânsito moderado';
  }

  String _inicioDeslocamentoTexto() {
    final inicio = _horarioInicioDeslocamento ??
        DateTime.now().subtract(const Duration(minutes: 10));
    final h = inicio.hour.toString().padLeft(2, '0');
    final m = inicio.minute.toString().padLeft(2, '0');
    return 'Deslocamento iniciado às $h:$m';
  }

  String _distanciaTexto() {
    if (_distanciaMetros == null) return 'Distância restante: 3,4 km';
    if (_distanciaMetros! >= 1000) {
      final km = (_distanciaMetros! / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return 'Distância restante: $km km';
    }
    return 'Distância restante: ${_distanciaMetros!.round()} m';
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(
        backgroundColor: cinzaFundo,
        body: Center(child: CircularProgressIndicator(color: azul)),
      );
    }

    return Scaffold(
      backgroundColor: cinzaFundo,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      _buildPillGpsStatusBar(),
                      const SizedBox(height: 10),
                      if (_fkStatus == 34) ...[
                        _buildAvisoProfissionalChegou(),
                      ] else ...[
                        _buildCardPrevisaoChegada(),
                      ],
                      const SizedBox(height: 12),
                      _buildTimelineProgresso(),
                      const SizedBox(height: 14),
                      _buildAreaMapa(),
                      const SizedBox(height: 14),
                      _buildCardInfoProfissional(),
                      const SizedBox(height: 14),
                      _buildCardCodigoConfirmacao(),
                      const SizedBox(height: 14),
                      _buildCardInfoServico(),
                      const SizedBox(height: 14),
                      _buildRodapeSuporte(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1. Cabeçalho com Seta, Título "Profissional A Caminho", Ícone de Ajuda e Avatar do Cliente
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: escuro, size: 24),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              _fkStatus == 34
                  ? 'Profissional Chegou'
                  : 'Profissional A Caminho',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: escuro,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            onPressed: _mostrarAjuda,
            icon: const Icon(Icons.help_outline, color: azul, size: 24),
          ),
          GestureDetector(
            onTap: _abrirMeuPerfilCliente,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: azul, width: 1.5),
              ),
              child: ClipOval(
                child: _fotoPerfilCliente != null &&
                        _fotoPerfilCliente!.isNotEmpty
                    ? Image.network(
                        _fotoPerfilCliente!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _avatarFallbackCliente(),
                      )
                    : _avatarFallbackCliente(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallbackCliente() {
    return Container(
      color: azul,
      alignment: Alignment.center,
      child: Text(
        obterIniciais(_nomeCliente.isNotEmpty ? _nomeCliente : 'Cliente'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 2. Row com Status do GPS e "Atualizado agora"
  Widget _buildPillGpsStatusBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: azul,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fkStatus == 34
                    ? 'Profissional no local • Conectado'
                    : 'GPS em tempo real • Conectado',
                style: const TextStyle(
                  color: azul,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: azul, size: 14),
              SizedBox(width: 5),
              Text(
                'Atualizado agora',
                style: TextStyle(
                  color: azul,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Card animado com efeito Sonar informando que o Profissional Chegou
  Widget _buildAvisoProfissionalChegou() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: azul,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: azul.withValues(alpha: 0.38),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Efeito Sonar no Ícone de Chegada
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _sonarController,
                  builder: (context, _) {
                    final t = _sonarController.value;
                    return Container(
                      width: 40 + (16 * t),
                      height: 40 + (16 * t),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              Colors.white.withValues(alpha: (1.0 - t) * 0.75),
                          width: 2.5,
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    color: azul,
                    size: 26,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profissional Chegou!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'O profissional está na área ou aguardando na portaria.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Card "PREVISÃO DE CHEGADA" (Fundo Azul #0FB3FF com ícone de Moto)
  Widget _buildCardPrevisaoChegada() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: azul,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: azul.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PREVISÃO DE CHEGADA',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _tempoEstimadoTexto(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _horarioEstimadoTexto(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.two_wheeler,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Timeline de Progresso com Etapas e Barra Linear
  Widget _buildTimelineProgresso() {
    final bool chegou = _fkStatus == 34;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '1. Saiu da Oficina',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: azul,
                ),
              ),
              const Text(
                '2. Em trânsito',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: azul,
                ),
              ),
              Text(
                '3. No seu endereço',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: chegou ? azul : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: chegou ? 100 : 62,
                    child: Container(color: azul),
                  ),
                  if (!chegou)
                    Expanded(
                      flex: 38,
                      child: Container(color: const Color(0xFFE2E8F0)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    chegou ? Icons.check_circle : Icons.check_circle_outline,
                    color: azul,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    chegou ? 'Chegou ao destino' : _inicioDeslocamentoTexto(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: azul,
                    ),
                  ),
                ],
              ),
              Text(
                chegou ? 'No local' : _distanciaTexto(),
                style: const TextStyle(
                  fontSize: 11.5,
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

  /// 5. Seção de Mapa com Marcadores Estilizados e Rota
  Widget _buildAreaMapa() {
    final posProf = _posicaoProfissional ??
        LatLng(_destino.latitude - 0.015, _destino.longitude - 0.012);

    return Container(
      height: 290,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: posProf,
                initialZoom: 14.5,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                  userAgentPackageName: 'br.com.consertaja',
                  maxZoom: 19,
                  fallbackUrl:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                if (_fkStatus != 34 && _rota.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _rota,
                        color: azul.withValues(alpha: 0.35),
                        strokeWidth: 9.0,
                      ),
                      Polyline(
                        points: _rota,
                        color: azul,
                        strokeWidth: 5.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // Marcador de Destino do Cliente (some ao chegar)
                    if (_fkStatus != 34)
                      Marker(
                        point: _destino,
                        width: 100,
                        height: 70,
                        alignment: Alignment.center,
                        child: _marcadorDestinoCliente(),
                      ),
                    // Marcador do Profissional
                    Marker(
                      point: posProf,
                      width: _fkStatus == 34 ? 170 : 150,
                      height: _fkStatus == 34 ? 130 : 90,
                      alignment: Alignment.center,
                      child: _marcadorProfissional(),
                    ),
                  ],
                ),
              ],
            ),
            // Botões de Controle na Direita
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _botaoControleMapa(
                    icon: Icons.explore_outlined,
                    onTap: () => mapController.rotate(0),
                  ),
                  const SizedBox(height: 8),
                  _botaoControleMapa(
                    icon: Icons.layers_outlined,
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  _botaoControleMapa(
                    icon: Icons.near_me_outlined,
                    onTap: () {
                      if (_posicaoProfissional != null) {
                        mapController.move(_posicaoProfissional!, 15);
                      }
                    },
                  ),
                ],
              ),
            ),
            // Pill com Endereço Flutuante Inferior (some ao chegar)
            if (_fkStatus != 34)
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: azul, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _enderecoLinha1.isNotEmpty
                              ? _enderecoLinha1
                              : 'Rua das Acácias, 452 - Mooca',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: escuro,
                          ),
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

  Widget _botaoControleMapa({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF334155), size: 19),
      ),
    );
  }

  Widget _marcadorDestinoCliente() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Text(
            'Seu local',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: escuro,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: azul,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: azul.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.home, color: Colors.white, size: 18),
        ),
      ],
    );
  }

  Widget _marcadorProfissional() {
    final bool chegou = _fkStatus == 34;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: azul,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            chegou
                ? 'Profissional no local'
                : '${_velocidadeKmH.round()} km/h • $_ruaAtualProfissional',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 3),
        if (chegou)
          AnimatedBuilder(
            animation: _sonarController,
            builder: (context, _) {
              final t = _sonarController.value;
              return SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Anel externo do sonar
                    Opacity(
                      opacity: ((1.0 - t) * 0.45).clamp(0.0, 1.0),
                      child: Container(
                        width: 48 + (38 * t),
                        height: 48 + (38 * t),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: azul.withValues(alpha: 0.2),
                          border: Border.all(
                            color: azul,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                    // Anel intermediário do sonar
                    Opacity(
                      opacity: ((1.0 - (t * 0.85)) * 0.55).clamp(0.0, 1.0),
                      child: Container(
                        width: 48 + (18 * t),
                        height: 48 + (18 * t),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: azul.withValues(alpha: 0.25),
                          border: Border.all(
                            color: azul,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                    // Avatar com borda primary blue mais grossa
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: azul, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: azul.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: _fotoPrestador != null &&
                                _fotoPrestador!.isNotEmpty
                            ? Image.network(
                                _fotoPrestador!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _avatarFallbackPrestador(),
                              )
                            : _avatarFallbackPrestador(),
                      ),
                    ),
                    // Badge de localização
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: azul,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.place_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          )
        else
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
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _fotoPrestador != null && _fotoPrestador!.isNotEmpty
                      ? Image.network(
                          _fotoPrestador!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _avatarFallbackPrestador(),
                        )
                      : _avatarFallbackPrestador(),
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
                  child: const Icon(
                    Icons.two_wheeler,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _avatarFallbackPrestador() {
    return Container(
      color: azul,
      alignment: Alignment.center,
      child: Text(
        obterIniciais(_nomePrestador),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 6. Card de Detalhes do Profissional/Loja e Veículo
  Widget _buildCardInfoProfissional() {
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
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipOval(
                  child: _fotoPrestador != null && _fotoPrestador!.isNotEmpty
                      ? Image.network(
                          _fotoPrestador!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _avatarFallbackPrestador(),
                        )
                      : _avatarFallbackPrestador(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _nomePrestador,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: escuro,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.verified, color: azul, size: 16),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _categoriaPrestador,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cinzaTexto,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${_notaAvaliacao.toStringAsFixed(1)} • $_totalAtendimentos atendimentos',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Em rota',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Container do Veículo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.two_wheeler, color: azul, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Veículo de deslocamento',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: cinzaTexto,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Honda CG 160 Cargo • Prata',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: escuro,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'PLACA',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: cinzaTexto,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'ABC-4J89',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: azul,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Botão Conversar no Chat (ocupando toda a largura, sem o de ligar)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _abrirChat,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text(
                'Conversar no Chat',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: azul,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 7. Seção de Código de Confirmação (`codigo_rec_dev` de 4 dígitos)
  Widget _buildCardCodigoConfirmacao() {
    final digitos = _codigoRecDev.padRight(4, '-').split('');

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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.confirmation_number_outlined,
                      color: azul, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Código de Confirmação',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: escuro,
                    ),
                  ),
                ],
              ),
              Text(
                'Forneça apenas na chegada',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: cinzaTexto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Diga este código ao $_nomePrestador ao entregar o objeto a ser reparado:',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: cinzaTexto,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          // 4 Caixas com os 4 Dígitos em Destaque
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 4; i++) ...[
                _caixaDigito(i < digitos.length ? digitos[i] : '-'),
                if (i < 3) const SizedBox(width: 14),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Banner de Verificação de Antecedentes e Seguro
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    color: Color(0xFF16A34A), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Profissional verificado com checagem de antecedentes e seguro ConsertaJá.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF166534),
                      height: 1.25,
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

  Widget _caixaDigito(String digito) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
      ),
      child: Text(
        digito,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: azul,
        ),
      ),
    );
  }

  /// 8. Seção de Informações do Serviço
  Widget _buildCardInfoServico() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pedido $_codigoPedido',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: azul,
                ),
              ),
              Text(
                'R\$ ${_valorFinal.toStringAsFixed(2).replaceAll('.', ',')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: escuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _tituloServico,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: escuro,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.apartment, color: cinzaTexto, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _complementoOuObs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cinzaTexto,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 9. Rodapé Inferior de Suporte
  Widget _buildRodapeSuporte() {
    return InkWell(
      onTap: () {
        launchUrl(
          Uri.parse('https://consertaja.com.br/suporte'),
          mode: LaunchMode.externalApplication,
        );
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headset_mic_outlined, color: Color(0xFF94A3B8), size: 15),
            SizedBox(width: 6),
            Text(
              'Central de Ajuda 24h disponível pelo suporte',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

