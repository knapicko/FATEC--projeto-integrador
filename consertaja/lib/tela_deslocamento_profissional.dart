import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const azul = Color(0xFF0FB3FF);
  final supabase = Supabase.instance.client;
  final mapa = MapController();
  StreamSubscription<Position>? _posicao;
  LatLng? _atual;
  List<LatLng> _rota = [];
  double? _distancia;
  int? _duracao;
  double? _precisao;
  bool _pausada = false;
  bool _chegou = false;

  @override
  void initState() {
    super.initState();
    _iniciarLocalizacao();
  }

  @override
  void dispose() {
    _posicao?.cancel();
    super.dispose();
  }

  Future<void> _iniciarLocalizacao() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        throw Exception('Ative o GPS para iniciar o deslocamento.');
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied)
        permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever)
        throw Exception('Permissão de localização não concedida.');
      final p = await Geolocator.getCurrentPosition();
      _atualizarPosicao(p);
      _posicao = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_atualizarPosicao);
      await _atualizarRota(LatLng(p.latitude, p.longitude));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    }
  }

  void _atualizarPosicao(Position p) {
    final atual = LatLng(p.latitude, p.longitude);
    if (!mounted) return;
    setState(() {
      _atual = atual;
      _precisao = p.accuracy;
    });
    if (!_pausada) _atualizarRota(atual);
  }

  Future<void> _atualizarRota(LatLng origem) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${origem.longitude},${origem.latitude};${widget.destino.longitude},${widget.destino.latitude}?overview=full&geometries=geojson&steps=true',
    );
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final route = (data['routes'] as List).first as Map<String, dynamic>;
      final geometry = route['geometry']['coordinates'] as List;
      if (!mounted) return;
      setState(() {
        _rota = geometry
            .map(
              (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
            )
            .toList();
        _distancia = (route['distance'] as num).toDouble();
        _duracao = (route['duration'] as num).round();
      });
    } catch (_) {}
  }

  Future<void> _iniciarTrajeto() async {
    await supabase
        .from('solicitacoes')
        .update({'fk_status': 33, 'etapa_solicitacao': 2})
        .eq('id_solicitacao', widget.idSolicitacao);
    if (mounted) setState(() => _chegou = false);
  }

  Future<void> _cheguei() async {
    if (_atual == null ||
        Geolocator.distanceBetween(
              _atual!.latitude,
              _atual!.longitude,
              widget.destino.latitude,
              widget.destino.longitude,
            ) >
            150)
      return;
    await supabase
        .from('solicitacoes')
        .update({'etapa_solicitacao': 3})
        .eq('id_solicitacao', widget.idSolicitacao);
    if (mounted) setState(() => _chegou = true);
  }

  String _distanciaTexto() => _distancia == null
      ? 'Calculando rota...'
      : _distancia! >= 1000
      ? '${(_distancia! / 1000).toStringAsFixed(1).replaceAll('.', ',')} km restantes'
      : '${_distancia!.round()} m restantes';
  String _eta() {
    if (_duracao == null) return '--';
    final t = DateTime.now().add(Duration(seconds: _duracao!));
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final perto =
        _atual != null &&
        Geolocator.distanceBetween(
              _atual!.latitude,
              _atual!.longitude,
              widget.destino.latitude,
              widget.destino.longitude,
            ) <=
            150;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _cabecalho(),
            _gps(),
            _instrucao(),
            Expanded(child: _mapa()),
            _resumo(perto),
            _destino(),
            _profissional(),
            _acoes(perto),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                '⚙  Central de Suporte Operacional ConsertaJá',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        const Icon(Icons.circle, color: azul, size: 9),
        const SizedBox(width: 7),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A CAMINHO DO CLIENTE',
                style: TextStyle(
                  color: azul,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Text('ConsertaJá Direção', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
        CircleAvatar(
          backgroundColor: Colors.red.shade100,
          child: const Text(
            'SOS',
            style: TextStyle(
              color: Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const CircleAvatar(
          backgroundColor: azul,
          child: Icon(Icons.person, color: Colors.white),
        ),
      ],
    ),
  );
  Widget _gps() => _card(
    child: Row(
      children: [
        const Icon(Icons.circle, color: Colors.blue, size: 10),
        const SizedBox(width: 8),
        const Text(
          'GPS Ao Vivo Conectado',
          style: TextStyle(
            color: azul,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const Text(
          '  •  Precisão ',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
        Text(
          _precisao == null ? '--' : '±${_precisao!.round()} m',
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
  Widget _instrucao() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: azul,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        const Icon(Icons.turn_right, color: Colors.white, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _distancia != null ? _distanciaTexto() : 'Rota até o cliente',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Siga pela rota calculada',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              Text(
                widget.enderecoPrincipal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            '-- km/h',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    ),
  );
  Widget _mapa() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FlutterMap(
        mapController: mapa,
        options: MapOptions(
          initialCenter: _atual ?? widget.destino,
          initialZoom: 14,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'br.com.consertaja',
          ),
          if (_rota.isNotEmpty)
            PolylineLayer(
              polylines: [Polyline(points: _rota, color: azul, strokeWidth: 5)],
            ),
          MarkerLayer(
            markers: [
              Marker(
                point: widget.destino,
                width: 42,
                height: 42,
                child: const Icon(
                  Icons.location_pin,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              if (_atual != null)
                Marker(
                  point: _atual!,
                  width: 42,
                  height: 42,
                  child: const Icon(Icons.navigation, color: azul, size: 34),
                ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _resumo(bool perto) => _card(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TEMPO ESTIMADO',
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
            Text(
              _duracao == null ? '--' : '${(_duracao! / 60).ceil()} min',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            Text(
              _distanciaTexto(),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'CHEGADA PREVISTA',
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
            Text(
              _eta(),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
            ),
            Text(
              perto ? 'Você chegou' : 'Em trânsito',
              style: const TextStyle(
                color: azul,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _destino() => _card(
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFFE0F2FE),
          child: Icon(Icons.location_on, color: azul),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.enderecoPrincipal,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                widget.enderecoComplementar,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Clipboard.setData(
            ClipboardData(
              text:
                  '${widget.enderecoPrincipal}, ${widget.enderecoComplementar}',
            ),
          ),
          child: const Text('Copiar'),
        ),
      ],
    ),
  );
  Widget _profissional() => _card(
    child: Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: widget.fotoCliente?.isNotEmpty == true
              ? NetworkImage(widget.fotoCliente!)
              : null,
          child: widget.fotoCliente?.isNotEmpty == true
              ? null
              : const Icon(Icons.person),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nomeCliente,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              widget.categoria,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              widget.codigoPedido,
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _acoes(bool perto) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
    child: Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _chegou
                ? null
                : (_atual == null
                      ? null
                      : (perto ? _cheguei : _iniciarTrajeto)),
            icon: Icon(_chegou || perto ? Icons.check : Icons.navigation),
            label: Text(
              _chegou
                  ? 'Cheguei no local'
                  : perto
                  ? 'Cheguei no local'
                  : 'Iniciar Trajeto',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _chegou
                  ? Colors.green
                  : perto
                  ? azul
                  : azul,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.warning_amber, color: Colors.orange),
                label: const Text('Avisar Atraso'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () => setState(() => _pausada = !_pausada),
                icon: Icon(_pausada ? Icons.play_arrow : Icons.pause),
                label: Text(_pausada ? 'Retomar Rota' : 'Pausar Rota'),
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(
              'https://www.google.com/maps/dir/?api=1&destination=${widget.destino.latitude},${widget.destino.longitude}',
            ),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.map_outlined),
          label: const Text('Abrir no Maps'),
        ),
      ],
    ),
  );
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 8),
      ],
    ),
    child: child,
  );
}
