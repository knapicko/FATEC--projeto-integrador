import '../utils/funcao_servico.dart';

class ServicoCatalogo {
  const ServicoCatalogo({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.fkOficio,
    this.fkFuncao,
    this.funcao,
    this.cor,
    this.imagemUrl,
    required this.ativo,
  });

  final int id;
  final String titulo;
  final String descricao;
  final int fkOficio;

  /// Referência à função na tabela `funcoes`.
  final int? fkFuncao;

  /// Nome da função, preenchido via join com `funcoes` (kSelectFuncao).
  final String? funcao;

  /// Cor associada ao ofício.
  final String? cor;

  final String? imagemUrl;
  final bool ativo;

  factory ServicoCatalogo.fromMap(Map<String, dynamic> map) {
    // Join com `funcoes` (kSelectFuncao): traz funcao + cor do ofício.
    final funcaoMap = extrairFuncao(map);
    final funcao = funcaoMap?['funcao']?.toString();
    // `cor` (nome) é a fonte oficial; CorOficio.parse também aceita o hex.
    final cor = (funcaoMap?['cor'] ?? funcaoMap?['cod_cor'])?.toString();

    return ServicoCatalogo(
      id: (map['id_catalogo'] as num).toInt(),
      titulo: map['titulo']?.toString() ?? '',
      descricao: map['descricao']?.toString() ?? '',
      fkOficio: (map['fk_oficio'] as num).toInt(),
      fkFuncao: (map['fk_funcao'] as num?)?.toInt(),
      funcao: funcao,
      cor: cor,
      imagemUrl: map['imagem_url']?.toString(),
      ativo: map['ativo'] == true,
    );
  }
}
