/// Utilitários de formatação de datas (exibição e persistência).
///
/// O banco de dados armazena datas no formato ISO (AAAA-MM-DD), enquanto o
/// usuário vê o formato brasileiro (DD/MM/AAAA).
library;

/// Converte uma data ISO (AAAA-MM-DD) para o formato brasileiro (DD/MM/AAAA).
String formatarDataBrasileira(String dataIso) {
  final partes = dataIso.split('-');
  if (partes.length == 3 && partes[0].length == 4) {
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }
  return dataIso;
}

/// Converte uma data no formato brasileiro (DD/MM/AAAA) para ISO (AAAA-MM-DD).
String converterDataParaIso(String dataBr) {
  final partes = dataBr.split('/');
  if (partes.length == 3) {
    return '${partes[2]}-${partes[1]}-${partes[0]}';
  }
  return dataBr;
}

/// Formata um [DateTime] selecionado no date picker como DD/MM/AAAA.
String formatarDataSelecionada(DateTime data) {
  final dia = data.day.toString().padLeft(2, '0');
  final mes = data.month.toString().padLeft(2, '0');
  return '$dia/$mes/${data.year}';
}
