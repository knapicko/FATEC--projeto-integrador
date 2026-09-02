class ServicoCatalogo {
  const ServicoCatalogo({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.fkOficio,
    this.funcao,
    this.cor,
    this.imagemUrl,
    required this.ativo,
  });

  final int id;
  final String titulo;
  final String descricao;
  final int fkOficio;

  /// Função (nome do ofício) preenchida via join com a tabela `oficios`.
  final String? funcao;

  /// Cor associada ao ofício.
  final String? cor;

  final String? imagemUrl;
  final bool ativo;

  factory ServicoCatalogo.fromMap(Map<String, dynamic> map) {
    // Se veio com join da tabela oficios
    final oficioMap = map['oficios'];
    final funcao = oficioMap is Map<String, dynamic>
        ? oficioMap['funcao']?.toString()
        : null;
    final cor = oficioMap is Map<String, dynamic>
        ? oficioMap['cod_cor']?.toString()
        : null;

    return ServicoCatalogo(
      id: (map['id_catalogo'] as num).toInt(),
      titulo: map['titulo']?.toString() ?? '',
      descricao: map['descricao']?.toString() ?? '',
      fkOficio: (map['fk_oficio'] as num).toInt(),
      funcao: funcao,
      cor: cor,
      imagemUrl: map['imagem_url']?.toString(),
      ativo: map['ativo'] == true,
    );
  }
}
