/// Retorna as duas primeiras letras do nome (iniciais) em maiúsculas.
///
/// Se o nome estiver vazio ou for um placeholder, retorna "N" (de "Nome não
/// encontrado").
String obterIniciais(String nome) {
  final limpo = nome.trim();
  if (limpo.isEmpty || limpo.toLowerCase() == 'nome não encontrado') {
    return 'N';
  }

  final partes = limpo.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

  if (partes.isEmpty) return 'N';

  // Primeira letra do primeiro nome
  final primeira = partes.first[0].toUpperCase();

  // Segunda letra: primeira letra do segundo nome (se existir),
  // senão a segunda letra do primeiro nome.
  String segunda;
  if (partes.length > 1) {
    segunda = partes[1][0].toUpperCase();
  } else if (partes.first.length > 1) {
    segunda = partes.first[1].toUpperCase();
  } else {
    segunda = primeira;
  }

  return '$primeira$segunda';
}