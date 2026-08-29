import 'package:flutter/material.dart';

class AdicionarServicoProfissionalPage extends StatelessWidget {
  const AdicionarServicoProfissionalPage({super.key});

  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _deepBlue = Color(0xFF003F87);
  static const Color _softBlue = Color(0xFFEAF9FF);
  static const Color _panel = Color(0xFFF5F8FB);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF1D2A39);
  static const Color _textMuted = Color(0xFF7B8393);
  static const Color _border = Color(0xFFE6ECF2);

  @override
  Widget build(BuildContext context) {
    final servicosOferecidos = [
      _ServicoOferta(
        titulo: 'Instalação de Ar Condicionado',
        preco: 'A partir de R\$ 350,00',
        imagem: 'assets/images/oficios_imgs/Paneleiro.jpg',
      ),
      _ServicoOferta(
        titulo: 'Reparo Elétrico Residencial',
        preco: 'A partir de R\$ 150,00',
        imagem: 'assets/images/oficios_imgs/Paneleiro.jpg',
      ),
    ];

    final sugestoes = [
      _SugestaoServico(
        titulo: 'Limpeza de Piscina',
        descricao: 'Alta demanda na sua região nesta época do ano.',
        imagem: 'assets/images/oficios_imgs/Paneleiro.jpg',
      ),
      _SugestaoServico(
        titulo: 'Pintura Res...',
        descricao: 'Aumente se... oferecendo... pintura.',
        imagem: 'assets/images/oficios_imgs/Paneleiro.jpg',
      ),
    ];

    return Scaffold(
      backgroundColor: _panel,
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
                        'Adicionar Serviço',
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
                    onPressed: () {},
                    icon: const Icon(
                      Icons.more_vert,
                      color: _primaryBlue,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                children: [
                  Row(
                    children: [
                      Text(
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
                        child: const Text(
                          '2 Ativos',
                          style: TextStyle(
                            color: Color(0xFF6C7783),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...servicosOferecidos.map((servico) => _buildServicoCard(servico)),
                  const SizedBox(height: 22),
                  const Text(
                    'Sugestões para Você',
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: sugestoes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = sugestoes[index];
                        final compact = index == 1;
                        return Container(
                          width: compact ? 155 : 165,
                          decoration: BoxDecoration(
                            color: _card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: Image.asset(
                                  item.imagem,
                                  height: 110,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                                child: Text(
                                  item.titulo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _textDark,
                                    fontSize: compact ? 14 : 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                                child: Text(
                                  item.descricao,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 36,
                                  child: ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _softBlue,
                                      foregroundColor: _primaryBlue,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Text(
                                      compact ? '+ A...' : '+ Adicionar',
                                      style: TextStyle(
                                        color: _primaryBlue,
                                        fontSize: compact ? 12 : 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                    decoration: BoxDecoration(
                      color: _deepBlue,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.straighten_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Criar Serviço Personalizado',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Não encontrou o que precisava? Crie um serviço do zero, com seu próprio nome e preço.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFCAD9EF),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _deepBlue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            child: const Text(
                              'Criar Novo Serviço',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicoCard(_ServicoOferta servico) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              servico.imagem,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servico.titulo,
                  style: const TextStyle(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  servico.preco,
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.edit,
              color: _primaryBlue,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicoOferta {
  const _ServicoOferta({
    required this.titulo,
    required this.preco,
    required this.imagem,
  });

  final String titulo;
  final String preco;
  final String imagem;
}

class _SugestaoServico {
  const _SugestaoServico({
    required this.titulo,
    required this.descricao,
    required this.imagem,
  });

  final String titulo;
  final String descricao;
  final String imagem;
}
