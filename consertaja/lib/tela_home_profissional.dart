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
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _titleDark = Color(0xFF1A2B4A);

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

      // 1. Busca o id do usuário
      final usuarioResponse = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (usuarioResponse == null) return null;
      final usuarioId = usuarioResponse['id_usuario'];

      // 2. Busca a associação do usuário com endereço (ativo primeiro)
      final assResponse = await supabase
          .from('ass_usuario_endereco')
          .select('fk_endereco, endereco_ativo')
          .eq('fk_usuario', usuarioId)
          .order('endereco_ativo', ascending: false)
          .limit(1)
          .maybeSingle();
      if (assResponse == null) return null;
      final fkEndereco = assResponse['fk_endereco'];

      // 3. Busca o endereço
      final enderecoResponse = await supabase
          .from('enderecos')
          .select('logradouro, numero, bairro, fk_cidade')
          .eq('id_endereco', fkEndereco)
          .maybeSingle();
      if (enderecoResponse == null) return null;

      final logradouro = enderecoResponse['logradouro']?.toString() ?? '';
      final numero = enderecoResponse['numero']?.toString() ?? '';
      final bairro = enderecoResponse['bairro']?.toString() ?? '';
      final fkCidade = enderecoResponse['fk_cidade'];
      if (logradouro.isEmpty) return null;

      // 4. Busca a cidade
      String cidade = '';
      String estado = '';
      if (fkCidade != null) {
        final cidadeResponse = await supabase
            .from('cidades')
            .select('nome_cidade, fk_estado')
            .eq('id_cidade', fkCidade)
            .maybeSingle();
        if (cidadeResponse != null) {
          cidade = cidadeResponse['nome_cidade']?.toString() ?? '';
          final fkEstado = cidadeResponse['fk_estado'];
          if (fkEstado != null) {
            final estadoResponse = await supabase
                .from('estados')
                .select('sigla_estado')
                .eq('id_estado', fkEstado)
                .maybeSingle();
            if (estadoResponse != null) {
              estado = estadoResponse['sigla_estado']?.toString() ?? '';
            }
          }
        }
      }

      final partes = <String>[
        if (logradouro.isNotEmpty) logradouro,
        if (numero.isNotEmpty) numero,
        if (bairro.isNotEmpty) bairro,
        if (cidade.isNotEmpty) cidade,
        if (estado.isNotEmpty) estado,
      ];

      return partes.join(', ');
    } catch (e) {
      return null;
    }
  }

  Future<List<String>?> _buscarOficios() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      // 1. Busca o id do usuário
      final usuarioResponse = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (usuarioResponse == null) return null;
      final usuarioId = usuarioResponse['id_usuario'];

      // 2. Busca dados profissionais para obter o id_profissional
      final dadosProf = await supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();
      if (dadosProf == null) return null;

      final idProfissional = dadosProf['id_profissional'];

      // 3. Busca os ofícios associados ao profissional
      final assOficios = await supabase
          .from('ass_oficio_profissional')
          .select('fk_oficio')
          .eq('fk_profissional', idProfissional);

      final idsOficios = assOficios
          .map((e) => e['fk_oficio'])
          .whereType<int>()
          .toList();

      // 4. Busca os nomes dos ofícios
      final oficios = <String>[];
      for (final id in idsOficios) {
        final oficioResponse = await supabase
            .from('oficios')
            .select('funcao')
            .eq('id_oficio', id)
            .maybeSingle();
        if (oficioResponse != null) {
          final funcao = oficioResponse['funcao']?.toString() ?? '';
          if (funcao.isNotEmpty) oficios.add(funcao);
        }
      }

      return oficios;
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ================= CARTÃO DE PERFIL =================
            FutureBuilder<Map<String, dynamic>?>(
              future: _buscarDadosProfissional(),
              builder: (context, snapshot) {
                final nomeCompleto =
                    snapshot.data?['nome'] as String? ?? 'Caneta Azul';
                final fotoUrl = snapshot.data?['foto_perfil_url'] as String?;

                return FutureBuilder<String?>(
                  future: _buscarEndereco(),
                  builder: (context, enderecoSnapshot) {
                    final enderecoTexto = enderecoSnapshot.data ??
                        'Nenhum endereço cadastrado';

                    return FutureBuilder<List<String>?>(
                      future: _buscarOficios(),
                      builder: (context, oficiosSnapshot) {
                        final oficios = oficiosSnapshot.data ?? <String>[];

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: _cardDecoration(),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomCenter,
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 34,
                                        backgroundColor:
                                            const Color(0xFFE1F5FE),
                                        backgroundImage: fotoUrl != null
                                            ? NetworkImage(fotoUrl)
                                            : null,
                                        child: fotoUrl == null
                                            ? Text(
                                                nomeCompleto.isNotEmpty
                                                    ? nomeCompleto[0]
                                                        .toUpperCase()
                                                    : 'P',
                                                style: const TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.bold,
                                                  color: _primaryBlue,
                                                ),
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: -6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _primaryBlue,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check,
                                                size: 9,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 2),
                                              Text(
                                                'Verificado',
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
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nomeCompleto,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: _titleDark,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          enderecoTexto,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.notifications_none_outlined,
                                          color: _primaryBlue,
                                          size: 26,
                                        ),
                                        onPressed: () {},
                                      ),
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            color: _primaryBlue,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Text(
                                            '2',
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
                                ],
                              ),
                              if (oficios.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.end,
                                  children: oficios.map(
                                    (oficio) => _buildTag(
                                      oficio,
                                      const Color(0xFF7B5EA7),
                                      const Color(0xFFEDE7F6),
                                    ),
                                  ).toList(),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),

            // ================= RADAR GEOGRÁFICO =================
            const Row(
              children: [
                Text(
                  'Radar Geográfico',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _titleDark,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.sensors, color: _primaryBlue, size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E7EF)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(double.infinity, 120),
                      painter: _MapPatternPainter(),
                    ),
                    Positioned(
                      left: 110,
                      top: -20,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primaryBlue.withValues(alpha: 0.12),
                          border: Border.all(
                            color: _primaryBlue.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 200,
                      top: 58,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primaryBlue,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryBlue.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: _titleDark,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  TextSpan(text: 'Há '),
                  TextSpan(
                    text: '1',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' solicitação de pedido na sua área'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= ESTATÍSTICAS + AGENDA (cartão único) =================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estatísticas dos Serviços',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _titleDark,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 20),
                  const Text(
                    'Agenda da semana',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _titleDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildWeekCalendar(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= ATALHOS / PAINEL DE AÇÕES =================
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildQuickOption(
                          Icons.bar_chart,
                          'Estatísticas\nFinanceiras',
                        ),
                      ),
                      Expanded(
                        child: _buildQuickOption(
                          Icons.history,
                          'Histórico de\nServiços',
                        ),
                      ),
                      Expanded(
                        child: _buildQuickOption(
                          Icons.work_outline,
                          'Meus\nServiços',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildQuickOption(
                          Icons.local_shipping_outlined,
                          'Método de\nEntrega',
                        ),
                      ),
                      Expanded(
                        child: _buildQuickOption(
                          Icons.verified_outlined,
                          'Plano de\nVerificado',
                        ),
                      ),
                      Expanded(
                        child: _buildQuickOption(
                          Icons.add_circle_outline,
                          'Mais\nOpções',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: _primaryBlue,
          unselectedItemColor: Colors.grey,
          currentIndex: _currentIndex,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              label: 'Mensagens',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              label: 'Pedidos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _titleDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar() {
    const diasSemana = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
    final dias = [
      {'numero': '3', 'hoje': true, 'agendado': false, 'evento': 'Hoje'},
      {'numero': '4', 'hoje': false, 'agendado': false, 'evento': ''},
      {
        'numero': '5',
        'hoje': false,
        'agendado': true,
        'evento': 'Cons.\ncabo Panela',
      },
      {'numero': '6', 'hoje': false, 'agendado': false, 'evento': ''},
      {'numero': '7', 'hoje': false, 'agendado': false, 'evento': ''},
      {'numero': '8', 'hoje': false, 'agendado': false, 'evento': ''},
      {'numero': '9', 'hoje': false, 'agendado': false, 'evento': ''},
    ];

    return Column(
      children: [
        Row(
          children: diasSemana
              .map(
                (dia) => Expanded(
                  child: Text(
                    dia,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(dias.length, (index) {
            final item = dias[index];
            final isHoje = item['hoje'] as bool;
            final isAgendado = item['agendado'] as bool;
            final diaNumero = item['numero'] as String;
            final eventoTexto = item['evento'] as String;

            if (isAgendado) {
              return Expanded(
                child: Container(
                  height: 72,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                  decoration: BoxDecoration(
                    color: _primaryBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        diaNumero,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (eventoTexto.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          eventoTexto,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return Expanded(
              child: Container(
                height: 72,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isHoje ? _primaryBlue : Colors.grey.shade200,
                    width: isHoje ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      diaNumero,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isHoje ? _primaryBlue : _titleDark,
                      ),
                    ),
                    if (eventoTexto.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        eventoTexto,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: _primaryBlue,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildQuickOption(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _primaryBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: _titleDark,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFDDE3EA)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final blockPaint = Paint()
      ..color = const Color(0xFFE8EDF2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(20, 15, 60, 40),
      blockPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(100, 30, 80, 50),
      blockPaint,
    );

    canvas.drawRect(
      Rect.fromLTWH(200, 10, 70, 35),
      blockPaint,
    );

    canvas.drawLine(
      const Offset(0, 60),
      Offset(size.width, 60),
      roadPaint,
    );

    canvas.drawLine(
      const Offset(0, 90),
      Offset(size.width, 90),
      roadPaint,
    );

    canvas.drawLine(
      const Offset(80, 0),
      Offset(80, size.height),
      roadPaint,
    );

    canvas.drawLine(
      const Offset(180, 0),
      Offset(180, size.height),
      roadPaint,
    );

    canvas.drawLine(
      const Offset(260, 0),
      Offset(260, size.height),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
