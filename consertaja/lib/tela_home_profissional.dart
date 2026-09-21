import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alterar_disponibilidade.dart';
import 'area_atuacao.dart';
import 'editar_informacoes.dart';
import 'empresa_associada.dart';
import 'gestao_equipe.dart';
import 'meus_enderecos.dart';
import 'modificar_conta_profissional.dart';
import 'metodo_entrega_profissional.dart';
import 'meus_servicos_profissional.dart';
import 'meus_servicos_solicitados.dart';
import 'minhas_postagens_profissional.dart';
import 'models/postagem_resumo.dart';
import 'services/postagens_profissional_service.dart';
import 'services/completar_cadastro_equipe.dart';
import 'tela_meu_perfil_profissional.dart';
import 'tela_mensagens.dart';
import 'utils/cor_oficio.dart';
import 'utils/bottom_navigation_bar_profissional.dart';
import 'utils/iniciais.dart';
import 'widgets/tag_oficio.dart';
import 'utils/app_navigation_util.dart';

class TelaHomeProfissional extends StatefulWidget {
  final bool isVisitante;
  const TelaHomeProfissional({super.key, required this.isVisitante});

  @override
  State<TelaHomeProfissional> createState() => _TelaHomeProfissionalState();
}

/// Representa um dia da semana no calendário da agenda, com o estado de
/// disponibilidade e a exceção (se houver).
class _DiaAgendaCalendario {
  const _DiaAgendaCalendario({
    required this.data,
    required this.disponivel,
    this.observacaoExcecao,
    this.horaInicioExcecao,
    this.horaFimExcecao,
  });

  final DateTime data;
  final bool disponivel;

  /// Preenchido quando existe exceção (grade_horario_excecao).
  final String? observacaoExcecao;
  final TimeOfDay? horaInicioExcecao;
  final TimeOfDay? horaFimExcecao;

  bool get isExcecao =>
      observacaoExcecao != null ||
      horaInicioExcecao != null ||
      horaFimExcecao != null;

  /// Exceção parcial: quando hora_ini e hora_fim estão preenchidos.
  bool get isExcecaoParcial =>
      horaInicioExcecao != null && horaFimExcecao != null;

  bool get isHoje {
    final agora = DateTime.now();
    return data.year == agora.year &&
        data.month == agora.month &&
        data.day == agora.day;
  }
}

class _OficiosPerfil {
  const _OficiosPerfil({
    this.tagEmpresa,
    this.corTagEmpresa,
    required this.oficios,
  });

  final String? tagEmpresa;
  final String? corTagEmpresa;
  final List<OficioInfo> oficios;
}

