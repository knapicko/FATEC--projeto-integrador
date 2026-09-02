import 'package:flutter/material.dart';

import 'adicionar_servico_profissional.dart';
import 'models/servico_profissional.dart';
import 'services/servicos_profissional_service.dart';

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
  // Cores do tema (iguais às da tela Adicionar Serviço)
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _deepBlue = Color(0xFF003F87);
  static const Color _softBlue = Color(0xFFEAF9FF);
  static const Color _panel = Color(0xFFF5F8FB);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF1D2A39);
  static const Color _textMuted = Color(0xFF7B8393);
  static const Color _border = Color(0xFFE6ECF2);

  List<ServicoProfissional> _servicosAtivos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    final servicos = await ServicosProfissionalService.buscarServicos();
    if (mounted) {
      setState(() {
        _servicosAtivos = servicos;
        _carregando = false;
      });
    }
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

  Future<void> _confirmarExclusao(ServicoProfissional s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover serviço?'),
        content: Text('Deseja remover "${s.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final deletou = await ServicosProfissionalService.deletarServico(s.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              deletou ? 'Serviço removido.' : 'Erro ao remover serviço.',
            ),
            backgroundColor: deletou ? Colors.green : Colors.red,
          ),
        );
        if (deletou) _carregar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _panel,
      body: SafeArea(
        child: Column(
          children: [
            // ── AppBar (igual à de Adicionar Serviço) ──────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: _panel,
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: _primaryBlue,
                      size: 22,
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Meus Serviços',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _carregar,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: _primaryBlue,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // ── Conteúdo ────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: _primaryBlue,
                onRefresh: _carregar,
                child: _carregando
                    ? const Center(
                        child: CircularProgressIndicator(color: _primaryBlue),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        children: [
                          _buildSecaoAtivos(),
                          const SizedBox(height: 20),
                          // Botão de adicionar novo serviço
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _abrirTelaServico,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryBlue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text(
                                'Adicionar Serviço',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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

  // ── Seção 1: Serviços já oferecidos ────────────────────────────────────
  Widget _buildSecaoAtivos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho com contagem de ativos
        Row(
          children: [
            const Text(
              'Serviços Oferecidos',
              style: TextStyle(
                color: _textDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _softBlue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_servicosAtivos.length} Ativo${_servicosAtivos.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  color: Color(0xFF6C7783),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_servicosAtivos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.home_repair_service_outlined,
                  color: Color(0xFF9AA4B2),
                  size: 36,
                ),
                SizedBox(height: 10),
                Text(
                  'Nenhum serviço cadastrado ainda.',
                  style: TextStyle(color: _textMuted, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ...List.generate(_servicosAtivos.length, (i) {
            final s = _servicosAtivos[i];
            return _buildCardServicoAtivo(s);
          }),
      ],
    );
  }

  Widget _buildCardServicoAtivo(ServicoProfissional s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          // Imagem
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: s.imagemUrl != null && s.imagemUrl!.isNotEmpty
                ? Image.network(
                    s.imagemUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, e, st) => _placeholderImg(72),
                  )
                : _placeholderImg(72),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.titulo,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'R\$ ${s.valor.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Botão editar
          GestureDetector(
            onTap: () => _abrirTelaServico(servicoParaEditar: s),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _softBlue,
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: _primaryBlue,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Botão deletar
          GestureDetector(
            onTap: () => _confirmarExclusao(s),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(19),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  Widget _placeholderImg(double size) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFEAF9FF),
      child: const Icon(
        Icons.home_repair_service_rounded,
        color: Color(0xFF0FB3FF),
        size: 28,
      ),
    );
  }
}
