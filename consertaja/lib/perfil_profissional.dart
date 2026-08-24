import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/postagem_resumo.dart';
import 'services/postagens_profissional_service.dart';
import 'utils/cor_oficio.dart';
import 'utils/iniciais.dart';
import 'widgets/tag_oficio.dart';

class PerfilProfissionalPage extends StatefulWidget {
  final String nomeInicial;
  final String imagemInicial;
  final String profissao;
  final double avaliacao;
  final int totalAvaliacoes;

  const PerfilProfissionalPage({
    super.key,
    required this.nomeInicial,
    required this.imagemInicial,
    this.profissao = 'Profissional independente',
    this.avaliacao = 4.9,
    this.totalAvaliacoes = 120,
  });

  @override
  State<PerfilProfissionalPage> createState() => _PerfilProfissionalPageState();
}

class _PerfilProfissionalPageState extends State<PerfilProfissionalPage> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _bannerDark = Color(0xFF1A3A5C);
  static const Color _priceOrange = Color(0xFFE6A817);
  static const double _pinnedHeaderHeight = 52;
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
  bool _showFloatingButton = false;
  bool _isAtBottom = false;
  double _lastScrollOffset = 0;
  bool _isScrollingProgrammatically = false;
  DateTime _ultimaAtualizacaoAba = DateTime.fromMillisecondsSinceEpoch(0);

  String _nome = '';
  String? _fotoUrl;
  bool _carregandoPerfil = true;

  String _filtroComentario = 'Principais';
  String _categoriaServico = 'Todos';
  bool _descricaoExpandida = false;
  String _anosExperiencia = '0-1 ano';
  String _descricaoPerfil = '';
  String _textoDisponibilidade = 'Disponibilidade';
  String _faixaHorarioDisponibilidade = '--:-- - --:--';

  DateTime _mesSelecionado = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  int? _idProfissional;
  int? _idPerfilProfissional;
  int? _idUsuarioLogado;
  bool _seguindoProfissional = false;
  bool _carregandoSeguimento = false;
  bool _alterandoSeguimento = false;
  int _totalSeguidores = 0;
  List<OficioInfo> _oficios = [];
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

  static const Color _blockedRed = Color(0xFF9B2335);
  static const Color _blockedBg = Color(0xFFFFF0F3);
  static const Color _blockedBorder = Color(0xFFCE4257);

  int _likesComentario1 = 0;
  bool _likedComentario1 = false;
  int _likesComentario2 = 1;
  bool _likedComentario2 = true;
  int _likesComentario3 = 0;
  bool _likedComentario3 = false;

  final List<Map<String, dynamic>> _avaliacoes = [
    {
      'nome': 'Luiz Fernando',
      'iniciais': 'LF',
      'nota': 5.0,
      'tempo': 'há 8 dias',
      'texto': 'Muito bom',
    },
    {
      'nome': 'Gabriel Santos',
      'iniciais': 'GS',
      'nota': 1.0,
      'tempo': 'há 8 dias',
      'texto': 'Moro em diadema',
    },
    {
      'nome': 'Kauã Andrade',
      'iniciais': 'KA',
      'nota': 1.0,
      'tempo': 'há 12 dias',
      'texto': 'Arrebentaram o cabo da minha panela',
    },
  ];

  final List<Map<String, dynamic>> _servicos = [
    {
      'titulo': 'Conserto de cabo de panela',
      'tag': 'Conserto de panela',
      'avaliacao': 4.9,
      'totalAvaliacoes': 253,
      'preco': 15.99,
      'imagem': 'assets/images/panela.png',
    },
    {
      'titulo': 'Conserto de cabo de panela',
      'tag': 'Conserto de panela',
      'avaliacao': 4.9,
      'totalAvaliacoes': 253,
      'preco': 15.99,
      'imagem': 'assets/images/panela.png',
    },
    {
      'titulo': 'Conserto de cabo de panela',
      'tag': 'Conserto de panela',
      'avaliacao': 4.9,
      'totalAvaliacoes': 253,
      'preco': 15.99,
      'imagem': 'assets/images/panela.png',
    },
    {
      'titulo': 'Conserto de cabo de panela',
      'tag': 'Conserto de panela',
      'avaliacao': 4.9,
      'totalAvaliacoes': 253,
      'preco': 15.99,
      'imagem': 'assets/images/panela.png',
    },
  ];

  final List<String> _categorias = [
    'Todos',
    'Costura',
    'Panelas',
    'Encanamento',
    'Cha',
  ];

  @override
  void initState() {
    super.initState();
    _nome = widget.nomeInicial.isNotEmpty
        ? widget.nomeInicial
        : 'Nome não encontrado';
    if (widget.imagemInicial.startsWith('http://') ||
        widget.imagemInicial.startsWith('https://')) {
      _fotoUrl = widget.imagemInicial;
    }
    _scrollController.addListener(_onScroll);
    _carregarUsuarioLogado();
    _carregarDadosProfissional();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosProfissional() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('usuarios')
          .select('nome, foto_perfil_url, id_usuario')
          .eq('tipo_conta', 'Profissional')
          .ilike('nome', '%${widget.nomeInicial}%')
          .maybeSingle();

      if (response != null && mounted) {
        int? idProfissional;
        int? fkPerfil;
        String? anosExperiencia;
        String? descricaoPerfil;
        final fkUsuario = response['id_usuario'];
        if (fkUsuario != null) {
          final dadosProf = await supabase
              .from('dados_profissionais')
              .select('id_profissional, fk_perfil, anos_experiencia')
              .eq('fk_usuario', fkUsuario)
              .maybeSingle();
          idProfissional = (dadosProf?['id_profissional'] as num?)?.toInt();
          fkPerfil = (dadosProf?['fk_perfil'] as num?)?.toInt();
          anosExperiencia = dadosProf?['anos_experiencia']?.toString();

          if (fkPerfil != null) {
            final perfil = await supabase
                .from('perfil')
                .select('descricao_perfil')
                .eq('id_perfil', fkPerfil)
                .maybeSingle();
            descricaoPerfil = perfil?['descricao_perfil']?.toString();
          }
        }

        setState(() {
          _nome = response['nome']?.toString() ?? 'Nome não encontrado';
          final foto = response['foto_perfil_url']?.toString();
          if (foto != null && foto.isNotEmpty && foto != 'null') {
            _fotoUrl = foto;
          }
          _idProfissional = idProfissional;
          _idPerfilProfissional = fkPerfil;
          if (anosExperiencia != null && anosExperiencia.isNotEmpty) {
            _anosExperiencia = anosExperiencia;
          }
          if (descricaoPerfil != null && descricaoPerfil.isNotEmpty) {
            _descricaoPerfil = descricaoPerfil;
          }
          _postagensGaleriaFuture = fkPerfil != null
              ? _carregarPostagensGaleria(fkPerfil, limit: 6)
              : Future.value(<PostagemResumo>[]);
        });

        if (idProfissional != null) {
          await Future.wait([
            _carregarExcecoes(),
            _carregarOficios(idProfissional),
            _carregarAgendaProfissional(idProfissional),
          ]);
        }
        if (fkPerfil != null) {
          await _carregarSeguimento(fkPerfil);
        }
      }
    } catch (_) {
      // Mantém dados iniciais em caso de falha
    } finally {
      if (mounted) {
        setState(() => _carregandoPerfil = false);
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
    if (_alterandoSeguimento || idPerfil == null) return;

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

  String _formatarAnosExperiencia(String valor) {
    if (valor == 'Mais de 15 anos') return '+15';
    return valor;
  }

  String _formatarHoraAgenda(Object? raw) {
    if (raw == null) return '--:--';
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.toString());
    if (match == null) return '--:--';
    final hh = int.parse(match.group(1)!).toString().padLeft(2, '0');
    final mm = match.group(2)!;
    return '$hh:$mm';
  }

  String _tituloDia(int index) {
    const titulos = [
      'Domingo',
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
    ];
    return titulos[index];
  }

  String _abreviacaoDia(int index) {
    const abreviacoes = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];
    return abreviacoes[index];
  }

  String _formatarDiasSemanaAgenda(String diasRaw) {
    final diasNormalizados = diasRaw
        .split(',')
        .map((d) => d.trim().toLowerCase())
        .where((d) => d.isNotEmpty)
        .toList();

    final indices =
        diasNormalizados
            .map(_ordemDiasSemana.indexOf)
            .where((i) => i >= 0)
            .toSet()
            .toList()
          ..sort();

    if (indices.isEmpty) return 'Disponibilidade';
    if (indices.length == 1) return _tituloDia(indices.first);

    final sequencial = List.generate(
      indices.length - 1,
      (i) => i,
    ).every((i) => indices[i + 1] == indices[i] + 1);

    if (sequencial) {
      return '${_tituloDia(indices.first)} a ${_tituloDia(indices.last)}';
    }

    return indices.map(_abreviacaoDia).join(', ');
  }

  Future<void> _carregarAgendaProfissional(int idProfissional) async {
    try {
      final supabase = Supabase.instance.client;

      Map<String, dynamic>? agenda;
      try {
        agenda = await supabase
            .from('agenda_profissional')
            .select('dias_semana, hora_ini, hora_fim')
            .eq('fk_profissional', idProfissional)
            .eq('fk_solicitacao', 0)
            .limit(1)
            .maybeSingle();
      } catch (_) {
        agenda = await supabase
            .from('agenda_profissional')
            .select('dias_semana, hora_ini, hora_fim')
            .eq('fk_profissional', idProfissional)
            .limit(1)
            .maybeSingle();
      }

      final dias = _formatarDiasSemanaAgenda(
        agenda?['dias_semana']?.toString() ?? '',
      );
      final horaIni = _formatarHoraAgenda(agenda?['hora_ini']);
      final horaFim = _formatarHoraAgenda(agenda?['hora_fim']);

      if (!mounted) return;
      setState(() {
        _textoDisponibilidade = dias;
        _faixaHorarioDisponibilidade = '$horaIni - $horaFim';
      });
    } catch (e) {
      debugPrint('Erro ao carregar agenda_profissional: $e');
    }
  }

  String _formatarDataHora(DateTime data) {
    final dd = data.day.toString().padLeft(2, '0');
    final mm = data.month.toString().padLeft(2, '0');
    final yyyy = data.year.toString();
    final hh = data.hour.toString().padLeft(2, '0');
    final min = data.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy às $hh:$min';
  }

  String _formatarHora(DateTime data) {
    final hh = data.hour.toString().padLeft(2, '0');
    final min = data.minute.toString().padLeft(2, '0');
    return '$hh:$min';
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

  bool _erroRelacionadoAFkPostagem(PostgrestException erro) {
    final texto = '${erro.message} ${erro.details ?? ''} ${erro.hint ?? ''}'
        .toLowerCase();
    return erro.code == '42703' || texto.contains('fk_postagem');
  }

  bool _erroRelacionadoAIdCurtida(PostgrestException erro) {
    final texto = '${erro.message} ${erro.details ?? ''} ${erro.hint ?? ''}'
        .toLowerCase();
    return erro.code == '23502' && texto.contains('id_curtida_postagem');
  }

  bool _erroPermissaoRls(PostgrestException erro) {
    final texto = '${erro.message} ${erro.details ?? ''} ${erro.hint ?? ''}'
        .toLowerCase();
    return erro.code == '42501' ||
        texto.contains('row-level security') ||
        texto.contains('permission denied');
  }

  bool _erroDuplicadoCurtida(PostgrestException erro) {
    final texto = '${erro.message} ${erro.details ?? ''} ${erro.hint ?? ''}'
        .toLowerCase();
    return erro.code == '23505' ||
        texto.contains('duplicate key') ||
        texto.contains('unique constraint') ||
        texto.contains('conflict');
  }

  int _ajustarContagemLike(int atual, int delta) {
    final proximo = atual + delta;
    return proximo < 0 ? 0 : proximo;
  }

  Future<int> _buscarTotalCurtidasDaPostagem(int idPostagem) async {
    final supabase = Supabase.instance.client;
    final rows = await supabase
        .from('curtidas_postagem')
        .select('id_curtida_postagem')
        .eq('fk_postagem', idPostagem);
    return rows.length;
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

  Future<void> _curtirPostagem(PostagemResumo postagem) async {
    final idPostagem = postagem.idPostagem;
    if (_curtidasEmAndamento.contains(idPostagem)) return;

    if (_usuarioCurtiuPostagem(idPostagem)) {
      return;
    }

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
    if (idPerfil == null) {
      idPerfil = await _buscarPerfilDaPostagem(idPostagem);
    }

    if (idPerfil == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível curtir esta postagem agora.'),
        ),
      );
      return;
    }

    final curtiaAntes = _usuarioCurtiuPostagem(idPostagem);
    final totalAntes = _curtidasExibidas(postagem);

    setState(() => _curtidasEmAndamento.add(idPostagem));
    setState(() {
      _postagensCurtidasPorMim.add(idPostagem);
      _curtidasPorPostagem[idPostagem] = _ajustarContagemLike(totalAntes, 1);
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
    } catch (e) {
      final erroDuplicado = e is PostgrestException && _erroDuplicadoCurtida(e);
      if (!mounted) return;
      if (erroDuplicado) {
        final totalReal = await _buscarTotalCurtidasDaPostagem(idPostagem);
        if (!mounted) return;
        setState(() {
          _postagensCurtidasPorMim.add(idPostagem);
          _curtidasPorPostagem[idPostagem] = totalReal;
        });
      } else if (e is PostgrestException && _erroPermissaoRls(e)) {
        debugPrint(
          'Curtida bloqueada por permissão/RLS: code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}',
        );
        setState(() {
          if (!curtiaAntes) {
            _postagensCurtidasPorMim.remove(idPostagem);
          }
          _curtidasPorPostagem[idPostagem] = totalAntes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sem permissão para curtir (RLS). Ajuste as políticas do Supabase para INSERT em curtidas_postagem.',
            ),
          ),
        );
      } else if (e is PostgrestException && _erroRelacionadoAFkPostagem(e)) {
        setState(() {
          if (!curtiaAntes) {
            _postagensCurtidasPorMim.remove(idPostagem);
          }
          _curtidasPorPostagem[idPostagem] = totalAntes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A tabela curtidas_postagem precisa da coluna fk_postagem para registrar curtidas por postagem.',
            ),
          ),
        );
      } else {
        setState(() {
          if (!curtiaAntes) {
            _postagensCurtidasPorMim.remove(idPostagem);
          }
          _curtidasPorPostagem[idPostagem] = totalAntes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível registrar a curtida agora.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _curtidasEmAndamento.remove(idPostagem));
      }
    }
  }

  Future<void> _descurtirPostagem(PostagemResumo postagem) async {
    final idPostagem = postagem.idPostagem;
    if (_curtidasEmAndamento.contains(idPostagem)) return;

    if (!_usuarioCurtiuPostagem(idPostagem)) {
      return;
    }

    if (_idUsuarioLogado == null) {
      await _carregarUsuarioLogado();
    }

    final idUsuario = _idUsuarioLogado;
    if (idUsuario == null) return;

    final curtiaAntes = _usuarioCurtiuPostagem(idPostagem);
    final totalAntes = _curtidasExibidas(postagem);

    setState(() => _curtidasEmAndamento.add(idPostagem));
    setState(() {
      _postagensCurtidasPorMim.remove(idPostagem);
      _curtidasPorPostagem[idPostagem] = _ajustarContagemLike(totalAntes, -1);
    });

    try {
      final removeu = await _removerCurtidaNoSupabase(
        idUsuario: idUsuario,
        idPostagem: idPostagem,
      );

      if (!removeu) {
        throw const PostgrestException(
          code: '42501',
          message: 'Delete bloqueado por RLS ou filtro não encontrou linha.',
        );
      }

      final totalReal = await _buscarTotalCurtidasDaPostagem(idPostagem);
      if (!mounted) return;
      setState(() => _curtidasPorPostagem[idPostagem] = totalReal);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (curtiaAntes) {
          _postagensCurtidasPorMim.add(idPostagem);
        }
        _curtidasPorPostagem[idPostagem] = totalAntes;
      });
      if (e is PostgrestException && _erroPermissaoRls(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sem permissão para remover curtida (RLS). Ajuste as políticas DELETE no Supabase.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível remover a curtida agora.'),
          ),
        );
      }
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

  Future<void> _curtirComAnimacaoTelaCheia(PostagemResumo postagem) async {
    _dispararAnimacaoLikeTelaCheia(postagem.idPostagem);
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

            Future<void> curtirAtual() async {
              await _curtirPostagem(postagemAtual);
              if (!mounted) return;
              setModalState(() {});
            }

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
                            await _curtirComAnimacaoTelaCheia(postagem);
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
                      child: GestureDetector(
                        onDoubleTap: () async {
                          await curtirAtual();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                postagemAtual.titulo,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                                    _formatarDataHora(
                                      postagemAtual.dataPostagem,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    curtiu
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: curtiu
                                        ? _primaryBlue
                                        : Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () async {
                                      await _alternarCurtida(postagemAtual);
                                      if (!mounted) return;
                                      setModalState(() {});
                                    },
                                    child: Text(
                                      '$curtidas',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
          .select('funcao, cor')
          .inFilter('id_oficio', idsOficios);

      final oficios = <OficioInfo>[];
      for (final row in oficiosData) {
        final info = OficioInfo.fromMap(row);
        if (info.funcao.isNotEmpty) oficios.add(info);
      }

      if (mounted) setState(() => _oficios = oficios);
    } catch (_) {
      // Mantém ofícios anteriores em caso de falha
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
      // Mantém exceções anteriores em caso de falha
    } finally {
      if (mounted) {
        setState(() => _carregandoExcecoes = false);
      }
    }
  }

  void _mostrarPopupDiaBloqueado(DateTime data, String? observacao) {
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
    final dataFormatada = '${data.day} de ${meses[data.month - 1]}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.event_busy, color: _blockedRed, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dataFormatada,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O profissional não está disponível neste dia.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            if (observacao != null && observacao.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                observacao,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fechar',
              style: TextStyle(
                color: _primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final atBottom = offset >= maxScroll - 80;
    final scrollingDown = offset > _lastScrollOffset;

    bool novoShowFloating = _showFloatingButton;
    if (atBottom) {
      novoShowFloating = false;
    } else if (scrollingDown && offset > 200) {
      novoShowFloating = true;
    } else if (!scrollingDown) {
      novoShowFloating = false;
    }

    _lastScrollOffset = offset;

    int? novaAba;
    if (!_isScrollingProgrammatically) {
      final now = DateTime.now();
      if (now.difference(_ultimaAtualizacaoAba) >=
          const Duration(milliseconds: 150)) {
        _ultimaAtualizacaoAba = now;
        novaAba = _calcularAbaAtiva(offset);
      }
    }

    if (novoShowFloating != _showFloatingButton ||
        atBottom != _isAtBottom ||
        (novaAba != null && novaAba != _abaAtiva)) {
      setState(() {
        _showFloatingButton = novoShowFloating;
        _isAtBottom = atBottom;
        if (novaAba != null) _abaAtiva = novaAba;
      });
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
    final keys = [_disponibilidadeKey, _avaliacoesKey, _detalhesKey];
    var aba = 0;
    for (var i = 0; i < keys.length; i++) {
      final sectionOffset = _offsetDaSecao(keys[i]);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildCabecalho()),
              SliverToBoxAdapter(child: _buildBarraBusca()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _AbasDelegate(
                  abaAtiva: _abaAtiva,
                  onAbaTap: _scrollParaAba,
                ),
              ),
              SliverToBoxAdapter(
                key: _disponibilidadeKey,
                child: _buildSecaoDisponibilidade(),
              ),
              SliverToBoxAdapter(
                key: _avaliacoesKey,
                child: _buildSecaoAvaliacoes(),
              ),
              SliverToBoxAdapter(
                key: _detalhesKey,
                child: _buildSecaoDetalhes(),
              ),
              SliverToBoxAdapter(child: _buildCatalogoServicos()),
              SliverToBoxAdapter(
                key: _footerButtonKey,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: _buildBotaoSolicitarServico(),
                ),
              ),
            ],
          ),
          if (_showFloatingButton && !_isAtBottom)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildBotaoSolicitarServico(),
            ),
        ],
      ),
    );
  }

  Widget _buildCabecalho() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(height: 140, width: double.infinity, color: _bannerDark),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: _primaryBlue,
                          size: 24,
                        ),
                      ),
                      const Icon(
                        Icons.more_vert,
                        color: _primaryBlue,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(child: _buildFotoPerfil()),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: _primaryBlue,
                        shape: BoxShape.circle,
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
        const SizedBox(height: 58),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_carregandoPerfil)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primaryBlue,
                  ),
                )
              else
                Text(
                  _nome,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _carregandoSeguimento || _alterandoSeguimento
                    ? null
                    : _alternarSeguimento,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _seguindoProfissional
                                  ? Icons.person
                                  : Icons.person_add_alt_1,
                              color: _primaryBlue,
                              size: 20,
                            ),
                            if (_seguindoProfissional) ...[
                              const SizedBox(width: 4),
                              const Text(
                                'seguindo',
                                style: TextStyle(
                                  color: _primaryBlue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.work_outline, color: _primaryBlue, size: 16),
            const SizedBox(width: 4),
            Text(
              'Profissional independente',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildCardHorarioTrabalho(),
        if (_oficios.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _oficios
                  .map((oficio) => TagOficio(oficio: oficio))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _buildMetrica(
                icone: Icons.star,
                iconeCor: const Color(0xFFFFC107),
                valor: widget.avaliacao.toStringAsFixed(1),
                label: '${widget.totalAvaliacoes} avaliações',
              ),
              _buildMetrica(
                icone: Icons.verified,
                iconeCor: _primaryBlue,
                valor: 'Pro',
                label: 'Verificado',
              ),
              _buildMetrica(
                icone: Icons.work_history_outlined,
                iconeCor: Colors.black,
                valor: _formatarAnosExperiencia(_anosExperiencia),
                label: 'Anos exp.',
              ),
              _buildMetrica(
                icone: Icons.person_outline,
                iconeCor: _primaryBlue,
                valor: '$_totalSeguidores',
                label: 'Seguidores',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
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
        errorBuilder: (_, _, _) => _buildIniciaisPerfil(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _primaryBlue,
            ),
          );
        },
      );
    }
    return _buildIniciaisPerfil();
  }

  Widget _buildIniciaisPerfil() {
    final nomeExibicao = _nome.isNotEmpty ? _nome : 'Nome não encontrado';
    return Container(
      color: const Color(0xFFE1F5FE),
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

  Widget _buildCardHorarioTrabalho() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFDCEAF4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.access_time_rounded,
              color: _primaryBlue,
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$_textoDisponibilidade: $_faixaHorarioDisponibilidade',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _primaryBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrica({
    required IconData icone,
    required Color iconeCor,
    required String valor,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, color: iconeCor, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  valor,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBarraBusca() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const TextField(
          decoration: InputDecoration(
            hintText: 'Buscar serviços',
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
            prefixIcon: Icon(Icons.search, color: Colors.grey, size: 20),
            suffixIcon: Icon(Icons.tune, color: Colors.grey, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildSecaoDisponibilidade() {
    final diasSemana = [
      'DOMINGO',
      'SEGUNDA',
      'TERÇA',
      'QUARTA',
      'QUINTA',
      'SEXTA',
      'SÁBADO',
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
                child: const Icon(Icons.chevron_left, color: _primaryBlue),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  Text(
                    meses[_mesSelecionado.month - 1],
                    style: const TextStyle(
                      color: _primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: _primaryBlue,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_mesSelecionado.year}',
                    style: const TextStyle(
                      color: _primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: _primaryBlue,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(width: 8),
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
                child: const Icon(Icons.chevron_right, color: _primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryBlue.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Row(
                  children: diasSemana
                      .map(
                        (dia) => Expanded(
                          child: Text(
                            dia,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: _primaryBlue,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                if (_carregandoExcecoes)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 1.1,
                        ),
                    itemCount: totalCelulas,
                    itemBuilder: (context, index) {
                      final diaNumero = index - diaInicioSemana + 1;
                      final isMesAtual =
                          diaNumero >= 1 && diaNumero <= ultimoDia.day;

                      if (!isMesAtual) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        );
                      }

                      final dataDia = DateTime(
                        _mesSelecionado.year,
                        _mesSelecionado.month,
                        diaNumero,
                      );
                      final chaveData = _formatarDataCompleta(dataDia);
                      final isHoje =
                          dataDia.year == hoje.year &&
                          dataDia.month == hoje.month &&
                          dataDia.day == hoje.day;
                      final isBloqueado = _diasBloqueados.containsKey(
                        chaveData,
                      );
                      final observacao = _diasBloqueados[chaveData];

                      Color bgColor;
                      Color textColor;
                      Color borderColor;

                      if (isBloqueado) {
                        bgColor = _blockedBg;
                        textColor = _blockedRed;
                        borderColor = _blockedBorder;
                      } else if (isHoje) {
                        bgColor = _primaryBlue;
                        textColor = Colors.white;
                        borderColor = _primaryBlue;
                      } else {
                        bgColor = Colors.white;
                        textColor = Colors.grey.shade700;
                        borderColor = Colors.grey.shade300;
                      }

                      return GestureDetector(
                        onTap: isBloqueado
                            ? () =>
                                  _mostrarPopupDiaBloqueado(dataDia, observacao)
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: borderColor,
                              width: isBloqueado ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$diaNumero',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                              decoration: isBloqueado
                                  ? TextDecoration.underline
                                  : null,
                              decorationColor: _blockedRed,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoAvaliacoes() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '5.0',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Icon(Icons.star, color: _primaryBlue, size: 18),
              const SizedBox(width: 4),
              const Text(
                'Avaliações do Profissional',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(923)',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumo dos comentários',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut id dui eu lectus varius pretium ac vel erat. Cras sed sollicitudin sem.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFiltroComentario('Principais'),
              const SizedBox(width: 8),
              _buildFiltroComentario('Recentes'),
              const Spacer(),
              const Text(
                'Ver todas (932)',
                style: TextStyle(
                  color: _primaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildComentarioItem(
            nome: _avaliacoes[0]['nome'],
            iniciais: _avaliacoes[0]['iniciais'],
            nota: _avaliacoes[0]['nota'],
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
          _buildComentarioItem(
            nome: _avaliacoes[1]['nome'],
            iniciais: _avaliacoes[1]['iniciais'],
            nota: _avaliacoes[1]['nota'],
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
          _buildComentarioItem(
            nome: _avaliacoes[2]['nome'],
            iniciais: _avaliacoes[2]['iniciais'],
            nota: _avaliacoes[2]['nota'],
            tempo: _avaliacoes[2]['tempo'],
            texto: _avaliacoes[2]['texto'],
            liked: _likedComentario3,
            likes: _likesComentario3,
            onLikeTap: () {
              setState(() {
                _likedComentario3 = !_likedComentario3;
                _likesComentario3 += _likedComentario3 ? 1 : -1;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroComentario(String texto) {
    final isSelected = _filtroComentario == texto;
    return GestureDetector(
      onTap: () => setState(() => _filtroComentario = texto),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _primaryBlue : Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: isSelected ? _primaryBlue : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildComentarioItem({
    required String nome,
    required String iniciais,
    required double nota,
    required String tempo,
    required String texto,
    required bool liked,
    required int likes,
    required VoidCallback onLikeTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _primaryBlue.withValues(alpha: 0.15),
            child: Text(
              iniciais,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < nota.floor() ? Icons.star : Icons.star_border,
                        color: _primaryBlue,
                        size: 12,
                      );
                    }),
                    const SizedBox(width: 6),
                    Text(
                      tempo,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  texto,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onLikeTap,
            child: Column(
              children: [
                Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? _primaryBlue : Colors.grey.shade400,
                  size: 18,
                ),
                Text(
                  '$likes',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoDetalhes() {
    const limiteDescricao = 120;
    final descricaoCompleta = _descricaoPerfil;
    final descricaoCurta = descricaoCompleta.length > limiteDescricao
        ? '${descricaoCompleta.substring(0, limiteDescricao)}...'
        : descricaoCompleta;

    final tiposServico = [
      {'icone': Icons.build_outlined, 'label': 'Instalação'},
      {'icone': Icons.handyman_outlined, 'label': 'Reparação'},
      {'icone': Icons.cleaning_services_outlined, 'label': 'Higienização'},
      {'icone': Icons.propane_tank_outlined, 'label': 'Carga de Gás'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: _primaryBlue, size: 20),
              const SizedBox(width: 6),
              const Text(
                'Sobre o Profissional',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _descricaoExpandida ? descricaoCompleta : descricaoCurta,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () =>
                  setState(() => _descricaoExpandida = !_descricaoExpandida),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _descricaoExpandida ? 'Ver Menos' : 'Ver Mais',
                    style: const TextStyle(
                      color: _primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _descricaoExpandida
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: _primaryBlue,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text(
            'Tipos de serviços oferecidos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.8,
            ),
            itemCount: tiposServico.length,
            itemBuilder: (context, index) {
              final item = tiposServico[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      item['icone'] as IconData,
                      color: _primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['label'] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Postagens do profissional',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
                    vertical: 22,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    'Este profissional ainda não publicou serviços.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                );
              }

              return SizedBox(
                height: 188,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: postagens.length,
                  itemBuilder: (context, index) {
                    final postagem = postagens[index];
                    final curtidas = _curtidasExibidas(postagem);
                    final curtiu = _usuarioCurtiuPostagem(postagem.idPostagem);
                    return Container(
                      width: 220,
                      margin: EdgeInsets.only(
                        right: index < postagens.length - 1 ? 10 : 0,
                      ),
                      child: _buildCardGaleriaPostagem(
                        postagem,
                        curtidas: curtidas,
                        curtiu: curtiu,
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: postagem.imagemUrl != null
                        ? Image.network(
                            postagem.imagemUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_outlined,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.image_outlined,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  _buildAnimacaoCoracao(
                    _animandoLikeNoCard.contains(postagem.idPostagem),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          PostagensProfissionalService.formatarDataPostagem(
                            postagem.dataPostagem,
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.schedule, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        _formatarHora(postagem.dataPostagem),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onLikeTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Icon(
                          curtiu ? Icons.favorite : Icons.favorite_border,
                          size: 13,
                          color: curtiu ? _primaryBlue : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$curtidas curtidas',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogoServicos() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Serviços Oferecidos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
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
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? _primaryBlue : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      categoria,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? _primaryBlue : Colors.grey.shade600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: _servicos.length,
            itemBuilder: (context, index) =>
                _buildCardServico(_servicos[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildCardServico(Map<String, dynamic> servico) {
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
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.asset(
                    servico['imagem'],
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      servico['tag'],
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Text(
              servico['titulo'],
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  '${servico['avaliacao']}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: _primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Colors.white, size: 9),
                ),
                const SizedBox(width: 2),
                Text(
                  '(${servico['totalAvaliacoes']})',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Preço Médio',
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                ),
                Text(
                  'R\$ ${servico['preco'].toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _priceOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoSolicitarServico() {
    return Material(
      elevation: _showFloatingButton ? 6 : 0,
      borderRadius: BorderRadius.circular(12),
      color: _primaryBlue,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/icone_caixa_branco.png',
                width: 22,
                height: 22,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'SOLICITAR SERVIÇO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

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
                        Text(
                          _abas[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? const Color(0xFF0FB3FF)
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 2,
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: isActive
                              ? const Color(0xFF0FB3FF)
                              : Colors.transparent,
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
