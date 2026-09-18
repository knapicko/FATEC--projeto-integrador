import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/postagem_resumo.dart';
import 'models/servico_profissional.dart';
import 'services/cor_dominante_service.dart';
import 'services/postagens_profissional_service.dart';
import 'services/servicos_profissional_service.dart';
import 'solicitar_servico.dart';
import 'tela_chat_profissional.dart';
import 'tela_servico.dart';
import 'utils/cor_oficio.dart';
import 'utils/icone_oficio.dart';
import 'utils/iniciais.dart';

class _DadosEnderecoProfissional {
  final String apelido;
  final String logradouro;
  final String numero;
  final String bairro;
  final String cidade;
  final String estado;
  final String cep;
  final double latitude;
  final double longitude;
  final bool temCoordenadas;

  const _DadosEnderecoProfissional({
    required this.apelido,
    required this.logradouro,
    required this.numero,
    required this.bairro,
    required this.cidade,
    required this.estado,
    required this.cep,
    required this.latitude,
    required this.longitude,
    required this.temCoordenadas,
  });
}

class _BlinkingSignalDot extends StatefulWidget {
  const _BlinkingSignalDot();

  @override
  State<_BlinkingSignalDot> createState() => _BlinkingSignalDotState();
}

class _BlinkingSignalDotState extends State<_BlinkingSignalDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(
                  0xFF10B981,
                ).withValues(alpha: _animation.value * 0.35),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(
                  0xFF10B981,
                ).withValues(alpha: 0.35 + (_animation.value * 0.65)),
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetodoEntregaInfo {
  final String titulo;
  final String textoBadge;
  final Color corFundoBadge;
  final Color corTextoBadge;
  final String descricao;
  final IconData icone;

  const _MetodoEntregaInfo({
    required this.titulo,
    required this.textoBadge,
    required this.corFundoBadge,
    required this.corTextoBadge,
    required this.descricao,
    required this.icone,
  });
}

class PerfilProfissionalPage extends StatefulWidget {
  final String nomeInicial;
  final String imagemInicial;
  final String profissao;
  final double avaliacao;
  final int totalAvaliacoes;
  final Color? corBannerInicial;
  final String? corBannerHexInicial;
  final int? idGrupoEmpresa;
  final int? idProfissional;

  const PerfilProfissionalPage({
    super.key,
    required this.nomeInicial,
    required this.imagemInicial,
    this.profissao = 'Profissional independente',
    this.avaliacao = 4.9,
    this.totalAvaliacoes = 120,
    this.corBannerInicial,
    this.corBannerHexInicial,
    this.idGrupoEmpresa,
    this.idProfissional,
  });

  @override
  State<PerfilProfissionalPage> createState() => _PerfilProfissionalPageState();
}

class _PerfilProfissionalPageState extends State<PerfilProfissionalPage> {
  // Cache em memória da cor do banner por profissional (evita "piscar"
  // do azul padrão -> cor real ao reabrir o mesmo perfil).
  static final Map<String, Color> _cacheCorBannerPorNome = {};

  // Cores do design system das imagens
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _starGold = Color(0xFFF59E0B);
  static const Color _priceOrange = Color(0xFFEA580C);
  static const Color _statusGreen = Color(0xFF10B981);
  static const Color _statusRed = Color(0xFFEF4444);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  static const double _pinnedHeaderHeight = 48;
  static const List<String> _ordemDiasSemana = [
    'domingo',
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
  ];

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _disponibilidadeKey = GlobalKey();
  final GlobalKey _avaliacoesKey = GlobalKey();
  final GlobalKey _detalhesKey = GlobalKey();
  final GlobalKey _footerButtonKey = GlobalKey();

  int _abaAtiva = 0;
  bool _isScrollingProgrammatically = false;
  DateTime _ultimaAtualizacaoAba = DateTime.fromMillisecondsSinceEpoch(0);
  double? _offsetDisponibilidade;
  double? _offsetAvaliacoes;
  double? _offsetDetalhes;

  String _nome = '';
  String? _fotoUrl;
  Color _corBanner = CorDominanteService.corPadraoColor;
  // Quando false, o cabeçalho já nasce com os dados iniciais (nome/foto/cor)
  // em vez de mostrar spinner -> nada "pisca" na abertura.
  bool _carregandoPerfil = false;

  String _filtroComentario = 'Principais';
  String _categoriaServico = 'Todos';
  bool _descricaoExpandida = false;
  String _anosExperiencia = '0-1 ano';
  String _descricaoPerfil = '';
  String _tipoPerfil = 'Profissional independente';
  bool _temAgendaCadastrada = false;
  String _faixaHorarioDisponibilidade = '--:-- - --:--';

  // Mapa de horários por dia da semana para o bottom sheet e status de disponibilidade
  final Map<String, String?> _horariosPorDia = {};

  DateTime _mesSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  int? _idProfissional;
  int? _idGrupoEmpresa;
  int? _idPerfilProfissional;
  int? _idUsuarioLogado;
  int? _idUsuarioProf;
  _DadosEnderecoProfissional? _enderecoProfissional;
  bool _enderecoCarregado = false;
  bool _seguindoProfissional = false;
  bool _carregandoSeguimento = false;
  bool _alterandoSeguimento = false;
  int _totalSeguidores = 0;
  List<OficioInfo> _oficios = [];
  List<_MetodoEntregaInfo> _metodosEntrega = [];
  Future<List<PostagemResumo>> _postagensGaleriaFuture = Future.value(
    <PostagemResumo>[],
  );
  final Map<int, int> _curtidasPorPostagem = {};
  final Set<int> _postagensCurtidasPorMim = <int>{};
  final Set<int> _curtidasEmAndamento = <int>{};
  final Set<int> _animandoLikeNoCard = <int>{};
  int? _postagemAnimandoLikeTelaCheia;

  /// Chave YYYY-MM-DD → observação da exceção de dia inteiro.
  final Map<String, String?> _diasBloqueados = {};
  bool _carregandoExcecoes = false;

  static const Color _blockedRed = Color(0xFFDC2626);
  static const Color _blockedBg = Color(0xFFFEF2F2);
  static const Color _blockedBorder = Color(0xFFF87171);

  int _likesComentario1 = 0;
  bool _likedComentario1 = false;
  int _likesComentario2 = 1;
  bool _likedComentario2 = true;

  final List<Map<String, dynamic>> _avaliacoes = [
    {
      'nome': 'Luiz Fernando',
      'iniciais': 'LF',
      'corAvatar': Color(0xFF0284C7),
      'nota': 5.0,
      'tempo': 'há 8 dias',
      'texto':
          'Muito bom! Chegou no horário previsto e abriu a porta em minutos sem danificar a fechadura.',
    },
    {
      'nome': 'Gabriel Santos',
      'iniciais': 'GS',
      'corAvatar': Color(0xFF4F46E5),
      'nota': 5.0,
      'tempo': 'há 8 dias',
      'texto':
          'Excelente trabalho e muito rápido no atendimento. Moro em Diadema e recomendo a todos!',
    },
  ];

  List<ServicoProfissional> _servicos = [];
  bool _carregandoServicos = true;
  List<String> _categorias = ['Todos'];

