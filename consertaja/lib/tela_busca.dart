import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'perfil_profissional.dart';
import 'tela_meu_perfil_cliente.dart';
import 'utils/bottom_navigation_bar_cliente.dart';
import 'utils/cor_oficio.dart';
import 'utils/iniciais.dart';
import 'widgets/tag_oficio.dart';

enum _AbaResultado { todos, servicos, profissionais }

class _ServicoBusca {
  final String titulo;
  final String codigoTag;
  final String categoriaTag;
  final String logistica;
  final double preco;
  final String localizacao;
  final String caminhoImagem;
  final List<String> termosBusca;

  const _ServicoBusca({
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
  final double avaliacao;
  final String tag1;
  final String? tag2;
  final List<OficioInfo> oficios;
  final String descricao;
  final String localizacao;
  final String distancia;
  final String? caminhoImagem;
  final bool verificado;
  final bool isLoja;
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
    this.verificado = true,
    this.isLoja = false,
    required this.termosBusca,
  });
}

class _PerfilVerificado {
  final String nome;
  final String codigoTag;
  final String categoriaTag;
  final int seguidores;
  final String caminhoImagem;
  final List<String> termosBusca;

  const _PerfilVerificado({
    required this.nome,
    required this.codigoTag,
    required this.categoriaTag,
    required this.seguidores,
    required this.caminhoImagem,
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
  bool _carregandoProfissionais = false;
  bool _erroNaBusca = false;

  static const List<String> _categoriasIniciais = [
    'Costura',
    'Chaveiro',
    'Tapeçaria',
    'Soldagem',
    'Panelas',
    'Vidraçaria',
    'Serralheria',
    'Sapataria',
  ];

  static const List<String> _categoriasExtras = [
    'Eletricista',
    'Encanador',
    'Pintura',
    'Limpeza',
    'Marcenaria',
    'Informática',
    'Jardinagem',
    'Refrigeração',
  ];

  static const List<_ServicoBusca> _todosServicos = [
    _ServicoBusca(
      titulo: 'Conserto de cabo de panela',
      codigoTag: '#CAEDS',
      categoriaTag: 'Panelas',
      logistica: 'Entregue em até 5 dias - Retirada',
      preco: 18.99,
      localizacao: 'Estrada das Lágrima',
      caminhoImagem: 'assets/images/panela.png',
      termosBusca: [
        'conserto',
        'cabo',
        'panela',
        'panelas',
        'caeds',
        'elétrica',
        'eletrica',
      ],
    ),
    _ServicoBusca(
      titulo: 'Solda em panela de pressão',
      codigoTag: '#SOLDAMAX',
      categoriaTag: 'Pressão',
      logistica: 'Entregue em até 3 dias - Leva e Traz',
      preco: 45.00,
      localizacao: 'Vila Mariana',
      caminhoImagem: 'assets/images/panela.png',
      termosBusca: [
        'solda',
        'panela',
        'pressão',
        'pressao',
        'soldamax',
        'panelas',
      ],
    ),
    _ServicoBusca(
      titulo: 'Polimento e troca de cabo',
      codigoTag: '#POLMAX',
      categoriaTag: 'Panelas',
      logistica: 'Pronto em 24h - Leva e Traz',
      preco: 25.50,
      localizacao: 'Ipiranga',
      caminhoImagem: 'assets/images/panela.png',
      termosBusca: [
        'polimento',
        'cabo',
        'troca',
        'panela',
        'panelas',
        'utensílios',
        'utensilios',
      ],
    ),
  ];

  static const List<_ProfissionalBusca> _todosProfissionais = [
    _ProfissionalBusca(
      nome: 'João Silva',
      avaliacao: 4.9,
      tag1: 'Eletricista',
      tag2: 'Panelas',
      descricao:
          'Especialista em conserto de panelas elétricas e cabos em geral. Atendimento rápido e garantia.',
      localizacao: 'Vila Mariana',
      distancia: '2.5km',
      caminhoImagem: '',
      termosBusca: [
        'joão',
        'joao',
        'silva',
        'eletricista',
        'panela',
        'panelas',
        'cabo',
        'conserto',
      ],
    ),
    _ProfissionalBusca(
      nome: 'Maria Oliveira',
      avaliacao: 4.7,
      tag1: 'Utensílios',
      descricao:
          'Profissional experiente em restauração e conserto de utensílios domésticos e panelas.',
      localizacao: 'Moema',
      distancia: '4.1km',
      caminhoImagem: '',
      termosBusca: [
        'maria',
        'oliveira',
        'utensílios',
        'utensilios',
        'panela',
        'panelas',
        'cabo',
        'conserto',
      ],
    ),
    _ProfissionalBusca(
      nome: 'Conserta Tudo Express',
      avaliacao: 4.5,
      tag1: 'Assistência Técnica',
      descricao:
          'Assistência técnica completa para eletrodomésticos e utensílios. Retirada e entrega.',
      localizacao: 'Sacomã',
      distancia: '5.0km',
      isLoja: true,
      termosBusca: [
        'conserta',
        'assistência',
        'assistencia',
        'técnica',
        'tecnica',
        'panela',
        'panelas',
        'cabo',
        'conserto',
      ],
    ),
  ];

  static const List<_PerfilVerificado> _perfisVerificados = [
    _PerfilVerificado(
      nome: 'Mundo das Louças',
      codigoTag: '#MUNLO',
      categoriaTag: 'Panelas',
      seguidores: 324,
      caminhoImagem: 'assets/images/loja_mundo_loucas.png',
      termosBusca: [
        'mundo',
        'louças',
        'loucas',
        'panela',
        'panelas',
        'cabo',
        'conserto',
      ],
    ),
    _PerfilVerificado(
      nome: 'Caedss - Estrada das Lágrimas',
      codigoTag: '#CAEDS',
      categoriaTag: 'Panelas',
      seguidores: 923,
      caminhoImagem: 'assets/images/loja_caedss.png',
      termosBusca: [
        'caedss',
        'panela',
        'panelas',
        'cabo',
        'conserto',
        'lágrimas',
        'lagrimas',
      ],
    ),
    _PerfilVerificado(
      nome: 'Chaveiro - Ipiranga',
      codigoTag: '#CHAVE',
      categoriaTag: 'Chaveiro',
      seguidores: 252,
      caminhoImagem: 'assets/images/loja_chaveiro.png',
      termosBusca: ['chaveiro', 'ipiranga', 'chave'],
    ),
  ];

  @override
  void initState() {
    super.initState();
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

  List<String> get _categoriasVisiveis => _mostrarMaisCategorias
      ? [..._categoriasIniciais, ..._categoriasExtras]
      : _categoriasIniciais;

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
      _erroNaBusca = false;
    });

    try {
      final supabase = Supabase.instance.client;

      // 1) Busca profissionais por NOME na tabela usuarios (sem joins)
      final usuariosPorNome = await supabase
          .from('usuarios')
          .select('id_usuario, nome, foto_perfil_url')
          .eq('tipo_conta', 'Profissional')
          .ilike('nome', '%$termo%');

      // 2) Busca ofícios (profissão) equivalentes ao termo
      final oficiosEncontrados = await supabase
          .from('oficios')
          .select('id_oficio, funcao, cor')
          .ilike('funcao', '%$termo%');

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
      }

      // 4) Busca ids_profissional por fk_usuario (para todos os usuários encontrados)
      Map<int, int> usuarioParaProfissional = {};

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
            .select('id_profissional, fk_usuario')
            .inFilter('id_profissional', oficiosPorProfissional.keys.toList());

        for (final dp in dadosProfPorOficio) {
          final idProf = (dp['id_profissional'] as num?)?.toInt();
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
            .select('id_profissional, fk_usuario')
            .inFilter('fk_usuario', idsUsuariosRelevantes.toList());

        for (final dp in dadosProfissionais) {
          final idProf = (dp['id_profissional'] as num?)?.toInt();
          final idUsuario = (dp['fk_usuario'] as num?)?.toInt();
          if (idProf != null && idUsuario != null) {
            usuarioParaProfissional[idUsuario] = idProf;
          }
        }
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

      // 5) Busca endereços ativos para todos os usuários encontrados
      final Map<int, String> localizacaoPorUsuario = {};

      if (usuariosEncontrados.isNotEmpty) {
        final idsUsuarios = usuariosEncontrados.keys.toList();

        // Busca associações de endereço ativas
        final assEnderecos = await supabase
            .from('ass_usuario_endereco')
            .select('fk_usuario, fk_endereco')
            .inFilter('fk_usuario', idsUsuarios)
            .eq('endereco_ativo', true);

        if (assEnderecos.isNotEmpty) {
          // Mapa de fk_usuario -> fk_endereco
          final Map<int, int> enderecoPorUsuario = {};
          final idEnderecos = <int>[];

          for (final ass in assEnderecos) {
            final fkUsuario = ass['fk_usuario'];
            final fkEndereco = ass['fk_endereco'];
            final idUsuario = fkUsuario is int
                ? fkUsuario
                : int.tryParse(fkUsuario?.toString() ?? '');
            final idEndereco = fkEndereco is int
                ? fkEndereco
                : int.tryParse(fkEndereco?.toString() ?? '');
            if (idUsuario != null && idEndereco != null) {
              enderecoPorUsuario[idUsuario] = idEndereco;
              idEnderecos.add(idEndereco);
            }
          }

          if (idEnderecos.isNotEmpty) {
            // Busca endereços
            final enderecosResp = await supabase
                .from('enderecos')
                .select(
                  'id_endereco, logradouro, numero, complemento, fk_cidade',
                )
                .inFilter('id_endereco', idEnderecos);

            // Busca cidades
            final cidadesResp = await supabase
                .from('cidades')
                .select('id_cidade, nome_cidade, fk_estado');

            // Busca estados
            final estadosResp = await supabase
                .from('estados')
                .select('id_estado, sigla_estado');

            // Mapas auxiliares
            final Map<int, Map<String, dynamic>> cidadesMap = {};
            for (final c in cidadesResp) {
              final fk = c['id_cidade'];
              final id = fk is int ? fk : int.tryParse(fk?.toString() ?? '');
              if (id != null) cidadesMap[id] = Map<String, dynamic>.from(c);
            }

            final Map<int, String> estadosMap = {};
            for (final e in estadosResp) {
              final fk = e['id_estado'];
              final id = fk is int ? fk : int.tryParse(fk?.toString() ?? '');
              if (id != null)
                estadosMap[id] = e['sigla_estado']?.toString() ?? '';
            }

            // Mapa de id_endereco -> dados do endereço
            final Map<int, Map<String, dynamic>> enderecosMap = {};
            for (final e in enderecosResp) {
              final fk = e['id_endereco'];
              final id = fk is int ? fk : int.tryParse(fk?.toString() ?? '');
              if (id != null) enderecosMap[id] = Map<String, dynamic>.from(e);
            }

            // Construye localização para cada usuário
            for (final entry in enderecoPorUsuario.entries) {
              final idUsuario = entry.key;
              final idEndereco = entry.value;
              final endereco = enderecosMap[idEndereco];
              if (endereco == null) continue;

              final logradouro = endereco['logradouro']?.toString() ?? '';
              final numero = endereco['numero']?.toString() ?? '';
              final complemento = endereco['complemento']?.toString() ?? '';
              final fkCidade = endereco['fk_cidade'];
              final idCidade = fkCidade is int
                  ? fkCidade
                  : int.tryParse(fkCidade?.toString() ?? '');

              final cidadeInfo = idCidade != null ? cidadesMap[idCidade] : null;
              final cidade = cidadeInfo?['nome_cidade']?.toString() ?? '';

              final fkEstado = cidadeInfo?['fk_estado'];
              final idEstado = fkEstado is int
                  ? fkEstado
                  : int.tryParse(fkEstado?.toString() ?? '');
              final estado = idEstado != null ? estadosMap[idEstado] ?? '' : '';

              final partes = <String>[];
              if (logradouro.isNotEmpty) {
                partes.add(
                  numero.isNotEmpty ? '$logradouro, $numero' : logradouro,
                );
              }
              if (complemento.isNotEmpty) {
                partes.add(complemento);
              }
              if (cidade.isNotEmpty) {
                partes.add(estado.isNotEmpty ? '$cidade - $estado' : cidade);
              }
              localizacaoPorUsuario[idUsuario] = partes.join(', ');
            }
          }
        }
      }

      // 6) Para cada usuário encontrado, busca ofícios
      final resultados = <_ProfissionalBusca>[];

      for (final entry in usuariosEncontrados.entries) {
        final usuarioId = entry.key;
        final usuario = entry.value;
        final nome = usuario['nome']?.toString() ?? '';
        if (nome.trim().isEmpty) continue;

        final String localizacao =
            localizacaoPorUsuario[usuarioId] ?? 'Localização não informada';

        // Ofícios do profissional (via dados_profissionais + ass_oficio_profissional + oficios)
        final idProfissional = usuarioParaProfissional[usuarioId];

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
            avaliacao: 4.9,
            tag1: oficiosDoUsuario.isNotEmpty
                ? oficiosDoUsuario.first.funcao
                : 'Profissional',
            tag2: oficiosDoUsuario.length > 1
                ? oficiosDoUsuario[1].funcao
                : null,
            oficios: oficiosDoUsuario,
            descricao: oficiosDoUsuario.isNotEmpty
                ? 'Profissional especializado em ${oficiosDoUsuario.map((o) => o.funcao).join(', ')} na plataforma ConsertaJá.'
                : 'Profissional verificado na plataforma ConsertaJá.',
            localizacao: localizacao,
            distancia: '',
            caminhoImagem: caminhoImagem,
            verificado: true,
            isLoja: false,
            termosBusca: termosBusca,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _profissionaisSupabase = resultados;
        _carregandoProfissionais = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _carregandoProfissionais = false;
        _erroNaBusca = true;
      });
    }
  }

  List<_ServicoBusca> get _servicosFiltrados {
    return _todosServicos
        .where((s) => _correspondeBusca(s.termosBusca, _termoBusca))
        .toList();
  }

  List<_ProfissionalBusca> get _profissionaisFiltrados {
    if (_profissionaisSupabase.isNotEmpty) {
      return _profissionaisSupabase;
    }
    return _todosProfissionais
        .where((p) => _correspondeBusca(p.termosBusca, _termoBusca))
        .toList();
  }

  List<_PerfilVerificado> get _perfisVerificadosFiltrados {
    return _perfisVerificados
        .where((p) => _correspondeBusca(p.termosBusca, _termoBusca))
        .toList();
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
            ' $avaliacao',
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
                'Perfis Verificados Perto de Você',
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

  Widget _buildCardPerfilVerificado(_PerfilVerificado perfil) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              perfil.caminhoImagem,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                color: _primaryBlue,
                child: const Icon(Icons.store, color: Colors.white),
              ),
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
                    _buildTag(
                      perfil.codigoTag,
                      const Color(0xFFE1F5FE),
                      _primaryBlue,
                    ),
                    const SizedBox(width: 4),
                    _buildTag(
                      perfil.categoriaTag,
                      const Color(0xFFEEEEEE),
                      const Color(0xFF616161),
                    ),
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

  Widget _buildCardServico(_ServicoBusca servico) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            servico.caminhoImagem,
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 140,
              color: Colors.grey.shade200,
              child: Icon(Icons.image, color: Colors.grey.shade400, size: 40),
            ),
          ),
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
                    _buildTag(
                      servico.codigoTag,
                      const Color(0xFFE1F5FE),
                      _primaryBlue,
                    ),
                    const SizedBox(width: 6),
                    _buildTag(
                      servico.categoriaTag,
                      const Color(0xFFEEEEEE),
                      const Color(0xFF616161),
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
                      ? Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(
                            Icons.store,
                            color: Colors.grey.shade600,
                            size: 28,
                          ),
                        )
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
                    if (profissional.oficios.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: profissional.oficios
                            .map(
                              (oficio) => TagOficio(
                                oficio: oficio,
                                fontSize: 10,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                borderRadius: 20,
                              ),
                            )
                            .toList(),
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
              _buildRatingBadge(profissional.avaliacao),
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
                if (!profissional.isLoja) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PerfilProfissionalPage(
                        nomeInicial: profissional.nome,
                        imagemInicial: profissional.caminhoImagem ?? '',
                        profissao: profissional.tag1,
                        avaliacao: profissional.avaliacao,
                        totalAvaliacoes: 120,
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
      return const Center(
        child: CircularProgressIndicator(color: _primaryBlue),
      );
    }

    if (_erroNaBusca && profissionais.isEmpty) {
      return _buildSemResultados(
        'Não foi possível buscar profissionais agora. Tente novamente.',
      );
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
                  children: _categoriasVisiveis.map(_buildChip).toList(),
                ),
              ),
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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _mostrandoResultados
          ? _buildTelaResultados()
          : _buildTelaBuscaInicial(),
      bottomNavigationBar: _mostrandoResultados
          ? BottomNavigationBarCliente(
              currentIndex: 0,
              onTap: (index) {
                if (index == 0) {
                  Navigator.pop(context);
                } else if (index == 4) {
                  Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      pageBuilder: (_, _, _) => TelaMeuPerfilClientePage(
                        isVisitante: widget.isVisitante,
                      ),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                }
              },
            )
          : null,
    );
  }
}
