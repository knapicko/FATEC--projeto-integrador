import 'package:flutter/material.dart';

import 'adicionar_servico_profissional.dart';
import 'models/servico_profissional.dart';
import 'services/servicos_profissional_service.dart';

// ── Helper ──────────────────────────────────────────────────────────────────
Color _hexToColorMSP(String hex) {
  try {
    return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
  } catch (_) {
    return const Color(0xFF1D2430);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Meus Serviços do Profissional
// ═══════════════════════════════════════════════════════════════════════════
class MeusServicosProfissionalPage extends StatefulWidget {
  const MeusServicosProfissionalPage({super.key});

  @override
  State<MeusServicosProfissionalPage> createState() =>
      _MeusServicosProfissionalPageState();
}

class _MeusServicosProfissionalPageState
    extends State<MeusServicosProfissionalPage> {
  // ── Cores (padrão do projeto) ──────────────────────────────────────────
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF6F7F9);

  // ── Estado ─────────────────────────────────────────────────────────────
  List<ServicoProfissional> _todosServicos = [];
  bool _carregando = true;

  final TextEditingController _buscaController = TextEditingController();
  String _termoBusca = '';
  String _categoriaAtiva = 'Todos';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final servicos = await ServicosProfissionalService.buscarServicos();
    if (mounted) {
      setState(() {
        _todosServicos = servicos;
        _carregando = false;
        // Reseta filtro se a categoria ativa sumiu
        final cats = _categorias();
        if (!cats.contains(_categoriaAtiva)) _categoriaAtiva = 'Todos';
      });
    }
  }

  // Retorna a lista de categorias únicas dos serviços carregados
  List<String> _categorias() {
    final Set<String> cats = {};
    for (final s in _todosServicos) {
      final cat = s.funcao?.trim();
      if (cat != null && cat.isNotEmpty) cats.add(cat);
    }
    return ['Todos', ...cats.toList()..sort()];
  }

  // Filtra serviços por busca e categoria
  List<ServicoProfissional> get _servicosFiltrados {
    return _todosServicos.where((s) {
      final matchBusca =
          _termoBusca.isEmpty ||
          s.titulo.toLowerCase().contains(_termoBusca.toLowerCase()) ||
          s.descricao.toLowerCase().contains(_termoBusca.toLowerCase());
      final matchCat =
          _categoriaAtiva == 'Todos' || (s.funcao?.trim() == _categoriaAtiva);
      return matchBusca && matchCat;
    }).toList();
  }

  /// Abre a tela de adicionar/editar serviço.
  Future<void> _abrirTelaServico({
    ServicoProfissional? servicoParaEditar,
  }) async {
    final mudou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdicionarServicoProfissionalPage(
          servicoParaEditar: servicoParaEditar,
        ),
      ),
    );
    if (mudou == true) _carregar();
  }

  // ── Build Principal ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final categorias = _categorias();

    return Scaffold(
      backgroundColor: _background,
      // ── AppBar ─────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _blue,
            size: 20,
          ),
        ),
        title: const Text(
          'Meu Serviços Disponíveis',
          style: TextStyle(
            color: _blue,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),

      // ── Conteúdo ────────────────────────────────────────────────────────
      body: Column(
        children: [
          // Fundo branco conectado ao AppBar
          Container(
            color: Colors.white,
            child: Column(
              children: [
                // Campo de busca
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _buildSearchBar(),
                ),
                // Chips de categoria
                if (!_carregando && _todosServicos.isNotEmpty)
                  _buildCategoryChips(categorias),
                if (!_carregando && _todosServicos.isNotEmpty)
                  const SizedBox(height: 12),
              ],
            ),
          ),

          // Lista de cards
          Expanded(
            child: RefreshIndicator(
              color: _blue,
              onRefresh: _carregar,
              child: _carregando
                  ? const Center(child: CircularProgressIndicator(color: _blue))
                  : _servicosFiltrados.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _servicosFiltrados.length,
                      itemBuilder: (context, index) {
                        return _buildCardServico(_servicosFiltrados[index]);
                      },
                    ),
            ),
          ),
        ],
      ),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirTelaServico(),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Novo Serviço',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  // ── Campo de busca ────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: _buscaController,
        onChanged: (v) => setState(() => _termoBusca = v),
        style: const TextStyle(fontSize: 14, color: Color(0xFF3E4350)),
        decoration: InputDecoration(
          hintText: 'Buscar serviços...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade400,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Chips de categoria ────────────────────────────────────────────────────
  Widget _buildCategoryChips(List<String> categorias) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categorias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categorias[index];
          final isActive = cat == _categoriaAtiva;
          return GestureDetector(
            onTap: () => setState(() => _categoriaAtiva = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFD6EDF8) : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF0A6E9D)
                      : const Color(0xFFDDE1E7),
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isActive ? _blue : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Card de serviço ───────────────────────────────────────────────────────
  Widget _buildCardServico(ServicoProfissional s) {
    // Cor da tag de categoria (vem do campo `cor` do modelo)
    final Color tagColor = (s.cor != null && s.cor!.isNotEmpty)
        ? _hexToColorMSP(s.cor!)
        : const Color(0xFF1D2430);

    // Formata o valor para exibição
    final String valorTexto = s.valor <= 0
        ? 'Sob consulta'
        : 'A partir de R\$ ${s.valor.toStringAsFixed(2).replaceAll('.', ',')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Área de imagem ───────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Stack(
              children: [
                // Imagem
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: s.imagemUrl != null && s.imagemUrl!.isNotEmpty
                      ? Image.network(
                          s.imagemUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, e, st) => _placeholderImagem(),
                        )
                      : _placeholderImagem(),
                ),

                // Tag de categoria (canto inferior esquerdo)
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (s.funcao ?? 'SERVIÇO').toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                // Tag de avaliação (canto inferior direito)
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFACC15),
                          size: 14,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Novo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Corpo do card ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título
                Text(
                  s.titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1D2A39),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Descrição
                Text(
                  s.descricao,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7B8393),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Divisor sutil
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F5)),
          ),

          // ── Rodapé do card ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 10, 12),
            child: Row(
              children: [
                // Valor
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VALOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9AA4B2),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        valorTexto,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _blue,
                        ),
                      ),
                    ],
                  ),
                ),

                // Botão de editar
                GestureDetector(
                  onTap: () => _abrirTelaServico(servicoParaEditar: s),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _blue, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: _blue,
                      size: 17,
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

  // ── Estado vazio ─────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_repair_service_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum serviço cadastrado ainda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque em "+ Novo Serviço" para adicionar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  // ── Placeholder de imagem ─────────────────────────────────────────────────
  Widget _placeholderImagem() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: const Color(0xFFEAF4FB),
        child: const Icon(
          Icons.home_repair_service_rounded,
          color: Color(0xFF0A6E9D),
          size: 40,
        ),
      ),
    );
  }
}
