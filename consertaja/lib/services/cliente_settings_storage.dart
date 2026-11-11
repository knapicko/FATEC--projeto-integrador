import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ClienteSettingsStorage {
  Future<Map<String, dynamic>> load(String userId) async {
    final file = await _settingsFile();
    if (!await file.exists()) return <String, dynamic>{};

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('O arquivo de configurações está inválido.');
    }

    final profiles = decoded['profiles'];
    if (profiles == null) return <String, dynamic>{};
    if (profiles is! Map) {
      throw const FormatException('Os perfis de configuração estão inválidos.');
    }

    final settings = profiles[userId];
    if (settings == null) return <String, dynamic>{};
    if (settings is! Map) {
      throw const FormatException(
        'As configurações do perfil estão inválidas.',
      );
    }
    return Map<String, dynamic>.from(settings);
  }

  Future<void> save(String userId, Map<String, dynamic> settings) async {
    final file = await _settingsFile();
    Map<String, dynamic> document = <String, dynamic>{'profiles': {}};
    if (await file.exists()) {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'O arquivo de configurações está inválido.',
        );
      }
      document = Map<String, dynamic>.from(decoded);
    }

    final existingProfiles = document['profiles'];
    if (existingProfiles != null && existingProfiles is! Map) {
      throw const FormatException('Os perfis de configuração estão inválidos.');
    }

    final profiles = existingProfiles == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(existingProfiles as Map);
    profiles[userId] = settings;
    document['profiles'] = profiles;

    await file.writeAsString(jsonEncode(document), flush: true);
  }

  Future<File> _settingsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}consertaja_settings_cliente.json',
    );
  }
}
