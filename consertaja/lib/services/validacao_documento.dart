/// Validações de CPF e CNPJ extraídas de [cadastro_cliente.dart] /
/// [cadastro_profissional.dart] (algoritmo idêntico).
library;

String somenteDigitos(String valor) {
  return valor.replaceAll(RegExp(r'\D'), '');
}

bool validarCpf(String cpf) {
  if (cpf.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

  final numeros = cpf.split('').map(int.parse).toList();

  int soma = 0;
  for (int i = 0; i < 9; i++) {
    soma += numeros[i] * (10 - i);
  }
  int resto = soma % 11;
  int digito1 = resto < 2 ? 0 : 11 - resto;
  if (numeros[9] != digito1) return false;

  soma = 0;
  for (int i = 0; i < 10; i++) {
    soma += numeros[i] * (11 - i);
  }
  resto = soma % 11;
  int digito2 = resto < 2 ? 0 : 11 - resto;

  return numeros[10] == digito2;
}

bool validarCnpj(String cnpj) {
  if (cnpj.length != 14) return false;
  if (RegExp(r'^(\d)\1{13}$').hasMatch(cnpj)) return false;

  final numeros = cnpj.split('').map(int.parse).toList();

  const pesos1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
  const pesos2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];

  int soma = 0;
  for (int i = 0; i < 12; i++) {
    soma += numeros[i] * pesos1[i];
  }
  int resto = soma % 11;
  int digito1 = resto < 2 ? 0 : 11 - resto;
  if (numeros[12] != digito1) return false;

  soma = 0;
  for (int i = 0; i < 13; i++) {
    soma += numeros[i] * pesos2[i];
  }
  resto = soma % 11;
  int digito2 = resto < 2 ? 0 : 11 - resto;

  return numeros[13] == digito2;
}

bool documentoEhCpf(String digits) => digits.length <= 11;

bool documentoEhCnpj(String digits) => digits.length > 11;

String formatarCpf(String digits) {
  final d = somenteDigitos(digits);
  if (d.length != 11) return digits;
  return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
}

String formatarCnpj(String digits) {
  final d = somenteDigitos(digits);
  if (d.length != 14) return digits;
  return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
}

String formatarCpfOuCnpj(String valor) {
  final d = somenteDigitos(valor);
  if (d.length == 11) return formatarCpf(d);
  if (d.length == 14) return formatarCnpj(d);
  return valor;
}

String rotuloDocumento(String valor) {
  final d = somenteDigitos(valor);
  return d.length > 11 ? 'CNPJ' : 'CPF';
}
