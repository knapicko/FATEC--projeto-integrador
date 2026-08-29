import 'package:flutter/material.dart';

class MeusServicosProfissionalPage extends StatelessWidget {
  const MeusServicosProfissionalPage({super.key});

  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _softBlue = Color(0xFFEAF9FF);
  static const Color _darkText = Color(0xFF1D2A39);
  static const Color _mutedText = Color(0xFF8A93A1);
  static const Color _panel = Color(0xFFF5F8FB);
  static const Color _border = Color(0xFFE6ECF2);
  static const Color _softDark = Color(0xFF1C2E3A);

  @override
  Widget build(BuildContext context) {
    final filtros = ['Todos', 'Elétrica', 'Hidráulica', 'Ar-cond...'];

    final servicos = [
      _ServicoItem(
        imagemPath: 'assets/images/oficios_imgs/Paneleiro.jpg',
        categoria: 'CLIMATIZAÇÃO',
        categoriaCor: const Color(0xFF1D2430),
        avaliacao: '4.9',
        titulo: 'Instalação de Ar Condicionado',
        descricao: 'Instalação completa com teste de carga.',
        valor: 'A partir de R\$ 250,00',
        valorLabel: 'VALOR',
        tagDireita: null,
      ),
      _ServicoItem(
        imagemPath: 'assets/images/oficios_imgs/Paneleiro.jpg',
        categoria: 'ELÉTRICA',
        categoriaCor: const Color(0xFF1A2430),
        avaliacao: '5.0',
        titulo: 'Reparo de Fiação Elétrica',
        descricao: 'Troca de fiação e diagnóstico de curto-circuito.',
        valor: 'R\$ 150,00',
        valorLabel: 'VALOR',
        tagDireita: null,
      ),
      _ServicoItem(
        imagemPath: 'assets/images/oficios_imgs/Paneleiro.jpg',
        categoria: 'HIDRÁULICA',
        categoriaCor: const Color(0xFF1F8BFF),
        avaliacao: 'Novo',
        titulo: 'Conserto de Vazamentos',
        descricao: 'Localização e reparo de vazamentos internos.',
        valor: 'Sob consulta',
        valorLabel: 'VALOR',
        tagDireita: 'Novo',
      ),
    ];

    return Scaffold(
      backgroundColor: _panel,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: const Icon(Icons.add, size: 22),
          label: const Text(
            'Novo Serviço',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                  Expanded(
                    child: Center(
                      child: Text(
                        'Meu Serviços Disponiveis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 14, right: 10),
                          child: Icon(
                            Icons.search,
                            color: Color(0xFF9AA4B2),
                            size: 20,
                          ),
                        ),
                        const Expanded(
                          child: TextField(
                            enabled: false,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Buscar serviços...',
                              hintStyle: TextStyle(
                                color: Color(0xFF9AA4B2),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: filtros.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final selecionado = index == 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selecionado ? _softBlue : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selecionado ? _primaryBlue.withValues(alpha: 0.15) : _border,
                            ),
                          ),
                          child: Text(
                            filtros[index],
                            style: TextStyle(
                              color: selecionado ? _darkText : const Color(0xFF6B7280),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...servicos.map((servico) => _buildCard(servico)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(_ServicoItem servico) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                child: Image.asset(
                  servico.imagemPath,
                  height: 165,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: servico.categoriaCor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    servico.categoria,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFFC857), size: 14),
                      const SizedBox(width: 3),
                      Text(
                        servico.avaliacao,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servico.titulo,
                  style: const TextStyle(
                    color: _darkText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  servico.descricao,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VALOR',
                            style: TextStyle(
                              color: _mutedText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            servico.valor,
                            style: const TextStyle(
                              color: _darkText,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EEF3),
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: _primaryBlue,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicoItem {
  const _ServicoItem({
    required this.imagemPath,
    required this.categoria,
    required this.categoriaCor,
    required this.avaliacao,
    required this.titulo,
    required this.descricao,
    required this.valor,
    required this.valorLabel,
    this.tagDireita,
  });

  final String imagemPath;
  final String categoria;
  final Color categoriaCor;
  final String avaliacao;
  final String titulo;
  final String descricao;
  final String valor;
  final String valorLabel;
  final String? tagDireita;
}
