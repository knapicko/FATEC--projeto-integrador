import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/servico_profissional.dart';
import 'perfil_profissional.dart';
import 'services/servicos_profissional_service.dart';
import 'tela_servico.dart';
import 'utils/cor_oficio.dart';
import 'utils/iniciais.dart';
import 'widgets/tag_oficio.dart';

class PerfilLoja extends StatefulWidget {
  final int? idGrupoEmpresa;
  final String? nomeEmpresa;
  final String? fotoUrlEmpresa;
  final String? bannerUrlEmpresa;
  final String? tagEmpresa;
  final String? corTagEmpresa;

  const PerfilLoja({
    super.key,
    this.idGrupoEmpresa,
    this.nomeEmpresa,
    this.fotoUrlEmpresa,
    this.bannerUrlEmpresa,
    this.tagEmpresa,
    this.corTagEmpresa,
  });

  @override
  State<PerfilLoja> createState() => _PerfilLojaState();
}

class _PerfilLojaState extends State<PerfilLoja> {
  int? _idGrupoEmpresa;
  String _nomeEmpresa = 'Caedss - Estrada das Lágrimas';
  String? _fotoUrlEmpresa;
  String? _bannerUrlEmpresa;
  String? _tagEmpresa = '#CAEDS';
  Color? _corTagEmpresa = const Color(0xFF0288D1);

  bool _carregandoProfissionais = true;
  List<Map<String, dynamic>> listaProfissionais = [];
  bool _carregandoServicos = true;
  List<ServicoProfissional> _servicosLoja = [];
  String _abaAtiva = 'Serviços';
  String _filtroServicos = '';

  String filtroComentario = 'Principais';
  bool isDescricaoExpandida = false;

  // Estados para controle dinâmico de cliques nos corações da seção de avaliações
  int likesComentario1 = 0;
  bool likedComentario1 = false;

  int likesComentario2 = 1;
  bool likedComentario2 = true;

