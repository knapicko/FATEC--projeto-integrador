// =============================================================================
// ConsertaJá — Função do serviço (tabela `funcoes`)
// =============================================================================
//
// O serviço (`servicos_profissional`, `servicos_chat_temporarios`,
// `servicos_catalogo`) aponta para a função via `fk_funcao`. Cada função
// pertence a um ofício (`funcoes.fk_oficio`), de onde vêm categoria e cor.
//
// Use [kSelectFuncao] dentro do `.select(...)` de qualquer consulta de
// serviço e leia o resultado com [extrairFuncao]:
//
//   .select('titulo, valor, $kSelectFuncao')
//   final f = extrairFuncao(row); // {funcao, cor, cod_cor, categoria, ...}
// =============================================================================

/// Embed do PostgREST que traz a função do serviço já "achatada" com os
/// dados do ofício (spread `...oficios`), sob a chave `funcoes`:
/// `{id_funcao, funcao, descricao, img_funcao, fk_oficio, categoria, cor, cod_cor}`.
const String kSelectFuncao =
    'funcoes(id_funcao, funcao, descricao, img_funcao, fk_oficio, '
    '...oficios(categoria, cor, cod_cor))';

/// Colunas para consultar a tabela `funcoes` diretamente devolvendo o mesmo
/// formato que `oficios` tinha antes (`id_oficio`, `funcao`, `descricao`,
/// `categoria`, `cor`, `cod_cor`) + `id_funcao` e `img_funcao`.
const String kColunasFuncaoComoOficio =
    'id_funcao, id_oficio:fk_oficio, funcao, descricao, img_funcao, '
    '...oficios(categoria, cor, cod_cor)';

/// Lê o embed [kSelectFuncao] de uma linha de serviço (aceita Map ou List).
Map<String, dynamic>? extrairFuncao(Map<dynamic, dynamic>? row) {
  if (row == null) return null;
  final raw = row['funcoes'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty && raw.first is Map) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  return null;
}

/// Nome da função do serviço (ou `null`).
String? nomeFuncao(Map<dynamic, dynamic>? row) {
  final nome = extrairFuncao(row)?['funcao']?.toString().trim();
  return (nome == null || nome.isEmpty) ? null : nome;
}
