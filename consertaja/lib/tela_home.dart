import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'perfil_loja.dart';
import 'perfil_profissional.dart';
import 'tela_meu_perfil_cliente.dart';
import 'widgets/foto_perfil_google.dart';

class ServicoPopular {
  final String titulo;
  final String categoria;
  final double avaliacao;
  final int totalAvaliacoes;
  final double precoMedio;
  final String caminhoImagem;

  ServicoPopular({
    required this.titulo,
    required this.categoria,
    required this.avaliacao,
    required this.totalAvaliacoes,
    required this.precoMedio,
    required this.caminhoImagem,
  });
}

class ServicoProximo {
  final String titulo;
  final String preco;
  final IconData icone;
  final String? oferecidoPor;

  ServicoProximo({
    required this.titulo,
    required this.preco,
    required this.icone,
    this.oferecidoPor,
  });
}

class LojaPopular {
  final String titulo;
  final double avaliacao;
  final int totalAvaliacoes;
  final String distancia;
  final String tag1;
  final String tag2;
  final Color tag1BgColor;
  final Color tag1TextColor;
  final Color tag2BgColor;
  final Color tag2TextColor;
  final String caminhoImagem;
  final bool isVerified;
  final String descricao;

  LojaPopular({
    required this.titulo,
    required this.avaliacao,
    required this.totalAvaliacoes,
    required this.distancia,
    required this.tag1,
    required this.tag2,
    required this.tag1BgColor,
    required this.tag1TextColor,
    required this.tag2BgColor,
    required this.tag2TextColor,
    required this.caminhoImagem,
    this.isVerified = false,
    this.descricao = 'Eletricista Residencial | 120+ serviços concluídos',
  });
}

class PerfilPopular {
  final String nome;
  final double avaliacao;
  final int totalAvaliacoes;
  final String tag;
  final Color tagBgColor;
  final Color tagTextColor;
  final String caminhoImagem;
  final String profissao;
  final String metrica;
  final bool isVerified;

  PerfilPopular({
    required this.nome,
    required this.avaliacao,
    required this.totalAvaliacoes,
    required this.tag,
    required this.tagBgColor,
    required this.tagTextColor,
    required this.caminhoImagem,
    this.profissao = 'Eletricista Residencial',
    this.metrica = '120+ serviços concluídos',
    this.isVerified = true,
  });
}

class TelaHome extends StatelessWidget {
  final bool isVisitante;

  TelaHome({super.key, required this.isVisitante});

  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _ratingBg = Color(0xFFFFF8E1);
  static const Color _ratingText = Color(0xFFE65100);

  final List<ServicoPopular> listaServicos = [
    ServicoPopular(
      titulo: 'Instalação de Ar Condicionado',
      categoria: 'Independente',
      avaliacao: 4.9,
      totalAvaliacoes: 253,
      precoMedio: 350,
      caminhoImagem: 'assets/images/panela.png',
    ),
    ServicoPopular(
      titulo: 'Afiação de faca',
      categoria: 'Independente',
      avaliacao: 4.7,
      totalAvaliacoes: 1248,
      precoMedio: 14.98,
      caminhoImagem: 'assets/images/faca.png',
    ),
    ServicoPopular(
      titulo: 'Costura de calça',
      categoria: 'Independente',
      avaliacao: 5.0,
      totalAvaliacoes: 10,
      precoMedio: 56.99,
      caminhoImagem: 'assets/images/costura.png',
    ),
    ServicoPopular(
      titulo: 'Polimento de sapato',
      categoria: 'Independente',
      avaliacao: 4.8,
      totalAvaliacoes: 9023,
      precoMedio: 28.99,
      caminhoImagem: 'assets/images/sapato.png',
    ),
  ];

  final List<ServicoProximo> listaServicosProximos = [
    ServicoProximo(
      titulo: 'Instalação de Ar',
      preco: 'A partir de R\$ 150',
      icone: Icons.ac_unit,
    ),
    ServicoProximo(
      titulo: 'Pintura Residencial',
      preco: 'A partir de R\$ 300',
      icone: Icons.format_paint_outlined,
      oferecidoPor: 'Oferecido por CAEDSS',
    ),
    ServicoProximo(
      titulo: 'Limpeza Pesada',
      preco: 'A partir de R\$ 120',
      icone: Icons.cleaning_services_outlined,
    ),
  ];

