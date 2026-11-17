/// Busca que ignora acentos e maiúsculas/minúsculas
/// ("eletrica" acha "Elétrica", "JOAO" acha "João").
String normalizarBusca(String texto) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final minusculo = texto.toLowerCase();
  final b = StringBuffer();
  for (final r in minusculo.runes) {
    final c = String.fromCharCode(r);
    final i = de.indexOf(c);
    b.write(i >= 0 ? para[i] : c);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Algum dos [campos] contém o [termo] (todas as palavras dele)?
bool textoContem(Iterable<String> campos, String termo) {
  final t = normalizarBusca(termo);
  if (t.isEmpty) return true;
  final validos = campos
      .map(normalizarBusca)
      .where((c) => c.isNotEmpty)
      .toList();
  if (validos.isEmpty) return false;
  if (validos.any((c) => c.contains(t))) return true;
  final palavras = t.split(' ').where((p) => p.length > 1);
  return palavras.isNotEmpty &&
      palavras.every((p) => validos.any((c) => c.contains(p)));
}
