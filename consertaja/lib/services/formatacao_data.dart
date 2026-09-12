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

/// Formata a última conexión de um usuário como texto relativo.
///
/// * `null`                    → `''` (não se exibe)
/// * fez 2 min ou menos        → `'Online'`
/// * fez menos de 1 hora       → `'há X min'`
/// * fez menos de 24 horas     → `'há X h'`
/// * fez 1 dia                 → `'há 1 dia'`
/// * fez menos de 7 dias       → `'há X dias'`
/// * fez menos de 30 dias      → `'há X semanas'`
/// * resto                     → `'há X meses'`
String formatarUltimaVezAtivo(DateTime? ultimaConexion) {
  if (ultimaConexion == null) return '';

  final diff = DateTime.now().difference(ultimaConexion);

  // Una conexión com menos de 2 minutos se considera "online".
  if (diff.inMinutes <= 2) return 'Online';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours} h';
  if (diff.inDays == 1) return 'há 1 dia';
  if (diff.inDays < 7) return 'há ${diff.inDays} dias';
  if (diff.inDays < 30) return 'há ${diff.inDays ~/ 7} semanas';
  return 'há ${diff.inDays ~/ 30} meses';
}
