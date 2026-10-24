import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'widgets/skeleton_loading.dart';
import 'meus_pedidos.dart';
import 'perfil_profissional.dart';
import 'perfil_loja.dart';
import 'tela_meu_perfil_cliente.dart';
import 'seguindo_cliente.dart';
import 'services/servicos_profissional_service.dart';
import 'utils/bottom_navigation_bar_cliente.dart';
import 'utils/cor_oficio.dart';
import 'utils/iniciais.dart';
import 'widgets/tag_oficio.dart';
import 'tela_home.dart';
import 'models/servico_profissional.dart';
import 'tela_servico.dart';
import 'utils/app_navigation_util.dart';

enum _AbaResultado { todos, servicos, profissionais }

class _ServicoBusca {
  final int? id;
  final ServicoProfissional servicoOriginal;
  final String titulo;
  final String? codigoTag;
  final String categoriaTag;
  final String logistica;
  final double preco;
  final String localizacao;
  final String caminhoImagem;
  final List<String> termosBusca;

  const _ServicoBusca({
    this.id,
    required this.servicoOriginal,
    required this.titulo,
    required this.codigoTag,
    required this.categoriaTag,
    required this.logistica,
    required this.preco,
    required this.localizacao,
    required this.caminhoImagem,
    required this.termosBusca,
  });
}

class _ProfissionalBusca {
  final String nome;
  final double? avaliacao;
  final String tag1;
  final String? tag2;
  final List<OficioInfo> oficios;
  final String descricao;
  final String localizacao;
  final String distancia;
  final String? caminhoImagem;
  final bool verificado;
  final bool isLoja;
  final int? idGrupoEmpresa;
  final int? idProfissional;
  final int totalAvaliacoes;
  final int seguidores;
  final String? tagEmpresa;
  final Color? tagEmpresaBgColor;
  final Color? tagEmpresaTextColor;
  final List<String> termosBusca;

  const _ProfissionalBusca({
    required this.nome,
    required this.avaliacao,
    required this.tag1,
    this.tag2,
    this.oficios = const [],
    required this.descricao,
    required this.localizacao,
    required this.distancia,
    this.caminhoImagem,
    this.verificado = false,
    this.isLoja = false,
    this.idGrupoEmpresa,
    this.idProfissional,
    this.totalAvaliacoes = 0,
    this.seguidores = 0,
    this.tagEmpresa,
    this.tagEmpresaBgColor,
    this.tagEmpresaTextColor,
    required this.termosBusca,
  });
}

class TelaBusca extends StatefulWidget {
  final bool isVisitante;

  const TelaBusca({super.key, this.isVisitante = false});

  static const Color _primaryBlue = Color(0xFF0FB3FF);

  @override
  State<TelaBusca> createState() => _TelaBuscaState();
}

class _TelaBuscaState extends State<TelaBusca> {
  static const Color _primaryBlue = TelaBusca._primaryBlue;
  static const Color _ratingBg = Color(0xFFFFF8E1);
  static const Color _ratingText = Color(0xFFE65100);

  final TextEditingController _controllerBusca = TextEditingController();
  final FocusNode _focusBusca = FocusNode();

  bool _mostrarMaisCategorias = false;
  bool _mostrandoResultados = false;
  String _termoBusca = '';
  _AbaResultado _abaAtiva = _AbaResultado.todos;

  List<_ProfissionalBusca> _profissionaisSupabase = [];
  List<_ProfissionalBusca> _empresasSupabase = [];
  List<_ServicoBusca> _servicosSupabase = [];
  bool _carregandoProfissionais = false;
  String? _erroNaBusca;
  List<String> _categorias = [];
  bool _carregandoCategorias = true;

