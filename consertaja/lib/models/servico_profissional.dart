import '../utils/funcao_servico.dart';

class ServicoProfissional {
  const ServicoProfissional({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.valor,
    required this.fkOficio,
    this.fkFuncao,
    this.funcao,
    this.cor,
    this.imagemUrl,
    required this.ativo,
    required this.fkProfissional,
    this.fkGrupoEmpresa,
    this.tipoExecucao = 'Execução',
    this.cargaServico = 'Médio',
    required this.dataCriacao,
  });

  final int id;
  final String titulo;
  final String descricao;
  final double valor;

  /// Referência ao ofício (categoria/cor) na tabela `oficios`.
  final int fkOficio;

  /// Referência à função do serviço na tabela `funcoes`.
  final int? fkFuncao;

  /// Nome da função, preenchido via join com `funcoes` (kSelectFuncao).
  final String? funcao;

  /// Cor (cod_cor) do ofício da função, vinda do mesmo join.
  final String? cor;

  final String? imagemUrl;
  final bool ativo;
  final int fkProfissional;

  /// Grupo proprietário do serviço; nulo quando o serviço é individual.
  final int? fkGrupoEmpresa;
  final String tipoExecucao;
  final String cargaServico;
  final DateTime dataCriacao;

  factory ServicoProfissional.fromMap(Map<String, dynamic> map) {
    // Join com `funcoes` (kSelectFuncao): traz funcao + cor do ofício.
    final funcaoMap = extrairFuncao(map);
    final funcao = funcaoMap?['funcao']?.toString();
    // `cor` (nome) é a fonte oficial; CorOficio.parse também aceita o hex.
    final cor = (funcaoMap?['cor'] ?? funcaoMap?['cod_cor'])?.toString();

    return ServicoProfissional(
      id: (map['id_servico_prof'] as num).toInt(),
      titulo: map['titulo']?.toString() ?? '',
      descricao: map['descricao']?.toString() ?? '',
      valor: (map['valor'] as num?)?.toDouble() ?? 0,
      fkOficio:
          (map['fk_oficios'] as num?)?.toInt() ??
          (funcaoMap?['fk_oficio'] as num?)?.toInt() ??
          0,
      fkFuncao: (map['fk_funcao'] as num?)?.toInt(),
      funcao: funcao,
      cor: cor,
      imagemUrl: map['imagem_url']?.toString(),
      ativo: map['ativo'] == true,
      fkProfissional: (map['fk_profissional'] as num).toInt(),
      fkGrupoEmpresa: (map['fk_grupo_empresa'] as num?)?.toInt(),
      tipoExecucao: map['tipo_execucao']?.toString() ?? 'Execução',
      cargaServico: map['carga_servico']?.toString() ?? 'Médio',
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
      'fk_funcao': fkFuncao,
      'imagem_url': imagemUrl,
      'ativo': ativo,
      'fk_profissional': fkProfissional,
      'fk_grupo_empresa': fkGrupoEmpresa,
      'tipo_execucao': tipoExecucao,
      'carga_servico': cargaServico,
    };
  }
}

class ServicoBuscaPublico {
  const ServicoBuscaPublico({
    required this.id,
    required this.titulo,
    required this.preco,
    required this.categoria,
    required this.servico,
    required this.tipoExecucao,
    this.tagEmpresa,
    this.imagemUrl,
    required this.localizacao,
  });

  final int id;
  final String titulo;
  final double preco;
  final String categoria;
  final ServicoProfissional servico;
  final String tipoExecucao;
  final String? tagEmpresa;
  final String? imagemUrl;
  final String localizacao;
}

class DetalheServicoPublico {
  const DetalheServicoPublico({
    required this.servico,
    required this.nomePrestador,
    this.fotoPrestador,
    required this.ehLoja,
    this.tipoPrestador = 'cpf',
    this.tagEmpresa,
    this.corTagEmpresa,
    this.idGrupoEmpresa,
    required this.idProfissional,
    this.idPerfilPrestador,
    this.fotoBannerEmpresa,
    required this.seguidores,
    required this.enderecoFormatado,
    required this.latitude,
    required this.longitude,
    required this.temCoordenadas,
  });

  final ServicoProfissional servico;
  final String nomePrestador;
  final String? fotoPrestador;
  final bool ehLoja;
  final String tipoPrestador; // 'empresa' | 'independente' | 'cpf'
  final String? tagEmpresa;
  final String? corTagEmpresa;
  final int? idGrupoEmpresa;
  final int idProfissional;
  final int? idPerfilPrestador;
  final String? fotoBannerEmpresa;
  final int seguidores;
  final String enderecoFormatado;
  final double latitude;
  final double longitude;
  final bool temCoordenadas;

  bool get ehEmpresa => tipoPrestador == 'empresa' || ehLoja;
  bool get ehIndependente => tipoPrestador == 'independente';
  bool get ehCpf => tipoPrestador == 'cpf';

  String get rotuloTipoPrestador {
    if (ehEmpresa) return 'Loja / Empresa';
    if (ehIndependente) return 'Independente (CNPJ)';
    return 'Autônomo (CPF)';
  }
}
