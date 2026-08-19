class PostagemResumo {
  final int idPostagem;
  final String titulo;
  final String? imagemUrl;
  final DateTime dataPostagem;
  final int curtidas;

  const PostagemResumo({
    required this.idPostagem,
    required this.titulo,
    this.imagemUrl,
    required this.dataPostagem,
    required this.curtidas,
  });
}