  @override
  void initState() {
    super.initState();
    _idGrupoEmpresa = widget.idGrupoEmpresa;
    _idProfissional = widget.idProfissional;
    _nome = widget.nomeInicial.isNotEmpty
        ? widget.nomeInicial
        : 'Profissional não encontrado';
    if (widget.imagemInicial.startsWith('http://') ||
        widget.imagemInicial.startsWith('https://')) {
      _fotoUrl = widget.imagemInicial;
    }
    // Cor inicial do banner: parâmetro -> hex -> cache -> padrão.
    // Assim o primeiro frame já nasce com a cor certa e não "pisca".
    final chaveCache = _nome.trim().toLowerCase();
    if (widget.corBannerInicial != null) {
      _corBanner = widget.corBannerInicial!;
    } else if (widget.corBannerHexInicial != null &&
        widget.corBannerHexInicial!.trim().isNotEmpty) {
      _corBanner = CorDominanteService.paraColor(
        widget.corBannerHexInicial,
      );
    } else if (_cacheCorBannerPorNome.containsKey(chaveCache)) {
      _corBanner = _cacheCorBannerPorNome[chaveCache]!;
    }
    _tipoPerfil = widget.profissao.isNotEmpty
        ? widget.profissao
        : 'Profissional independente';
    // Foto já vinda da lista: pré-carrega para o avatar não piscar.
    final fotoInicial = _fotoUrl;
    if (fotoInicial != null && fotoInicial.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        precacheImage(NetworkImage(fotoInicial), context).catchError((_) {});
      });
    }
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _atualizarOffsetsSecoes();
    });
    _carregarUsuarioLogado();
    _carregarDadosProfissional();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Lógica de cálculo de aberto/fechado de acordo com a data/hora atual e agenda do Supabase
  bool _estaAbertoAgora() {
    if (!_temAgendaCadastrada) return false;

    final agora = DateTime.now();

    // 1. Verifica se hoje é bloqueado por exceção de dia inteiro no banco
    final chaveHoje = _formatarDataCompleta(agora);
    if (_diasBloqueados.containsKey(chaveHoje)) {
      return false;
    }

    // 2. Verifica se hoje é um dia em que o profissional trabalha
    final diaSemanaNome = _nomeDiaSemana(agora.weekday);
    final horarioHoje = _horariosPorDia[diaSemanaNome];
    if (horarioHoje == null ||
        horarioHoje.isEmpty ||
        horarioHoje == 'Fechado') {
      return false;
    }

    // 3. Extrai faixa de horário (ex: '08:00 - 16:00')
    final partes = horarioHoje.split('-');
    if (partes.length != 2) return false;

    final iniPartes = partes[0].trim().split(':');
    final fimPartes = partes[1].trim().split(':');
    if (iniPartes.length < 2 || fimPartes.length < 2) return false;

    final iniH = int.tryParse(iniPartes[0]);
    final iniM = int.tryParse(iniPartes[1]);
    final fimH = int.tryParse(fimPartes[0]);
    final fimM = int.tryParse(fimPartes[1]);

    if (iniH == null || iniM == null || fimH == null || fimM == null) {
      return false;
    }

    final minutosAgora = agora.hour * 60 + agora.minute;
    final minutosIni = iniH * 60 + iniM;
    final minutosFim = fimH * 60 + fimM;

    return minutosAgora >= minutosIni && minutosAgora <= minutosFim;
  }

  String _nomeDiaSemana(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'segunda-feira';
      case DateTime.tuesday:
        return 'terça-feira';
      case DateTime.wednesday:
        return 'quarta-feira';
      case DateTime.thursday:
        return 'quinta-feira';
      case DateTime.friday:
        return 'sexta-feira';
      case DateTime.saturday:
        return 'sábado';
      case DateTime.sunday:
        return 'domingo';
      default:
        return '';
    }
  }

  String _nomeDiaFormatado(String diaChave) {
    switch (diaChave) {
      case 'domingo':
        return 'Domingo';
      case 'segunda-feira':
        return 'Segunda-feira';
      case 'terça-feira':
        return 'Terça-feira';
      case 'quarta-feira':
        return 'Quarta-feira';
      case 'quinta-feira':
        return 'Quinta-feira';
      case 'sexta-feira':
        return 'Sexta-feira';
      case 'sábado':
        return 'Sábado';
      default:
        return diaChave;
    }
  }

  bool _diaPertenceADiasSemana(String diaAlvo, String diasConfigurados) {
    final cfg = diasConfigurados
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('ã', 'a');
    final alvo = diaAlvo
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('ã', 'a');

    if (cfg.contains(alvo)) return true;

    final abrevs = {
      'domingo': 'dom',
      'segunda-feira': 'seg',
      'terça-feira': 'ter',
      'quarta-feira': 'qua',
      'quinta-feira': 'qui',
      'sexta-feira': 'sex',
      'sábado': 'sab',
    };
    final abrev = abrevs[diaAlvo];
    if (abrev != null && cfg.contains(abrev)) return true;

    return false;
  }

  // Bottom Sheet estilizado ao clicar no status de disponibilidade
  void _mostrarModalHorariosFuncionamento() {
    final aberto = _estaAbertoAgora();
    final diaHojeNome = _nomeDiaSemana(DateTime.now().weekday);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de arraste
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Cabeçalho do modal
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: _primaryBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Horários de Funcionamento',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: aberto ? _statusGreen : _statusRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              !_temAgendaCadastrada
                                  ? 'Fechado'
                                  : (aberto ? 'Aberto agora' : 'Fechado agora'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: aberto ? _statusGreen : _statusRed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: _borderColor),
              const SizedBox(height: 12),

              // Lista de todos os 7 dias da semana
              ...List.generate(_ordemDiasSemana.length, (index) {
                final diaChave = _ordemDiasSemana[index];
                final diaFormatado = _nomeDiaFormatado(diaChave);
                final horario = _horariosPorDia[diaChave];
                final ehHoje = diaChave == diaHojeNome;
                final estaFechado =
                    !_temAgendaCadastrada || horario == null || horario.isEmpty;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: ehHoje
                        ? const Color(0xFFF0F9FF)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: ehHoje
                        ? Border.all(color: const Color(0xFFBAE6FD))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Text(
                        diaFormatado,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: ehHoje
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: ehHoje ? _primaryBlue : _textDark,
                        ),
                      ),
                      if (ehHoje) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryBlue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Hoje',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (estaFechado)
                        const Text(
                          'Fechado',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _statusRed,
                          ),
                        )
                      else
                        Text(
                          horario,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _carregarDadosProfissional() async {
    try {
      debugPrint(
        '🔎 [PerfilProfissional] Iniciando busca para nome: "${widget.nomeInicial}", idProf: ${widget.idProfissional}',
      );
      final supabase = Supabase.instance.client;
      Map<String, dynamic>? response;
      int? idUsuarioParaBuscar = _idUsuarioProf;
      int? idProfissionalEncontrado = _idProfissional ?? widget.idProfissional;
      int? idPerfilEncontrado = _idPerfilProfissional;

      // 1. Se já conhecemos o id_usuario (por exemplo, de carregamento anterior)
      if (idUsuarioParaBuscar != null) {
        response = await supabase
            .from('usuarios')
            .select('nome, foto_perfil_url, id_usuario')
            .eq('id_usuario', idUsuarioParaBuscar)
            .maybeSingle();
      }

      // 2. Se não achou e temos id_profissional
      if (response == null && idProfissionalEncontrado != null) {
        final dp = await supabase
            .from('dados_profissionais')
            .select('fk_usuario')
            .eq('id_profissional', idProfissionalEncontrado)
            .maybeSingle();
        final fkU = dp?['fk_usuario'];
        if (fkU != null) {
          response = await supabase
              .from('usuarios')
              .select('nome, foto_perfil_url, id_usuario')
              .eq('id_usuario', fkU)
              .maybeSingle();
        }
      }

      // 3. Se não achou e temos fk_perfil
      if (response == null && idPerfilEncontrado != null) {
        final dp = await supabase
            .from('dados_profissionais')
            .select('fk_usuario')
            .eq('fk_perfil', idPerfilEncontrado)
            .maybeSingle();
        final fkU = dp?['fk_usuario'];
        if (fkU != null) {
          response = await supabase
              .from('usuarios')
              .select('nome, foto_perfil_url, id_usuario')
              .eq('id_usuario', fkU)
              .maybeSingle();
        }
      }

      // 4. Se ainda não achou, busca por nome (atual ou inicial)
      if (response == null) {
        final nomeBusca = _nome.isNotEmpty && _nome != 'Profissional não encontrado'
            ? _nome
            : widget.nomeInicial;
        final query = await supabase
            .from('usuarios')
            .select('nome, foto_perfil_url, id_usuario')
            .eq('tipo_conta', 'Profissional')
            .ilike('nome', '%$nomeBusca%')
            .limit(1);
        if (query.isNotEmpty) {
          response = query.first;
        } else if (nomeBusca != widget.nomeInicial && widget.nomeInicial.isNotEmpty) {
          final queryIni = await supabase
              .from('usuarios')
              .select('nome, foto_perfil_url, id_usuario')
              .eq('tipo_conta', 'Profissional')
              .ilike('nome', '%${widget.nomeInicial}%')
              .limit(1);
          if (queryIni.isNotEmpty) {
            response = queryIni.first;
          }
        }
      }

      debugPrint(
        '🔎 [PerfilProfissional] Usuário encontrado: ${response != null}',
      );
      if (response != null && mounted) {
        int? idProfissional = idProfissionalEncontrado;
        int? fkPerfil = idPerfilEncontrado;
        String? anosExperiencia;
        String? descricaoPerfil;
        String? tipoPerfil;
        String? corBanner;
        int? idGrupoEmpresa = widget.idGrupoEmpresa ?? _idGrupoEmpresa;

        final fkUsuario = response['id_usuario'];
        final idUsuarioProf = (fkUsuario as num?)?.toInt();
        _idUsuarioProf = idUsuarioProf;
        debugPrint(
          '🔎 [PerfilProfissional] id_usuario encontrado: $idUsuarioProf',
        );
        String? metodoEntregaRaw;
        if (fkUsuario != null) {
          final dadosProf = await supabase
              .from('dados_profissionais')
              .select(
                'id_profissional, fk_perfil, fk_grupo_empresa, anos_experiencia, metodo_entrega',
              )
              .eq('fk_usuario', fkUsuario)
              .maybeSingle();
          idProfissional = (dadosProf?['id_profissional'] as num?)?.toInt() ?? idProfissional;
          fkPerfil = (dadosProf?['fk_perfil'] as num?)?.toInt() ?? fkPerfil;
          idGrupoEmpresa = (dadosProf?['fk_grupo_empresa'] as num?)?.toInt() ?? idGrupoEmpresa;
          anosExperiencia = dadosProf?['anos_experiencia']?.toString();
          metodoEntregaRaw = dadosProf?['metodo_entrega']?.toString();
          debugPrint(
            '🔎 [PerfilProfissional] id_profissional: $idProfissional; fk_perfil: $fkPerfil; fk_grupo_empresa: $idGrupoEmpresa',
          );

          if (idGrupoEmpresa == null && fkPerfil != null) {
            final grupoDono = await supabase
                .from('grupo_empresa')
                .select('id_grupo_empresa')
                .eq('fk_perfil', fkPerfil)
                .maybeSingle();
            if (grupoDono != null) {
              idGrupoEmpresa = (grupoDono['id_grupo_empresa'] as num?)?.toInt();
            }
          }

          if (fkPerfil != null) {
            final perfil = await supabase
                .from('perfil')
                .select('descricao_perfil, tipo_perfil, cor_banner')
                .eq('id_perfil', fkPerfil)
                .maybeSingle();
            descricaoPerfil = perfil?['descricao_perfil']?.toString();
            tipoPerfil = perfil?['tipo_perfil']?.toString();
            corBanner = perfil?['cor_banner']?.toString();
          }
        }

        setState(() {
          _idGrupoEmpresa = idGrupoEmpresa;
          _nome = response?['nome']?.toString() ?? 'Profissional não encontrado';
          final foto = response?['foto_perfil_url']?.toString();
          String? novaFoto;
          if (foto != null && foto.isNotEmpty && foto != 'null') {
            novaFoto = foto;
          } else {
            novaFoto = null;
          }
          _fotoUrl = novaFoto;
          final f = novaFoto;
          if (f != null && f.isNotEmpty && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              precacheImage(NetworkImage(f), context).catchError((_) {});
            });
          }
          _idProfissional = idProfissional;
          _idPerfilProfissional = fkPerfil;
          final novaCor = CorDominanteService.paraColor(corBanner);
          // Só atualiza a cor se for diferente da que já está na tela
          // (inicial/cache). O banner usa AnimatedContainer, então mesmo
          // na primeira vez sem cache a transição é suave, sem "piscar".
          if (novaCor != _corBanner) {
            _corBanner = novaCor;
          }
          _cacheCorBannerPorNome[_nome.trim().toLowerCase()] = _corBanner;
          _metodosEntrega = _parseMetodosEntrega(metodoEntregaRaw);
          if (tipoPerfil != null && tipoPerfil.isNotEmpty) {
            _tipoPerfil = tipoPerfil;
          }
          if (anosExperiencia != null && anosExperiencia.isNotEmpty) {
            _anosExperiencia = anosExperiencia;
          } else {
            _anosExperiencia = '0-1 ano';
          }
          if (descricaoPerfil != null && descricaoPerfil.isNotEmpty) {
            _descricaoPerfil = descricaoPerfil;
          } else {
            _descricaoPerfil = 'Este profissional não possui descrição';
          }
          _postagensGaleriaFuture = fkPerfil != null
              ? _carregarPostagensGaleria(fkPerfil, limit: 10)
              : Future.value(<PostagemResumo>[]);
        });

        final tarefas = <Future<void>>[];
        if (idProfissional != null) {
          tarefas.addAll([
            _carregarExcecoes(),
            _carregarOficios(idProfissional),
            _carregarAgendaProfissional(idProfissional),
            _carregarServicosProfissional(idProfissional),
          ]);
        }
        if (fkPerfil != null) {
          tarefas.add(_carregarSeguimento(fkPerfil));
        }
        if (idUsuarioProf != null) {
          tarefas.add(_carregarEnderecoProfissional(idUsuarioProf));
        } else {
          if (mounted) {
            setState(() => _enderecoCarregado = true);
          }
        }
        if (tarefas.isNotEmpty) {
          await Future.wait(tarefas);
        }

        // Se o banco ainda está com o default antigo ou nulo/vazio,
        // recalcula a partir da foto atual (ou usa o novo default
        // 0xFF0FB3FF quando não há foto) e salva no Supabase.
        if (fkPerfil != null && mounted) {
          final precisaRecalcular = corBanner == null ||
              corBanner.trim().isEmpty ||
              corBanner.trim().toLowerCase() == 'null' ||
              corBanner.trim().toUpperCase() == '0XFF0A6E9D';
          if (precisaRecalcular) {
            final fotoAtual = _fotoUrl;
            final corRecalculada =
                await CorDominanteService.extrairDaUrl(fotoAtual);
            if (mounted) {
              final corNova =
                  CorDominanteService.paraColor(corRecalculada);
              // Só dá setState se a cor realmente mudou -> sem "piscar".
              if (corNova != _corBanner) {
                setState(() {
                  _corBanner = corNova;
                });
              }
              _cacheCorBannerPorNome[_nome.trim().toLowerCase()] = _corBanner;
            }
            try {
              await supabase.from('perfil').update(
                {'cor_banner': corRecalculada},
              ).eq('id_perfil', fkPerfil);
            } catch (e) {
              debugPrint('⚠️ [PerfilProfissional] Falha ao salvar cor recalculada: $e');
            }
          }
        }
      } else {
        debugPrint(
          '⚠️ [PerfilProfissional] Nenhum usuário encontrado para nome: "${widget.nomeInicial}"',
        );
        if (mounted) {
          setState(() {
            _enderecoCarregado = true;
            _carregandoServicos = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [PerfilProfissional] Erro ao carregar perfil: $e');
      debugPrint(
        '❌ [PerfilProfissional] Erro ao carregar perfil STACK: ${StackTrace.current}',
      );
      // Mantém dados iniciais em caso de falha
      if (mounted) {
        setState(() {
          _enderecoCarregado = true;
          _carregandoServicos = false;
        });
      }
    } finally {
      if (mounted) {
        // _carregandoPerfil já nasce false (cabeçalho instantâneo):
        // só marca rebuild se algo ainda pendente mudou, sem
        // recriar o header e sem "piscar".
        final precisaAtualizar = _carregandoPerfil || !_enderecoCarregado;
        _carregandoPerfil = false;
        _enderecoCarregado = true;
        _carregandoServicos = false;
        if (precisaAtualizar) {
          setState(() {});
        }
      }
    }
  }

  List<_MetodoEntregaInfo> _parseMetodosEntrega(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <_MetodoEntregaInfo>[];

    final partes = raw.split(',').map((e) => e.trim().toLowerCase()).toList();
    final List<_MetodoEntregaInfo> resultado = [];

    for (final parte in partes) {
      if (parte.contains('leva')) {
        const info = _MetodoEntregaInfo(
          titulo: 'Leva e Traz',
          textoBadge: 'Popular',
          corFundoBadge: Color(0xFFE0F2FE),
          corTextoBadge: Color(0xFF0284C7),
          descricao: 'O profissional retira e entrega no seu endereço',
          icone: Icons.electric_moped_rounded,
        );
        if (!resultado.any((m) => m.titulo == info.titulo)) resultado.add(info);
      } else if (parte.contains('retirad')) {
        const info = _MetodoEntregaInfo(
          titulo: 'Retirada no Local',
          textoBadge: 'Grátis',
          corFundoBadge: Color(0xFFF1F5F9),
          corTextoBadge: Color(0xFF475569),
          descricao: 'Você leva e busca no endereço do profissional',
          icone: Icons.storefront_outlined,
        );
        if (!resultado.any((m) => m.titulo == info.titulo)) resultado.add(info);
      } else if (parte.contains('receba')) {
        const info = _MetodoEntregaInfo(
          titulo: 'Receba em Casa',
          textoBadge: 'Entrega',
          corFundoBadge: Color(0xFFE0F2FE),
          corTextoBadge: Color(0xFF0284C7),
          descricao: 'Você leva para o profissional e recebe depois',
          icone: Icons.inventory_2_outlined,
        );
        if (!resultado.any((m) => m.titulo == info.titulo)) resultado.add(info);
      } else if (parte.contains('domicil') || parte.contains('domicíl')) {
        const info = _MetodoEntregaInfo(
          titulo: 'Atendimento em Domicílio',
          textoBadge: 'No Local',
          corFundoBadge: Color(0xFFECFDF5),
          corTextoBadge: Color(0xFF059669),
          descricao: 'Técnico vai até a sua residência',
          icone: Icons.home_repair_service_outlined,
        );
        if (!resultado.any((m) => m.titulo == info.titulo)) resultado.add(info);
      }
    }

    return resultado;
  }

  Future<void> _carregarEnderecoProfissional(int idUsuario) async {
    try {
      final supabase = Supabase.instance.client;

      // 1. Busca associação de endereço ativo do usuário na ass_usuario_endereco
      final assList = await supabase
          .from('ass_usuario_endereco')
          .select(
            'fk_endereco, apelido_endereco, tipo_endereco, endereco_ativo',
          )
          .eq('fk_usuario', idUsuario)
          .eq('endereco_ativo', true)
          .limit(1);

      if (assList.isEmpty) {
        if (mounted) {
          setState(() {
            _enderecoProfissional = null;
            _enderecoCarregado = true;
          });
        }
        return;
      }

      final ass = assList.first;
      final fkEndereco = ass['fk_endereco'];
      final idEndereco = fkEndereco is int
          ? fkEndereco
          : int.tryParse(fkEndereco?.toString() ?? '');

      if (idEndereco == null) {
        if (mounted) {
          setState(() {
            _enderecoProfissional = null;
            _enderecoCarregado = true;
          });
        }
        return;
      }

      // 2. Busca dados na tabela enderecos
      final endList = await supabase
          .from('enderecos')
          .select(
            'id_endereco, cep, logradouro, numero, bairro, complemento, fk_cidade, latitude, longitude',
          )
          .eq('id_endereco', idEndereco)
          .limit(1);

      if (endList.isEmpty) {
        if (mounted) {
          setState(() {
            _enderecoProfissional = null;
            _enderecoCarregado = true;
          });
        }
        return;
      }

      final enderecoRow = endList.first;

      // 3. Busca cidade e estado
      String nomeCidade = '';
      String siglaEstado = '';

      final fkCidade = enderecoRow['fk_cidade'];
      final idCidade = fkCidade is int
          ? fkCidade
          : int.tryParse(fkCidade?.toString() ?? '');

      if (idCidade != null) {
        final cidList = await supabase
            .from('cidades')
            .select('nome_cidade, fk_estado')
            .eq('id_cidade', idCidade)
            .limit(1);

        if (cidList.isNotEmpty) {
          final cidRow = cidList.first;
          nomeCidade = cidRow['nome_cidade']?.toString() ?? '';

          final fkEstado = cidRow['fk_estado'];
          final idEstado = fkEstado is int
              ? fkEstado
              : int.tryParse(fkEstado?.toString() ?? '');

          if (idEstado != null) {
            final estList = await supabase
                .from('estados')
                .select('sigla_estado')
                .eq('id_estado', idEstado)
                .limit(1);

            if (estList.isNotEmpty) {
              siglaEstado = estList.first['sigla_estado']?.toString() ?? '';
            }
          }
        }
      }

      final apelido = ass['apelido_endereco']?.toString();
      final logradouro = enderecoRow['logradouro']?.toString() ?? '';
      final numero = enderecoRow['numero']?.toString() ?? '';
      final bairro = enderecoRow['bairro']?.toString() ?? '';
      final cep = enderecoRow['cep']?.toString() ?? '';
      final latDb = double.tryParse(enderecoRow['latitude']?.toString() ?? '');
      final lngDb = double.tryParse(enderecoRow['longitude']?.toString() ?? '');

      final bool temCoords = latDb != null && lngDb != null;
      // Coordenadas padrão para o centro caso o banco não possua latitude/longitude
      final latFinal = latDb ?? -23.5505;
      final lngFinal = lngDb ?? -46.6333;

      if (mounted) {
        setState(() {
          _enderecoProfissional = _DadosEnderecoProfissional(
            apelido: (apelido != null && apelido.trim().isNotEmpty)
                ? apelido.trim()
                : 'Oficina & Base Operacional',
            logradouro: logradouro,
            numero: numero,
            bairro: bairro,
            cidade: nomeCidade,
            estado: siglaEstado,
            cep: cep,
            latitude: latFinal,
            longitude: lngFinal,
            temCoordenadas: temCoords,
          );
          _enderecoCarregado = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _enderecoProfissional = null;
          _enderecoCarregado = true;
        });
      }
    }
  }

  Future<void> _carregarUsuarioLogado() async {
    try {
      final supabase = Supabase.instance.client;
      final authUser = supabase.auth.currentUser;
      if (authUser == null) return;

      final usuario = await supabase
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      final idUsuario = (usuario?['id_usuario'] as num?)?.toInt();
      if (!mounted || idUsuario == null) return;
      setState(() => _idUsuarioLogado = idUsuario);
    } catch (_) {
      // Se não conseguir identificar o usuário, mantém como null.
    }
  }

  Future<void> _carregarSeguimento(int idPerfil) async {
    if (_carregandoSeguimento) return;
    _carregandoSeguimento = true;

    try {
      if (_idUsuarioLogado == null) {
        await _carregarUsuarioLogado();
      }

      final supabase = Supabase.instance.client;
      final seguidores = await supabase
          .from('seguidores_profissional')
          .select('id_seguidor_profissional')
          .eq('fk_perfil', idPerfil);

      var seguindo = false;
      final idUsuario = _idUsuarioLogado;
      if (idUsuario != null) {
        final vinculo = await supabase
            .from('seguidores_profissional')
            .select('id_seguidor_profissional')
            .eq('fk_perfil', idPerfil)
            .eq('fk_usuario', idUsuario)
            .maybeSingle();
        seguindo = vinculo != null;
      }

      if (!mounted) return;
      setState(() {
        _totalSeguidores = seguidores.length;
        _seguindoProfissional = seguindo;
      });
    } catch (_) {
      // Mantém o estado inicial se a consulta de seguidores falhar.
    } finally {
      _carregandoSeguimento = false;
    }
  }

  Future<void> _alternarSeguimento() async {
    final idPerfil = _idPerfilProfissional;
    if (_alterandoSeguimento || idPerfil == null) {
      setState(() {
        _seguindoProfissional = !_seguindoProfissional;
        _totalSeguidores += _seguindoProfissional ? 1 : -1;
        if (_totalSeguidores < 0) _totalSeguidores = 0;
      });
      return;
    }

    if (_idUsuarioLogado == null) {
      await _carregarUsuarioLogado();
    }

    final idUsuario = _idUsuarioLogado;
    if (idUsuario == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para seguir profissionais.')),
      );
      return;
    }

    final seguindoAntes = _seguindoProfissional;
    final totalAntes = _totalSeguidores;
    setState(() {
      _alterandoSeguimento = true;
      _seguindoProfissional = !seguindoAntes;
      _totalSeguidores = totalAntes + (seguindoAntes ? -1 : 1);
      if (_totalSeguidores < 0) _totalSeguidores = 0;
    });

    try {
      final supabase = Supabase.instance.client;
      if (seguindoAntes) {
        await supabase
            .from('seguidores_profissional')
            .delete()
            .eq('fk_perfil', idPerfil)
            .eq('fk_usuario', idUsuario);
      } else {
        await supabase.from('seguidores_profissional').insert({
          'seguido_em': DateTime.now().toUtc().toIso8601String(),
          'fk_perfil': idPerfil,
          'fk_usuario': idUsuario,
        });
      }

      await _carregarSeguimento(idPerfil);
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _seguindoProfissional = seguindoAntes;
        _totalSeguidores = totalAntes;
      });
      final mensagem = erro is PostgrestException && _erroPermissaoRls(erro)
          ? 'Sem permissão para seguir. Crie as políticas RLS da tabela seguidores_profissional no Supabase.'
          : _tabelaSeguidoresIndisponivel(erro)
          ? 'A tabela seguidores_profissional não está disponível no schema public do Supabase.'
          : 'Não foi possível atualizar o seguimento.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
    } finally {
      if (mounted) {
        setState(() => _alterandoSeguimento = false);
      }
    }
  }

  bool _tabelaSeguidoresIndisponivel(Object erro) {
    if (erro is! PostgrestException) return false;
    final texto = '${erro.message} ${erro.details ?? ''} ${erro.hint ?? ''}'
        .toLowerCase();
    return erro.code == '42P01' ||
        texto.contains('seguidores_profissional') &&
            (texto.contains('not found') ||
                texto.contains('does not exist') ||
                texto.contains('schema cache') ||
                texto.contains('relation'));
  }

  Future<List<PostagemResumo>> _carregarPostagensGaleria(
    int idPerfil, {
    int? limit,
  }) async {
    final postagens =
        await PostagensProfissionalService.buscarPostagensPorPerfil(
          idPerfil,
          limit: limit,
        );

    // Suporte também para carregar imagens da tabela imagens_postagem se imagemUrl for nula
    try {
      final supabase = Supabase.instance.client;
      for (var i = 0; i < postagens.length; i++) {
        final p = postagens[i];
        if (p.imagemUrl == null || p.imagemUrl!.isEmpty) {
          try {
            final imgRows = await supabase
                .from('imagens_postagem')
                .select('caminho_imagem, url_imagem, url')
                .eq('fk_postagem', p.idPostagem)
                .limit(1);
            if (imgRows.isNotEmpty) {
              final row = imgRows.first;
              final url =
                  row['url_imagem'] ?? row['caminho_imagem'] ?? row['url'];
              if (url != null && url.toString().isNotEmpty) {
                postagens[i] = PostagemResumo(
                  idPostagem: p.idPostagem,
                  titulo: p.titulo,
                  imagemUrl: url.toString(),
                  dataPostagem: p.dataPostagem,
                  curtidas: p.curtidas,
                  arquivado: p.arquivado,
                );
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    if (!mounted) return postagens;

    setState(() {
      _curtidasPorPostagem
        ..clear()
        ..addEntries(postagens.map((p) => MapEntry(p.idPostagem, p.curtidas)));
    });

    await _carregarCurtidasDoUsuario(postagens);
    return postagens;
  }

  Future<void> _carregarCurtidasDoUsuario(
    List<PostagemResumo> postagens,
  ) async {
    if (postagens.isEmpty) return;

    if (_idUsuarioLogado == null) {
      await _carregarUsuarioLogado();
    }

    final idUsuario = _idUsuarioLogado;
    if (idUsuario == null) return;

    try {
      final supabase = Supabase.instance.client;
      final idsPostagens = postagens.map((p) => p.idPostagem).toList();
      final response = await supabase
          .from('curtidas_postagem')
          .select('fk_postagem')
          .eq('fk_usuario', idUsuario)
          .inFilter('fk_postagem', idsPostagens);

      if (!mounted) return;

      setState(() {
        _postagensCurtidasPorMim
          ..clear()
          ..addAll(
            response
                .map((row) => (row['fk_postagem'] as num?)?.toInt())
                .whereType<int>(),
          );
      });
    } catch (_) {
      // Em caso de erro, mantém estado local sem marcação de curtidas do usuário.
    }
  }

  Future<int> _buscarTotalCurtidasDaPostagem(int idPostagem) async {
    try {
      final supabase = Supabase.instance.client;
      final rows = await supabase
          .from('curtidas_postagem')
          .select('id_curtida_postagem')
          .eq('fk_postagem', idPostagem);
      return rows.length;
    } catch (_) {
      return _curtidasPorPostagem[idPostagem] ?? 0;
    }
  }

  Future<int> _proximoIdCurtidaPostagem() async {
    final supabase = Supabase.instance.client;
    final row = await supabase
        .from('curtidas_postagem')
        .select('id_curtida_postagem')
        .order('id_curtida_postagem', ascending: false)
        .limit(1)
        .maybeSingle();
    final atual = (row?['id_curtida_postagem'] as num?)?.toInt() ?? 0;
    return atual + 1;
  }

  bool _erroRelacionadoAIdCurtida(PostgrestException erro) {
    final texto = '${erro.message} ${erro.details ?? ''} ${erro.hint ?? ''}'
        .toLowerCase();
    return erro.code == '23502' && texto.contains('id_curtida_postagem');
  }

  Future<void> _inserirCurtidaNoSupabase({
    required int idPerfil,
    required int idUsuario,
    required int idPostagem,
  }) async {
    final supabase = Supabase.instance.client;
    final payload = {
      'curtido_em': DateTime.now().toUtc().toIso8601String(),
      'fk_perfil': idPerfil,
      'fk_usuario': idUsuario,
      'fk_postagem': idPostagem,
    };

    try {
      await supabase.from('curtidas_postagem').insert(payload);
    } on PostgrestException catch (erro) {
      if (_erroRelacionadoAIdCurtida(erro)) {
        final payloadComId = {
          ...payload,
          'id_curtida_postagem': await _proximoIdCurtidaPostagem(),
        };
        await supabase.from('curtidas_postagem').insert(payloadComId);
        return;
      }
      rethrow;
    }
  }

  Future<bool> _removerCurtidaNoSupabase({
    required int idUsuario,
    required int idPostagem,
  }) async {
    final supabase = Supabase.instance.client;
    final removidas = await supabase
        .from('curtidas_postagem')
        .delete()
        .eq('fk_usuario', idUsuario)
        .eq('fk_postagem', idPostagem)
        .select('id_curtida_postagem');

    return removidas.isNotEmpty;
  }

  Future<int?> _buscarPerfilDaPostagem(int idPostagem) async {
    try {
      final supabase = Supabase.instance.client;
      final row = await supabase
          .from('postagens')
          .select('fk_perfil')
          .eq('id_postagem', idPostagem)
          .maybeSingle();
      return (row?['fk_perfil'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  String _formatarAnosExperiencia(String valor) {
    if (valor == 'Mais de 15 anos') return '+15';
    if (valor == '10-15 anos') return '10-15';
    if (valor == '5-10 anos') return '5-10';
    if (valor == '3-5 anos') return '3-5';
    if (valor == '1-3 anos') return '1-3';
    if (valor == '0-1 ano') return '0-1';
    if (valor.startsWith('+')) return valor;
    return valor.isNotEmpty ? valor : '0-1';
  }

  String _formatarHoraAgenda(Object? raw) {
    if (raw == null) return '08:00';
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.toString());
    if (match == null) return '08:00';
    final hh = int.parse(match.group(1)!).toString().padLeft(2, '0');
    final mm = match.group(2)!;
    return '$hh:$mm';
  }

  Future<void> _carregarAgendaProfissional(int idProfissional) async {
    try {
      final supabase = Supabase.instance.client;

      List<Map<String, dynamic>> listaAgendas = [];
      try {
        final res = await supabase
            .from('agenda_profissional')
            .select('dias_semana, hora_ini, hora_fim')
            .eq('fk_profissional', idProfissional)
            .eq('fk_solicitacao', 0);
        listaAgendas = List<Map<String, dynamic>>.from(res);
      } catch (_) {
        try {
          final res = await supabase
              .from('agenda_profissional')
              .select('dias_semana, hora_ini, hora_fim')
              .eq('fk_profissional', idProfissional);
          listaAgendas = List<Map<String, dynamic>>.from(res);
        } catch (_) {}
      }

      if (listaAgendas.isEmpty) {
        if (!mounted) return;
        setState(() {
          _temAgendaCadastrada = false;
          _horariosPorDia.clear();
        });
        return;
      }

      final agendaPrincipal = listaAgendas.first;
      final diasRaw = agendaPrincipal['dias_semana']?.toString();
      if (diasRaw == null || diasRaw.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _temAgendaCadastrada = false;
          _horariosPorDia.clear();
        });
        return;
      }

      final horaIni = _formatarHoraAgenda(agendaPrincipal['hora_ini']);
      final horaFim = _formatarHoraAgenda(agendaPrincipal['hora_fim']);
      final faixa = '$horaIni - $horaFim';

      // Atualiza o mapa de horários de cada dia da semana para o bottom sheet
      final novosHorarios = <String, String?>{};
      for (final dia in _ordemDiasSemana) {
        if (_diaPertenceADiasSemana(dia, diasRaw)) {
          novosHorarios[dia] = faixa;
        } else {
          novosHorarios[dia] = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _temAgendaCadastrada = true;
        _faixaHorarioDisponibilidade = faixa;
        _horariosPorDia.clear();
        _horariosPorDia.addAll(novosHorarios);
      });
    } catch (e) {
      debugPrint('Erro ao carregar agenda_profissional: $e');
    }
  }

  String _formatarHora(DateTime data) {
    final hh = data.hour.toString().padLeft(2, '0');
    final min = data.minute.toString().padLeft(2, '0');
    return '$hh:$min';
  }

  String _formatarDataHora(DateTime data) {
    final dd = data.day.toString().padLeft(2, '0');
    final mm = data.month.toString().padLeft(2, '0');
    final yyyy = data.year.toString();
    return '$dd/$mm/$yyyy às ${_formatarHora(data)}';
  }

  int _curtidasExibidas(PostagemResumo postagem) {
    return _curtidasPorPostagem[postagem.idPostagem] ?? postagem.curtidas;
  }

  bool _usuarioCurtiuPostagem(int idPostagem) {
    return _postagensCurtidasPorMim.contains(idPostagem);
  }

  void _dispararAnimacaoLikeNoCard(int idPostagem) {
    setState(() => _animandoLikeNoCard.add(idPostagem));
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _animandoLikeNoCard.remove(idPostagem));
    });
  }

  void _dispararAnimacaoLikeTelaCheia(int idPostagem) {
    setState(() => _postagemAnimandoLikeTelaCheia = idPostagem);
  }

  void _limparAnimacaoLikeTelaCheia() {
    if (_postagemAnimandoLikeTelaCheia == null) return;
    setState(() => _postagemAnimandoLikeTelaCheia = null);
  }

  Widget _buildAnimacaoCoracao(bool visivel) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visivel ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedScale(
          scale: visivel ? 1 : 0.6,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 44),
          ),
        ),
      ),
    );
  }

  bool _erroPermissaoRls(PostgrestException erro) {
    final texto = '${erro.message} ${erro.details ?? ''} ${erro.hint ?? ''}'
        .toLowerCase();
    return erro.code == '42501' ||
        texto.contains('row-level security') ||
        texto.contains('permission denied');
  }

  Future<void> _curtirPostagem(PostagemResumo postagem) async {
    final idPostagem = postagem.idPostagem;
    if (_curtidasEmAndamento.contains(idPostagem)) return;
    if (_usuarioCurtiuPostagem(idPostagem)) return;

    if (_idUsuarioLogado == null) {
      await _carregarUsuarioLogado();
    }

    final idUsuario = _idUsuarioLogado;
    if (idUsuario == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Faça login para curtir postagens.')),
      );
      return;
    }

    var idPerfil = _idPerfilProfissional;
    idPerfil ??= await _buscarPerfilDaPostagem(idPostagem);

    if (idPerfil == null) return;

    final totalAntes = _curtidasExibidas(postagem);

    setState(() => _curtidasEmAndamento.add(idPostagem));
    setState(() {
      _postagensCurtidasPorMim.add(idPostagem);
      _curtidasPorPostagem[idPostagem] = totalAntes + 1;
    });

    try {
      await _inserirCurtidaNoSupabase(
        idPerfil: idPerfil,
        idUsuario: idUsuario,
        idPostagem: idPostagem,
      );

      final totalReal = await _buscarTotalCurtidasDaPostagem(idPostagem);
      if (!mounted) return;
      setState(() => _curtidasPorPostagem[idPostagem] = totalReal);
    } catch (_) {
      // Reverte em caso de falha de conexão
      if (!mounted) return;
      setState(() {
        _postagensCurtidasPorMim.remove(idPostagem);
        _curtidasPorPostagem[idPostagem] = totalAntes;
      });
    } finally {
      if (mounted) {
        setState(() => _curtidasEmAndamento.remove(idPostagem));
      }
    }
  }

  Future<void> _descurtirPostagem(PostagemResumo postagem) async {
    final idPostagem = postagem.idPostagem;
    if (_curtidasEmAndamento.contains(idPostagem)) return;
    if (!_usuarioCurtiuPostagem(idPostagem)) return;

    if (_idUsuarioLogado == null) {
      await _carregarUsuarioLogado();
    }

    final idUsuario = _idUsuarioLogado;
    if (idUsuario == null) return;

    final totalAntes = _curtidasExibidas(postagem);

    setState(() => _curtidasEmAndamento.add(idPostagem));
    setState(() {
      _postagensCurtidasPorMim.remove(idPostagem);
      _curtidasPorPostagem[idPostagem] = totalAntes > 0 ? totalAntes - 1 : 0;
    });

    try {
      await _removerCurtidaNoSupabase(
        idUsuario: idUsuario,
        idPostagem: idPostagem,
      );

      final totalReal = await _buscarTotalCurtidasDaPostagem(idPostagem);
      if (!mounted) return;
      setState(() => _curtidasPorPostagem[idPostagem] = totalReal);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _postagensCurtidasPorMim.add(idPostagem);
        _curtidasPorPostagem[idPostagem] = totalAntes;
      });
    } finally {
      if (mounted) {
        setState(() => _curtidasEmAndamento.remove(idPostagem));
      }
    }
  }

  Future<void> _alternarCurtida(PostagemResumo postagem) async {
    if (_usuarioCurtiuPostagem(postagem.idPostagem)) {
      await _descurtirPostagem(postagem);
      return;
    }
    await _curtirPostagem(postagem);
  }

  Future<void> _curtirComAnimacaoNoCard(PostagemResumo postagem) async {
    _dispararAnimacaoLikeNoCard(postagem.idPostagem);
    await _curtirPostagem(postagem);
  }

  Future<void> _abrirGaleriaPostagens(
    List<PostagemResumo> postagens,
    int initialIndex,
  ) async {
    if (postagens.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (context) {
        var paginaAtual = initialIndex;
        final pageController = PageController(initialPage: initialIndex);

        return StatefulBuilder(
          builder: (context, setModalState) {
            final postagemAtual = postagens[paginaAtual];
            final curtidas = _curtidasExibidas(postagemAtual);
            final curtiu = _usuarioCurtiuPostagem(postagemAtual.idPostagem);

            return Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: pageController,
                      itemCount: postagens.length,
                      onPageChanged: (index) {
                        _limparAnimacaoLikeTelaCheia();
                        setModalState(() => paginaAtual = index);
                      },
                      itemBuilder: (context, index) {
                        final postagem = postagens[index];
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: () async {
                            _dispararAnimacaoLikeTelaCheia(postagem.idPostagem);
                            await _curtirPostagem(postagem);
                            if (!mounted) return;
                            setModalState(() {});
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: postagem.imagemUrl != null
                                    ? InteractiveViewer(
                                        minScale: 1,
                                        maxScale: 4,
                                        child: Image.network(
                                          postagem.imagemUrl!,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white54,
                                            size: 64,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.image_outlined,
                                        color: Colors.white54,
                                        size: 72,
                                      ),
                              ),
                              _buildAnimacaoCoracao(
                                _postagemAnimandoLikeTelaCheia ==
                                    postagem.idPostagem,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 24,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              postagemAtual.titulo,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatarDataHora(postagemAtual.dataPostagem),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () async {
                                    await _alternarCurtida(postagemAtual);
                                    if (!mounted) return;
                                    setModalState(() {});
                                  },
                                  child: Row(
                                    children: [
                                      Icon(
                                        curtiu
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: curtiu
                                            ? _primaryBlue
                                            : Colors.white70,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$curtidas',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
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
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _carregarOficios(int idProfissional) async {
    try {
      final supabase = Supabase.instance.client;
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
        if (mounted) setState(() => _oficios = []);
        return;
      }

      final oficiosData = await supabase
          .from('oficios')
          .select('funcao, cor, categoria')
          .inFilter('id_oficio', idsOficios);

      final oficios = <OficioInfo>[];
      for (final row in oficiosData) {
        final info = OficioInfo.fromMap(row);
        if (info.funcao.isNotEmpty) oficios.add(info);
      }

      if (mounted) setState(() => _oficios = oficios);
    } catch (_) {}
  }

  Future<void> _carregarServicosProfissional(int idProfissional) async {
    try {
      if (_idGrupoEmpresa != null) {
        if (mounted) {
          setState(() {
            _servicos = [];
            _categorias = ['Todos'];
            _categoriaServico = 'Todos';
            _carregandoServicos = false;
          });
        }
        return;
      }
      final ehMembroEmpresa = await ServicosProfissionalService
          .profissionalEhMembroEmpresa(idProfissional);
      if (ehMembroEmpresa) {
        if (mounted) {
          setState(() {
            _servicos = [];
            _categorias = ['Todos'];
            _categoriaServico = 'Todos';
            _carregandoServicos = false;
          });
        }
        return;
      }
      debugPrint(
        '🔎 [PerfilProfissional] Buscando serviços para id_profissional=$idProfissional',
      );
      final servicos = await ServicosProfissionalService.buscarServicos(
        idProfissional: idProfissional,
      );
      debugPrint(
        '✅ [PerfilProfissional] Serviços recebidos: ${servicos.length}',
      );
      if (!mounted) return;

      final categoriasSet = <String>{'Todos'};
      for (final s in servicos) {
        if (s.funcao != null && s.funcao!.trim().isNotEmpty) {
          categoriasSet.add(s.funcao!.trim());
        }
      }

      setState(() {
        _servicos = servicos;
        _categorias = categoriasSet.toList();
        if (!_categorias.contains(_categoriaServico)) {
          _categoriaServico = 'Todos';
        }
        _carregandoServicos = false;
      });
      debugPrint(
        '✅ [PerfilProfissional] Estado atualizado. Serviços exibíveis: ${_servicos.length}; categorias: $_categorias',
      );
    } catch (e) {
      debugPrint('Erro ao carregar serviços do profissional: $e');
      debugPrint(
        '❌ [PerfilProfissional] Serviços STACK: ${StackTrace.current}',
      );
      if (mounted) {
        setState(() => _carregandoServicos = false);
      }
    }
  }

  String _formatarDataCompleta(DateTime data) {
    final mm = data.month.toString().padLeft(2, '0');
    final dd = data.day.toString().padLeft(2, '0');
    return '${data.year}-$mm-$dd';
  }

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

  bool _isExcecaoDiaInteiro(Map<String, dynamic> row) {
    final horaIni = row['hora_ini'];
    final horaFim = row['hora_fim'];
    if (horaIni == null || horaFim == null) return true;
    final iniStr = horaIni.toString().trim();
    final fimStr = horaFim.toString().trim();
    if (iniStr.isEmpty || fimStr.isEmpty) return true;
    final iniMatch = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(iniStr);
    final fimMatch = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(fimStr);
    return iniMatch == null || fimMatch == null;
  }

  Future<void> _carregarExcecoes() async {
    if (_idProfissional == null) return;

    setState(() => _carregandoExcecoes = true);

    try {
      final supabase = Supabase.instance.client;
      final ano = _mesSelecionado.year;
      final mes = _mesSelecionado.month;
      final primeiroDia = DateTime(ano, mes, 1);
      final ultimoDia = DateTime(ano, mes + 1, 0);

      final response = await supabase
          .from('grade_horario_excecao')
          .select('dia_semana, hora_ini, hora_fim, observacao')
          .eq('fk_profissional', _idProfissional!)
          .gte('dia_semana', _formatarDataCompleta(primeiroDia))
          .lte('dia_semana', _formatarDataCompleta(ultimoDia));

      if (!mounted) return;

      final bloqueados = <String, String?>{};
      for (final row in response) {
        // Se tiver hora_ini e hora_fim válidos, NÃO é bloqueio de dia inteiro (não fica vermelho)
        if (!_isExcecaoDiaInteiro(row)) continue;
        final dataExcecao = _parseDataExcecao(row['dia_semana']);
        if (dataExcecao == null) continue;
        final chave = _formatarDataCompleta(dataExcecao);
        final obs = row['observacao']?.toString().trim();
        bloqueados[chave] = (obs != null && obs.isNotEmpty) ? obs : null;
      }

      setState(() {
        _diasBloqueados
          ..clear()
          ..addAll(bloqueados);
      });
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _carregandoExcecoes = false);
      }
    }
  }

  // Bottom sheet estilizado ao clicar em uma data de exceção
  void _mostrarBottomSheetDiaBloqueado(DateTime data, String? observacao) {
    final meses = [
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
    final dataFormatada =
        '${data.day} de ${meses[data.month - 1]} de ${data.year}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _blockedBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_busy_rounded,
                    color: _blockedRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dataFormatada,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Indisponível nesta data',
                        style: TextStyle(
                          fontSize: 12,
                          color: _blockedRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: _borderColor),
            const SizedBox(height: 16),
            const Text(
              'Motivo da indisponibilidade:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _borderColor),
              ),
              child: Text(
                observacao != null && observacao.isNotEmpty
                    ? observacao
                    : 'O profissional não terá atendimento neste dia.',
                style: const TextStyle(
                  fontSize: 14,
                  color: _textDark,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Fechar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _atualizarOffsetsSecoes() {
    _offsetDisponibilidade = _offsetDaSecao(_disponibilidadeKey);
    _offsetAvaliacoes = _offsetDaSecao(_avaliacoesKey);
    _offsetDetalhes = _offsetDaSecao(_detalhesKey);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.offset;
    if (!_isScrollingProgrammatically) {
      final now = DateTime.now();
      if (now.difference(_ultimaAtualizacaoAba) >=
          const Duration(milliseconds: 150)) {
        _ultimaAtualizacaoAba = now;
        final novaAba = _calcularAbaAtiva(offset);
        if (novaAba != _abaAtiva) {
          setState(() {
            _abaAtiva = novaAba;
          });
        }
      }
    }
  }

  double? _offsetDaSecao(GlobalKey key) {
    final sectionContext = key.currentContext;
    if (sectionContext == null) return null;
    final renderObject = sectionContext.findRenderObject();
    if (renderObject == null || !renderObject.attached) return null;
    final viewport = RenderAbstractViewport.of(renderObject);
    return viewport.getOffsetToReveal(renderObject, 0.0).offset;
  }

  int _calcularAbaAtiva(double scrollOffset) {
    final scrollTop = scrollOffset + _pinnedHeaderHeight;
    final offsets = [
      _offsetDisponibilidade,
      _offsetAvaliacoes,
      _offsetDetalhes,
    ];
    var aba = 0;
    for (var i = 0; i < offsets.length; i++) {
      final sectionOffset = offsets[i];
      if (sectionOffset != null && scrollTop >= sectionOffset - 20) {
        aba = i;
      }
    }
    return aba;
  }

  Future<void> _scrollParaAba(int index) async {
    final keys = [_disponibilidadeKey, _avaliacoesKey, _detalhesKey];

    setState(() {
      _abaAtiva = index;
      _isScrollingProgrammatically = true;
    });

    for (var tentativa = 0; tentativa < 5; tentativa++) {
      await Future<void>.delayed(Duration.zero);
      if (!mounted || !_scrollController.hasClients) break;

      final sectionOffset = _offsetDaSecao(keys[index]);
      if (sectionOffset != null) {
        final target = (sectionOffset - _pinnedHeaderHeight).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        await _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    if (mounted) {
      setState(() => _isScrollingProgrammatically = false);
    }
  }

  Future<void> _recarregarPerfil() async {
    // 1. Limpa cache em memória do Flutter para garantir que fotos e imagens atualizadas sejam recarregadas
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    final fotoAtual = _fotoUrl;
    if (fotoAtual != null &&
        fotoAtual.isNotEmpty &&
        (fotoAtual.startsWith('http://') || fotoAtual.startsWith('https://'))) {
      await NetworkImage(fotoAtual).evict().catchError((_) => true);
    }
    if (widget.imagemInicial.isNotEmpty &&
        (widget.imagemInicial.startsWith('http://') ||
            widget.imagemInicial.startsWith('https://'))) {
      await NetworkImage(widget.imagemInicial).evict().catchError((_) => true);
    }

    // 2. Destrava flags para permitir recarga completa
    _carregandoSeguimento = false;

    // 3. Recarrega os dados completos do usuário logado e do perfil profissional
    await Future.wait([
      _carregarUsuarioLogado(),
      _carregarDadosProfissional(),
    ]);

    if (mounted) {
      setState(() {});
      _atualizarOffsetsSecoes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: RefreshIndicator(
          color: _primaryBlue,
          backgroundColor: Colors.white,
          edgeOffset: MediaQuery.paddingOf(context).top + 8,
          onRefresh: _recarregarPerfil,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            clipBehavior: Clip.none,
            slivers: [
              SliverToBoxAdapter(child: _buildCabecalhoVisual()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: _buildBarraBusca(),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _AbasDelegate(
                  abaAtiva: _abaAtiva,
                  onAbaTap: _scrollParaAba,
                ),
              ),
              SliverToBoxAdapter(
                key: _disponibilidadeKey,
                child: RepaintBoundary(child: _buildSecaoDisponibilidade()),
              ),
              SliverToBoxAdapter(
                child: RepaintBoundary(child: _buildSecaoLocalizacao()),
              ),
              SliverToBoxAdapter(
                key: _avaliacoesKey,
                child: RepaintBoundary(child: _buildSecaoAvaliacoes()),
              ),
              SliverToBoxAdapter(
                key: _detalhesKey,
                child: RepaintBoundary(child: _buildSecaoDetalhes()),
              ),
              SliverToBoxAdapter(
                key: _footerButtonKey,
                child: const SizedBox(height: 48),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Cabeçalho e Informações do Perfil de acordo com as imagens de referência
  Widget _buildCabecalhoVisual() {
    final estaAberto = _estaAbertoAgora();

    return Column(
      children: [
        // Banner Superior Azul Escuro com Foto de Perfil Centralizada Sobreposta
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Fundo escuro estendido para cima que acompanha o pull-to-refresh / overscroll
            // AnimatedContainer: se a cor real chegar depois (primeira vez sem
            // cache), a transição é suave em vez de "piscar".
            Positioned(
              top: -1000,
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                color: _corBanner,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              height: 140,
              width: double.infinity,
              color: _corBanner,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Avatar Circular com Borda Branca e Selo de Verificação Azul
            Positioned(
              bottom: -55,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(child: _buildFotoPerfil()),
                  ),
                  // Selo de verificação azul com check branco no canto inferior direito
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _primaryBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 64),

        // Nome do Profissional (já nasce com o nome inicial -> instantâneo,
        // sem spinner que fazia o layout "pular" na abertura).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _nome,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _textDark,
              letterSpacing: -0.2,
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Tipo de Profissional (Independente ou Loja do perfil)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _tipoPerfil.toLowerCase().trim() == 'loja'
                  ? Icons.storefront_outlined
                  : Icons.business_center_outlined,
              color: _textMuted,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              _tipoPerfil.toLowerCase().trim() == 'independente'
                  ? 'Profissional independente'
                  : (_tipoPerfil.isNotEmpty
                        ? _tipoPerfil
                        : 'Profissional independente'),
              style: const TextStyle(
                fontSize: 14,
                color: _textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        // Chips de Ofícios carregados dinamicamente com cores de cor_oficio.dart
        if (_oficios.isNotEmpty) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _oficios
                  .map((oficio) => _buildChipOficio(oficio))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 14),

        // Status de Disponibilidade:
        // Caso não haja dados em agenda_profissional, mostra só "(bolinha vermelha) Fechado"
        if (!_temAgendaCadastrada)
          GestureDetector(
            onTap: _mostrarModalHorariosFuncionamento,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _statusRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Fechado',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _statusRed,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GestureDetector(
            onTap: _mostrarModalHorariosFuncionamento,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FB),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFBAE6FD).withValues(alpha: 0.7),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: estaAberto ? _statusGreen : _statusRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    estaAberto ? 'Aberto agora' : 'Fechado agora',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: estaAberto ? const Color(0xFF0369A1) : _statusRed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '•',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.access_time_rounded,
                    color: _primaryBlue,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _faixaHorarioDisponibilidade,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        if (_idProfissional != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF8FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB9E8FF)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.handyman_outlined,
                    color: _primaryBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Encontrou o serviço que precisa?',
                      style: TextStyle(
                        color: _textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _abrirSolicitacaoServico,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Solicitar Serviço'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Botões de Ação: "+ Seguir" e "Conversar"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _buildBotaoSeguir()),
              const SizedBox(width: 12),
              Expanded(child: _buildBotaoConversar()),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 2. Estatísticas do Profissional (Banner Card com 4 seções e divisores verticais sutis)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Estrelas e Avaliações (estático)
                _buildMetricaItem(
                  icone: Icons.star,
                  corIcone: _starGold,
                  valor: widget.avaliacao.toStringAsFixed(1),
                  subtitulo: '${widget.totalAvaliacoes} avaliações',
                ),
                _buildDivisorVertical(),
                // Selo de Verificação (estático)
                _buildMetricaItem(
                  icone: Icons.verified_outlined,
                  corIcone: _primaryBlue,
                  valor: 'Pro',
                  corValor: _primaryBlue,
                  subtitulo: 'Verificado',
                ),
                _buildDivisorVertical(),
                // Anos de Experiência (do Supabase ou default 0-1 ano)
                _buildMetricaItem(
                  icone: Icons.business_center_outlined,
                  corIcone: _textDark,
                  valor: _formatarAnosExperiencia(_anosExperiencia),
                  subtitulo: 'Anos exp.',
                ),
                _buildDivisorVertical(),
                // Seguidores (do Supabase ou 0)
                _buildMetricaItem(
                  icone: Icons.people_outline,
                  corIcone: _textDark,
                  valor: '$_totalSeguidores',
                  subtitulo: 'Seguidores',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChipOficio(OficioInfo oficio) {
    final corBase = CorOficio.parse(oficio.cor);
    final corFundo = corBase.withValues(alpha: 0.15);
    final corTexto = CorOficio.corTexto(corBase);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: corBase.withValues(alpha: 0.3)),
      ),
      child: Text(
        oficio.funcao,
        style: TextStyle(
          color: corTexto,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildBotaoSeguir({bool isSmall = false}) {
    return OutlinedButton(
      onPressed: _carregandoSeguimento || _alterandoSeguimento
          ? null
          : _alternarSeguimento,
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryBlue,
        backgroundColor: Colors.white,
        side: const BorderSide(color: _primaryBlue, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: _alterandoSeguimento
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _primaryBlue,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _seguindoProfissional
                      ? Icons.check
                      : Icons.person_add_outlined,
                  size: 20,
                  color: _primaryBlue,
                ),
                const SizedBox(width: 8),
                Text(
                  _seguindoProfissional ? 'Seguindo' : '+ Seguir',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBotaoConversar() {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TelaChatProfissional(
              nomeProfissional: _nome.isNotEmpty ? _nome : widget.nomeInicial,
              fotoProfissional: _fotoUrl ?? widget.imagemInicial,
              oficioPrincipal: _oficios.isNotEmpty
                  ? _oficios.first.funcao
                  : widget.profissao,
              idProfissional: _idProfissional,
            ),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 20, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Conversar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirSolicitacaoServico() async {
    if (_idProfissional == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.96,
        child: SolicitarServicoPage(
          idProfissional: _idProfissional!,
          servicos: List<ServicoProfissional>.unmodifiable(_servicos),
        ),
      ),
    );
  }

  Widget _buildMetricaItem({
    required IconData icone,
    required Color corIcone,
    required String valor,
    Color? corValor,
    required String subtitulo,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, color: corIcone, size: 16),
              const SizedBox(width: 4),
              Text(
                valor,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: corValor ?? _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: _textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivisorVertical() {
    return Container(width: 1, height: 28, color: _borderColor);
  }

  Widget _buildFotoPerfil() {
    final String imagemParaExibir = _fotoUrl ?? widget.imagemInicial;
    final bool ehUrl =
        imagemParaExibir.startsWith('http://') ||
        imagemParaExibir.startsWith('https://');

    if (ehUrl) {
      return Image.network(
        imagemParaExibir,
        fit: BoxFit.cover,
        cacheWidth: 250,
        // Mantém a imagem anterior/inicial enquanto a nova carrega:
        // nada "pisca" ao trocar da foto inicial para a do Supabase.
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _buildIniciaisPerfil(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          // Enquanto carrega, mostra as iniciais (estático) em vez de
          // spinner — parece que nem carregou, sem piscar.
          return _buildIniciaisPerfil();
        },
      );
    }
    return _buildIniciaisPerfil();
  }

  Widget _buildIniciaisPerfil() {
    final nomeExibicao = _nome.isNotEmpty
        ? _nome
        : 'Profissional não encontrado';
    return Container(
      color: const Color(0xFFE0F2FE),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(nomeExibicao),
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _primaryBlue,
        ),
      ),
    );
  }

  // 3. Barra de Pesquisa
  Widget _buildBarraBusca() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: const TextField(
          decoration: InputDecoration(
            hintText: 'Buscar serviços',
            hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF), size: 22),
            suffixIcon: Icon(Icons.tune, color: Color(0xFF64748B), size: 22),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  // 5. Conteúdo das Abas: Seção de Disponibilidade (Calendário com Exceções reais do Supabase)
  Widget _buildSecaoDisponibilidade() {
    final diasSemanaCabecalho = [
      'DOM',
      'SEG',
      'TER',
      'QUA',
      'QUI',
      'SEX',
      'SÁB',
    ];

    final primeiroDia = DateTime(
      _mesSelecionado.year,
      _mesSelecionado.month,
      1,
    );
    final ultimoDia = DateTime(
      _mesSelecionado.year,
      _mesSelecionado.month + 1,
      0,
    );
    final diasNoMesAnterior = DateTime(
      _mesSelecionado.year,
      _mesSelecionado.month,
      0,
    ).day;

    final diaInicioSemana = primeiroDia.weekday % 7;
    final totalCelulas = ((diaInicioSemana + ultimoDia.day) / 7).ceil() * 7;
    final hoje = DateTime.now();

    final meses = [
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Topo do Calendário: Mês e Ano navegáveis na esquerda e setas na direita
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      meses[_mesSelecionado.month - 1],
                      style: const TextStyle(
                        color: _primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: _primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_mesSelecionado.year}',
                      style: const TextStyle(
                        color: _primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: _primaryBlue,
                      size: 20,
                    ),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _mesSelecionado = DateTime(
                            _mesSelecionado.year,
                            _mesSelecionado.month - 1,
                          );
                        });
                        _carregarExcecoes();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.chevron_left,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _mesSelecionado = DateTime(
                            _mesSelecionado.year,
                            _mesSelecionado.month + 1,
                          );
                        });
                        _carregarExcecoes();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.chevron_right,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cabeçalho dos dias da semana
            Row(
              children: diasSemanaCabecalho
                  .map(
                    (d) => Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),

            // Grade de dias do calendário
            if (_carregandoExcecoes)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primaryBlue,
                    ),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.05,
                ),
                itemCount: totalCelulas,
                itemBuilder: (context, index) {
                  final ehAntes = index < diaInicioSemana;
                  final diaAtual = index - diaInicioSemana + 1;
                  final ehDepois = diaAtual > ultimoDia.day;

                  if (ehAntes) {
                    final diaAnt =
                        diasNoMesAnterior - (diaInicioSemana - index - 1);
                    return Center(
                      child: Text(
                        '$diaAnt',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  if (ehDepois) {
                    final diaProx = diaAtual - ultimoDia.day;
                    return Center(
                      child: Text(
                        '$diaProx',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFCBD5E1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }

                  final dataDia = DateTime(
                    _mesSelecionado.year,
                    _mesSelecionado.month,
                    diaAtual,
                  );
                  final chaveData = _formatarDataCompleta(dataDia);
                  final isHoje =
                      dataDia.year == hoje.year &&
                      dataDia.month == hoje.month &&
                      dataDia.day == hoje.day;
                  final isBloqueado = _diasBloqueados.containsKey(chaveData);
                  final observacao = _diasBloqueados[chaveData];

                  // Se for exceção de dia inteiro: vermelho e clicável para abrir o bottom sheet
                  if (isBloqueado) {
                    return GestureDetector(
                      onTap: () =>
                          _mostrarBottomSheetDiaBloqueado(dataDia, observacao),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _blockedBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _blockedBorder),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$diaAtual',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _blockedRed,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    );
                  }

                  // Se for o dia atual: pintado de azul
                  if (isHoje) {
                    return Container(
                      decoration: BoxDecoration(
                        color: _primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$diaAtual',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    );
                  }

                  // Não exceção e não dia atual: não pintado
                  return Center(
                    child: Text(
                      '$diaAtual',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // 4.5. Seção de Localização e Atendimento
  Widget _buildSecaoLocalizacao() {
    if (!_enderecoCarregado) {
      return const SizedBox.shrink();
    }

    final endereco = _enderecoProfissional;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.location_on_outlined,
                color: Color(0xFF00A3FF),
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Localização e Atendimento',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (endereco == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: const [
                  Icon(
                    Icons.location_off_outlined,
                    color: Color(0xFF94A3B8),
                    size: 32,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Profissional não possui endereço cadastrado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            )
          else
            _buildCardLocalizacao(endereco),
        ],
      ),
    );
  }

  Widget _buildCardLocalizacao(_DadosEnderecoProfissional endereco) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Mapa interativo com visualização da base e raio de atendimento
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        endereco.latitude,
                        endereco.longitude,
                      ),
                      initialZoom: 15.0,
                      minZoom: 3,
                      maxZoom: 19,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'br.com.consertaja',
                        maxNativeZoom: 19,
                        maxZoom: 19,
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(
                              endereco.latitude,
                              endereco.longitude,
                            ),
                            radius: 68,
                            useRadiusInMeter: false,
                            color: const Color(
                              0xFF0284C7,
                            ).withValues(alpha: 0.12),
                            borderColor: const Color(
                              0xFF0284C7,
                            ).withValues(alpha: 0.35),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              endereco.latitude,
                              endereco.longitude,
                            ),
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF0FB3FF),
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Badge superior esquerdo: "A 2.4 km de você" com bolinha verde pulsante
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          _BlinkingSignalDot(),
                          SizedBox(width: 6),
                          Text(
                            'A 2.4 km de você',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Badge superior direito: "Raio de 1 km"
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.radar_rounded,
                            size: 16,
                            color: Color(0xFF0284C7),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Raio de 1 km',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 2. Informações do endereço e botões de navegação
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFBAE6FD).withValues(alpha: 0.8),
                        ),
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: Color(0xFF0284C7),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            endereco.apelido,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${endereco.logradouro}, ${endereco.numero}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${endereco.bairro}, ${endereco.cidade} - ${endereco.estado} • CEP ${endereco.cep}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Calculando rota para ${endereco.logradouro}, ${endereco.numero}...',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFBAE6FD),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.assistant_direction_outlined,
                                  size: 20,
                                  color: Color(0xFF0284C7),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Como Chegar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Abrindo no Google Maps...'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.map_outlined,
                                  size: 20,
                                  color: Color(0xFF334155),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Google Maps',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  // 5. Conteúdo das Abas: Seção de Avaliações (mantida estática)
  Widget _buildSecaoAvaliacoes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título com resumo das estrelas e total: "5.0 ★ Avaliações do Profissional (923)"
          Row(
            children: [
              const Text(
                '5.0',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.star, color: _starGold, size: 20),
              const SizedBox(width: 6),
              const Text(
                'Avaliações do Profissional',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '(923)',
                style: TextStyle(fontSize: 15, color: _textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Card de Resumo dos comentários
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo dos comentários',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Profissional elogiado pela agilidade incomparável, pontualidade britânica e serviço impecável tanto em chaveiro quanto em manutenções elétricas e refrigeração.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Chips de filtro: Principais, Recentes e Ver todas (932)
          Row(
            children: [
              _buildChipFiltroComentario('Principais'),
              const SizedBox(width: 8),
              _buildChipFiltroComentario('Recentes'),
              const Spacer(),
              const Text(
                'Ver todas (932)',
                style: TextStyle(
                  color: _primaryBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cards de comentários individuais
          _buildCardComentario(
            nome: _avaliacoes[0]['nome'],
            iniciais: _avaliacoes[0]['iniciais'],
            corAvatar: _avaliacoes[0]['corAvatar'] as Color,
            tempo: _avaliacoes[0]['tempo'],
            texto: _avaliacoes[0]['texto'],
            liked: _likedComentario1,
            likes: _likesComentario1,
            onLikeTap: () {
              setState(() {
                _likedComentario1 = !_likedComentario1;
                _likesComentario1 += _likedComentario1 ? 1 : -1;
              });
            },
          ),
          const SizedBox(height: 10),
          _buildCardComentario(
            nome: _avaliacoes[1]['nome'],
            iniciais: _avaliacoes[1]['iniciais'],
            corAvatar: _avaliacoes[1]['corAvatar'] as Color,
            tempo: _avaliacoes[1]['tempo'],
            texto: _avaliacoes[1]['texto'],
            liked: _likedComentario2,
            likes: _likesComentario2,
            onLikeTap: () {
              setState(() {
                _likedComentario2 = !_likedComentario2;
                _likesComentario2 += _likedComentario2 ? 1 : -1;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltroComentario(String texto) {
    final isSelected = _filtroComentario == texto;
    return GestureDetector(
      onTap: () => setState(() => _filtroComentario = texto),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryBlue : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: isSelected ? _primaryBlue : const Color(0xFF475569),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCardComentario({
    required String nome,
    required String iniciais,
    required Color corAvatar,
    required String tempo,
    required String texto,
    required bool liked,
    required int likes,
    required VoidCallback onLikeTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: corAvatar,
            child: Text(
              iniciais,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    ...List.generate(5, (_) {
                      return const Icon(Icons.star, color: _starGold, size: 14);
                    }),
                    const SizedBox(width: 8),
                    Text(
                      tempo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onLikeTap,
            child: Column(
              children: [
                Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? _primaryBlue : const Color(0xFF94A3B8),
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  '$likes',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: liked ? _primaryBlue : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. Conteúdo das Abas: Seção de Detalhes (Sobre o Profissional e Tipos de serviços dos ofícios)
  Widget _buildSecaoDetalhes() {
    final descricaoCompleta = _descricaoPerfil.isNotEmpty
        ? _descricaoPerfil
        : 'Este profissional não possui descrição';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sobre o Profissional
          Row(
            children: [
              const Icon(Icons.person_outline, color: _primaryBlue, size: 22),
              const SizedBox(width: 6),
              const Text(
                'Sobre o Profissional',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            descricaoCompleta,
            maxLines: _descricaoExpandida ? 100 : 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF475569),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          if (descricaoCompleta.length > 120)
            GestureDetector(
              onTap: () =>
                  setState(() => _descricaoExpandida = !_descricaoExpandida),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _descricaoExpandida ? 'Ver Menos' : 'Ver Mais',
                    style: const TextStyle(
                      color: _primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _descricaoExpandida
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _primaryBlue,
                    size: 18,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Serviços Oferecidos abaixo da descrição
          if (_idGrupoEmpresa == null) ...[
            _buildCatalogoServicos(embutido: true),
            const SizedBox(height: 24),
          ],

          // Tipos de serviços oferecidos (vindos de _oficios do profissional)
          const Text(
            'Tipos de serviços oferecidos',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 12),

          if (_oficios.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Nenhum tipo de serviço cadastrado.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _textMuted),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.5,
              ),
              itemCount: _oficios.length,
              itemBuilder: (context, index) {
                final oficio = _oficios[index];
                final corBase = CorOficio.parse(oficio.cor);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: corBase,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: IconeOficio.imagemPorFuncao(
                            oficio.funcao,
                            tamanho: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          oficio.funcao,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),

          if (_idGrupoEmpresa == null) ...[
            _buildSecaoMetodosEntrega(),
            const SizedBox(height: 24),
          ],

          // Galeria de Postagens (carregada do Supabase)
          const Text(
            'Galeria de Postagens',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<PostagemResumo>>(
            future: _postagensGaleriaFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 140,
                  child: Center(
                    child: CircularProgressIndicator(color: _primaryBlue),
                  ),
                );
              }

              final postagens = snapshot.data ?? const <PostagemResumo>[];

              if (postagens.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Este profissional ainda não publicou postagens.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _textMuted),
                  ),
                );
              }

              return SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: postagens.length,
                  itemBuilder: (context, index) {
                    final postagem = postagens[index];
                    return Container(
                      width: 230,
                      margin: EdgeInsets.only(
                        right: index < postagens.length - 1 ? 12 : 0,
                      ),
                      child: _buildCardGaleriaPostagem(
                        postagem,
                        curtidas: _curtidasExibidas(postagem),
                        curtiu: _usuarioCurtiuPostagem(postagem.idPostagem),
                        onTap: () => _abrirGaleriaPostagens(postagens, index),
                        onDoubleTap: () => _curtirComAnimacaoNoCard(postagem),
                        onLikeTap: () => _alternarCurtida(postagem),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCardGaleriaPostagem(
    PostagemResumo postagem, {
    required int curtidas,
    required bool curtiu,
    required VoidCallback onTap,
    required VoidCallback onDoubleTap,
    required VoidCallback onLikeTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (postagem.imagemUrl != null && postagem.imagemUrl!.isNotEmpty)
              Image.network(
                postagem.imagemUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image, color: Colors.grey),
                ),
              )
            else
              Container(
                color: const Color(0xFFE2E8F0),
                child: const Icon(Icons.image_outlined, color: Colors.grey),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      postagem.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onLikeTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          curtiu ? Icons.favorite : Icons.favorite_border,
                          color: curtiu ? _primaryBlue : Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$curtidas',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildAnimacaoCoracao(
              _animandoLikeNoCard.contains(postagem.idPostagem),
            ),
          ],
        ),
      ),
    );
  }

  // Seção de Métodos de Entrega
  Widget _buildSecaoMetodosEntrega() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.local_shipping_rounded,
              color: Color(0xFF00A3FF),
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Métodos de Entrega',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _textDark,
                letterSpacing: -0.3,
              ),
            ),
            if (_metodosEntrega.isNotEmpty) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FDF2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  '${_metodosEntrega.length} ${_metodosEntrega.length == 1 ? 'modalidade' : 'modalidades'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (_metodosEntrega.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'O profissional ainda não possui método de entrega cadastrado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (int i = 0; i < _metodosEntrega.length; i += 2) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _buildCardMetodoEntrega(_metodosEntrega[i]),
                    ],
                  ],
                ),
              ),
              if (_metodosEntrega.length > 1) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      for (int i = 1; i < _metodosEntrega.length; i += 2) ...[
                        if (i > 1) const SizedBox(height: 10),
                        _buildCardMetodoEntrega(_metodosEntrega[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  String _formatarTituloMetodo(String titulo) {
    if (titulo.toLowerCase().contains('domicil')) {
      return 'Atendimento em\nDomicílio';
    }
    return titulo;
  }

  Widget _buildCardMetodoEntrega(_MetodoEntregaInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    info.icone,
                    color: const Color(0xFF00A3FF),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatarTituloMetodo(info.titulo),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: info.corFundoBadge,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        info.textoBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: info.corTextoBadge,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            info.descricao,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // 5. Conteúdo das Abas: Serviços Oferecidos
  Widget _buildCatalogoServicos({bool embutido = false}) {
    final servicosFiltrados = _categoriaServico == 'Todos'
        ? _servicos
        : _servicos.where((s) => s.funcao == _categoriaServico).toList();

    return Padding(
      padding: embutido
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Serviços Oferecidos',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 12),
          if (_carregandoServicos)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: _primaryBlue),
              ),
            )
          else if (_servicos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Este profissional ainda não oferece nenhum serviço',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else ...[
            // Chips de filtro horizontal
            if (_categorias.length > 1) ...[
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _categorias.length,
                  itemBuilder: (context, index) {
                    final categoria = _categorias[index];
                    final isSelected = _categoriaServico == categoria;
                    return GestureDetector(
                      onTap: () => setState(() => _categoriaServico = categoria),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFF0F9FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? _primaryBlue
                                : const Color(0xFFCBD5E1),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          categoria,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? _primaryBlue
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (servicosFiltrados.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Nenhum serviço encontrado nesta categoria.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              // Grid de Cards verticais de serviço
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.68,
                ),
                itemCount: servicosFiltrados.length,
                itemBuilder: (context, index) =>
                    _buildCardServicoVisual(servicosFiltrados[index]),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardServicoVisual(ServicoProfissional servico) {
    final corTag = servico.cor != null && servico.cor!.isNotEmpty
        ? CorOficio.parse(servico.cor)
        : (servico.funcao != null && servico.funcao!.isNotEmpty
            ? CorOficio.parse(servico.funcao!)
            : _primaryBlue);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TelaServico(
              idServico: servico.id,
              servicoInicial: servico,
            ),
          ),
        );
      },
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem do serviço com tag de categoria sobreposta
          Expanded(
            flex: 11,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (servico.imagemUrl != null &&
                    servico.imagemUrl!.trim().isNotEmpty)
                  Image.network(
                    servico.imagemUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildFallbackImagemServico(),
                  )
                else
                  _buildFallbackImagemServico(),
                if (servico.funcao != null && servico.funcao!.trim().isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: CorOficio.corFundo(corTag),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        servico.funcao!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: CorOficio.corTexto(corTag),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Informações do serviço
          Expanded(
            flex: 9,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    servico.titulo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${servico.tipoExecucao} • Carga ${servico.cargaServico}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        widget.avaliacao.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.star, color: _starGold, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        '(${_avaliacoes.length})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: _borderColor),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preço Médio',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF0FB3FF),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'R\$ ${servico.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _priceOrange,
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
      ),
    );
  }

  Widget _buildFallbackImagemServico() {
    return Container(
      color: const Color(0xFFEAF4FB),
      child: const Center(
        child: Icon(
          Icons.home_repair_service_rounded,
          color: Color(0xFF0A6E9D),
          size: 36,
        ),
      ),
    );
  }
}

// 4. Navegação por Abas (TabBar) Fixa com indicador azul
class _AbasDelegate extends SliverPersistentHeaderDelegate {
  final int abaAtiva;
  final void Function(int) onAbaTap;

  static const List<String> _abas = [
    'Disponibilidade',
    'Avaliações',
    'Detalhes',
  ];

  _AbasDelegate({required this.abaAtiva, required this.onAbaTap});

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: List.generate(_abas.length, (index) {
                final isActive = abaAtiva == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onAbaTap(index),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        Text(
                          _abas[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isActive
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 3,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF0284C7)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AbasDelegate oldDelegate) {
    return oldDelegate.abaAtiva != abaAtiva;
  }
}
