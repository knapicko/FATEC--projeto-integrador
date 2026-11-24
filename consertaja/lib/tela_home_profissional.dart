import 'dart:async' show unawaited;
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'estatisticas_profissional.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'alterar_disponibilidade.dart';
import 'area_atuacao.dart';
import 'editar_informacoes.dart';
import 'empresa_associada.dart';
import 'gestao_equipe.dart';
import 'configuracoes_empresa.dart';
import 'meus_enderecos.dart';
import 'meus_dados_financeiros_profissional.dart';
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
import 'widgets/skeleton_loading.dart';
import 'widgets/tag_oficio.dart';
import 'utils/app_navigation_util.dart';
import 'utils/funcao_servico.dart';
import 'solicitacao_geografica_profissional.dart';
import 'widgets/previa_radar_profissional.dart';
import 'minhas_notificacoes.dart';
import 'widgets/contador_notificacoes.dart';
import 'widgets/permissoes_iniciais.dart';
import 'widgets/dialogo_sheet.dart';
import 'widgets/painel_atalhos.dart';
import 'certificados.dart';
import 'meus_documentos.dart';
import 'utils/abrir_solicitacao.dart';
import 'services/conclusao_cadastro_profissional.dart';
import 'services/requisitos_conta.dart';
import 'minhas_avaliacoes_profissional.dart';
import 'tela_configuracoes_cliente.dart';
import 'meu_historico_servico_profissional.dart';
import 'services/solicitacao_geografica_service.dart';
import 'tutorial/tutorial.dart';
import 'tutorial/tutorial_visto.dart';
import 'tutorial/ilustracoes.dart';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';
import 'utils/movimento.dart';

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
    required this.servicos,
  });

  final DateTime data;
  final bool disponivel;

  /// Preenchido quando existe exceção (grade_horario_excecao).
  final String? observacaoExcecao;
  final TimeOfDay? horaInicioExcecao;
  final TimeOfDay? horaFimExcecao;
  final List<_ServicoAgendado> servicos;

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

  bool get temServico => servicos.isNotEmpty;
}

class _ServicoAgendado {
  const _ServicoAgendado({
    required this.idSolicitacao,
    required this.nomeCliente,
    required this.tituloServico,
    required this.data,
    this.fotoCliente,
  });

  final int idSolicitacao;
  final String nomeCliente;
  final String? fotoCliente;
  final String tituloServico;
  final DateTime data;
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
  /// Muda ao voltar do Radar para a prévia do mapa recarregar.
  int _versaoPreviaRadar = 0;

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

  /// Contagem real das solicitações (Pendentes, Ativos, Concluídos,
  /// Cancelados) da conta ativa.
  late Future<Map<String, int>> _estatisticasFuture;

