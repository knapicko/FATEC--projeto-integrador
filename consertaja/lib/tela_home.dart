import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // IMPORTADO: Para realizar o logout do Supabase
import 'main.dart'; // IMPORTADO: Para redirecionar para a TelaEscolhaConta
import 'perfil_loja.dart'; // Conecta a tela de perfil da loja
import 'tela_meu_perfil_cliente.dart';

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

  PerfilPopular({
    required this.nome,
    required this.avaliacao,
    required this.totalAvaliacoes,
    required this.tag,
    required this.tagBgColor,
    required this.tagTextColor,
    required this.caminhoImagem,
  });
}

class TelaHome extends StatelessWidget {
  final bool isVisitante;

  TelaHome({super.key, required this.isVisitante});

  final List<ServicoPopular> listaServicos = [
    ServicoPopular(
      titulo: 'Conserto de cabo de panela',
      categoria: 'Conserto de panela',
      avaliacao: 4.9,
      totalAvaliacoes: 253,
      precoMedio: 15.99,
      caminhoImagem: 'assets/images/panela.png',
    ),
    ServicoPopular(
      titulo: 'Afiação de faca',
      categoria: 'Afiação de faca',
      avaliacao: 4.7,
      totalAvaliacoes: 1248,
      precoMedio: 14.98,
      caminhoImagem: 'assets/images/faca.png',
    ),
    ServicoPopular(
      titulo: 'Costura de calça',
      categoria: 'Costura',
      avaliacao: 5.0,
      totalAvaliacoes: 10,
      precoMedio: 56.99,
      caminhoImagem: 'assets/images/costura.png',
    ),
    ServicoPopular(
      titulo: 'Polimento de sapato',
      categoria: 'Engraxate',
      avaliacao: 4.8,
      totalAvaliacoes: 9023,
      precoMedio: 28.99,
      caminhoImagem: 'assets/images/sapato.png',
    ),
  ];

  final List<LojaPopular> listaLojas = [
    LojaPopular(
      titulo: 'Caedss - Estrada das Lágrimas',
      avaliacao: 5.0,
      totalAvaliacoes: 923,
      distancia: '1.2 km',
      tag1: '#CAEDS',
      tag2: 'Costura',
      tag1BgColor: const Color(0xFFE1F5FE),
      tag1TextColor: const Color(0xFF0288D1),
      tag2BgColor: const Color(0xFFE8F5E9),
      tag2TextColor: const Color(0xFF2E7D32),
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
      tag1TextColor: const Color(0xFF0288D1),
      tag2BgColor: const Color(0xFFEEEEEE),
      tag2TextColor: const Color(0xFF616161),
      caminhoImagem: 'assets/images/loja_mundo_loucas.png',
    ),
    LojaPopular(
      titulo: 'Chaveiro - Ipiranga',
      avaliacao: 4.9,
      totalAvaliacoes: 252,
      distancia: '800 m',
      tag1: '#CHAVE',
      tag2: 'Chaveiro',
      tag1BgColor: const Color(0xFFFFE0B2),
      tag1TextColor: const Color(0xFFE65100),
      tag2BgColor: const Color(0xFFE1F5FE),
      tag2TextColor: const Color(0xFF0288D1),
      caminhoImagem: 'assets/images/loja_chaveiro.png',
    ),
    LojaPopular(
      titulo: 'Caedss - Estrada das Lágrimas',
      avaliacao: 5.0,
      totalAvaliacoes: 923,
      distancia: '1.2 km',
      tag1: '#CAEDS',
      tag2: 'Polimento',
      tag1BgColor: const Color(0xFFE1F5FE),
      tag1TextColor: const Color(0xFF0288D1),
      tag2BgColor: const Color(0xFFEEEEEE),
      tag2TextColor: const Color(0xFF616161),
      caminhoImagem: 'assets/images/loja_caedss.png',
    ),
  ];

