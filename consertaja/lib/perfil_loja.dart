import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/servico_profissional.dart';
import 'models/postagem_resumo.dart';
import 'perfil_profissional.dart';
import 'services/servicos_profissional_service.dart';
import 'tela_chat_profissional.dart';
import 'tela_servico.dart';
import 'utils/cor_oficio.dart';
import 'utils/icone_oficio.dart';
import 'utils/iniciais.dart';

// Cores temáticas fiéis ao design
const Color _kPrimaryCyan = Color(0xFF0FB3FF);
const Color _kDarkBlueStart = Color(0xFF002244);
const Color _kDarkBlueEnd = Color(0xFF026DB5);
const Color _kDarkSlate = Color(0xFF0F172A);
const Color _kTextMuted = Color(0xFF64748B);
const Color _kBorderColor = Color(0xFFE2E8F0);
const Color _kStarGold = Color(0xFFF59E0B);
const Color _kCtaNavy = Color(0xFF222938);

/// Ponto verde com animação pulsante para indicar status ativo/online e localização
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
                color: const Color(0xFF10B981)
                    .withValues(alpha: _animation.value * 0.35),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981)
                    .withValues(alpha: 0.35 + (_animation.value * 0.65)),
                shape: BoxShape.circle,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dados do endereço da empresa (ass_grupo_empresa_endereco -> enderecos).
class _DadosEnderecoEmpresa {
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

