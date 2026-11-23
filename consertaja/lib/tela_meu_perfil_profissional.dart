import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/skeleton_loading.dart';
import 'alterar_disponibilidade.dart';
import 'area_atuacao.dart';
import 'editar_informacoes.dart';
import 'meus_documentos.dart';
import 'meus_enderecos.dart';
import 'perguntas_frequentes.dart';
import 'termos_de_uso.dart';
import 'politica_de_privacidade.dart';
import 'sobre_conserta_ja.dart';
import 'meus_servicos_solicitados.dart';
import 'tela_home_profissional.dart';
import 'tela_mensagens.dart';
import 'tela_inicial.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'utils/iniciais.dart';
import 'utils/app_navigation_util.dart';
import 'solicitacao_geografica_profissional.dart';
import 'minhas_notificacoes.dart';
import 'widgets/contador_notificacoes.dart';
import 'services/requisitos_conta.dart';
import 'widgets/avisos_bottom_sheet.dart';
import 'certificados.dart';
import 'minhas_avaliacoes_profissional.dart';
import 'tela_configuracoes_cliente.dart';
import 'meu_historico_servico_profissional.dart';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';

class TelaMeuPerfilProfissionalPage extends StatefulWidget {
  final bool isVisitante;

  const TelaMeuPerfilProfissionalPage({super.key, this.isVisitante = false});

  @override
  State<TelaMeuPerfilProfissionalPage> createState() =>
      _TelaMeuPerfilProfissionalPageState();
}