class _TelaHomeProfissionalState extends State<TelaHomeProfissional> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _titleDark = Color(0xFF1A2B4A);
  static const Color _inputGray = Color(0xFFF0F2F5);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _vermelhoExcecao = Color(0xFFCE4257);

  static const List<String> _nomesDiasSemana = [
    'Domingo',
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
  ];

  static const List<String> _nomesDiasMinusculo = [
    'domingo',
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
  ];

  static const List<String> _mesesExtenso = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  int _currentIndex = 0;

  final TextEditingController _postagemController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Futures cacheados para evitar recarregamento ao rolar a tela
  late Future<Map<String, dynamic>?> _dadosProfissionalFuture;
  late Future<String?> _enderecoFuture;
  late Future<_OficiosPerfil?> _oficiosFuture;
  late Future<String?> _tipoPerfilFuture;
  late Future<List<PostagemResumo>> _postagensFuture;
  late Future<List<_DiaAgendaCalendario>> _agendaSemanaFuture;
  late Future<List<Map<String, dynamic>>> _convitesEmpresaFuture;

  // Estado da criação de postagem
  List<XFile> _imagensSelecionadas = [];
  bool _enviandoPostagem = false;

  // Estado da conta ativa (false = Profissional CNPJ, true = Empresa / grupo_empresa)
  bool _contaEmpresaAtiva = false;
  static const String _prefContaAtivaKey = 'consertaja_conta_empresa_ativa';

  // Cache das infos das 2 contas (profissional x empresa) para abrir o
  // bottom sheet de troca instantaneamente, sem tela de carregamento.
  Map<String, dynamic>? _cacheInfosContas;

  @override
  void initState() {
    super.initState();
    _carregarPreferenciaContaAtiva();
    _inicializarFutures();
    // Pré-carrega as infos das contas em 2º plano para a troca abrir na hora.
    _precarregarInfosContas();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mostrarCompletamentoEquipeSeNecessario();
    });
  }

  Future<void> _carregarPreferenciaContaAtiva() async {
    // Aquece o cache da bottom bar para o primeiro frame não piscar.
    unawaited(BottomNavigationBarProfissional.precarregarContaEmpresa());
    try {
      final prefs = await SharedPreferences.getInstance();
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final key = '${_prefContaAtivaKey}_${user.id}';
      final ativa = prefs.getBool(key) ?? false;
      if (mounted && ativa != _contaEmpresaAtiva) {
        setState(() {
          _contaEmpresaAtiva = ativa;
          _inicializarFutures();
        });
      }
    } catch (_) {}
  }

  Future<void> _salvarPreferenciaContaAtiva(bool isEmpresa) async {
    // Atualiza o cache da bottom bar na hora (evita "piscar" o Perfil).
    BottomNavigationBarProfissional.notificarTrocaConta(isEmpresa);
    try {
      final prefs = await SharedPreferences.getInstance();
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final key = '${_prefContaAtivaKey}_${user.id}';
      await prefs.setBool(key, isEmpresa);
    } catch (_) {}
  }

  Future<void> _mostrarCompletamentoEquipeSeNecessario() async {
    if (widget.isVisitante || !mounted) return;
    final deveCompletar = await CompletarCadastroEquipeDialog.deveCompletar();
    if (!deveCompletar || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isDismissible: false,
      builder: (_) => const CompletarCadastroEquipeDialog(),
    );
  }

  void _inicializarFutures() {
    _dadosProfissionalFuture = _buscarDadosProfissional();
    _enderecoFuture = _buscarEndereco();
    _oficiosFuture = _buscarOficios();
    _tipoPerfilFuture = _buscarTipoPerfil();
    _postagensFuture = _carregarPostagens();
    _agendaSemanaFuture = _carregarAgendaSemana();
    _convitesEmpresaFuture = _buscarConvitesEmpresa();
    // Mantém o cache da troca de contas atualizado em 2º plano.
    _precarregarInfosContas();
  }

  /// Recarrega a página atual (usado ao tocar na aba ativa da bottom bar).
  void _recarregarPaginaAtual() {
    if (!mounted) return;
    setState(() {
      _currentIndex = 0;
      _inicializarFutures();
    });
  }

  /// Pré-carrega (sem setState) as infos do bottom sheet de troca,
  /// para que ele abra instantaneamente sem spinner.
  Future<void> _precarregarInfosContas() async {
    try {
      final infos = await _carregarInformacoesContas();
      _cacheInfosContas = infos;
    } catch (_) {}
  }

  Future<List<PostagemResumo>> _carregarPostagens() async {
    final isEmpresa = _contaEmpresaAtiva;
    final idGrupoEmpresa = await _buscarIdGrupoEmpresa();
    final idPerfilEmpresa = await _buscarIdPerfilEmpresa();

    if (isEmpresa) {
      // Conta empresa ativa: mostra SÓ postagens da empresa
      // (tipo_autor='empresa' + fk_grupo_empresa do grupo).
      if (idPerfilEmpresa != null) {
        final posts = await PostagensProfissionalService.buscarPostagensConta(
          idPerfil: idPerfilEmpresa,
          isEmpresa: true,
          idGrupoEmpresa: idGrupoEmpresa,
          limit: 10,
        );
        if (posts.isNotEmpty) return posts;
        // Se o grupo ainda não tem fk_perfil dedicado, tenta listar
        // pelo vínculo fk_grupo_empresa varrendo o perfil do profissional
        // (caso em que a empresa herdou o perfil do dono).
        final idPerfilProf = await _buscarIdPerfilProfissional();
        if (idPerfilProf != null && idGrupoEmpresa != null) {
          return PostagensProfissionalService.buscarPostagensConta(
            idPerfil: idPerfilProf,
            isEmpresa: true,
            idGrupoEmpresa: idGrupoEmpresa,
            limit: 10,
          );
        }
        return posts;
      }
      return [];
    }

    // Conta profissional (CNPJ individual): mostra SÓ as postagens do
    // profissional (tipo_autor='profissional', sem as da empresa).
    final idPerfilProf = await _buscarIdPerfilProfissional();
    if (idPerfilProf != null) {
      return PostagensProfissionalService.buscarPostagensConta(
        idPerfil: idPerfilProf,
        isEmpresa: false,
        limit: 10,
      );
    }
    return PostagensProfissionalService.buscarPostagens(limit: 10);
  }

  @override
  void dispose() {
    _postagemController.dispose();
    super.dispose();
  }

  Color _corFromHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return const Color(0xFF0FB3FF);
    var value = hex.trim().replaceAll('#', '');
    if (value.startsWith('0x') || value.startsWith('0X')) {
      value = value.substring(2);
    }
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return const Color(0xFF0FB3FF);
    return Color(parsed);
  }

  Color _corContraste(Color c) {
    final lum = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    return lum > 0.55 ? Colors.black : Colors.white;
  }

  Future<List<Map<String, dynamic>>> _buscarConvitesEmpresa() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();

      final usuarioId = (usuario?['id_usuario'] as num?)?.toInt();
      if (usuarioId == null) return [];

      final dadosProf = await supabase
          .from('dados_profissionais')
          .select('id_profissional, fk_grupo_empresa')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();

      final idProf = (dadosProf?['id_profissional'] as num?)?.toInt();
      if (idProf == null) return [];

      List<dynamic>? convites;
      try {
        convites = await supabase
            .from('convites_empresa')
            .select('*, grupo_empresa(*)')
            .eq('fk_dados_profissionais', idProf);
      } catch (_) {
        try {
          convites = await supabase
              .from('convites_empresa')
              .select('*, grupo_empresa(*)')
              .eq('fk_profissional', idProf);
        } catch (_) {}
      }

      if (convites == null || convites.isEmpty) return [];

      return List<Map<String, dynamic>>.from(convites);
    } catch (e) {
      debugPrint('Erro ao buscar convites de empresa: $e');
      return [];
    }
  }

  Future<bool> _aceitarConviteEmpresa(Map<String, dynamic> convite) async {
    try {
      final supabase = Supabase.instance.client;
      final idGrupo = (convite['fk_grupo_empresa'] as num?)?.toInt();
      final idProf =
          (convite['fk_dados_profissionais'] ??
                  convite['fk_profissional'] as num?)
              ?.toInt();
      final idConvite =
          (convite['id_convite_empresa'] ??
                  convite['id_convite'] ??
                  convite['id'] as num?)
              ?.toInt();

      if (idProf == null) return false;

      // Regra: cada profissional só pode participar de uma empresa.
      final profAtual = await supabase
          .from('dados_profissionais')
          .select('fk_grupo_empresa')
          .eq('id_profissional', idProf)
          .maybeSingle();
      final empresaAtual = (profAtual?['fk_grupo_empresa'] as num?)?.toInt();

      if (empresaAtual != null && empresaAtual != idGrupo) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Você já faz parte de outra empresa e só pode participar de uma.',
              ),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      if (idGrupo != null && idProf != null) {
        await supabase
            .from('dados_profissionais')
            .update({'fk_grupo_empresa': idGrupo})
            .eq('id_profissional', idProf);
      }

      if (idConvite != null) {
        try {
          await supabase
              .from('convites_empresa')
              .delete()
              .eq('id_convite_empresa', idConvite);
        } catch (_) {
          await supabase
              .from('convites_empresa')
              .delete()
              .eq('id_convite', idConvite);
        }
      } else if (idGrupo != null && idProf != null) {
        try {
          await supabase.from('convites_empresa').delete().match({
            'fk_grupo_empresa': idGrupo,
            'fk_dados_profissionais': idProf,
          });
        } catch (_) {
          await supabase.from('convites_empresa').delete().match({
            'fk_grupo_empresa': idGrupo,
            'fk_profissional': idProf,
          });
        }
      }

      if (mounted) {
        setState(() {
          _convitesEmpresaFuture = _buscarConvitesEmpresa();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Convite aceito com sucesso! Agora você faz parte da equipe.',
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Erro ao aceitar convite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aceitar convite: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _recusarConviteEmpresa(Map<String, dynamic> convite) async {
    try {
      final supabase = Supabase.instance.client;
      final idGrupo = (convite['fk_grupo_empresa'] as num?)?.toInt();
      final idProf =
          (convite['fk_dados_profissionais'] ??
                  convite['fk_profissional'] as num?)
              ?.toInt();
      final idConvite =
          (convite['id_convite_empresa'] ??
                  convite['id_convite'] ??
                  convite['id'] as num?)
              ?.toInt();

      if (idConvite != null) {
        try {
          await supabase
              .from('convites_empresa')
              .delete()
              .eq('id_convite_empresa', idConvite);
        } catch (_) {
          await supabase
              .from('convites_empresa')
              .delete()
              .eq('id_convite', idConvite);
        }
      } else if (idGrupo != null && idProf != null) {
        try {
          await supabase.from('convites_empresa').delete().match({
            'fk_grupo_empresa': idGrupo,
            'fk_dados_profissionais': idProf,
          });
        } catch (_) {
          await supabase.from('convites_empresa').delete().match({
            'fk_grupo_empresa': idGrupo,
            'fk_profissional': idProf,
          });
        }
      }

      if (mounted) {
        setState(() {
          _convitesEmpresaFuture = _buscarConvitesEmpresa();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Convite recusado.'),
            backgroundColor: Color(0xFF1A2B4A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Erro ao recusar convite: $e');
      return false;
    }
  }

  Widget _buildBotaoNotificacao() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _convitesEmpresaFuture,
      builder: (context, snapshot) {
        final convites = snapshot.data ?? const <Map<String, dynamic>>[];
        final total = convites.length;
        return Stack(
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
              onPressed: _abrirPainelConvites,
            ),
            if (total > 0)
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
                  child: Text(
                    total > 9 ? '9+' : '$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _abrirPainelConvites() async {
    final convites = await _buscarConvitesEmpresa();
    if (!mounted) return;

    if (convites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não possui convites para empresas no momento.'),
          backgroundColor: Color(0xFF1A2B4A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PainelConvitesEmpresa(
        convites: convites,
        onAceitar: _aceitarConviteEmpresa,
        onRecusar: _recusarConviteEmpresa,
      ),
    );
  }

  Future<String?> _buscarTipoPerfil() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();

      final usuarioId = usuario?['id_usuario'];
      if (usuarioId == null) return null;

      final dadosProf = await supabase
          .from('dados_profissionais')
          .select('fk_perfil')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();

      final fkPerfil = dadosProf?['fk_perfil'];
      if (fkPerfil == null) return null;

      final perfil = await supabase
          .from('perfil')
          .select('tipo_perfil')
          .eq('id_perfil', fkPerfil)
          .maybeSingle();

      return perfil?['tipo_perfil']?.toString();
    } catch (e) {
      debugPrint('Erro ao buscar tipo_perfil: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _buscarDadosEmpresa() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      final usuarioId = usuario?['id_usuario'];
      if (usuarioId == null) return null;

      final dadosProf = await supabase
          .from('dados_profissionais')
          .select('id_profissional, fk_grupo_empresa, fk_perfil')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();

      final idGrupo = (dadosProf?['fk_grupo_empresa'] as num?)?.toInt();
      final idPerfil = (dadosProf?['fk_perfil'] as num?)?.toInt();

      Map<String, dynamic>? grupo;
      if (idGrupo != null) {
        grupo = await supabase
            .from('grupo_empresa')
            .select('*')
            .eq('id_grupo_empresa', idGrupo)
            .maybeSingle();
      }
      if (grupo == null && idPerfil != null) {
        grupo = await supabase
            .from('grupo_empresa')
            .select('*')
            .eq('fk_perfil', idPerfil)
            .maybeSingle();
      }

      return grupo;
    } catch (e) {
      debugPrint('Erro ao buscar dados empresa: $e');
      return null;
    }
  }

  /// ID do grupo_empresa vinculado ao profissional logado (null se não tem).
  Future<int?> _buscarIdGrupoEmpresa() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      final usuarioId = usuario?['id_usuario'];
      if (usuarioId == null) return null;

      final dadosProf = await supabase
          .from('dados_profissionais')
          .select('fk_grupo_empresa, fk_perfil')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();
      if (dadosProf == null) return null;

      final idGrupo = (dadosProf['fk_grupo_empresa'] as num?)?.toInt();
      if (idGrupo != null) return idGrupo;

      // Fallback: grupo que usa o mesmo perfil do profissional.
      final idPerfil = (dadosProf['fk_perfil'] as num?)?.toInt();
      if (idPerfil == null) return null;
      final grupo = await supabase
          .from('grupo_empresa')
          .select('id_grupo_empresa')
          .eq('fk_perfil', idPerfil)
          .maybeSingle();
      return (grupo?['id_grupo_empresa'] as num?)?.toInt();
    } catch (e) {
      debugPrint('Erro ao buscar id grupo empresa: $e');
      return null;
    }
  }

  /// Perfil (fk_perfil) que a EMPRESA usa para postar.
  /// Garante que exista um perfil dedicado p/ a empresa (tipo 'Loja'),
  /// para não colidir com as postagens do profissional individual.
  Future<int?> _buscarIdPerfilEmpresa() async {
    try {
      final empresa = await _buscarDadosEmpresa();
      var fkPerfil = (empresa?['fk_perfil'] as num?)?.toInt();
      if (fkPerfil != null) return fkPerfil;

      // Empresa sem perfil dedicado: cria um perfil 'Loja' e vincula.
      final supabase = Supabase.instance.client;
      final idGrupo =
          (empresa?['id_grupo_empresa'] as num?)?.toInt() ??
          await _buscarIdGrupoEmpresa();
      if (idGrupo == null) return null;

      final novoPerfil = await supabase
          .from('perfil')
          .insert({'tipo_perfil': 'Loja'})
          .select('id_perfil')
          .single();
      fkPerfil = (novoPerfil['id_perfil'] as num?)?.toInt();
      if (fkPerfil == null) return null;

      await supabase
          .from('grupo_empresa')
          .update({'fk_perfil': fkPerfil})
          .eq('id_grupo_empresa', idGrupo);
      debugPrint(
        '🏢 [perfil empresa] criado fk_perfil=$fkPerfil p/ grupo=$idGrupo',
      );
      return fkPerfil;
    } catch (e) {
      debugPrint('Erro ao buscar/criar perfil da empresa: $e');
      return null;
    }
  }

  /// Perfil do profissional individual (fk_perfil de dados_profissionais).
  Future<int?> _buscarIdPerfilProfissional() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;
      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      final usuarioId = usuario?['id_usuario'];
      if (usuarioId == null) return null;
      final dadosProf = await supabase
          .from('dados_profissionais')
          .select('fk_perfil')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();
      return (dadosProf?['fk_perfil'] as num?)?.toInt();
    } catch (e) {
      debugPrint('Erro ao buscar perfil profissional: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _buscarDadosProfissional() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;
      final response = await supabase
          .from('usuarios')
          .select('nome, foto_perfil_url, id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      if (response == null) return null;

      if (_contaEmpresaAtiva) {
        final empresa = await _buscarDadosEmpresa();
        if (empresa != null) {
          final nomeEmp = empresa['nome_empresa']?.toString().trim();
          final fotoEmp = empresa['foto_url_empresa']?.toString().trim();
          return {
            'nome': (nomeEmp != null && nomeEmp.isNotEmpty)
                ? nomeEmp
                : response['nome'],
            'foto_perfil_url': (fotoEmp != null && fotoEmp.isNotEmpty)
                ? fotoEmp
                : response['foto_perfil_url'],
            'is_empresa': true,
          };
        }
      }

      return {...response, 'is_empresa': false};
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

      // 2. Busca a associação com endereço
      dynamic fkEndereco;
      if (_contaEmpresaAtiva) {
        final empresa = await _buscarDadosEmpresa();
        fkEndereco = empresa?['fk_endereco'];

        if (fkEndereco == null) {
          final assComercial = await supabase
              .from('ass_usuario_endereco')
              .select('fk_endereco')
              .eq('fk_usuario', usuarioId)
              .inFilter('tipo_endereco', [
                'Comercial',
                'Trabalho',
                'Empresa',
                'Loja',
              ])
              .limit(1)
              .maybeSingle();
          if (assComercial != null) {
            fkEndereco = assComercial['fk_endereco'];
          }
        }
      }

      if (fkEndereco == null) {
        final assResponse = await supabase
            .from('ass_usuario_endereco')
            .select('fk_endereco, endereco_ativo')
            .eq('fk_usuario', usuarioId)
            .order('endereco_ativo', ascending: false)
            .limit(1)
            .maybeSingle();
        if (assResponse == null) return null;
        fkEndereco = assResponse['fk_endereco'];
      }
      if (fkEndereco == null) return null;

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

  Future<_OficiosPerfil?> _buscarOficios() async {
    try {
      final supabase = Supabase.instance.client;

      if (_contaEmpresaAtiva) {
        final empresa = await _buscarDadosEmpresa();
        if (empresa == null) return null;

        final idGrupoEmpresa = (empresa['id_grupo_empresa'] as num?)?.toInt();
        final tagEmpresa = empresa['tag_empresa']?.toString().trim();
        final corTagEmpresa = empresa['cor_tag_empresa']?.toString().trim();

        if (idGrupoEmpresa == null) {
          return _OficiosPerfil(
            tagEmpresa: tagEmpresa,
            corTagEmpresa: corTagEmpresa,
            oficios: const [],
          );
        }

        final assOficios = await supabase
            .from('ass_oficio_grupo_empresa')
            .select('fk_oficio')
            .eq('fk_grupo_empresa', idGrupoEmpresa);

        final idsOficios = assOficios
            .map((e) => e['fk_oficio'])
            .whereType<num>()
            .map((e) => e.toInt())
            .toList();

        if (idsOficios.isEmpty) {
          return _OficiosPerfil(
            tagEmpresa: tagEmpresa,
            corTagEmpresa: corTagEmpresa,
            oficios: const [],
          );
        }

        final oficiosData = await supabase
            .from('oficios')
            .select('funcao, cor')
            .inFilter('id_oficio', idsOficios);

        final oficios = <OficioInfo>[];
        for (final row in oficiosData) {
          final info = OficioInfo.fromMap(row);
          if (info.funcao.isNotEmpty) oficios.add(info);
        }

        return _OficiosPerfil(
          tagEmpresa: tagEmpresa,
          corTagEmpresa: corTagEmpresa,
          oficios: oficios,
        );
      }

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
          .select('id_profissional, fk_grupo_empresa')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();
      if (dadosProf == null) return null;

      final idProfissional = dadosProf['id_profissional'];
      String? tagEmpresa;
      String? corTagEmpresa;
      final idGrupoEmpresa = (dadosProf['fk_grupo_empresa'] as num?)?.toInt();

      if (idGrupoEmpresa != null) {
        final grupo = await supabase
            .from('grupo_empresa')
            .select('tag_empresa, cor_tag_empresa')
            .eq('id_grupo_empresa', idGrupoEmpresa)
            .maybeSingle();
        tagEmpresa = grupo?['tag_empresa']?.toString().trim();
        corTagEmpresa = grupo?['cor_tag_empresa']?.toString().trim();
      }

      // 3. Busca os ofícios associados ao profissional
      final assOficios = await supabase
          .from('ass_oficio_profissional')
          .select('fk_oficio')
          .eq('fk_profissional', idProfissional);

      final idsOficios = assOficios
          .map((e) => e['fk_oficio'])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList();

      if (idsOficios.isEmpty) {
        return _OficiosPerfil(
          tagEmpresa: tagEmpresa,
          corTagEmpresa: corTagEmpresa,
          oficios: const [],
        );
      }

      // 4. Busca os nomes e cores dos ofícios
      final oficiosData = await supabase
          .from('oficios')
          .select('funcao, cor')
          .inFilter('id_oficio', idsOficios);

      final oficios = <OficioInfo>[];
      for (final row in oficiosData) {
        final info = OficioInfo.fromMap(row);
        if (info.funcao.isNotEmpty) oficios.add(info);
      }

      return _OficiosPerfil(
        tagEmpresa: tagEmpresa,
        corTagEmpresa: corTagEmpresa,
        oficios: oficios,
      );
    } catch (e) {
      return null;
    }
  }

  // ================= AGENDA DA SEMANA =================

  /// Busca o `id_profissional` do usuário logado.
  Future<int?> _buscarIdProfissional() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return null;

      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      final usuarioId = usuario?['id_usuario'];
      if (usuarioId == null) return null;

      final dadosProf = await supabase
          .from('dados_profissionais')
          .select('id_profissional')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();
      if (dadosProf == null) return null;

      return (dadosProf['id_profissional'] as num?)?.toInt();
    } catch (e) {
      debugPrint('❌ [_buscarIdProfissional] ERRO: $e');
      return null;
    }
  }

  String _formatarDataCompleta(DateTime data) {
    final mm = data.month.toString().padLeft(2, '0');
    final dd = data.day.toString().padLeft(2, '0');
    return '${data.year}-$mm-$dd';
  }

  /// Converte uma string time (ex: "08:00:00" ou "08:00:00-03") em TimeOfDay.
  TimeOfDay? _parseHora(Object? raw) {
    if (raw == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.toString());
    if (match == null) return null;
    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }

  /// Converte a coluna `date` (formato "YYYY-MM-DD") em DateTime.
  DateTime? _parseDataExcecao(Object? raw) {
    if (raw == null) return null;
    final texto = raw.toString().trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(texto);
    if (match == null) return DateTime.tryParse(texto);
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// Carrega os 7 dias da semana atual (segunda a domingo), verificando a
  /// disponibilidade recorrente (agenda_profissional) e as exceções
  /// (grade_horario_excecao) de cada dia.
  Future<List<_DiaAgendaCalendario>> _carregarAgendaSemana() async {
    try {
      final supabase = Supabase.instance.client;
      final idProfissional = widget.isVisitante
          ? null
          : await _buscarIdProfissional();
      int? idEmpresa;

      if (_contaEmpresaAtiva) {
        final empresa = await _buscarDadosEmpresa();
        idEmpresa = (empresa?['id_grupo_empresa'] as num?)?.toInt();
        if (idEmpresa == null) return _gerarSemanaDefault();
      } else {
        if (idProfissional == null) return _gerarSemanaDefault();
      }

      final agora = DateTime.now();
      final hoje = DateTime(agora.year, agora.month, agora.day);

      // Hoje é o primeiro dia da fila, seguido dos próximos 6 dias.
      final diasDaSemana = List.generate(7, (i) => hoje.add(Duration(days: i)));

      // 1. Busca a disponibilidade recorrente (fk_solicitacao = 0)
      final queryAgenda = supabase
          .from('agenda_profissional')
          .select('dias_semana')
          .eq('fk_solicitacao', 0);

      final agenda = _contaEmpresaAtiva
          ? await queryAgenda
                .eq('fk_grupo_empresa', idEmpresa!)
                .limit(1)
                .maybeSingle()
          : await queryAgenda
                .eq('fk_profissional', idProfissional!)
                .limit(1)
                .maybeSingle();

      final diasDisponiveis = <int>{};
      final diasRaw = agenda?['dias_semana']?.toString();
      if (diasRaw != null && diasRaw.trim().isNotEmpty) {
        for (final nome in diasRaw.split(',')) {
          final indice = _nomesDiasMinusculo.indexOf(nome.trim().toLowerCase());
          if (indice >= 0) diasDisponiveis.add(indice);
        }
      }

      // 2. Busca as exceções dos 7 dias da semana
      final primeiraData = _formatarDataCompleta(diasDaSemana.first);
      final ultimaData = _formatarDataCompleta(diasDaSemana.last);

      List<Map<String, dynamic>> excecoes = [];
      try {
        final queryExcecoes = supabase
            .from('grade_horario_excecao')
            .select('dia_semana, hora_ini, hora_fim, observacao')
            .gte('dia_semana', primeiraData)
            .lte('dia_semana', ultimaData);

        final response = _contaEmpresaAtiva
            ? await queryExcecoes.eq('fk_grupo_empresa', idEmpresa!)
            : await queryExcecoes.eq('fk_profissional', idProfissional!);
        excecoes = response;
      } catch (e) {
        debugPrint('❌ [_carregarAgendaSemana] ERRO ao buscar exceções: $e');
      }

      // 3. Monta a lista de dias
      final resultado = <_DiaAgendaCalendario>[];
      for (final dia in diasDaSemana) {
        final chave = _formatarDataCompleta(dia);
        final disponivel = diasDisponiveis.contains(dia.weekday % 7);

        String? observacao;
        TimeOfDay? horaIni;
        TimeOfDay? horaFim;

        final excecao = excecoes.where((e) {
          final dataExcecao = _parseDataExcecao(e['dia_semana']);
          return dataExcecao != null &&
              _formatarDataCompleta(dataExcecao) == chave;
        });

        if (excecao.isNotEmpty) {
          final row = excecao.first;
          observacao = row['observacao']?.toString();
          horaIni = _parseHora(row['hora_ini']);
          horaFim = _parseHora(row['hora_fim']);
        }

        resultado.add(
          _DiaAgendaCalendario(
            data: dia,
            disponivel: disponivel,
            observacaoExcecao: observacao,
            horaInicioExcecao: horaIni,
            horaFimExcecao: horaFim,
          ),
        );
      }

      return resultado;
    } catch (e) {
      debugPrint('❌ [_carregarAgendaSemana] ERRO GERAL: $e');
      return _gerarSemanaDefault();
    }
  }

  /// Gera a semana atual com todos os dias indisponíveis (usado quando não é
  /// possível carregar a disponibilidade do banco).
  List<_DiaAgendaCalendario> _gerarSemanaDefault() {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    return List.generate(
      7,
      (i) => _DiaAgendaCalendario(
        data: hoje.add(Duration(days: i)),
        disponivel: false,
      ),
    );
  }

  String _formatarDataExcecaoPopup(DateTime data) {
    return '${data.day} de ${_mesesExtenso[data.month - 1]} de ${data.year}';
  }

  String _formatarHoraExibicao(TimeOfDay time) {
    final hora = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minuto = time.minute.toString().padLeft(2, '0');
    final periodo = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hora.toString().padLeft(2, '0')}:$minuto $periodo';
  }

  void _mostrarPopupExcecao(_DiaAgendaCalendario dia) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final observacao = dia.observacaoExcecao?.trim().isNotEmpty == true
            ? dia.observacaoExcecao!.trim()
            : 'Indisponível';

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.event_busy, color: _vermelhoExcecao, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Exceção na agenda',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _titleDark,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatarDataExcecaoPopup(dia.data),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _titleDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _nomesDiasSemana[dia.data.weekday % 7],
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _vermelhoExcecao.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _vermelhoExcecao.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Motivo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _vermelhoExcecao,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      observacao,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _titleDark,
                        height: 1.4,
                      ),
                    ),
                    if (dia.horaInicioExcecao != null &&
                        dia.horaFimExcecao != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ausência das ${_formatarHoraExibicao(dia.horaInicioExcecao!)} '
                        'às ${_formatarHoraExibicao(dia.horaFimExcecao!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: _vermelhoExcecao),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
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

  // ================= BOTTOM SHEET DO PERFIL =================

  Widget _buildAvatarIniciais(String nome) {
    return Container(
      color: const Color(0xFFE1F5FE),
      child: Center(
        child: Text(
          obterIniciais(nome),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _primaryBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildOpcaoBottomSheet({
    required Widget iconeWidget,
    required String titulo,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: Center(child: iconeWidget),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarBottomSheetPerfil({
    required String nome,
    required String? fotoUrl,
    required String endereco,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (bottomSheetContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(bottomSheetContext).pop(),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {}, // Impede fechar ao clicar no interior
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Traço de arrasto superior
                          Center(
                            child: Container(
                              width: 44,
                              height: 4,
                              margin: const EdgeInsets.only(
                                top: 12,
                                bottom: 20,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1D5DB),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // Cabeçalho: Foto + Selo, Nome, Endereço e Setas de troca
                          // Toda a área (foto/nome/endereço) abre a troca de conta.
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                Navigator.of(bottomSheetContext).pop();
                                await _mostrarBottomSheetTrocaConta();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _primaryBlue,
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child:
                                            fotoUrl != null &&
                                                fotoUrl.isNotEmpty
                                            ? Image.network(
                                                fotoUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    _buildAvatarIniciais(nome),
                                              )
                                            : _buildAvatarIniciais(nome),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: _primaryBlue,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 10,
                                          ),
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
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        nome,
                                        style: const TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on,
                                            size: 16,
                                            color: _primaryBlue,
                                          ),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              endereco,
                                              style: const TextStyle(
                                                fontSize: 13.5,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.swap_horiz,
                                    size: 26,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          const SizedBox(height: 8),

                          // Opção 1: Editar dados pessoais
                          _buildOpcaoBottomSheet(
                            iconeWidget: const Icon(
                              Icons.person_outline_rounded,
                              color: _primaryBlue,
                              size: 28,
                            ),
                            titulo: 'Editar dados pessoais',
                            onTap: () async {
                              Navigator.of(bottomSheetContext).pop();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EditarInformacoesPage(),
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  _inicializarFutures();
                                });
                              }
                            },
                          ),

                          // Opção 2: Meus endereços
                          _buildOpcaoBottomSheet(
                            iconeWidget: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: _primaryBlue,
                                  size: 30,
                                ),
                                Positioned(
                                  top: 6,
                                  child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.home,
                                        color: _primaryBlue,
                                        size: 9,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            titulo: 'Meus endereços',
                            onTap: () async {
                              Navigator.of(bottomSheetContext).pop();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MeusEnderecosPage(
                                    isVisitante: widget.isVisitante,
                                    isProfissional: true,
                                  ),
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  _inicializarFutures();
                                });
                              }
                            },
                          ),

                          // Opção 3: Minha área de atuação
                          _buildOpcaoBottomSheet(
                            iconeWidget: Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE0F2FE),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: CustomPaint(
                                  size: const Size(22, 22),
                                  painter: const _IconeAreaAtuacaoPainter(
                                    color: _primaryBlue,
                                  ),
                                ),
                              ),
                            ),
                            titulo: 'Minha área de atuação',
                            onTap: () async {
                              Navigator.of(bottomSheetContext).pop();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AreaAtuacaoPage(),
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  _inicializarFutures();
                                });
                              }
                            },
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ================= BOTTOM SHEET DE TROCA DE CONTAS =================

  String _formatarSeguidores(int total) {
    if (total >= 1000) {
      final mil = (total / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return '$mil mil';
    }
    return '$total';
  }

  Future<Map<String, dynamic>> _carregarInformacoesContas() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      return {
        'nome_profissional': 'Profissional CNPJ',
        'foto_profissional': null,
        'seguidores_profissional': 0,
        'nome_empresa': 'Minha Empresa',
        'foto_empresa': null,
        'seguidores_empresa': 0,
        'tem_empresa': false,
      };
    }

    // 1. Dados do Usuário (Profissional CNPJ)
    final usuario = await supabase
        .from('usuarios')
        .select('id_usuario, nome, foto_perfil_url')
        .eq('auth_id', user.id)
        .maybeSingle();

    final nomeProf = usuario?['nome']?.toString() ?? 'Profissional CNPJ';
    final fotoProf = usuario?['foto_perfil_url']?.toString();
    final usuarioId = (usuario?['id_usuario'] as num?)?.toInt();

    // 2. Dados Profissionais
    Map<String, dynamic>? dadosProf;
    if (usuarioId != null) {
      dadosProf = await supabase
          .from('dados_profissionais')
          .select('id_profissional, fk_grupo_empresa, fk_perfil')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();
    }

    final idProfissional = (dadosProf?['id_profissional'] as num?)?.toInt();
    final idGrupo = (dadosProf?['fk_grupo_empresa'] as num?)?.toInt();
    final idPerfil = (dadosProf?['fk_perfil'] as num?)?.toInt();

    // 3. Dados da Empresa (grupo_empresa)
    Map<String, dynamic>? grupo;
    if (idGrupo != null) {
      grupo = await supabase
          .from('grupo_empresa')
          .select('*')
          .eq('id_grupo_empresa', idGrupo)
          .maybeSingle();
    }
    if (grupo == null && idPerfil != null) {
      grupo = await supabase
          .from('grupo_empresa')
          .select('*')
          .eq('fk_perfil', idPerfil)
          .maybeSingle();
    }

    final nomeEmpresa = grupo?['nome_empresa']?.toString().trim();
    final fotoEmpresa = grupo?['foto_url_empresa']?.toString().trim();

    // 4. Seguidores do Profissional (Valor estático é 0, carregar do Supabase)
    int segProf = 0;
    if (idProfissional != null) {
      try {
        final res = await supabase
            .from('seguidores_profissional')
            .select('id_seguidor')
            .eq('fk_profissional', idProfissional);
        segProf = (res as List).length;
      } catch (_) {}
    }

    // 5. Seguidores da Empresa (Valor estático é 0, carregar do Supabase)
    int segEmp = 0;
    if (grupo != null) {
      final segColuna = (grupo['seguidores_empresa'] as num?)?.toInt();
      if (segColuna != null && segColuna > 0) {
        segEmp = segColuna;
      } else {
        try {
          final idGrupoReal =
              (grupo['id_grupo_empresa'] as num?)?.toInt() ?? idGrupo;
          if (idGrupoReal != null) {
            final res = await supabase
                .from('seguidores_empresa')
                .select('id_seguidor')
                .eq('fk_grupo_empresa', idGrupoReal);
            segEmp = (res as List).length;
          }
        } catch (_) {}
      }
    }

    return {
      'nome_profissional': nomeProf,
      'foto_profissional': fotoProf,
      'seguidores_profissional': segProf,
      'nome_empresa': (nomeEmpresa != null && nomeEmpresa.isNotEmpty)
          ? nomeEmpresa
          : 'Minha Empresa',
      'foto_empresa': (fotoEmpresa != null && fotoEmpresa.isNotEmpty)
          ? fotoEmpresa
          : null,
      'seguidores_empresa': segEmp,
      'tem_empresa': grupo != null,
    };
  }

  // Placeholder usado só se o cache ainda não carregou (1º acesso bem
  // no início). Como o cache é pré-carregado no initState, na prática o
  // sheet sempre abre direto no conteúdo, sem spinner.
  static const Map<String, dynamic> _infosContasPlaceholder = {
    'nome_profissional': 'Profissional CNPJ',
    'foto_profissional': null,
    'seguidores_profissional': 0,
    'nome_empresa': 'Minha Empresa',
    'foto_empresa': null,
    'seguidores_empresa': 0,
    'tem_empresa': false,
  };

  Future<void> _mostrarBottomSheetTrocaConta() async {
    // Abre na hora com o cache; atualiza em 2º plano sem spinner.
    final iniciais = _cacheInfosContas ?? _infosContasPlaceholder;
    if (_cacheInfosContas == null) {
      _precarregarInfosContas().then((_) {
        if (mounted && _cacheInfosContas != null) {
          setState(() {});
        }
      });
    } else {
      // Atualiza silenciosamente para a próxima abertura.
      _precarregarInfosContas();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (sheetContext) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(sheetContext).pop(),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      // StatefulBuilder permite trocar o conteúdo quando o
                      // cache terminar de carregar, sem fechar/reabrir.
                      child: StatefulBuilder(
                        builder: (context, setSheetState) {
                          if (_cacheInfosContas == null) {
                            _precarregarInfosContas().then((_) {
                              if (mounted) {
                                setSheetState(() {});
                              }
                            });
                          }
                          final dados = _cacheInfosContas ?? iniciais;
                          return _buildConteudoTrocaConta(sheetContext, dados);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Conteúdo do bottom sheet de troca (extraído para reutilizar o
  /// cache e não depender de FutureBuilder com spinner).
  Widget _buildConteudoTrocaConta(
    BuildContext sheetContext,
    Map<String, dynamic> dados,
  ) {
    final nomeProf = dados['nome_profissional'] as String;
    final fotoProf = dados['foto_profissional'] as String?;
    final segProf = dados['seguidores_profissional'] as int;

    final nomeEmp = dados['nome_empresa'] as String;
    final fotoEmp = dados['foto_empresa'] as String?;
    final segEmp = dados['seguidores_empresa'] as int;

    final nomeAtivo = _contaEmpresaAtiva ? nomeEmp : nomeProf;
    final fotoAtivo = _contaEmpresaAtiva ? fotoEmp : fotoProf;
    final segAtivo = _contaEmpresaAtiva ? segEmp : segProf;

    final nomeInativo = _contaEmpresaAtiva ? nomeProf : nomeEmp;
    final fotoInativo = _contaEmpresaAtiva ? fotoProf : fotoEmp;
    final subtituloInativo = _contaEmpresaAtiva
        ? 'Profissional CNPJ'
        : 'Empresa / Loja';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Barra de arrasto
        Center(
          child: Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Conta Ativa (Foto, Nome em #0FB3FF e Checkmark em círculo #0FB3FF)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFE1F5FE),
                backgroundImage: fotoAtivo != null && fotoAtivo.isNotEmpty
                    ? NetworkImage(fotoAtivo)
                    : null,
                child: fotoAtivo == null || fotoAtivo.isEmpty
                    ? Text(
                        obterIniciais(nomeAtivo),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  nomeAtivo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: _primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),

        // Containers de Métricas (Seguidores na esquerda, Pedidos ativos na direita)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    '${_formatarSeguidores(segAtivo)} seguidores',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                  ),
                  child: const Text(
                    '0 pedidos ativos',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

        // Outra Conta (Inativa) - Ao clicar nela, troca de conta!
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final messenger = ScaffoldMessenger.of(sheetContext);
              Navigator.of(sheetContext).pop();
              final novoEstado = !_contaEmpresaAtiva;
              // Troca instantânea: fecha o sheet, atualiza
              // a UI na hora e salva em 2º plano.
              setState(() {
                _contaEmpresaAtiva = novoEstado;
                _inicializarFutures();
              });
              unawaited(_salvarPreferenciaContaAtiva(novoEstado));
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Conta alternada para $nomeInativo'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFF1F5F9),
                    backgroundImage:
                        fotoInativo != null && fotoInativo.isNotEmpty
                        ? NetworkImage(fotoInativo)
                        : null,
                    child: fotoInativo == null || fotoInativo.isEmpty
                        ? Text(
                            obterIniciais(nomeInativo),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          nomeInativo,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF5252),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              subtituloInativo,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
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
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // ================= CRIAÇÃO DE POSTAGEM =================

  Future<void> _abrirCriacaoPostagem({
    required String? fotoUrl,
    required String nome,
  }) async {
    _postagemController.clear();
    setState(() {
      _imagensSelecionadas = [];
      _enviandoPostagem = false;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFE1F5FE),
                        backgroundImage: fotoUrl != null
                            ? NetworkImage(fotoUrl)
                            : null,
                        child: fotoUrl == null
                            ? Text(
                                obterIniciais(nome),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryBlue,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _titleDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _postagemController,
                    maxLines: 4,
                    minLines: 2,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'No que você está trabalhando hoje?',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      filled: true,
                      fillColor: _inputGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _primaryBlue,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (_imagensSelecionadas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imagensSelecionadas.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final imagem = _imagensSelecionadas[index];
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: kIsWeb
                                    ? Image.network(
                                        imagem.path,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _buildPlaceholderImagemSelecionada(),
                                      )
                                    : Image.file(
                                        File(imagem.path),
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _buildPlaceholderImagemSelecionada(),
                                      ),
                              ),
                              Positioned(
                                right: -6,
                                top: -6,
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      _imagensSelecionadas.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Botão de anexar foto
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _enviandoPostagem
                              ? null
                              : () => _escolherImagens(setModalState),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(
                                  Icons.photo_camera_outlined,
                                  color: _primaryBlue,
                                  size: 26,
                                ),
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: const BoxDecoration(
                                      color: _primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botão de enviar postagem (avião de papel)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _enviandoPostagem
                              ? null
                              : () => _enviarPostagem(setModalState),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: _enviandoPostagem
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: _primaryBlue,
                                    ),
                                  )
                                : Icon(
                                    Icons.send_outlined,
                                    color: _imagensSelecionadas.isEmpty
                                        ? Colors.grey.shade400
                                        : _primaryBlue,
                                    size: 26,
                                  ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_imagensSelecionadas.length} foto(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _escolherImagens(StateSetter setModalState) async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );

      if (pickedFiles.isEmpty) return;

      setModalState(() {
        _imagensSelecionadas = [..._imagensSelecionadas, ...pickedFiles];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagens: $e')),
        );
      }
    }
  }

  Future<void> _enviarPostagem(StateSetter setModalState) async {
    final conteudo = _postagemController.text.trim();
    if (_imagensSelecionadas.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Você só pode realizar postagens com fotos anexadas.',
            ),
          ),
        );
      }
      return;
    }

    int? fkPerfilEmpresa;
    int? idGrupoEmpresaPost;
    if (_contaEmpresaAtiva) {
      // Empresa: garante perfil dedicado (Loja) + grupo para marcar a
      // postagem como tipo_autor='empresa' (não mistura com o CNPJ).
      idGrupoEmpresaPost = await _buscarIdGrupoEmpresa();
      fkPerfilEmpresa = await _buscarIdPerfilEmpresa();
      if (fkPerfilEmpresa == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível identificar a empresa para postar. '
                'Verifique a empresa associada.',
              ),
            ),
          );
        }
        return;
      }
    }

    final resultado = await PostagensProfissionalService.criarPostagem(
      conteudo: conteudo,
      imagens: _imagensSelecionadas,
      idPerfilOverride: fkPerfilEmpresa,
      tipoAutor: _contaEmpresaAtiva ? 'empresa' : 'profissional',
      idGrupoEmpresa: idGrupoEmpresaPost,
    );

    if (!mounted) return;

    if (resultado.sucesso) {
      Navigator.of(context).pop();
      setState(() {
        _imagensSelecionadas = [];
        _enviandoPostagem = false;
        _postagensFuture = _carregarPostagens();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Postagem publicada com sucesso!')),
      );
    } else {
      setModalState(() => _enviandoPostagem = false);
      debugPrint(
        '❌ [tela_home_profissional] Falha ao publicar: ${resultado.erro}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado.erro ?? 'Erro ao publicar postagem.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPlaceholderImagemSelecionada() {
    return Container(
      width: 90,
      height: 90,
      color: const Color(0xFFE8EDF2),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 28,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackHandler(
      isHome: true,
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ================= CARTÃO DE PERFIL =================
              FutureBuilder<Map<String, dynamic>?>(
                future: _dadosProfissionalFuture,
                builder: (context, snapshot) {
                  final nomeCompleto =
                      snapshot.data?['nome'] as String? ??
                      'Nome não encontrado';
                  final fotoUrl = snapshot.data?['foto_perfil_url'] as String?;

                  return FutureBuilder<String?>(
                    future: _enderecoFuture,
                    builder: (context, enderecoSnapshot) {
                      final enderecoTexto =
                          enderecoSnapshot.data ?? 'Nenhum endereço cadastrado';

                      return FutureBuilder<_OficiosPerfil?>(
                        future: _oficiosFuture,
                        builder: (context, oficiosSnapshot) {
                          final dadosOficios = oficiosSnapshot.data;
                          final oficios =
                              dadosOficios?.oficios ?? <OficioInfo>[];
                          final tagEmpresa = dadosOficios?.tagEmpresa;
                          final corTagEmpresa = _corFromHex(
                            dadosOficios?.corTagEmpresa,
                          );
                          final tagEmpresaTexto =
                              tagEmpresa == null || tagEmpresa.isEmpty
                              ? null
                              : tagEmpresa.startsWith('#')
                              ? tagEmpresa
                              : '#$tagEmpresa';

                          return Container(
                            decoration: _cardDecoration(),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _mostrarBottomSheetPerfil(
                                  nome: nomeCompleto,
                                  fotoUrl: fotoUrl,
                                  endereco: enderecoTexto,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Stack(
                                            alignment: Alignment.bottomCenter,
                                            clipBehavior: Clip.none,
                                            children: [
                                              CircleAvatar(
                                                radius: 34,
                                                backgroundColor: const Color(
                                                  0xFFE1F5FE,
                                                ),
                                                backgroundImage: fotoUrl != null
                                                    ? NetworkImage(fotoUrl)
                                                    : null,
                                                child: fotoUrl == null
                                                    ? Text(
                                                        obterIniciais(
                                                          nomeCompleto,
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 26,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: _primaryBlue,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              Positioned(
                                                bottom: -6,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _primaryBlue,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
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
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          _buildBotaoNotificacao(),
                                        ],
                                      ),
                                      if (oficios.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.end,
                                          children: [
                                            if (tagEmpresaTexto != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 5,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: corTagEmpresa,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  tagEmpresaTexto,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: _corContraste(
                                                      corTagEmpresa,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ...oficios.map(
                                              (oficio) =>
                                                  TagOficio(oficio: oficio),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),

              // ================= CRIAR POSTAGEM =================
              FutureBuilder<Map<String, dynamic>?>(
                future: _dadosProfissionalFuture,
                builder: (context, snapshot) {
                  final nomeCompleto =
                      snapshot.data?['nome'] as String? ??
                      'Nome não encontrado';
                  final fotoUrl = snapshot.data?['foto_perfil_url'] as String?;
                  return _buildCaixaCriacaoPostagem(
                    fotoUrl: fotoUrl,
                    nome: nomeCompleto,
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

              // ================= BOTÃO GERENCIAR EMPRESA (SÓ CONTA EMPRESA) =================
              // Aparece apenas quando a conta ativa é a da empresa
              // (_contaEmpresaAtiva == true). Na conta do profissional
              // independente (CNPJ) fica oculto.
              if (_contaEmpresaAtiva)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _primaryBlue,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          await Navigator.of(
                            context,
                          ).push(_rotaSemAnimacao(const GestaoEquipePage()));
                          if (mounted) {
                            setState(() {
                              _tipoPerfilFuture = _buscarTipoPerfil();
                            });
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Gerenciar Empresa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ================= ATALHOS / PAINEL DE AÇÕES =================
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 12,
                ),
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildQuickOption(
                            Icons.bar_chart,
                            'Estatísticas\ne Gráficos',
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
                            onTap: () {
                              Navigator.of(context).push(
                                _rotaSemAnimacao(
                                  const MeusServicosProfissionalPage(),
                                ),
                              );
                            },
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
                            onTap: () {
                              Navigator.of(context).push(
                                _rotaSemAnimacao(
                                  const MetodoEntregaProfissionalPage(),
                                ),
                              );
                            },
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
                            Icons.calendar_month_outlined,
                            'Ajustar\nDisponibilidade',
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              final empresa = _contaEmpresaAtiva
                                  ? await _buscarDadosEmpresa()
                                  : null;
                              final idGrupo =
                                  (empresa?['id_grupo_empresa'] as num?)
                                      ?.toInt();

                              if (!mounted) return;
                              await navigator.push(
                                _rotaSemAnimacao(
                                  AlterarDisponibilidadePage(
                                    isEmpresa: _contaEmpresaAtiva,
                                    idGrupoEmpresa: idGrupo,
                                  ),
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  _agendaSemanaFuture = _carregarAgendaSemana();
                                });
                              }
                            },
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
                            Icons.account_balance_wallet_outlined,
                            'Dados\nFinanceiros',
                          ),
                        ),
                        Expanded(
                          child: _buildQuickOption(
                            Icons.manage_accounts_outlined,
                            'Modificar\nconta',
                            onTap: () async {
                              await Navigator.of(context).push(
                                _rotaSemAnimacao(
                                  const ModificarContaProfissionalPage(),
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  _tipoPerfilFuture = _buscarTipoPerfil();
                                });
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: FutureBuilder<String?>(
                            future: _tipoPerfilFuture,
                            builder: (context, snapshot) {
                              final isIndependente =
                                  snapshot.data == 'Independente';
                              return _buildQuickOption(
                                isIndependente
                                    ? Icons.storefront_outlined
                                    : Icons.remove_red_eye_outlined,
                                isIndependente
                                    ? 'Empresa\nassociada'
                                    : 'Visualizar\nperfil',
                                onTap: () {
                                  Navigator.of(context).push(
                                    _rotaSemAnimacao(
                                      isIndependente
                                          ? const EmpresaAssociadaPage()
                                          : TelaMeuPerfilProfissionalPage(
                                              isVisitante: widget.isVisitante,
                                            ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ================= SUAS POSTAGENS =================
              FutureBuilder<List<PostagemResumo>>(
                future: _postagensFuture,
                builder: (context, snapshot) {
                  final postagens = snapshot.data ?? [];
                  return _buildSecaoPostagens(postagens);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBarProfissional(
          currentIndex: _currentIndex,
          isContaEmpresa: _contaEmpresaAtiva,
          // Tocar na aba atual (Home) recarrega os dados da página.
          onReselecionarAbaAtual: (_) => _recarregarPaginaAtual(),
          onTap: (index) {
            if (index == 2) {
              AppNavigationUtil.navegarAba(
                context,
                TelaMensagensPage(
                  isVisitante: widget.isVisitante,
                  isProfissional: true,
                ),
                isHome: false,
              );
              return;
            }
            if (index == 3) {
              // Aba Serviços: abre os serviços solicitados ao profissional
              // (conta independente) ou à empresa (conta empresa).
              Navigator.of(
                context,
              ).push(_rotaSemAnimacao(const MeusServicosSolicitadosPage()));
              return;
            }
            if (index == 4) {
              // Conta empresa ativa: 5º botão vira "Empresa" e abre a gestão.
              // Conta profissional: 5º botão é "Perfil" como antes.
              if (_contaEmpresaAtiva) {
                Navigator.of(
                  context,
                ).push(_rotaSemAnimacao(const GestaoEquipePage()));
                return;
              }
              AppNavigationUtil.navegarAba(
                context,
                TelaMeuPerfilProfissionalPage(isVisitante: widget.isVisitante),
                isHome: false,
              );
              return;
            }
            setState(() => _currentIndex = index);
          },
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
    return FutureBuilder<List<_DiaAgendaCalendario>>(
      future: _agendaSemanaFuture,
      builder: (context, snapshot) {
        final dias = snapshot.data ?? <_DiaAgendaCalendario>[];

        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 72,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _primaryBlue,
              ),
            ),
          );
        }

        return Column(
          children: [
            Row(
              children: List.generate(dias.length, (index) {
                final dia = dias[index];
                return Expanded(
                  child: Text(
                    _abreviacaoDiaSemana(dia.data.weekday % 7),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.3,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(dias.length, (index) {
                final dia = dias[index];
                return Expanded(child: _buildCelulaDiaAgenda(dia));
              }),
            ),
          ],
        );
      },
    );
  }

  String _abreviacaoDiaSemana(int index) {
    const abreviaturas = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB'];
    return abreviaturas[index];
  }

  String _horaCurta(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Widget _buildCelulaDiaAgenda(_DiaAgendaCalendario dia) {
    final isHoje = dia.isHoje;
    final isExcecao = dia.isExcecao;
    final isExcecaoParcial = dia.isExcecaoParcial;

    if (isExcecao) {
      // Exceção parcial (hora_ini e hora_fim preenchidos): borda vermelha,
      // fundo claro, e exibe o intervalo de horário em vez do motivo.
      if (isExcecaoParcial) {
        final horaIni = _horaCurta(dia.horaInicioExcecao!);
        final horaFim = _horaCurta(dia.horaFimExcecao!);
        return GestureDetector(
          onTap: () => _mostrarPopupExcecao(dia),
          child: Container(
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isHoje ? _vermelhoExcecao : _vermelhoExcecao,
                width: isHoje ? 2 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${dia.data.day}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _vermelhoExcecao,
                  ),
                ),
                if (isHoje) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Hoje',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: _vermelhoExcecao,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '$horaIni\nàs $horaFim',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w600,
                    color: _vermelhoExcecao,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }

      // Dia inteiro com exceção: fundo vermelho e mostra a observação
      // (motivo) no dia.
      final motivo = dia.observacaoExcecao?.trim().isNotEmpty == true
          ? dia.observacaoExcecao!.trim()
          : 'Indisponível';

      return GestureDetector(
        onTap: () => _mostrarPopupExcecao(dia),
        child: Container(
          height: 72,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: _vermelhoExcecao,
            borderRadius: BorderRadius.circular(6),
            border: isHoje ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${dia.data.day}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (isHoje) ...[
                const SizedBox(height: 2),
                const Text(
                  'Hoje',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                motivo,
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
          ),
        ),
      );
    }

    if (dia.disponivel) {
      // Dia disponível (agenda_profissional).
      return Container(
        height: 72,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color: _primaryBlue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isHoje ? _primaryBlue : _primaryBlue.withValues(alpha: 0.4),
            width: isHoje ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${dia.data.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isHoje ? _primaryBlue : _primaryBlue,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Disponível',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w600,
                color: _primaryBlue,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Dia indisponível (padrão) ou hoje sem exceção.
    return Container(
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
            '${dia.data.day}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isHoje ? _primaryBlue : _titleDark,
            ),
          ),
          if (isHoje) ...[
            const SizedBox(height: 2),
            const Text(
              'Hoje',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: _primaryBlue,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCaixaCriacaoPostagem({
    required String? fotoUrl,
    required String nome,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE1F5FE),
            backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
            child: fotoUrl == null
                ? Text(
                    obterIniciais(nome),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () =>
                    _abrirCriacaoPostagem(fotoUrl: fotoUrl, nome: nome),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _inputGray,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    'No que você está trabalhando hoje?',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _abrirCriacaoPostagem(fotoUrl: fotoUrl, nome: nome),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.photo_camera_outlined,
                      color: _primaryBlue,
                      size: 26,
                    ),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: _primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Botão de enviar postagem (avião de papel)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _abrirCriacaoPostagem(fotoUrl: fotoUrl, nome: nome),
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.send_outlined, color: _primaryBlue, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoPostagens(List<PostagemResumo> postagens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Suas Postagens',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _titleDark,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MinhasPostagensProfissionalPage(),
                  ),
                );
              },
              child: Text(
                'Ver todas',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (postagens.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 32,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nenhuma postagem ainda',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: postagens.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _buildCardPostagem(postagens[index]);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCardPostagem(PostagemResumo postagem) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 100,
            width: double.infinity,
            child: postagem.imagemUrl != null
                ? Image.network(
                    postagem.imagemUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _buildPlaceholderImagemPostagem(),
                  )
                : _buildPlaceholderImagemPostagem(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    postagem.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _titleDark,
                      height: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          PostagensProfissionalService.formatarDataPostagem(
                            postagem.dataPostagem,
                          ),
                          style: const TextStyle(
                            fontSize: 10,
                            color: _textMuted,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.favorite_border,
                        size: 14,
                        color: _textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        postagem.curtidas.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: _textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImagemPostagem() {
    return Container(
      color: const Color(0xFFE8EDF2),
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildQuickOption(IconData icon, String label, {VoidCallback? onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
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

class _PainelConvitesEmpresa extends StatefulWidget {
  const _PainelConvitesEmpresa({
    required this.convites,
    required this.onAceitar,
    required this.onRecusar,
  });

  final List<Map<String, dynamic>> convites;
  final Future<bool> Function(Map<String, dynamic> convite) onAceitar;
  final Future<bool> Function(Map<String, dynamic> convite) onRecusar;

  @override
  State<_PainelConvitesEmpresa> createState() => _PainelConvitesEmpresaState();
}

class _PainelConvitesEmpresaState extends State<_PainelConvitesEmpresa> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _titleDark = Color(0xFF1A2B4A);

  late List<Map<String, dynamic>> _convites;
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _convites = List.of(widget.convites);
  }

  String _nomeEmpresa(Map<String, dynamic> convite) {
    final grupo = convite['grupo_empresa'];
    if (grupo is Map) {
      final valor = grupo['nome_empresa'];
      final nome = valor?.toString().trim();
      if (nome != null && nome.isNotEmpty) return nome;
    }
    return 'Empresa';
  }

  String _tagEmpresa(Map<String, dynamic> convite) {
    final grupo = convite['grupo_empresa'];
    if (grupo is Map) {
      final valor = grupo['tag_empresa'];
      final tag = valor?.toString().trim();
      if (tag != null && tag.isNotEmpty) return tag;
    }
    return '';
  }

  String _dataConvite(Map<String, dynamic> convite) {
    final data = convite['data_convite']?.toString();
    if (data == null || data.isEmpty) return '';
    final diaMesAno = data.split('T').first.split(' ').first;
    final partes = diaMesAno.split('-');
    if (partes.length == 3) {
      return '${partes[2]}/${partes[1]}/${partes[0]}';
    }
    return diaMesAno;
  }

  Future<void> _agir(Map<String, dynamic> convite, bool aceitar) async {
    if (_processando) return;
    setState(() => _processando = true);

    final ok = aceitar
        ? await widget.onAceitar(convite)
        : await widget.onRecusar(convite);

    if (!mounted) return;

    setState(() {
      _processando = false;
      if (ok) {
        _convites = _convites.where((c) => c != convite).toList();
      }
    });

    if (ok && _convites.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.groups_outlined, color: _primaryBlue),
                  const SizedBox(width: 10),
                  Text(
                    'Convites de Empresa',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _titleDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Você tem ${_convites.length} convite(s) pendente(s) para entrar em uma equipe.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _convites.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final convite = _convites[index];
                    return _buildConviteCard(convite);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConviteCard(Map<String, dynamic> convite) {
    final tag = _tagEmpresa(convite);
    final data = _dataConvite(convite);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _primaryBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag.isEmpty ? 'EMPRESA' : tag.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              if (data.isNotEmpty)
                Text(
                  'Convite: $data',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _nomeEmpresa(convite),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _titleDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Você foi convidado(a) para fazer parte desta equipe.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _processando ? null : () => _agir(convite, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Color(0xFFFECACA)),
                ),
                child: const Text('Recusar'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _processando ? null : () => _agir(convite, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Aceitar'),
              ),
            ],
          ),
        ],
      ),
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

    canvas.drawRect(Rect.fromLTWH(20, 15, 60, 40), blockPaint);

    canvas.drawRect(Rect.fromLTWH(100, 30, 80, 50), blockPaint);

    canvas.drawRect(Rect.fromLTWH(200, 10, 70, 35), blockPaint);

    canvas.drawLine(const Offset(0, 60), Offset(size.width, 60), roadPaint);

    canvas.drawLine(const Offset(0, 90), Offset(size.width, 90), roadPaint);

    canvas.drawLine(const Offset(80, 0), Offset(80, size.height), roadPaint);

    canvas.drawLine(const Offset(180, 0), Offset(180, size.height), roadPaint);

    canvas.drawLine(const Offset(260, 0), Offset(260, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IconeAreaAtuacaoPainter extends CustomPainter {
  final Color color;
  const _IconeAreaAtuacaoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Círculo externo
    final rExt = size.width * 0.44;
    canvas.drawCircle(center, rExt, paint);

    // Círculo interno
    final rInt = size.width * 0.22;
    canvas.drawCircle(center, rInt, paint);

    // Traço diagonal conectando na direção inferior direita
    const cos45 = 0.7071;
    final start = Offset(center.dx + rInt * cos45, center.dy + rInt * cos45);
    final end = Offset(center.dx + rExt * cos45, center.dy + rExt * cos45);
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