  const _DadosEnderecoEmpresa({
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

class PerfilLoja extends StatefulWidget {
  final int? idGrupoEmpresa;
  final String? nomeEmpresa;
  final String? fotoUrlEmpresa;
  final String? bannerUrlEmpresa;
  final String? tagEmpresa;
  final String? corTagEmpresa;
  final bool? compartilharFuncionarios;

  const PerfilLoja({
    super.key,
    this.idGrupoEmpresa,
    this.nomeEmpresa,
    this.fotoUrlEmpresa,
    this.bannerUrlEmpresa,
    this.tagEmpresa,
    this.corTagEmpresa,
    this.compartilharFuncionarios,
  });

  @override
  State<PerfilLoja> createState() => _PerfilLojaState();
}

class _PerfilLojaState extends State<PerfilLoja> {
  final ScrollController _scrollController = ScrollController();

  // Chaves para rolagem suave entre abas
  final GlobalKey _equipeKey = GlobalKey();
  final GlobalKey _servicosKey = GlobalKey();
  final GlobalKey _sobreKey = GlobalKey();
  final GlobalKey _avaliacoesKey = GlobalKey();

  int? _idGrupoEmpresa;
  int? _idProfissionalDono;
  int? _idUsuarioLogado;
  String _nomeEmpresa = 'Caedss & Equipe ConsertaJá';
  String? _fotoUrlEmpresa;
  String? _bannerUrlEmpresa;
  String? _tagEmpresa = '#CAEDS';
  Color? _corTagEmpresa = const Color(0xFF0288D1);

  bool _compartilharFuncionarios = false;
  bool _carregandoProfissionais = true;
  List<Map<String, dynamic>> listaProfissionais = [];
  bool _carregandoServicos = true;
  List<ServicoProfissional> _servicosLoja = [];
  List<OficioInfo> _oficiosEmpresa = [];

  String _abaAtiva = 'Serviços';
  String _filtroServicos = '';
  String _categoriaServicoSelecionada = 'Todos';

  String filtroComentario = 'Principais';
  bool isDescricaoExpandida = false;

  // Estado de seguir dinâmico com Supabase (padrão 0)
  bool _seguindo = false;
  int _totalSeguidores = 0;
  bool _alterandoSeguimento = false;

  // Estados para controle dinâmico de curtidas nos comentários
  int likesComentario1 = 0;
  bool likedComentario1 = false;

  int likesComentario2 = 1;
  bool likedComentario2 = true;

  // --- Estado vindo do Supabase (grupo_empresa) ---
  String _descricaoEmpresa = '';
  String _anosMercado = '1';
  _DadosEnderecoEmpresa? _enderecoEmpresa;
  bool _enderecoCarregado = false;

  // --- Galeria = postagens da empresa (postagens.fk_grupo_empresa) ---
  Future<List<PostagemResumo>> _postagensGaleriaFuture =
      Future.value(<PostagemResumo>[]);

  // Controller do mapa: initialCenter só vale na 1ª construção (quando o
  // endereço ainda é null). Quando o endereço real chega, damos move()
  // para centralizar no pinpoint. Sem isso o mapa fica no default.
  final MapController _mapController = MapController();
  bool _mapaCentralizado = false;

  @override
  void initState() {
    super.initState();
    _idGrupoEmpresa = widget.idGrupoEmpresa;
    if (widget.compartilharFuncionarios != null) {
      _compartilharFuncionarios = widget.compartilharFuncionarios!;
    }
    _abaAtiva = _compartilharFuncionarios ? 'Equipe' : 'Serviços';
    if (widget.nomeEmpresa != null && widget.nomeEmpresa!.trim().isNotEmpty) {
      _nomeEmpresa = widget.nomeEmpresa!.trim();
    }
    _fotoUrlEmpresa = widget.fotoUrlEmpresa;
    _bannerUrlEmpresa = widget.bannerUrlEmpresa;
    if (widget.tagEmpresa != null && widget.tagEmpresa!.trim().isNotEmpty) {
      final t = widget.tagEmpresa!.trim();
      _tagEmpresa = t.startsWith('#') ? t : '#$t';
    }
    if (widget.corTagEmpresa != null &&
        widget.corTagEmpresa!.trim().isNotEmpty) {
      _corTagEmpresa = CorOficio.parse(widget.corTagEmpresa);
    }
    _carregarUsuarioLogado();
    _carregarDadosEmpresaEProfissionais();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    } catch (_) {}
  }

  Future<void> _carregarDadosEmpresaEProfissionais() async {
    try {
      final supabase = Supabase.instance.client;
      int? idGrupo = _idGrupoEmpresa;
      int? fkPerfil;

      // Se idGrupo não foi passado diretamente, tenta resolver via banco
      if (idGrupo == null) {
        Map<String, dynamic>? grupoEncontrado;
        if (_tagEmpresa != null && _tagEmpresa!.isNotEmpty) {
          final cleanTag = _tagEmpresa!.replaceAll('#', '').trim();
          final res = await supabase
              .from('grupo_empresa')
              .select(
                'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa, fk_perfil, seguidores_empresa, compartilhar_funcionarios, descricao_empresa, anos_mercado',
              )
              .ilike('tag_empresa', '%$cleanTag%')
              .maybeSingle();
          grupoEncontrado = res;
        }
        if (grupoEncontrado == null && _nomeEmpresa.isNotEmpty) {
          final res = await supabase
              .from('grupo_empresa')
              .select(
                'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa, fk_perfil, seguidores_empresa, compartilhar_funcionarios, descricao_empresa, anos_mercado',
              )
              .ilike('nome_empresa', '%$_nomeEmpresa%')
              .maybeSingle();
          grupoEncontrado = res;
        }
        if (grupoEncontrado == null) {
          final list = await supabase
              .from('grupo_empresa')
              .select(
                'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa, fk_perfil, seguidores_empresa, compartilhar_funcionarios, descricao_empresa, anos_mercado',
              )
              .limit(1);
          if (list.isNotEmpty) {
            grupoEncontrado = list.first;
          }
        }
        if (grupoEncontrado != null) {
          idGrupo = (grupoEncontrado['id_grupo_empresa'] as num?)?.toInt();
          _idGrupoEmpresa = idGrupo;
        }
      }

      if (idGrupo != null) {
        final grupo = await supabase
            .from('grupo_empresa')
            .select(
              'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa, fk_perfil, seguidores_empresa, compartilhar_funcionarios, descricao_empresa, anos_mercado',
            )
            .eq('id_grupo_empresa', idGrupo)
            .maybeSingle();

        if (grupo != null && mounted) {
          fkPerfil = (grupo['fk_perfil'] as num?)?.toInt();
          final nome = grupo['nome_empresa']?.toString().trim();
          final tag = grupo['tag_empresa']?.toString().trim();
          final corHex = grupo['cor_tag_empresa']?.toString();
          final foto = grupo['foto_url_empresa']?.toString();
          final banner = grupo['banner_url_empresa']?.toString();
          final seguidores = (grupo['seguidores_empresa'] as num?)?.toInt() ?? 0;
          final comp = grupo['compartilhar_funcionarios'];
          final bool compBool = comp == true;
          final descricaoDb = grupo['descricao_empresa']?.toString().trim() ?? '';
          final anosDb = grupo['anos_mercado']?.toString().trim() ?? '';

          setState(() {
            if (nome != null && nome.isNotEmpty) _nomeEmpresa = nome;
            if (descricaoDb.isNotEmpty) _descricaoEmpresa = descricaoDb;
            if (anosDb.isNotEmpty) _anosMercado = anosDb;
            if (tag != null && tag.isNotEmpty) {
              _tagEmpresa = tag.startsWith('#') ? tag : '#$tag';
            }
            if (corHex != null && corHex.isNotEmpty) {
              _corTagEmpresa = CorOficio.parse(corHex);
            }
            if (foto != null && foto.isNotEmpty) _fotoUrlEmpresa = foto;
            if (banner != null && banner.isNotEmpty) {
              _bannerUrlEmpresa = banner;
            }
            _totalSeguidores = seguidores >= 0 ? seguidores : 0;
            _compartilharFuncionarios = compBool;
            if (!compBool && _abaAtiva == 'Equipe') {
              _abaAtiva = 'Serviços';
            } else if (compBool && _abaAtiva == 'Serviços' && widget.compartilharFuncionarios == null) {
              _abaAtiva = 'Equipe';
            }
          });
        }
      }

      // Carrega seguidores no Supabase
      if (idGrupo != null) {
        _carregarSeguimento(idGrupo);
        _carregarAgendaEmpresa(idGrupo);
        _carregarEnderecoEmpresa(idGrupo);
        _carregarPostagensEmpresa(idGrupo);
      }

      // Carrega serviços SÓ da empresa (igual meus_servicos_profissional.dart
      // no modo empresa): buscarServicosEmpresa + trava fk_grupo_empresa.
      List<ServicoProfissional> servicos = [];
      if (idGrupo != null) {
        try {
          var lista =
              await ServicosProfissionalService.buscarServicosEmpresa(idGrupo);
          final idGrupoFinal = idGrupo;
          lista = lista
              .where((s) =>
                  s.fkGrupoEmpresa != null &&
                  s.fkGrupoEmpresa == idGrupoFinal)
              .toList();
          servicos = lista;
        } catch (e) {
          debugPrint('Erro ao carregar serviços da empresa: $e');
        }
      }

      // Carrega ofícios oferecidos pela empresa dinamicamente
      List<OficioInfo> oficiosCarregados = [];
      if (idGrupo != null) {
        try {
          final assOficios = await supabase
              .from('ass_oficio_grupo_empresa')
              .select('fk_oficio')
              .eq('fk_grupo_empresa', idGrupo);

          final idsOficios = assOficios
              .map((e) => e['fk_oficio'])
              .whereType<num>()
              .map((e) => e.toInt())
              .toList();

          if (idsOficios.isNotEmpty) {
            final oficiosData = await supabase
                .from('oficios')
                .select('id_oficio, funcao, categoria, cor')
                .inFilter('id_oficio', idsOficios);

            for (final row in oficiosData) {
              final info = OficioInfo.fromMap(row);
              if (info.funcao.isNotEmpty) {
                oficiosCarregados.add(info);
              }
            }
          }
        } catch (e) {
          debugPrint('Erro ao carregar ofícios da empresa: $e');
        }
      }

      // Se não encontrou na tabela associativa, extrai dos serviços da loja
      if (oficiosCarregados.isEmpty && servicos.isNotEmpty) {
        final nomesVistos = <String>{};
        for (final s in servicos) {
          final f = s.funcao?.trim();
          if (f != null && f.isNotEmpty && !nomesVistos.contains(f)) {
            nomesVistos.add(f);
            oficiosCarregados.add(OficioInfo(
              funcao: f,
              categoria: 'Geral',
              cor: '#0FB3FF',
            ));
          }
        }
      }

      // Se ainda vazio, não inventa ofícios: mostra estado vazio real.
      if (oficiosCarregados.isEmpty) {
        oficiosCarregados = const [];
      }

      if (mounted) {
        setState(() {
          _servicosLoja = servicos;
          _oficiosEmpresa = oficiosCarregados;
          _carregandoServicos = false;
        });
      }

      // Carrega lista de profissionais da empresa (Proprietário: Responsável | Outros: Funcionário)
      final List<Map<String, dynamic>> novosProfissionais = [];
      final Set<int> idsProfissionaisAdicionados = {};

      // 1. Carrega Proprietário (fk_perfil vinculado ao grupo_empresa -> Responsável)
      if (fkPerfil != null) {
        try {
          final dadosDono = await supabase
              .from('dados_profissionais')
              .select('id_profissional, fk_usuario, fk_perfil')
              .eq('fk_perfil', fkPerfil)
              .maybeSingle();

          if (dadosDono != null) {
            final idProfDono = (dadosDono['id_profissional'] as num?)?.toInt();
            final fkUsuario = dadosDono['fk_usuario'];
            _idProfissionalDono = idProfDono;

            if (fkUsuario != null && idProfDono != null) {
              idsProfissionaisAdicionados.add(idProfDono);

              final usuarioDono = await supabase
                  .from('usuarios')
                  .select('nome, foto_perfil_url')
                  .eq('id_usuario', fkUsuario)
                  .maybeSingle();

              final nomeDono =
                  usuarioDono?['nome']?.toString().trim() ?? 'Responsável da Loja';
              final fotoDono =
                  usuarioDono?['foto_perfil_url']?.toString().trim() ?? '';

              novosProfissionais.add({
                'idProfissional': idProfDono,
                'nome': nomeDono,
                'avaliacao': 4.9,
                'totalAvaliacoes': 423,
                'cargo': 'Responsável',
                'caminhoImagem': fotoDono,
                'isResponsavel': true,
              });
            }
          }
        } catch (e) {
          debugPrint('Erro ao carregar proprietário da empresa: $e');
        }
      }

      // 2. Carrega Membros da equipe (tipo_perfil Loja/Dono -> Responsável, restante -> Funcionário)
      if (idGrupo != null) {
        try {
          final membros = await supabase
              .from('dados_profissionais')
              .select(
                'id_profissional, fk_usuario, fk_perfil, usuarios(nome, foto_perfil_url)',
              )
              .eq('fk_grupo_empresa', idGrupo);

          for (final m in membros) {
            final idProf = (m['id_profissional'] as num?)?.toInt();
            if (idProf == null || idsProfissionaisAdicionados.contains(idProf)) {
              continue;
            }
            idsProfissionaisAdicionados.add(idProf);

            final u = m['usuarios'] as Map<String, dynamic>?;
            final nome =
                u?['nome']?.toString().trim() ?? 'Profissional da Equipe';
            final foto = u?['foto_perfil_url']?.toString().trim() ?? '';

            final bool ehResponsavel = (idProf == _idProfissionalDono) ||
                (fkPerfil != null && m['fk_perfil'] == fkPerfil);

            novosProfissionais.add({
              'idProfissional': idProf,
              'nome': nome,
              'avaliacao': 4.8,
              'totalAvaliacoes': 198,
              'cargo': ehResponsavel ? 'Responsável' : 'Funcionário',
              'caminhoImagem': foto,
              'isResponsavel': ehResponsavel,
            });
          }
        } catch (e) {
          debugPrint('Erro ao carregar membros da empresa: $e');
        }
      }

      if (mounted) {
        setState(() {
          listaProfissionais = novosProfissionais;
          _carregandoProfissionais = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados da empresa e profissionais: $e');
      if (mounted) {
        setState(() {
          _carregandoProfissionais = false;
          _carregandoServicos = false;
        });
      }
    }
  }

  // --- Disponibilidade da empresa (agenda_profissional via fk_grupo_empresa) ---
  static const List<String> _ordemDiasSemana = [
    'domingo',
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
  ];
  bool _temAgendaCadastrada = false;
  String _faixaHorarioDisponibilidade = '--:-- - --:--';
  final Map<String, String?> _horariosPorDia = {};

  bool _estaAbertoAgora() {
    if (!_temAgendaCadastrada) return false;
    final agora = DateTime.now();
    final horarioHoje = _horariosPorDia[_nomeDiaSemana(agora.weekday)];
    if (horarioHoje == null || horarioHoje.isEmpty || horarioHoje == 'Fechado') {
      return false;
    }
    final partes = horarioHoje.split(' - ');
    if (partes.length != 2) return false;
    final inicio = _parseHorario(partes[0].trim());
    final fim = _parseHorario(partes[1].trim());
    if (inicio == null || fim == null) return false;
    final agoraMin = agora.hour * 60 + agora.minute;
    return agoraMin >= (inicio.$1 * 60 + inicio.$2) &&
        agoraMin < (fim.$1 * 60 + fim.$2);
  }

  (int, int)? _parseHorario(String texto) {
    final partes = texto.split(':');
    if (partes.length != 2) return null;
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null) return null;
    return (h, m);
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

  String _nomeDiaExibicao(String dia) {
    switch (dia) {
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
      case 'domingo':
        return 'Domingo';
      default:
        return dia;
    }
  }

  bool _diaPertence(String diaAlvo, String diasConfigurados) {
    final diasSplit = diasConfigurados.split(',').map((d) => d.trim());
    for (final d in diasSplit) {
      if (d == diaAlvo) return true;
      switch (diaAlvo) {
        case 'segunda-feira':
          if (d == 'segunda' || d == 'seg') return true;
          break;
        case 'terça-feira':
          if (d == 'terca' || d == 'terça' || d == 'ter') return true;
          break;
        case 'quarta-feira':
          if (d == 'quarta' || d == 'qua') return true;
          break;
        case 'quinta-feira':
          if (d == 'quinta' || d == 'qui') return true;
          break;
        case 'sexta-feira':
          if (d == 'sexta' || d == 'sex') return true;
          break;
        case 'sábado':
          if (d == 'sabado' || d == 'sábado' || d == 'sab') return true;
          break;
        case 'domingo':
          if (d == 'domingo' || d == 'dom') return true;
          break;
      }
    }
    return false;
  }

  String _textoStatusDisponibilidade() {
    final diasAbertos = _ordemDiasSemana
        .where((d) {
          final h = _horariosPorDia[d];
          return h != null && h.isNotEmpty && h != 'Fechado';
        })
        .map((d) {
          const mapa = {
            'segunda-feira': 'Seg',
            'terça-feira': 'Ter',
            'quarta-feira': 'Qua',
            'quinta-feira': 'Qui',
            'sexta-feira': 'Sex',
          };
          return mapa[d] ?? d;
        })
        .toList();
    final diasTexto = diasAbertos.isEmpty ? '' : ' (${diasAbertos.join(' a ')})';
    final aberto = _estaAbertoAgora();
    return '${aberto ? 'Aberto agora' : 'Fechado agora'} • $_faixaHorarioDisponibilidade$diasTexto';
  }

  Future<void> _carregarAgendaEmpresa(int idGrupo) async {
    try {
      final supabase = Supabase.instance.client;
      final linhas = await supabase
          .from('agenda_profissional')
          .select('dias_semana, hora_ini, hora_fim')
          .eq('fk_grupo_empresa', idGrupo);
      if (!mounted) return;
      setState(() {
        _horariosPorDia.clear();
        for (final dia in _ordemDiasSemana) {
          _horariosPorDia[dia] = 'Fechado';
        }
        _temAgendaCadastrada = linhas.isNotEmpty;
        _faixaHorarioDisponibilidade = '--:-- - --:--';
        String? faixa;
        for (final row in linhas) {
          final diasRaw = row['dias_semana']?.toString() ?? '';
          final iniRaw = row['hora_ini']?.toString() ?? '';
          final fimRaw = row['hora_fim']?.toString() ?? '';
          final horaIni = iniRaw.length >= 5 ? iniRaw.substring(0, 5) : iniRaw;
          final horaFim = fimRaw.length >= 5 ? fimRaw.substring(0, 5) : fimRaw;
          if (horaIni.isEmpty || horaFim.isEmpty) continue;
          faixa ??= '$horaIni - $horaFim';
          final intervalo = '$horaIni - $horaFim';
          for (final dia in _ordemDiasSemana) {
            if (_diaPertence(dia, diasRaw)) _horariosPorDia[dia] = intervalo;
          }
        }
        if (faixa != null) _faixaHorarioDisponibilidade = faixa;
      });
    } catch (e) {
      debugPrint('Erro agenda empresa: $e');
    }
  }

  Future<void> _carregarEnderecoEmpresa(int idGrupo) async {
    try {
      final supabase = Supabase.instance.client;
      // Igual ao meus_enderecos.dart (conta empresa): lê direto da
      // ass_grupo_empresa_endereco por fk_grupo_empresa, sem exigir RLS
      // de membro (perfil_loja é público — o visitante é cliente).
      // Se a tabela nova ainda não existir/migration não rodada, cai no
      // vínculo legado do dono em ass_usuario_endereco (Loja/Oficina/Outro).
      List vinculos = [];
      try {
        vinculos = await supabase
            .from('ass_grupo_empresa_endereco')
            .select('fk_endereco, apelido_endereco, endereco_ativo')
            .eq('fk_grupo_empresa', idGrupo);
      } catch (_) {
        vinculos = [];
      }
      if (vinculos.isEmpty) {
        try {
          final donoProf = await supabase
              .from('dados_profissionais')
              .select('fk_usuario')
              .eq('fk_grupo_empresa', idGrupo)
              .limit(10);
          final idsUsuarios = donoProf
              .map((r) => (r as Map)['fk_usuario'])
              .whereType<num>()
              .map((n) => n.toInt())
              .toSet()
              .toList();
          if (idsUsuarios.isNotEmpty) {
            vinculos = await supabase
                .from('ass_usuario_endereco')
                .select('fk_endereco, apelido_endereco, endereco_ativo')
                .inFilter('fk_usuario', idsUsuarios)
                .inFilter('tipo_endereco', ['Loja', 'Oficina', 'Outro'])
                .limit(5);
          }
        } catch (_) {}
      }
      if (vinculos.isEmpty) {
        if (mounted) setState(() => _enderecoCarregado = true);
        return;
      }
      Map<String, dynamic>? vinculoAtivo;
      for (final v in vinculos) {
        if ((v as Map)['endereco_ativo'] == true) {
          vinculoAtivo = Map<String, dynamic>.from(v);
          break;
        }
      }
      vinculoAtivo ??= Map<String, dynamic>.from(vinculos.first as Map);
      final fk = vinculoAtivo['fk_endereco'];
      final idEnd = fk is int ? fk : int.tryParse('$fk');
      if (idEnd == null) {
        if (mounted) setState(() => _enderecoCarregado = true);
        return;
      }
      final endList = await supabase
          .from('enderecos')
          .select('cep, logradouro, numero, bairro, fk_cidade, latitude, longitude')
          .eq('id_endereco', idEnd)
          .limit(1);
      if (endList.isEmpty) {
        if (mounted) setState(() => _enderecoCarregado = true);
        return;
      }
      final row = Map<String, dynamic>.from(endList.first as Map);
      String cidade = '';
      String uf = '';
      final fkCid = row['fk_cidade'];
      final idCid = fkCid is int ? fkCid : int.tryParse('$fkCid');
      if (idCid != null) {
        final cid = await supabase
            .from('cidades')
            .select('nome_cidade, fk_estado')
            .eq('id_cidade', idCid)
            .limit(1);
        if (cid.isNotEmpty) {
          cidade = cid.first['nome_cidade']?.toString() ?? '';
          final fkEst = cid.first['fk_estado'];
          final idEst = fkEst is int ? fkEst : int.tryParse('$fkEst');
          if (idEst != null) {
            final est = await supabase
                .from('estados')
                .select('sigla_estado')
                .eq('id_estado', idEst)
                .limit(1);
            if (est.isNotEmpty) uf = est.first['sigla_estado']?.toString() ?? '';
          }
        }
      }
      final apelido = vinculoAtivo['apelido_endereco']?.toString();
      final lat = double.tryParse(row['latitude']?.toString() ?? '');
      final lng = double.tryParse(row['longitude']?.toString() ?? '');
      if (!mounted) return;
      setState(() {
        _enderecoEmpresa = _DadosEnderecoEmpresa(
          apelido: (apelido != null && apelido.trim().isNotEmpty)
              ? apelido.trim()
              : 'Endereço da empresa',
          logradouro: row['logradouro']?.toString() ?? '',
          numero: row['numero']?.toString() ?? '',
          bairro: row['bairro']?.toString() ?? '',
          cidade: cidade,
          estado: uf,
          cep: row['cep']?.toString() ?? '',
          latitude: lat ?? -23.5505,
          longitude: lng ?? -46.6333,
          temCoordenadas: lat != null && lng != null,
        );
        _enderecoCarregado = true;
      });
      // Centraliza o mapa no pinpoint real (só com coordenada do banco).
      if (lat != null && lng != null && !_mapaCentralizado) {
        _mapaCentralizado = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _mapController.move(LatLng(lat, lng), 15.0);
          } catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('Erro endereco empresa: $e');
      if (mounted) setState(() => _enderecoCarregado = true);
    }
  }

  Future<void> _carregarPostagensEmpresa(int idGrupo) async {
    try {
      final supabase = Supabase.instance.client;
      List rows = [];
      try {
        rows = await supabase
            .from('postagens')
            .select('id_postagem, conteudo, data_postagem, arquivado')
            .eq('fk_grupo_empresa', idGrupo)
            .eq('tipo_autor', 'empresa')
            .eq('arquivado', false)
            .order('data_postagem', ascending: false);
      } catch (_) {
        rows = [];
      }
      final lista = <PostagemResumo>[];
      for (final r in rows) {
        final row = Map<String, dynamic>.from(r as Map);
        final id = (row['id_postagem'] as num?)?.toInt();
        if (id == null) continue;
        String? imagemUrl;
        try {
          final imgs = await supabase
              .from('imagens_postagens')
              .select('url_imagem')
              .eq('fk_postagem', id)
              .order('ordem', ascending: true)
              .limit(1);
          if (imgs.isNotEmpty) imagemUrl = imgs.first['url_imagem']?.toString();
        } catch (_) {}
        final conteudo = row['conteudo']?.toString().trim() ?? '';
        String? doTexto;
        final linhas = conteudo
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        for (final linha in linhas) {
          if (linha.startsWith('http://') || linha.startsWith('https://')) {
            imagemUrl ??= linha;
          } else {
            doTexto ??= linha;
          }
        }
        final dataRaw = row['data_postagem']?.toString();
        lista.add(PostagemResumo(
          idPostagem: id,
          titulo: (doTexto != null && doTexto.isNotEmpty)
              ? doTexto
              : (imagemUrl != null ? 'Postagem' : 'Sem título'),
          imagemUrl: imagemUrl,
          dataPostagem: dataRaw != null
              ? DateTime.tryParse(dataRaw) ?? DateTime.now()
              : DateTime.now(),
          curtidas: 0,
          arquivado: row['arquivado'] == true,
        ));
      }
      if (!mounted) return;
      setState(() {
        _postagensGaleriaFuture = Future.value(lista);
      });
    } catch (e) {
      debugPrint('Erro postagens empresa: $e');
    }
  }

  void _mostrarDisponibilidadeSemanal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Horários de funcionamento',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kDarkSlate),
              ),
              const SizedBox(height: 6),
              Text(
                _temAgendaCadastrada
                    ? 'Confira os dias e horários da empresa'
                    : 'A empresa ainda não cadastrou horários',
                style: const TextStyle(fontSize: 13, color: _kTextMuted),
              ),
              const SizedBox(height: 16),
              ...List.generate(_ordemDiasSemana.length, (index) {
                final diaChave = _ordemDiasSemana[index];
                final raw = _horariosPorDia[diaChave];
                final aberto = raw != null && raw != 'Fechado';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _nomeDiaExibicao(diaChave),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kDarkSlate),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: aberto ? const Color(0xFFDEF7EC) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: aberto ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          raw ?? 'Fechado',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: aberto ? const Color(0xFF046C4E) : _kTextMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _carregarSeguimento(int idGrupo) async {
    try {
      final supabase = Supabase.instance.client;

      if (_idUsuarioLogado == null) {
        await _carregarUsuarioLogado();
      }

      // Verifica se usuário atual segue esta empresa na tabela seguidores_empresa
      if (_idUsuarioLogado != null) {
        try {
          final vinculo = await supabase
              .from('seguidores_empresa')
              .select('id_seguidor_empresa')
              .eq('fk_grupo_empresa', idGrupo)
              .eq('fk_usuario', _idUsuarioLogado!)
              .maybeSingle();

          if (mounted) {
            setState(() => _seguindo = vinculo != null);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _alternarSeguimento() async {
    final idGrupo = _idGrupoEmpresa;
    if (_alterandoSeguimento) return;

    if (_idUsuarioLogado == null) {
      await _carregarUsuarioLogado();
    }

    final idUsuario = _idUsuarioLogado;
    final seguindoAntes = _seguindo;
    final totalAntes = _totalSeguidores;

    // Atualização otimista imediata na UI
    setState(() {
      _alterandoSeguimento = true;
      _seguindo = !seguindoAntes;
      _totalSeguidores = totalAntes + (seguindoAntes ? -1 : 1);
      if (_totalSeguidores < 0) _totalSeguidores = 0;
    });

    if (idGrupo == null) {
      setState(() => _alterandoSeguimento = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      if (idUsuario != null) {
        if (seguindoAntes) {
          try {
            await supabase
                .from('seguidores_empresa')
                .delete()
                .eq('fk_grupo_empresa', idGrupo)
                .eq('fk_usuario', idUsuario);
          } catch (_) {}
        } else {
          try {
            await supabase.from('seguidores_empresa').insert({
              'fk_grupo_empresa': idGrupo,
              'fk_usuario': idUsuario,
              'seguido_em': DateTime.now().toUtc().toIso8601String(),
            });
          } catch (_) {}
        }
      }

      // Atualiza também a coluna seguidores_empresa na tabela grupo_empresa
      await supabase
          .from('grupo_empresa')
          .update({'seguidores_empresa': _totalSeguidores})
          .eq('id_grupo_empresa', idGrupo);
    } catch (e) {
      debugPrint('Erro ao atualizar seguidores no Supabase: $e');
    } finally {
      if (mounted) {
        setState(() => _alterandoSeguimento = false);
      }
    }
  }

  void _scrollParaAba(String aba, GlobalKey key) {
    setState(() => _abaAtiva = aba);
    final targetContext = key.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.08,
      );
    }
  }

  void _abrirConversa() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaChatProfissional(
          nomeProfissional: _nomeEmpresa,
          fotoProfissional: _fotoUrlEmpresa ?? 'assets/images/loja_caedss.png',
          oficioPrincipal: 'Loja e Oficina Especializada',
          idProfissional: _idProfissionalDono,
          // Chat da EMPRESA: usa fk_grupo_empresa (chat próprio da loja).
          idGrupoEmpresa: _idGrupoEmpresa,
        ),
      ),
    );
  }

  Future<void> _abrirSolicitacaoServico() async {
    // Fluxo antigo (SolicitarServicoPage) removido: a solicitação nasce só no
    // botão Continuar da lista_servicos.dart. Aqui não faz nada.
    return;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // 1. Cabeçalho, Informações, Métricas e Busca
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildCabecalhoSuperiorComLogo(),
                  const SizedBox(height: 52),
                  _buildInformacoesLoja(),
                  const SizedBox(height: 16),
                  _buildMetricasLoja(),
                  const SizedBox(height: 18),
                  _buildBarraPesquisa(),
                  const SizedBox(height: 6),
                ],
              ),
            ),

            // 2. Abas Sticky Pinned (grudam no topo ao rolar a tela, igual perfil_profissional.dart)
            SliverPersistentHeader(
              pinned: true,
              delegate: _AbasLojaDelegate(
                abaAtiva: _abaAtiva,
                onAbaTap: (aba, key) => _scrollParaAba(aba, key),
                equipeKey: _equipeKey,
                servicosKey: _servicosKey,
                sobreKey: _sobreKey,
                avaliacoesKey: _avaliacoesKey,
                mostrarEquipe: _compartilharFuncionarios,
              ),
            ),

            // 3. Seção: Equipe de Especialistas (exibida apenas se compartilhar_funcionarios == true)
            if (_compartilharFuncionarios)
              SliverToBoxAdapter(
                key: _equipeKey,
                child: _buildSecaoEquipe(),
              ),

            // 4. Seção: Localização e Atendimento
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: _buildSecaoLocalizacao(),
              ),
            ),

            // 5. Seção: Serviços Oferecidos (Catálogo em Grid 2x2 com preço em _kDarkBlueEnd)
            SliverToBoxAdapter(
              key: _servicosKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: _buildSecaoServicosOferecidos(),
              ),
            ),

            // 6. Seção: Sobre a Loja / Empresa (com Tipos de serviços dinâmicos e Galeria)
            SliverToBoxAdapter(
              key: _sobreKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSecaoSobre(),
                    const SizedBox(height: 28),
                    _buildSecaoTiposServicos(),
                    const SizedBox(height: 28),
                    _buildSecaoGaleria(),
                  ],
                ),
              ),
            ),

            // 7. Seção: Avaliações e Rodapé Persistente
            SliverToBoxAdapter(
              key: _avaliacoesKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSecaoAvaliacoes(),
                    const SizedBox(height: 20),
                    _buildBarraAcaoRodape(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 1. BANNER COM GRADIENTE, VOLTAR, OPÇÕES E LOGO CENTRALIZADA COM SELO
  // =========================================================================
  Widget _buildCabecalhoSuperiorComLogo() {
    final usaBannerRede = _bannerUrlEmpresa != null &&
        _bannerUrlEmpresa!.isNotEmpty &&
        (_bannerUrlEmpresa!.startsWith('http://') ||
            _bannerUrlEmpresa!.startsWith('https://'));

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // Gradiente azul escuro superior
        Container(
          height: 145,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: usaBannerRede
                ? null
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _kDarkBlueStart,
                      Color(0xFF003D7A),
                      _kDarkBlueEnd,
                    ],
                  ),
            image: usaBannerRede
                ? DecorationImage(
                    image: NetworkImage(_bannerUrlEmpresa!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white, size: 24),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opções adicionais do perfil da loja'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // Logo da loja centralizado com bordas arredondadas e selo azul de verificação
        Positioned(
          bottom: -44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white, width: 3.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _buildFotoLoja(),
                ),
              ),
              // Selo azul de verificação no canto inferior direito
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _kPrimaryCyan,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFotoLoja() {
    final bool usaImagemRede = _fotoUrlEmpresa != null &&
        _fotoUrlEmpresa!.isNotEmpty &&
        (_fotoUrlEmpresa!.startsWith('http://') ||
            _fotoUrlEmpresa!.startsWith('https://'));

    if (usaImagemRede) {
      return Image.network(
        _fotoUrlEmpresa!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildImagemPadraoOuIniciais(),
      );
    } else if (_fotoUrlEmpresa != null &&
        _fotoUrlEmpresa!.isNotEmpty &&
        _fotoUrlEmpresa!.startsWith('assets/')) {
      return Image.asset(
        _fotoUrlEmpresa!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildImagemPadraoOuIniciais(),
      );
    } else {
      return _buildImagemPadraoOuIniciais();
    }
  }

  Widget _buildImagemPadraoOuIniciais() {
    return Image.asset(
      'assets/images/loja_caedss.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFFE0F2FE),
          alignment: Alignment.center,
          child: Text(
            obterIniciais(_nomeEmpresa),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: _kPrimaryCyan,
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // TÍTULO, SUBTÍTULO, CHIPS DE OFÍCIOS DINÂMICOS, STATUS E BOTÕES
  // =========================================================================
  Widget _buildInformacoesLoja() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Título principal
          Text(
            _nomeEmpresa,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _kDarkSlate,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),

          // Subtítulo descritivo em cinza com ícone de loja
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.store_mall_directory_outlined,
                color: _kPrimaryCyan,
                size: 16,
              ),
              SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Oficina e Prestadores Especializados • Loja Registrada',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _kTextMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_tagEmpresa != null && _tagEmpresa!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _corTagEmpresa?.withValues(alpha: 0.15) ??
                    const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _tagEmpresa!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _corTagEmpresa ?? const Color(0xFF0284C7),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Chips de categorias carregadas dinamicamente com cor_oficio.dart
          if (_oficiosEmpresa.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _oficiosEmpresa.map((oficio) {
                final corBase = CorOficio.parse(oficio.cor);
                final corFundo = CorOficio.corFundo(corBase);
                final corTexto = CorOficio.corTexto(corBase);

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: corFundo,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: corBase.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    oficio.funcao,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: corTexto,
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 14),

          // Status dinâmico (agenda da empresa). Toque abre o bottom sheet.
          GestureDetector(
            onTap: _mostrarDisponibilidadeSemanal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _estaAbertoAgora()
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _estaAbertoAgora()
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _BlinkingSignalDot(),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _textoStatusDisponibilidade(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: _estaAbertoAgora()
                            ? const Color(0xFF065F46)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Dois botões de ação lado a lado: "+ Seguir" e "Conversar"
          Row(
            children: [
              // Botão Seguir (dinâmico com Supabase)
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _alternarSeguimento,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF8FAFC),
                      foregroundColor: const Color(0xFF0284C7),
                      side: const BorderSide(color: Color(0xFFBAE6FD), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _seguindo ? Icons.check : Icons.add,
                          color: const Color(0xFF0284C7),
                          size: 19,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _seguindo ? 'Seguindo' : 'Seguir',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Botão Conversar (preenchido em azul claro #0FB3FF)
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _abrirConversa,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimaryCyan,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Conversar',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
    );
  }

  // =========================================================================
  // FAIXA DE MÉTRICAS (4 COLUNAS: AVALIAÇÃO, PRO, ANOS EXP., SEGUIDORES)
  // =========================================================================
  Widget _buildMetricasLoja() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorderColor),
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
            _buildColunaMetrica(
              icone: Icons.star,
              corIcone: _kStarGold,
              valor: '4.9',
              subtitulo: '120 avaliações',
            ),
            _buildDivisorVertical(),
            _buildColunaMetrica(
              icone: Icons.verified,
              corIcone: _kPrimaryCyan,
              valor: 'Pro',
              corValor: _kDarkSlate,
              subtitulo: 'Verificado',
            ),
            _buildDivisorVertical(),
            _buildColunaMetrica(
              icone: Icons.business_center_outlined,
              corIcone: const Color(0xFF475569),
              valor: _anosMercado,
              subtitulo: 'Anos exp.',
            ),
            _buildDivisorVertical(),
            _buildColunaMetrica(
              icone: Icons.people_outline,
              corIcone: const Color(0xFF475569),
              valor: '$_totalSeguidores',
              subtitulo: 'Seguidores',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColunaMetrica({
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
                  color: corValor ?? _kDarkSlate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: _kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivisorVertical() {
    return Container(
      height: 28,
      width: 1,
      color: _kBorderColor,
    );
  }

  // =========================================================================
  // BARRA DE PESQUISA INTERNA
  // =========================================================================
  Widget _buildBarraPesquisa() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorderColor),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _filtroServicos = val.trim().toLowerCase();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Buscar serviços neste perfil...',
                  hintStyle: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13.5,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const Icon(
              Icons.tune_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2. SEÇÃO: EQUIPE DE ESPECIALISTAS (TAG RESPONSÁVEL / FUNCIONÁRIO)
  // =========================================================================
  Widget _buildSecaoEquipe() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Equipe de Especialistas',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: _kDarkSlate,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Profissionais verificados e vinculados',
                    style: TextStyle(
                      fontSize: 12,
                      color: _kTextMuted,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Total de ${listaProfissionais.length} integrantes na equipe.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Text(
                  'Ver todos (${listaProfissionais.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_carregandoProfissionais)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: _kPrimaryCyan),
            ),
          )
        else
          SizedBox(
            height: 195,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemCount: listaProfissionais.length,
              itemBuilder: (context, index) {
                final p = listaProfissionais[index];
                return _buildCardProfissionalCarrossel(p);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCardProfissionalCarrossel(Map<String, dynamic> perfil) {
    final nome = perfil['nome']?.toString().trim() ?? 'Profissional';
    final foto = perfil['caminhoImagem']?.toString().trim() ?? '';
    final bool usaFotoRede =
        foto.startsWith('http://') || foto.startsWith('https://');
    final double avaliacao = (perfil['avaliacao'] as num?)?.toDouble() ?? 4.9;
    final int totalAvaliacoes =
        (perfil['totalAvaliacoes'] as num?)?.toInt() ?? 120;

    // Apenas 'Responsável' ou 'Funcionário'
    final bool isResponsavel =
        perfil['isResponsavel'] == true || perfil['cargo'] == 'Responsável';
    final String cargo = isResponsavel ? 'Responsável' : 'Funcionário';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PerfilProfissionalPage(
              nomeInicial: nome,
              imagemInicial: foto,
              profissao: cargo,
              avaliacao: avaliacao,
              totalAvaliacoes: totalAvaliacoes,
              idGrupoEmpresa: _idGrupoEmpresa,
              idProfissional: (perfil['idProfissional'] as num?)?.toInt(),
            ),
          ),
        );
      },
      child: Container(
        width: 145,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE0F2FE),
              backgroundImage: usaFotoRede ? NetworkImage(foto) : null,
              child: !usaFotoRede
                  ? (foto.isNotEmpty && foto.startsWith('assets/')
                      ? ClipOval(
                          child: Image.asset(foto, fit: BoxFit.cover),
                        )
                      : Text(
                          obterIniciais(nome),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _kPrimaryCyan,
                          ),
                        ))
                  : null,
            ),
            const SizedBox(height: 10),
            Text(
              nome,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _kDarkSlate,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: _kStarGold, size: 13),
                const SizedBox(width: 3),
                Text(
                  avaliacao.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: _kDarkSlate,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '($totalAvaliacoes)',
                  style: const TextStyle(fontSize: 10, color: _kTextMuted),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isResponsavel
                    ? const Color(0xFFF0F9FF)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isResponsavel
                      ? const Color(0xFFBAE6FD)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                cargo,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isResponsavel
                      ? const Color(0xFF0284C7)
                      : const Color(0xFF475569),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. SEÇÃO: LOCALIZAÇÃO E ATENDIMENTO (MAPA, BADGES E BOTÕES DE ROTA)
  // =========================================================================
  Widget _buildSecaoLocalizacao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.location_on_outlined, color: _kPrimaryCyan, size: 20),
            SizedBox(width: 6),
            Text(
              'Localização e Atendimento',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: _kDarkSlate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 180,
                width: double.infinity,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(
                          _enderecoEmpresa?.latitude ?? -23.5505,
                          _enderecoEmpresa?.longitude ?? -46.6333,
                        ),
                        initialZoom: 15.0,
                        minZoom: 3,
                        maxZoom: 19,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                        // Se o mapa for criado DEPOIS do endereço chegar,
                        // já nasce centralizado no pinpoint.
                        onMapReady: () {
                          final e = _enderecoEmpresa;
                          if (e != null && e.temCoordenadas && !_mapaCentralizado) {
                            _mapaCentralizado = true;
                            try {
                              _mapController.move(
                                LatLng(e.latitude, e.longitude),
                                15.0,
                              );
                            } catch (_) {}
                          }
                        },
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
                                _enderecoEmpresa?.latitude ?? -23.5505,
                                _enderecoEmpresa?.longitude ?? -46.6333,
                              ),
                              radius: 68,
                              useRadiusInMeter: false,
                              color: const Color(0xFF0284C7)
                                  .withValues(alpha: 0.12),
                              borderColor: const Color(0xFF0284C7)
                                  .withValues(alpha: 0.35),
                              borderStrokeWidth: 1.5,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                _enderecoEmpresa?.latitude ?? -23.5505,
                                _enderecoEmpresa?.longitude ?? -46.6333,
                              ),
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _kPrimaryCyan,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _kPrimaryCyan
                                          .withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

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
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _BlinkingSignalDot(),
                            const SizedBox(width: 6),
                            Text(
                              _estaAbertoAgora() ? 'Aberto agora' : 'Fechado agora',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _estaAbertoAgora()
                                    ? const Color(0xFF065F46)
                                    : const Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

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
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.radar_rounded,
                              size: 15,
                              color: Color(0xFF0284C7),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Raio de 1 km',
                              style: TextStyle(
                                fontSize: 12,
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

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFBAE6FD)
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: Color(0xFF0284C7),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _enderecoEmpresa?.apelido ?? 'Endereço da empresa',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _kDarkSlate,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _enderecoCarregado
                                    ? (_enderecoEmpresa != null
                                        ? '${_enderecoEmpresa!.logradouro}${_enderecoEmpresa!.numero.isNotEmpty ? ', ${_enderecoEmpresa!.numero}' : ''}'
                                        : 'Endereço não cadastrado')
                                    : 'Carregando endereço...',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _enderecoCarregado
                                    ? (_enderecoEmpresa != null
                                        ? '${_enderecoEmpresa!.bairro}${_enderecoEmpresa!.cidade.isNotEmpty ? ', ${_enderecoEmpresa!.cidade}' : ''}${_enderecoEmpresa!.estado.isNotEmpty ? ' - ${_enderecoEmpresa!.estado}' : ''} • CEP ${_enderecoEmpresa!.cep}'
                                        : '')
                                    : '',
                                style: const TextStyle(
                                  fontSize: 12,
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
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () {
                                final e = _enderecoEmpresa;
                                if (e == null || !_enderecoCarregado) return;
                                final rota =
                                    '${e.logradouro}${e.numero.isNotEmpty ? ', ${e.numero}' : ''} - ${e.bairro}';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Calculando rota para $rota...',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFF0F9FF),
                                foregroundColor: const Color(0xFF0284C7),
                                side: const BorderSide(
                                  color: Color(0xFFBAE6FD),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.assistant_direction_outlined,
                                    size: 18,
                                    color: Color(0xFF0284C7),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Como Chegar',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: () async {
                                final e = _enderecoEmpresa;
                                if (e == null || !_enderecoCarregado) return;
                                final query = Uri.encodeComponent(
                                  '${e.logradouro}, ${e.numero} - ${e.bairro}, ${e.cidade}/${e.estado} - CEP ${e.cep}',
                                );
                                final uri = Uri.parse(
                                  'https://www.google.com/maps/search/?api=1&query=$query',
                                );
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Abrindo no Google Maps...'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF334155),
                                side: const BorderSide(color: _kBorderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 18,
                                    color: Color(0xFF334155),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Google Maps',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF334155),
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
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 4. SEÇÃO: SOBRE A LOJA / EMPRESA COM EXPANSÃO VER MAIS
  // =========================================================================
  Widget _buildSecaoSobre() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: Color(0xFF0284C7),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Sobre a empresa',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: _kDarkSlate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _descricaoEmpresa.isNotEmpty
              ? (isDescricaoExpandida
                  ? _descricaoEmpresa
                  : (_descricaoEmpresa.length > 220
                      ? '${_descricaoEmpresa.substring(0, 220)}...'
                      : _descricaoEmpresa))
              : 'Esta empresa ainda não cadastrou uma descrição.',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() {
              isDescricaoExpandida = !isDescricaoExpandida;
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isDescricaoExpandida ? 'Ver Menos' : 'Ver Mais',
                style: const TextStyle(
                  color: Color(0xFF0284C7),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                isDescricaoExpandida
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: const Color(0xFF0284C7),
                size: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 5. SEÇÃO: TIPOS DE SERVIÇOS OFERECIDOS (OFÍCIOS REAIS COM COR E ÍCONE)
  // =========================================================================
  Widget _buildSecaoTiposServicos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipos de serviços oferecidos',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.bold,
            color: _kDarkSlate,
          ),
        ),
        const SizedBox(height: 14),
        if (_oficiosEmpresa.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kBorderColor),
            ),
            child: const Text(
              'Nenhum tipo de serviço cadastrado para esta empresa.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _kTextMuted),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.7,
            ),
            itemCount: _oficiosEmpresa.length,
            itemBuilder: (context, index) {
              final oficio = _oficiosEmpresa[index];
              final corBase = CorOficio.parse(oficio.cor);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorderColor),
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
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _kDarkSlate,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // =========================================================================
  // 6. SEÇÃO: GALERIA DE SERVIÇOS (FOTOS COM LEGENDA EM GRADIENTE ESCURO)
  // =========================================================================
  Widget _buildSecaoGaleria() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: const [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Galeria de serviços',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: _kDarkSlate,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Fotos reais de trabalhos realizados',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kTextMuted,
                  ),
                ),
              ],
            ),
            Text(
              'Arraste para ver →',
              style: TextStyle(
                fontSize: 12,
                color: _kTextMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FutureBuilder<List<PostagemResumo>>(
          future: _postagensGaleriaFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 145,
                child: Center(
                  child: CircularProgressIndicator(color: _kPrimaryCyan),
                ),
              );
            }
            final postagens = snapshot.data ?? const <PostagemResumo>[];
            if (postagens.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kBorderColor),
                ),
                child: const Text(
                  'Esta empresa ainda não publicou trabalhos na galeria.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: _kTextMuted),
                ),
              );
            }
            return SizedBox(
              height: 145,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: postagens.length,
                itemBuilder: (context, index) {
                  final item = postagens[index];
                  return Container(
                    width: 230,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                    if (item.imagemUrl != null && item.imagemUrl!.isNotEmpty)
                      Image.network(
                        item.imagemUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFE2E8F0),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                              size: 32,
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(
                          Icons.image_outlined,
                          color: Colors.grey,
                          size: 32,
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 65,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        alignment: Alignment.bottomLeft,
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          item.titulo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
          },
        ),
      ],
    );
  }

  // =========================================================================
  // 7. SEÇÃO: SERVIÇOS OFERECIDOS (PLACEHOLDER DE MEUS_SERVICOS E PREÇO EM _kDarkBlueEnd)
  // =========================================================================
  Widget _buildSecaoServicosOferecidos() {
    final categorias = [
      'Todos',
      ..._oficiosEmpresa.map((o) => o.funcao).toSet(),
    ];

    final servicosFiltrados = _servicosLoja.where((s) {
      final t = s.titulo.toLowerCase();
      final d = s.descricao.toLowerCase();
      final f = (s.funcao ?? '').toLowerCase();

      final bateBusca = _filtroServicos.isEmpty ||
          t.contains(_filtroServicos) ||
          d.contains(_filtroServicos) ||
          f.contains(_filtroServicos);

      final bateCategoria = _categoriaServicoSelecionada == 'Todos' ||
          f.contains(_categoriaServicoSelecionada.toLowerCase()) ||
          t.contains(_categoriaServicoSelecionada.toLowerCase());

      return bateBusca && bateCategoria;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Serviços Oferecidos',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.bold,
            color: _kDarkSlate,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Contratação direta com garantia ConsertaJá',
          style: TextStyle(
            fontSize: 12,
            color: _kTextMuted,
          ),
        ),
        const SizedBox(height: 14),

        // Filtros em formato de pílula horizontais
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: categorias.map((cat) {
              final bool isSelected = _categoriaServicoSelecionada == cat;
              return GestureDetector(
                onTap: () {
                  setState(() => _categoriaServicoSelecionada = cat);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF0F9FF)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? _kPrimaryCyan : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF475569),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        if (_carregandoServicos)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: _kPrimaryCyan),
            ),
          )
        else if (servicosFiltrados.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorderColor),
            ),
            child: Text(
              _servicosLoja.isEmpty
                  ? 'Esta empresa ainda não cadastrou serviços.'
                  : 'Nenhum serviço encontrado para esta categoria ou busca.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: _kTextMuted),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.78,
            ),
            itemCount: servicosFiltrados.length,
            itemBuilder: (context, index) {
              final servico = servicosFiltrados[index];
              return _buildCardServicoCatalogo(servico);
            },
          ),
      ],
    );
  }

  // Placeholder idêntico a meus_servicos_profissional.dart
  Widget _placeholderImagemServico() {
    return Container(
      height: 105,
      width: double.infinity,
      color: const Color(0xFFEAF4FB),
      child: const Center(
        child: Icon(
          Icons.home_repair_service_rounded,
          color: Color(0xFF0A6E9D),
          size: 38,
        ),
      ),
    );
  }

  Widget _buildCardServicoCatalogo(ServicoProfissional servico) {
    final bool usaImagemRede = servico.imagemUrl != null &&
        servico.imagemUrl!.trim().isNotEmpty &&
        (servico.imagemUrl!.startsWith('http://') ||
            servico.imagemUrl!.startsWith('https://'));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaServico(
              idServico: servico.id,
              servicoInicial: servico,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 105,
                  width: double.infinity,
                  child: usaImagemRede
                      ? Image.network(
                          servico.imagemUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _placeholderImagemServico(),
                        )
                      : _placeholderImagemServico(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      servico.funcao ?? 'Serviço',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: _kDarkSlate,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      servico.titulo,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: _kDarkSlate,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.star, color: _kStarGold, size: 12),
                        SizedBox(width: 3),
                        Text(
                          '4.9',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _kDarkSlate,
                          ),
                        ),
                        SizedBox(width: 2),
                        Text(
                          '(180)',
                          style: TextStyle(
                            fontSize: 10,
                            color: _kTextMuted,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Text(
                      'Preço Médio',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: _kTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'R\$ ${servico.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: _kDarkBlueEnd,
                      ),
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

  // =========================================================================
  // 8. SEÇÃO: SISTEMA DE AVALIAÇÕES (RESUMO, FILTROS E COMENTÁRIOS COM CURTIDA)
  // =========================================================================
  Widget _buildSecaoAvaliacoes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text(
              '5.0',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kDarkSlate,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.star, color: _kStarGold, size: 18),
            SizedBox(width: 6),
            Text(
              'Avaliações do Profissional',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kDarkSlate,
              ),
            ),
            SizedBox(width: 4),
            Text(
              '(923)',
              style: TextStyle(fontSize: 14, color: _kTextMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(Icons.star, color: Color(0xFF0284C7), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Resumo dos comentários',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: _kDarkSlate,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Clientes destacam pontualidade, simpatia dos técnicos e preço justo. A oficina é amplamente recomendada por resolver emergências com agilidade e deixar os locais limpos.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildFiltroComentario('Principais'),
                const SizedBox(width: 8),
                _buildFiltroComentario('Recentes'),
              ],
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Exibindo todas as 932 avaliações da loja.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Ver todas (932)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildItemComentario(
          iniciais: 'LF',
          nome: 'Luiz Fernando',
          tempo: 'há 8 dias',
          texto:
              'Muito bom, serviço impecável e rápido! Trocou o segredo da minha fechadura em 20 minutos.',
          liked: likedComentario1,
          likes: likesComentario1,
          onLikeTap: () {
            setState(() {
              likedComentario1 = !likedComentario1;
              likesComentario1 += likedComentario1 ? 1 : -1;
            });
          },
        ),
        const SizedBox(height: 10),

        _buildItemComentario(
          iniciais: 'GS',
          nome: 'Gabriel Santos',
          tempo: 'há 8 dias',
          texto:
              'Moro em Diadema, atendimento super rápido para cópia de chave codificada. Recomendo demais!',
          liked: likedComentario2,
          likes: likesComentario2,
          onLikeTap: () {
            setState(() {
              likedComentario2 = !likedComentario2;
              likesComentario2 += likedComentario2 ? 1 : -1;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFiltroComentario(String texto) {
    final bool isSelected = filtroComentario == texto;
    return GestureDetector(
      onTap: () => setState(() => filtroComentario = texto),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F9FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _kPrimaryCyan : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF475569),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildItemComentario({
    required String iniciais,
    required String nome,
    required String tempo,
    required String texto,
    required bool liked,
    required int likes,
    required VoidCallback onLikeTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _kPrimaryCyan,
                child: Text(
                  iniciais,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: _kDarkSlate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => const Icon(
                            Icons.star,
                            color: _kStarGold,
                            size: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tempo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onLikeTap,
                child: Row(
                  children: [
                    Icon(
                      liked ? Icons.favorite : Icons.favorite_border,
                      color: liked ? _kPrimaryCyan : const Color(0xFF94A3B8),
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$likes',
                      style: TextStyle(
                        fontSize: 12,
                        color: liked ? _kPrimaryCyan : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 9. BARRA FIXA / CTA PERSISTENTE (DOCK INFERIOR ESCURO COM BOTÃO DE CONVERSÃO)
  // =========================================================================
  Widget _buildBarraAcaoRodape() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kCtaNavy,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Precisa de suporte urgente?',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Chame agora pelo ConsertaJá',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _kPrimaryCyan,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _abrirSolicitacaoServico,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimaryCyan,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Orçamento / Contratar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PLACEHOLDERS REMOVIDOS — sem fallback estático (lista vazia = vazio real).
  // =========================================================================
}

// =========================================================================
// DELEGATE PARA ABAS STICKY (PINNED) NO TOPO AO ROLAR A TELA
// =========================================================================
class _AbasLojaDelegate extends SliverPersistentHeaderDelegate {
  final String abaAtiva;
  final void Function(String aba, GlobalKey key) onAbaTap;
  final GlobalKey equipeKey;
  final GlobalKey servicosKey;
  final GlobalKey sobreKey;
  final GlobalKey avaliacoesKey;
  final bool mostrarEquipe;

  _AbasLojaDelegate({
    required this.abaAtiva,
    required this.onAbaTap,
    required this.equipeKey,
    required this.servicosKey,
    required this.sobreKey,
    required this.avaliacoesKey,
    this.mostrarEquipe = true,
  });

  List<String> get _abas => [
    if (mostrarEquipe) 'Equipe',
    'Serviços',
    'Sobre a Empresa',
    'Avaliações',
  ];

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
              children: _abas.map((aba) {
                final bool isActive = abaAtiva == aba;
                GlobalKey targetKey;
                switch (aba) {
                  case 'Equipe':
                    targetKey = equipeKey;
                    break;
                  case 'Serviços':
                    targetKey = servicosKey;
                    break;
                  case 'Sobre a Empresa':
                    targetKey = sobreKey;
                    break;
                  case 'Avaliações':
                  default:
                    targetKey = avaliacoesKey;
                    break;
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () => onAbaTap(aba, targetKey),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        Text(
                          aba,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.w600,
                            color: isActive
                                ? _kPrimaryCyan
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 2.5,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _kPrimaryCyan
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AbasLojaDelegate oldDelegate) {
    return oldDelegate.abaAtiva != abaAtiva ||
        oldDelegate.mostrarEquipe != mostrarEquipe;
  }
}
