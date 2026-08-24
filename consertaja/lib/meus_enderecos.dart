import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tela_home.dart';
import 'tela_home_profissional.dart';
import 'tela_meu_perfil_cliente.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/bottom_navigation_bar_cliente.dart';
import 'utils/bottom_navigation_bar_profissional.dart';

/// Constantes dos nomes das tabelas no Supabase
const String _tabelaEndereco = 'enderecos';
const String _tabelaAssUsuarioEndereco = 'ass_usuario_endereco';
const String _tabelaCidade = 'cidades';
const String _tabelaEstado = 'estados';

class EnderecoEditData {
  final int idEndereco;
  final String cep;
  final String logradouro;
  final String numero;
  final String bairro;
  final String complemento;
  final String cidade;
  final String estado;
  final String tipoEndereco;
  final double? latitude;
  final double? longitude;

  const EnderecoEditData({
    required this.idEndereco,
    required this.cep,
    required this.logradouro,
    required this.numero,
    required this.bairro,
    required this.complemento,
    required this.cidade,
    required this.estado,
    required this.tipoEndereco,
    this.latitude,
    this.longitude,
  });
}

class _EnderecoItem {
  final int? id;
  final String titulo;
  final IconData icone;
  final double? latitude;
  final double? longitude;
  final String linha1;
  final String? linha2;
  final String? linha3;
  final String? cep;
  final bool exibirMapa;
  final bool principal;
  final String logradouro;
  final String numero;
  final String bairro;
  final String complemento;
  final String cidade;
  final String estado;
  final String tipoEndereco;

  const _EnderecoItem({
    this.id,
    this.titulo = 'Endereço',
    this.icone = Icons.location_on_outlined,
    this.latitude,
    this.longitude,
    this.linha1 = '',
    this.linha2,
    this.linha3,
    this.cep,
    this.exibirMapa = false,
    this.principal = false,
    this.logradouro = '',
    this.numero = '',
    this.bairro = '',
    this.complemento = '',
    this.cidade = '',
    this.estado = '',
    this.tipoEndereco = 'Casa',
  });

  EnderecoEditData toEditData() {
    return EnderecoEditData(
      idEndereco: id!,
      cep: cep ?? '',
      logradouro: logradouro,
      numero: numero,
      bairro: bairro,
      complemento: complemento,
      cidade: cidade,
      estado: estado,
      tipoEndereco: tipoEndereco,
      latitude: latitude,
      longitude: longitude,
    );
  }

  _EnderecoItem copyWith({bool? principal}) {
    return _EnderecoItem(
      id: id,
      titulo: titulo,
      icone: icone,
      latitude: latitude,
      longitude: longitude,
      linha1: linha1,
      linha2: linha2,
      linha3: linha3,
      cep: cep,
      exibirMapa: exibirMapa,
      principal: principal ?? this.principal,
      logradouro: logradouro,
      numero: numero,
      bairro: bairro,
      complemento: complemento,
      cidade: cidade,
      estado: estado,
      tipoEndereco: tipoEndereco,
    );
  }
}

class MeusEnderecosPage extends StatefulWidget {
  final bool isVisitante;
  final bool isProfissional;

  const MeusEnderecosPage({
    super.key,
    this.isVisitante = false,
    this.isProfissional = false,
  });

  @override
  State<MeusEnderecosPage> createState() => _MeusEnderecosPageState();
}

