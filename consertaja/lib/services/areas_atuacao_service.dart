import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Área de atuação = OFÍCIO (Reparos domésticos, Segurança...).
///
/// O profissional (ou a loja) escolhe ofícios. No banco continuam sendo
/// gravadas as FUNÇÕES (`ass_oficio_profissional.fk_funcao` /
/// `ass_oficio_grupo_empresa.fk_funcao`): todas as funções de cada ofício
/// escolhido. Assim o Radar, a busca, os perfis e o "adicionar serviço"
/// (que listam por função) continuam funcionando, e ao criar um serviço
/// aparecem todas as funções dos ofícios dele.
///
/// Cada ofício é devolvido como um Map com as MESMAS chaves que as telas já
/// usavam para as funções: `id_oficio`, `funcao` (= nome do ofício),
/// `descricao`, `img_funcao`, `categoria`, `cor`, `cod_cor` — mais
/// `funcoes_ids` e `funcoes_nomes`.
class AreasAtuacaoService {
  AreasAtuacaoService._();

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> carregarOficios() async {
    final oficios = await _db
        .from('oficios')
        .select('id_oficio, categoria, cor, cod_cor')
        .order('categoria');
    final funcoes = await _db
        .from('funcoes')
        .select('id_funcao, funcao, fk_oficio, img_funcao')
        .order('funcao');
    final porOficio = <int, List<Map<String, dynamic>>>{};
    for (final f in funcoes) {
      final o = (f['fk_oficio'] as num?)?.toInt();
      if (o == null) continue;
      porOficio.putIfAbsent(o, () => []).add(Map<String, dynamic>.from(f));
    }
    final lista = <Map<String, dynamic>>[];
    for (final o in oficios) {
      final id = (o['id_oficio'] as num?)?.toInt();
      if (id == null) continue;
      final fs = porOficio[id] ?? const [];
      if (fs.isEmpty) continue; // ofício sem função não serve como área
      final nomes = [for (final f in fs) f['funcao']?.toString() ?? ''];
      final img = fs
          .map((f) => f['img_funcao']?.toString().trim() ?? '')
          .firstWhere((u) => u.isNotEmpty && u != 'null', orElse: () => '');
      final categoria = o['categoria']?.toString() ?? '';
      lista.add({
        'id_oficio': id,
        'funcao': categoria,
        'categoria': categoria,
        'cor': o['cor'],
        'cod_cor': o['cod_cor'],
        'descricao': 'Inclui: ${nomes.join(', ')}.',
        'img_funcao': img.isEmpty ? null : img,
        'funcoes_ids': [
          for (final f in fs) (f['id_funcao'] as num).toInt(),
        ],
        'funcoes_nomes': nomes,
      });
    }
    return lista;
  }

  /// Para EXIBIR a área de atuação: junta as linhas de função (consulta com
  /// `kColunasFuncaoComoOficio`) em uma linha por ofício, com as mesmas
  /// chaves (`funcao` vira o nome do ofício). Mantém a ordem de chegada.
  static List<Map<String, dynamic>> comoOficios(List<dynamic> linhasFuncao) {
    final porOficio = <Object, Map<String, dynamic>>{};
    for (final l in linhasFuncao) {
      if (l is! Map) continue;
      final m = Map<String, dynamic>.from(l);
      final categoria = m['categoria']?.toString().trim() ?? '';
      final chave = m['fk_oficio'] ?? (categoria.isEmpty ? m['funcao'] : categoria);
      if (chave == null) continue;
      final existente = porOficio[chave];
      if (existente == null) {
        porOficio[chave] = {
          ...m,
          'id_oficio': m['fk_oficio'] ?? m['id_oficio'],
          'funcao': categoria.isEmpty ? m['funcao'] : categoria,
          'funcoes_nomes': [m['funcao']?.toString() ?? ''],
        };
      } else {
        (existente['funcoes_nomes'] as List).add(m['funcao']?.toString() ?? '');
        final img = existente['img_funcao']?.toString() ?? '';
        if (img.isEmpty || img == 'null') existente['img_funcao'] = m['img_funcao'];
      }
    }
    for (final o in porOficio.values) {
      o['descricao'] = 'Inclui: ${(o['funcoes_nomes'] as List).join(', ')}.';
    }
    return porOficio.values.toList();
  }

  /// Todas as funções dos ofícios escolhidos (o que vai para o banco).
  static List<int> funcoesDe(Iterable<Map<String, dynamic>> oficios) => {
    for (final o in oficios)
      for (final id in (o['funcoes_ids'] as List? ?? const []))
        (id as num).toInt(),
  }.toList();

  /// Ofícios (da [lista]) que têm pelo menos uma das [funcoes] gravadas.
  static List<Map<String, dynamic>> oficiosDasFuncoes(
    List<Map<String, dynamic>> lista,
    Iterable<int> funcoes,
  ) {
    final ids = funcoes.toSet();
    return [
      for (final o in lista)
        if ((o['funcoes_ids'] as List? ?? const []).any(
          (f) => ids.contains((f as num).toInt()),
        ))
          o,
    ];
  }

  static Future<Set<int>> _funcoesGravadas(
    String tabela,
    String coluna,
    int id,
  ) async {
    final rows = await _db.from(tabela).select('fk_funcao').eq(coluna, id);
    return {
      for (final r in rows)
        if (r['fk_funcao'] != null) (r['fk_funcao'] as num).toInt(),
    };
  }

  static Future<Set<int>> funcoesDoProfissional(int idProfissional) =>
      _funcoesGravadas(
        'ass_oficio_profissional',
        'fk_profissional',
        idProfissional,
      );

  static Future<Set<int>> funcoesDaEmpresa(int idGrupo) =>
      _funcoesGravadas('ass_oficio_grupo_empresa', 'fk_grupo_empresa', idGrupo);

  /// Grava só a diferença: as funções dos [oficios] escolhidos.
  static Future<void> _salvar(
    String tabela,
    String coluna,
    int id,
    List<Map<String, dynamic>> oficios,
  ) async {
    final atuais = await _funcoesGravadas(tabela, coluna, id);
    final novas = funcoesDe(oficios).toSet();
    final adicionar = novas.difference(atuais);
    final remover = atuais.difference(novas);
    if (adicionar.isNotEmpty) {
      await _db.from(tabela).insert([
        for (final f in adicionar) {coluna: id, 'fk_funcao': f},
      ]);
    }
    if (remover.isNotEmpty) {
      await _db
          .from(tabela)
          .delete()
          .eq(coluna, id)
          .inFilter('fk_funcao', remover.toList());
    }
    debugPrint('[Areas] $tabela $id: +${adicionar.length} -${remover.length}');
  }

  static Future<void> salvarProfissional(
    int idProfissional,
    List<Map<String, dynamic>> oficios,
  ) => _salvar(
    'ass_oficio_profissional',
    'fk_profissional',
    idProfissional,
    oficios,
  );

  static Future<void> salvarEmpresa(
    int idGrupo,
    List<Map<String, dynamic>> oficios,
  ) => _salvar('ass_oficio_grupo_empresa', 'fk_grupo_empresa', idGrupo, oficios);
}
