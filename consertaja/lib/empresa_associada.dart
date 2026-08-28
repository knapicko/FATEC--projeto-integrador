import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'utils/cor_oficio.dart';
import 'utils/icone_oficio.dart';
import 'utils/iniciais.dart';

class EmpresaAssociadaPage extends StatefulWidget {
  const EmpresaAssociadaPage({super.key});

  @override
  State<EmpresaAssociadaPage> createState() => _EmpresaAssociadaPageState();
}

class _EmpresaAssociadaPageState extends State<EmpresaAssociadaPage> {
  static const _blue = Color(0xFF0FB3FF);
  static const _dark = Color(0xFF202124);
  static const _background = Color(0xFFF9F7FF);

  Map<String, dynamic>? _empresa;
  List<_MembroEmpresa> _membros = [];
  List<OficioInfo> _oficios = [];
  bool _carregando = true;

  void _marcarSemEmpresa() {
    if (!mounted) return;
    setState(() {
      _empresa = null;
      _carregando = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _carregarEmpresa();
  }

  Future<void> _carregarEmpresa() async {
    try {
      final client = Supabase.instance.client;
      final usuario = client.auth.currentUser;
      if (usuario == null) {
        _marcarSemEmpresa();
        return;
      }
      final usuarioRow = await client
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', usuario.id)
          .maybeSingle();
      final usuarioId = (usuarioRow?['id_usuario'] as num?)?.toInt();
      if (usuarioId == null) {
        _marcarSemEmpresa();
        return;
      }
      final profissional = await client
          .from('dados_profissionais')
          .select('id_profissional, fk_grupo_empresa, fk_perfil')
          .eq('fk_usuario', usuarioId)
          .maybeSingle();
      if (profissional == null) {
        _marcarSemEmpresa();
        return;
      }

      final grupoId = (profissional['fk_grupo_empresa'] as num?)?.toInt();
      final perfilId = (profissional['fk_perfil'] as num?)?.toInt();
      Map<String, dynamic>? grupo;
      const campos =
          'id_grupo_empresa, nome_empresa, tag_empresa, cor_tag_empresa, foto_url_empresa, banner_url_empresa, fk_perfil';
      if (grupoId != null) {
        grupo = await client
            .from('grupo_empresa')
            .select(campos)
            .eq('id_grupo_empresa', grupoId)
            .maybeSingle();
      }
      grupo ??= perfilId == null
          ? null
          : await client
                .from('grupo_empresa')
                .select(campos)
                .eq('fk_perfil', perfilId)
                .maybeSingle();
      if (grupo == null) {
        _marcarSemEmpresa();
        return;
      }

      final idGrupo = (grupo['id_grupo_empresa'] as num?)?.toInt();
      final fkPerfilGrupo = (grupo['fk_perfil'] as num?)?.toInt();
      final membros = <_MembroEmpresa>[];
      final vistos = <int>{};
      final todosOficios = <OficioInfo>[];

      Future<void> adicionar(dynamic row) async {
        final mapa = Map<String, dynamic>.from(row as Map);
        final id = (mapa['id_profissional'] as num?)?.toInt();
        if (id == null || !vistos.add(id)) return;
        final usuarioMap = mapa['usuarios'] is Map
            ? Map<String, dynamic>.from(mapa['usuarios'] as Map)
            : <String, dynamic>{};
        final ids = await client
            .from('ass_oficio_profissional')
            .select('fk_oficio')
            .eq('fk_profissional', id);
        final oficioIds = ids
            .map((item) => (item['fk_oficio'] as num?)?.toInt())
            .whereType<int>()
            .toList();
        final oficios = oficioIds.isEmpty
            ? <OficioInfo>[]
            : (await client
                      .from('oficios')
                      .select('funcao, categoria, cor')
                      .inFilter('id_oficio', oficioIds))
                  .map<OficioInfo>(OficioInfo.fromMap)
                  .where((item) => item.funcao.isNotEmpty)
                  .toList();
        membros.add(
          _MembroEmpresa(
            nome: usuarioMap['nome']?.toString().trim() ?? 'Profissional',
            foto: usuarioMap['foto_perfil_url']?.toString(),
            cargo: oficios.isEmpty ? 'Profissional' : oficios.first.funcao,
            oficios: oficios,
          ),
        );
        todosOficios.addAll(oficios);
      }

      if (fkPerfilGrupo != null) {
        final dono = await client
            .from('dados_profissionais')
            .select(
              'id_profissional, fk_usuario, usuarios(nome, foto_perfil_url)',
            )
            .eq('fk_perfil', fkPerfilGrupo)
            .maybeSingle();
        if (dono != null) await adicionar(dono);
      }
      if (idGrupo != null) {
        final rows = await client
            .from('dados_profissionais')
            .select(
              'id_profissional, fk_usuario, usuarios(nome, foto_perfil_url)',
            )
            .eq('fk_grupo_empresa', idGrupo);
        for (final row in rows) {
          await adicionar(row);
        }
      }

      if (mounted) {
        setState(() {
          _empresa = grupo;
          _membros = membros;
          _oficios = todosOficios.fold<List<OficioInfo>>([], (lista, oficio) {
            if (!lista.any(
              (item) =>
                  item.funcao.toLowerCase() == oficio.funcao.toLowerCase(),
            ))
              lista.add(oficio);
            return lista;
          });
          _carregando = false;
        });
      }
    } catch (_) {
      _marcarSemEmpresa();
    }
  }

  Future<void> _abrirOpcoesEmpresa() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'Sair da empresa',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmarSaidaEmpresa();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmarSaidaEmpresa() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Sair da empresa?'),
          content: const Text(
            'Tem certeza de que deseja sair desta empresa? Você deixará de fazer parte da equipe.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmou == true) await _sairDaEmpresa();
  }

  Future<void> _sairDaEmpresa() async {
    try {
      final client = Supabase.instance.client;
      final usuario = client.auth.currentUser;
      if (usuario == null) throw Exception('Usuário não autenticado.');

      final usuarioRow = await client
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', usuario.id)
          .maybeSingle();
      final usuarioId = (usuarioRow?['id_usuario'] as num?)?.toInt();
      if (usuarioId == null) throw Exception('Usuário não encontrado.');

      await client
          .from('dados_profissionais')
          .update({'fk_grupo_empresa': null})
          .eq('fk_usuario', usuarioId);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você saiu da empresa com sucesso.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível sair da empresa: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _blue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Empresa associada',
          style: TextStyle(color: _blue, fontWeight: FontWeight.bold),
        ),
        actions: _empresa == null
            ? const []
            : [
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: _blue),
                  onPressed: _abrirOpcoesEmpresa,
                ),
              ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : _empresa == null
          ? const Center(child: Text('Você não faz parte de nenhuma empresa'))
          : RefreshIndicator(
              color: _blue,
              onRefresh: _carregarEmpresa,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildCapa(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(17, 88, 17, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _empresa!['nome_empresa']?.toString() ??
                              'Empresa associada',
                          style: const TextStyle(
                            fontSize: 29,
                            height: 1.15,
                            fontWeight: FontWeight.bold,
                            color: _dark,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Soluções completas em manutenção predial e residencial.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF52525B),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 9),
                        _buildTags(),
                        const SizedBox(height: 26),
                        _buildTitulo('Equipe Atual', acao: 'Ver todos'),
                        const SizedBox(height: 13),
                        _buildEquipe(),
                        const SizedBox(height: 25),
                        const Text(
                          'Ofícios Disponibilizados',
                          style: TextStyle(fontSize: 16, color: _dark),
                        ),
                        const SizedBox(height: 12),
                        ..._buildServicos(),
                        const SizedBox(height: 24),
                        const Text(
                          'Serviços Disponibilizados',
                          style: TextStyle(fontSize: 16, color: _dark),
                        ),
                        const SizedBox(height: 12),
                        ..._buildCardsServicos(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCapa() {
    final banner = _empresa!['banner_url_empresa']?.toString();
    final foto = _empresa!['foto_url_empresa']?.toString();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 248,
          width: double.infinity,
          child: _imagem(
            banner,
            const Icon(Icons.business, size: 70, color: Colors.white54),
            BoxFit.cover,
            fundo: const Color(0xFF9AA9B7),
          ),
        ),
        Positioned(
          left: 17,
          bottom: -67,
          child: Container(
            width: 132,
            height: 132,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 7),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: _imagem(
                foto,
                Text(
                  obterIniciais(
                    _empresa!['nome_empresa']?.toString() ?? 'Empresa',
                  ),
                  style: const TextStyle(
                    fontSize: 30,
                    color: _blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                BoxFit.cover,
                fundo: const Color(0xFFE1F5FE),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagem(
    String? url,
    Widget fallback,
    BoxFit fit, {
    required Color fundo,
  }) => url == null || url.trim().isEmpty
      ? Container(color: fundo, alignment: Alignment.center, child: fallback)
      : Image.network(
          url,
          fit: fit,
          errorBuilder: (_, _, _) => Container(
            color: fundo,
            alignment: Alignment.center,
            child: fallback,
          ),
        );

  Widget _buildTags() {
    final tag = _empresa!['tag_empresa']?.toString().trim();
    final tags = <Widget>[];
    if (tag != null && tag.isNotEmpty) {
      final corTag = CorOficio.parse(_empresa!['cor_tag_empresa']?.toString());
      tags.add(
        _pill(
          tag.startsWith('#') ? tag : '#$tag',
          corTag,
          CorOficio.corTextoContraste(corTag),
        ),
      );
    }
    for (final oficio in _oficios.take(3)) {
      final cor = CorOficio.parse(oficio.cor);
      tags.add(_pill(oficio.funcao, cor, CorOficio.corTextoContraste(cor)));
    }
    return Wrap(spacing: 7, runSpacing: 7, children: tags);
  }

  Widget _pill(String texto, Color fundo, Color textoCor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: fundo,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: 13,
        color: textoCor,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
  Widget _buildTitulo(String titulo, {String? acao}) => Row(
    children: [
      Expanded(
        child: Text(titulo, style: const TextStyle(fontSize: 17, color: _dark)),
      ),
      if (acao != null)
        Text(
          acao,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0A3D70)),
        ),
    ],
  );

  Widget _buildEquipe() {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _membros.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, index) {
          final membro = _membros[index];
          return Container(
            width: 145,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE9E2EC),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFD8F3FF),
                  backgroundImage:
                      membro.foto != null && membro.foto!.isNotEmpty
                      ? NetworkImage(membro.foto!)
                      : null,
                  child: membro.foto == null || membro.foto!.isEmpty
                      ? Text(
                          obterIniciais(membro.nome),
                          style: const TextStyle(
                            color: _blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  membro.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: _dark),
                ),
                Text(
                  membro.cargo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF454047),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildServicos() {
    final grupos = <String, List<String>>{};
    for (final oficio in _oficios) {
      final categoria = oficio.categoria?.trim();
      if (categoria == null || categoria.isEmpty) continue;
      final chave = categoria.toLowerCase();
      grupos.putIfAbsent(chave, () => []);
      if (!grupos[chave]!.any(
        (funcao) => funcao.toLowerCase() == oficio.funcao.toLowerCase(),
      )) {
        grupos[chave]!.add(oficio.funcao);
      }
    }

    final categorias = <String, String>{};
    for (final oficio in _oficios) {
      final categoria = oficio.categoria?.trim();
      if (categoria != null && categoria.isNotEmpty) {
        categorias.putIfAbsent(categoria.toLowerCase(), () => categoria);
      }
    }

    return grupos.entries.map((grupo) {
      final categoria = categorias[grupo.key] ?? grupo.key;
      final funcoes = grupo.value.join(', ');
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFBFC),
          border: Border.all(color: const Color(0xFFE2DEE4)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconeOficio.imagem(categoria, tamanho: 30),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoria,
                    style: const TextStyle(fontSize: 15, color: _dark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    funcoes,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF52525B),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _buildCardsServicos() {
    return _oficios.take(3).map((oficio) {
      final membro = _membros.isEmpty
          ? 'Equipe'
          : _membros
                .firstWhere(
                  (m) => m.oficios.any((o) => o.funcao == oficio.funcao),
                  orElse: () => _membros.first,
                )
                .nome;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFBFC),
          border: Border.all(color: const Color(0xFFE2DEE4)),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: const Color(0xFFDDEAF0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.handyman_outlined,
                color: _blue,
                size: 34,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pill('#FATEC', const Color(0xFF07518C), Colors.white),
                  const SizedBox(height: 6),
                  Text(
                    oficio.funcao,
                    style: const TextStyle(
                      fontSize: 16,
                      color: _dark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Manutenção, instalação e reparos realizados por profissionais da equipe.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF52525B),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Oferecido por: $membro',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF52525B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _MembroEmpresa {
  const _MembroEmpresa({
    required this.nome,
    required this.foto,
    required this.cargo,
    required this.oficios,
  });
  final String nome;
  final String? foto;
  final String cargo;
  final List<OficioInfo> oficios;
}
