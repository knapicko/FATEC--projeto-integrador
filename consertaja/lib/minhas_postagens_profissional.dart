import 'package:flutter/material.dart';

import 'models/postagem_resumo.dart';
import 'services/postagens_profissional_service.dart';

class MinhasPostagensProfissionalPage extends StatefulWidget {
  const MinhasPostagensProfissionalPage({super.key});

  @override
  State<MinhasPostagensProfissionalPage> createState() =>
      _MinhasPostagensProfissionalPageState();
}

class _MinhasPostagensProfissionalPageState
    extends State<MinhasPostagensProfissionalPage> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _titleDark = Color(0xFF1A2B4A);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _inputGray = Color(0xFFF0F2F5);

  final TextEditingController _buscaController = TextEditingController();

  bool _carregando = true;
  List<PostagemResumo> _todasPostagens = [];
  List<PostagemResumo> _postagensFiltradas = [];
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    _carregarPostagens();
    _buscaController.addListener(_filtrarPostagens);
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarPostagens() async {
    setState(() => _carregando = true);

    final postagens = await PostagensProfissionalService.buscarPostagens();

    if (!mounted) return;

    setState(() {
      _todasPostagens = postagens;
      _postagensFiltradas = postagens;
      _carregando = false;
    });
  }

  void _filtrarPostagens() {
    final termo = _buscaController.text.trim().toLowerCase();
    setState(() {
      _termoBusca = termo;
      if (termo.isEmpty) {
        _postagensFiltradas = _todasPostagens;
        return;
      }

      _postagensFiltradas = _todasPostagens.where((postagem) {
        return postagem.titulo.toLowerCase().contains(termo);
      }).toList();
    });
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
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: _titleDark,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Minhas Postagens',
          style: TextStyle(
            color: _titleDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                hintText: 'Pesquisar postagens...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade500,
                ),
                suffixIcon: _termoBusca.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.grey.shade500,
                          size: 20,
                        ),
                        onPressed: () {
                          _buscaController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: _inputGray,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: _primaryBlue),
                  )
                : _postagensFiltradas.isEmpty
                ? _buildEstadoVazio()
                : RefreshIndicator(
                    color: _primaryBlue,
                    onRefresh: _carregarPostagens,
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: _postagensFiltradas.length,
                      itemBuilder: (context, index) {
                        return _buildCardPostagem(_postagensFiltradas[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoVazio() {
    final buscando = _termoBusca.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              buscando ? Icons.search_off_outlined : Icons.photo_library_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              buscando
                  ? 'Nenhuma postagem encontrada'
                  : 'Nenhuma postagem ainda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            if (buscando) ...[
              const SizedBox(height: 6),
              Text(
                'Tente buscar por outro termo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardPostagem(PostagemResumo postagem) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              width: double.infinity,
              child: postagem.imagemUrl != null
                  ? Image.network(
                      postagem.imagemUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildPlaceholderImagem(),
                    )
                  : _buildPlaceholderImagem(),
            ),
          ),
          Expanded(
            flex: 2,
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

  Widget _buildPlaceholderImagem() {
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
}