class _TelaMeuPerfilProfissionalPageState
    extends State<TelaMeuPerfilProfissionalPage> {
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _blueBorder = Color(0xFF048DF8);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _divider = Color(0xFFD9D9D9);
  static const Color _iconGray = Color(0xFF878B8D);
  static const Color _textGray = Color(0xFF7B7B7B);

  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _nomeCompleto = 'Nome não encontrado';
  String _email = '';
  String? _fotoPerfilUrl;

  final List<String> _avisosAtivos = [];

  @override
  void initState() {
    super.initState();

    if (widget.isVisitante) {
      _isLoading = false;
      _nomeCompleto = 'Nome não encontrado';
      _email = '';
      _fotoPerfilUrl = null;
      return;
    }

    _carregarDadosPerfil();
  }

  Future<void> _carregarDadosPerfil() async {
    _atualizarPendencias();
    if (widget.isVisitante) return;

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

      // Pessoa física (CPF)? Só ela precisa de data de nascimento.
      var pessoaFisica = false;
      try {
        final idTipo = data?['fk_tipo_pessoa'];
        if (idTipo != null) {
          final ass = await _supabase
              .from('ass_tipo_pessoa')
              .select('fk_pessoa_fisica')
              .eq('id_tipo_pessoa', idTipo)
              .maybeSingle();
          pessoaFisica = ass?['fk_pessoa_fisica'] != null;
        }
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _avisosAtivos.clear();

        _nomeCompleto =
            (data?['nome'] ??
                    user.userMetadata?['nome'] ??
                    'Nome não encontrado')
                .toString();
        _email = (data?['email'] ?? user.email ?? '').toString();
        _fotoPerfilUrl = data?['foto_perfil_url']?.toString();

        // Colunas reais de usuarios (antes procurava "cpf", "telefone" e
        // "email", que não existem nessa tabela — o aviso nunca sumia).
        // Data de nascimento só é exigida de pessoa física.
        final bool dadosFaltando =
            _campoVazio(data?['nome']) ||
            data?['fk_email'] == null ||
            data?['fk_telefone'] == null ||
            data?['fk_tipo_pessoa'] == null ||
            (pessoaFisica && _campoVazio(data?['data_nascimento']));

        if (dadosFaltando) _avisosAtivos.add('dados');
        if (user.emailConfirmedAt == null &&
            (user.email ?? '').trim().isNotEmpty) {
          _avisosAtivos.add('email');
        }

        _avisosAtivos.shuffle();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _nomeCompleto = 'Nome não encontrado';
          _isLoading = false;
        });
      }
    }
  }

  /// Itens com aviso "!" (endereço, disponibilidade) — iguais aos da home.
  Set<String> _pendencias = {};

  Future<void> _atualizarPendencias() async {
    if (widget.isVisitante) return;
    final p = await RequisitosConta.pendenciasProfissional();
    if (mounted) setState(() => _pendencias = p);
  }

  bool _campoVazio(dynamic value) {
    if (value == null) return true;
    final text = value.toString().trim();
    return text.isEmpty || text.toLowerCase() == 'null';
  }

  void _abrirEditarInformacoes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditarInformacoesPage()),
    ).then((_) {
      if (!widget.isVisitante) {
        _carregarDadosPerfil();
      }
    });
  }

  Widget _buildAvatar() {
    final initials = obterIniciais(_nomeCompleto);

    final Widget avatar =
        _fotoPerfilUrl != null && _fotoPerfilUrl!.trim().isNotEmpty
        ? ClipOval(
            child: ImagemApp(child: Image.network(
              _fotoPerfilUrl!,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildFallbackAvatar(initials),
            )),
          )
        : _buildFallbackAvatar(initials);

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
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
      ],
    );
  }

  Widget _buildFallbackAvatar(String initials) {
    return CorOriginal(interface: true, child: Container(
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
    ));
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
        ? TextSpan(
            text: 'Por favor, informe o restante das suas informações. ',
            children: [
              TextSpan(
                text: 'Defina agora',
                style: const TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.w500,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = _abrirEditarInformacoes,
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
        border: Border.all(color: const Color(0xFFE0E0E0)),
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
    bool semIcone = false,
    VoidCallback? onTap,
    Widget? trailing,
    bool pendente = false,
  }) {
    if (semIcone) {
      return InkWell(
        onTap: onTap ?? () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            label,
            style: const TextStyle(
              color: _textGray,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }

    Widget leading;

    if (imageAsset != null) {
      leading = Image.asset(
        imageAsset,
        width: 24,
        height: 24,
        color: _iconGray,
        errorBuilder: (_, _, _) => Icon(
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
            if (trailing != null) ...[trailing, const SizedBox(width: 6)],
            if (pendente) ...[const SeloPendente(), const SizedBox(width: 6)],
            const Icon(Icons.chevron_right, color: Color(0xFFB0B0B0), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Stack(
      children: [
        CorOriginal(interface: true, child: Container(
          width: double.infinity,
          color: _blue,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
          child: Column(
            children: [
              _buildAvatar(),
              const SizedBox(height: 12),
              Text(
                _nomeCompleto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        )),
        Positioned(
          top: 4,
          right: 4,
          child: BotaoAjuda(
            cor: Colors.white,
            passos: () => explicacaoDaTela(
              context,
              tela: 'Este é o seu perfil de profissional.',
              conteudo: [
                'Aqui ficam os seus dados, avaliações, histórico, documentos, endereços e configurações.',
                'Os itens com ! amarelo são obrigatórios para oferecer serviços.',
              ],
              rodape: 56,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditarMeusDados() {
    return Column(
      children: [
        InkWell(
          onTap: _abrirEditarInformacoes,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: const [
                SizedBox(
                  width: 28,
                  child: Center(
                    child: Icon(
                      Icons.edit_outlined,
                      color: _iconGray,
                      size: 24,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Editar Meus Dados',
                    style: TextStyle(
                      color: _textGray,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: Color(0xFFB0B0B0), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sairDaConta() async {
    if (!await confirmarSairDaConta(context)) return;
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TelaInicial()),
      (route) => false,
    );
  }

  // (Removido: _irParaPerfilOuEmpresa não é mais usado.)

  Widget _buildBottomNav() {
    // Sem prop isContaEmpresa: a barra resolve sozinha pelo cache interno
    // (valor síncrono no primeiro frame, confirmação em background só com
    // setState se mudar) — sem piscar Perfil/Empresa na abertura.
    return BottomNavigationBarProfissional(
      key: const ValueKey('bottomProfissional'),
      currentIndex: 4,
      // Tocar em Perfil estando no Perfil recarrega os dados.
      onReselecionarAbaAtual: (_) async {
        await _carregarDadosPerfil();
        if (mounted) setState(() {});
      },
      onTap: (index) async {
        if (index == 0) {
          AppNavigationUtil.navegarAba(
            context,
            TelaHomeProfissional(isVisitante: widget.isVisitante),
            isHome: true,
          );
        } else if (index == 1) {
          Navigator.of(context).push(
            AppNavigationUtil.rotaSemAnimacao(
              SolicitacaoGeograficaProfissionalPage(
                isVisitante: widget.isVisitante,
              ),
              nome: 'SolicitacaoGeograficaProfissionalPage',
            ),
          );
        } else if (index == 2) {
          AppNavigationUtil.navegarAba(
            context,
            TelaMensagensPage(
              isVisitante: widget.isVisitante,
              isProfissional: true,
            ),
            isHome: false,
          );
        } else if (index == 3) {
          // Aba Serviços: abre os serviços solicitados (conta
          // independente ou empresa), igual às demais telas.
          Navigator.of(context).push(
            AppNavigationUtil.rotaSemAnimacao(
              const MeusServicosSolicitadosPage(),
              nome: 'MeusServicosSolicitadosPage',
            ),
          );
        } else if (index == 4 && !widget.isVisitante) {
          await _carregarDadosPerfil();
          if (mounted) setState(() {});
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackHandler(
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const SkeletonPage(layout: SkeletonLayout.profile)
                    : ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildTopHeader(),
                          if (!widget.isVisitante && _avisosAtivos.isNotEmpty)
                            _buildAvisoAtual(),
                          if (!widget.isVisitante) _buildEditarMeusDados(),
                          _buildSectionTitle('Sua Atividade'),
                          _buildProfileItem(
                            label: 'Meus Endereços',
                            pendente: _pendencias.contains(
                              RequisitosConta.enderecos,
                            ),
                            fallbackIcon: Icons.location_on_outlined,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MeusEnderecosPage(
                                    isVisitante: widget.isVisitante,
                                    isProfissional: true,
                                  ),
                                ),
                              ).then((_) => _atualizarPendencias());
                            },
                          ),
                          _buildProfileItem(
                            label: 'Histórico de Serviços',
                            fallbackIcon: Icons.inventory_2_outlined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const MeuHistoricoServicoProfissionalPage(),
                              ),
                            ),
                          ),
                          _buildProfileItem(
                            label: 'Minhas Avaliações',
                            fallbackIcon: Icons.star_rounded,
                            useRoundedIcon: true,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const MinhasAvaliacoesProfissionalPage(),
                              ),
                            ),
                          ),
                          _buildProfileItem(
                            label: 'Minha Área de Atuação',
                            fallbackIcon: Icons.work_outline,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AreaAtuacaoPage(),
                                ),
                              );
                            },
                          ),
                          _buildProfileItem(
                            label: 'Meus Documentos',
                            fallbackIcon: Icons.description_outlined,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MeusDocumentosPage(),
                                ),
                              );
                            },
                          ),
                          _buildProfileItem(
                            label: 'Ajustar Disponibilidade',
                            fallbackIcon: Icons.event_available_outlined,
                            pendente: _pendencias.contains(
                              RequisitosConta.disponibilidade,
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AlterarDisponibilidadePage(),
                                ),
                              );
                              _atualizarPendencias();
                            },
                          ),
                          _buildProfileItem(
                            label: 'Certificados',
                            fallbackIcon: Icons.workspace_premium_outlined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CertificadosPage(),
                              ),
                            ),
                          ),
                          _buildProfileItem(
                            label: 'Notificações',
                            fallbackIcon: Icons.notifications_none_rounded,
                            trailing: const ContadorNaoLidas(),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const MinhasNotificacoesPage(
                                        soDaContaProfissionalAtiva: true,
                                      ),
                                ),
                              );
                            },
                          ),

                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: _divider,
                          ),

                          _buildSectionTitle('Suporte'),
                          _buildProfileItem(
                            label: 'Perguntas Frequentes',
                            fallbackIcon: Icons.help_outline_rounded,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PerguntasFrequentesPage(),
                                ),
                              );
                            },
                          ),
                          _buildProfileItem(
                            label: 'Fale Conosco',
                            fallbackIcon: Icons.support_agent_rounded,
                          ),

                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: _divider,
                          ),

                          _buildProfileItem(
                            label: 'Sobre a ConsertaJá',
                            imageAsset:
                                'assets/images/icone/icone_consertaja.png',
                            fallbackIcon: Icons.info_outline_rounded,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SobreConsertaJaPage(),
                                ),
                              );
                            },
                          ),
                          _buildProfileItem(
                            label: 'Configurações',
                            fallbackIcon: Icons.settings_outlined,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TelaConfiguracoesClientePage(),
                              ),
                            ),
                          ),
                          _buildProfileItem(
                            label: 'Termos de Uso',
                            semIcone: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TermosDeUsoPage(),
                                ),
                              );
                            },
                          ),
                          _buildProfileItem(
                            label: 'Política de Privacidade',
                            semIcone: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PoliticaDePrivacidadePage(),
                                ),
                              );
                            },
                          ),

                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: _divider,
                          ),

                          InkWell(
                            onTap: _sairDaConta,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 28,
                                    child: Center(
                                      child: Icon(
                                        Icons.logout,
                                        color: Colors.red,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Sair da conta',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }
}