  @override
  void initState() {
    super.initState();
    _idGrupoEmpresa = widget.idGrupoEmpresa;
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
    _carregarDadosEmpresaEProfissionais();
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
                'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa, fk_perfil',
              )
              .ilike('tag_empresa', '%$cleanTag%')
              .maybeSingle();
          grupoEncontrado = res;
        }
        if (grupoEncontrado == null && _nomeEmpresa.isNotEmpty) {
          final res = await supabase
              .from('grupo_empresa')
              .select(
                'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa, fk_perfil',
              )
              .ilike('nome_empresa', '%$_nomeEmpresa%')
              .maybeSingle();
          grupoEncontrado = res;
        }
        if (grupoEncontrado == null) {
          final list = await supabase
              .from('grupo_empresa')
              .select(
                'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa, fk_perfil',
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
              'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa, fk_perfil',
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

          setState(() {
            if (nome != null && nome.isNotEmpty) _nomeEmpresa = nome;
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
          });
        }
      }

      // Carrega serviços da empresa
      List<ServicoProfissional> servicos = [];
      if (idGrupo != null) {
        try {
          servicos = await ServicosProfissionalService.buscarServicosEmpresa(idGrupo);
        } catch (e) {
          debugPrint('Erro ao carregar serviços da empresa: $e');
        }
      }

      // Se a loja não tiver serviços cadastrados no banco, provê catálogo padrão para exibição
      if (servicos.isEmpty) {
        servicos = _gerarServicosPadraoLoja(idGrupo);
      }

      if (mounted) {
        setState(() {
          _servicosLoja = servicos;
          _carregandoServicos = false;
        });
      }

      // Carrega lista de profissionais da empresa (Proprietário + Membros)
      final List<Map<String, dynamic>> novosProfissionais = [];
      final Set<int> idsProfissionaisAdicionados = {};

      // 1. Carrega Proprietário (fk_perfil vinculado ao grupo_empresa)
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

            if (fkUsuario != null && idProfDono != null) {
              idsProfissionaisAdicionados.add(idProfDono);

              final usuarioDono = await supabase
                  .from('usuarios')
                  .select('nome, foto_perfil_url')
                  .eq('id_usuario', fkUsuario)
                  .maybeSingle();

              final nomeDono =
                  usuarioDono?['nome']?.toString().trim() ?? 'Proprietário';
              final fotoDono =
                  usuarioDono?['foto_perfil_url']?.toString().trim() ?? '';

              final List<OficioInfo> oficiosDono = [];
                if (_idGrupoEmpresa != null) {
                final assOficios = await supabase
                  .from('ass_oficio_grupo_empresa')
                  .select('fk_oficio')
                  .eq('fk_grupo_empresa', _idGrupoEmpresa!);
                final idsOficios = assOficios
                  .map((e) => e['fk_oficio'])
                  .whereType<num>()
                  .map((e) => e.toInt())
                  .toList();
                final oficiosData = await supabase
                    .from('oficios')
                  .select('funcao, categoria, cor')
                    .inFilter('id_oficio', idsOficios);
                for (final row in oficiosData) {
                  final info = OficioInfo.fromMap(row);
                  if (info.funcao.isNotEmpty) oficiosDono.add(info);
                }
              }

              final oficioPrincipal =
                  oficiosDono.isNotEmpty ? oficiosDono.first : null;

              final corBase = oficioPrincipal != null
                  ? CorOficio.parse(oficioPrincipal.cor)
                  : const Color(0xFF0288D1);

              novosProfissionais.add({
                'idProfissional': idProfDono,
                'nome': nomeDono,
                'avaliacao': 5.0,
                'totalAvaliacoes': 120,
                'oficios': oficiosDono,
                'tag': oficioPrincipal?.funcao.isNotEmpty == true
                    ? oficioPrincipal!.funcao
                    : 'Proprietário',
                'tagBgColor': CorOficio.corFundo(corBase),
                'tagTextColor': CorOficio.corTexto(corBase),
                'caminhoImagem': fotoDono,
                'profissao': oficioPrincipal?.funcao.isNotEmpty == true
                    ? oficioPrincipal!.funcao
                    : 'Proprietário',
              });
            }
          }
        } catch (e) {
          debugPrint('Erro ao carregar proprietário da empresa: $e');
        }
      }

      // 2. Carrega Membros ativos (dados_profissionais com fk_grupo_empresa)
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

            final List<OficioInfo> oficiosMembro = [];
            if (_idGrupoEmpresa != null) {
              final assOficios = await supabase
                .from('ass_oficio_grupo_empresa')
                .select('fk_oficio')
                .eq('fk_grupo_empresa', _idGrupoEmpresa!);
              final idsOficios = assOficios
                .map((e) => e['fk_oficio'])
                .whereType<num>()
                .map((e) => e.toInt())
                .toList();
              final oficiosData = await supabase
                  .from('oficios')
                .select('funcao, categoria, cor')
                  .inFilter('id_oficio', idsOficios);
              for (final row in oficiosData) {
                final info = OficioInfo.fromMap(row);
                if (info.funcao.isNotEmpty) oficiosMembro.add(info);
              }
            }

            final oficioPrincipal =
                oficiosMembro.isNotEmpty ? oficiosMembro.first : null;

            final corBase = oficioPrincipal != null
                ? CorOficio.parse(oficioPrincipal.cor)
                : const Color(0xFF0288D1);

            novosProfissionais.add({
              'idProfissional': idProf,
              'nome': nome,
              'avaliacao': 4.9,
              'totalAvaliacoes': 120,
              'oficios': oficiosMembro,
              'tag': oficioPrincipal?.funcao.isNotEmpty == true
                  ? oficioPrincipal!.funcao
                  : 'Profissional',
              'tagBgColor': CorOficio.corFundo(corBase),
              'tagTextColor': CorOficio.corTexto(corBase),
              'caminhoImagem': foto,
              'profissao': oficioPrincipal?.funcao.isNotEmpty == true
                  ? oficioPrincipal!.funcao
                  : 'Profissional',
            });
          }
        } catch (e) {
          debugPrint('Erro ao carregar membros da empresa: $e');
        }
      }

      if (novosProfissionais.isEmpty) {
        novosProfissionais.addAll(_gerarProfissionaisPadraoLoja());
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
        setState(() => _carregandoProfissionais = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usaBannerRede =
        _bannerUrlEmpresa != null &&
        _bannerUrlEmpresa!.isNotEmpty &&
        (_bannerUrlEmpresa!.startsWith('http://') ||
            _bannerUrlEmpresa!.startsWith('https://'));

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // BANNER E CONTROLES DE TOPO
            // ==========================================
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF115F80), // Cor especificada do Banner
                    image: usaBannerRede
                        ? DecorationImage(
                            image: NetworkImage(_bannerUrlEmpresa!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                // FOTO DA LOJA SOBREPOSTA COM SELO E TAG EMBUTIDAS
                Positioned(
                  bottom: -35,
                  left: 16,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: _buildFotoLoja(),
                        ),
                      ),
                      // Símbolo de verificado no canto superior esquerdo
                      const Positioned(
                        top: -4,
                        left: -4,
                        child: Icon(
                          Icons.verified,
                          color: Color(0xFF00A3FF),
                          size: 18,
                        ),
                      ),
                      // Tag da empresa embutida no canto inferior direito
                      if (_tagEmpresa != null && _tagEmpresa!.isNotEmpty)
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _corTagEmpresa != null
                                  ? _corTagEmpresa!
                                  : const Color(0xFFE1F5FE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _tagEmpresa!,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: _corTagEmpresa != null
                                    ? CorOficio.corTextoContraste(_corTagEmpresa!)
                                    : const Color(0xFF0288D1),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 45,
            ), // Alinhamento para compensar a foto flutuante

            // ==========================================
            // DETALHES DE INFORMAÇÃO DA LOJA
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nomeEmpresa,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        'Aberta até 20h',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.star,
                        color: Color(0xFF00A3FF),
                        size: 13,
                      ),
                      const SizedBox(width: 2),
                      const Text(
                        '5.0 (923)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Badge de Perfil Verificado na mesma row
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              color: Color(0xFF00A3FF),
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Perfil Verificado',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00A3FF),
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
            const SizedBox(height: 16),

            // BARRA DE PESQUISA CENTRALIZADA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _filtroServicos = val.trim().toLowerCase();
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Buscar serviços',
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey,
                      size: 20,
                    ),
                    suffixIcon: Icon(
                      Icons.tune,
                      color: Color(0xFF00A3FF),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ROW COM NAVEGAÇÃO DE TABS (Serviços, Profissionais, Avaliações e Detalhes)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTabButton('Serviços', _abaAtiva == 'Serviços', () {
                    setState(() => _abaAtiva = 'Serviços');
                  }),
                  _buildTabButton('Profissionais', _abaAtiva == 'Profissionais', () {
                    setState(() => _abaAtiva = 'Profissionais');
                  }),
                  _buildTabButton('Avaliações', _abaAtiva == 'Avaliações', () {
                    setState(() => _abaAtiva = 'Avaliações');
                  }),
                  _buildTabButton('Detalhes', _abaAtiva == 'Detalhes', () {
                    setState(() => _abaAtiva = 'Detalhes');
                  }),
                ],
              ),
            ),
            const Divider(height: 24, thickness: 1),

            // ==========================================
            // SEÇÃO: SERVIÇOS OFERECIDOS PELA LOJA
            // ==========================================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Serviços Oferecidos',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final servicosExibidos = _filtroServicos.isEmpty
                    ? _servicosLoja
                    : _servicosLoja.where((s) {
                        final t = s.titulo.toLowerCase();
                        final d = (s.descricao ?? '').toLowerCase();
                        final f = (s.funcao ?? '').toLowerCase();
                        return t.contains(_filtroServicos) ||
                            d.contains(_filtroServicos) ||
                            f.contains(_filtroServicos);
                      }).toList();

                if (_carregandoServicos) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF00A3FF)),
                    ),
                  );
                } else if (servicosExibidos.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      _filtroServicos.isNotEmpty
                          ? 'Nenhum serviço encontrado para "$_filtroServicos".'
                          : 'Nenhum serviço cadastrado para esta loja no momento.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                } else {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: servicosExibidos
                          .map((servico) => _buildCardServicoLoja(servico))
                          .toList(),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),

            // ==========================================
            // SEÇÃO: PROFISSIONAIS
            // ==========================================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Profissionais',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_carregandoProfissionais)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00A3FF)),
                ),
              )
            else if (listaProfissionais.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Nenhum profissional vinculado a esta empresa no momento.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: listaProfissionais
                      .map((p) => _buildCardProfissional(p))
                      .toList(),
                ),
              ),
            const SizedBox(height: 20),

            // ==========================================
            // SEÇÃO: AVALIAÇÕES
            // ==========================================
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.star, color: Color(0xFF00A3FF), size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Avaliações da loja',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '(923)',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Container de Resumo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut id dui eu lectus varius pretium ac vel erat. Cras sed sollicitudin sem.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filtros clicáveis de Comentário
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildFiltroComentario('Principais'),
                  const SizedBox(width: 8),
                  _buildFiltroComentario('Recentes'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Comentário 1: Luiz Fernando
            _buildComentarioItem(
              nome: 'Luiz Fernando',
              nota: 4.5,
              tempo: 'há 8 dias',
              texto: 'Muito bom',
              liked: likedComentario1,
              likes: likesComentario1,
              onLikeTap: () {
                setState(() {
                  likedComentario1 = !likedComentario1;
                  likesComentario1 += likedComentario1 ? 1 : -1;
                });
              },
            ),

            // Comentário 2: Kauã Andrade
            _buildComentarioItem(
              nome: 'Kauã Andrade',
              nota: 0.5,
              tempo: 'há 8 dias',
              texto: 'Arrebentaram o cabo da minha panela',
              liked: likedComentario2,
              likes: likesComentario2,
              onLikeTap: () {
                setState(() {
                  likedComentario2 = !likedComentario2;
                  likesComentario2 += likedComentario2 ? 1 : -1;
                });
              },
            ),
            const SizedBox(height: 20),

            // ==========================================
            // SEÇÃO: DETALHES (DESCRIÇÃO COM EXPANSÃO)
            // ==========================================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Descrição',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Divider(height: 16, thickness: 1),
                    Text(
                      isDescricaoExpandida
                          ? 'A Caedss Acessórios é uma loja localizada na Estrada das Lágrimas, em São Paulo, especializada em acessórios e tecnologia para celulares. A empresa oferece produtos modernos e soluções práticas para quem busca qualidade, inovação e atendimento personalizado no segmento de tecnologia móvel.\nLorem Ipsum Lorem IpsumLorem IpsumLorem \n\nAAAAAA Texto aumentadoaumentadoaumentadoaumentadoaumentadoaumentado aumentadoaumentadoaumentadoaumentado'
                          : 'A Caedss Acessórios é uma loja localizada na Estrada das Lágrimas, em São Paulo, especializada em acessórios e tecnologia para celulares. A empresa oferece produtos modernos e soluções práticas para quem busca qualidade, inovação e atendimento personalizado no segmento de tecnologia móvel.\nLorem Ipsum Lorem IpsumLorem IpsumLorem ',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
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
                                color: Color(0xFF00A3FF),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              isDescricaoExpandida
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: const Color(0xFF00A3FF),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFotoLoja() {
    final bool usaImagemRede =
        _fotoUrlEmpresa != null &&
        _fotoUrlEmpresa!.isNotEmpty &&
        (_fotoUrlEmpresa!.startsWith('http://') ||
            _fotoUrlEmpresa!.startsWith('https://'));

    if (usaImagemRede) {
      return Image.network(
        _fotoUrlEmpresa!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildAvatarIniciaisLoja(),
      );
    } else if (_fotoUrlEmpresa != null &&
        _fotoUrlEmpresa!.isNotEmpty &&
        _fotoUrlEmpresa!.startsWith('assets/')) {
      return Image.asset(
        _fotoUrlEmpresa!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildAvatarIniciaisLoja(),
      );
    } else {
      return _buildAvatarIniciaisLoja();
    }
  }

  Widget _buildAvatarIniciaisLoja() {
    return Container(
      color: const Color(0xFFE1F5FE),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(_nomeEmpresa),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF00A3FF),
        ),
      ),
    );
  }

  Widget _buildTabButton(String titulo, bool isActive, [VoidCallback? onTap]) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isActive ? const Color(0xFF00A3FF) : Colors.grey,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 4),
            Container(width: 40, height: 2, color: const Color(0xFF00A3FF)),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltroComentario(String texto) {
    bool isSelected = filtroComentario == texto;
    return GestureDetector(
      onTap: () {
        setState(() {
          filtroComentario = texto;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE3F2FD) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF00A3FF) : Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00A3FF) : Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildChipsOficios(Map<String, dynamic> perfil) {
    final oficios = perfil['oficios'];
    if (oficios is List && oficios.isNotEmpty) {
      return Wrap(
        spacing: 4,
        runSpacing: 4,
        children: oficios.map((o) {
          final OficioInfo info = o is OficioInfo
              ? o
              : OficioInfo.fromMap(Map<String, dynamic>.from(o));
          return TagOficio(
            oficio: info,
            fontSize: 9,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            borderRadius: 12,
          );
        }).toList(),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: perfil['tagBgColor'] ?? const Color(0xFFE1F5FE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        perfil['tag']?.toString() ?? 'Profissional',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: perfil['tagTextColor'] ?? const Color(0xFF0288D1),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCardProfissional(Map<String, dynamic> perfil) {
    final nome = perfil['nome']?.toString().trim() ?? 'Nome não encontrado';
    final foto =
        perfil['caminhoImagem']?.toString().trim() ??
        perfil['foto']?.toString().trim() ??
        '';
    final bool usaFotoRede =
        foto.startsWith('http://') || foto.startsWith('https://');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PerfilProfissionalPage(
              nomeInicial: nome,
              imagemInicial: foto,
              profissao:
                  perfil['profissao']?.toString() ??
                  perfil['tag']?.toString() ??
                  'Profissional independente',
              avaliacao: (perfil['avaliacao'] as num?)?.toDouble() ?? 4.9,
              totalAvaliacoes:
                  (perfil['totalAvaliacoes'] as num?)?.toInt() ?? 120,
              idGrupoEmpresa: _idGrupoEmpresa,
              idProfissional: (perfil['idProfissional'] as num?)?.toInt(),
            ),
          ),
        );
      },
      child: Container(
        width: 135,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFFE1F5FE),
                backgroundImage: usaFotoRede ? NetworkImage(foto) : null,
                child: !usaFotoRede
                    ? Text(
                        obterIniciais(nome),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00A3FF),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              nome,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFF00A3FF), size: 11),
                const SizedBox(width: 2),
                Text(
                  '${perfil['avaliacao'] ?? 4.9}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  '(${perfil['totalAvaliacoes'] ?? 120})',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildChipsOficios(perfil),
          ],
        ),
      ),
    );
  }

  List<ServicoProfissional> _gerarServicosPadraoLoja(int? idGrupo) {
    return [
      ServicoProfissional(
        id: 9001,
        fkProfissional: 1,
        fkGrupoEmpresa: idGrupo,
        titulo: 'Conserto de Cabo de Panela',
        descricao:
            'Conserto e substituição de cabos e alças de panelas com materiais reforçados e resistentes ao calor.',
        valor: 18.99,
        fkOficio: 1,
        funcao: 'Panelas',
        ativo: true,
        imagemUrl: null,
        dataCriacao: DateTime.now(),
      ),
      _servicoPadraoLoja(idGrupo, 9002, 'Troca de Válvula de Panela de Pressão',
          'Troca de válvula de segurança e anel de borracha original com teste de vedação completo.', 24.50, 'Panelas'),
      _servicoPadraoLoja(idGrupo, 9003, 'Conserto de Tampa e Alça Lateral',
          'Ajuste técnico de tampas empenadas e instalação de alças laterais antitérmicas.', 16.00, 'Panelas'),
      _servicoPadraoLoja(idGrupo, 9004, 'Polimento e Reforma Completa de Panelas',
          'Polimento profissional de alta durabilidade, desamasso de fundo e restauração do brilho.', 32.90, 'Panelas'),
      _servicoPadraoLoja(idGrupo, 9005, 'Manutenção em Panela Elétrica',
          'Diagnóstico e reparo elétrico de circuitos, termostatos e botões de acionamento.', 45.00, 'Eletroportáteis'),
    ];
  }

  static ServicoProfissional _servicoPadraoLoja(
    int? idGrupo,
    int id,
    String titulo,
    String descricao,
    double valor,
    String funcao,
  ) {
    return ServicoProfissional(
      id: id,
      fkProfissional: 1,
      fkGrupoEmpresa: idGrupo,
      titulo: titulo,
      descricao: descricao,
      valor: valor,
      fkOficio: 1,
      funcao: funcao,
      ativo: true,
      imagemUrl: null,
      dataCriacao: DateTime.now(),
    );
  }

  List<Map<String, dynamic>> _gerarProfissionaisPadraoLoja() {
    return [
      {
        'idProfissional': 1,
        'nome': 'Clóvis Vieira',
        'avaliacao': 5.0,
        'totalAvaliacoes': 148,
        'oficios': <OficioInfo>[],
        'tag': 'Panelas',
        'tagBgColor': CorOficio.corFundo(const Color(0xFF0288D1)),
        'tagTextColor': CorOficio.corTexto(const Color(0xFF0288D1)),
        'caminhoImagem': '',
        'profissao': 'Panelas',
      },
    ];
  }

  Widget _placeholderImagemServico({double height = 100}) {
    return Container(
      height: height,
      width: double.infinity,
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

  Widget _buildCardServicoLoja(ServicoProfissional servico) {
    final bool usaImagemRede = servico.imagemUrl != null &&
        servico.imagemUrl!.isNotEmpty &&
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
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            usaImagemRede
                ? Image.network(
                    servico.imagemUrl!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _placeholderImagemServico(height: 100),
                  )
                : _placeholderImagemServico(height: 100),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    servico.titulo,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (servico.funcao != null && servico.funcao!.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final corBase = CorOficio.parse(servico.funcao!);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CorOficio.corFundo(corBase),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            servico.funcao!,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: CorOficio.corTexto(corBase),
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'R\$ ${servico.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00A2FF),
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

  Widget _buildComentarioItem({
    required String nome,
    required double nota,
    required String tempo,
    required String texto,
    required bool liked,
    required int likes,
    required VoidCallback onLikeTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                      if (index < nota.floor()) {
                        return const Icon(
                          Icons.star,
                          color: Color(0xFF00A3FF),
                          size: 12,
                        );
                      } else if (index == nota.floor() && nota % 1 != 0) {
                        return const Icon(
                          Icons.star_half,
                          color: Color(0xFF00A3FF),
                          size: 12,
                        );
                      } else {
                        return const Icon(
                          Icons.star_border,
                          color: Color(0xFF00A3FF),
                          size: 12,
                        );
                      }
                    }),
                    const SizedBox(width: 8),
                    Text(
                      tempo,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  texto,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ÍCONES DE CORAÇÃO INTERATIVOS CONFORME COR E ESPECIFICAÇÃO
          GestureDetector(
            onTap: onLikeTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    color: liked
                        ? const Color(0xFF00A3FF)
                        : Colors.grey.shade400,
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$likes',
                    style: TextStyle(
                      fontSize: 10,
                      color: liked ? const Color(0xFF00A3FF) : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
