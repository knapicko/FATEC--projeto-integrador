import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatThemeData {
  final String corBaloes;
  final String planoFundo;
  final double desfoqueFundo;
  final double opacidadeFundo;

  const ChatThemeData({
    required this.corBaloes,
    required this.planoFundo,
    required this.desfoqueFundo,
    required this.opacidadeFundo,
  });

  Map<String, dynamic> toJson() => {
    'cor_baloes': corBaloes,
    'plano_fundo': planoFundo,
    'desfoque_fundo': desfoqueFundo,
    'opacidade_fundo': opacidadeFundo,
  };

  factory ChatThemeData.fromJson(Map<String, dynamic> json) {
    return ChatThemeData(
      corBaloes: json['cor_baloes']?.toString() ?? '0xFF0FB3FF',
      planoFundo:
          json['plano_fundo']?.toString() ??
          'assets/images/plano_fundo_chat/doodle_default.png',
      desfoqueFundo: (json['desfoque_fundo'] as num?)?.toDouble() ?? 0.0,
      opacidadeFundo: (json['opacidade_fundo'] as num?)?.toDouble() ?? 35.0,
    );
  }
}

class ChatThemeStorage {
  static const _preferencesKey = 'chat_themes_v1';
  static const _defaultUserKey = 'anonymous';

  static ChatThemeData get defaultTheme => const ChatThemeData(
    corBaloes: '0xFF0FB3FF',
    planoFundo: 'assets/images/plano_fundo_chat/doodle_default.png',
    desfoqueFundo: 0.0,
    opacidadeFundo: 35.0,
  );

  Future<ChatThemeData> load({
    required String? userId,
    required int? conversationId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final themes = _readThemes(preferences);
    final userKey = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : _defaultUserKey;
    final conversationKey = conversationId == null
        ? null
        : '$userKey:conversation:$conversationId';
    final json =
        (conversationKey == null ? null : themes[conversationKey]) ??
        themes['$userKey:all'];
    if (json is! Map) return defaultTheme;
    return ChatThemeData.fromJson(Map<String, dynamic>.from(json));
  }

  Future<void> save({
    required String? userId,
    required int? conversationId,
    required ChatThemeData theme,
    bool applyToAll = false,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final themes = _readThemes(preferences);
    final userKey = userId?.trim().isNotEmpty == true
        ? userId!.trim()
        : _defaultUserKey;
    final json = jsonEncode(theme.toJson());
    if (conversationId != null) {
      themes['$userKey:conversation:$conversationId'] =
          jsonDecode(json) as Map<String, dynamic>;
    }
    if (applyToAll || conversationId == null) {
      themes['$userKey:all'] = jsonDecode(json) as Map<String, dynamic>;
    }
    await preferences.setString(_preferencesKey, jsonEncode(themes));
  }

  Future<String> copyGalleryImage({
    required String? userId,
    required int? conversationId,
    required String sourcePath,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final userKey =
        (userId?.trim().isNotEmpty == true ? userId!.trim() : _defaultUserKey)
            .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final conversationKey = conversationId?.toString() ?? 'all';
    final targetDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}chat_themes'
      '${Platform.pathSeparator}$userKey'
      '${Platform.pathSeparator}$conversationKey',
    );
    await targetDirectory.create(recursive: true);
    final extension = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.')).toLowerCase()
        : '.jpg';
    final target = File(
      '${targetDirectory.path}${Platform.pathSeparator}wallpaper.bkup$extension',
    );
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  Map<String, dynamic> _readThemes(SharedPreferences preferences) {
    final value = preferences.getString(_preferencesKey);
    if (value == null) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } on FormatException {
      return <String, dynamic>{};
    }
  }
}
