import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'detalhes_pedido.dart';
import 'models/servico_profissional.dart';
import 'services/servicos_profissional_service.dart';

class TelaDeslocamentoClientePage extends StatefulWidget {
  const TelaDeslocamentoClientePage({super.key, required this.idSolicitacao});

  final int idSolicitacao;

  @override
  State<TelaDeslocamentoClientePage> createState() =>
      _TelaDeslocamentoClientePageState();
}

class _TelaDeslocamentoClientePageState
    extends State<TelaDeslocamentoClientePage> {
  static const azul = Color(0xFF0FB3FF);
  static const texto = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);

  final _supabase = Supabase.instance.client;
  final _mapController = MapController();
  final _picker = ImagePicker();
  final _codigo = List.generate(4, (_) => TextEditingController());
  StreamSubscription<Position>? _posicao;

  LatLng _cliente = const LatLng(-23.5505, -46.6333);
  LatLng _destino = const LatLng(-23.5505, -46.6333);
  String _enderecoDestino = 'Endereço do profissional';
  String _nomeProfissional = 'Profissional';
  String? _fotoCliente;
  String? _fotoProfissional;
  String _codigoCorreto = '';
  XFile? _fotoEntrada;
  bool _carregando = true;
  bool _enviando = false;
  bool _codigoValido = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _posicao?.cancel();
    for (final controller in _codigo) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final sol = await _supabase
          .from('solicitacoes')
          .select(
            'fk_usuario, fk_servico_prof, codigo_rec_dev, fk_grupo_empresa, '
            'fk_profissional, fk_endereco',
          )
          .eq('id_solicitacao', widget.idSolicitacao)
          .single();
      _codigoCorreto = sol['codigo_rec_dev']?.toString().trim() ?? '';

      final idCliente = (sol['fk_usuario'] as num?)?.toInt();
      if (idCliente != null) {
        final cliente = await _supabase
            .from('usuarios')
            .select('foto_perfil_url')
            .eq('id_usuario', idCliente)
            .maybeSingle();
        _fotoCliente = cliente?['foto_perfil_url']?.toString().trim();
      }

      final idServico = (sol['fk_servico_prof'] as num?)?.toInt();
      DetalheServicoPublico? detalhe;
      if (idServico != null) {
        detalhe = await ServicosProfissionalService.buscarDetalhePublico(
          idServico,
        );
      }
      if (detalhe != null) {
        _nomeProfissional = detalhe.nomePrestador;
        _fotoProfissional = detalhe.fotoPrestador;
        _destino = LatLng(detalhe.latitude, detalhe.longitude);
        _enderecoDestino = detalhe.enderecoFormatado;
      }
      await _iniciarLocalizacao();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar trajeto: $e')));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _iniciarLocalizacao() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      return;
    }
    final atual = await Geolocator.getCurrentPosition();
    _atualizarPosicao(atual);
    _posicao = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_atualizarPosicao);
  }

  void _atualizarPosicao(Position position) {
    if (!mounted) return;
    setState(() => _cliente = LatLng(position.latitude, position.longitude));
    _mapController.move(_cliente, 14);
  }

  void _validarCodigo() {
    final informado = _codigo.map((controller) => controller.text).join();
    setState(() {
      _codigoValido =
          informado.length == 4 && informado == _codigoCorreto;
    });
  }

  Future<void> _selecionarFoto() async {
    final foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto != null && mounted) setState(() => _fotoEntrada = foto);
  }

  Future<void> _confirmarEntrada() async {
    if (_fotoEntrada == null || !_codigoValido || _enviando) return;
    setState(() => _enviando = true);
    try {
      final bytes = await _fotoEntrada!.readAsBytes();
      final caminho =
          'solicitacao/${widget.idSolicitacao}/recebimento_cliente_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from('Imagens Recebimento')
          .uploadBinary(
            caminho,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      final url = _supabase.storage.from('Imagens Recebimento').getPublicUrl(
        caminho,
      );
      await _supabase
          .from('solicitacoes')
          .update({
            'imagens_recebimento': [url],
            'fk_status': 4,
            'etapa_solicitacao': 3,
            'data_inicio_andamento': DateTime.now().toIso8601String(),
            'andamento_pausado': false,
          })
          .eq('id_solicitacao', widget.idSolicitacao);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DetalhesPedidoPage(
            idSolicitacao: widget.idSolicitacao,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao registrar entrada: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _cliente,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'br.com.consertaja',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _cliente,
                          width: 52,
                          height: 52,
                          child: _avatar(_fotoCliente, Icons.person),
                        ),
                        Marker(
                          point: _destino,
                          width: 52,
                          height: 52,
                          child: _avatar(_fotoProfissional, Icons.storefront),
                        ),
                      ],
                    ),
                  ],
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 3,
                      child: ListTile(
                        leading: const Icon(Icons.arrow_back, color: texto),
                        onTap: () => Navigator.pop(context),
                        title: Text(
                          'Deslocamento até $_nomeProfissional',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: texto,
                          ),
                        ),
                        subtitle: Text(_enderecoDestino),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _painel(),
                ),
              ],
            ),
    );
  }

  Widget _painel() {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Registro de Entrada',
                style: TextStyle(
                  color: texto,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Adicione uma foto do produto e informe o código com o profissional.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _selecionarFoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(
                  _fotoEntrada == null
                      ? 'Adicionar foto obrigatória'
                      : 'Foto adicionada',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Código de entrega no balcão',
                style: TextStyle(color: texto, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  4,
                  (index) => SizedBox(
                    width: 58,
                    child: TextField(
                      controller: _codigo[index],
                      maxLength: 1,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (_) => _validarCodigo(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _fotoEntrada != null && _codigoValido
                      ? _confirmarEntrada
                      : null,
                  icon: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar entrada'),
                  style: FilledButton.styleFrom(backgroundColor: azul),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(String? url, IconData icon) {
    return CircleAvatar(
      backgroundColor: azul,
      backgroundImage: url != null && url.isNotEmpty
          ? NetworkImage(url)
          : null,
      child: url == null || url.isEmpty
          ? Icon(icon, color: Colors.white)
          : null,
    );
  }
}