class _MeusEnderecosPageState extends State<MeusEnderecosPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGray = Color(0xFF7B7B7B);
  static const Color _iconGray = Color(0xFF878B8D);
  static const Color _iconCircleGray = Color(0xFFF0F0F0);

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';

  List<_EnderecoItem> _enderecos = [];
  bool _carregando = true;
  bool _erro = false;

  @override
  void initState() {
    super.initState();
    _carregarEnderecos();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<int?> _buscarIdUsuario(SupabaseClient supabase, String authId) async {
    final usuarioResponse = await supabase
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', authId)
        .maybeSingle();
    if (usuarioResponse == null) return null;
    return usuarioResponse['id_usuario'] is int
        ? usuarioResponse['id_usuario'] as int
        : int.tryParse(usuarioResponse['id_usuario']?.toString() ?? '');
  }

  Future<void> _carregarEnderecos() async {
    setState(() {
      _carregando = true;
      _erro = false;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            _enderecos = [];
            _carregando = false;
          });
        }
        return;
      }

      final usuarioId = await _buscarIdUsuario(supabase, user.id);
      if (usuarioId == null) {
        if (mounted) {
          setState(() {
            _enderecos = [];
            _carregando = false;
          });
        }
        return;
      }

      // 1. Busca associações do usuário
      final assResponse = await supabase
          .from(_tabelaAssUsuarioEndereco)
          .select(
            'fk_endereco, apelido_endereco, tipo_endereco, endereco_ativo',
          )
          .eq('fk_usuario', usuarioId);

      if (assResponse.isEmpty) {
        if (mounted) {
          setState(() {
            _enderecos = [];
            _carregando = false;
          });
        }
        return;
      }

      // 2. Busca todos os endereços
      final enderecosResponse = await supabase
          .from(_tabelaEndereco)
          .select(
            'id_endereco, cep, logradouro, numero, bairro, complemento, fk_cidade, latitude, longitude',
          );

      // 3. Busca cidades e estados
      final cidadesResponse = await supabase
          .from(_tabelaCidade)
          .select('id_cidade, nome_cidade, fk_estado');

      final estadosResponse = await supabase
          .from(_tabelaEstado)
          .select('id_estado, sigla_estado');

      final Map<int, Map<String, dynamic>> cidadesMap = {};
      for (final c in cidadesResponse) {
        final id = c['id_cidade'] is int
            ? c['id_cidade'] as int
            : int.tryParse(c['id_cidade']?.toString() ?? '');
        if (id != null) cidadesMap[id] = Map<String, dynamic>.from(c);
      }

      final Map<int, String> estadosMap = {};
      for (final e in estadosResponse) {
        final id = e['id_estado'] is int
            ? e['id_estado'] as int
            : int.tryParse(e['id_estado']?.toString() ?? '');
        final sigla = e['sigla_estado']?.toString() ?? '';
        if (id != null) estadosMap[id] = sigla;
      }

      // 4. Monta os itens
      final enderecos = <_EnderecoItem>[];

      for (final ass in assResponse) {
        final fkEndereco = ass['fk_endereco'];
        final idEndereco = fkEndereco is int
            ? fkEndereco
            : int.tryParse(fkEndereco?.toString() ?? '');
        if (idEndereco == null) continue;

        final itemRow = enderecosResponse.firstWhere((e) {
          final id = e['id_endereco'];
          final eid = id is int ? id : int.tryParse(id?.toString() ?? '');
          return eid == idEndereco;
        }, orElse: () => const {});

        final logradouro = itemRow['logradouro']?.toString() ?? '';
        final numero = itemRow['numero']?.toString() ?? '';
        final bairro = itemRow['bairro']?.toString() ?? '';
        final complemento = itemRow['complemento']?.toString() ?? '';
        final cep = itemRow['cep']?.toString() ?? '';
        final fkCidade = itemRow['fk_cidade'];
        final latDb = double.tryParse(itemRow['latitude']?.toString() ?? '');
        final lngDb = double.tryParse(itemRow['longitude']?.toString() ?? '');

        final idCidade = fkCidade is int
            ? fkCidade
            : int.tryParse(fkCidade?.toString() ?? '');

        final cidadeInfo = idCidade != null ? cidadesMap[idCidade] : null;
        final cidade = cidadeInfo?['nome_cidade']?.toString() ?? '';

        final fkEstado = cidadeInfo?['fk_estado'];
        final idEstado = fkEstado is int
            ? fkEstado
            : int.tryParse(fkEstado?.toString() ?? '');
        final estado = idEstado != null ? estadosMap[idEstado] ?? '' : '';

        final tipoEndereco =
            ass['tipo_endereco']?.toString() ??
            ass['apelido_endereco']?.toString() ??
            'Casa';
        final titulo =
            ass['tipo_endereco']?.toString() ??
            ass['apelido_endereco']?.toString() ??
            'Endereço';
        final ativo = ass['endereco_ativo'] == true;

        final linha1 = numero.isNotEmpty ? '$logradouro, $numero' : logradouro;

        final detalhesBairro = [
          if (bairro.isNotEmpty) bairro,
          if (complemento.isNotEmpty) complemento,
        ].join(', ');
        final linha2 = detalhesBairro.isNotEmpty ? detalhesBairro : null;

        final linha3 = cidade.isNotEmpty ? '$cidade - $estado' : null;

        enderecos.add(
          _EnderecoItem(
            id: idEndereco,
            titulo: titulo.toUpperCase(),
            icone: _iconeParaTitulo(titulo),
            latitude: latDb,
            longitude: lngDb,
            linha1: linha1.isNotEmpty ? linha1 : 'Endereço sem logradouro',
            linha2: linha2,
            linha3: linha3,
            cep: cep.isNotEmpty ? cep : null,
            exibirMapa: ativo,
            principal: ativo,
            logradouro: logradouro,
            numero: numero,
            bairro: bairro,
            complemento: complemento,
            cidade: cidade,
            estado: estado,
            tipoEndereco: tipoEndereco,
          ),
        );
      }

      // Ordena para que o endereço ativo venha primeiro
      enderecos.sort((a, b) {
        if (a.principal == b.principal) return 0;
        return a.principal ? -1 : 1;
      });

      if (mounted) {
        setState(() {
          _enderecos = enderecos;
          _carregando = false;
        });
      }

      // Geocodifica o endereço principal se não tiver coordenadas salvas
      final principal = enderecos.where((e) => e.principal).firstOrNull;
      if (principal != null && principal.latitude == null) {
        await _geocodificarEnderecoPrincipal(principal);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = true;
          _carregando = false;
        });
      }
    }
  }

  Future<void> _geocodificarEnderecoPrincipal(_EnderecoItem endereco) async {
    try {
      final logradouro = endereco.logradouro;
      final numero = endereco.numero;
      final bairro = endereco.bairro;
      final cidade = endereco.cidade;
      final uf = endereco.estado;

      if (logradouro.isEmpty || cidade.isEmpty || uf.isEmpty) return;

      final partes = <String>[
        if (logradouro.isNotEmpty)
          numero.isNotEmpty ? '$logradouro, $numero' : logradouro,
        if (bairro.isNotEmpty) bairro,
        cidade,
        uf,
        'Brasil',
      ];
      final query = Uri.encodeComponent(partes.join(', '));

      final resposta = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
        ),
        headers: const {
          'User-Agent': 'ConsertaJa/1.0 (contato@consertaja.com.br)',
        },
      );

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final lista = jsonDecode(resposta.body) as List<dynamic>;
        if (lista.isNotEmpty) {
          final dados = lista.first as Map<String, dynamic>;
          final lat = double.tryParse(dados['lat']?.toString() ?? '');
          final lng = double.tryParse(dados['lon']?.toString() ?? '');

          if (lat != null && lng != null) {
            setState(() {
              _enderecos = _enderecos.map((e) {
                if (e.id == endereco.id) {
                  return _EnderecoItem(
                    id: e.id,
                    titulo: e.titulo,
                    icone: e.icone,
                    latitude: lat,
                    longitude: lng,
                    linha1: e.linha1,
                    linha2: e.linha2,
                    linha3: e.linha3,
                    cep: e.cep,
                    exibirMapa: e.exibirMapa,
                    principal: e.principal,
                    logradouro: e.logradouro,
                    numero: e.numero,
                    bairro: e.bairro,
                    complemento: e.complemento,
                    cidade: e.cidade,
                    estado: e.estado,
                    tipoEndereco: e.tipoEndereco,
                  );
                }
                return e;
              }).toList();
            });
          }
        }
      }
    } catch (_) {
      // Falha silenciosa na geocodificação
    }
  }

  IconData _iconeParaTitulo(String titulo) {
    final t = titulo.toLowerCase();
    if (t.contains('casa')) return Icons.home_rounded;
    if (t.contains('trabalho')) return Icons.work_outline_rounded;
    return Icons.location_on_outlined;
  }

  Future<void> _definirComoPrincipal(_EnderecoItem endereco) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final usuarioId = await _buscarIdUsuario(supabase, user.id);
      if (usuarioId == null) return;

      // Remove o "ativo" de todos os endereços do usuário
      await supabase
          .from(_tabelaAssUsuarioEndereco)
          .update({'endereco_ativo': false})
          .eq('fk_usuario', usuarioId);

      // Define o endereço selecionado como ativo (principal)
      if (endereco.id != null) {
        await supabase
            .from(_tabelaAssUsuarioEndereco)
            .update({'endereco_ativo': true})
            .eq('fk_usuario', usuarioId)
            .eq('fk_endereco', endereco.id!);
      }

      // Atualiza a lista local
      setState(() {
        _enderecos = _enderecos.map((e) {
          return e.copyWith(principal: e.id == endereco.id);
        }).toList();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereço definido como principal!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao definir endereço principal: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _abrirEditarEndereco(_EnderecoItem endereco) async {
    if (endereco.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdicionarEnderecoPage(
          isVisitante: widget.isVisitante,
          isProfissional: widget.isProfissional,
          enderecoEditar: endereco.toEditData(),
        ),
      ),
    );
    _carregarEnderecos();
  }

  Future<void> _confirmarExclusaoEndereco(_EnderecoItem endereco) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Excluir endereço?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Deseja excluir o endereço "${endereco.titulo}"? Esta ação não pode ser desfeita.',
          style: const TextStyle(fontSize: 14, color: _textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: _textGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _excluirEndereco(endereco);
    }
  }

  Future<void> _excluirEndereco(_EnderecoItem endereco) async {
    if (endereco.id == null) return;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final usuarioId = await _buscarIdUsuario(supabase, user.id);
      if (usuarioId == null) return;

      final eraPrincipal = endereco.principal;

      await supabase
          .from(_tabelaAssUsuarioEndereco)
          .delete()
          .eq('fk_usuario', usuarioId)
          .eq('fk_endereco', endereco.id!);

      await supabase
          .from(_tabelaEndereco)
          .delete()
          .eq('id_endereco', endereco.id!);

      if (eraPrincipal) {
        final restantes = await supabase
            .from(_tabelaAssUsuarioEndereco)
            .select('fk_endereco')
            .eq('fk_usuario', usuarioId)
            .limit(1);

        if (restantes.isNotEmpty) {
          final fk = restantes.first['fk_endereco'];
          final idRestante = fk is int
              ? fk
              : int.tryParse(fk?.toString() ?? '');
          if (idRestante != null) {
            await supabase
                .from(_tabelaAssUsuarioEndereco)
                .update({'endereco_ativo': true})
                .eq('fk_usuario', usuarioId)
                .eq('fk_endereco', idRestante);
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Endereço excluído com sucesso!'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      _carregarEnderecos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir endereço: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildBotoesAcaoEndereco(_EnderecoItem endereco) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _abrirEditarEndereco(endereco),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.edit_outlined,
            color: Colors.grey.shade500,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => _confirmarExclusaoEndereco(endereco),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.delete_outline,
            color: Colors.grey.shade500,
            size: 20,
          ),
        ),
      ],
    );
  }

  Future<void> _mostrarDialogoPrincipal(_EnderecoItem endereco) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Definir como principal?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Deseja transformar o endereço "${endereco.titulo}" em seu endereço principal?',
          style: const TextStyle(fontSize: 14, color: _textGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: _textGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: _blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _definirComoPrincipal(endereco);
    }
  }

  PageRouteBuilder<T> _rotaSemAnimacao<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, _, _) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  bool _correspondeBusca(_EnderecoItem endereco) {
    if (_termoBusca.trim().isEmpty) return true;
    final termo = _termoBusca.toLowerCase();
    final campos = [
      endereco.titulo,
      endereco.linha1,
      endereco.linha2 ?? '',
      endereco.linha3 ?? '',
      endereco.cep ?? '',
    ];
    return campos.any((campo) => campo.toLowerCase().contains(termo));
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      backgroundColor: _blue,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
      ),
      title: const Text(
        'Meus Endereços',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildBarraPesquisa() {
    return Container(
      color: _background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _buscaController,
          onChanged: (value) => setState(() => _termoBusca = value),
          style: const TextStyle(fontSize: 15, color: _textDark),
          decoration: InputDecoration(
            hintText: 'Buscar endereço',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.grey.shade400,
              size: 22,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildTituloSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Text(
        titulo,
        style: const TextStyle(
          color: _textDark,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildIconeEndereco({
    required IconData icone,
    required bool principal,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: _iconCircleGray, shape: BoxShape.circle),
      child: Icon(icone, color: principal ? _blue : _iconGray, size: 22),
    );
  }

  Widget _buildLinhasEndereco(_EnderecoItem endereco) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          endereco.linha1,
          style: const TextStyle(
            color: _textDark,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        if (endereco.linha2 != null)
          Text(
            endereco.linha2!,
            style: const TextStyle(color: _textGray, fontSize: 14, height: 1.4),
          ),
        if (endereco.linha3 != null)
          Text(
            endereco.linha3!,
            style: const TextStyle(color: _textGray, fontSize: 14, height: 1.4),
          ),
        if (endereco.cep != null)
          Text(
            endereco.cep!,
            style: const TextStyle(color: _textGray, fontSize: 14, height: 1.4),
          ),
      ],
    );
  }

  Widget _buildMapaMiniatura() {
    final principal = _enderecos.where((e) => e.principal).firstOrNull;
    final double? lat = principal?.latitude;
    final double? lng = principal?.longitude;
    final bool temCoordenadas = lat != null && lng != null;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 130,
            width: double.infinity,
            child: temCoordenadas
                ? FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(lat, lng),
                      initialZoom: 16,
                      minZoom: 3,
                      maxZoom: 19,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'br.com.consertaja',
                        maxNativeZoom: 19,
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(lat, lng),
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.location_on,
                              color: _blue,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : CustomPaint(
                    painter: _MapaPlaceholderPainter(),
                    child: Container(color: const Color(0xFFE8EDE8)),
                  ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.map_outlined, color: _blue, size: 18),
                SizedBox(width: 6),
                Text(
                  'Ver no mapa',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardPrincipal(_EnderecoItem endereco) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconeEndereco(icone: endereco.icone, principal: true),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  endereco.titulo,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              _buildBotoesAcaoEndereco(endereco),
            ],
          ),
          const SizedBox(height: 12),
          _buildLinhasEndereco(endereco),
          if (endereco.exibirMapa) ...[
            const SizedBox(height: 14),
            _buildMapaMiniatura(),
          ],
        ],
      ),
    );
  }

  Widget _buildCardOutroEndereco(_EnderecoItem endereco) {
    return GestureDetector(
      onTap: () => _mostrarDialogoPrincipal(endereco),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIconeEndereco(icone: endereco.icone, principal: false),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    endereco.titulo,
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                _buildBotoesAcaoEndereco(endereco),
              ],
            ),
            const SizedBox(height: 10),
            _buildLinhasEndereco(endereco),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoAdicionar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: CustomPaint(
        painter: _BordaTracejadaPainter(color: _blue.withValues(alpha: 0.5)),
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdicionarEnderecoPage(
                  isVisitante: widget.isVisitante,
                  isProfissional: widget.isProfissional,
                ),
              ),
            );
            _carregarEnderecos();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.location_on, color: _blue, size: 36),
                    Positioned(
                      top: 6,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: _blue, size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Adicionar Novo Endereço',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return widget.isProfissional
        ? BottomNavigationBarProfissional(
            currentIndex: 4,
            onTap: _onBottomNavigationTap,
          )
        : BottomNavigationBarCliente(
            currentIndex: 4,
            onTap: _onBottomNavigationTap,
          );
  }

  void _onBottomNavigationTap(int index) {
    if (index == 0) {
      Navigator.of(context).pushReplacement(
        _rotaSemAnimacao(
          widget.isProfissional
              ? TelaHomeProfissional(isVisitante: widget.isVisitante)
              : TelaHome(isVisitante: widget.isVisitante),
        ),
      );
    } else if (index == 4) {
      Navigator.of(context).pushReplacement(
        _rotaSemAnimacao(
          widget.isProfissional
              ? TelaMeuPerfilProfissionalPage(isVisitante: widget.isVisitante)
              : TelaMeuPerfilClientePage(isVisitante: widget.isVisitante),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enderecoPrincipal = _enderecos.where((e) => e.principal).firstOrNull;
    final outrosEnderecos = _enderecos.where((e) => !e.principal).toList();

    final exibirPrincipal =
        enderecoPrincipal != null && _correspondeBusca(enderecoPrincipal);
    final outrosFiltrados = outrosEnderecos.where(_correspondeBusca).toList();

    return Scaffold(
      backgroundColor: _background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildAppBar(),
      ),
      body: Column(
        children: [
          _buildBarraPesquisa(),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator(color: _blue))
                : _erro
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.grey.shade400,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Erro ao carregar endereços.',
                          style: TextStyle(color: _textGray, fontSize: 15),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _carregarEnderecos,
                          child: const Text(
                            'Tentar novamente',
                            style: TextStyle(color: _blue),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (exibirPrincipal) ...[
                        _buildTituloSecao('Endereço Principal'),
                        _buildCardPrincipal(enderecoPrincipal),
                        const SizedBox(height: 20),
                      ],
                      if (outrosFiltrados.isNotEmpty) ...[
                        _buildTituloSecao('Outros Endereços'),
                        ...outrosFiltrados.map(_buildCardOutroEndereco),
                      ],
                      if (!exibirPrincipal && outrosFiltrados.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _enderecos.isEmpty
                                ? 'Nenhum endereço cadastrado ainda.'
                                : 'Nenhum endereço encontrado.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      _buildBotaoAdicionar(),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

class AdicionarEnderecoPage extends StatefulWidget {
  final bool isVisitante;
  final bool isProfissional;
  final EnderecoEditData? enderecoEditar;

  const AdicionarEnderecoPage({
    super.key,
    this.isVisitante = false,
    this.isProfissional = false,
    this.enderecoEditar,
  });

  bool get isEdicao => enderecoEditar != null;

  @override
  State<AdicionarEnderecoPage> createState() => _AdicionarEnderecoPageState();
}

class _AdicionarEnderecoPageState extends State<AdicionarEnderecoPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _labelGray = Color(0xFF4A4A4A);
  static const Color _inputFill = Color(0xFFF5F5F5);

  static const List<String> _estados = [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];

  final TextEditingController _cepController = TextEditingController();
  final TextEditingController _logradouroController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _complementoController = TextEditingController();
  final TextEditingController _bairroController = TextEditingController();
  final TextEditingController _cidadeController = TextEditingController();

  String? _estadoSelecionado;
  String _tipoSalvar = 'Casa';
  bool _salvando = false;

  // Coordenadas do mapa (CEP, geocodificação ou clique)
  double? _mapLat;
  double? _mapLng;
  bool _buscandoCep = false;
  bool _geocodificando = false;
  Timer? _geocodeDebounce;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    final edit = widget.enderecoEditar;
    if (edit != null) {
      _cepController.text = edit.cep;
      _logradouroController.text = edit.logradouro;
      _numeroController.text = edit.numero;
      _complementoController.text = edit.complemento;
      _bairroController.text = edit.bairro;
      _cidadeController.text = edit.cidade;
      _estadoSelecionado = _estados.contains(edit.estado.toUpperCase())
          ? edit.estado.toUpperCase()
          : null;
      _tipoSalvar = edit.tipoEndereco;

      // Carrega coordenadas salvas se existirem
      if (edit.latitude != null && edit.longitude != null) {
        _mapLat = edit.latitude;
        _mapLng = edit.longitude;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _geocodificarEndereco();
        });
      }
    }

    _numeroController.addListener(_agendarGeocodificacao);
    _logradouroController.addListener(_agendarGeocodificacao);
    _bairroController.addListener(_agendarGeocodificacao);
    _cidadeController.addListener(_agendarGeocodificacao);
  }

  void _agendarGeocodificacao() {
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(
      const Duration(milliseconds: 900),
      _geocodificarEndereco,
    );
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    _mapController.dispose();
    _numeroController.removeListener(_agendarGeocodificacao);
    _logradouroController.removeListener(_agendarGeocodificacao);
    _bairroController.removeListener(_agendarGeocodificacao);
    _cidadeController.removeListener(_agendarGeocodificacao);
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    super.dispose();
  }

  Future<void> _buscarCep() async {
    FocusScope.of(context).unfocus();

    final cep = _cepController.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um CEP válido com 8 dígitos.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _buscandoCep = true);

    try {
      final resposta = await http.get(
        Uri.parse('https://cep.awesomeapi.com.br/json/$cep'),
      );

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body) as Map<String, dynamic>;
        final uf = (dados['state']?.toString() ?? '').toUpperCase().trim();
        final latitude = double.tryParse(dados['lat']?.toString() ?? '');
        final longitude = double.tryParse(dados['lng']?.toString() ?? '');

        setState(() {
          _logradouroController.text =
              dados['address']?.toString().trim() ?? '';
          _bairroController.text = dados['district']?.toString().trim() ?? '';
          _cidadeController.text = dados['city']?.toString().trim() ?? '';
          _estadoSelecionado = _estados.contains(uf) ? uf : null;
          _mapLat = (latitude != null && latitude != 0) ? latitude : null;
          _mapLng = (longitude != null && longitude != 0) ? longitude : null;
          _buscandoCep = false;
        });

        if (_mapLat != null && _mapLng != null) {
          _moverMapaParaCoordenadas(_mapLat!, _mapLng!);
        }

        if (_numeroController.text.trim().isNotEmpty) {
          _geocodificarEndereco();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Endereço encontrado! Campos preenchidos automaticamente.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _mapLat = null;
          _mapLng = null;
          _buscandoCep = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resposta.statusCode == 404
                  ? 'CEP não encontrado. Verifique e tente novamente.'
                  : 'CEP inválido. Informe apenas os 8 números.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _mapLat = null;
          _mapLng = null;
          _buscandoCep = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erro ao buscar o CEP. Verifique sua conexão e tente novamente.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _geocodificarEndereco() async {
    final logradouro = _logradouroController.text.trim();
    final numero = _numeroController.text.trim();
    final bairro = _bairroController.text.trim();
    final cidade = _cidadeController.text.trim();
    final uf = _estadoSelecionado ?? '';

    if (logradouro.isEmpty || cidade.isEmpty || uf.isEmpty) return;

    setState(() => _geocodificando = true);

    try {
      final partes = <String>[
        if (logradouro.isNotEmpty)
          numero.isNotEmpty ? '$logradouro, $numero' : logradouro,
        if (bairro.isNotEmpty) bairro,
        cidade,
        uf,
        'Brasil',
      ];
      final query = Uri.encodeComponent(partes.join(', '));

      final resposta = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1',
        ),
        headers: const {
          'User-Agent': 'ConsertaJa/1.0 (contato@consertaja.com.br)',
        },
      );

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final lista = jsonDecode(resposta.body) as List<dynamic>;
        if (lista.isNotEmpty) {
          final dados = lista.first as Map<String, dynamic>;
          final lat = double.tryParse(dados['lat']?.toString() ?? '');
          final lng = double.tryParse(dados['lon']?.toString() ?? '');

          if (lat != null && lng != null) {
            setState(() {
              _mapLat = lat;
              _mapLng = lng;
              _geocodificando = false;
            });
            _moverMapaParaCoordenadas(lat, lng);
            return;
          }
        }
      }

      if (mounted) setState(() => _geocodificando = false);
    } catch (_) {
      if (mounted) setState(() => _geocodificando = false);
    }
  }

  void _moverMapaParaCoordenadas(double lat, double lng) {
    try {
      _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
    } catch (_) {
      // Mapa ainda não montado; coordenadas serão usadas no próximo build.
    }
  }

  Future<int?> _buscarIdUsuario(SupabaseClient supabase, String authId) async {
    final usuarioResponse = await supabase
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', authId)
        .maybeSingle();
    if (usuarioResponse == null) return null;
    return usuarioResponse['id_usuario'] is int
        ? usuarioResponse['id_usuario'] as int
        : int.tryParse(usuarioResponse['id_usuario']?.toString() ?? '');
  }

  Future<void> _salvarEndereco() async {
    FocusScope.of(context).unfocus();

    if (_logradouroController.text.trim().isEmpty ||
        _cidadeController.text.trim().isEmpty ||
        _estadoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha os campos obrigatórios: logradouro, cidade e estado.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() => _salvando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Você precisa estar logado para salvar um endereço.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final usuarioId = await _buscarIdUsuario(supabase, user.id);
      if (usuarioId == null) {
        if (mounted) {
          setState(() => _salvando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuário não encontrado no sistema.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final assResponse = await supabase
          .from(_tabelaAssUsuarioEndereco)
          .select('fk_endereco')
          .eq('fk_usuario', usuarioId);

      final isPrimeiroEndereco = assResponse.isEmpty;

      // 1. Busca ou cria o estado (UF)
      final estadoResponse = await supabase
          .from(_tabelaEstado)
          .select('id_estado')
          .eq('sigla_estado', _estadoSelecionado!)
          .maybeSingle();

      int idEstado;
      if (estadoResponse == null) {
        final novoEstado = await supabase
            .from(_tabelaEstado)
            .insert({
              'sigla_estado': _estadoSelecionado!,
              'nome_estado': _estadoSelecionado!,
            })
            .select('id_estado')
            .single();
        idEstado = novoEstado['id_estado'] is int
            ? novoEstado['id_estado'] as int
            : int.parse(novoEstado['id_estado'].toString());
      } else {
        idEstado = estadoResponse['id_estado'] is int
            ? estadoResponse['id_estado'] as int
            : int.parse(estadoResponse['id_estado'].toString());
      }

      // 2. Busca ou cria a cidade
      final cidadeResponse = await supabase
          .from(_tabelaCidade)
          .select('id_cidade')
          .eq('nome_cidade', _cidadeController.text.trim())
          .eq('fk_estado', idEstado)
          .maybeSingle();

      int idCidade;
      if (cidadeResponse == null) {
        final novaCidade = await supabase
            .from(_tabelaCidade)
            .insert({
              'nome_cidade': _cidadeController.text.trim(),
              'fk_estado': idEstado,
            })
            .select('id_cidade')
            .single();
        idCidade = novaCidade['id_cidade'] is int
            ? novaCidade['id_cidade'] as int
            : int.parse(novaCidade['id_cidade'].toString());
      } else {
        idCidade = cidadeResponse['id_cidade'] is int
            ? cidadeResponse['id_cidade'] as int
            : int.parse(cidadeResponse['id_cidade'].toString());
      }

      // 3. Salva ou atualiza o endereço (incluindo latitude/longitude do ponteiro)
      final dadosEndereco = {
        'cep': _cepController.text.trim(),
        'logradouro': _logradouroController.text.trim(),
        'numero': _numeroController.text.trim(),
        'bairro': _bairroController.text.trim(),
        'complemento': _complementoController.text.trim(),
        'fk_cidade': idCidade,
        if (_mapLat != null) 'latitude': _mapLat,
        if (_mapLng != null) 'longitude': _mapLng,
      };

      if (widget.isEdicao) {
        final idEndereco = widget.enderecoEditar!.idEndereco;

        await supabase
            .from(_tabelaEndereco)
            .update(dadosEndereco)
            .eq('id_endereco', idEndereco);

        await supabase
            .from(_tabelaAssUsuarioEndereco)
            .update({
              'apelido_endereco': _tipoSalvar,
              'tipo_endereco': _tipoSalvar,
            })
            .eq('fk_usuario', usuarioId)
            .eq('fk_endereco', idEndereco);
      } else {
        final enderecoResponse = await supabase
            .from(_tabelaEndereco)
            .insert(dadosEndereco)
            .select('id_endereco')
            .single();

        final idEndereco = enderecoResponse['id_endereco'] is int
            ? enderecoResponse['id_endereco'] as int
            : int.parse(enderecoResponse['id_endereco'].toString());

        await supabase.from(_tabelaAssUsuarioEndereco).insert({
          'fk_usuario': usuarioId,
          'fk_endereco': idEndereco,
          'apelido_endereco': _tipoSalvar,
          'tipo_endereco': _tipoSalvar,
          'endereco_ativo': isPrimeiroEndereco,
        });
      }

      if (mounted) {
        setState(() => _salvando = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEdicao
                  ? 'Endereço atualizado com sucesso!'
                  : 'Endereço salvo com sucesso!',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar endereço: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: _inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildLabel(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: _labelGray,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCampo({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            style: const TextStyle(color: _textDark, fontSize: 14),
            decoration: _inputDecoration(hint),
          ),
        ],
      ),
    );
  }

  Widget _buildMapaPreview() {
    final double? lat = _mapLat;
    final double? lng = _mapLng;
    final bool temCoordenadas = lat != null && lng != null;
    final String cidade = _cidadeController.text.trim().isNotEmpty
        ? _cidadeController.text.trim()
        : 'São Paulo';
    final String uf = _estadoSelecionado ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            SizedBox(
              height: 180,
              width: double.infinity,
              child: temCoordenadas
                  ? FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(lat, lng),
                        initialZoom: 15,
                        minZoom: 3,
                        maxZoom: 19,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _mapLat = point.latitude;
                            _mapLng = point.longitude;
                          });
                        },
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'br.com.consertaja',
                          maxNativeZoom: 19,
                          maxZoom: 19,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.location_on,
                                color: _blue,
                                size: 36,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : CustomPaint(
                      painter: _MapaCidadePainter(),
                      child: Container(color: const Color(0xFFE4EBE4)),
                    ),
            ),
            if (!temCoordenadas)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: _blue,
                        size: 42,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cidade,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_geocodificando)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: _blue,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  temCoordenadas
                      ? (uf.isNotEmpty ? '$cidade - $uf' : cidade)
                      : 'Informe o CEP para visualizar no mapa',
                  style: const TextStyle(
                    color: Color(0xFF2B2B2B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (temCoordenadas)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Toque no mapa para ajustar',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoCep() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel('CEP'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cepController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CepInputFormatter()],
                  style: const TextStyle(color: _textDark, fontSize: 14),
                  decoration: _inputDecoration('00000-000'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _buscandoCep ? null : _buscarCep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _blue.withValues(alpha: 0.6),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: _buscandoCep
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.search, size: 18),
                  label: Text(
                    _buscandoCep ? '...' : 'Buscar',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCampoEstado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Estado'),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _inputFill,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _estadoSelecionado,
              isExpanded: true,
              hint: Text(
                'UF',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.grey.shade500,
              ),
              style: const TextStyle(color: _textDark, fontSize: 14),
              items: _estados
                  .map(
                    (uf) =>
                        DropdownMenuItem<String>(value: uf, child: Text(uf)),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _estadoSelecionado = value);
                _agendarGeocodificacao();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChipTipo(String label) {
    final selecionado = _tipoSalvar == label;
    return GestureDetector(
      onTap: () => setState(() => _tipoSalvar = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selecionado ? _blue : Colors.grey.shade300,
            width: selecionado ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selecionado ? _blue : _labelGray,
            fontSize: 14,
            fontWeight: selecionado ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCampoCep(),
          _buildCampo(
            label: 'Logradouro',
            controller: _logradouroController,
            hint: 'Ex: Rua das Flores',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: _buildCampo(
                  label: 'Número',
                  controller: _numeroController,
                  hint: '123',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildCampo(
                  label: 'Complemento (Opcional)',
                  controller: _complementoController,
                  hint: 'Apto, Sala, Bloco...',
                ),
              ),
            ],
          ),
          _buildCampo(
            label: 'Bairro',
            controller: _bairroController,
            hint: 'Ex: Centro',
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildCampo(
                  label: 'Cidade',
                  controller: _cidadeController,
                  hint: 'Sua Cidade',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildCampoEstado(),
                ),
              ),
            ],
          ),
          _buildLabel('Salvar como'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildChipTipo('Casa'),
              _buildChipTipo('Trabalho'),
              _buildChipTipo('Outro'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: _textDark),
        ),
        title: Text(
          widget.isEdicao ? 'Editar Endereço' : 'Adicionar Endereço',
          style: const TextStyle(
            color: _textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildMapaPreview(),
                  _buildFormulario(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          Container(
            color: _background,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvarEndereco,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _salvando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.isEdicao
                            ? 'Salvar Alterações'
                            : 'Salvar Endereço',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 5) buffer.write('-');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _MapaCidadePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blockPaint = Paint()..color = const Color(0xFFDCE3DC);
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const blockSize = 28.0;
    for (var x = 0.0; x < size.width; x += blockSize) {
      for (var y = 0.0; y < size.height; y += blockSize) {
        if ((x / blockSize + y / blockSize).toInt().isEven) {
          canvas.drawRect(
            Rect.fromLTWH(x + 1, y + 1, blockSize - 2, blockSize - 2),
            blockPaint,
          );
        }
      }
    }

    for (var x = 0.0; x <= size.width; x += blockSize * 2) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), roadPaint);
    }
    for (var y = 0.0; y <= size.height; y += blockSize * 2) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), roadPaint);
    }

    final avenuePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.35, size.height),
      avenuePaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.45),
      Offset(size.width, size.height * 0.5),
      avenuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapaPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final routePaint = Paint()
      ..color = const Color(0xFF0FB3FF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final roadPath = Path()
      ..moveTo(0, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.45);

    final routePath = Path()
      ..moveTo(size.width * 0.15, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.2,
        size.width * 0.85,
        size.height * 0.55,
      );

    canvas.drawPath(roadPath, roadPaint);
    canvas.drawPath(routePath, routePaint);

    final pinPaint = Paint()..color = const Color(0xFF0FB3FF);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.55),
      6,
      pinPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BordaTracejadaPainter extends CustomPainter {
  final Color color;

  _BordaTracejadaPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordaTracejadaPainter oldDelegate) =>
      oldDelegate.color != color;
}
