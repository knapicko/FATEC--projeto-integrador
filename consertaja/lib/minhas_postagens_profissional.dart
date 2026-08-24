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
  static const Color _deleteRed = Color(0xFFE53935);
  static const Color _archiveGray = Color(0xFF9E9E9E);

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

    final postagens = await PostagensProfissionalService.buscarTodasPostagens();

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

  Future<void> _confirmarApagarPostagem(PostagemResumo postagem) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: _deleteRed, size: 24),
            SizedBox(width: 8),
            Text(
              'Apagar postagem?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Tem certeza que deseja apagar "${postagem.titulo}"? Esta ação não pode ser desfeita.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Apagar',
              style: TextStyle(color: _deleteRed, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) return;

    await _apagarPostagem(postagem);
  }

  Future<void> _apagarPostagem(PostagemResumo postagem) async {
    final sucesso = await PostagensProfissionalService.apagarPostagem(
      postagem.idPostagem,
    );

    if (!mounted) return;

    if (sucesso) {
      setState(() {
        _todasPostagens = _todasPostagens
            .where((p) => p.idPostagem != postagem.idPostagem)
            .toList();
        _postagensFiltradas = _postagensFiltradas
            .where((p) => p.idPostagem != postagem.idPostagem)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postagem apagada.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível apagar a postagem. Verifique as permissões do Supabase.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmarArquivarPostagem(PostagemResumo postagem) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.archive_outlined, color: _archiveGray, size: 24),
            SizedBox(width: 8),
            Text(
              'Arquivar postagem?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Deseja arquivar "${postagem.titulo}"? Ela não aparecerá mais para os clientes.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Arquivar',
              style: TextStyle(color: _archiveGray, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) return;

    await _arquivarPostagem(postagem);
  }

  Future<void> _arquivarPostagem(PostagemResumo postagem) async {
    final ok = await PostagensProfissionalService.arquivarPostagem(
      postagem.idPostagem,
    );

    if (!mounted) return;

    if (ok) {
      setState(() {
        _todasPostagens = _todasPostagens.map((p) {
          if (p.idPostagem == postagem.idPostagem) {
            return PostagemResumo(
              idPostagem: p.idPostagem,
              titulo: p.titulo,
              imagemUrl: p.imagemUrl,
              dataPostagem: p.dataPostagem,
              curtidas: p.curtidas,
              arquivado: true,
            );
          }
          return p;
        }).toList();
        _postagensFiltradas = _postagensFiltradas.map((p) {
          if (p.idPostagem == postagem.idPostagem) {
            return PostagemResumo(
              idPostagem: p.idPostagem,
              titulo: p.titulo,
              imagemUrl: p.imagemUrl,
              dataPostagem: p.dataPostagem,
              curtidas: p.curtidas,
              arquivado: true,
            );
          }
          return p;
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postagem arquivada.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível arquivar a postagem. Verifique as permissões do Supabase.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                  ? 'Nenhuna postagem encontrada'
                  : 'Nenhuna postagem ainda',
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
    final arquivada = postagem.arquivado;

    return Container(
      decoration: BoxDecoration(
        color: arquivada ? const Color(0xFFE8E8E8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: arquivada ? Colors.grey.shade300 : Colors.grey.shade200,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: arquivada
                              ? Colors.grey.shade500
                              : _titleDark,
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
                              style: TextStyle(
                                fontSize: 10,
                                color: arquivada
                                    ? Colors.grey.shade400
                                    : _textMuted,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.favorite_border,
                            size: 14,
                            color: arquivada
                                ? Colors.grey.shade400
                                : _textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            postagem.curtidas.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: arquivada
                                  ? Colors.grey.shade400
                                  : _textMuted,
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
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botão arquivar (cinza)
                GestureDetector(
                  onTap: () => _confirmarArquivarPostagem(postagem),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.archive_outlined,
                      size: 16,
                      color: _archiveGray,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Botão de apagar (vermelho)
                GestureDetector(
                  onTap: () => _confirmarApagarPostagem(postagem),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.shade300,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.delete_outlined,
                      size: 16,
                      color: _deleteRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (arquivada)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Arquivada',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
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