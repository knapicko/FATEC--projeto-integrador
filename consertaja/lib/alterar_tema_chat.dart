import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/chat_anexos_service.dart';
import 'utils/iniciais.dart';

/// Configurações do tema do chat retornadas ao sair da tela.
class TemaChatConfig {
  final String corBaloes;
  final String planoFundo;
  final double desfoqueFundo;
  final double opacidadeFundo;
  final bool aplicarATodas;

  const TemaChatConfig({
    required this.corBaloes,
    required this.planoFundo,
    required this.desfoqueFundo,
    required this.opacidadeFundo,
    this.aplicarATodas = false,
  });

  Color get corBaloesColor {
    try {
      final limpo = corBaloes.replaceAll('#', '').trim();
      if (limpo.startsWith('0x') || limpo.startsWith('0X')) {
        return Color(int.parse(limpo));
      }
      if (limpo.length == 6) {
        return Color(int.parse('0xFF$limpo'));
      }
      return Color(int.parse(limpo));
    } catch (_) {
      return const Color(0xFF0FB3FF);
    }
  }
}

class AlterarTemaChat extends StatefulWidget {
  final int? idConversa;
  final String? nomeContato;
  final String? fotoContato;
  final String? oficioPrincipal;
  final String? corBaloesAtual;
  final String? planoFundoAtual;
  final double? desfoqueFundoAtual;
  final double? opacidadeFundoAtual;
  final int? idProfissional;
  final int? idGrupoEmpresa;

  const AlterarTemaChat({
    super.key,
    this.idConversa,
    this.nomeContato,
    this.fotoContato,
    this.oficioPrincipal,
    this.corBaloesAtual,
    this.planoFundoAtual,
    this.desfoqueFundoAtual,
    this.opacidadeFundoAtual,
    this.idProfissional,
    this.idGrupoEmpresa,
  });

  @override
  State<AlterarTemaChat> createState() => _AlterarTemaChatState();
}

class _AlterarTemaChatState extends State<AlterarTemaChat> {
  static const Color _corAzulPadrao = Color(0xFF0FB3FF);
  static const String _doodleDefaultAsset =
      'assets/images/plano_fundo_chat/doodle_default.png';

  final _supabase = Supabase.instance.client;

  // Estado atual das opções
  late String _corBaloesHex;
  late String _planoFundoId;
  late double _desfoqueFundo;
  late double _opacidadeFundo;
  bool _aplicarATodas = false;
  String _abaFiltroAtiva = 'Todos';

  XFile? _imagemGaleriaSelecionada;
  int? _idUsuarioLogado;
  bool _carregandoInicial = true;
  bool _salvando = false;

  // Lista de cores de balão disponíveis
  final List<Color> _paletaCores = const [
    Color(0xFF0FB3FF), // Azul Padrão ConsertaJá
    Color(0xFF00966D), // Verde Esmeralda
    Color(0xFF7C3AED), // Roxo Vibrante
    Color(0xFFEA580C), // Laranja
    Color(0xFF334155), // Cinza Grafite / Ardósia
    Color(0xFFDB2777), // Rosa Magenta
    Color(0xFF0B2545), // Azul Marinho Profundo
  ];

  // Filtros disponíveis
  final List<String> _filtros = const [
    'Todos',
    'Padrão',
    'Gradientes',
    'Doodles',
    'Sólidos',
  ];