  final List<LojaPopular> listaLojas = [
    LojaPopular(
      titulo: 'Caedss - Estrada das Lágrimas',
      avaliacao: 4.9,
      totalAvaliacoes: 923,
      distancia: '1.2 km',
      tag1: 'Panelas',
      tag2: '#CAEDS',
      tag1BgColor: const Color(0xFFEEEEEE),
      tag1TextColor: const Color(0xFF616161),
      tag2BgColor: const Color(0xFFE1F5FE),
      tag2TextColor: _primaryBlue,
      caminhoImagem: 'assets/images/loja_caedss.png',
      isVerified: true,
    ),
    LojaPopular(
      titulo: 'Chaveiro - Ipiranga',
      avaliacao: 4.9,
      totalAvaliacoes: 252,
      distancia: '800 m',
      tag1: 'Panelas',
      tag2: '#CAEDS',
      tag1BgColor: const Color(0xFFEEEEEE),
      tag1TextColor: const Color(0xFF616161),
      tag2BgColor: const Color(0xFFE1F5FE),
      tag2TextColor: _primaryBlue,
      caminhoImagem: 'assets/images/loja_chaveiro.png',
      isVerified: true,
    ),
    LojaPopular(
      titulo: 'Caedss - Estrada das Lágrimas',
      avaliacao: 4.9,
      totalAvaliacoes: 923,
      distancia: '1.2 km',
      tag1: '#CHAVE',
      tag2: 'Chaveiro',
      tag1BgColor: const Color(0xFFFFE0B2),
      tag1TextColor: const Color(0xFFE65100),
      tag2BgColor: const Color(0xFFE1F5FE),
      tag2TextColor: _primaryBlue,
      caminhoImagem: 'assets/images/loja_caedss.png',
      isVerified: true,
    ),
    LojaPopular(
      titulo: 'Mundo das louças - Estrada das Lágrimas',
      avaliacao: 4.7,
      totalAvaliacoes: 1323,
      distancia: '105 m',
      tag1: '#MUNLO',
      tag2: 'Panelas',
      tag1BgColor: const Color(0xFFE1F5FE),
      tag1TextColor: _primaryBlue,
      tag2BgColor: const Color(0xFFEEEEEE),
      tag2TextColor: const Color(0xFF616161),
      caminhoImagem: 'assets/images/loja_mundo_loucas.png',
    ),
  ];

  final List<PerfilPopular> listaPerfis = [
    PerfilPopular(
      nome: 'Carlos Mendes',
      avaliacao: 4.9,
      totalAvaliacoes: 423,
      tag: 'Eletricista',
      tagBgColor: const Color(0xFFE1F5FE),
      tagTextColor: _primaryBlue,
      caminhoImagem: 'assets/images/perfil_caneta_azul.png',
    ),
    PerfilPopular(
      nome: 'Carlos Mendes',
      avaliacao: 4.9,
      totalAvaliacoes: 423,
      tag: 'Eletricista',
      tagBgColor: const Color(0xFFE1F5FE),
      tagTextColor: _primaryBlue,
      caminhoImagem: 'assets/images/perfil_caneta_azul.png',
    ),
    PerfilPopular(
      nome: 'Carlos Mendes',
      avaliacao: 4.9,
      totalAvaliacoes: 423,
      tag: 'Eletricista',
      tagBgColor: const Color(0xFFE1F5FE),
      tagTextColor: _primaryBlue,
      caminhoImagem: 'assets/images/perfil_caneta_azul.png',
    ),
    PerfilPopular(
      nome: 'Caneta Azul',
      avaliacao: 4.9,
      totalAvaliacoes: 423,
      tag: 'Chaveiro',
      tagBgColor: const Color(0xFFE1F5FE),
      tagTextColor: _primaryBlue,
      caminhoImagem: 'assets/images/perfil_caneta_azul.png',
      profissao: 'Chaveiro',
    ),
  ];