  @override
  void initState() {
    super.initState();
    _carregarCategorias();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusBusca.requestFocus();
    });
  }

  @override
  void dispose() {
    _controllerBusca.dispose();
    _focusBusca.dispose();
    super.dispose();
  }

  List<String> get _categoriasVisiveis =>
      _mostrarMaisCategorias ? _categorias : _categorias.take(8).toList();

  Future<void> _carregarCategorias() async {
    try {
      final rows = await Supabase.instance.client
          .from('oficios')
          .select('categoria')
          .order('categoria');
      final categorias =
          rows
              .map((row) => row['categoria']?.toString().trim() ?? '')
              .where((categoria) => categoria.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _carregandoCategorias = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Erro ao carregar categorias da busca: $e\n$stackTrace');
      if (!mounted) return;
      setState(() => _carregandoCategorias = false);
    }
  }

  bool _correspondeBusca(List<String> termos, String termo) {
    if (termo.trim().isEmpty) return true;
    final normalizado = _normalizar(termo);
    final palavras = normalizado
        .split(RegExp(r'\s+'))
        .where((p) => p.length > 1)
        .toList();

    bool termoCombina(String item) {
      final itemNorm = _normalizar(item);
      return itemNorm.contains(normalizado) || normalizado.contains(itemNorm);
    }

    if (palavras.isEmpty) {
      return termos.any(termoCombina);
    }

    return palavras.any(
      (palavra) => termos.any((t) {
        final tNorm = _normalizar(t);
        return tNorm.contains(palavra) || palavra.contains(tNorm);
      }),
    );
  }

  String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }

  bool _imagemEhUrl(String? caminho) {
    if (caminho == null) return false;
    return caminho.startsWith('http://') || caminho.startsWith('https://');
  }

  Future<void> _buscarProfissionaisNoSupabase(String termo) async {
    setState(() {
      _carregandoProfissionais = true;
      _erroNaBusca = null;
    });

    try {
      final supabase = Supabase.instance.client;

      final empresasData = await supabase
          .from('grupo_empresa')
          .select(
            'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, fk_perfil, seguidores_empresa, descricao_empresa',
          );
      final empresasPorId = <int, Map<String, dynamic>>{};
      final empresasPorPerfil = <int, Map<String, dynamic>>{};
      final gruposPorOficio = <int>{};
      for (final empresa in empresasData) {
        final idGrupo = (empresa['id_grupo_empresa'] as num?)?.toInt();
        if (idGrupo == null) continue;
        final dados = Map<String, dynamic>.from(empresa);
        empresasPorId[idGrupo] = dados;
        final fkPerfil = (empresa['fk_perfil'] as num?)?.toInt();
        if (fkPerfil != null) empresasPorPerfil[fkPerfil] = dados;
      }

      List<_ProfissionalBusca> empresasEncontradas = [];

      // 1) Busca profissionais por NOME na tabela usuarios (sem joins)
      final usuariosPorNome = await supabase
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url')
          .eq('tipo_conta', 'Profissional')
          .ilike('nome', '%$termo%');

      // 2) Busca ofícios (profissão) equivalentes ao termo
      final todosOficios = await supabase
          .from('oficios')
          .select('id_oficio, funcao, categoria, cor')
          .order('funcao');
      final oficiosEncontrados = todosOficios.where((oficio) {
        return _correspondeBusca([
          oficio['funcao']?.toString() ?? '',
          oficio['categoria']?.toString() ?? '',
        ], termo);
      }).toList();

      // Mapa de id_oficio -> funcao
      final oficiosPorId = <int, String>{
        for (final oficio in oficiosEncontrados)
          if ((oficio['id_oficio'] as num?)?.toInt() case final int id)
            id: oficio['funcao']?.toString() ?? '',
      };

      final idsOficios = oficiosPorId.keys.toList();

      // 3) Mapa de id_profissional -> Lista de id_oficio
      final oficiosPorProfissional = <int, List<int>>{};

      if (idsOficios.isNotEmpty) {
        // Busca todas as associações desses ofícios
        final associacoes = await supabase
            .from('ass_oficio_profissional')
            .select('fk_profissional, fk_oficio')
            .inFilter('fk_oficio', idsOficios);

        for (final ass in associacoes) {
          final idProf = (ass['fk_profissional'] as num?)?.toInt();
          final idOf = (ass['fk_oficio'] as num?)?.toInt();
          if (idProf != null && idOf != null) {
            oficiosPorProfissional.putIfAbsent(idProf, () => []).add(idOf);
          }
        }

        final associacoesEmpresas = await supabase
            .from('ass_oficio_grupo_empresa')
            .select('fk_grupo_empresa')
            .inFilter('fk_oficio', idsOficios);
        for (final associacao in associacoesEmpresas) {
          final idGrupo = (associacao['fk_grupo_empresa'] as num?)?.toInt();
          if (idGrupo != null) gruposPorOficio.add(idGrupo);
        }
      }

      // 4) Busca ids_profissional por fk_usuario (para todos os usuários encontrados)
      Map<int, int> usuarioParaProfissional = {};
      final dadosPorProfissional = <int, Map<String, dynamic>>{};

      // Combina todos os ids de usuários relevantes: por nome e por ofício
      final idsUsuariosRelevantes = usuariosPorNome
          .map((e) => (e['id_usuario'] as num?)?.toInt() ?? 0)
          .where((id) => id > 0)
          .toSet();

      // Usuários por ofício
      Set<int> idsUsuariosPorOficio = {};
      if (oficiosPorProfissional.isNotEmpty) {
        final dadosProfPorOficio = await supabase
            .from('dados_profissionais')
            .select(
              'id_profissional, fk_usuario, fk_grupo_empresa, fk_perfil, verificar_autenticacao',
            )
            .inFilter('id_profissional', oficiosPorProfissional.keys.toList());

        for (final dp in dadosProfPorOficio) {
          final idProf = (dp['id_profissional'] as num?)?.toInt();
          if (idProf != null) {
            dadosPorProfissional[idProf] = Map<String, dynamic>.from(dp);
          }
          final idGrupo = (dp['fk_grupo_empresa'] as num?)?.toInt();
          if (idGrupo != null) gruposPorOficio.add(idGrupo);
          final idUsuario = (dp['fk_usuario'] as num?)?.toInt();
          if (idProf != null && idUsuario != null) {
            usuarioParaProfissional[idUsuario] = idProf;
          }
          if (idUsuario != null) {
            idsUsuariosPorOficio.add(idUsuario);
          }
        }
      }

      // Busca mapping para usuários por nome
      if (idsUsuariosRelevantes.isNotEmpty) {
        final dadosProfissionais = await supabase
            .from('dados_profissionais')
            .select(
              'id_profissional, fk_usuario, fk_grupo_empresa, fk_perfil, verificar_autenticacao',
            )
            .inFilter('fk_usuario', idsUsuariosRelevantes.toList());

        for (final dp in dadosProfissionais) {
          final idProf = (dp['id_profissional'] as num?)?.toInt();
          if (idProf != null) {
            dadosPorProfissional[idProf] = Map<String, dynamic>.from(dp);
          }
          final idUsuario = (dp['fk_usuario'] as num?)?.toInt();
          if (idProf != null && idUsuario != null) {
            usuarioParaProfissional[idUsuario] = idProf;
          }
        }
      }

      final empresasFiltradas = empresasData.where((empresa) {
        final idGrupo = (empresa['id_grupo_empresa'] as num?)?.toInt();
        return _correspondeBusca([
              empresa['nome_empresa']?.toString() ?? '',
              empresa['tag_empresa']?.toString() ?? '',
            ], termo) ||
            (idGrupo != null && gruposPorOficio.contains(idGrupo));
      }).toList();

      // Para cada empresa encontrada, carrega a foto e todos os oficios
      // herdados dos profissionais vinculados (proprietario + membros).
      for (final empresa in empresasFiltradas) {
        final idGrupo = (empresa['id_grupo_empresa'] as num?)?.toInt();
        final fkPerfil = (empresa['fk_perfil'] as num?)?.toInt();
        final tag = empresa['tag_empresa']?.toString().trim() ?? '';
        final cor = CorOficio.parse(empresa['cor_tag_empresa']?.toString());
        final nome = empresa['nome_empresa']?.toString().trim() ?? '';

        final List<OficioInfo> oficiosEmpresa = [];
        if (idGrupo != null) {
          final Set<int> idsProfissional = <int>{};
          if (fkPerfil != null) {
            final dono = await supabase
                .from('dados_profissionais')
                .select('id_profissional')
                .eq('fk_perfil', fkPerfil)
                .maybeSingle();
            final idProfDono = (dono?['id_profissional'] as num?)?.toInt();
            if (idProfDono != null) idsProfissional.add(idProfDono);
          }

          final membros = await supabase
              .from('dados_profissionais')
              .select('id_profissional')
              .eq('fk_grupo_empresa', idGrupo);
          for (final membro in membros) {
            final idProf = (membro['id_profissional'] as num?)?.toInt();
            if (idProf != null) idsProfissional.add(idProf);
          }

          final idsOficiosEmpresa = <int>{};
          if (idsProfissional.isNotEmpty) {
            final associacoesProfissionais = await supabase
                .from('ass_oficio_profissional')
                .select('fk_oficio')
                .inFilter('fk_profissional', idsProfissional.toList());
            idsOficiosEmpresa.addAll(
              associacoesProfissionais
                  .map((row) => (row['fk_oficio'] as num?)?.toInt())
                  .whereType<int>(),
            );
          }
          final associacoesEmpresa = await supabase
              .from('ass_oficio_grupo_empresa')
              .select('fk_oficio')
              .eq('fk_grupo_empresa', idGrupo);
          idsOficiosEmpresa.addAll(
            associacoesEmpresa
                .map((row) => (row['fk_oficio'] as num?)?.toInt())
                .whereType<int>(),
          );

          if (idsOficiosEmpresa.isNotEmpty) {
            final oficiosData = await supabase
                .from('oficios')
                .select('funcao, cor')
                .inFilter('id_oficio', idsOficiosEmpresa.toList());
            final funcoesVistas = <String>{};
            for (final row in oficiosData) {
              final info = OficioInfo.fromMap(row);
              if (info.funcao.trim().isNotEmpty &&
                  funcoesVistas.add(info.funcao.trim().toLowerCase())) {
                oficiosEmpresa.add(info);
              }
            }
          }
        }

        final descricaoBanco =
            empresa['descricao_empresa']?.toString().trim() ?? '';
        final profissionalDono = fkPerfil == null
            ? null
            : await supabase
                  .from('dados_profissionais')
                  .select('verificar_autenticacao')
                  .eq('fk_perfil', fkPerfil)
                  .maybeSingle();
        empresasEncontradas.add(
          _ProfissionalBusca(
            nome: nome,
            avaliacao: null,
            tag1: 'Empresa',
            descricao: descricaoBanco.isNotEmpty
                ? descricaoBanco
                : oficiosEmpresa.map((o) => o.funcao).join(', '),
            localizacao: 'Localização não informada',
            distancia: '',
            caminhoImagem: empresa['foto_url_empresa']?.toString().trim() ?? '',
            verificado: profissionalDono?['verificar_autenticacao'] == true,
            isLoja: true,
            idGrupoEmpresa: idGrupo,
            seguidores: (empresa['seguidores_empresa'] as num?)?.toInt() ?? 0,
            oficios: oficiosEmpresa,
            tagEmpresa: tag.isEmpty
                ? null
                : (tag.startsWith('#') ? tag : '#$tag'),
            tagEmpresaBgColor: cor,
            tagEmpresaTextColor: CorOficio.corTextoContraste(cor),
            termosBusca: [nome, tag],
          ),
        );
      }

      // Combinar usuários por nome + usuários por ofício
      Map<int, Map<String, dynamic>> usuariosEncontrados = {};
      for (final item in usuariosPorNome) {
        final id = (item['id_usuario'] as num?)?.toInt();
        if (id != null) {
          usuariosEncontrados[id] = Map<String, dynamic>.from(item);
        }
      }

      if (idsUsuariosPorOficio.isNotEmpty) {
        final usuariosPorOficio = await supabase
            .from('usuarios')
            .select('id_usuario, nome, foto_perfil_url')
            .inFilter('id_usuario', idsUsuariosPorOficio.toList());

        for (final item in usuariosPorOficio) {
          final id = (item['id_usuario'] as num?)?.toInt();
          if (id != null) {
            usuariosEncontrados.putIfAbsent(
              id,
              () => Map<String, dynamic>.from(item),
            );
          }
        }
      }

      // 5) Busca a localização pública vinculada ao perfil profissional.
      final localizacaoPorProfissional = <int, String>{};
      final idsProfissionais = usuarioParaProfissional.values.toSet().toList();
      if (idsProfissionais.isNotEmpty) {
        final vinculos = await supabase
            .from('ass_profissional_endereco')
            .select('fk_profissional, fk_endereco')
            .inFilter('fk_profissional', idsProfissionais)
            .eq('endereco_ativo', true);
        final enderecoPorProfissional = <int, int>{};
        for (final vinculo in vinculos) {
          final idProfissional = (vinculo['fk_profissional'] as num?)?.toInt();
          final idEndereco = (vinculo['fk_endereco'] as num?)?.toInt();
          if (idProfissional != null && idEndereco != null) {
            enderecoPorProfissional.putIfAbsent(
              idProfissional,
              () => idEndereco,
            );
          }
        }

        if (enderecoPorProfissional.isNotEmpty) {
          final enderecos = await supabase
              .from('enderecos')
              .select('id_endereco, fk_cidade')
              .inFilter(
                'id_endereco',
                enderecoPorProfissional.values.toSet().toList(),
              );
          final cidadePorEndereco = <int, int>{};
          for (final endereco in enderecos) {
            final idEndereco = (endereco['id_endereco'] as num?)?.toInt();
            final idCidade = (endereco['fk_cidade'] as num?)?.toInt();
            if (idEndereco != null && idCidade != null) {
              cidadePorEndereco[idEndereco] = idCidade;
            }
          }

          final cidades = await supabase
              .from('cidades')
              .select('id_cidade, nome_cidade, fk_estado')
              .inFilter('id_cidade', cidadePorEndereco.values.toSet().toList());
          final estadoPorCidade = <int, String>{};
          final cidadesPorId = <int, Map<String, dynamic>>{};
          for (final cidade in cidades) {
            final idCidade = (cidade['id_cidade'] as num?)?.toInt();
            final idEstado = (cidade['fk_estado'] as num?)?.toInt();
            if (idCidade != null) {
              cidadesPorId[idCidade] = Map<String, dynamic>.from(cidade);
              if (idEstado != null) estadoPorCidade[idCidade] = '$idEstado';
            }
          }
          final idsEstados = estadoPorCidade.values
              .map(int.tryParse)
              .whereType<int>()
              .toSet()
              .toList();
          final estados = idsEstados.isEmpty
              ? <Map<String, dynamic>>[]
              : await supabase
                    .from('estados')
                    .select('id_estado, sigla_estado')
                    .inFilter('id_estado', idsEstados);
          final siglaPorEstado = <int, String>{
            for (final estado in estados)
              if ((estado['id_estado'] as num?)?.toInt() case final int id)
                id: estado['sigla_estado']?.toString() ?? '',
          };

          for (final entry in enderecoPorProfissional.entries) {
            final idCidade = cidadePorEndereco[entry.value];
            final cidade = idCidade == null ? null : cidadesPorId[idCidade];
            final nomeCidade = cidade?['nome_cidade']?.toString() ?? '';
            final idEstado = idCidade == null
                ? null
                : int.tryParse(estadoPorCidade[idCidade] ?? '');
            final siglaEstado = idEstado == null
                ? ''
                : siglaPorEstado[idEstado] ?? '';
            if (nomeCidade.isNotEmpty) {
              localizacaoPorProfissional[entry.key] = siglaEstado.isEmpty
                  ? nomeCidade
                  : '$nomeCidade - $siglaEstado';
            }
          }
        }
      }

      // 6) Para cada usuário encontrado, busca ofícios
      final resultados = <_ProfissionalBusca>[];
      final idsProfissionaisEncontrados = usuarioParaProfissional.values
          .toSet()
          .toList();
      final avaliacoesPorProfissional = <int, List<int>>{};
      if (idsProfissionaisEncontrados.isNotEmpty) {
        final solicitacoes = await supabase
            .from('solicitacoes')
            .select('id_solicitacao, fk_profissional')
            .inFilter('fk_profissional', idsProfissionaisEncontrados);
        final profissionalPorSolicitacao = <int, int>{};
        for (final solicitacao in solicitacoes) {
          final idSolicitacao = (solicitacao['id_solicitacao'] as num?)
              ?.toInt();
          final idProfissional = (solicitacao['fk_profissional'] as num?)
              ?.toInt();
          if (idSolicitacao != null && idProfissional != null) {
            profissionalPorSolicitacao[idSolicitacao] = idProfissional;
          }
        }

        if (profissionalPorSolicitacao.isNotEmpty) {
          final avaliacoes = await supabase
              .from('avaliacoes_solicitacao')
              .select('fk_solicitacao, nota')
              .eq('tipo_avaliacao', 'profissional')
              .inFilter(
                'fk_solicitacao',
                profissionalPorSolicitacao.keys.toList(),
              );
          for (final avaliacao in avaliacoes) {
            final idSolicitacao = (avaliacao['fk_solicitacao'] as num?)
                ?.toInt();
            final nota = (avaliacao['nota'] as num?)?.toInt();
            final idProfissional = idSolicitacao == null
                ? null
                : profissionalPorSolicitacao[idSolicitacao];
            if (idProfissional != null && nota != null) {
              avaliacoesPorProfissional
                  .putIfAbsent(idProfissional, () => [])
                  .add(nota);
            }
          }
        }
      }

      for (final entry in usuariosEncontrados.entries) {
        final usuarioId = entry.key;
        final usuario = entry.value;
        final nome = usuario['nome']?.toString() ?? '';
        if (nome.trim().isEmpty) continue;

        final idProfissional = usuarioParaProfissional[usuarioId];
        final String localizacao = idProfissional == null
            ? 'Localização não informada'
            : localizacaoPorProfissional[idProfissional] ??
                  'Localização não informada';

        // Ofícios do profissional (via dados_profissionais + ass_oficio_profissional + oficios)
        final dadosProfissional = idProfissional == null
            ? null
            : dadosPorProfissional[idProfissional];
        final idGrupoEmpresa = (dadosProfissional?['fk_grupo_empresa'] as num?)
            ?.toInt();
        final fkPerfil = (dadosProfissional?['fk_perfil'] as num?)?.toInt();
        final empresa = idGrupoEmpresa != null
            ? empresasPorId[idGrupoEmpresa]
            : (fkPerfil != null ? empresasPorPerfil[fkPerfil] : null);
        final tagEmpresaRaw = empresa?['tag_empresa']?.toString().trim() ?? '';
        final corEmpresa = CorOficio.parse(
          empresa?['cor_tag_empresa']?.toString(),
        );

        List<OficioInfo> oficiosDoUsuario = [];
        if (idProfissional != null) {
          final oficiosDoProf = oficiosPorProfissional[idProfissional] ?? [];

          // Se veio via nome, ainda não temos ofícios; busca associações
          if (oficiosDoProf.isEmpty) {
            final assPorProf = await supabase
                .from('ass_oficio_profissional')
                .select('fk_oficio')
                .eq('fk_profissional', idProfissional);

            for (final ass in assPorProf) {
              final idOf = (ass['fk_oficio'] as num?)?.toInt();
              if (idOf != null) oficiosDoProf.add(idOf);
            }
          }

          // Busca funções e cores desses ofícios
          if (oficiosDoProf.isNotEmpty) {
            final oficiosData = await supabase
                .from('oficios')
                .select('funcao, cor')
                .inFilter('id_oficio', oficiosDoProf);

            for (final of in oficiosData) {
              final info = OficioInfo.fromMap(of);
              if (info.funcao.isNotEmpty) oficiosDoUsuario.add(info);
            }
          }
        }

        final termosBusca = <String>[_normalizar(nome)];
        for (final oficio in oficiosDoUsuario) {
          termosBusca.add(_normalizar(oficio.funcao));
        }

        final foto = usuario['foto_perfil_url']?.toString() ?? '';
        final caminhoImagem = (foto.isNotEmpty && foto.toLowerCase() != 'null')
            ? foto
            : '';

        resultados.add(
          _ProfissionalBusca(
            nome: nome,
            idProfissional: idProfissional,
            avaliacao: idProfissional == null
                ? null
                : _mediaAvaliacoes(avaliacoesPorProfissional[idProfissional]),
            totalAvaliacoes:
                avaliacoesPorProfissional[idProfissional]?.length ?? 0,
            tag1: oficiosDoUsuario.isNotEmpty
                ? oficiosDoUsuario.first.funcao
                : 'Profissional',
            tag2: oficiosDoUsuario.length > 1
                ? oficiosDoUsuario[1].funcao
                : null,
            oficios: oficiosDoUsuario,
            descricao: oficiosDoUsuario.isNotEmpty
                ? 'Profissional especializado em ${oficiosDoUsuario.map((o) => o.funcao).join(', ')} na plataforma ConsertaJá.'
                : 'Profissional cadastrado na plataforma ConsertaJá.',
            localizacao: localizacao,
            distancia: '',
            caminhoImagem: caminhoImagem,
            verificado: dadosProfissional?['verificar_autenticacao'] == true,
            isLoja: false,
            tagEmpresa: tagEmpresaRaw.isEmpty
                ? null
                : (tagEmpresaRaw.startsWith('#')
                      ? tagEmpresaRaw
                      : '#$tagEmpresaRaw'),
            tagEmpresaBgColor: tagEmpresaRaw.isEmpty ? null : corEmpresa,
            tagEmpresaTextColor: tagEmpresaRaw.isEmpty
                ? null
                : CorOficio.corTextoContraste(corEmpresa),
            termosBusca: termosBusca,
          ),
        );
      }

      final servicosDb =
          await ServicosProfissionalService.buscarServicosPublicos(termo);
      final servicosEncontrados = servicosDb.map((s) {
        return _ServicoBusca(
          id: s.id,
          servicoOriginal: s.servico,
          titulo: s.titulo,
          codigoTag: s.tagEmpresa,
          categoriaTag: s.categoria,
          logistica: s.tipoExecucao,
          preco: s.preco,
          localizacao: s.localizacao,
          caminhoImagem: s.imagemUrl ?? '',
          termosBusca: [s.titulo, s.categoria, s.tagEmpresa ?? ''],
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _profissionaisSupabase = resultados;
        _empresasSupabase = empresasEncontradas;
        _servicosSupabase = servicosEncontrados;
        _carregandoProfissionais = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Erro ao buscar resultados por "$termo": $e\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _carregandoProfissionais = false;
        _erroNaBusca =
            'Não foi possível consultar os dados agora. Tente novamente.';
      });
    }
  }

  List<_ServicoBusca> get _servicosFiltrados => _servicosSupabase;

  List<_ProfissionalBusca> get _profissionaisFiltrados {
    return [..._profissionaisSupabase, ..._empresasSupabase];
  }

  List<_ProfissionalBusca> get _perfisVerificadosFiltrados =>
      _empresasSupabase.where((empresa) => empresa.verificado).toList();

  double? _mediaAvaliacoes(List<int>? notas) {
    if (notas == null || notas.isEmpty) return null;
    return notas.reduce((total, nota) => total + nota) / notas.length;
  }

  Future<void> _executarBusca([String? termo]) async {
    final texto = (termo ?? _controllerBusca.text).trim();
    if (texto.isEmpty) return;
    _controllerBusca.text = texto;
    setState(() {
      _termoBusca = texto;
      _mostrandoResultados = true;
      _abaAtiva = _AbaResultado.todos;
      _profissionaisSupabase = [];
      _empresasSupabase = [];
      _servicosSupabase = [];
      _erroNaBusca = null;
    });
    _focusBusca.unfocus();
    await _buscarProfissionaisNoSupabase(texto);
  }

  void _voltarParaBusca() {
    setState(() {
      _mostrandoResultados = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusBusca.requestFocus();
    });
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildChip(String categoria) {
    return GestureDetector(
      onTap: () => _executarBusca(categoria),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade400, width: 0.8),
        ),
        child: Text(
          categoria,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: _primaryBlue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 10),
    );
  }

  Widget _buildRatingBadge(double avaliacao) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _ratingBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: _ratingText, size: 12),
          Text(
            ' ${avaliacao.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _ratingText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String texto, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildCabecalhoResultados() {
    return Container(
      color: _primaryBlue,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _voltarParaBusca,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _termoBusca,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.search,
                            color: Colors.grey.shade500,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.radar, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Adicionar Localização',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 18,
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.tune, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    const Text(
                      'Filtros',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 18,
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

  Widget _buildCarrosselPerfisVerificados() {
    final perfis = _perfisVerificadosFiltrados;
    if (perfis.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              const Text(
                'Empresas verificadas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _primaryBlue,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.radar, color: _primaryBlue, size: 18),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: perfis.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _buildCardPerfilVerificado(perfis[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildCardPerfilVerificado(_ProfissionalBusca perfil) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _imagemEhUrl(perfil.caminhoImagem)
                ? Image.network(
                    perfil.caminhoImagem!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: _primaryBlue,
                      child: const Icon(Icons.store, color: Colors.white),
                    ),
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: _primaryBlue,
                    child: const Icon(Icons.store, color: Colors.white),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  perfil.nome,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (perfil.tagEmpresa != null)
                      _buildTag(
                        perfil.tagEmpresa!,
                        const Color(0xFFE1F5FE),
                        _primaryBlue,
                      ),
                    if (perfil.oficios.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      _buildTag(
                        perfil.oficios.first.funcao,
                        const Color(0xFFEEEEEE),
                        const Color(0xFF616161),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${perfil.seguidores} Seguidores',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbas() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          _buildAba('Todos', _AbaResultado.todos),
          _buildAba('Serviços', _AbaResultado.servicos),
          _buildAba('Profissionais', _AbaResultado.profissionais),
        ],
      ),
    );
  }

  Widget _buildAba(String titulo, _AbaResultado aba) {
    final ativa = _abaAtiva == aba;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _abaAtiva = aba),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: ativa
                ? _primaryBlue.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: ativa ? _primaryBlue : Colors.grey.shade200,
                width: ativa ? 2.5 : 1,
              ),
            ),
          ),
          child: Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: ativa ? FontWeight.w600 : FontWeight.w500,
              color: ativa ? _primaryBlue : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholderImagemServico({double height = 140}) {
    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFFEAF4FB),
      child: const Center(
        child: Icon(
          Icons.home_repair_service_rounded,
          color: Color(0xFF0A6E9D),
          size: 40,
        ),
      ),
    );
  }

  Widget _buildCardServico(_ServicoBusca servico) {
    final bool usaImagemRede = _imagemEhUrl(servico.caminhoImagem);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TelaServico(
              idServico: servico.id,
              servicoInicial: servico.servicoOriginal,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: _cardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            usaImagemRede
                ? Image.network(
                    servico.caminhoImagem,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _placeholderImagemServico(height: 140),
                  )
                : (servico.caminhoImagem.isNotEmpty &&
                      !servico.caminhoImagem.contains('panela.png'))
                ? Image.asset(
                    servico.caminhoImagem,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _placeholderImagemServico(height: 140),
                  )
                : _placeholderImagemServico(height: 140),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    servico.titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (servico.codigoTag != null) ...[
                        _buildTag(
                          servico.codigoTag!,
                          const Color(0xFFE1F5FE),
                          _primaryBlue,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Builder(
                        builder: (context) {
                          final corBase = CorOficio.parse(servico.categoriaTag);
                          return _buildTag(
                            servico.categoriaTag,
                            CorOficio.corFundo(corBase),
                            CorOficio.corTexto(corBase),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          servico.logistica,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.local_shipping_outlined,
                        color: _primaryBlue,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'R\$ ${servico.preco.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryBlue,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.location_on_outlined,
                        color: Colors.grey.shade500,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        servico.localizacao,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
    );
  }

  Widget _buildLojaPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Icon(Icons.store, color: Colors.grey.shade600, size: 28),
    );
  }

  Widget _buildCardProfissional(_ProfissionalBusca profissional) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  profissional.isLoja
                      ? (profissional.caminhoImagem != null &&
                                _imagemEhUrl(profissional.caminhoImagem))
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.network(
                                  profissional.caminhoImagem!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildLojaPlaceholder(),
                                ),
                              )
                            : _buildLojaPlaceholder()
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: _imagemEhUrl(profissional.caminhoImagem)
                              ? Image.network(
                                  profissional.caminhoImagem!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 56,
                                    height: 56,
                                    color: const Color(0xFFE1F5FE),
                                    alignment: Alignment.center,
                                    child: Text(
                                      obterIniciais(profissional.nome),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: _primaryBlue,
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  color: const Color(0xFFE1F5FE),
                                  alignment: Alignment.center,
                                  child: Text(
                                    obterIniciais(profissional.nome),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: _primaryBlue,
                                    ),
                                  ),
                                ),
                        ),
                  if (profissional.verificado)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: _buildVerifiedBadge(),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profissional.nome,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (profissional.verificado) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: _primaryBlue,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (profissional.tagEmpresa != null ||
                        profissional.oficios.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (profissional.tagEmpresa != null)
                            _buildTag(
                              profissional.tagEmpresa!,
                              profissional.tagEmpresaBgColor ??
                                  const Color(0xFFE1F5FE),
                              profissional.tagEmpresaTextColor ?? _primaryBlue,
                            ),
                          ...profissional.oficios.map(
                            (oficio) => TagOficio(
                              oficio: oficio,
                              fontSize: 10,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              borderRadius: 20,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          _buildTag(
                            profissional.tag1,
                            const Color(0xFFE1F5FE),
                            _primaryBlue,
                          ),
                          if (profissional.tag2 != null) ...[
                            const SizedBox(width: 6),
                            _buildTag(
                              profissional.tag2!,
                              const Color(0xFFEEEEEE),
                              const Color(0xFF616161),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              if (profissional.avaliacao != null)
                _buildRatingBadge(profissional.avaliacao!),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            profissional.descricao,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: Colors.grey.shade500,
                size: 14,
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  profissional.distancia.isNotEmpty
                      ? '${profissional.localizacao} - ${profissional.distancia}'
                      : profissional.localizacao,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (profissional.isLoja) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PerfilLoja(
                        idGrupoEmpresa: profissional.idGrupoEmpresa,
                        nomeEmpresa: profissional.nome,
                        fotoUrlEmpresa: profissional.caminhoImagem,
                        tagEmpresa: profissional.tagEmpresa,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PerfilProfissionalPage(
                        nomeInicial: profissional.nome,
                        imagemInicial: profissional.caminhoImagem ?? '',
                        profissao: profissional.tag1,
                        avaliacao: profissional.avaliacao,
                        totalAvaliacoes: profissional.totalAvaliacoes,
                        idGrupoEmpresa: profissional.idGrupoEmpresa,
                        idProfissional: profissional.idProfissional,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Ver Perfil',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConteudoResultados() {
    final servicos = _servicosFiltrados;
    final profissionais = _profissionaisFiltrados;

    if (_carregandoProfissionais) {
      return const SkeletonPage(layout: SkeletonLayout.grid);
    }

    if (_erroNaBusca != null) {
      return _buildSemResultados(_erroNaBusca!);
    }

    switch (_abaAtiva) {
      case _AbaResultado.servicos:
        if (servicos.isEmpty) {
          return _buildSemResultados(
            'Nenhum serviço encontrado para "$_termoBusca"',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: servicos.map(_buildCardServico).toList(),
        );

      case _AbaResultado.profissionais:
        if (profissionais.isEmpty) {
          return _buildSemResultados(
            'Nenhum profissional encontrado para "$_termoBusca"',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Profissionais para \'$_termoBusca\'',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Text(
                  '${profissionais.length} encontrados',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...profissionais.map(_buildCardProfissional),
          ],
        );

      case _AbaResultado.todos:
        if (servicos.isEmpty && profissionais.isEmpty) {
          return _buildSemResultados(
            'Nenhum resultado encontrado para "$_termoBusca"',
          );
        }
        final itens = <Widget>[];
        var indiceServico = 0;
        var indiceProfissional = 0;
        while (indiceServico < servicos.length ||
            indiceProfissional < profissionais.length) {
          if (indiceServico < servicos.length) {
            itens.add(_buildCardServico(servicos[indiceServico]));
            indiceServico++;
          }
          if (indiceProfissional < profissionais.length) {
            itens.add(
              _buildCardProfissional(profissionais[indiceProfissional]),
            );
            indiceProfissional++;
          }
        }
        return ListView(padding: const EdgeInsets.all(16), children: itens);
    }
  }

  Widget _buildSemResultados(String mensagem) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildTelaBuscaInicial() {
    return Column(
      children: [
        Container(
          height: MediaQuery.of(context).padding.top,
          color: _primaryBlue,
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back, color: Colors.grey.shade700),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controllerBusca,
                        focusNode: _focusBusca,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _executarBusca,
                        decoration: InputDecoration(
                          hintText: 'Buscar no ConsertaJá',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _executarBusca(),
                      icon: Icon(Icons.search, color: Colors.grey.shade700),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    if (_carregandoCategorias)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      ..._categoriasVisiveis.map(_buildChip),
                  ],
                ),
              ),
              if (_categorias.length > 8)
                TextButton(
                  onPressed: () {
                    setState(
                      () => _mostrarMaisCategorias = !_mostrarMaisCategorias,
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _mostrarMaisCategorias ? 'Ver menos' : 'Ver mais',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        _mostrarMaisCategorias
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        Expanded(child: Container(color: Colors.grey.shade100)),
      ],
    );
  }

  Widget _buildTelaResultados() {
    return Column(
      children: [
        Container(
          height: MediaQuery.of(context).padding.top,
          color: _primaryBlue,
        ),
        _buildCabecalhoResultados(),
        Expanded(
          child: Container(
            color: Colors.grey.shade100,
            child: Column(
              children: [
                _buildCarrosselPerfisVerificados(),
                _buildAbas(),
                Expanded(child: _buildConteudoResultados()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackHandler(
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: _mostrandoResultados
            ? _buildTelaResultados()
            : _buildTelaBuscaInicial(),
        bottomNavigationBar: _mostrandoResultados
            ? BottomNavigationBarCliente(
                currentIndex: 0,
                onTap: (index) {
                  if (index == 0) {
                    AppNavigationUtil.navegarAba(
                      context,
                      TelaHome(isVisitante: widget.isVisitante),
                      isHome: true,
                    );
                  } else if (index == 1) {
                    AppNavigationUtil.navegarAba(
                      context,
                      SeguindoClientePage(isVisitante: widget.isVisitante),
                      isHome: false,
                    );
                  } else if (index == 3) {
                    AppNavigationUtil.navegarAba(
                      context,
                      MeusPedidosPage(isVisitante: widget.isVisitante),
                      isHome: false,
                    );
                  } else if (index == 4) {
                    AppNavigationUtil.navegarAba(
                      context,
                      TelaMeuPerfilClientePage(isVisitante: widget.isVisitante),
                      isHome: false,
                    );
                  }
                },
              )
            : null,
      ),
    );
  }
}
