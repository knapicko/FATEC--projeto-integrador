import 'package:flutter/material.dart';

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

class TelaHome extends StatelessWidget {
  final bool isVisitante; // se true = visita, se false= cliente 

  TelaHome({super.key, required this.isVisitante});

  // apenas coisa simulada pros cards 
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

  @override
  Widget build(BuildContext context) {

    double larguraDaTela = MediaQuery.of(context).size.width;
    double alturaDaTela = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF), 
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [

            // Localização e Perfil
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LOCALIZAÇÃO ATUAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF00A3FF), size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'Adicionar Localização', 
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                      ],
                    )
                  ],
                ),
                
                // foto de perfil
                isVisitante
                    ? const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFE3F2FD),
                        child: Icon(Icons.person, color: Color(0xFF00A3FF)),
                      )
                    : const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFE3F2FD),
                        child: Icon(Icons.person, color: Color(0xFF00A3FF)),
                        //backgroundImage: AssetImage('assets/images/foto_cliente.png') // quando tiver o cadastro funcionando
                      ),
              ],
            ),
            SizedBox(height: alturaDaTela * 0.02),

            // barra de pesquisa
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
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

            // serviços iniciais, só vai mostrar se nãofor visita 
            const Text('Serviços Iniciais', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildQuadradoServico('Panelas', Icons.soup_kitchen_outlined, !isVisitante))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildQuadradoServico('Chaveiro', Icons.vpn_key_outlined, !isVisitante))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildQuadradoServico('', Icons.add, false))),
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _buildQuadradoServico('', Icons.add, false))),
              ],
            ),
            SizedBox(height: alturaDaTela * 0.03),
            // banner pro visita criar logo a conta no mlehor app do mundo (não é a betano)
            if (isVisitante) ...[
              Container(
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
                          Text('Acesse agora', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Text('Entre ou cadastre-se para ter acesso completo ao ConsertaJá', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward, color: Colors.white, size: 28),
                    )
                  ],
                ),
              ),
              SizedBox(height: alturaDaTela * 0.03),
            ],

            // serviços populares
            const Text('Serviços Populares', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),

            // a grade
            GridView.builder(
              shrinkWrap: true, //para o vertical não fica infinito 
              physics: const NeverScrollableScrollPhysics(), // não deixa a tela rolar sozinha
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: ( larguraDaTela / 2) / 220,
              ),
              itemCount: listaServicos.length,
              itemBuilder: (context, index) {
                final servico = listaServicos[index];
                return _buildCardServico(servico);
              },
            ),
          ],
        ),
      ),
      
      // a barra de baixo 
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00A3FF),
        unselectedItemColor: Colors.grey,
        currentIndex: 0, // Home selecionada
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensagens'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
      ),
    );
  }

  // Widget auxiliar para os quadradinhos de Serviços Iniciais
  Widget _buildQuadradoServico(String texto, IconData icone, bool mostrarConteudo) {
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
                Icon(icone, color: Colors.grey, size: 28),
                const SizedBox(height: 4),
                Text(texto, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            )
          : null, 
    );
  }

  // Widget auxiliar para montar cada cartão de serviço popular
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
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              image: DecorationImage(
                image: AssetImage(servico.caminhoImagem), 
                fit: BoxFit.cover),
              ),
              alignment: Alignment.topRight,
              padding: const EdgeInsets.all(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                child: Text(servico.categoria, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(servico.titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('${servico.avaliacao}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(width: 2),
                    const Icon(Icons.star, color: Color(0xFF00A3FF), size: 10),
                    const SizedBox(width: 2),
                    Text('(${servico.totalAvaliacoes})', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Preço Médio', style: TextStyle(fontSize: 9, color: Colors.grey)),
                    Text('R\$ ${servico.precoMedio.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}