  // Modelos de papéis de parede / planos de fundo
  final List<_OpcaoFundo> _opcoesFundo = [
    _OpcaoFundo(
      id: _doodleDefaultAsset,
      titulo: 'Doodle ConsertaJá',
      subtitulo: 'Textura Oficial',
      categorias: ['Todos', 'Padrão', 'Doodles'],
      tipo: _TipoFundo.doodle,
      isPadrao: true,
      assetPath: _doodleDefaultAsset,
    ),
    const _OpcaoFundo(
      id: 'minimalista',
      titulo: 'Minimalista',
      subtitulo: 'Limpo & Serena',
      categorias: ['Todos', 'Padrão', 'Sólidos'],
      tipo: _TipoFundo.solido,
      corSolida: Color(0xFFF8FAFC),
    ),
    const _OpcaoFundo(
      id: 'aurora_profundo',
      titulo: 'Aurora Profundo',
      subtitulo: 'Profundo...',
      categorias: ['Todos', 'Gradientes'],
      tipo: _TipoFundo.gradiente,
      coresGradiente: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
    ),
    const _OpcaoFundo(
      id: 'azul_ceu',
      titulo: 'Azul Céu',
      subtitulo: 'Gradiente Suave',
      categorias: ['Todos', 'Gradientes'],
      tipo: _TipoFundo.gradiente,
      coresGradiente: [
        Color(0xFFBAE6FD),
        Color(0xFF38BDF8),
        Color(0xFF0284C7),
      ],
    ),
    const _OpcaoFundo(
      id: 'geometrico',
      titulo: 'Geométrico',
      subtitulo: 'Padrão Is...',
      categorias: ['Todos', 'Doodles', 'Padrão'],
      tipo: _TipoFundo.geometrico,
    ),
    const _OpcaoFundo(
      id: 'menta_pastel',
      titulo: 'Menta Pastel',
      subtitulo: 'Serenidade',
      categorias: ['Todos', 'Sólidos'],
      tipo: _TipoFundo.solido,
      corSolida: Color(0xFFE6F4EA),
    ),
    const _OpcaoFundo(
      id: 'por_do_sol',
      titulo: 'Pôr do Sol',
      subtitulo: 'Tons Quentes',
      categorias: ['Todos', 'Gradientes'],
      tipo: _TipoFundo.gradiente,
      coresGradiente: [
        Color(0xFFFFEDD5),
        Color(0xFFFDBA74),
        Color(0xFFF43F5E),
      ],
    ),
    const _OpcaoFundo(
      id: 'grafite_dark',
      titulo: 'Grafite',
      subtitulo: 'Elegante Dark',
      categorias: ['Todos', 'Sólidos'],
      tipo: _TipoFundo.solido,
      corSolida: Color(0xFF1E293B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _corBaloesHex = widget.corBaloesAtual ?? '0xFF0FB3FF';
    _planoFundoId = widget.planoFundoAtual ?? _doodleDefaultAsset;
    _desfoqueFundo = widget.desfoqueFundoAtual ?? 0.0;
    _opacidadeFundo = widget.opacidadeFundoAtual ?? 95.0;

    _carregarDadosSupabase();
  }

  Color _corDeHex(String hex) {
    try {
      final limpo = hex.replaceAll('#', '').trim();
      if (limpo.startsWith('0x') || limpo.startsWith('0X')) {
        return Color(int.parse(limpo));
      }
      if (limpo.length == 6) {
        return Color(int.parse('0xFF$limpo'));
      }
      return Color(int.parse(limpo));
    } catch (_) {
      return _corAzulPadrao;
    }
  }

  String _hexDeCor(Color cor) {
    return '0x${cor.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Future<void> _carregarDadosSupabase() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser != null) {
        final usuario = await _supabase
            .from('usuarios')
            .select('id_usuario')
            .eq('auth_id', authUser.id)
            .maybeSingle();
        _idUsuarioLogado = (usuario?['id_usuario'] as num?)?.toInt();
      }

      if (widget.idConversa != null) {
        final conv = await _supabase
            .from('conversas')
            .select('cor_baloes, plano_fundo, desfoque_fundo, opacidade_fundo')
            .eq('id_conversa', widget.idConversa!)
            .maybeSingle();

        if (conv != null && mounted) {
          setState(() {
            if (conv['cor_baloes'] != null) {
              _corBaloesHex = conv['cor_baloes'].toString();
            }
            if (conv['plano_fundo'] != null) {
              _planoFundoId = conv['plano_fundo'].toString();
            }
            if (conv['desfoque_fundo'] != null) {
              _desfoqueFundo =
                  (conv['desfoque_fundo'] as num).toDouble().clamp(0.0, 15.0);
            }
            if (conv['opacidade_fundo'] != null) {
              _opacidadeFundo =
                  (conv['opacidade_fundo'] as num).toDouble().clamp(10.0, 100.0);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Aviso ao carregar tema da conversa: $e');
    } finally {
      if (mounted) {
        setState(() {
          _carregandoInicial = false;
        });
      }
    }
  }

  Future<void> _salvarTemaNoSupabase() async {
    if (_salvando) return;
    _salvando = true;

    try {
      final Map<String, dynamic> dados = {
        'cor_baloes': _corBaloesHex,
        'plano_fundo': _planoFundoId,
        'desfoque_fundo': _desfoqueFundo.round(),
        'opacidade_fundo': _opacidadeFundo.round(),
      };

      if (_aplicarATodas && _idUsuarioLogado != null) {
        // Atualiza todas as conversas do usuário logado
        await _supabase
            .from('conversas')
            .update(dados)
            .eq('fk_usuario', _idUsuarioLogado!);
      }

      // Atualiza a conversa específica se tiver id
      if (widget.idConversa != null) {
        await _supabase
            .from('conversas')
            .update(dados)
            .eq('id_conversa', widget.idConversa!);
      }
    } catch (e) {
      debugPrint('Aviso ao salvar tema da conversa no Supabase: $e');
    } finally {
      _salvando = false;
    }
  }

  void _restaurarPadrao() {
    setState(() {
      _corBaloesHex = '0xFF0FB3FF';
      _planoFundoId = _doodleDefaultAsset;
      _desfoqueFundo = 0.0;
      _opacidadeFundo = 95.0;
      _imagemGaleriaSelecionada = null;
    });

    _salvarTemaNoSupabase();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tema restaurado para o padrão oficial.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selecionarDaGaleria() async {
    try {
      final picker = ImagePicker();
      final foto = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (foto != null && mounted) {
        setState(() {
          _imagemGaleriaSelecionada = foto;
          _planoFundoId = 'galeria:${foto.path}';
        });

        // Opcional: tenta enviar pro storage caso tenha idConversa
        if (widget.idConversa != null) {
          _fazerUploadFotoFundo(foto);
        } else {
          _salvarTemaNoSupabase();
        }
      }
    } catch (e) {
      debugPrint('Erro ao selecionar foto da galeria: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível carregar a imagem.')),
        );
      }
    }
  }

  Future<void> _fazerUploadFotoFundo(XFile foto) async {
    try {
      final bytes = await foto.readAsBytes();
      final ext = foto.name.split('.').last.toLowerCase();
      final caminho =
          'fundo_conversa_${widget.idConversa}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from(ChatAnexosService.bucketAnexos).uploadBinary(
            caminho,
            bytes,
            fileOptions: FileOptions(
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
              upsert: true,
            ),
          );

      final url = _supabase.storage
          .from(ChatAnexosService.bucketAnexos)
          .getPublicUrl(caminho);

      if (mounted) {
        setState(() {
          _planoFundoId = url;
        });
        _salvarTemaNoSupabase();
      }
    } catch (e) {
      debugPrint('Aviso upload foto fundo: $e, usando caminho local.');
      _salvarTemaNoSupabase();
    }
  }

  TemaChatConfig _gerarResultadoConfig() {
    return TemaChatConfig(
      corBaloes: _corBaloesHex,
      planoFundo: _planoFundoId,
      desfoqueFundo: _desfoqueFundo,
      opacidadeFundo: _opacidadeFundo,
      aplicarATodas: _aplicarATodas,
    );
  }

  @override
  Widget build(BuildContext context) {
    final corAtual = _corDeHex(_corBaloesHex);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _salvarTemaNoSupabase();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: Color(0xFF0F172A),
              size: 24,
            ),
            onPressed: () {
              _salvarTemaNoSupabase();
              Navigator.pop(context, _gerarResultadoConfig());
            },
          ),
          title: const Text(
            'Alterar Tema',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: const Color(0xFFF1F5F9), height: 1),
          ),
        ),
        body: _carregandoInicial
            ? const Center(
                child: CircularProgressIndicator(color: _corAzulPadrao),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Cabeçalho de Personalização Visual
                    _buildSecaoPersonalizacaoVisual(),
                    const SizedBox(height: 18),

                    // 2. Pré-visualização em Tempo Real
                    _buildSecaoPreVisualizacao(corAtual),
                    const SizedBox(height: 24),

                    // 3. Cor dos Balões & Destaque
                    _buildSecaoCorBaloes(corAtual),
                    const SizedBox(height: 24),

                    // 4. Plano de Fundo da Conversa
                    _buildSecaoPlanoFundo(),
                    const SizedBox(height: 20),

                    // 5. Controles de Ajuste (Sliders)
                    _buildSecaoControlesAjuste(),
                    const SizedBox(height: 18),

                    // 6. Aplicar a todas as conversas
                    _buildSecaoAplicarATodas(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. SEÇÃO PERSONALIZAÇÃO VISUAL
  // ---------------------------------------------------------------------------
  Widget _buildSecaoPersonalizacaoVisual() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE0F2FE),
              ),
              child: const Icon(
                Icons.palette_rounded,
                color: _corAzulPadrao,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'PERSONALIZAÇÃO VISUAL',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        InkWell(
          onTap: _restaurarPadrao,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Icon(
                  Icons.restart_alt,
                  color: _corAzulPadrao,
                  size: 18,
                ),
                SizedBox(width: 4),
                Text(
                  'Restaurar padrão',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _corAzulPadrao,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. PRÉ-VISUALIZAÇÃO EM TEMPO REAL
  // ---------------------------------------------------------------------------
  Widget _buildSecaoPreVisualizacao(Color corBalao) {
    final nomeExibido = widget.nomeContato ?? 'ConsertaJá Assistência';
    final foto = widget.fotoContato;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PRÉ-VISUALIZAÇÃO EM TEMPO REAL',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0284C7),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Ao Vivo',
                    style: TextStyle(
                      color: Color(0xFF0369A1),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Card do Chat Simulado
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Plano de Fundo com Blur e Opacidade
              Positioned.fill(
                child: _buildBackgroundRenderizado(
                  opacidade: _opacidadeFundo / 100.0,
                  desfoque: _desfoqueFundo,
                ),
              ),

              // Conteúdo do Chat
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top bar do chat simulado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9).withValues(alpha: 0.94),
                      border: const Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Avatar com indicador online
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF0A3977),
                              backgroundImage: (foto != null && foto.isNotEmpty)
                                  ? NetworkImage(foto)
                                  : null,
                              child: (foto == null || foto.isEmpty)
                                  ? Text(
                                      obterIniciais(nomeExibido),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      nomeExibido,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified,
                                    size: 15,
                                    color: _corAzulPadrao,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              const Row(
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Online agora',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.more_vert,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                      ],
                    ),
                  ),

                  // Mensagens simuladas
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Column(
                      children: [
                        // Pill "HOJE"
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Text(
                              'HOJE',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Mensagem Recebida
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 270),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Olá! Seu pedido de troca da fechadura foi confirmado. Quando podemos retirar as chaves?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                    height: 1.35,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    '14:33',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Mensagem Enviada com a Cor Selecionada
                        Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 270),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: corBalao,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(4),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: corBalao.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Perfeito! Já deixei a chave na portaria com o seu nome cadastrado. Muito obrigado!',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Spacer(),
                                    Text(
                                      '14:35',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.done_all,
                                      size: 14,
                                      color: Colors.white.withValues(alpha: 0.95),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Barra de Digitação Simulada
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Color(0xFFF1F5F9)),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          color: Color(0xFF64748B),
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Text(
                                  'Mensagem...',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 13,
                                  ),
                                ),
                                Spacer(),
                                Icon(
                                  Icons.camera_alt_outlined,
                                  color: Color(0xFF94A3B8),
                                  size: 19,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: _corAzulPadrao,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. SEÇÃO COR DOS BALÕES & DESTAQUE
  // ---------------------------------------------------------------------------
  Widget _buildSecaoCorBaloes(Color corAtual) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cor dos Balões & Destaque',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Escolha o tom predominante para suas mensagens e botões na conversa.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),

        // Círculos de Cores (Primeiro é o botão customizado com +)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // 1. Símbolo de cor personalizada com +
              _buildBotaoCorPersonalizada(),

              // Demais cores da paleta
              ..._paletaCores.map((cor) {
                final hexCor = _hexDeCor(cor);
                final selecionada =
                    _corDeHex(_corBaloesHex).toARGB32() == cor.toARGB32();

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _corBaloesHex = hexCor;
                      });
                      _salvarTemaNoSupabase();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: cor.withValues(alpha: 0.35),
                            blurRadius: selecionada ? 8 : 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: selecionada
                          ? const Center(
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// Primeiro círculo: colorido com um + no meio para abrir o bottom sheet hex
  Widget _buildBotaoCorPersonalizada() {
    final corAtual = _corDeHex(_corBaloesHex);
    final ehPersonalizada = !_paletaCores.any(
      (c) => c.toARGB32() == corAtual.toARGB32(),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: _abrirModalCorPersonalizada,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFFEF4444),
                Color(0xFFF59E0B),
                Color(0xFF10B981),
                Color(0xFF06B6D4),
                Color(0xFF0FB3FF),
                Color(0xFF8B5CF6),
                Color(0xFFEC4899),
                Color(0xFFEF4444),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: ehPersonalizada
                    ? corAtual.withValues(alpha: 0.45)
                    : Colors.black.withValues(alpha: 0.12),
                blurRadius: ehPersonalizada ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: ehPersonalizada
                ? Border.all(color: Colors.white, width: 2.2)
                : null,
          ),
          child: Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ehPersonalizada
                    ? corAtual
                    : Colors.black.withValues(alpha: 0.16),
              ),
              child: Center(
                child: Icon(
                  ehPersonalizada ? Icons.check : Icons.add_rounded,
                  color: Colors.white,
                  size: ehPersonalizada ? 22 : 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// BottomSheet estilizado para escolher a cor hexadecimal
  void _abrirModalCorPersonalizada() {
    Color corTemp = _corDeHex(_corBaloesHex);
    double hueAtual = HSLColor.fromColor(corTemp).hue;
    double lightnessAtual = HSLColor.fromColor(corTemp).lightness;
    double saturationAtual =
        HSLColor.fromColor(corTemp).saturation.clamp(0.3, 1.0);

    final hexController = TextEditingController(
      text:
          '#${corTemp.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void atualizarCor(Color novaCor, {bool atualizarHex = true}) {
              setModalState(() {
                corTemp = novaCor;
                final hsl = HSLColor.fromColor(novaCor);
                hueAtual = hsl.hue;
                lightnessAtual = hsl.lightness;
                saturationAtual = hsl.saturation.clamp(0.25, 1.0);
                if (atualizarHex) {
                  hexController.text =
                      '#${novaCor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                }
              });
            }

            final hexExibido =
                '#${corTemp.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

            const coresSugeridas = [
              Color(0xFFEF4444),
              Color(0xFFF97316),
              Color(0xFFF59E0B),
              Color(0xFF10B981),
              Color(0xFF06B6D4),
              Color(0xFF0284C7),
              Color(0xFF6366F1),
              Color(0xFF8B5CF6),
              Color(0xFFD946EF),
              Color(0xFFEC4899),
              Color(0xFF14B8A6),
              Color(0xFF84CC16),
              Color(0xFF0F172A),
              Color(0xFF475569),
            ];

            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 14,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFE0F2FE),
                          ),
                          child: const Icon(
                            Icons.color_lens_rounded,
                            color: _corAzulPadrao,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Escolha sua Cor',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Personalize o tom dos balões com código HEX',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Prévia da cor com balão simulado
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: corTemp,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: corTemp.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hexExibido,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Código Hexadecimal',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: corTemp,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Mensagem',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Slider de Tonalidade (Arco-íris)
                    const Text(
                      'Tonalidade',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF0000),
                            Color(0xFFFFFF00),
                            Color(0xFF00FF00),
                            Color(0xFF00FFFF),
                            Color(0xFF0000FF),
                            Color(0xFFFF00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                          elevation: 3,
                        ),
                      ),
                      child: Slider(
                        value: hueAtual,
                        min: 0,
                        max: 360,
                        onChanged: (val) {
                          final novaCor = HSLColor.fromAHSL(
                            1.0,
                            val,
                            saturationAtual.clamp(0.4, 1.0),
                            lightnessAtual.clamp(0.2, 0.8),
                          ).toColor();
                          atualizarCor(novaCor);
                        },
                      ),
                    ),

                    // Slider de Luminosidade
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Luminosidade',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Text(
                          '${(lightnessAtual * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            HSLColor.fromAHSL(1.0, hueAtual, saturationAtual, 0.15)
                                .toColor(),
                            HSLColor.fromAHSL(1.0, hueAtual, saturationAtual, 0.5)
                                .toColor(),
                            HSLColor.fromAHSL(1.0, hueAtual, saturationAtual, 0.85)
                                .toColor(),
                          ],
                        ),
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        activeTrackColor: Colors.transparent,
                        inactiveTrackColor: Colors.transparent,
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                          elevation: 3,
                        ),
                      ),
                      child: Slider(
                        value: lightnessAtual.clamp(0.15, 0.85),
                        min: 0.15,
                        max: 0.85,
                        onChanged: (val) {
                          final novaCor = HSLColor.fromAHSL(
                            1.0,
                            hueAtual,
                            saturationAtual.clamp(0.3, 1.0),
                            val,
                          ).toColor();
                          atualizarCor(novaCor);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Paleta de Sugestões
                    const Text(
                      'Tons Rápidos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: coresSugeridas.map((c) {
                        final ativa = c.toARGB32() == corTemp.toARGB32();
                        return GestureDetector(
                          onTap: () => atualizarCor(c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: ativa ? Colors.black87 : Colors.white,
                                width: ativa ? 2.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: c.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: ativa
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Input HEX
                    TextField(
                      controller: hexController,
                      decoration: InputDecoration(
                        labelText: 'Digitar Código HEX',
                        hintText: '#0FB3FF',
                        prefixIcon: const Icon(Icons.tag, color: _corAzulPadrao),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (text) {
                        try {
                          final limpo = text.replaceAll('#', '').trim();
                          if (limpo.length == 6) {
                            final c = Color(int.parse('0xFF$limpo'));
                            atualizarCor(c, atualizarHex: false);
                          } else if (limpo.length == 8 ||
                              limpo.startsWith('0x') ||
                              limpo.startsWith('0X')) {
                            final c = Color(int.parse(limpo));
                            atualizarCor(c, atualizarHex: false);
                          }
                        } catch (_) {}
                      },
                    ),
                    const SizedBox(height: 20),

                    // Botão Aplicar
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: corTemp,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                          shadowColor: corTemp.withValues(alpha: 0.4),
                        ),
                        onPressed: () {
                          final hexFinal = _hexDeCor(corTemp);
                          setState(() {
                            _corBaloesHex = hexFinal;
                          });
                          _salvarTemaNoSupabase();
                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Aplicar Cor',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4. SEÇÃO PLANO DE FUNDO DA CONVERSA (ROW SCROLLÁVEL HORIZONTAL 2 X N)
  // ---------------------------------------------------------------------------
  Widget _buildSecaoPlanoFundo() {
    final opcoesFiltradas = _opcoesFundo.where((op) {
      if (_abaFiltroAtiva == 'Todos') return true;
      return op.categorias.contains(_abaFiltroAtiva);
    }).toList();

    // Monta todos os cards filtrados
    final List<Widget> cards = [];
    if (_abaFiltroAtiva == 'Todos' || _abaFiltroAtiva == 'Padrão') {
      cards.add(_buildCardGaleria());
    }
    for (final opcao in opcoesFiltradas) {
      cards.add(_buildCardOpcaoFundo(opcao));
    }

    // Agrupa em estrutura 2 x N (2 cards verticais por coluna horizontal)
    final List<Widget> colunas = [];
    for (int i = 0; i < cards.length; i += 2) {
      final cardSuperior = cards[i];
      final cardInferior = (i + 1 < cards.length) ? cards[i + 1] : null;

      colunas.add(
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            width: 145,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 180,
                  width: 145,
                  child: cardSuperior,
                ),
                const SizedBox(height: 10),
                if (cardInferior != null)
                  SizedBox(
                    height: 180,
                    width: 145,
                    child: cardInferior,
                  )
                else
                  const SizedBox(height: 180, width: 145),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Plano de Fundo da Conversa',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Selecione papéis de parede elegantes ou texturas de oficina.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),

        // Abas de Filtro
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filtros.map((filtro) {
              final ativa = _abaFiltroAtiva == filtro;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _abaFiltroAtiva = filtro;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: ativa ? _corAzulPadrao : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      filtro,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: ativa ? FontWeight.w700 : FontWeight.w500,
                        color: ativa ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Estrutura 2 x N Scrollável Horizontalmente com cards de tamanho aumentado
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: colunas,
          ),
        ),
      ],
    );
  }

  /// Card tracejado "Da Galeria"
  Widget _buildCardGaleria() {
    final selecionado = _planoFundoId.startsWith('galeria:') ||
        _planoFundoId.startsWith('http');

    return GestureDetector(
      onTap: _selecionarDaGaleria,
      child: CustomPaint(
        painter: _DottedBorderPainter(
          cor: selecionado ? _corAzulPadrao : const Color(0xFFCBD5E1),
          raio: 16,
          largura: selecionado ? 2.0 : 1.5,
        ),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: _corAzulPadrao,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Da Galeria',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Carregar foto',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de opção normal do grid
  Widget _buildCardOpcaoFundo(_OpcaoFundo opcao) {
    final selecionado = _planoFundoId == opcao.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _planoFundoId = opcao.id;
          _imagemGaleriaSelecionada = null;
        });
        _salvarTemaNoSupabase();
      },
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selecionado ? _corAzulPadrao : const Color(0xFFE2E8F0),
            width: selecionado ? 2.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Renderização do thumbnail do fundo
            Positioned.fill(
              child: _buildThumbnailFundo(opcao),
            ),

            // Badge "Padrão" no topo esquerdo
            if (opcao.isPadrao)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _corAzulPadrao,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Padrão',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Check circle azul no topo direito quando selecionado
            if (selecionado)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: _corAzulPadrao,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),

            // Tarja inferior translúcida com títulos
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.72),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      opcao.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      opcao.subtitulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 9.5,
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

  // ---------------------------------------------------------------------------
  // 5. CONTROLES DE AJUSTE (SLIDERS)
  // ---------------------------------------------------------------------------
  Widget _buildSecaoControlesAjuste() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          // Slider 1: Desfoque do Fundo
          Row(
            children: [
              const Icon(
                Icons.grid_view_rounded,
                color: Color(0xFF334155),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Desfoque do Fundo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                '${_desfoqueFundo.round()}px',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              activeTrackColor: _corAzulPadrao,
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: _corAzulPadrao,
              overlayColor: _corAzulPadrao.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _desfoqueFundo,
              min: 0.0,
              max: 15.0,
              divisions: 15,
              onChanged: (val) {
                setState(() {
                  _desfoqueFundo = val;
                });
              },
              onChangeEnd: (_) => _salvarTemaNoSupabase(),
            ),
          ),
          const SizedBox(height: 12),

          // Slider 2: Opacidade da Textura
          Row(
            children: [
              const Icon(
                Icons.water_drop_outlined,
                color: Color(0xFF334155),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Opacidade da Textura',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                '${_opacidadeFundo.round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              activeTrackColor: _corAzulPadrao,
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: _corAzulPadrao,
              overlayColor: _corAzulPadrao.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _opacidadeFundo,
              min: 10.0,
              max: 100.0,
              divisions: 90,
              onChanged: (val) {
                setState(() {
                  _opacidadeFundo = val;
                });
              },
              onChangeEnd: (_) => _salvarTemaNoSupabase(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. APLICAR A TODAS AS CONVERSAS
  // ---------------------------------------------------------------------------
  Widget _buildSecaoAplicarATodas() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFF475569),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aplicar a todas as conversas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Padronizar tema com todos os profissionais',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _aplicarATodas,
            activeThumbColor: Colors.white,
            activeTrackColor: _corAzulPadrao,
            inactiveTrackColor: const Color(0xFFCBD5E1),
            inactiveThumbColor: Colors.white,
            onChanged: (val) {
              setState(() {
                _aplicarATodas = val;
              });
              _salvarTemaNoSupabase();
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS DE RENDERIZAÇÃO DO BACKGROUND
  // ---------------------------------------------------------------------------
  Widget _buildBackgroundRenderizado({
    required double opacidade,
    required double desfoque,
  }) {
    Widget backgroundWidget;

    if (_imagemGaleriaSelecionada != null) {
      if (kIsWeb) {
        backgroundWidget = Image.network(
          _imagemGaleriaSelecionada!.path,
          fit: BoxFit.cover,
        );
      } else {
        backgroundWidget = Image.file(
          File(_imagemGaleriaSelecionada!.path),
          fit: BoxFit.cover,
        );
      }
    } else if (_planoFundoId.startsWith('galeria:')) {
      final caminho = _planoFundoId.replaceFirst('galeria:', '');
      backgroundWidget = Image.file(
        File(caminho),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildDoodleWidget(),
      );
    } else if (_planoFundoId.startsWith('http')) {
      backgroundWidget = Image.network(
        _planoFundoId,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildDoodleWidget(),
      );
    } else {
      // Procura na lista de opções
      final op = _opcoesFundo.firstWhere(
        (o) => o.id == _planoFundoId,
        orElse: () => _opcoesFundo.first,
      );

      switch (op.tipo) {
        case _TipoFundo.doodle:
          backgroundWidget = _buildDoodleWidget();
          break;
        case _TipoFundo.solido:
          backgroundWidget = Container(color: op.corSolida);
          break;
        case _TipoFundo.gradiente:
          backgroundWidget = Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: op.coresGradiente ?? [Colors.white, Colors.blueGrey],
              ),
            ),
          );
          break;
        case _TipoFundo.geometrico:
          backgroundWidget = CustomPaint(
            painter: _GeometricPatternPainter(),
            child: Container(color: const Color(0xFFF1F5F9)),
          );
          break;
      }
    }

    // Aplica opacidade e blur
    Widget resultado = Opacity(
      opacity: opacidade.clamp(0.05, 1.0),
      child: backgroundWidget,
    );

    if (desfoque > 0.1) {
      resultado = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: desfoque,
          sigmaY: desfoque,
        ),
        child: resultado,
      );
    }

    return Container(
      color: Colors.white,
      child: resultado,
    );
  }

  Widget _buildDoodleWidget() {
    return Image.asset(
      _doodleDefaultAsset,
      fit: BoxFit.cover,
      repeat: ImageRepeat.repeat,
      errorBuilder: (context, error, stackTrace) {
        // Fallback dinâmico com CustomPainter se o asset ainda estiver sendo carregado
        return CustomPaint(
          painter: _DoodleConsertaJaPainter(),
          child: Container(color: Colors.white),
        );
      },
    );
  }

  Widget _buildThumbnailFundo(_OpcaoFundo opcao) {
    switch (opcao.tipo) {
      case _TipoFundo.doodle:
        return _buildDoodleWidget();
      case _TipoFundo.solido:
        return Container(color: opcao.corSolida);
      case _TipoFundo.gradiente:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: opcao.coresGradiente ?? [Colors.white, Colors.grey],
            ),
          ),
        );
      case _TipoFundo.geometrico:
        return CustomPaint(
          painter: _GeometricPatternPainter(),
          child: Container(color: const Color(0xFFF1F5F9)),
        );
    }
  }
}

// -----------------------------------------------------------------------------
// MODELOS AUXILIARES
// -----------------------------------------------------------------------------
enum _TipoFundo { doodle, solido, gradiente, geometrico }

class _OpcaoFundo {
  final String id;
  final String titulo;
  final String subtitulo;
  final List<String> categorias;
  final _TipoFundo tipo;
  final bool isPadrao;
  final String? assetPath;
  final Color? corSolida;
  final List<Color>? coresGradiente;

  const _OpcaoFundo({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.categorias,
    required this.tipo,
    this.isPadrao = false,
    this.assetPath,
    this.corSolida,
    this.coresGradiente,
  });
}

// -----------------------------------------------------------------------------
// PAINTERS CUSTOMIZADOS (BORDA TRACEJADA E TEXTURAS)
// -----------------------------------------------------------------------------
class _DottedBorderPainter extends CustomPainter {
  final Color cor;
  final double raio;
  final double largura;

  const _DottedBorderPainter({
    required this.cor,
    required this.raio,
    required this.largura,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cor
      ..strokeWidth = largura
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(raio),
        ),
      );

    // Converte o path em tracejado
    final metrics = path.computeMetrics();
    const dashWidth = 5.0;
    const dashSpace = 4.0;

    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length)
            ? dashWidth
            : metric.length - distance;
        canvas.drawPath(metric.extractPath(distance, distance + length), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedBorderPainter oldDelegate) =>
      oldDelegate.cor != cor || oldDelegate.largura != largura;
}

class _GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 2.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DoodleConsertaJaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const step = 45.0;
    for (double y = 15; y < size.height; y += step) {
      for (double x = 15; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 6.0, paint);
        canvas.drawLine(Offset(x - 5, y - 5), Offset(x + 5, y + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
