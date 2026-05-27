import 'package:flutter/material.dart';

class PerfilLoja extends StatefulWidget {
  const PerfilLoja({super.key});

  @override
  State<PerfilLoja> createState() => _PerfilLojaState();
}

class _PerfilLojaState extends State<PerfilLoja> {
  String filtroComentario = 'Principais';
  bool isDescricaoExpandida = false;
  
  // Estados para controle dinâmico de cliques nos corações da seção de avaliações
  int likesComentario1 = 0;
  bool likedComentario1 = false;
  
  int likesComentario2 = 1;
  bool likedComentario2 = true;

  // Lista mockada de profissionais locais seguindo o design solicitado
  final List<Map<String, dynamic>> listaProfissionais = [
    {
      'nome': 'Caneta Azul',
      'avaliacao': 4.9,
      'totalAvaliacoes': 423,
      'tag': 'Chaveiro',
      'tagBgColor': const Color(0xFFE1F5FE),
      'tagTextColor': const Color(0xFF0288D1),
      'caminhoImagem': 'assets/images/perfil_caneta_azul.png',
    },
    {
      'nome': 'Caneta Azul',
      'avaliacao': 4.9,
      'totalAvaliacoes': 423,
      'tag': 'Costura',
      'tagBgColor': const Color(0xFFE8F5E9),
      'tagTextColor': const Color(0xFF2E7D32),
      'caminhoImagem': 'assets/images/perfil_caneta_azul.png',
    },
    {
      'nome': 'Caneta Azul',
      'avaliacao': 4.9,
      'totalAvaliacoes': 423,
      'tag': 'Chaveiro',
      'tagBgColor': const Color(0xFFE1F5FE),
      'tagTextColor': const Color(0xFF0288D1),
      'caminhoImagem': 'assets/images/perfil_caneta_azul.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // BANNER E CONTROLES DE TOPO
            // ==========================================
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 130,
                  color: const Color(0xFF115F80), // Cor especificada do Banner
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                        ),
                        const Icon(Icons.more_vert, color: Colors.white, size: 24),
                      ],
                    ),
                  ),
                ),
                
                // FOTO DA LOJA SOBREPOSTA COM SELO E TAG EMBUTIDAS
                Positioned(
                  bottom: -35,
                  left: 16,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 3),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/loja_caedss.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // Símbolo de verificado no canto superior esquerdo
                      const Positioned(
                        top: -4,
                        left: -4,
                        child: Icon(Icons.verified, color: Color(0xFF00A3FF), size: 18),
                      ),
                      // Tag1 embutida no canto inferior direito
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1F5FE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '#CAEDS',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Color(0xFF0288D1)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 45), // Alinhamento para compensar a foto flutuante

            // ==========================================
            // DETALHES DE INFORMAÇÃO DA LOJA
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Caedss - Estrada das Lágrimas',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        'Aberta até 20h',
                        style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star, color: Color(0xFF00A3FF), size: 13),
                      const SizedBox(width: 2),
                      const Text(
                        '5.0 (923)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      // Badge de Perfil Verificado na mesma row
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Color(0xFF00A3FF), size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Perfil Verificado',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00A3FF)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // BARRA DE PESQUISA CENTRALIZADA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar serviços',
                    prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
                    suffixIcon: Icon(Icons.tune, color: Color(0xFF00A3FF), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ROW COM NAVEGAÇÃO DE TABS (Profissionais, Avaliações e Detalhes)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTabButton('Profissionais', true),
                  _buildTabButton('Avaliações', false),
                  _buildTabButton('Detalhes', false),
                ],
              ),
            ),
            const Divider(height: 24, thickness: 1),

            // ==========================================
            // SEÇÃO: PROFISSIONAIS
            // ==========================================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Profissionais',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: listaProfissionais.map((p) => _buildCardProfissional(p)).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // SEÇÃO: AVALIAÇÕES
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFF00A3FF), size: 18),
                  const SizedBox(width: 4),
                  const Text(
                    'Avaliações da loja',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(width: 4),
                  const Text('(923)', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            
            // Container de Resumo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut id dui eu lectus varius pretium ac vel erat. Cras sed sollicitudin sem.',
                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filtros clicáveis de Comentário
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildFiltroComentario('Principais'),
                  const SizedBox(width: 8),
                  _buildFiltroComentario('Recentes'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Comentário 1: Luiz Fernando
            _buildComentarioItem(
              nome: 'Luiz Fernando',
              nota: 4.5,
              tempo: 'há 8 dias',
              texto: 'Muito bom',
              liked: likedComentario1,
              likes: likesComentario1,
              onLikeTap: () {
                setState(() {
                  likedComentario1 = !likedComentario1;
                  likesComentario1 += likedComentario1 ? 1 : -1;
                });
              },
            ),

            // Comentário 2: Kauã Andrade
            _buildComentarioItem(
              nome: 'Kauã Andrade',
              nota: 0.5,
              tempo: 'há 8 dias',
              texto: 'Arrebentaram o cabo da minha panela',
              liked: likedComentario2,
              likes: likesComentario2,
              onLikeTap: () {
                setState(() {
                  likedComentario2 = !likedComentario2;
                  likesComentario2 += likedComentario2 ? 1 : -1;
                });
              },
            ),
            const SizedBox(height: 20),

            // ==========================================
            // SEÇÃO: DETALHES (DESCRIÇÃO COM EXPANSÃO)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Descrição',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const Divider(height: 16, thickness: 1),
                    Text(
                      isDescricaoExpandida
                          ? 'A Caedss Acessórios é uma loja localizada na Estrada das Lágrimas, em São Paulo, especializada em acessórios e tecnologia para celulares. A empresa oferece produtos modernos e soluções práticas para quem busca qualidade, inovação e atendimento personalizado no segmento de tecnologia móvel.\nLorem Ipsum Lorem IpsumLorem IpsumLorem \n\nAAAAAA Texto aumentadoaumentadoaumentadoaumentadoaumentadoaumentado aumentadoaumentadoaumentadoaumentado'
                          : 'A Caedss Acessórios é uma loja localizada na Estrada das Lágrimas, em São Paulo, especializada em acessórios e tecnologia para celulares. A empresa oferece produtos modernos e soluções práticas para quem busca qualidade, inovação e atendimento personalizado no segmento de tecnologia móvel.\nLorem Ipsum Lorem IpsumLorem IpsumLorem ',
                      style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isDescricaoExpandida = !isDescricaoExpandida;
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isDescricaoExpandida ? 'Ver Menos' : 'Ver Mais',
                              style: const TextStyle(
                                color: Color(0xFF00A3FF),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              isDescricaoExpandida ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              color: const Color(0xFF00A3FF),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String titulo, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titulo,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isActive ? const Color(0xFF00A3FF) : Colors.grey,
          ),
        ),
        if (isActive) ...[
          const SizedBox(height: 4),
          Container(width: 40, height: 2, color: const Color(0xFF00A3FF))
        ]
      ],
    );
  }

  Widget _buildFiltroComentario(String texto) {
    bool isSelected = filtroComentario == texto;
    return GestureDetector(
      onTap: () {
        setState(() {
          filtroComentario = texto;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00A3FF) : Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00A3FF) : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildCardProfissional(Map<String, dynamic> perfil) {
    return Container(
      width: 135,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.grey.shade100,
              backgroundImage: AssetImage(perfil['caminhoImagem']),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            perfil['nome'],
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFF00A3FF), size: 11),
              const SizedBox(width: 2),
              Text(
                '${perfil['avaliacao']}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(width: 2),
              Text(
                '(${perfil['totalAvaliacoes']})',
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: perfil['tagBgColor'],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              perfil['tag'],
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: perfil['tagTextColor']),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComentarioItem({
    required String nome,
    required double nota,
    required String tempo,
    required String texto,
    required bool liked,
    required int likes,
    required VoidCallback onLikeTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      if (index < nota.floor()) {
                        return const Icon(Icons.star, color: Color(0xFF00A3FF), size: 12);
                      } else if (index == nota.floor() && nota % 1 != 0) {
                        return const Icon(Icons.star_half, color: Color(0xFF00A3FF), size: 12);
                      } else {
                        return const Icon(Icons.star_border, color: Color(0xFF00A3FF), size: 12);
                      }
                    }),
                    const SizedBox(width: 8),
                    Text(tempo, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(texto, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          
          // ÍCONES DE CORAÇÃO INTERATIVOS CONFORME COR E ESPECIFICAÇÃO
          GestureDetector(
            onTap: onLikeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked ? const Color(0xFF00A3FF) : Colors.grey.shade400,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$likes',
                    style: TextStyle(
                      fontSize: 10,
                      color: liked ? const Color(0xFF00A3FF) : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}