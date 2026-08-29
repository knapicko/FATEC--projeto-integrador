import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/icone_oficio.dart';

class AreaAtuacaoPage extends StatefulWidget {
  const AreaAtuacaoPage({super.key});

  @override
  State<AreaAtuacaoPage> createState() => _AreaAtuacaoPageState();
}

class _AreaAtuacaoPageState extends State<AreaAtuacaoPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textGray = Color(0xFF7B7B7B);
  static const Color _cardBlueBg = Color(0xFFE8F7FF);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _carregando = true;
  bool _salvando = false;
  List<Map<String, dynamic>> _oficiosDisponiveis = [];
  final List<Map<String, dynamic>> _oficiosSelecionados = [];
  final PageController _detalhesController = PageController();
  int? _idProfissional;
  int _detalheAtual = 0;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _detalhesController.dispose();
    super.dispose();
  }

  Future<int?> _buscarIdUsuario(String authId) async {
    final response = await _supabase
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', authId)
        .maybeSingle();
    if (response == null) return null;
    final id = response['id_usuario'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      final oficiosResponse = await _supabase
          .from('oficios')
          .select('id_oficio, funcao, categoria, descricao')
          .order('funcao');

      _oficiosDisponiveis = List<Map<String, dynamic>>.from(oficiosResponse);

      final usuarioId = await _buscarIdUsuario(user.id);
      if (usuarioId == null) {
        if (mounted) setState(() => _carregando = false);
        return;
      }

      final dadosProf = await _supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();

      if (dadosProf != null) {
        _idProfissional = (dadosProf['id_profissional'] as num?)?.toInt();
      }

      if (_idProfissional != null) {
        final associacoes = await _supabase
            .from('ass_oficio_profissional')
            .select('fk_oficio')
            .eq('fk_profissional', _idProfissional!);

        final idsOficios = associacoes
            .map((e) => (e['fk_oficio'] as num?)?.toInt())
            .whereType<int>()
            .toList();

        _oficiosSelecionados.clear();
        for (final id in idsOficios) {
          final oficio = _oficiosDisponiveis.firstWhere(
            (o) => (o['id_oficio'] as num?)?.toInt() == id,
            orElse: () => <String, dynamic>{},
          );
          if (oficio.isNotEmpty) _oficiosSelecionados.add(oficio);
        }
      }

      if (mounted) setState(() => _carregando = false);
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  String _caminhoImagemOficio(String nome) {
    return 'assets/images/oficios_imgs/${nome.trim()}.jpg';
  }

  Widget _imagemDetalheOficio(String nome) {
    return Image.asset(
      _caminhoImagemOficio(nome),
      width: double.infinity,
      height: 194,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        height: 194,
        color: _cardBlueBg,
        alignment: Alignment.center,
        child: IconeOficio.imagemPorFuncao(nome, tamanho: 54),
      ),
    );
  }

  void _abrirSeletorOficio(int slotIndex) {
    final idsSelecionados = _oficiosSelecionados
        .map((e) => (e['id_oficio'] as num?)?.toInt())
        .whereType<int>()
        .toSet();

    final opcoes = _oficiosDisponiveis.where((oficio) {
      final id = (oficio['id_oficio'] as num?)?.toInt();
      if (id == null) return false;
      if (slotIndex < _oficiosSelecionados.length) {
        final atual =
            (_oficiosSelecionados[slotIndex]['id_oficio'] as num?)?.toInt();
        if (id == atual) return true;
      }
      return !idsSelecionados.contains(id);
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Selecione uma área',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
              ),
              if (opcoes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nenhuma área disponível.',
                    style: TextStyle(color: _textGray),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: opcoes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final oficio = opcoes[index];
                      final nome = oficio['funcao']?.toString() ?? '';
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconeOficio.imagemPorFuncao(
                            oficio['funcao']?.toString(),
                            tamanho: 28,
                          ),
                        ),
                        title: Text(nome),
                        onTap: () {
                          setState(() {
                            if (slotIndex < _oficiosSelecionados.length) {
                              _oficiosSelecionados[slotIndex] = oficio;
                            } else {
                              _oficiosSelecionados.add(oficio);
                            }
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              if (slotIndex < _oficiosSelecionados.length)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Remover área',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    setState(() => _oficiosSelecionados.removeAt(slotIndex));
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _salvarAlteracoes() async {
    if (_idProfissional == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil profissional não encontrado.'),
        ),
      );
      return;
    }

    if (_oficiosSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos uma área de atuação.'),
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      await _supabase
          .from('ass_oficio_profissional')
          .delete()
          .eq('fk_profissional', _idProfissional!);

      for (final oficio in _oficiosSelecionados) {
        final idOficio = (oficio['id_oficio'] as num?)?.toInt();
        if (idOficio == null) continue;
        await _supabase.from('ass_oficio_profissional').insert({
          'fk_profissional': _idProfissional,
          'fk_oficio': idOficio,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alterações salvas com sucesso!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: _blue, size: 20),
          ),
          const Expanded(
            child: Text(
              'Áreas de Atuação',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _blue,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSecaoEscolha() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Escolha suas áreas',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Até 3',
                style: TextStyle(
                  color: _textGray,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(3, (index) {
              final oficio = index < _oficiosSelecionados.length
                  ? _oficiosSelecionados[index]
                  : null;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 2 ? 10 : 0),
                  child: GestureDetector(
                    onTap: () => _abrirSeletorOficio(index),
                    child: oficio != null
                        ? _buildCardOficioSelecionado(oficio)
                        : _buildCardVazio(),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCardOficioSelecionado(Map<String, dynamic> oficio) {
    final nome = oficio['funcao']?.toString() ?? '';

    return Container(
      height: 136,
      decoration: BoxDecoration(
        color: const Color(0xFFBEEBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _blue, width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: _blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconeOficio.imagemPorFuncaoAzul(nome, tamanho: 56),
                const SizedBox(height: 8),
                Text(
                  nome,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 14,
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

  Widget _buildCardVazio() {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: Colors.grey.shade300,
        strokeWidth: 1.8,
        radius: 22,
      ),
      child: Container(
        height: 136,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.grey.shade400, size: 34),
            const SizedBox(height: 8),
            Text(
              'Vazio',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalhesAreas() {
    if (_oficiosSelecionados.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(11, 28, 11, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detalhes das Áreas Selecionadas',
            style: TextStyle(
              color: _textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 360,
            child: PageView.builder(
              controller: _detalhesController,
              itemCount: _oficiosSelecionados.length,
              onPageChanged: (index) => setState(() => _detalheAtual = index),
              itemBuilder: (context, index) {
                final oficio = _oficiosSelecionados[index];
                final nome = oficio['funcao']?.toString() ?? '';
                final descricao = oficio['descricao']?.toString().trim() ?? '';
                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5F5),
                    border: Border.all(color: const Color(0xFFE0DEDE)),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(22),
                            ),
                            child: _imagemDetalheOficio(nome),
                          ),
                          if (index > 0)
                            Positioned(
                              left: 8,
                              top: 78,
                              child: _buildSetaDetalhe(Icons.chevron_left, () {
                                _detalhesController.previousPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              }),
                            ),
                          if (index < _oficiosSelecionados.length - 1)
                            Positioned(
                              right: 8,
                              top: 78,
                              child: _buildSetaDetalhe(Icons.chevron_right, () {
                                _detalhesController.nextPage(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              }),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                        child: Text(
                          nome,
                          style: const TextStyle(
                            color: Color(0xFF005477),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: Text(
                          descricao,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF50515A),
                            fontSize: 16,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _oficiosSelecionados.length,
                          (dotIndex) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: dotIndex == _detalheAtual
                                  ? _blue
                                  : const Color(0xFFC5C9D5),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetaDetalhe(IconData icone, VoidCallback onPressed) {
    return Material(
      color: Colors.white.withOpacity(0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Icon(icone, color: _textDark, size: 24),
      ),
    );
  }

  Widget _buildBannerSuporte() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entre em contato pelo menu "Fale Conosco".'),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _cardBlueBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: const [
            Icon(Icons.headset_mic_outlined, color: _blue, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Não encontrou sua área de atuação? Nos contate!',
                style: TextStyle(
                  color: _blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoSalvar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _salvando ? null : _salvarAlteracoes,
          style: ElevatedButton.styleFrom(
            backgroundColor: _blue,
            disabledBackgroundColor: _blue.withValues(alpha: 0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: _salvando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Salvar Alterações',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: _blue,
                        size: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator(color: _blue))
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSecaoEscolha(),
                          _buildDetalhesAreas(),
                          _buildBannerSuporte(),
                        ],
                      ),
                    ),
                  ),
                  _buildBotaoSalvar(),
                ],
              ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}