  Future<Map<String, dynamic>?> _buscarDadosUsuario() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final response = await supabase
          .from('usuarios')
          .select('nome, foto_perfil_url')
          .eq('auth_id', user.id)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  PageRouteBuilder _rotaSemAnimacao(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  void _exibirDialogSair(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            isVisitante ? 'Sair do Modo Visitante' : 'Confirmar Saída',
          ),
          content: Text(
            isVisitante
                ? 'Deseja realmente voltar para a tela de escolha de conta?'
                : 'Deseja realmente sair da sua conta?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();

                if (!isVisitante) {
                  await Supabase.instance.client.auth.signOut();
                }

                navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const TelaEscolhaConta()),
                  (route) => false,
                );
              },
              child: const Text(
                'Sair',
                style: TextStyle(
                  color: _primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navegarParaPerfil(BuildContext context) {
    Navigator.of(context).pushReplacement(
      _rotaSemAnimacao(
        TelaMeuPerfilClientePage(isVisitante: isVisitante),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildRatingBadge(double avaliacao) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _ratingBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: _ratingText, size: 12),
          Text(
            ' $avaliacao',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _ratingText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: _primaryBlue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 10),
    );
  }

  Widget _buildSectionHeader({
    required String titulo,
    Color? tituloColor,
    bool mostrarRadar = false,
    String? linkVerTodos,
  }) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: tituloColor ?? Colors.black87,
                  ),
                ),
              ),
              if (mostrarRadar) ...[
                const SizedBox(width: 4),
                const Icon(Icons.radar, color: _primaryBlue, size: 18),
              ],
            ],
          ),
        ),
        if (linkVerTodos != null)
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              linkVerTodos,
              style: const TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOutlineButton(String texto) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryBlue,
          side: const BorderSide(color: _primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          texto,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final larguraDaTela = MediaQuery.of(context).size.width;
    final alturaDaTela = MediaQuery.of(context).size.height;
    final larguraCategoria = (larguraDaTela - 32 - 24) / 4;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 8),

            // Cabeçalho
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LOCALIZAÇÃO ATUAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: _primaryBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 2),
                          const Flexible(
                            child: Text(
                              'Novo Horizonte, SP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.grey.shade700,
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 12, top: 4),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: _primaryBlue,
                        size: 26,
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: _primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: const Text(
                          '2',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _navegarParaPerfil(context),
                  onLongPress: () => _exibirDialogSair(context),
                  child: isVisitante
                      ? CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey.shade200,
                          child: Icon(
                            Icons.person,
                            color: Colors.grey.shade600,
                            size: 22,
                          ),
                        )
                      : FutureBuilder<Map<String, dynamic>?>(
                          future: _buscarDadosUsuario(),
                          builder: (context, snapshot) {
                            final fotoUrl =
                                snapshot.data?['foto_perfil_url'] as String?;
                            return FotoPerfilGoogle(
                              fotoUrl: fotoUrl,
                              radius: 20,
                            );
                          },
                        ),
                ),
              ],
            ),

            SizedBox(height: alturaDaTela * 0.02),

            // Barra de pesquisa + radar
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Qual será o serviço de hoje?',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.radar, color: _primaryBlue, size: 24),
                ),
              ],
            ),

            SizedBox(height: alturaDaTela * 0.025),

            if (isVisitante) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_primaryBlue, Color(0xFF0066FF)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Acesse agora',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Entre ou cadastre-se para ter acesso completo ao ConsertaJá',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: alturaDaTela * 0.025),
            ],

            // Tipos de Serviços
            _buildSectionHeader(
              titulo: 'Tipos de Serviços',
              linkVerTodos: 'Ver todos',
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 8,
              childAspectRatio: larguraCategoria / 72,
              children: [
                _buildCategoriaServico('Ar Cond.', Icons.ac_unit),
                _buildCategoriaServico('Reformas', Icons.handyman_outlined),
                _buildCategoriaServico(
                  'Limpeza',
                  Icons.cleaning_services_outlined,
                ),
                _buildCategoriaServico('Aulas', Icons.school_outlined),
                _buildCategoriaServico('Assistência', Icons.build_outlined),
                _buildCategoriaServico(
                  'Fretes',
                  Icons.local_shipping_outlined,
                ),
                _buildCategoriaServico('Beleza', Icons.content_cut),
                _buildCategoriaServico('Mais', Icons.more_horiz, isMais: true),
              ],
            ),

            SizedBox(height: alturaDaTela * 0.03),

            // Profissionais Perto de Você
            _buildSectionHeader(
              titulo: 'Profissionais Perto de Você',
              tituloColor: _primaryBlue,
              mostrarRadar: true,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: listaPerfis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildCardProfissional(
                    listaPerfis[index],
                    largura: larguraDaTela * 0.78,
                  );
                },
              ),
            ),

            SizedBox(height: alturaDaTela * 0.03),

            // Serviços Perto de Você
            _buildSectionHeader(
              titulo: 'Serviços Perto de Você',
              tituloColor: _primaryBlue,
              mostrarRadar: true,
              linkVerTodos: 'Ver todos',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: listaServicosProximos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildCardServicoProximo(listaServicosProximos[index]);
                },
              ),
            ),

            SizedBox(height: alturaDaTela * 0.03),

            // Profissionais em destaque
            _buildSectionHeader(titulo: 'Profissionais em destaque'),
            const SizedBox(height: 12),
            ...listaPerfis.take(3).map(
                  (perfil) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PerfilProfissionalPage(
                              nomeInicial: perfil.nome,
                              imagemInicial: perfil.caminhoImagem,
                              profissao: perfil.profissao,
                              avaliacao: perfil.avaliacao,
                              totalAvaliacoes: perfil.totalAvaliacoes,
                            ),
                          ),
                        );
                      },
                      child: _buildCardProfissional(perfil),
                    ),
                  ),
                ),
            _buildOutlineButton('Ver todos os profissionais'),

            SizedBox(height: alturaDaTela * 0.03),

            // Lojas em destaque
            _buildSectionHeader(titulo: 'Lojas em destaque'),
            const SizedBox(height: 12),
            ...listaLojas.take(3).map(
                  (loja) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        if (loja.titulo == 'Caedss - Estrada das Lágrimas') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PerfilLoja(),
                            ),
                          );
                        }
                      },
                      child: _buildCardLojaVertical(loja),
                    ),
                  ),
                ),
            _buildOutlineButton('Ver todos os profissionais'),

            SizedBox(height: alturaDaTela * 0.03),

            // Serviços populares
            _buildSectionHeader(titulo: 'Serviços populares'),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: listaServicos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildCardServicoPopular(listaServicos[index]);
                },
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: _primaryBlue,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        currentIndex: 0,
        onTap: (index) {
          if (index == 4) {
            _navegarParaPerfil(context);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Seguindo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Mensagens',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Pedidos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriaServico(
    String texto,
    IconData icone, {
    bool isMais = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isMais ? Colors.grey.shade200 : _primaryBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icone,
            color: isMais ? Colors.grey.shade600 : Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          texto,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCardProfissional(PerfilPopular perfil, {double? largura}) {
    return Container(
      width: largura,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  perfil.caminhoImagem,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: Colors.grey.shade200,
                    child: Icon(Icons.person, color: Colors.grey.shade500),
                  ),
                ),
              ),
              if (perfil.isVerified)
                Positioned(right: -2, bottom: -2, child: _buildVerifiedBadge()),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        perfil.nome,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildRatingBadge(perfil.avaliacao),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  perfil.profissao,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  perfil.metrica,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardServicoProximo(ServicoProximo servico) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(servico.icone, color: _primaryBlue, size: 28),
          const SizedBox(height: 8),
          Text(
            servico.titulo,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            servico.preco,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _primaryBlue,
            ),
          ),
          if (servico.oferecidoPor != null) ...[
            const SizedBox(height: 4),
            Text(
              servico.oferecidoPor!,
              style: const TextStyle(
                fontSize: 9,
                color: _primaryBlue,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardLojaVertical(LojaPopular loja) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _primaryBlue,
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: AssetImage(loja.caminhoImagem),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (loja.isVerified)
                Positioned(right: -2, bottom: -2, child: _buildVerifiedBadge()),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        loja.titulo,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildRatingBadge(loja.avaliacao),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  loja.descricao,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildTag(loja.tag1, loja.tag1BgColor, loja.tag1TextColor),
                    const SizedBox(width: 6),
                    _buildTag(loja.tag2, loja.tag2BgColor, loja.tag2TextColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String texto, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildCardServicoPopular(ServicoPopular servico) {
    return Container(
      width: 160,
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.asset(
                servico.caminhoImagem,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 100,
                  color: Colors.grey.shade200,
                  child: Icon(Icons.image, color: Colors.grey.shade400),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: _buildRatingBadge(servico.avaliacao),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servico.titulo,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  servico.categoria,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Preço médio: R\$ ${servico.precoMedio.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