  /// Atalhos com informação faltando (mostram a bolinha de "importante"):
  /// 'disponibilidade', 'entrega', 'financeiro', 'conta', 'enderecos'.
  Set<String> _pendencias = {};
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PermissoesIniciais.pedirSePrimeiraVez(context);
      if (mounted) await _mostrarCompletamentoEquipeSeNecessario();
      if (mounted) await _tutorial();
    });
  }

  // ── Tutorial (primeiro acesso) ─────────────────────────────────────────────

  final _rolagem = ScrollController();
  final _kCabecalho = GlobalKey();
  final _kEndereco = GlobalKey();
  final _kAreas = GlobalKey();
  final _kPostagem = GlobalKey();
  final _kAddImagem = GlobalKey();
  final _kRadar = GlobalKey();
  final _kRadarInfo = GlobalKey();
  final _kEstatisticas = GlobalKey();
  final _kAgenda = GlobalKey();
  final _kAtalhos = GlobalKey();
  final _kBarra = GlobalKey();
  final _kSheetConta = GlobalKey();
  final _kAjuda = GlobalKey();
  final _atalhoEmFoco = ValueNotifier<String?>(null);
  final Map<String, GlobalKey> _kAtalho = {
    'conta': GlobalKey(),
    'empresa': GlobalKey(),
    'config_empresa': GlobalKey(),
  };

  /// Chaves dos atalhos só durante o tutorial (arrastar um atalho monta o
  /// desenho duas vezes, e a mesma chave não pode aparecer duas vezes).
  bool _tutorialAtivo = false;
  bool _tutorialRodando = false;
  BuildContext? _ctxSheetPerfil;

  Rect? _rectDe(GlobalKey k) {
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Atalho [id] (vai para a página dele); sem ele, o painel inteiro.
  Rect? Function() _atalho(String id) =>
      () => _rectDe(_kAtalho[id]!) ?? _rectDe(_kAtalhos);

  Future<void> _rolarTopo() async {
    if (_rolagem.hasClients) {
      await _rolagem.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _focarAtalho(String id) async {
    _atalhoEmFoco.value = null;
    _atalhoEmFoco.value = id;
    await Future<void>.delayed(const Duration(milliseconds: 320));
  }

  Future<void> _tutorial() async {
    if (widget.isVisitante || _tutorialRodando || !mounted) return;
    if (!await TutorialVisto.esperarSessao(() => mounted)) return;
    final empresa = _contaEmpresaAtiva;
    final chave = empresa ? 'home_empresa' : 'home_profissional';
    if (await TutorialVisto.jaViu(chave)) return;
    _tutorialRodando = true;
    // Espera a home carregar (para medir os destaques).
    try {
      await Future.wait(
        [
          _dadosProfissionalFuture,
          _enderecoFuture,
        ].map((f) => f.catchError((_) => null)),
      );
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) {
      _tutorialRodando = false;
      return;
    }
    setState(() => _tutorialAtivo = true);
    try {
      if (empresa) {
        await _tutorialEmpresa();
      } else {
        await _tutorialIndependente();
      }
      // Interrompido (a home saiu no meio): aparece de novo depois.
      if (Tutorial.ultimoResultado != ResultadoTutorial.interrompido) {
        await TutorialVisto.marcar(chave);
      }
    } finally {
      _tutorialRodando = false;
      if (mounted) setState(() => _tutorialAtivo = false);
    }
  }

  Future<bool> _ehPessoaJuridica() async {
    try {
      final db = Supabase.instance.client;
      final u = await db
          .from('usuarios')
          .select('fk_tipo_pessoa')
          .eq('auth_id', db.auth.currentUser!.id)
          .limit(1)
          .maybeSingle();
      final tipo = u?['fk_tipo_pessoa'];
      if (tipo == null) return false;
      final ass = await db
          .from('ass_tipo_pessoa')
          .select('fk_pessoa_juridica')
          .eq('id_tipo_pessoa', tipo)
          .maybeSingle();
      return ass?['fk_pessoa_juridica'] != null;
    } catch (_) {
      return false;
    }
  }

  /// Título do Radar + a prévia do mapa (até o texto de baixo).
  Rect? _rectRadar() {
    final a = _rectDe(_kRadar);
    final b = _rectDe(_kRadarInfo);
    if (a == null) return b;
    return b == null ? a : a.expandToInclude(b);
  }

  Rect? Function() _aba(int i) =>
      Tutorial.itemBarra(_kBarra, indice: i, total: 5);

  /// Último balão: aponta o botão "?" do cabeçalho (círculo + seta).
  PassoTutorial _fimApontandoAjuda({
    bool apenasAoPular = false,
    Future<void> Function()? antes,
  }) => PassoTutorial(
    kFalaFinalTutorial,
    ehFinal: true,
    apenasAoPular: apenasAoPular,
    alvo: _kAjuda,
    raio: 22,
    folga: 2,
    apontar: true,
    antes: () async {
      await antes?.call();
      await _rolarTopo();
    },
  );

  /// Balões da home do profissional: a apresentação do primeiro acesso ou
  /// (sem [apresentacao]) a explicação do botão "?".
  List<PassoTutorial> _passosHomeProf({
    required bool apresentacao,
    required bool cnpj,
    required bool temAreas,
  }) => [
    if (apresentacao) ...[
      const PassoTutorial('Que bom te ver de novo por aqui!'),
      const PassoTutorial(
        'Vou te mostrar a sua tela principal e as partes mais importantes '
        'do app.',
      ),
      const PassoTutorial(
        'Se quiser, toque em "Pular", no canto de baixo, a qualquer '
        'momento.',
      ),
    ],
    PassoTutorial(
      'Este é o seu cabeçalho: sua foto, o endereço, as áreas em que você '
      'atua e as notificações.',
      alvo: _kCabecalho,
      rolagem: _rolagem,
      alinhamentoRolagem: 0,
    ),
    PassoTutorial(
      'Este é o seu endereço. Ele é necessário para oferecer serviços e '
      'usar o Radar.',
      alvo: _kEndereco,
      raio: 10,
    ),
    PassoTutorial(
      temAreas
          ? 'Estas são as suas áreas de atuação. Você só atende pedidos e '
                'cria serviços dessas áreas.'
          : 'Aqui vão aparecer as suas áreas de atuação. Você só atende '
                'pedidos e cria serviços delas.',
      alvo: temAreas ? _kAreas : _kCabecalho,
      raio: 14,
    ),
    PassoTutorial(
      'Aqui você cria postagens, que os clientes veem no seu perfil.',
      alvo: _kPostagem,
      rolagem: _rolagem,
      alinhamentoRolagem: 0.2,
    ),
    PassoTutorial(
      'Toda postagem precisa de pelo menos uma imagem. Comece tocando '
      'aqui!',
      alvo: _kAddImagem,
      raio: 16,
      folga: 6,
    ),
    PassoTutorial(
      'Este é o Radar. Os clientes da sua região publicam pedidos, que '
      'aparecem neste mapa.',
      alvo: _kRadar,
      alvoRect: _rectRadar,
      rolagem: _rolagem,
      alinhamentoRolagem: 0.15,
      ilustracao: const IlustracaoRadar(doProfissional: true),
    ),
    PassoTutorial(
      'Você vê os pedidos e manda a sua proposta de preço. O cliente '
      'escolhe a que achar melhor.',
      alvo: _kRadar,
      alvoRect: _rectRadar,
      ilustracao: const IlustracaoRadar(doProfissional: true),
    ),
    PassoTutorial(
      'Quando um cliente pedir algo na sua área, você recebe uma '
      'notificação. Aqui aparece quantos pedidos há agora.',
      alvo: _kRadarInfo,
      raio: 10,
    ),
    PassoTutorial(
      'Aqui você acompanha os seus serviços: pendentes, ativos, '
      'concluídos e cancelados.',
      alvo: _kEstatisticas,
      rolagem: _rolagem,
      alinhamentoRolagem: 0.2,
      raio: 12,
    ),
    PassoTutorial(
      'E esta é a sua agenda da semana, com os dias em que você atende.',
      alvo: _kAgenda,
      rolagem: _rolagem,
      alinhamentoRolagem: 0.25,
      raio: 12,
    ),
    PassoTutorial(
      'Estes são os atalhos para configurar a sua conta. Deslize para o '
      'lado para ver mais.',
      alvo: _kAtalhos,
      rolagem: _rolagem,
      alinhamentoRolagem: 0.1,
    ),
    PassoTutorial(
      'Os atalhos com ! amarelo são obrigatórios: sem eles você não '
      'consegue adicionar serviços nem usar o Radar.',
      alvo: _kAtalhos,
    ),
    PassoTutorial(
      'Em Mensagens ficam as conversas com os seus clientes.',
      alvoRect: _aba(2),
      folga: 2,
      raio: 14,
    ),
    PassoTutorial(
      'Em Serviços você vê e responde os pedidos que recebe.',
      alvoRect: _aba(3),
      folga: 2,
      raio: 14,
    ),
    PassoTutorial(
      'E no Perfil ficam os seus dados, avaliações e configurações.',
      alvoRect: _aba(4),
      folga: 2,
      raio: 14,
    ),
    if (apresentacao && cnpj) ...[
      PassoTutorial(
        'Como a sua conta é de CNPJ, você também pode ter uma conta de '
        'empresa!',
        alvo: _kAtalhos,
        alvoRect: _atalho('conta'),
        rolagem: _rolagem,
        antes: () => _focarAtalho('conta'),
        ilustracao: const IlustracaoEquipe(),
      ),
      PassoTutorial(
        'Com ela dá para adicionar funcionários, ter a página da sua loja '
        'e receber pedidos como empresa.',
        alvoRect: _atalho('conta'),
        ilustracao: const IlustracaoEquipe(),
      ),
      PassoTutorial(
        'Para ativar, é pelo atalho "Modificar conta". Vou te mostrar!',
        alvoRect: _atalho('conta'),
      ),
      _fimApontandoAjuda(apenasAoPular: true),
    ] else if (apresentacao)
      _fimApontandoAjuda(),
  ];

  Future<void> _tutorialIndependente() async {
    final cnpj = await _ehPessoaJuridica();
    if (!mounted) return;
    final temAreas =
        (await _oficiosFuture.catchError((_) => null))?.oficios.isNotEmpty ==
        true;
    if (!mounted) return;
    final r = await Tutorial.mostrar(
      context,
      pularParaFinal: true,
      chave: 'home_profissional',
      forcar: true,
      marcarVisto: false,
      passos: _passosHomeProf(
        apresentacao: true,
        cnpj: cnpj,
        temAreas: temAreas,
      ),
    );
    if (!cnpj || r != ResultadoTutorial.concluido || !mounted) {
      if (mounted) await _rolarTopo();
      return;
    }

    // Adendo (CNPJ): tela "Modificar conta" → tipo de conta.
    final rConta = await Navigator.of(context).push<ResultadoTutorial>(
      MaterialPageRoute(
        builder: (_) =>
            const ModificarContaProfissionalPage(tutorialTipoConta: true),
      ),
    );
    if (!mounted || rConta == ResultadoTutorial.pulado) return;
    await _rolarTopo();
    if (!mounted) return;
    await Tutorial.mostrar(
      context,
      pularParaFinal: true,
      chave: 'home_profissional_troca',
      forcar: true,
      marcarVisto: false,
      comEntrada: false,
      passos: [
        PassoTutorial(
          'De volta! Tocando no seu cabeçalho, você abre as opções da conta.',
          alvo: _kCabecalho,
        ),
        PassoTutorial(
          'Com a conta de empresa ativa, toque aqui para ver as suas contas.',
          alvo: _kSheetConta,
          raio: 14,
          antes: () async {
            final d = await _dadosProfissionalFuture.catchError((_) => null);
            final e = await _enderecoFuture.catchError((_) => null);
            if (!mounted) return;
            unawaited(
              _mostrarBottomSheetPerfil(
                nome: d?['nome']?.toString() ?? '',
                fotoUrl: d?['foto_perfil_url']?.toString(),
                endereco: e ?? '',
              ),
            );
            await Future<void>.delayed(const Duration(milliseconds: 550));
          },
          ilustracao: const IlustracaoTrocaConta(),
        ),
        PassoTutorial(
          'Depois é só escolher a conta "Loja" para usar o app como empresa. '
          'Para voltar, é o mesmo caminho!',
          alvo: _kSheetConta,
          raio: 14,
          ilustracao: const IlustracaoTrocaConta(),
        ),
        _fimApontandoAjuda(
          antes: () async {
            final ctx = _ctxSheetPerfil;
            if (ctx != null && ctx.mounted) Navigator.of(ctx).maybePop();
            _ctxSheetPerfil = null;
            await Future<void>.delayed(const Duration(milliseconds: 300));
          },
        ),
      ],
    );
    final ctx = _ctxSheetPerfil;
    if (ctx != null && ctx.mounted) Navigator.of(ctx).maybePop();
  }

  /// Primeira vez na conta de empresa: Gerenciar Empresa e Configurações.
  Future<void> _tutorialEmpresa() async {
    final r1 = await Tutorial.mostrar(
      context,
      pularParaFinal: true,
      chave: 'home_empresa',
      forcar: true,
      marcarVisto: false,
      passos: [
        PassoTutorial(
          'Agora você está na sua conta de empresa!',
          alvo: _kCabecalho,
          rolagem: _rolagem,
          alinhamentoRolagem: 0,
        ),
        PassoTutorial(
          'Em "Gerenciar Empresa" você cuida da sua equipe: convida '
          'funcionários, vê quem faz parte e muito mais.',
          alvoRect: _atalho('empresa'),
          rolagem: _rolagem,
          antes: () async {
            await _focarAtalho('empresa');
            final ctx = _kAtalhos.currentContext;
            if (ctx != null && ctx.mounted) {
              await Scrollable.ensureVisible(
                ctx,
                alignment: 0.2,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOutCubic,
              );
            }
          },
          ilustracao: const IlustracaoEquipe(),
        ),
        PassoTutorial(
          'Vou abrir para você ver como funciona.',
          alvoRect: _atalho('empresa'),
        ),
        _fimApontandoAjuda(apenasAoPular: true),
      ],
    );
    if (r1 != ResultadoTutorial.concluido || !mounted) return;
    final r2 = await Navigator.of(context).push<ResultadoTutorial>(
      MaterialPageRoute(
        builder: (_) => const GestaoEquipePage(tutorialESair: true),
      ),
    );
    if (!mounted || r2 == ResultadoTutorial.pulado) return;
    if (_souDonoEmpresa) {
      final r3 = await Tutorial.mostrar(
        context,
        pularParaFinal: true,
        chave: 'home_empresa_config',
        forcar: true,
        marcarVisto: false,
        comEntrada: false,
        passos: [
          PassoTutorial(
            'Já em "Configurações da Empresa" ficam os dados da loja e como '
            'ela aparece para os clientes.',
            alvoRect: _atalho('config_empresa'),
            antes: () => _focarAtalho('config_empresa'),
          ),
          PassoTutorial(
            'Vamos dar uma olhada!',
            alvoRect: _atalho('config_empresa'),
          ),
          _fimApontandoAjuda(apenasAoPular: true),
        ],
      );
      if (r3 != ResultadoTutorial.concluido || !mounted) return;
      final r4 = await Navigator.of(context).push<ResultadoTutorial>(
        MaterialPageRoute(
          builder: (_) => const ConfiguracoesEmpresaPage(tutorialESair: true),
        ),
      );
      if (!mounted || r4 == ResultadoTutorial.pulado) return;
    }
    _atalhoEmFoco.value = null;
    _atalhoEmFoco.value = 'empresa';
    await _rolarTopo();
    if (!mounted) return;
    await Tutorial.mostrar(
      context,
      pularParaFinal: true,
      chave: 'home_empresa_fim',
      forcar: true,
      marcarVisto: false,
      comEntrada: false,
      passos: [_fimApontandoAjuda()],
    );
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
    try {
      await BottomNavigationBarProfissional.salvarContaEmpresaAtiva(isEmpresa);
    } catch (_) {}
  }

  Future<void> _mostrarCompletamentoEquipeSeNecessario() async {
    if (widget.isVisitante || !mounted) return;
    // Cadastro que ficou pela metade (ex.: conta que precisava confirmar o
    // e-mail): conclui dados do profissional, ofícios e documentos agora.
    await ConclusaoCadastroProfissional.concluirPendente();
    if (!mounted) return;
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
    _estatisticasFuture = _carregarEstatisticas();
    unawaited(_atualizarPendencias());
    unawaited(_verificarDonoEmpresa());
    // Endereço do profissional sem latitude/longitude não aparece para os
    // clientes (home e Radar): geocodifica e grava em segundo plano.
    if (!widget.isVisitante) {
      unawaited(
        SolicitacaoGeograficaService.localizacaoEnderecoProfissional(
          contaEmpresa: _contaEmpresaAtiva,
        ).then((_) {}, onError: (_) {}),
      );
    }
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
    } catch (e, stackTrace) {
      debugPrint('Erro ao carregar dados para troca de conta: $e\n$stackTrace');
      _cacheInfosContas = null;
    }
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
    _rolagem.dispose();
    _atalhoEmFoco.dispose();
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

  /// Sininho: notificações não lidas + convites de empresa pendentes. Abre a
  /// central de notificações; os convites ficam num card no topo dela.
  Widget _buildBotaoNotificacao() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _convitesEmpresaFuture,
      builder: (context, snapshot) {
        final convites = snapshot.data ?? const <Map<String, dynamic>>[];
        final total = convites.length;
        return SinoNotificacoes(
          cor: _primaryBlue,
          extra: total,
          aoTocar: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (rotaContext) => MinhasNotificacoesPage(
                soDaContaProfissionalAtiva: true,
                totalConvites: total,
                aoAbrirConvites: () {
                  Navigator.of(rotaContext).pop();
                  _abrirPainelConvites();
                },
              ),
            ),
          ),
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

      // A mesma pessoa pode ter mais de uma linha (conta independente e da
      // empresa): maybeSingle() falhava e o botão de trocar de conta sumia.
      final linhas = await supabase
          .from('dados_profissionais')
          .select('fk_perfil')
          .eq('fk_usuario', usuarioId);
      final perfis = {
        for (final l in linhas)
          if (l['fk_perfil'] != null) l['fk_perfil'],
      };
      if (perfis.isEmpty) return null;

      final tipos = await supabase
          .from('perfil')
          .select('tipo_perfil')
          .inFilter('id_perfil', perfis.toList());
      String? tipo;
      for (final t in tipos) {
        final v = t['tipo_perfil']?.toString().trim() ?? '';
        if (v.toLowerCase() == 'loja') return 'Loja';
        if (v.isNotEmpty) tipo = v;
      }
      // Dono de uma empresa (grupo_empresa com o mesmo perfil) também é Loja.
      final grupo = await supabase
          .from('grupo_empresa')
          .select('id_grupo_empresa')
          .inFilter('fk_perfil', perfis.toList())
          .limit(1);
      if ((grupo as List).isNotEmpty) return 'Loja';
      return tipo;
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

      final idProfissional = (dadosProf?['id_profissional'] as num?)?.toInt();
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

        if (grupo == null) {
          final perfil = await supabase
              .from('perfil')
              .select('tipo_perfil')
              .eq('id_perfil', idPerfil)
              .maybeSingle();
          if (perfil?['tipo_perfil']?.toString() == 'Loja') {
            final nomeFallback = usuario?['nome']?.toString().trim();
            final novoGrupo = await supabase
                .from('grupo_empresa')
                .insert({
                  'fk_perfil': idPerfil,
                  'nome_empresa':
                      (nomeFallback != null && nomeFallback.isNotEmpty)
                      ? nomeFallback
                      : 'Minha Loja',
                  'tag_empresa': 'LOJA',
                })
                .select('*')
                .maybeSingle();
            if (novoGrupo != null) {
              grupo = novoGrupo;
              if (idProfissional != null) {
                await supabase
                    .from('dados_profissionais')
                    .update({'fk_grupo_empresa': novoGrupo['id_grupo_empresa']})
                    .eq('id_profissional', idProfissional);
              }
            }
          }
        }
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
            // Empresa sem foto: iniciais da empresa (nunca a foto pessoal).
            'foto_perfil_url': (fotoEmp != null && fotoEmp.isNotEmpty)
                ? fotoEmp
                : null,
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

      // 2. Endereço da CONTA ATIVA, nas mesmas tabelas que meus_enderecos.dart
      //    usa para profissional:
      //    - Loja (grupo_empresa)  -> ass_grupo_empresa_endereco
      //    - Independente           -> ass_profissional_endereco
      //    (antes lia ass_usuario_endereco, onde o endereço do profissional
      //    não fica — por isso a home não reconhecia o endereço cadastrado).
      //    O ativo vem primeiro; ass_usuario_endereco fica só de reserva.
      dynamic fkEndereco;
      Future<dynamic> primeiroAtivo(
        String tabela,
        String coluna,
        int id,
      ) async {
        try {
          final rows = await supabase
              .from(tabela)
              .select('fk_endereco, endereco_ativo')
              .eq(coluna, id);
          if (rows.isEmpty) return null;
          final ativo = rows.where((r) => r['endereco_ativo'] == true);
          return (ativo.isNotEmpty ? ativo.first : rows.first)['fk_endereco'];
        } catch (_) {
          return null;
        }
      }

      if (_contaEmpresaAtiva) {
        final empresa = await _buscarDadosEmpresa();
        final idGrupo = (empresa?['id_grupo_empresa'] as num?)?.toInt();
        if (idGrupo != null) {
          fkEndereco = await primeiroAtivo(
            'ass_grupo_empresa_endereco',
            'fk_grupo_empresa',
            idGrupo,
          );
        }
        fkEndereco ??= empresa?['fk_endereco'];
      } else {
        final dados = await supabase
            .from('dados_profissionais')
            .select('id_profissional')
            .eq('fk_usuario', usuarioId)
            .limit(1)
            .maybeSingle();
        final idProf = (dados?['id_profissional'] as num?)?.toInt();
        if (idProf != null) {
          fkEndereco = await primeiroAtivo(
            'ass_profissional_endereco',
            'fk_profissional',
            idProf,
          );
        }
      }

      fkEndereco ??= await primeiroAtivo(
        'ass_usuario_endereco',
        'fk_usuario',
        (usuarioId as num).toInt(),
      );
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
            .select('fk_funcao')
            .eq('fk_grupo_empresa', idGrupoEmpresa);

        final idsOficios = assOficios
            .map((e) => e['fk_funcao'])
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
            .from('funcoes')
            .select(kColunasFuncaoComoOficio)
            .inFilter('id_funcao', idsOficios);

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
          .select('fk_funcao')
          .eq('fk_profissional', idProfissional);

      final idsOficios = assOficios
          .map((e) => e['fk_funcao'])
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
          .from('funcoes')
          .select(kColunasFuncaoComoOficio)
          .inFilter('id_funcao', idsOficios);

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
  /// (id_usuario, dados_profissionais, grupo_empresa da conta ativa).
  Future<(int?, Map<String, dynamic>?, int?)> _contextoConta() async {
    final db = Supabase.instance.client;
    final user = db.auth.currentUser;
    if (user == null) return (null, null, null);
    final u = await db
        .from('usuarios')
        .select('id_usuario')
        .eq('auth_id', user.id)
        .maybeSingle();
    final idUsuario = (u?['id_usuario'] as num?)?.toInt();
    if (idUsuario == null) return (null, null, null);
    // Pela linha que tem dados de profissional (pode haver mais de uma).
    final dp = await RequisitosConta.dadosProfissionalLogado(
      'id_profissional, fk_perfil, fk_grupo_empresa, anos_experiencia, '
      'chave_pix, pagamento_aceito, metodo_entrega',
    );
    int? idGrupo;
    if (_contaEmpresaAtiva) {
      final empresa = await _buscarDadosEmpresa();
      idGrupo = (empresa?['id_grupo_empresa'] as num?)?.toInt();
    }
    return (idUsuario, dp, idGrupo);
  }

  Future<Map<String, int>> _carregarEstatisticas() async {
    final contagem = {
      'pendentes': 0,
      'ativos': 0,
      'concluidos': 0,
      'cancelados': 0,
    };
    if (widget.isVisitante) return contagem;
    try {
      final (_, dp, idGrupo) = await _contextoConta();
      final idProf = (dp?['id_profissional'] as num?)?.toInt();
      var query = Supabase.instance.client
          .from('solicitacoes')
          .select('fk_status, status!solicitacoes_fk_status_fkey(status)');
      if (_contaEmpresaAtiva) {
        if (idGrupo == null) return contagem;
        query = query.eq('fk_grupo_empresa', idGrupo);
      } else {
        if (idProf == null) return contagem;
        query = query
            .eq('fk_profissional', idProf)
            .isFilter('fk_grupo_empresa', null);
      }
      final rows = await query;
      for (final row in rows) {
        final st = (row['fk_status'] as num?)?.toInt();
        final rel = row['status'];
        final texto =
            (rel is Map
                    ? rel['status']
                    : rel is List && rel.isNotEmpty
                    ? (rel.first as Map)['status']
                    : null)
                ?.toString()
                .toLowerCase() ??
            '';
        if (st == 6 || texto.contains('conclu')) {
          contagem['concluidos'] = contagem['concluidos']! + 1;
        } else if (texto.contains('cancel') || texto.contains('recus')) {
          contagem['cancelados'] = contagem['cancelados']! + 1;
        } else if (st == 1 || texto == 'aberto' || texto == 'pendente') {
          // Abertas que o profissional ainda não respondeu.
          contagem['pendentes'] = contagem['pendentes']! + 1;
        } else {
          contagem['ativos'] = contagem['ativos']! + 1;
        }
      }
    } catch (e) {
      debugPrint('[estatisticas] $e');
    }
    return contagem;
  }

  /// Confere o que falta preencher para marcar os atalhos.
  Future<void> _atualizarPendencias() async {
    if (widget.isVisitante) return;
    final pendencias = <String>{};
    try {
      final db = Supabase.instance.client;
      final (_, dp, idGrupo) = await _contextoConta();
      if (dp == null) {
        // Sem conseguir ler os dados do profissional: marca tudo como
        // pendente (antes não mostrava nenhum aviso).
        if (mounted) {
          setState(
            () => _pendencias = {
              'enderecos',
              'entrega',
              'locomocao',
              'financeiro',
              'disponibilidade',
              'conta',
            },
          );
        }
        return;
      }
      final idProf = (dp['id_profissional'] as num?)?.toInt();
      bool vazio(Object? v) {
        final t = v?.toString().trim() ?? '';
        return t.isEmpty || t == 'null' || t == '[]';
      }

      Map<String, dynamic>? grupo;
      if (_contaEmpresaAtiva && idGrupo != null) {
        try {
          grupo = await db
              .from('grupo_empresa')
              .select('chave_pix, pagamento_aceito, metodo_entrega_empresa')
              .eq('id_grupo_empresa', idGrupo)
              .maybeSingle();
        } catch (_) {}
      }

      // Dados financeiros: Pix aceito e sem chave PIX.
      if (RequisitosConta.precisaChavePix(grupo ?? dp)) {
        pendencias.add('financeiro');
      }

      // Método de entrega: nenhum salvo.
      final metodo = grupo != null
          ? (grupo['metodo_entrega_empresa'] ?? dp['metodo_entrega'])
          : dp['metodo_entrega'];
      if (vazio(metodo) ||
          await RequisitosConta.entregaNuncaDefinida(
            idGrupo: grupo != null ? idGrupo : null,
            idProfissional: idProf,
          )) {
        pendencias.add('entrega');
      }
      // Locomoção (carro, moto...) e placa: também no atalho de entrega.
      if (await RequisitosConta.locomocaoPendente(
        idGrupo: grupo != null ? idGrupo : null,
        idProfissional: idProf,
      )) {
        pendencias.add('locomocao');
      }

      // Disponibilidade: sem dias definidos.
      try {
        final q = db
            .from('agenda_profissional')
            .select('dias_semana')
            .eq('fk_solicitacao', 0);
        final agenda = grupo != null
            ? await q.eq('fk_grupo_empresa', idGrupo!).limit(1).maybeSingle()
            : idProf == null
            ? null
            : await q.eq('fk_profissional', idProf).limit(1).maybeSingle();
        if (vazio(agenda?['dias_semana'])) pendencias.add('disponibilidade');
      } catch (_) {}

      // Modificar conta: sem descrição ou sem anos de experiência.
      if (!_contaEmpresaAtiva) {
        var descricao = '';
        final idPerfil = (dp['fk_perfil'] as num?)?.toInt();
        if (idPerfil != null) {
          try {
            final perfil = await db
                .from('perfil')
                .select('descricao_perfil')
                .eq('id_perfil', idPerfil)
                .maybeSingle();
            descricao = perfil?['descricao_perfil']?.toString().trim() ?? '';
          } catch (_) {}
        }
        if (descricao.isEmpty || vazio(dp['anos_experiencia'])) {
          pendencias.add('conta');
        }
      }

      // Meus endereços: nenhum cadastrado.
      try {
        final enderecos = grupo != null
            ? await db
                  .from('ass_grupo_empresa_endereco')
                  .select('fk_endereco')
                  .eq('fk_grupo_empresa', idGrupo!)
                  .limit(1)
            : idProf == null
            ? const <Map<String, dynamic>>[]
            : await db
                  .from('ass_profissional_endereco')
                  .select('fk_endereco')
                  .eq('fk_profissional', idProf)
                  .limit(1);
        if (enderecos.isEmpty) pendencias.add('enderecos');
      } catch (_) {}
      // Empresa (conta Loja ativa): sem "sobre", com anos de mercado no
      // padrão ou sem nenhum certificado → aviso em "Gerenciar Empresa".
      if (_contaEmpresaAtiva && idGrupo != null) {
        try {
          final g = await db
              .from('grupo_empresa')
              .select('descricao_empresa, anos_mercado')
              .eq('id_grupo_empresa', idGrupo)
              .maybeSingle();
          final certs = await db
              .from('certificados_profissional')
              .select('id_certificado')
              .eq('fk_grupo_empresa', idGrupo)
              .limit(1);
          final anos = g?['anos_mercado']?.toString().trim() ?? '';
          if (vazio(g?['descricao_empresa']) ||
              anos.isEmpty ||
              anos == '1' ||
              certs.isEmpty) {
            pendencias.add('empresa');
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[pendencias] $e');
    }
    if (mounted) setState(() => _pendencias = pendencias);
    // Mesmo aviso no ícone da aba Perfil/Empresa da barra inferior.
    RequisitosConta.abaPendenteProfissional.value = pendencias.isNotEmpty;
  }

  /// Abre um atalho e, na volta, reconfere o que ainda falta preencher.
  Future<void> _abrirAtalho(Widget pagina) async {
    await Navigator.of(context).push(_rotaSemAnimacao(pagina));
    if (mounted) unawaited(_atualizarPendencias());
  }

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

      final servicos = await _carregarServicosAgendados(
        idProfissional: idProfissional,
        idEmpresa: idEmpresa,
        inicio: primeiraData,
        fim: ultimaData,
      );

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
            servicos: servicos
                .where(
                  (servico) => _formatarDataCompleta(servico.data) == chave,
                )
                .toList(),
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
        servicos: const [],
      ),
    );
  }

  Future<List<_ServicoAgendado>> _carregarServicosAgendados({
    required int? idProfissional,
    required int? idEmpresa,
    required String inicio,
    required String fim,
  }) async {
    final supabase = Supabase.instance.client;
    final query = supabase
        .from('solicitacoes')
        .select(
          'id_solicitacao, data_agendada, fk_usuario, fk_servico_prof, '
          'fk_grupo_empresa, fk_profissional, '
          'status!solicitacoes_fk_status_fkey(status)',
        )
        .not('data_agendada', 'is', null)
        .gte('data_agendada', inicio)
        .lte('data_agendada', fim);
    final rows = _contaEmpresaAtiva
        ? await query.eq('fk_grupo_empresa', idEmpresa!)
        : await query.eq('fk_profissional', idProfissional!);

    final resultado = <_ServicoAgendado>[];
    for (final raw in rows) {
      final status = raw['status'];
      final statusTexto = status is Map
          ? status['status']?.toString().toLowerCase() ?? ''
          : status is List && status.isNotEmpty
          ? (status.first as Map)['status']?.toString().toLowerCase() ?? ''
          : '';
      if (statusTexto.contains('recus') || statusTexto.contains('cancel')) {
        continue;
      }

      final data = _parseDataExcecao(raw['data_agendada']);
      final id = (raw['id_solicitacao'] as num?)?.toInt();
      if (data == null || id == null) continue;

      var nomeCliente = 'Cliente';
      String? fotoCliente;
      final idCliente = (raw['fk_usuario'] as num?)?.toInt();
      if (idCliente != null) {
        final cliente = await supabase
            .from('usuarios')
            .select('nome, foto_perfil_url')
            .eq('id_usuario', idCliente)
            .maybeSingle();
        final nome = cliente?['nome']?.toString().trim() ?? '';
        if (nome.isNotEmpty) nomeCliente = nome;
        final foto = cliente?['foto_perfil_url']?.toString().trim() ?? '';
        if (foto.isNotEmpty) fotoCliente = foto;
      }

      var titulo = 'Serviço';
      final idServico = (raw['fk_servico_prof'] as num?)?.toInt();
      if (idServico != null) {
        final servico = await supabase
            .from('servicos_profissional')
            .select('titulo')
            .eq('id_servico_prof', idServico)
            .maybeSingle();
        final tituloRaw = servico?['titulo']?.toString().trim() ?? '';
        if (tituloRaw.isNotEmpty) titulo = tituloRaw;
      }
      resultado.add(
        _ServicoAgendado(
          idSolicitacao: id,
          nomeCliente: nomeCliente,
          fotoCliente: fotoCliente,
          tituloServico: titulo,
          data: data,
        ),
      );
    }
    return resultado;
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
    mostrarDialogoComoSheet<void>(
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

  /// Abre a tela certa da solicitação (status, etapa e método de entrega).
  void _abrirServicoAgendado(_ServicoAgendado servico) {
    abrirSolicitacaoPorStatus(
      context,
      servico.idSolicitacao,
      comoProfissional: true,
    ).then((_) {
      if (mounted) {
        setState(() => _agendaSemanaFuture = _carregarAgendaSemana());
      }
    });
  }

  /// Dia com vários serviços: lista estilizada; toque abre a solicitação.
  void _mostrarServicosDoDia(_DiaAgendaCalendario dia) {
    const meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    const semana = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];
    final d = dia.data;
    final servicos = [...dia.servicos]
      ..sort((a, b) => a.data.compareTo(b.data));
    String hora(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: _primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${d.day}',
                        style: const TextStyle(
                          color: _primaryBlue,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${semana[d.weekday - 1]}, ${d.day} de ${meses[d.month - 1]}',
                            style: const TextStyle(
                              color: _titleDark,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${servicos.length} serviços agendados',
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: servicos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final s = servicos[i];
                      final foto = s.fotoCliente ?? '';
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(ctx);
                          _abrirServicoAgendado(s);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              CorOriginal(interface: true, child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _primaryBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  hora(s.data),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              )),
                              const SizedBox(width: 10),
                              CorOriginal(child: CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFDCE5EE),
                                backgroundImage: foto.startsWith('http')
                                    ? NetworkImage(foto)
                                    : null,
                                child: foto.startsWith('http')
                                    ? null
                                    : Text(
                                        obterIniciais(s.nomeCliente),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF5E6F7E),
                                        ),
                                      ),
                              )),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.tituloServico,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _titleDark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      s.nomeCliente,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        _ctxSheetPerfil = bottomSheetContext;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(bottomSheetContext).pop(),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: desfoque(5),
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
                          // Toda a área (foto/nome/endereço) abre a troca de conta SOMENTE se for Loja.
                          FutureBuilder<String?>(
                            future: _tipoPerfilFuture,
                            builder: (context, tipoSnapshot) {
                              final podeTrocarConta =
                                  tipoSnapshot.data?.trim() == 'Loja';

                              return Material(
                                key: _kSheetConta,
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: podeTrocarConta
                                      ? () async {
                                          Navigator.of(
                                            bottomSheetContext,
                                          ).pop();
                                          await _mostrarBottomSheetTrocaConta();
                                        }
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
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
                                                    ? ImagemApp(child: Image.network(
                                                        fotoUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, _, _) =>
                                                            _buildAvatarIniciais(
                                                              nome,
                                                            ),
                                                      ))
                                                    : _buildAvatarIniciais(
                                                        nome,
                                                      ),
                                              ),
                                            ),
                                            Positioned(
                                              bottom: 0,
                                              right: 0,
                                              child: CorOriginal(interface: true, child: Container(
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
                                              )),
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
                                                        color: Color(
                                                          0xFF64748B,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (podeTrocarConta) ...[
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
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF1F5F9),
                          ),
                          const SizedBox(height: 8),

                          // Opção 1: dados pessoais ou empresariais
                          _buildOpcaoBottomSheet(
                            iconeWidget: const Icon(
                              Icons.person_outline_rounded,
                              color: _primaryBlue,
                              size: 28,
                            ),
                            titulo: _contaEmpresaAtiva
                                ? 'Editar dados empresariais'
                                : 'Editar dados pessoais',
                            onTap: () async {
                              Navigator.of(bottomSheetContext).pop();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _contaEmpresaAtiva
                                      ? const GestaoEquipePage()
                                      : const EditarInformacoesPage(),
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

                          // Opção 3: área de atuação ou configurações da empresa
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
                            titulo: _contaEmpresaAtiva
                                ? 'Configurações da empresa'
                                : 'Minha área de atuação',
                            onTap: () async {
                              Navigator.of(bottomSheetContext).pop();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _contaEmpresaAtiva
                                      ? const ConfiguracoesEmpresaPage()
                                      : const AreaAtuacaoPage(),
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
      throw StateError('Usuário não autenticado.');
    }

    // 1. Dados do Usuário (Profissional CNPJ)
    final usuario = await supabase
        .from('usuarios')
        .select('id_usuario, nome, foto_perfil_url, fk_tipo_pessoa')
        .eq('auth_id', user.id)
        .maybeSingle();

    final nomeProf = usuario?['nome']?.toString().trim() ?? '';
    if (nomeProf.isEmpty) {
      throw StateError('Nome do profissional não encontrado no banco.');
    }
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

    // Se o grupo ainda não foi encontrado, mas o tipo_perfil é 'Loja':
    if (grupo == null && idPerfil != null) {
      try {
        final perfilRow = await supabase
            .from('perfil')
            .select('tipo_perfil')
            .eq('id_perfil', idPerfil)
            .maybeSingle();
        final tipo = perfilRow?['tipo_perfil']?.toString();
        if (tipo == 'Loja') {
          // Busca nome fantasia ou razão social da PJ
          String? nomePj;
          final tipoPessoaId = usuario?['fk_tipo_pessoa'];
          if (tipoPessoaId != null) {
            try {
              final ass = await supabase
                  .from('ass_tipo_pessoa')
                  .select('fk_pessoa_juridica')
                  .eq('id_tipo_pessoa', tipoPessoaId)
                  .maybeSingle();
              final fkPj = ass?['fk_pessoa_juridica'];
              if (fkPj != null) {
                final pj = await supabase
                    .from('pessoa_juridica')
                    .select('nome_fantasia, razao_social')
                    .eq('id_pessoa_juridica', fkPj)
                    .maybeSingle();
                nomePj = pj?['nome_fantasia']?.toString().trim();
                if (nomePj == null || nomePj.isEmpty) {
                  nomePj = pj?['razao_social']?.toString().trim();
                }
              }
            } catch (_) {}
          }
          final nomeEmpresaCriar = (nomePj != null && nomePj.isNotEmpty)
              ? nomePj
              : (nomeProf.isNotEmpty ? nomeProf : 'Minha Loja');

          try {
            final novoGrupo = await supabase
                .from('grupo_empresa')
                .insert({
                  'fk_perfil': idPerfil,
                  'nome_empresa': nomeEmpresaCriar,
                  'tag_empresa': 'LOJA',
                })
                .select('*')
                .maybeSingle();

            if (novoGrupo != null) {
              grupo = novoGrupo;
              final novoIdGrupo = (novoGrupo['id_grupo_empresa'] as num?)
                  ?.toInt();
              if (novoIdGrupo != null && idProfissional != null) {
                await supabase
                    .from('dados_profissionais')
                    .update({'fk_grupo_empresa': novoIdGrupo})
                    .eq('id_profissional', idProfissional);
              }
            }
          } catch (e) {
            debugPrint('Falha ao auto-criar grupo_empresa para Loja: $e');
          }

          // Fallback caso o insert tenha falhado mas o usuário é 'Loja'
          grupo ??= {
            'nome_empresa': nomeEmpresaCriar,
            'foto_url_empresa': null,
            'seguidores_empresa': 0,
          };
        }
      } catch (_) {}
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
      'nome_empresa': nomeEmpresa ?? '',
      'foto_empresa': (fotoEmpresa != null && fotoEmpresa.isNotEmpty)
          ? fotoEmpresa
          : null,
      'seguidores_empresa': segEmp,
      'tem_empresa': grupo != null,
    };
  }

  Future<void> _mostrarBottomSheetTrocaConta() async {
    final tipo = await _buscarTipoPerfil();
    if (tipo != 'Loja' || !mounted) return;

    if (_cacheInfosContas == null) {
      await _precarregarInfosContas();
      if (!mounted) return;
    } else {
      _precarregarInfosContas();
    }
    if (!mounted) return;
    final infos = _cacheInfosContas;
    if (infos == null || infos['tem_empresa'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma conta de empresa foi encontrada.'),
        ),
      );
      return;
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
                  filter: desfoque(5),
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
                      child: StatefulBuilder(
                        builder: (context, _) {
                          return _buildConteudoTrocaConta(sheetContext, infos);
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
              CorOriginal(child: CircleAvatar(
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
              )),
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
              CorOriginal(interface: true, child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: _primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check, color: Colors.white, size: 16),
                ),
              )),
            ],
          ),
        ),

        // Seguidores da conta ativa.
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
              Future<void>.delayed(
                const Duration(milliseconds: 900),
                () => _tutorial(),
              );
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
                  CorOriginal(child: CircleAvatar(
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
                  )),
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
                      CorOriginal(child: CircleAvatar(
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
                      )),
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
                                    ? ImagemApp(child: Image.network(
                                        imagem.path,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _buildPlaceholderImagemSelecionada(),
                                      ))
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
                                  child: CorOriginal(interface: true, child: Container(
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
                                  )),
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
                                    CupertinoIcons.paperplane,
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
          // Arrastar para baixo recarrega a home (dados, agenda, avisos...).
          child: RefreshIndicator(
            color: _primaryBlue,
            onRefresh: () async {
              _recarregarPaginaAtual();
              await Future.wait(
                [
                  _dadosProfissionalFuture,
                  _agendaSemanaFuture,
                  _estatisticasFuture,
                ].map((f) => f.catchError((_) => null)),
              );
            },
            child: ListView(
              controller: _rolagem,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                // ================= CARTÃO DE PERFIL =================
                FutureBuilder<Map<String, dynamic>?>(
                  future: _dadosProfissionalFuture,
                  builder: (context, snapshot) {
                    final nomeCompleto =
                        snapshot.data?['nome'] as String? ??
                        'Nome não encontrado';
                    final fotoUrl =
                        snapshot.data?['foto_perfil_url'] as String?;

                    return FutureBuilder<String?>(
                      future: _enderecoFuture,
                      builder: (context, enderecoSnapshot) {
                        final enderecoTexto =
                            enderecoSnapshot.data ??
                            'Nenhum endereço cadastrado';

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
                              key: _kCabecalho,
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
                                                CorOriginal(child: CircleAvatar(
                                                  radius: 34,
                                                  backgroundColor: const Color(
                                                    0xFFE1F5FE,
                                                  ),
                                                  backgroundImage:
                                                      fotoUrl != null
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
                                                )),
                                                Positioned(
                                                  bottom: -6,
                                                  child: CorOriginal(interface: true, child: Container(
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
                                                  )),
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _titleDark,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    key: _kEndereco,
                                                    enderecoTexto,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade600,
                                                      height: 1.3,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            BotaoAjuda(
                                              key: _kAjuda,
                                              cor: _primaryBlue,
                                              passos: () => _passosHomeProf(
                                                apresentacao: false,
                                                cnpj: false,
                                                temAreas:
                                                    _kAreas.currentContext !=
                                                    null,
                                              ),
                                            ),
                                            _buildBotaoNotificacao(),
                                          ],
                                        ),
                                        if (oficios.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Wrap(
                                            key: _kAreas,
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
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    tagEmpresaTexto,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                    final fotoUrl =
                        snapshot.data?['foto_perfil_url'] as String?;
                    return KeyedSubtree(
                      key: _kPostagem,
                      child: _buildCaixaCriacaoPostagem(
                        fotoUrl: fotoUrl,
                        nome: nomeCompleto,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // ================= RADAR GEOGRÁFICO =================
                Row(
                  key: _kRadar,
                  children: const [
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
                // Prévia do mapa do Radar (raio, você e os pedidos da área);
                // tocar abre o Radar. Ao voltar, a prévia recarrega.
                PreviaRadarProfissional(
                  key: ValueKey('previaRadar$_versaoPreviaRadar'),
                  chaveInfo: _kRadarInfo,
                  aoTocar: () async {
                    await Navigator.of(context).push(
                      AppNavigationUtil.rotaSemAnimacao(
                        SolicitacaoGeograficaProfissionalPage(
                          isVisitante: widget.isVisitante,
                        ),
                        nome: 'SolicitacaoGeograficaProfissionalPage',
                      ),
                    );
                    if (mounted) setState(() => _versaoPreviaRadar++);
                  },
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
                      FutureBuilder<Map<String, int>>(
                        future: _estatisticasFuture,
                        builder: (context, snapshot) {
                          final c = snapshot.data;
                          String v(String chave) =>
                              c == null ? '–' : '${c[chave] ?? 0}';
                          return Row(
                            key: _kEstatisticas,
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Pendentes',
                                  v('pendentes'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard('Ativos', v('ativos')),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  'Concluídos',
                                  v('concluidos'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatCard(
                                  'Cancelados',
                                  v('cancelados'),
                                ),
                              ),
                            ],
                          );
                        },
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
                      KeyedSubtree(key: _kAgenda, child: _buildWeekCalendar()),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ================= ATALHOS / PAINEL DE AÇÕES =================
                // 2 páginas (deslize para o lado); segure para reorganizar.
                FutureBuilder<String?>(
                  future: _tipoPerfilFuture,
                  builder: (context, snapshot) => Container(
                    key: _kAtalhos,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 12,
                    ),
                    decoration: _cardDecoration(),
                    child: PainelAtalhos(
                      mostrarAtalho: _atalhoEmFoco,
                      chaveOrdem: _contaEmpresaAtiva
                          ? 'atalhos_home_empresa_v1'
                          : 'atalhos_home_independente_v1',
                      itens: _atalhos(snapshot.data),
                      construir: (a) => KeyedSubtree(
                        // Só no tutorial (ver _tutorialAtivo).
                        key: _tutorialAtivo ? _kAtalho[a.id] : null,
                        child: _buildQuickOption(
                          a.icone,
                          a.rotulo,
                          onTap: a.aoTocar,
                          pendente: a.pendente,
                          bloqueado: a.bloqueado,
                        ),
                      ),
                    ),
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
        ),
        bottomNavigationBar: BottomNavigationBarProfissional(
          key: _kBarra,
          currentIndex: _currentIndex,
          isContaEmpresa: _contaEmpresaAtiva,
          // A barra recebe diretamente o estado da conta ativa para alternar
          // entre Perfil e Empresa sem depender apenas do cache.
          // Tocar na aba atual (Home) recarrega os dados da página.
          onReselecionarAbaAtual: (_) => _recarregarPaginaAtual(),
          onTap: (index) {
            if (index == 1) {
              // Aba Radar: solicitações geográficas da área do profissional.
              Navigator.of(context).push(
                AppNavigationUtil.rotaSemAnimacao(
                  SolicitacaoGeograficaProfissionalPage(
                    isVisitante: widget.isVisitante,
                  ),
                  nome: 'SolicitacaoGeograficaProfissionalPage',
                ),
              );
              return;
            }
            if (index == 2) {
              // Aba Mensagens: push direto com nome de rota estável, igual
              // às demais telas (evita o navegarAba reaproveitar a rota
              // errada e causar conflito entre Gestão/Mensagens).
              Navigator.of(context).push(
                AppNavigationUtil.rotaSemAnimacao(
                  TelaMensagensPage(
                    isVisitante: widget.isVisitante,
                    isProfissional: true,
                  ),
                  nome: 'TelaMensagensPage',
                ),
              );
              return;
            }
            if (index == 3) {
              // Aba Serviços: abre os serviços solicitados ao profissional
              // (conta independente) ou à empresa (conta empresa).
              Navigator.of(context).push(
                AppNavigationUtil.rotaSemAnimacao(
                  const MeusServicosSolicitadosPage(),
                  nome: 'MeusServicosSolicitadosPage',
                ),
              );
              return;
            }
            if (index == 4) {
              // 5º botão: conta empresa -> "Empresa" (gestão), senão "Perfil".
              // Usa o cache síncrono da barra (igual às demais telas), sem
              // depender do setState assíncrono de _contaEmpresaAtiva.
              final ehEmpresa = _contaEmpresaAtiva;
              if (ehEmpresa) {
                Navigator.of(context).push(
                  AppNavigationUtil.rotaSemAnimacao(
                    const GestaoEquipePage(),
                    nome: 'GestaoEquipePage',
                  ),
                );
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
          return const SkeletonAgenda();
        }

        // Dias maiores (rolam na horizontal quando não cabem).
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(dias.length, (index) {
              final dia = dias[index];
              return SizedBox(
                width: 78,
                child: Column(
                  // stretch: todos os dias com a mesma largura, até os
                  // vazios (antes ficavam finos, do tamanho do número).
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _abreviacaoDiaSemana(dia.data.weekday % 7),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildCelulaDiaAgenda(dia),
                  ],
                ),
              );
            }),
          ),
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

    if (dia.temServico) {
      final servico = dia.servicos.length == 1 ? dia.servicos.first : null;
      return GestureDetector(
        // Um serviço: abre direto; vários: lista do dia num bottom sheet.
        onTap: servico != null
            ? () => _abrirServicoAgendado(servico)
            : () => _mostrarServicosDoDia(dia),
        child: CorOriginal(interface: true, child: Container(
          height: 104,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: _primaryBlue,
            borderRadius: BorderRadius.circular(12),
            border: isHoje ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${dia.data.day}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (isHoje) ...[
                const SizedBox(height: 2),
                const Text(
                  'Hoje',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                servico?.nomeCliente ?? '${dia.servicos.length} serviços',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        )),
      );
    }

    if (isExcecao) {
      // Exceção parcial (hora_ini e hora_fim preenchidos): borda vermelha,
      // fundo claro, e exibe o intervalo de horário em vez do motivo.
      if (isExcecaoParcial) {
        final horaIni = _horaCurta(dia.horaInicioExcecao!);
        final horaFim = _horaCurta(dia.horaFimExcecao!);
        return GestureDetector(
          onTap: () => _mostrarPopupExcecao(dia),
          child: Container(
            height: 104,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
                    fontSize: 22,
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
                      fontSize: 11,
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
                    fontSize: 11,
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
          height: 104,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: _vermelhoExcecao,
            borderRadius: BorderRadius.circular(12),
            border: isHoje ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${dia.data.day}',
                style: const TextStyle(
                  fontSize: 22,
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
                    fontSize: 11,
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
                  fontSize: 11,
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
        height: 104,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: _primaryBlue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
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
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isHoje ? _primaryBlue : _primaryBlue,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Disponível',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
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
      height: 104,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
              fontSize: 22,
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
                fontSize: 11,
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
          CorOriginal(child: CircleAvatar(
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
          )),
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
            key: _kAddImagem,
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
                      child: CorOriginal(interface: true, child: Container(
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
                      )),
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
                child: Icon(
                  CupertinoIcons.paperplane,
                  color: _primaryBlue,
                  size: 26,
                ),
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
                ? ImagemApp(child: Image.network(
                    postagem.imagemUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        _buildPlaceholderImagemPostagem(),
                  ))
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

  /// [pendente]: falta preencher algo → bolinha laranja com "!" no canto.
  /// [bloqueado]: atalho indisponível para a conta → cinza.
  /// Atalhos da home (ordem padrão; o usuário pode reorganizar).
  /// Página 1: os do dia a dia; página 2: os demais.
  List<AtalhoItem> _atalhos(String? tipoPerfil) {
    Future<void> abrirDisponibilidade() async {
      final navigator = Navigator.of(context);
      final empresa = _contaEmpresaAtiva ? await _buscarDadosEmpresa() : null;
      final idGrupo = (empresa?['id_grupo_empresa'] as num?)?.toInt();
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
        setState(() => _agendaSemanaFuture = _carregarAgendaSemana());
        unawaited(_atualizarPendencias());
      }
    }

    Future<void> abrirCertificados() async {
      final navigator = Navigator.of(context);
      final idGrupo = _contaEmpresaAtiva ? await _buscarIdGrupoEmpresa() : null;
      if (!mounted) return;
      await navigator.push(
        _rotaSemAnimacao(CertificadosPage(idGrupoEmpresa: idGrupo)),
      );
      if (mounted) unawaited(_atualizarPendencias());
    }

    final independente = tipoPerfil == 'Independente';
    return [
      const AtalhoItem(
        id: 'estatisticas',
        icone: Icons.bar_chart,
        rotulo: 'Estatísticas\ne Gráficos',
      ),
      AtalhoItem(
        id: 'enderecos',
        icone: Icons.location_on_outlined,
        rotulo: 'Meus\nEndereços',
        pendente: _pendencias.contains('enderecos'),
        aoTocar: () =>
            _abrirAtalho(const MeusEnderecosPage(isProfissional: true)),
      ),
      AtalhoItem(
        id: 'servicos',
        icone: Icons.work_outline,
        rotulo: 'Meus\nServiços',
        aoTocar: () => Navigator.of(
          context,
        ).push(_rotaSemAnimacao(const MeusServicosProfissionalPage())),
      ),
      AtalhoItem(
        id: 'entrega',
        icone: Icons.local_shipping_outlined,
        rotulo: 'Método de\nEntrega',
        pendente:
            _pendencias.contains('entrega') ||
            _pendencias.contains('locomocao'),
        aoTocar: () => _abrirAtalho(const MetodoEntregaProfissionalPage()),
      ),
      const AtalhoItem(
        id: 'verificado',
        icone: Icons.verified_outlined,
        rotulo: 'Plano de\nVerificado',
      ),
      AtalhoItem(
        id: 'disponibilidade',
        icone: Icons.calendar_month_outlined,
        rotulo: 'Ajustar\nDisponibilidade',
        pendente: _pendencias.contains('disponibilidade'),
        aoTocar: abrirDisponibilidade,
      ),
      AtalhoItem(
        id: 'financeiro',
        icone: Icons.account_balance_wallet_outlined,
        rotulo: 'Dados\nFinanceiros',
        pendente: _pendencias.contains('financeiro'),
        aoTocar: () =>
            _abrirAtalho(const MeusDadosFinanceirosProfissionalPage()),
      ),
      if (_contaEmpresaAtiva)
        AtalhoItem(
          id: 'empresa',
          icone: Icons.storefront_rounded,
          rotulo: 'Gerenciar\nEmpresa',
          pendente: _pendencias.contains('empresa'),
          aoTocar: () async {
            await Navigator.of(
              context,
            ).push(_rotaSemAnimacao(const GestaoEquipePage()));
            if (mounted) {
              setState(() => _tipoPerfilFuture = _buscarTipoPerfil());
              unawaited(_atualizarPendencias());
            }
          },
        )
      else
        AtalhoItem(
          id: 'conta',
          icone: Icons.manage_accounts_outlined,
          rotulo: 'Modificar\nconta',
          pendente: _pendencias.contains('conta'),
          aoTocar: () async {
            await _abrirAtalho(const ModificarContaProfissionalPage());
            if (mounted) {
              setState(() => _tipoPerfilFuture = _buscarTipoPerfil());
            }
          },
        ),
      AtalhoItem(
        id: 'certificados',
        icone: Icons.workspace_premium_outlined,
        rotulo: 'Certificados',
        aoTocar: abrirCertificados,
      ),
      // ---- página 2 ----
      if (!_contaEmpresaAtiva)
        AtalhoItem(
          id: 'empresa_associada',
          icone: Icons.storefront_outlined,
          rotulo: 'Empresa\nassociada',
          bloqueado: independente,
          aoTocar: independente
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Seu perfil é independente: você não está associado '
                      'a uma empresa.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                )
              : () => Navigator.of(
                  context,
                ).push(_rotaSemAnimacao(const EmpresaAssociadaPage())),
        ),
      AtalhoItem(
        id: 'historico',
        icone: Icons.history_rounded,
        rotulo: 'Histórico de\nServiços',
        aoTocar: () => Navigator.of(
          context,
        ).push(_rotaSemAnimacao(const MeuHistoricoServicoProfissionalPage())),
      ),
      // Conta de empresa: sem "Meus documentos"; o dono (não os
      // funcionários) tem as configurações da empresa.
      if (!_contaEmpresaAtiva)
        AtalhoItem(
          id: 'documentos',
          icone: Icons.badge_outlined,
          rotulo: 'Meus\nDocumentos',
          aoTocar: () => _abrirAtalho(const MeusDocumentosPage()),
        ),
      if (_contaEmpresaAtiva && _souDonoEmpresa)
        AtalhoItem(
          id: 'config_empresa',
          icone: Icons.settings_suggest_outlined,
          rotulo: 'Configurações\nda Empresa',
          aoTocar: () => _abrirAtalho(const ConfiguracoesEmpresaPage()),
        ),
      // Independente e loja (cada um vê só os dados da conta ativa).
      AtalhoItem(
        id: 'avaliacoes',
        icone: Icons.star_outline_rounded,
        rotulo: 'Minhas\nAvaliações',
        aoTocar: () => _abrirAtalho(const MinhasAvaliacoesProfissionalPage()),
      ),
      AtalhoItem(
        id: 'estatisticas',
        icone: Icons.insights_rounded,
        rotulo: 'Estatísticas\ne Gráficos',
        aoTocar: () => _abrirAtalho(const EstatisticasProfissionalPage()),
      ),
      AtalhoItem(
        id: 'notificacoes',
        icone: Icons.notifications_none_rounded,
        rotulo: 'Notificações',
        aoTocar: () => _abrirAtalho(
          const MinhasNotificacoesPage(soDaContaProfissionalAtiva: true),
        ),
      ),
      if (!_contaEmpresaAtiva) ...[
        AtalhoItem(
          id: 'area_atuacao',
          icone: Icons.handyman_outlined,
          rotulo: 'Área de\nAtuação',
          aoTocar: () => _abrirAtalho(const AreaAtuacaoPage()),
        ),
        AtalhoItem(
          id: 'editar_dados',
          icone: Icons.edit_note_rounded,
          rotulo: 'Editar Meus\nDados',
          aoTocar: () => _abrirAtalho(const EditarInformacoesPage()),
        ),
        AtalhoItem(
          id: 'configuracoes',
          icone: Icons.settings_outlined,
          rotulo: 'Configurações',
          aoTocar: () => _abrirAtalho(const TelaConfiguracoesClientePage()),
        ),
      ],
    ];
  }

  /// Dono do CNPJ (a empresa usa o mesmo perfil): vê as configurações da
  /// empresa nos atalhos.
  bool _souDonoEmpresa = false;

  Future<void> _verificarDonoEmpresa() async {
    try {
      final dp = await RequisitosConta.dadosProfissionalLogado(
        'id_profissional, fk_perfil',
      );
      final perfil = dp?['fk_perfil'];
      if (perfil == null) return;
      final g = await Supabase.instance.client
          .from('grupo_empresa')
          .select('id_grupo_empresa')
          .eq('fk_perfil', perfil)
          .limit(1);
      if (mounted) setState(() => _souDonoEmpresa = (g as List).isNotEmpty);
    } catch (_) {}
  }

  Widget _buildQuickOption(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool pendente = false,
    bool bloqueado = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: CorOriginal(interface: true, ativo: !(bloqueado), child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: bloqueado ? const Color(0xFFD1D5DB) : _primaryBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    bloqueado ? Icons.lock_outline_rounded : icon,
                    color: Colors.white,
                    size: 26,
                  ),
                )),
              ),
            ),
            Positioned(
              top: -5,
              right: -5,
              child: AnimatedScale(
                scale: pendente && !bloqueado ? 1 : 0,
                duration: duracao(const Duration(milliseconds: 220)),
                curve: Curves.easeOutBack,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Text(
                    '!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: bloqueado ? const Color(0xFF9CA3AF) : _titleDark,
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
              CorOriginal(interface: true, child: Container(
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
              )),
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
