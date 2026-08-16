import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tela_meu_perfil_profissional.dart';

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

  PageRouteBuilder _rotaSemAnimacao(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, _, _) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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

                return FutureBuilder<String?>(
                  future: _buscarEndereco(),
                  builder: (context, enderecoSnapshot) {
                    String enderecoTexto = enderecoSnapshot.data ??
                        "Rua Capitão Pacheco e Chaves, 313 - Mooca, São Paulo - SP";

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Foto de perfil com Selo Verificado Sobreposto abaixo
                        Stack(
                          alignment: Alignment.bottomCenter,
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: const Color(0xFFE1F5FE),
                              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                              child: fotoUrl == null
                                  ? Text(
                                      nomeCompleto.isNotEmpty ? nomeCompleto[0].toUpperCase() : 'P',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0FB3FF),
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: -6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0FB3FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle, size: 10, color: Colors.white),
                                    SizedBox(width: 2),
                                    Text(
                                      'Perfil Verificado',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        // Informações Textuais (Nome, Endereço, Tags)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nomeCompleto,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                enderecoTexto,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _buildTag('Chaveiro', const Color(0xFF023BF6)),
                                  const SizedBox(width: 6),
                                  _buildTag('#CAEDS', const Color(0xFF40BAEC)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Ícone de notificação com Badge
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF0FB3FF), size: 28),
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
                );
              },
            ),
            const SizedBox(height: 24),

            // ================= RADAR GEOGRÁFICO =================
            const Row(
              children: [
                Text(
                  'Radar Geográfico',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0FB3FF),
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.sensors, color: Color(0xFF0FB3FF), size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFB3E5FC).withValues(alpha: 0.5)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    // Círculo translúcido simulando o raio do radar
                    Positioned(
                      left: 100,
                      top: -25,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0FB3FF).withValues(alpha: 0.15),
                          border: Border.all(
                            color: const Color(0xFF0FB3FF).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    // Ponto indicador azul do radar
                    Positioned(
                      left: 210,
                      top: 65,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0FB3FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Há 1 solicitação de pedido na sua área',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF0FB3FF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),

            // ================= ESTATÍSTICAS DOS SERVIÇOS =================
            const Text(
              'Estatísticas dos Serviços',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildStatCard('Pendentes', '1')),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('Ativos', '1')),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('Concluídos', '1')),
                const SizedBox(width: 8),
                Expanded(child: _buildStatCard('Cancelados', '0')),
              ],
            ),
            const SizedBox(height: 24),

            // ================= AGENDA DA SEMANA =================
            const Text(
              'Agenda da Semana',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            _buildWeekCalendar(),
            const SizedBox(height: 24),

            // ================= GRADE DE RECURSOS / OPÇÕES RÁPIDAS =================
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildQuickOption(Icons.bar_chart, 'Estatísticas\nFinanceiras')),
                      Expanded(child: _buildQuickOption(Icons.description_outlined, 'Histórico de\nServiços')),
                      Expanded(child: _buildQuickOption(Icons.folder_outlined, 'Meus\nServiços')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildQuickOption(Icons.shopping_cart_outlined, 'Método de\nEntrega')),
                      Expanded(child: _buildQuickOption(Icons.verified_outlined, 'Plano de\nVerificado')),
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
              blurRadius: 8,
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
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          onTap: (index) {
            if (index == 4) {
              Navigator.of(context).pushReplacement(
                _rotaSemAnimacao(
                  TelaMeuPerfilProfissionalPage(
                    isVisitante: widget.isVisitante,
                  ),
                ),
              );
              return;
            }
            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.sensors), label: 'Radar'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensagens'),
            BottomNavigationBarItem(icon: Icon(Icons.archive_outlined), label: 'Pedidos'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar() {
    final semana = [
      {'dia': 'DOMINGO', 'numero': '3', 'hoje': true, 'agendado': false, 'evento': 'Hoje'},
      {'dia': 'SEGUNDA', 'numero': '4', 'hoje': false, 'agendado': false, 'evento': ''},
      {'dia': 'TERÇA', 'numero': '5', 'hoje': false, 'agendado': true, 'evento': 'Cons.\ncabo Panela'},
      {'dia': 'QUARTA', 'numero': '6', 'hoje': false, 'agendado': false, 'evento': ''},
      {'dia': 'QUINTA', 'numero': '7', 'hoje': false, 'agendado': false, 'evento': ''},
      {'dia': 'SEXTA', 'numero': '8', 'hoje': false, 'agendado': false, 'evento': ''},
      {'dia': 'SÁBADO', 'numero': '9', 'hoje': false, 'agendado': false, 'evento': ''},
    ];

    return Row(
      children: semana.map((item) {
        final isHoje = item['hoje'] as bool;
        final isAgendado = item['agendado'] as bool;
        final diaNumero = item['numero'] as String;
        final diaNome = item['dia'] as String;
        final eventoTexto = item['evento'] as String;

        Color backgroundColor = Colors.white;
        Color borderColor = Colors.grey.shade200;
        Color labelColor = const Color(0xFF0FB3FF);
        Color numeroColor = Colors.grey.shade700;

        if (isHoje) {
          borderColor = const Color(0xFF0FB3FF);
          numeroColor = const Color(0xFF0FB3FF);
        } else if (isAgendado) {
          backgroundColor = const Color(0xFF0FB3FF);
          borderColor = const Color(0xFF0FB3FF);
          labelColor = Colors.white;
          numeroColor = Colors.white;
        }

        return Expanded(
          child: Container(
            height: 76,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: borderColor, width: isHoje ? 1.5 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  diaNome,
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  diaNumero,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: numeroColor,
                  ),
                ),
                if (eventoTexto.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 1, right: 1),
                    child: Text(
                      eventoTexto,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 6.5,
                        fontWeight: FontWeight.w600,
                        color: isAgendado ? Colors.white : const Color(0xFF0FB3FF),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickOption(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFF0FB3FF),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}