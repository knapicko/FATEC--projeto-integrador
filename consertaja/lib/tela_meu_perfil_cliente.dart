import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tela_home.dart';

class TelaMeuPerfilClientePage extends StatefulWidget {
  const TelaMeuPerfilClientePage({super.key});

  @override
  State<TelaMeuPerfilClientePage> createState() =>
      _TelaMeuPerfilClientePageState();
}

class _TelaMeuPerfilClientePageState extends State<TelaMeuPerfilClientePage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _blueBorder = Color(0xFF048DF8);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _divider = Color(0xFFD9D9D9);
  static const Color _iconGray = Color(0xFF878B8D);
  static const Color _textGray = Color(0xFF7B7B7B);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _nomeCompleto = 'Carregando...';
  String? _fotoPerfilUrl;

  final double _avaliacao = 4.9;
  final int _totalAvaliacoes = 423;
  final int _seguindo = 0;
  final bool _perfilVerificado = true;

  final List<String> _avisosAtivos = [];

  @override
  void initState() {
    super.initState();
    _carregarDadosPerfil();
  }

  Future<void> _carregarDadosPerfil() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      Map<String, dynamic>? data;

      try {
        data = await _supabase
            .from('usuarios')
            .select()
            .eq('auth_id', user.id)
            .maybeSingle();
      } catch (_) {
        data = null;
      }

      data ??= await _supabase
          .from('usuarios')
          .select()
          .eq('auth_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _avisosAtivos.clear();

        _nomeCompleto =
            (data?['nome'] ?? user.userMetadata?['nome'] ?? 'Usuário')
                .toString();
        _fotoPerfilUrl = data?['foto_perfil_url']?.toString();

        final bool dadosFaltando =
            _campoVazio(data?['cpf']) ||
            _campoVazio(data?['telefone']) ||
            _campoVazio(data?['dataNascimento']) ||
            _campoVazio(data?['data_nascimento']) ||
            _campoVazio(data?['nome']) ||
            _campoVazio(data?['email']);

        if (dadosFaltando) _avisosAtivos.add('dados');
        if (user.emailConfirmedAt == null) _avisosAtivos.add('email');
        if (user.phoneConfirmedAt == null) _avisosAtivos.add('telefone');

        _avisosAtivos.shuffle();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _nomeCompleto = 'Erro ao carregar';
          _isLoading = false;
        });
      }
    }
  }

  bool _campoVazio(dynamic value) {
    if (value == null) return true;
    final text = value.toString().trim();
    return text.isEmpty || text.toLowerCase() == 'null';
  }

  String _obterIniciais(String? nome) {
    if (nome == null || nome.trim().isEmpty) {
      return 'U';
    }

    final partes = nome.trim().split(' ');

    if (partes.length > 1) {
      final sobrenome = partes.last.trim();

      if (sobrenome.length >= 2) {
        return sobrenome.substring(0, 2).toUpperCase();
      }

      return sobrenome.toUpperCase();
    }

    return nome.substring(0, 1).toUpperCase();
  }

  Widget _buildAvatar() {
    final initials = _obterIniciais(_nomeCompleto);

    final Widget avatar =
        _fotoPerfilUrl != null && _fotoPerfilUrl!.trim().isNotEmpty
        ? ClipOval(
            child: Image.network(
              _fotoPerfilUrl!,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildFallbackAvatar(initials),
            ),
          )
        : _buildFallbackAvatar(initials);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.20),
              width: 2,
            ),
          ),
          child: Center(child: avatar),
        ),

        Positioned(
          left: 29,
          bottom: -4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Fundo branco menor (só atrás do check)
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const Icon(Icons.verified, color: _blueBorder, size: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackAvatar(String initials) {
    return Container(
      width: 72,
      height: 72,
      decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  void _fecharAvisoAtual() {
    if (_avisosAtivos.isEmpty) return;
    setState(() {
      _avisosAtivos.removeAt(0);
    });
  }

  Widget _buildAvisoAtual() {
    if (_avisosAtivos.isEmpty) return const SizedBox.shrink();

    final tipo = _avisosAtivos.first;
    final icone = tipo == 'dados'
        ? Icons.edit_outlined
        : tipo == 'email'
        ? Icons.mark_email_unread_outlined
        : Icons.phone_outlined;

    final TextSpan message = tipo == 'dados'
        ? const TextSpan(
            text: 'Por favor, informe o restante das suas informações. ',
            children: [
              TextSpan(
                text: 'Defina agora',
                style: TextStyle(color: _blue, fontWeight: FontWeight.w500),
              ),
            ],
          )
        : tipo == 'email'
        ? const TextSpan(
            text:
                'Por favor, verifique o seu e-mail para concluir seu cadastro. ',
            children: [
              TextSpan(
                text: 'Verifique agora',
                style: TextStyle(color: _blue, fontWeight: FontWeight.w500),
              ),
            ],
          )
        : const TextSpan(
            text:
                'Por favor, verifique o seu telefone para concluir seu cadastro. ',
            children: [
              TextSpan(
                text: 'Verifique agora',
                style: TextStyle(color: _blue, fontWeight: FontWeight.w500),
              ),
            ],
          );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icone, color: _blue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              message,
              style: const TextStyle(
                color: Color(0xFF2F2F2F),
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _fecharAvisoAtual,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, color: Color(0xFF7E7E7E), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsTopo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(child: _buildRatingButton()),
          const SizedBox(width: 8),
          Expanded(child: _buildVerifiedButton()),
        ],
      ),
    );
  }

  Widget _buildRatingButton() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star_rounded, color: _blue, size: 18),
          const SizedBox(width: 4),
          const Text(
            '4.9',
            style: TextStyle(
              color: Color(0xFF1F1F1F),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '(423)',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedButton() {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _blueBorder, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.verified, color: _blueBorder, size: 18),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              'Perfil Verificado',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _blueBorder,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required String label,
    String? imageAsset,
    IconData? fallbackIcon,
    bool useRoundedIcon = false,
    VoidCallback? onTap,
  }) {
    Widget leading;

    if (imageAsset != null) {
      leading = Image.asset(
        imageAsset,
        width: 24,
        height: 24,
        color: _iconGray,
        errorBuilder: (_, __, ___) => Icon(
          fallbackIcon ?? Icons.chevron_right,
          color: _iconGray,
          size: useRoundedIcon ? 24 : 26,
        ),
      );
    } else if (fallbackIcon != null) {
      leading = Icon(
        fallbackIcon,
        color: _iconGray,
        size: useRoundedIcon ? 24 : 26,
      );
    } else {
      leading = const SizedBox(width: 24, height: 24);
    }

    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(width: 28, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _textGray,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      color: _blue,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _nomeCompleto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {},
                  child: const Text(
                    'Editar Informações >',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.0,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {},
                  child: Text(
                    'Seguindo : $_seguindo',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.0,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: _blue,
      unselectedItemColor: const Color(0xFF8F8F8F),
      currentIndex: 4, // Perfil selecionado
      onTap: (index) async {
        switch (index) {
          case 0:
            // Home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TelaHome(isVisitante: false),
              ),
            );
            break;

          case 4:
            // Perfil
            await _carregarDadosPerfil();

            if (mounted) {
              setState(() {});
            }
            break;
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _background,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildTopHeader(),
                  if (_avisosAtivos.isNotEmpty) _buildAvisoAtual(),
                  _buildChipsTopo(),
                  const SizedBox(height: 10),
                  const Divider(height: 1, thickness: 1, color: _divider),

                  _buildSectionTitle('Sua Atividade'),
                  _buildProfileItem(
                    label: 'Meus Endereços',
                    imageAsset: 'assets/images/Endereço_Cinza.png',
                    fallbackIcon: Icons.location_on_outlined,
                  ),
                  _buildProfileItem(
                    label: 'Histórico de Pedidos',
                    imageAsset: 'assets/images/CaixaPedido_Cinza.png',
                    fallbackIcon: Icons.inventory_2_outlined,
                  ),
                  _buildProfileItem(
                    label: 'Avaliações de Serviços',
                    fallbackIcon: Icons.star_rounded,
                    useRoundedIcon: true,
                  ),
                  _buildProfileItem(
                    label: 'Notificações',
                    fallbackIcon: Icons.notifications_none_rounded,
                  ),
                  _buildProfileItem(
                    label: 'Serviços Favoritados',
                    fallbackIcon: Icons.favorite_border_rounded,
                  ),

                  const Divider(height: 1, thickness: 1, color: _divider),

                  _buildSectionTitle('Suporte'),
                  _buildProfileItem(
                    label: 'Perguntas Frequentes',
                    fallbackIcon: Icons.help_outline_rounded,
                  ),
                  _buildProfileItem(
                    label: 'Fale Conosco',
                    imageAsset: 'assets/images/Suporte_Cinza.png',
                    fallbackIcon: Icons.support_agent_rounded,
                  ),
                  _buildProfileItem(
                    label: 'Sobre a ConsertaJá',
                    imageAsset: 'assets/images/ConsertaJa_Cinza.png',
                    fallbackIcon: Icons.info_outline_rounded,
                  ),

                  const Divider(height: 1, thickness: 1, color: _divider),

                  _buildProfileItem(
                    label: 'Configurações',
                    imageAsset: 'assets/images/Configuracoes_Cinza.png',
                    fallbackIcon: Icons.settings_outlined,
                  ),
                  _buildProfileItem(
                    label: 'Termos de Uso',
                    fallbackIcon: Icons.description_outlined,
                  ),
                  _buildProfileItem(
                    label: 'Política de Privacidade',
                    fallbackIcon: Icons.privacy_tip_outlined,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}
