class ServicoProfissional {
  const ServicoProfissional({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.valor,
    required this.fkOficio,
    this.funcao,
    this.cor,
    this.imagemUrl,
    required this.ativo,
    required this.fkProfissional,
    required this.dataCriacao,
  });

  final int id;
  final String titulo;
  final String descricao;
  final double valor;

  /// Referência ao ofício (categoria) na tabela `oficios`.
  final int fkOficio;

  /// Função (nome do ofício) preenchida via join com `oficios`.
  final String? funcao;

  /// Cor (cod_cor) do ofício preenchida via join com `oficios`.
  final String? cor;

  final String? imagemUrl;
  final bool ativo;
  final int fkProfissional;
  final DateTime dataCriacao;

  factory ServicoProfissional.fromMap(Map<String, dynamic> map) {
    // Se veio com join da tabela oficios (pode ser Map ou List)
    final dynamic oficioRaw = map['oficios'];
    final Map<String, dynamic>? oficioMap = oficioRaw is Map<String, dynamic>
        ? oficioRaw
        : (oficioRaw is List && oficioRaw.isNotEmpty
              ? oficioRaw.first as Map<String, dynamic>
              : null);
    final funcao = oficioMap is Map<String, dynamic>
        ? oficioMap['funcao']?.toString()
        : null;
    final cor = oficioMap is Map<String, dynamic>
        ? oficioMap['cod_cor']?.toString()
        : null;

    return ServicoProfissional(
      id: (map['id_servico_prof'] as num).toInt(),
      titulo: map['titulo']?.toString() ?? '',
      descricao: map['descricao']?.toString() ?? '',
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      fkOficio: (map['fk_oficios'] as num?)?.toInt() ?? 0,
      funcao: funcao,
      cor: cor,
      imagemUrl: map['imagem_url']?.toString(),
      ativo: map['ativo'] == true,
      fkProfissional: (map['fk_profissional'] as num).toInt(),
      dataCriacao: map['data_criacao'] != null
          ? DateTime.tryParse(map['data_criacao'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'titulo': titulo,
      'descricao': descricao,
      'valor': valor,
      'fk_oficios': fkOficio,
      'imagem_url': imagemUrl,
      'ativo': ativo,
      'fk_profissional': fkProfissional,
    };
  }
}