  final List<PerfilPopular> listaPerfis = [
    PerfilPopular(
      nome: 'Caneta Azul',
      avaliacao: 4.9,
      totalAvaliacoes: 423,
      tag: 'Chaveiro',
      tagBgColor: const Color(0xFFE1F5FE),
      tagTextColor: const Color(0xFF0288D1),
      caminhoImagem: 'assets/images/perfil_caneta_azul.png',
    ),
    PerfilPopular(
      nome: 'Caneta Azul',
      avaliacao: 4.9,
      totalAvaliacoes: 423,
      tag: 'Costura',
      tagBgColor: const Color(0xFFE8F5E9),
      tagTextColor: const Color(0xFF2E7D32),
      caminhoImagem: 'assets/images/perfil_caneta_azul.png',
    ),
    PerfilPopular(
      nome: 'Caneta Azul',
      avaliacao: 4.9,
      totalAvaliacoes: 423,
      tag: 'Chaveiro',
      tagBgColor: const Color(0xFFE1F5FE),
      tagTextColor: const Color(0xFF0288D1),
      caminhoImagem: 'assets/images/perfil_caneta_azul.png',
    ),
    PerfilPopular(
      nome: 'Caneta Azul',
      avaliacao: 4.9,
      totalAvaliacoes: 423,
      tag: 'Chaveiro',
      tagBgColor: const Color(0xFFE1F5FE),
      tagTextColor: const Color(0xFF0288D1),
      caminhoImagem: 'assets/images/perfil_caneta_azul.png',
    ),
    PerfilPopular(
      nome: 'Caneta Azul',
      avaliacao: 4.9,
      totalAvaliacoes: 423,
      tag: 'Chaveiro',
      tagBgColor: const Color(0xFFE1F5FE),
      tagTextColor: const Color(0xFF0288D1),
      caminhoImagem: 'assets/images/perfil_caneta_azul.png',
    ),
    PerfilPopular(
      nome: 'Caneta Azul',
      avaliacao: 4.9,
      totalAvaliacoes: 423,
      tag: 'Chaveiro',
      tagBgColor: const Color(0xFFE1F5FE),
      tagTextColor: const Color(0xFF0288D1),
      caminhoImagem: 'assets/images/perfil_caneta_azul.png',
    ),
  ];

  Future<String?> _buscarNomeUsuario() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      // Busca apenas o nome do usuário logado relacionando o auth_id
      final response = await supabase
          .from('usuarios')
          .select('nome')
          .eq('auth_id', user.id)
          .maybeSingle();

