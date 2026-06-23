import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'login.dart';
import 'tela_home.dart';

class TelaHomeProfissional extends StatefulWidget {
  final bool isVisitante;

  const TelaHomeProfissional({super.key, required this.isVisitante});

  @override
  State<TelaHomeProfissional> createState() => _TelaHomeProfissionalState();
}

class _TelaHomeProfissionalState extends State<TelaHomeProfissional> {
  int _currentIndex = 0;

  Future<Map<String, dynamic>?> _buscarDadosProfissional() async {
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

  Future<String?> _buscarEndereco() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final usuarioResponse = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (usuarioResponse == null) return "Rua Capitão Pacheco e Chaves, 313 - Mooca, São Paulo - SP";

      final usuarioId = usuarioResponse['id_usuario'];

      final enderecoResponse = await supabase
          .from('enderecos')
          .select('logradouro, numero, bairro, cidade, estado')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();

      if (enderecoResponse == null) return null;

      final logradouro = enderecoResponse['logradouro'] ?? '';
      final numero = enderecoResponse['numero'] ?? '';
      final bairro = enderecoResponse['bairro'] ?? '';
      final cidade = enderecoResponse['cidade'] ?? '';
      final estado = enderecoResponse['estado'] ?? '';

      if (logradouro.toString().isEmpty) return null;

      return '$logradouro, $numero - $bairro, $cidade - $estado';
    } catch (e) {
      return null;
    }
  }

  void _exibirDialogSair(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Saída'),
          content: const Text('Deseja realmente sair da sua conta?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await Supabase.instance.client.auth.signOut();
                navigatorKey.currentState?.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const TelaEscolhaConta()),
                  (route) => false,
                );
              },
              child: const Text(
                'Sair',
                style: TextStyle(
                  color: Color(0xFF0FB3FF),
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ================= CABEÇALHO E PERFIL DO PROFISSIONAL =================
            FutureBuilder<Map<String, dynamic>?>(
              future: _buscarDadosProfissional(),
              builder: (context, snapshot) {
                final nomeCompleto = snapshot.data?['nome'] as String? ?? 'Caneta Azul';
                final fotoUrl = snapshot.data?['foto_perfil_url'] as String?;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto de perfil
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFFE1F5FE),
                      backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                      child: fotoUrl == null
                          ? Text(
                              nomeCompleto.isNotEmpty ? nomeCompleto[0].toUpperCase() : 'P',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0FB3FF),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    // Informações
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                nomeCompleto,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0FB3FF).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF0FB3FF).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 14, color: Color(0xFF0FB3FF)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Perfil Verificado',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0FB3FF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          FutureBuilder<String?>(
                            future: _buscarEndereco(),
                            builder: (context, enderecoSnapshot) {
                              String enderecoTexto = enderecoSnapshot.data ?? "Rua Capitão Pacheco e Chaves, 313 - Mooca, São Paulo - SP";
                              return Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      enderecoTexto,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildTag('Chaveiro', const Color(0xFF023BF6), 0.26),
                              const SizedBox(width: 8),
                              _buildTag('#CAEDS', const Color(0xFF40BAEC), 0.40),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Ícone de notificação
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: Colors.black54, size: 26),
                          onPressed: () {},
                        ),
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0FB3FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '2',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // ================= RADAR GEOGRÁFICO =================
            const Text(
              'Radar Geográfico',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F9FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1F5FE)),
              ),
              child: Stack(
                children: [
                  // Simulação de mapa
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Raio de cobertura circular
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0FB3FF).withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0FB3FF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wifi_tethering,
                              color: const Color(0xFF0FB3FF),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Radar Geográfico',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0FB3FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF0FB3FF)),
                SizedBox(width: 6),
                Text(
                  'Há 1 solicitação de pedido na sua área',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0FB3FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ================= ESTATÍSTICAS DOS SERVIÇOS =================
            Row(
              children: [
                Expanded(child: _buildStatCard('Pendentes', '1', const Color(0xFFFFA726))),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard('Ativos', '1', const Color(0xFF0FB3FF))),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard('Concluídos', '1', const Color(0xFF66BB6A))),
                const SizedBox(width: 10),
                Expanded(child: _buildStatCard('Cancelados', '0', const Color(0xFFEF5350))),
              ],
            ),
            const SizedBox(height: 20),

            // ================= AGENDA DA SEMANA =================
            const Text(
              'Agenda da Semana',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            _buildWeekCalendar(),
            const SizedBox(height: 24),

            // ================= GRADE DE RECURSOS / OPÇÕES RÁPIDAS =================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildQuickOption(Icons.bar_chart, 'Estatísticas\nFinanceiras')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickOption(Icons.description_outlined, 'Histórico de\nServiços')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickOption(Icons.folder_outlined, 'Meus\nServiços')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildQuickOption(Icons.shopping_cart_outlined, 'Método de\nEntrega')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickOption(Icons.verified_outlined, 'Plano de\nVerificado')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildQuickOption(Icons.add, 'Mais\nOpções')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      // ================= BARRA DE NAVEGAÇÃO INFERIOR =================
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0FB3FF),
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 4) {
              _exibirDialogSair(context);
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Radar'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensagens'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Pedidos'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color, double opacity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color.withValues(alpha: 1.0),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar() {
    final semana = [
      {'dia': 'Dom', 'numero': '2', 'evento': false, 'hoje': false, 'agendado': false},
      {'dia': 'Seg', 'numero': '3', 'evento': false, 'hoje': true, 'agendado': false},
      {'dia': 'Ter', 'numero': '5', 'evento': false, 'hoje': false, 'agendado': true},
      {'dia': 'Qua', 'numero': '6', 'evento': false, 'hoje': false, 'agendado': false},
      {'dia': 'Qui', 'numero': '7', 'evento': false, 'hoje': false, 'agendado': false},
      {'dia': 'Sex', 'numero': '8', 'evento': false, 'hoje': false, 'agendado': false},
      {'dia': 'Sáb', 'numero': '9', 'evento': false, 'hoje': false, 'agendado': false},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: semana.map((item) {
          final isHoje = item['hoje'] as bool;
          final isAgendado = item['agendado'] as bool;
          final diaNumero = item['numero'] as String;
          final diaNome = item['dia'] as String;

          return Container(
            width: 70,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: isAgendado ? const Color(0xFF0FB3FF) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHoje
                    ? const Color(0xFF0FB3FF)
                    : (isAgendado ? Colors.transparent : Colors.grey.shade200),
                width: isHoje ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  diaNome,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isAgendado ? Colors.white70 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  diaNumero,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isAgendado ? Colors.white : Colors.black87,
                  ),
                ),
                if (isHoje)
                  Text(
                    'Hoje',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isAgendado ? Colors.white : const Color(0xFF0FB3FF),
                    ),
                  ),
                if (isAgendado)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Cons. cabo\nPanela',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w500,
                        color: isAgendado ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickOption(IconData icon, String label) {
    return GestureDetector(
      onTap: () {},
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF0FB3FF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0FB3FF),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}