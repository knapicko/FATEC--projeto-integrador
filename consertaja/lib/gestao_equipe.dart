import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'modificar_conta_profissional.dart';

class GestaoEquipePage extends StatefulWidget {
  const GestaoEquipePage({super.key});

  @override
  State<GestaoEquipePage> createState() => _GestaoEquipePageState();
}

class _MembroEquipe {
  final String id;
  final String nome;
  final String cargo;
  final String tagFuncao;
  final Color corTagBg;
  final Color corTagTexto;
  final bool isOnline;
  final bool isPendente;
  final String? fotoUrl;
  final String? iniciais;

  _MembroEquipe({
    required this.id,
    required this.nome,
    required this.cargo,
    required this.tagFuncao,
    required this.corTagBg,
    required this.corTagTexto,
    this.isOnline = false,
    this.isPendente = false,
    this.fotoUrl,
    this.iniciais,
  });
}

class _GestaoEquipePageState extends State<GestaoEquipePage> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _bgLight = Color(0xFFF8FAFC);
  static const Color _titleDark = Color(0xFF1E293B);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _cardBorder = Color(0xFFE2E8F0);

  final TextEditingController _emailController = TextEditingController();
  String _nomeEmpresa = 'ConsertaJá Serviços Ltda.';

  late List<_MembroEquipe> _membros;

  @override
  void initState() {
    super.initState();
    _carregarNomeEmpresa();
    _membros = [
      _MembroEquipe(
        id: '1',
        nome: 'Carlos Eduardo',
        cargo: 'Gerente Geral',
        tagFuncao: 'Proprietário',
        corTagBg: const Color(0xFFF1F5F9),
        corTagTexto: const Color(0xFF64748B),
        isOnline: true,
        isPendente: false,
        fotoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&auto=format&fit=crop&q=80',
        iniciais: 'CE',
      ),
      _MembroEquipe(
        id: '2',
        nome: 'Ana Souza',
        cargo: 'Eletricista Sênior',
        tagFuncao: 'Funcionário',
        corTagBg: const Color(0xFFEFF6FF),
        corTagTexto: const Color(0xFF0284C7),
        isOnline: true,
        isPendente: false,
        fotoUrl: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150&auto=format&fit=crop&q=80',
        iniciais: 'AS',
      ),
      _MembroEquipe(
        id: '3',
        nome: 'Roberto Martins',
        cargo: 'Encanador',
        tagFuncao: 'Convite Pendente',
        corTagBg: const Color(0xFFF1F5F9),
        corTagTexto: const Color(0xFF64748B),
        isOnline: false,
        isPendente: true,
        iniciais: 'RM',
      ),
    ];
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _carregarNomeEmpresa() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final usuario = await supabase
          .from('usuarios')
          .select('nome, id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (usuario != null) {
        final idUsuario = usuario['id_usuario'];
        final dadosProf = await supabase
            .from('dados_profissionais')
            .select('fk_perfil')
            .eq('fk_usuario', idUsuario)
            .maybeSingle();

        final fkPerfil = dadosProf?['fk_perfil'];
        if (fkPerfil != null) {
          final perfil = await supabase
              .from('perfil')
              .select('descricao_perfil')
              .eq('id_perfil', fkPerfil)
              .maybeSingle();

          final desc = perfil?['descricao_perfil']?.toString();
          if (desc != null && desc.trim().isNotEmpty && mounted) {
            setState(() {
              _nomeEmpresa = desc.trim();
            });
          }
        }
      }
    } catch (_) {}
  }

  void _convidarFuncionario() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe um e-mail válido.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final partes = email.split('@').first.split('.');
    String nomeFormatado = partes.map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join(' ');
    if (nomeFormatado.isEmpty) nomeFormatado = 'Novo Colaborador';

    final iniciais = nomeFormatado.length >= 2
        ? nomeFormatado.substring(0, 2).toUpperCase()
        : nomeFormatado.toUpperCase();

    setState(() {
      _membros.add(
        _MembroEquipe(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          nome: nomeFormatado,
          cargo: 'Colaborador',
          tagFuncao: 'Convite Pendente',
          corTagBg: const Color(0xFFF1F5F9),
          corTagTexto: const Color(0xFF64748B),
          isOnline: false,
          isPendente: true,
          iniciais: iniciais,
        ),
      );
      _emailController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Convite enviado com sucesso para $email!'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copiarLink() {
    Clipboard.setData(
      const ClipboardData(text: 'https://consertaja.app/convite-equipe/c39a2f'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link de convite copiado para a área de transferência!'),
        backgroundColor: _primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removerMembro(String id, String nome) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover Membro'),
        content: Text('Tem certeza que deseja remover $nome da equipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: _textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _membros.removeWhere((m) => m.id == id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$nome foi removido da equipe.'),
                  backgroundColor: _titleDark,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  void _reenviarConvite(String nome) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Convite reenviado para $nome.'),
        backgroundColor: _primaryBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _bgLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Gestão de Equipe',
          style: TextStyle(
            color: _primaryBlue,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: _primaryBlue),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ModificarContaProfissionalPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= SEÇÃO PERFIL EMPRESARIAL =================
            const Text(
              'Perfil Empresarial',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.015),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.apartment_rounded,
                    color: _textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _nomeEmpresa,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _titleDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ModificarContaProfissionalPage(),
                        ),
                      );
                      _carregarNomeEmpresa();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Editar',
                        style: TextStyle(
                          color: _primaryBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ================= CARD NOVO MEMBRO =================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_alt_1,
                          color: _titleDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Novo Membro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _titleDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Expanda sua equipe enviando um convite direto.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF475569),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'E-mail do colaborador',
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      onSubmitted: (_) => _convidarFuncionario(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _convidarFuncionario,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Convidar Funcionário',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text(
                        'Compartilhe o acesso',
                        style: TextStyle(
                          fontSize: 14,
                          color: _textMuted,
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _copiarLink,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.link, color: _primaryBlue, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Copiar Link',
                                  style: TextStyle(
                                    color: _primaryBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ================= SEÇÃO EQUIPE ATUAL =================
            Row(
              children: [
                const Text(
                  'Equipe Atual',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _titleDark,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${_membros.length} Membros',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Lista de Cards dos Membros
            ..._membros.map((membro) => _buildMembroCard(membro)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMembroCard(_MembroEquipe membro) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          _buildAvatar(membro),
          const SizedBox(width: 14),

          // Informações do membro
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  membro.nome,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _titleDark,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  membro.cargo,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: membro.corTagBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    membro.tagFuncao,
                    style: TextStyle(
                      fontSize: 11,
                      color: membro.corTagTexto,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Ações à direita
          _buildAcoesMembro(membro),
        ],
      ),
    );
  }

  Widget _buildAvatar(_MembroEquipe membro) {
    if (membro.isPendente) {
      return CustomPaint(
        painter: _DashedCirclePainter(
          color: const Color(0xFFCBD5E1),
          strokeWidth: 1.5,
        ),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Text(
              membro.iniciais ?? 'RM',
              style: const TextStyle(
                color: _textMuted,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox(
            width: 48,
            height: 48,
            child: membro.fotoUrl != null
                ? Image.network(
                    membro.fotoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: Center(
                        child: Text(
                          membro.iniciais ?? 'U',
                          style: const TextStyle(
                            color: _textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFFF1F5F9),
                    child: Center(
                      child: Text(
                        membro.iniciais ?? 'U',
                        style: const TextStyle(
                          color: _textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (membro.isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAcoesMembro(_MembroEquipe membro) {
    if (membro.isPendente) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.forward_to_inbox_rounded,
              color: _textMuted,
              size: 20,
            ),
            tooltip: 'Reenviar convite',
            splashRadius: 20,
            onPressed: () => _reenviarConvite(membro.nome),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: _textMuted,
              size: 20,
            ),
            tooltip: 'Cancelar convite',
            splashRadius: 20,
            onPressed: () => _removerMembro(membro.id, membro.nome),
          ),
        ],
      );
    }

    if (membro.tagFuncao == 'Proprietário') {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (value) {
          if (value == 'editar') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ModificarContaProfissionalPage(),
              ),
            );
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'editar',
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18, color: _textMuted),
                SizedBox(width: 8),
                Text('Editar Perfil'),
              ],
            ),
          ),
        ],
      );
    }

    return IconButton(
      icon: const Icon(
        Icons.delete_outline_rounded,
        color: _textMuted,
        size: 22,
      ),
      tooltip: 'Remover funcionário',
      splashRadius: 20,
      onPressed: () => _removerMembro(membro.id, membro.nome),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double dashGap;

  _DashedCirclePainter({
    this.color = const Color(0xFF94A3B8),
    this.strokeWidth = 1.5,
    this.dashLength = 4,
    this.dashGap = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final circumference = 2 * math.pi * radius;
    final totalDashLength = dashLength + dashGap;
    final count = (circumference / totalDashLength).floor();
    final angleStep = (2 * math.pi) / count;
    final dashAngle = (dashLength / circumference) * (2 * math.pi);

    for (int i = 0; i < count; i++) {
      final startAngle = i * angleStep;
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(radius, radius),
          radius: radius - strokeWidth / 2,
        ),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