      return response?['nome'] as String?;
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
                  color: Color(0xFF00A3FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double larguraDaTela = MediaQuery.of(context).size.width;
    double alturaDaTela = MediaQuery.of(context).size.height;

    double larguraDoQuadrado = (larguraDaTela - 32) / 4.2;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOCALIZAÇÃO ATUAL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Color(0xFF00A3FF),
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Adicionar Localização',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                      ],
                    ),
                  ],
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Novo bloco: Mostra o nome do usuário logado
                    if (!isVisitante)
                      FutureBuilder<String?>(
                        future: _buscarNomeUsuario(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00A3FF),
                                ),
                              ),
                            );
                          }
                          final nomeCompleto = snapshot.data;
                          if (nomeCompleto != null && nomeCompleto.isNotEmpty) {
                            // Pega apenas o primeiro nome para não quebrar o layout da barra
                            final primeiroNome = nomeCompleto.split(' ')[0];
                            return Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: Text(
                                primeiroNome,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),

                    // Botão de Logout mantido e ajustado
                    if (!isVisitante)
                      IconButton(
                        icon: const Icon(
                          Icons.logout,
                          color: Color(0xFF00A3FF),
                          size: 22,
                        ),
                        onPressed: () => _exibirDialogSair(context),
                        tooltip: 'Sair da Conta',
                      ),
                  ],
                ),
              ],
            ),
            SizedBox(height: alturaDaTela * 0.02),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Qual será o serviço de hoje?',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            SizedBox(height: alturaDaTela * 0.03),

            const Text(
              'Serviços Iniciais',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  SizedBox(
                    width: larguraDoQuadrado,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildQuadradoServico(
                        'Panelas',
                        Icons.soup_kitchen_outlined,
                        true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: larguraDoQuadrado,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildQuadradoServico(
                        'Chaveiro',
                        Icons.vpn_key_outlined,
                        true,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: larguraDoQuadrado,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildQuadradoServico('Mais', Icons.add, true),
                    ),
                  ),
                  SizedBox(
                    width: larguraDoQuadrado,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildQuadradoServico('Mais', Icons.add, true),
                    ),
                  ),
                  SizedBox(
                    width: larguraDoQuadrado,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildQuadradoServico('Mais', Icons.add, true),
                    ),
                  ),
                  SizedBox(
                    width: larguraDoQuadrado,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildQuadradoServico('Mais', Icons.add, true),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: alturaDaTela * 0.03),

            if (isVisitante) ...[
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00A3FF), Color(0xFF0066FF)],
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
              SizedBox(height: alturaDaTela * 0.03),
            ],

            const Text(
              'Serviços Populares',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: (larguraDaTela / 2) / 220,
              ),
              itemCount: listaServicos.length,
              itemBuilder: (context, index) {
                final servico = listaServicos[index];
                return _buildCardServico(servico);
              },
            ),
            SizedBox(height: alturaDaTela * 0.04),

            const Text(
              'Lojas populares',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFiltroLoja('Todos', isSelected: true),
                  _buildFiltroLoja('Costura'),
                  _buildFiltroLoja('Panelas'),
                  _buildFiltroLoja('Encanamento'),
                  _buildFiltroLoja('Chaveiro'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate((listaLojas.length / 2).ceil(), (
                      index,
                    ) {
                      int actualIndex = index * 2;
                      final loja = listaLojas[actualIndex];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            if (loja.titulo ==
                                'Caedss - Estrada das Lágrimas') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PerfilLoja(),
                                ),
                              );
                            }
                          },
                          child: _buildCardLoja(loja),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(listaLojas.length ~/ 2, (index) {
                      int actualIndex = (index * 2) + 1;
                      final loja = listaLojas[actualIndex];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            if (loja.titulo ==
                                'Caedss - Estrada das Lágrimas') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const PerfilLoja(),
                                ),
                              );
                            }
                          },
                          child: _buildCardLoja(loja),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Perfis populares',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFiltroLoja('Todos', isSelected: true),
                  _buildFiltroLoja('Costura'),
                  _buildFiltroLoja('Panelas'),
                  _buildFiltroLoja('Encanamento'),
                  _buildFiltroLoja('Chaveiro'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate((listaPerfis.length / 2).ceil(), (
                      index,
                    ) {
                      int actualIndex = index * 2;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildCardPerfil(listaPerfis[actualIndex]),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(listaPerfis.length ~/ 2, (index) {
                      int actualIndex = (index * 2) + 1;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildCardPerfil(listaPerfis[actualIndex]),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00A3FF),
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        onTap: (index) {
          if (index == 4) {
            Navigator.of(context).pushReplacement(
              _rotaSemAnimacao(
                TelaMeuPerfilClientePage(isVisitante: isVisitante),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
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
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildQuadradoServico(
    String texto,
    IconData icone,
    bool mostrarConteudo,
  ) {
    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: mostrarConteudo
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, color: const Color(0xFF00A3FF), size: 26),
                const SizedBox(height: 4),
                if (texto.isNotEmpty)
                  Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            )
          : null,
    );
  }

  Widget _buildCardServico(ServicoPopular servico) {
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
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                image: DecorationImage(
                  image: AssetImage(servico.caminhoImagem),
                  fit: BoxFit.cover,
                ),
              ),
              alignment: Alignment.topRight,
              padding: const EdgeInsets.all(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  servico.categoria,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servico.titulo,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${servico.avaliacao}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.star, color: Color(0xFF00A3FF), size: 10),
                    const SizedBox(width: 2),
                    Text(
                      '(${servico.totalAvaliacoes})',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Preço Médio',
                      style: TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    Text(
                      'R\$ ${servico.precoMedio.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
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

  Widget _buildFiltroLoja(String texto, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCardLoja(LojaPopular loja) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: AssetImage(loja.caminhoImagem),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (loja.isVerified)
                const Positioned(
                  right: -4,
                  bottom: -4,
                  child: Icon(
                    Icons.verified,
                    color: Color(0xFF00A3FF),
                    size: 16,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loja.titulo,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFF00A3FF), size: 11),
                    const SizedBox(width: 1),
                    Text(
                      '${loja.avaliacao}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '(${loja.totalAvaliacoes})',
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF00A3FF),
                      size: 11,
                    ),
                    Text(
                      loja.distancia,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: loja.tag1BgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        loja.tag1,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: loja.tag1TextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: loja.tag2BgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        loja.tag2,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: loja.tag2TextColor,
                        ),
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

  Widget _buildCardPerfil(PerfilPopular perfil) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
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
            child: FutureBuilder<String?>(
              future: _buscarNomeUsuario(),
              builder: (context, snapshot) {
                final nomeCompleto = snapshot.data ?? '';
                final primeiroNome = nomeCompleto.trim().isNotEmpty
                    ? nomeCompleto.trim().split(' ').first
                    : 'Perfil';

                return SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(
                    child: Text(
                      primeiroNome,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00A3FF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            perfil.nome,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFF00A3FF), size: 12),
              const SizedBox(width: 2),
              Text(
                '${perfil.avaliacao}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '(${perfil.totalAvaliacoes})',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: perfil.tagBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              perfil.tag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: perfil.tagTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
