import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'minhas_postagens_profissional.dart';
import 'models/postagem_resumo.dart';
import 'services/postagens_profissional_service.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/cor_oficio.dart';
import 'widgets/tag_oficio.dart';

class TelaHomeProfissional extends StatefulWidget {
  final bool isVisitante;
  const TelaHomeProfissional({super.key, required this.isVisitante});

  @override
  State<TelaHomeProfissional> createState() => _TelaHomeProfissionalState();
}

class _TelaHomeProfissionalState extends State<TelaHomeProfissional> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _titleDark = Color(0xFF1A2B4A);
  static const Color _inputGray = Color(0xFFF0F2F5);
  static const Color _textMuted = Color(0xFF9CA3AF);

  int _currentIndex = 0;

  final TextEditingController _postagemController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Futures cacheados para evitar recarregamento ao rolar a tela
  late Future<Map<String, dynamic>?> _dadosProfissionalFuture;
  late Future<String?> _enderecoFuture;
  late Future<List<OficioInfo>?> _oficiosFuture;
  late Future<List<PostagemResumo>> _postagensFuture;

  // Estado da criação de postagem
  List<XFile> _imagensSelecionadas = [];
  bool _enviandoPostagem = false;

  @override
  void initState() {
    super.initState();
    _inicializarFutures();
  }

  void _inicializarFutures() {
    _dadosProfissionalFuture = _buscarDadosProfissional();
    _enderecoFuture = _buscarEndereco();
    _oficiosFuture = _buscarOficios();
    _postagensFuture = PostagensProfissionalService.buscarPostagens(limit: 10);
  }

  Future<Map<String, dynamic>?> _buscarDadosProfissional() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;
      final response = await supabase
          .from('usuarios')
          .select('nome, foto_perfil_url')
          .eq('auth_id', user.id)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  Future<String?> _buscarEndereco() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      // 1. Busca o id do usuário
      final usuarioResponse = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (usuarioResponse == null) return null;
      final usuarioId = usuarioResponse['id_usuario'];

      // 2. Busca a associação do usuário com endereço (ativo primeiro)
      final assResponse = await supabase
          .from('ass_usuario_endereco')
          .select('fk_endereco, endereco_ativo')
          .eq('fk_usuario', usuarioId)
          .order('endereco_ativo', ascending: false)
          .limit(1)
          .maybeSingle();
      if (assResponse == null) return null;
      final fkEndereco = assResponse['fk_endereco'];

      // 3. Busca o endereço
      final enderecoResponse = await supabase
          .from('enderecos')
          .select('logradouro, numero, bairro, fk_cidade')
          .eq('id_endereco', fkEndereco)
          .maybeSingle();
      if (enderecoResponse == null) return null;

      final logradouro = enderecoResponse['logradouro']?.toString() ?? '';
      final numero = enderecoResponse['numero']?.toString() ?? '';
      final bairro = enderecoResponse['bairro']?.toString() ?? '';
      final fkCidade = enderecoResponse['fk_cidade'];
      if (logradouro.isEmpty) return null;

      // 4. Busca a cidade
      String cidade = '';
      String estado = '';
      if (fkCidade != null) {
        final cidadeResponse = await supabase
            .from('cidades')
            .select('nome_cidade, fk_estado')
            .eq('id_cidade', fkCidade)
            .maybeSingle();
        if (cidadeResponse != null) {
          cidade = cidadeResponse['nome_cidade']?.toString() ?? '';
          final fkEstado = cidadeResponse['fk_estado'];
          if (fkEstado != null) {
            final estadoResponse = await supabase
                .from('estados')
                .select('sigla_estado')
                .eq('id_estado', fkEstado)
                .maybeSingle();
            if (estadoResponse != null) {
              estado = estadoResponse['sigla_estado']?.toString() ?? '';
            }
          }
        }
      }

      final partes = <String>[
        if (logradouro.isNotEmpty) logradouro,
        if (numero.isNotEmpty) numero,
        if (bairro.isNotEmpty) bairro,
        if (cidade.isNotEmpty) cidade,
        if (estado.isNotEmpty) estado,
      ];

      return partes.join(', ');
    } catch (e) {
      return null;
    }
  }

  Future<List<OficioInfo>?> _buscarOficios() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      // 1. Busca o id do usuário
      final usuarioResponse = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (usuarioResponse == null) return null;
      final usuarioId = usuarioResponse['id_usuario'];

      // 2. Busca dados profissionais para obter o id_profissional
      final dadosProf = await supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();
      if (dadosProf == null) return null;

      final idProfissional = dadosProf['id_profissional'];

      // 3. Busca os ofícios associados ao profissional
      final assOficios = await supabase
          .from('ass_oficio_profissional')
          .select('fk_oficio')
          .eq('fk_profissional', idProfissional);

      final idsOficios = assOficios
          .map((e) => e['fk_oficio'])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList();

      if (idsOficios.isEmpty) return [];

      // 4. Busca os nomes e cores dos ofícios
      final oficiosData = await supabase
          .from('oficios')
          .select('funcao, cor')
          .inFilter('id_oficio', idsOficios);

      final oficios = <OficioInfo>[];
      for (final row in oficiosData) {
        final info = OficioInfo.fromMap(row);
        if (info.funcao.isNotEmpty) oficios.add(info);
      }

      return oficios;
    } catch (e) {
      return null;
    }
  }

  PageRouteBuilder _rotaSemAnimacao(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  // ================= CRIAÇÃO DE POSTAGEM =================

  Future<void> _abrirCriacaoPostagem({
    required String? fotoUrl,
    required String nome,
  }) async {
    _postagemController.clear();
    setState(() {
      _imagensSelecionadas = [];
      _enviandoPostagem = false;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
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
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE1F5FE),
                        backgroundImage:
                            fotoUrl != null ? NetworkImage(fotoUrl) : null,
                        child: fotoUrl == null
                            ? Text(
                                nome.isNotEmpty ? nome[0].toUpperCase() : 'P',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryBlue,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _titleDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _postagemController,
                    maxLines: 4,
                    minLines: 2,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'No que você está trabalhando hoje?',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      filled: true,
                      fillColor: _inputGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _primaryBlue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (_imagensSelecionadas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imagensSelecionadas.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final imagem = _imagensSelecionadas[index];
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: kIsWeb
                                    ? Image.network(
                                        imagem.path,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _buildPlaceholderImagemSelecionada(),
                                      )
                                    : Image.file(
                                        File(imagem.path),
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _buildPlaceholderImagemSelecionada(),
                                      ),
                              ),
                              Positioned(
                                right: -6,
                                top: -6,
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      _imagensSelecionadas.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Botão de anexar foto
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _enviandoPostagem
                              ? null
                              : () => _escolherImagens(setModalState),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(
                                  Icons.photo_camera_outlined,
                                  color: _primaryBlue,
                                  size: 26,
                                ),
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: const BoxDecoration(
                                      color: _primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botão de enviar postagem (avião de papel)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _enviandoPostagem
                              ? null
                              : () => _enviarPostagem(setModalState),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: _enviandoPostagem
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: _primaryBlue,
                                    ),
                                  )
                                : Icon(
                                    Icons.send_outlined,
                                    color: _imagensSelecionadas.isEmpty
                                        ? Colors.grey.shade400
                                        : _primaryBlue,
                                    size: 26,
                                  ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_imagensSelecionadas.length} foto(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _escolherImagens(StateSetter setModalState) async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return;

      setModalState(() {
        _imagensSelecionadas = [..._imagensSelecionadas, ...pickedFiles];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagens: $e')),
        );
      }
    }
  }

  Future<void> _enviarPostagem(StateSetter setModalState) async {
    final conteudo = _postagemController.text.trim();
    if (_imagensSelecionadas.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você só pode realizar postagens com fotos anexadas.'),
          ),
        );
      }
      return;
    }

    setModalState(() => _enviandoPostagem = true);

    final resultado = await PostagensProfissionalService.criarPostagem(
      conteudo: conteudo,
      imagens: _imagensSelecionadas,
    );

    if (!mounted) return;

    if (resultado.sucesso) {
      Navigator.of(context).pop();
      setState(() {
        _imagensSelecionadas = [];
        _enviandoPostagem = false;
        _postagensFuture =
            PostagensProfissionalService.buscarPostagens(limit: 10);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postagem publicada com sucesso!')),
      );
    } else {
      setModalState(() => _enviandoPostagem = false);
      debugPrint('❌ [tela_home_profissional] Falha ao publicar: ${resultado.erro}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado.erro ?? 'Erro ao publicar postagem.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPlaceholderImagemSelecionada() {
    return Container(
      width: 90,
      height: 90,
      color: const Color(0xFFE8EDF2),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 28,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ================= CARTÃO DE PERFIL =================
            FutureBuilder<Map<String, dynamic>?>(
              future: _dadosProfissionalFuture,
              builder: (context, snapshot) {
                final nomeCompleto =
                    snapshot.data?['nome'] as String? ?? 'Caneta Azul';
                final fotoUrl = snapshot.data?['foto_perfil_url'] as String?;

                return FutureBuilder<String?>(
                  future: _enderecoFuture,
                  builder: (context, enderecoSnapshot) {
                    final enderecoTexto = enderecoSnapshot.data ??
                        'Nenhum endereço cadastrado';

                    return FutureBuilder<List<OficioInfo>?>(
                      future: _oficiosFuture,
                      builder: (context, oficiosSnapshot) {
                        final oficios = oficiosSnapshot.data ?? <OficioInfo>[];

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _cardDecoration(),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomCenter,
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 34,
                                        backgroundColor:
                                            const Color(0xFFE1F5FE),
                                        backgroundImage: fotoUrl != null
                                            ? NetworkImage(fotoUrl)
                                            : null,
                                        child: fotoUrl == null
                                            ? Text(
                                                nomeCompleto.isNotEmpty
                                                    ? nomeCompleto[0]
                                                        .toUpperCase()
                                                    : 'P',
                                                style: const TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                  color: _primaryBlue,
                                                ),
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: -6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _primaryBlue,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check,
                                                size: 9,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                'Verificado',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nomeCompleto,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: _titleDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          enderecoTexto,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.notifications_none_outlined,
                                          color: _primaryBlue,
                                          size: 26,
                                        ),
                                        onPressed: () {},
                                      ),
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            color: _primaryBlue,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Text(
                                            '2',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (oficios.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: oficios
                                      .map((oficio) =>
                                          TagOficio(oficio: oficio))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // ================= CRIAR POSTAGEM =================
            FutureBuilder<Map<String, dynamic>?>(
              future: _dadosProfissionalFuture,
              builder: (context, snapshot) {
                final nomeCompleto =
                    snapshot.data?['nome'] as String? ?? 'Profissional';
                final fotoUrl = snapshot.data?['foto_perfil_url'] as String?;
                return _buildCaixaCriacaoPostagem(
                  fotoUrl: fotoUrl,
                  nome: nomeCompleto,
                );
              },
            ),
            const SizedBox(height: 20),

            // ================= RADAR GEOGRÁFICO =================
            const Row(
              children: [
                Text(
                  'Radar Geográfico',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _titleDark,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.sensors, color: _primaryBlue, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E7EF)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _MapPatternPainter(),
                    ),
                    Positioned(
                      left: 110,
                      top: -20,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primaryBlue.withValues(alpha: 0.12),
                          border: Border.all(
                            color: _primaryBlue.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 200,
                      top: 58,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primaryBlue,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: _titleDark,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(text: 'Há '),
                  TextSpan(
                    text: '1',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' solicitação de pedido na sua área'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= ESTATÍSTICAS + AGENDA (cartão único) =================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estatísticas dos Serviços',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _titleDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Pendentes', '1')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatCard('Ativos', '1')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatCard('Concluídos', '1')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatCard('Cancelados', '0')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Agenda da semana',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _titleDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildWeekCalendar(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= ATALHOS / PAINEL DE AÇÕES =================
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildQuickOption(
                          Icons.bar_chart,
                          'Estatísticas\nFinanceiras',
                        ),
                      ),
                      Expanded(
                        child: _buildQuickOption(
                          Icons.history,
                          'Histórico de\nServiços',
                        ),
                      ),
                      Expanded(
                        child: _buildQuickOption(
                          Icons.work_outline,
                          'Meus\nServiços',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildQuickOption(
                          Icons.local_shipping_outlined,
                          'Método de\nEntrega',
                        ),
                      ),
                      Expanded(
                        child: _buildQuickOption(
                          Icons.verified_outlined,
                          'Plano de\nVerificado',
                        ),
                      ),
                      Expanded(
                        child: _buildQuickOption(
                          Icons.add_circle_outline,
                          'Mais\nOpções',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= SUAS POSTAGENS =================
            FutureBuilder<List<PostagemResumo>>(
              future: _postagensFuture,
              builder: (context, snapshot) {
                final postagens = snapshot.data ?? [];
                return _buildSecaoPostagens(postagens);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: _primaryBlue,
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          onTap: (index) {
            if (index == 4) {
              Navigator.of(context).pushReplacement(
                _rotaSemAnimacao(
                  TelaMeuPerfilProfissionalPage(
                    isVisitante: widget.isVisitante,
                  ),
                ),
              );
              return;
            }
            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.sensors), label: 'Radar'),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Mensagens',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              label: 'Pedidos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _titleDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar() {
    const diasSemana = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
    final dias = [
      {'numero': '3', 'hoje': true, 'agendado': false, 'evento': 'Hoje'},
      {'numero': '4', 'hoje': false, 'agendado': false, 'evento': ''},
      {
        'numero': '5',
        'hoje': false,
        'agendado': true,
        'evento': 'Cons.\ncabo Panela',
      },
      {'numero': '6', 'hoje': false, 'agendado': false, 'evento': ''},
      {'numero': '7', 'hoje': false, 'agendado': false, 'evento': ''},
      {'numero': '8', 'hoje': false, 'agendado': false, 'evento': ''},
      {'numero': '9', 'hoje': false, 'agendado': false, 'evento': ''},
    ];

    return Column(
      children: [
        Row(
          children: diasSemana
              .map(
                (dia) => Expanded(
                  child: Text(
                    dia,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(dias.length, (index) {
            final item = dias[index];
            final isHoje = item['hoje'] as bool;
            final isAgendado = item['agendado'] as bool;
            final diaNumero = item['numero'] as String;
            final eventoTexto = item['evento'] as String;

            if (isAgendado) {
              return Expanded(
                child: Container(
                  height: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  decoration: BoxDecoration(
                    color: _primaryBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        diaNumero,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (eventoTexto.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          eventoTexto,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return Expanded(
              child: Container(
                height: 72,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isHoje ? _primaryBlue : Colors.grey.shade200,
                    width: isHoje ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      diaNumero,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isHoje ? _primaryBlue : _titleDark,
                      ),
                    ),
                    if (eventoTexto.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        eventoTexto,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCaixaCriacaoPostagem({
    required String? fotoUrl,
    required String nome,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE1F5FE),
            backgroundImage:
                fotoUrl != null ? NetworkImage(fotoUrl) : null,
            child: fotoUrl == null
                ? Text(
                    nome.isNotEmpty ? nome[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _abrirCriacaoPostagem(
                  fotoUrl: fotoUrl,
                  nome: nome,
                ),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _inputGray,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'No que você está trabalhando hoje?',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _abrirCriacaoPostagem(
                fotoUrl: fotoUrl,
                nome: nome,
              ),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.photo_camera_outlined,
                      color: _primaryBlue,
                      size: 26,
                    ),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: _primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botão de enviar postagem (avião de papel)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _abrirCriacaoPostagem(
                fotoUrl: fotoUrl,
                nome: nome,
              ),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.send_outlined,
                  color: _primaryBlue,
                  size: 26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoPostagens(List<PostagemResumo> postagens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Suas Postagens',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _titleDark,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MinhasPostagensProfissionalPage(),
                  ),
                );
              },
              child: Text(
                'Ver todas',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (postagens.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 32,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nenhuma postagem ainda',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: postagens.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildCardPostagem(postagens[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCardPostagem(PostagemResumo postagem) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 100,
            width: double.infinity,
            child: postagem.imagemUrl != null
                ? Image.network(
                    postagem.imagemUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildPlaceholderImagemPostagem(),
                  )
                : _buildPlaceholderImagemPostagem(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    postagem.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _titleDark,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          PostagensProfissionalService.formatarDataPostagem(
                            postagem.dataPostagem,
                          ),
                          style: const TextStyle(
                            fontSize: 10,
                            color: _textMuted,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.favorite_border,
                        size: 14,
                        color: _textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        postagem.curtidas.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: _textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImagemPostagem() {
    return Container(
      color: const Color(0xFFE8EDF2),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildQuickOption(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _primaryBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: _titleDark,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFDDE3EA)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final blockPaint = Paint()
      ..color = const Color(0xFFE8EDF2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(20, 15, 60, 40),
      blockPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(100, 30, 80, 50),
      blockPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(200, 10, 70, 35),
      blockPaint,
    );

    canvas.drawLine(
      const Offset(0, 60),
      Offset(size.width, 60),
      roadPaint,
    );

    canvas.drawLine(
      const Offset(0, 90),
      Offset(size.width, 90),
      roadPaint,
    );

    canvas.drawLine(
      const Offset(80, 0),
      Offset(80, size.height),
      roadPaint,
    );

    canvas.drawLine(
      const Offset(180, 0),
      Offset(180, size.height),
      roadPaint,
    );

    canvas.drawLine(
      const Offset(260, 0),
      Offset(260, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
