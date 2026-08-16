import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PerfilProfissionalPage extends StatefulWidget {
  final String nomeInicial;
  final String imagemInicial;
  final String profissao;
  final double avaliacao;
  final int totalAvaliacoes;

  const PerfilProfissionalPage({
    super.key,
    required this.nomeInicial,
    required this.imagemInicial,
    this.profissao = 'Profissional independente',
    this.avaliacao = 4.9,
    this.totalAvaliacoes = 120,
  });

  @override
  State<PerfilProfissionalPage> createState() => _PerfilProfissionalPageState();
}

class _PerfilProfissionalPageState extends State<PerfilProfissionalPage> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _bannerDark = Color(0xFF1A3A5C);
  static const Color _priceOrange = Color(0xFFE6A817);
  static const double _pinnedHeaderHeight = 52;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _disponibilidadeKey = GlobalKey();
  final GlobalKey _avaliacoesKey = GlobalKey();
  final GlobalKey _detalhesKey = GlobalKey();
  final GlobalKey _footerButtonKey = GlobalKey();

  int _abaAtiva = 0;
  bool _showFloatingButton = false;
  bool _isAtBottom = false;
  double _lastScrollOffset = 0;
  bool _isScrollingProgrammatically = false;

  String _nome = '';
  String? _fotoUrl;
  bool _carregandoPerfil = true;

  String _filtroComentario = 'Principais';
  String _categoriaServico = 'Todos';
  bool _descricaoExpandida = false;

  DateTime _mesSelecionado = DateTime(2026, 5);

  int _likesComentario1 = 0;
  bool _likedComentario1 = false;
  int _likesComentario2 = 1;
  bool _likedComentario2 = true;
  int _likesComentario3 = 0;
  bool _likedComentario3 = false;

  final List<Map<String, dynamic>> _avaliacoes = [
    {
      'nome': 'Luiz Fernando',
      'iniciais': 'LF',
      'nota': 5.0,
      'tempo': 'há 8 dias',
      'texto': 'Muito bom',
    },
    {
      'nome': 'Gabriel Santos',
      'iniciais': 'GS',
      'nota': 1.0,
      'tempo': 'há 8 dias',
      'texto': 'Moro em diadema',
    },
    {
      'nome': 'Kauã Andrade',
      'iniciais': 'KA',
      'nota': 1.0,
      'tempo': 'há 12 dias',
      'texto': 'Arrebentaram o cabo da minha panela',
    },
  ];

  final List<Map<String, dynamic>> _servicos = [
    {
      'titulo': 'Conserto de cabo de panela',
      'tag': 'Conserto de panela',
      'avaliacao': 4.9,
      'totalAvaliacoes': 253,
      'preco': 15.99,
      'imagem': 'assets/images/panela.png',
    },
    {
      'titulo': 'Conserto de cabo de panela',
      'tag': 'Conserto de panela',
      'avaliacao': 4.9,
      'totalAvaliacoes': 253,
      'preco': 15.99,
      'imagem': 'assets/images/panela.png',
    },
    {
      'titulo': 'Conserto de cabo de panela',
      'tag': 'Conserto de panela',
      'avaliacao': 4.9,
      'totalAvaliacoes': 253,
      'preco': 15.99,
      'imagem': 'assets/images/panela.png',
    },
    {
      'titulo': 'Conserto de cabo de panela',
      'tag': 'Conserto de panela',
      'avaliacao': 4.9,
      'totalAvaliacoes': 253,
      'preco': 15.99,
      'imagem': 'assets/images/panela.png',
    },
  ];

  final List<String> _categorias = [
    'Todos',
    'Costura',
    'Panelas',
    'Encanamento',
    'Cha',
  ];

  @override
  void initState() {
    super.initState();
    _nome = widget.nomeInicial;
    _scrollController.addListener(_onScroll);
    _carregarDadosProfissional();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosProfissional() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('usuarios')
          .select('nome, foto_perfil_url')
          .eq('tipo_conta', 'Profissional')
          .ilike('nome', '%${widget.nomeInicial}%')
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _nome = response['nome']?.toString() ?? widget.nomeInicial;
          final foto = response['foto_perfil_url']?.toString();
          if (foto != null && foto.isNotEmpty && foto != 'null') {
            _fotoUrl = foto;
          }
        });
      }
    } catch (_) {
      // Mantém dados iniciais em caso de falha
    } finally {
      if (mounted) {
        setState(() => _carregandoPerfil = false);
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final atBottom = offset >= maxScroll - 80;
    final scrollingDown = offset > _lastScrollOffset;

    if (!_isScrollingProgrammatically) {
      _atualizarAbaAtiva();
    }

    setState(() {
      _isAtBottom = atBottom;
      if (atBottom) {
        _showFloatingButton = false;
      } else if (scrollingDown && offset > 200) {
        _showFloatingButton = true;
      } else if (!scrollingDown) {
        _showFloatingButton = false;
      }
      _lastScrollOffset = offset;
    });
  }

  double? _getSectionScrollOffset(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached) return null;
    final viewport = RenderAbstractViewport.of(renderObject);
    return viewport.getOffsetToReveal(renderObject, 0.0).offset;
  }

  void _atualizarAbaAtiva() {
    final keys = [_disponibilidadeKey, _avaliacoesKey, _detalhesKey];
    final scrollTop = _scrollController.offset + _pinnedHeaderHeight + 8;

    int novaAba = 0;
    for (int i = 0; i < keys.length; i++) {
      final offset = _getSectionScrollOffset(keys[i]);
      if (offset != null && scrollTop >= offset - 20) {
        novaAba = i;
      }
    }

    if (novaAba != _abaAtiva) {
      setState(() => _abaAtiva = novaAba);
    }
  }

  Future<void> _scrollParaAba(int index) async {
    final keys = [_disponibilidadeKey, _avaliacoesKey, _detalhesKey];
    final key = keys[index];
    final context = key.currentContext;
    if (context == null) return;

    setState(() {
      _abaAtiva = index;
      _isScrollingProgrammatically = true;
    });

    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      alignment: 0.0,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );

    await Future.delayed(const Duration(milliseconds: 550));
    if (mounted) {
      setState(() => _isScrollingProgrammatically = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildCabecalho()),
              SliverToBoxAdapter(child: _buildBarraBusca()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _AbasDelegate(
                  abaAtiva: _abaAtiva,
                  onAbaTap: _scrollParaAba,
                ),
              ),
              SliverToBoxAdapter(
                key: _disponibilidadeKey,
                child: _buildSecaoDisponibilidade(),
              ),
              SliverToBoxAdapter(
                key: _avaliacoesKey,
                child: _buildSecaoAvaliacoes(),
              ),
              SliverToBoxAdapter(
                key: _detalhesKey,
                child: _buildSecaoDetalhes(),
              ),
              SliverToBoxAdapter(child: _buildCatalogoServicos()),
              SliverToBoxAdapter(
                key: _footerButtonKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: _buildBotaoSolicitarServico(),
                ),
              ),
            ],
          ),
          if (_showFloatingButton && !_isAtBottom)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildBotaoSolicitarServico(),
            ),
        ],
      ),
    );
  }

  Widget _buildCabecalho() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              color: _bannerDark,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: _primaryBlue,
                          size: 24,
                        ),
                      ),
                      const Icon(
                        Icons.more_vert,
                        color: _primaryBlue,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(child: _buildFotoPerfil()),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: _primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 58),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_carregandoPerfil)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primaryBlue,
                  ),
                )
              else
                Text(
                  _nome,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(
                Icons.person_add_alt_1,
                color: _primaryBlue,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.work_outline, color: _primaryBlue, size: 16),
            const SizedBox(width: 4),
            Text(
              'Profissional independente',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _buildMetrica(
                icone: Icons.star,
                iconeCor: const Color(0xFFFFC107),
                valor: widget.avaliacao.toStringAsFixed(1),
                label: '${widget.totalAvaliacoes} avaliações',
              ),
              _buildMetrica(
                icone: Icons.verified,
                iconeCor: _primaryBlue,
                valor: 'Pro',
                label: 'Verificado',
              ),
              _buildMetrica(
                icone: Icons.work_history_outlined,
                iconeCor: _primaryBlue,
                valor: '5+',
                label: 'Anos exp.',
              ),
              _buildMetrica(
                icone: Icons.person_outline,
                iconeCor: _primaryBlue,
                valor: '200',
                label: 'Seguidores',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFotoPerfil() {
    if (_fotoUrl != null) {
      return Image.network(
        _fotoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(
          widget.imagemInicial,
          fit: BoxFit.cover,
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primaryBlue,
            ),
          );
        },
      );
    }
    return Image.asset(widget.imagemInicial, fit: BoxFit.cover);
  }

  Widget _buildMetrica({
    required IconData icone,
    required Color iconeCor,
    required String valor,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icone, color: iconeCor, size: 18),
          const SizedBox(height: 4),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBarraBusca() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const TextField(
          decoration: InputDecoration(
            hintText: 'Buscar serviços',
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
            prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
            suffixIcon: Icon(Icons.tune, color: Colors.grey, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildSecaoDisponibilidade() {
    final diasSemana = [
      'DOMINGO',
      'SEGUNDA',
      'TERÇA',
      'QUARTA',
      'QUINTA',
      'SEXTA',
      'SÁBADO',
    ];
    final diasDestacados = {5, 18, 19, 20};
    final diasIndisponiveis = {13, 14};

    final primeiroDia = DateTime(_mesSelecionado.year, _mesSelecionado.month, 1);
    final ultimoDia = DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0);
    final diaInicioSemana = primeiroDia.weekday % 7;
    final totalCelulas = ((diaInicioSemana + ultimoDia.day) / 7).ceil() * 7;

    final meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _mesSelecionado = DateTime(
                      _mesSelecionado.year,
                      _mesSelecionado.month - 1,
                    );
                  });
                },
                child: const Icon(Icons.chevron_left, color: _primaryBlue),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Text(
                    meses[_mesSelecionado.month - 1],
                    style: const TextStyle(
                      color: _primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: _primaryBlue, size: 18),
                  const SizedBox(width: 12),
                  Text(
                    '${_mesSelecionado.year}',
                    style: const TextStyle(
                      color: _primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: _primaryBlue, size: 18),
                ],
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _mesSelecionado = DateTime(
                      _mesSelecionado.year,
                      _mesSelecionado.month + 1,
                    );
                  });
                },
                child: const Icon(Icons.chevron_right, color: _primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryBlue.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Row(
                  children: diasSemana
                      .map(
                        (dia) => Expanded(
                          child: Text(
                            dia,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: _primaryBlue,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: totalCelulas,
                  itemBuilder: (context, index) {
                    final diaNumero = index - diaInicioSemana + 1;
                    final isMesAtual =
                        diaNumero >= 1 && diaNumero <= ultimoDia.day;
                    final isDestacado =
                        isMesAtual && diasDestacados.contains(diaNumero);
                    final isIndisponivel =
                        isMesAtual && diasIndisponiveis.contains(diaNumero);

                    Color bgColor;
                    Color textColor;
                    if (isDestacado) {
                      bgColor = _primaryBlue;
                      textColor = Colors.white;
                    } else if (!isMesAtual || isIndisponivel) {
                      bgColor = Colors.grey.shade200;
                      textColor = Colors.grey.shade400;
                    } else {
                      bgColor = Colors.white;
                      textColor = Colors.grey.shade700;
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDestacado
                              ? _primaryBlue
                              : Colors.grey.shade300,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isMesAtual ? '$diaNumero' : '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoAvaliacoes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '5.0',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Icon(Icons.star, color: _primaryBlue, size: 18),
              const SizedBox(width: 4),
              const Text(
                'Avaliações do Profissional',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(923)',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo dos comentários',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut id dui eu lectus varius pretium ac vel erat. Cras sed sollicitudin sem.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFiltroComentario('Principais'),
              const SizedBox(width: 8),
              _buildFiltroComentario('Recentes'),
              const Spacer(),
              const Text(
                'Ver todas (932)',
                style: TextStyle(
                  color: _primaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildComentarioItem(
            nome: _avaliacoes[0]['nome'],
            iniciais: _avaliacoes[0]['iniciais'],
            nota: _avaliacoes[0]['nota'],
            tempo: _avaliacoes[0]['tempo'],
            texto: _avaliacoes[0]['texto'],
            liked: _likedComentario1,
            likes: _likesComentario1,
            onLikeTap: () {
              setState(() {
                _likedComentario1 = !_likedComentario1;
                _likesComentario1 += _likedComentario1 ? 1 : -1;
              });
            },
          ),
          _buildComentarioItem(
            nome: _avaliacoes[1]['nome'],
            iniciais: _avaliacoes[1]['iniciais'],
            nota: _avaliacoes[1]['nota'],
            tempo: _avaliacoes[1]['tempo'],
            texto: _avaliacoes[1]['texto'],
            liked: _likedComentario2,
            likes: _likesComentario2,
            onLikeTap: () {
              setState(() {
                _likedComentario2 = !_likedComentario2;
                _likesComentario2 += _likedComentario2 ? 1 : -1;
              });
            },
          ),
          _buildComentarioItem(
            nome: _avaliacoes[2]['nome'],
            iniciais: _avaliacoes[2]['iniciais'],
            nota: _avaliacoes[2]['nota'],
            tempo: _avaliacoes[2]['tempo'],
            texto: _avaliacoes[2]['texto'],
            liked: _likedComentario3,
            likes: _likesComentario3,
            onLikeTap: () {
              setState(() {
                _likedComentario3 = !_likedComentario3;
                _likesComentario3 += _likedComentario3 ? 1 : -1;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroComentario(String texto) {
    final isSelected = _filtroComentario == texto;
    return GestureDetector(
      onTap: () => setState(() => _filtroComentario = texto),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryBlue : Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: isSelected ? _primaryBlue : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildComentarioItem({
    required String nome,
    required String iniciais,
    required double nota,
    required String tempo,
    required String texto,
    required bool liked,
    required int likes,
    required VoidCallback onLikeTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _primaryBlue.withValues(alpha: 0.15),
            child: Text(
              iniciais,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < nota.floor()
                            ? Icons.star
                            : Icons.star_border,
                        color: _primaryBlue,
                        size: 12,
                      );
                    }),
                    const SizedBox(width: 6),
                    Text(
                      tempo,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  texto,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onLikeTap,
            child: Column(
              children: [
                Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? _primaryBlue : Colors.grey.shade400,
                  size: 18,
                ),
                Text(
                  '$likes',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoDetalhes() {
    const descricaoCurta =
        'Especialista em instalação, manutenção preventiva e corretiva de ar-condicionado (Split, Inverter e Janela) e sistemas de refrigeração comercial. Compromisso com';
    const descricaoCompleta =
        'Especialista em instalação, manutenção preventiva e corretiva de ar-condicionado (Split, Inverter e Janela) e sistemas de refrigeração comercial. Compromisso com qualidade, pontualidade e atendimento personalizado. Mais de 5 anos de experiência no mercado.';

    final tiposServico = [
      {'icone': Icons.build_outlined, 'label': 'Instalação'},
      {'icone': Icons.handyman_outlined, 'label': 'Reparação'},
      {'icone': Icons.cleaning_services_outlined, 'label': 'Higienização'},
      {'icone': Icons.propane_tank_outlined, 'label': 'Carga de Gás'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: _primaryBlue, size: 20),
              const SizedBox(width: 6),
              const Text(
                'Sobre o Profissional',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _descricaoExpandida ? descricaoCompleta : descricaoCurta,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _descricaoExpandida = !_descricaoExpandida),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _descricaoExpandida ? 'Ver Menos' : 'Ver Mais',
                    style: const TextStyle(
                      color: _primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _descricaoExpandida
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _primaryBlue,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Tipos de serviços oferecidos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.8,
            ),
            itemCount: tiposServico.length,
            itemBuilder: (context, index) {
              final item = tiposServico[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['icone'] as IconData,
                      color: _primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['label'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Galeria de serviços',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 3,
              itemBuilder: (context, index) {
                return Container(
                  width: 200,
                  margin: EdgeInsets.only(right: index < 2 ? 10 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/panela.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.all(10),
                    child: const Text(
                      'Instalação Split 12k BTUs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogoServicos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Serviços Oferecidos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _categorias.length,
              itemBuilder: (context, index) {
                final categoria = _categorias[index];
                final isSelected = _categoriaServico == categoria;
                return GestureDetector(
                  onTap: () => setState(() => _categoriaServico = categoria),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? _primaryBlue : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      categoria,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _primaryBlue : Colors.grey.shade600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: _servicos.length,
            itemBuilder: (context, index) => _buildCardServico(_servicos[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildCardServico(Map<String, dynamic> servico) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.asset(
                    servico['imagem'],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      servico['tag'],
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Text(
              servico['titulo'],
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  '${servico['avaliacao']}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: _primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Colors.white, size: 9),
                ),
                const SizedBox(width: 2),
                Text(
                  '(${servico['totalAvaliacoes']})',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Preço Médio',
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                ),
                Text(
                  'R\$ ${servico['preco'].toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _priceOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoSolicitarServico() {
    return Material(
      elevation: _showFloatingButton ? 6 : 0,
      borderRadius: BorderRadius.circular(12),
      color: _primaryBlue,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icone_caixa_branco.png',
                width: 22,
                height: 22,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'SOLICITAR SERVIÇO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbasDelegate extends SliverPersistentHeaderDelegate {
  final int abaAtiva;
  final void Function(int) onAbaTap;

  static const List<String> _abas = [
    'Disponibilidade',
    'Avaliações',
    'Detalhes',
  ];

  _AbasDelegate({required this.abaAtiva, required this.onAbaTap});

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: List.generate(_abas.length, (index) {
                final isActive = abaAtiva == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onAbaTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _abas[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? const Color(0xFF0FB3FF)
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 2,
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: isActive
                              ? const Color(0xFF0FB3FF)
                              : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AbasDelegate oldDelegate) {
    return oldDelegate.abaAtiva != abaAtiva;
  }
}
