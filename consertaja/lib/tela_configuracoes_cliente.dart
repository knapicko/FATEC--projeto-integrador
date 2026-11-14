import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'editar_informacoes.dart';
import 'perguntas_frequentes.dart';
import 'services/app_settings_controller.dart';
import 'tela_inicial.dart';
import 'utils/iniciais.dart';

class TelaConfiguracoesClientePage extends StatefulWidget {
  const TelaConfiguracoesClientePage({super.key});

  @override
  State<TelaConfiguracoesClientePage> createState() =>
      _TelaConfiguracoesClientePageState();
}

Widget _avatarInitials(String initials) {
  return Text(
    initials,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _TelaConfiguracoesClientePageState
    extends State<TelaConfiguracoesClientePage> {
  static const Color _blue = Color(0xFF15B3EF);
  static const Color _blueDark = Color(0xFF087BAE);
  static const Color _background = Color(0xFFF8F8F8);
  static const Color _mutedBackground = Color(0xFFF3F3F4);

  static const List<String> _fontSizes = [
    'Pequeno',
    'Padrão',
    'Médio',
    'Grande',
    'Extra',
  ];

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  // As configurações vivem no AppSettingsController (lido do arquivo de
  // sistema consertaja_settings_cliente.json) para valerem no app inteiro.
  AppSettingsController get _controller => AppSettingsController.instance;
  Map<String, dynamic> get _settings => _controller.settings;
  String _name = 'Cliente';
  String _email = 'E-mail não informado';
  String? _photoUrl;
  String _search = '';
  String? _profileLoadError;
  bool _isLoading = true;
  bool _cacheCleared = false;

  // O modo escuro agora é aplicado globalmente (filtro no MaterialApp), então
  // esta tela é desenhada no tema claro e escurece junto com o resto do app.
  bool get _isDark => false;
  Color get _cardColor => _isDark ? const Color(0xFF202124) : Colors.white;
  Color get _primaryText =>
      _isDark ? const Color(0xFFF5F5F5) : const Color(0xFF202124);
  Color get _secondaryText => _settings['accessibility.highContrast'] == true
      ? (_isDark ? Colors.white : const Color(0xFF333333))
      : (_isDark ? const Color(0xFFBDBDBD) : const Color(0xFF6D7075));
  Color get _surfaceColor =>
      _isDark ? const Color(0xFF303236) : _mutedBackground;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSettingsChanged);
    unawaited(_loadSettingsAndProfile());
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onSettingsChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSettingsAndProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    var name = (metadata['full_name'] ?? metadata['name'] ?? metadata['nome'])
        ?.toString();
    var photo = (metadata['avatar_url'] ?? metadata['picture'])?.toString();

    try {
      await _controller.recarregar();
    } catch (error) {
      _showMessage('Não foi possível carregar as configurações locais: $error');
    }

    if (user != null) {
      try {
        final profile = await Supabase.instance.client
            .from('usuarios')
            .select('nome, foto_perfil_url')
            .eq('auth_id', user.id)
            .maybeSingle();
        name = profile?['nome']?.toString() ?? name;
        photo = profile?['foto_perfil_url']?.toString() ?? photo;
      } catch (error) {
        _profileLoadError = error.toString();
      }
    }

    if (!mounted) return;
    setState(() {
      _name = name?.trim().isNotEmpty == true ? name!.trim() : 'Cliente';
      _email = user?.email ?? 'E-mail não informado';
      _photoUrl = photo;
      _isLoading = false;
    });
    if (_profileLoadError != null) {
      _showMessage(
        'Não foi possível atualizar a foto e o nome do perfil: '
        '$_profileLoadError',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveSettings() {
    return _controller.salvarAgora().catchError((Object error) {
      _showMessage(
        'Não foi possível salvar a configuração no dispositivo: $error',
      );
    });
  }

  void _updateSetting(String key, Object value) {
    unawaited(
      _controller.atualizar(key, value).catchError((Object error) {
        _showMessage(
          'Não foi possível salvar a configuração no dispositivo: $error',
        );
      }),
    );
  }

  bool _matches(String text) =>
      _search.trim().isEmpty ||
      text.toLowerCase().contains(_search.trim().toLowerCase());

  _SettingEntry _switchEntry({
    required String key,
    required String title,
    required String description,
    bool initialValue = false,
    bool enabled = true,
    String? footnote,
  }) {
    final value = (_settings[key] as bool?) ?? initialValue;
    return _SettingEntry(
      title: title,
      description: description,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: _switchRow(
          title: title,
          description: description,
          value: value,
          enabled: enabled,
          footnote: footnote,
          onChanged: (newValue) => _updateSetting(key, newValue),
        ),
      ),
    );
  }

  _SettingEntry _choiceEntry({
    required String title,
    required String description,
    required String settingKey,
    required List<String> options,
    int columns = 2,
  }) {
    final selected = (_settings[settingKey] as String?) ?? options.first;
    return _SettingEntry(
      title: title,
      description: description,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _rowTitleStyle),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth =
                    (constraints.maxWidth - 8 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((option) {
                    final isSelected = selected == option;
                    return SizedBox(
                      width: itemWidth,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () => _updateSetting(settingKey, option),
                        child: AnimatedContainer(
                          duration:
                              _settings['accessibility.reduceMotion'] == true
                              ? Duration.zero
                              : const Duration(milliseconds: 150),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? _blue : _surfaceColor,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(
                            option,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? Colors.white : _primaryText,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  _SettingEntry _actionEntry({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    String? status,
    bool danger = false,
  }) {
    return _SettingEntry(
      title: title,
      description: description,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Icon(icon, color: danger ? Colors.red.shade600 : _blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: danger ? Colors.red.shade700 : _primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(description, style: _rowDescriptionStyle),
                  ],
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 6),
                _statusBadge(status),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: danger ? Colors.red.shade600 : _secondaryText,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SettingEntry _permissionEntry({
    required String title,
    required String description,
    required String status,
    VoidCallback? onTap,
    bool showManageButton = false,
  }) {
    return _SettingEntry(
      title: title,
      description: description,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _rowTitleStyle),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: onTap == null ? _secondaryText : _blueDark,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (showManageButton)
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    foregroundColor: _blueDark,
                    backgroundColor: _surfaceColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 34),
                  ),
                  child: Text(status),
                )
              else
                _statusBadge(status),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _rowTitleStyle => TextStyle(
    color: _primaryText,
    fontSize: 14,
    fontWeight: _settings['accessibility.boldText'] == true
        ? FontWeight.w700
        : FontWeight.w500,
    height: 1.25,
  );

  TextStyle get _rowDescriptionStyle => TextStyle(
    color: _secondaryText,
    fontSize: 12,
    height: 1.3,
    letterSpacing: _settings['accessibility.readability'] == true ? 0.12 : 0,
  );

  Widget _statusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF34445C) : const Color(0xFFDCE6F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: _primaryText,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool enabled = true,
    String? footnote,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _rowTitleStyle),
                const SizedBox(height: 2),
                Text(description, style: _rowDescriptionStyle),
                if (footnote != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    footnote,
                    style: const TextStyle(
                      color: _blueDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: Colors.white,
            activeTrackColor: _blue,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: _isDark
                ? const Color(0xFF55585C)
                : const Color(0xFFE0E0E0),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<_SettingEntry> entries,
    String? badge,
  }) {
    final sectionMatches = _matches('$title $subtitle');
    final visibleEntries = entries
        .where(
          (entry) =>
              _search.isEmpty ||
              sectionMatches ||
              _matches('${entry.title} ${entry.description}'),
        )
        .toList();
    if (visibleEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.12 : 0.025),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _isDark
                      ? const Color(0xFF34445C)
                      : const Color(0xFFDDE7F7),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _blue, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: _rowDescriptionStyle),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...visibleEntries.map((entry) => entry.child),
        ],
      ),
    );
  }

  Widget _profileCard() {
    final initials = obterIniciais(_name);
    final image = _photoUrl?.trim().isNotEmpty == true
        ? Image.network(
            _photoUrl!,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallbackAvatar(initials),
          )
        : _fallbackAvatar(initials);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipOval(child: image),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified, color: _blue, size: 19),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _statusBadge('Verificada'),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _rowDescriptionStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _surfaceColor,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Editar perfil',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditarInformacoesPage(),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, color: _blue, size: 19),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(String initials) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF30465B),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  _SettingEntry _fontSizeEntry() {
    final value =
        ((_settings['accessibility.fontSize'] as num?)?.toDouble() ?? 1)
            .clamp(0, 4)
            .toDouble();
    final selected = value.round();
    return _SettingEntry(
      title: 'Tamanho da fonte',
      description: _fontSizes[selected],
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Tamanho da fonte', style: _rowTitleStyle),
                const Spacer(),
                Text(
                  _fontSizes[selected],
                  style: const TextStyle(
                    color: _blueDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: 0,
              max: 4,
              divisions: 4,
              activeColor: _blue,
              inactiveColor: _isDark
                  ? const Color(0xFF52565B)
                  : const Color(0xFFD9D9D9),
              onChanged: (newValue) => _controller.atualizar(
                'accessibility.fontSize',
                newValue.round(),
                salvar: false,
              ),
              onChangeEnd: (_) => unawaited(_saveSettings()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _fontSizes
                  .map(
                    (size) => Text(
                      size,
                      style: TextStyle(color: _secondaryText, fontSize: 9),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  _SettingEntry _themeEntry() {
    const themes = [
      ('Claro', Icons.wb_sunny_outlined),
      ('Escuro', Icons.nightlight_round),
      ('Sistema', Icons.devices_outlined),
    ];
    final selected = (_settings['appearance.theme'] as String?) ?? 'Claro';
    return _SettingEntry(
      title: 'Tema visual',
      description: 'Tema visual do ConsertaJá',
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: themes.map((theme) {
            final isSelected = selected == theme.$1;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => _updateSetting('appearance.theme', theme.$1),
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: isSelected ? _blueDark : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      children: [
                        if (isSelected)
                          const Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              Icons.check_circle,
                              color: _blue,
                              size: 16,
                            ),
                          ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                theme.$2,
                                color: isSelected ? _blue : _secondaryText,
                                size: 22,
                              ),
                              const SizedBox(height: 7),
                              Text(
                                theme.$1,
                                style: TextStyle(
                                  color: isSelected ? _blueDark : _primaryText,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _openAppPermissions() async {
    try {
      final opened = await openAppSettings();
      if (!mounted) return;
      _showMessage(
        opened
            ? 'Configurações de permissões do aplicativo abertas.'
            : 'Não foi possível abrir as configurações do aplicativo.',
      );
    } catch (error) {
      _showMessage('Erro ao abrir as permissões do aplicativo: $error');
    }
  }

  Future<void> _openHelp() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PerguntasFrequentesPage()),
    );
  }

  Future<void> _showSupportDialog({
    required bool report,
    bool complaint = false,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          complaint
              ? 'Denunciar usuário ou prestador'
              : report
              ? 'Reportar um problema'
              : 'Falar com suporte',
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report
                    ? 'Descreva o ocorrido. O relato ficará salvo neste dispositivo; o envio para a equipe de moderação ainda não está integrado.'
                    : 'O atendimento por chat ainda não está integrado. Você pode registrar uma mensagem local para não perder o relato.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Escreva sua mensagem',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Digite uma mensagem.'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            child: const Text('Salvar neste dispositivo'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (submitted == null) return;
    final reports = (_settings['local.supportReports'] as List?) ?? [];
    await _controller.atualizar('local.supportReports', [
      ...reports,
      {
        'kind': complaint
            ? 'denuncia'
            : report
            ? 'problema'
            : 'suporte',
        'message': submitted,
        'createdAt': DateTime.now().toIso8601String(),
      },
    ], salvar: false);
    await _saveSettings();
  }

  Future<void> _clearTemporaryCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar cache do aplicativo?'),
        content: const Text(
          'Somente arquivos temporários do ConsertaJá serão removidos. '
          'Seus dados da conta e configurações não serão apagados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final temp = await getTemporaryDirectory();
      final cacheDirectory = Directory(temp.path);
      if (await cacheDirectory.exists()) {
        await for (final entity in cacheDirectory.list()) {
          await entity.delete(recursive: true);
        }
      }
      if (!mounted) return;
      setState(() => _cacheCleared = true);
      _showMessage('Arquivos temporários removidos.');
    } catch (error) {
      _showMessage('Não foi possível limpar os arquivos temporários: $error');
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Deseja realmente sair da sua conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TelaInicial()),
        (_) => false,
      );
    } catch (error) {
      _showMessage('Não foi possível sair da conta: $error');
    }
  }

  List<_SettingEntry> _notificationEntries() {
    final masterEnabled = _settings['notifications.enabled'] == true;
    return [
      _switchEntry(
        key: 'notifications.enabled',
        title: 'Receber notificações',
        description: 'Chave mestre de envio',
        initialValue: true,
      ),
      _switchEntry(
        key: 'notifications.orders',
        title: 'Atualizações de pedidos',
        description: 'Avisos sobre status, chegadas e orçamentos',
        initialValue: true,
        enabled: masterEnabled,
      ),
      _switchEntry(
        key: 'notifications.messages',
        title: 'Novas mensagens no chat',
        description: 'Mensagens diretas de técnicos',
        initialValue: true,
        enabled: masterEnabled,
      ),
      _switchEntry(
        key: 'notifications.payments',
        title: 'Atualizações de pagamentos',
        description: 'Aprovação de PIX, recibos e estornos',
        initialValue: true,
        enabled: masterEnabled,
      ),
      _switchEntry(
        key: 'notifications.reminders',
        title: 'Lembretes de serviços',
        description: 'Lembretes de agendamentos próximos',
        initialValue: true,
        enabled: masterEnabled,
      ),
      _switchEntry(
        key: 'notifications.promotions',
        title: 'Promoções e novidades',
        description: 'Descontos e cupons para manutenção',
        initialValue: false,
        enabled: masterEnabled,
      ),
      _switchEntry(
        key: 'notifications.sound',
        title: 'Sons de notificação',
        description: 'Toque: Padrão ConsertaJá',
        initialValue: true,
        enabled: masterEnabled,
      ),
      _switchEntry(
        key: 'notifications.vibration',
        title: 'Vibração háptica',
        description: 'Feedback tátil ao receber avisos',
        initialValue: true,
        enabled: masterEnabled,
      ),
    ];
  }

  List<_SettingEntry> _accessibilityEntries() => [
    _fontSizeEntry(),
    _switchEntry(
      key: 'accessibility.boldText',
      title: 'Texto em negrito',
      description: '',
    ),
    _switchEntry(
      key: 'accessibility.highContrast',
      title: 'Alto contraste',
      description: '',
    ),
    _choiceEntry(
      title: 'Modo para daltônicos',
      description: 'Filtro de espectro',
      settingKey: 'accessibility.colorFilter',
      options: ['Desativado', 'Protanopia', 'Deuteranopia', 'Tritanopia'],
    ),
    _switchEntry(
      key: 'accessibility.reduceMotion',
      title: 'Reduzir animações',
      description: 'Minimiza efeitos de transição',
    ),
    _switchEntry(
      key: 'accessibility.reduceTransparency',
      title: 'Reduzir transparências',
      description: 'Elimina desfoques e vidros',
    ),
    _switchEntry(
      key: 'accessibility.readability',
      title: 'Melhorar legibilidade',
      description: 'Espaçamento dinâmico entre caracteres',
      initialValue: true,
    ),
  ];

  List<_SettingEntry> _privacyEntries() => [
    _permissionEntry(
      title: 'Permissão de localização',
      description: 'Permitido durante o uso',
      status: 'Gerenciar',
      onTap: _openAppPermissions,
      showManageButton: true,
    ),
    _permissionEntry(
      title: 'Permissão de câmera',
      description: 'Fotos de defeitos, laudos e vistorias',
      status: 'Permitido',
      onTap: _openAppPermissions,
    ),
    _permissionEntry(
      title: 'Permissão de fotos e arquivos',
      description: 'Envio de notas fiscais e comprovantes',
      status: 'Permitido',
      onTap: _openAppPermissions,
    ),
    _switchEntry(
      key: 'privacy.personalizedOffers',
      title: 'Personalização de ofertas',
      description: 'Serviços recomendados baseados no seu histórico',
      initialValue: true,
    ),
    _switchEntry(
      key: 'privacy.analytics',
      title: 'Compartilhamento de dados para análises',
      description: 'Estatísticas anônimas de uso e desempenho (LGPD)',
    ),
  ];

  List<_SettingEntry> _networkEntries() => [
    _switchEntry(
      key: 'network.dataSaver',
      title: 'Economia de dados',
      description: 'Reduz a qualidade das imagens em 4G/5G',
    ),
    _choiceEntry(
      title: 'Carregamento automático de imagens',
      description: '',
      settingKey: 'network.imageLoading',
      options: ['Sempre', 'Somente Wi-Fi', 'Nunca'],
      columns: 3,
    ),
    _switchEntry(
      key: 'network.videoAutoplay',
      title: 'Reprodução automática de vídeos',
      description: 'Apenas em redes Wi-Fi',
      initialValue: true,
    ),
    _SettingEntry(
      title: 'Limpar cache do aplicativo',
      description: 'Arquivos temporários',
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Limpar cache do aplicativo', style: _rowTitleStyle),
                  const SizedBox(height: 3),
                  Text(
                    _cacheCleared
                        ? '0 MB ocupados em arquivos temporários'
                        : '142 MB ocupados em arquivos temporários',
                    style: _rowDescriptionStyle,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _clearTemporaryCache,
              style: TextButton.styleFrom(
                foregroundColor: _blueDark,
                backgroundColor: _cardColor,
              ),
              child: const Text('Limpar'),
            ),
          ],
        ),
      ),
    ),
  ];

  List<_SettingEntry> _helpEntries() => [
    _actionEntry(
      title: 'Central de ajuda',
      description: 'Guia de uso e políticas de garantia',
      icon: Icons.support_agent_outlined,
      onTap: _openHelp,
    ),
    _actionEntry(
      title: 'Perguntas frequentes (FAQ)',
      description: 'Dúvidas comuns sobre técnicos e pagamentos',
      icon: Icons.quiz_outlined,
      onTap: _openHelp,
    ),
    _actionEntry(
      title: 'Falar com suporte',
      description: 'Chat humano com tempo médio de resposta de 2 min',
      icon: Icons.chat_bubble_outline,
      status: 'Online',
      onTap: () => _showSupportDialog(report: false),
    ),
    _actionEntry(
      title: 'Reportar um problema',
      description: 'Envie diagnóstico de erro ou falhas no aplicativo',
      icon: Icons.bug_report_outlined,
      onTap: () => _showSupportDialog(report: true),
    ),
    _actionEntry(
      title: 'Denunciar usuário ou prestador',
      description: 'Canal seguro e anônimo para moderação',
      icon: Icons.flag_outlined,
      danger: true,
      onTap: () => _showSupportDialog(report: true, complaint: true),
    ),
  ];

  Widget _footer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surfaceColor,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(9),
            child: Image.asset(
              'assets/images/icone/icone_consertaja.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.shield_outlined, color: _blue, size: 24),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ConsertaJá',
            style: TextStyle(
              color: _primaryText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Versão 2.14.0 (Build 412) • Canal Oficial',
            textAlign: TextAlign.center,
            style: _rowDescriptionStyle,
          ),
          const SizedBox(height: 7),
          Text(
            'Seus dados e sessões estão protegidos por criptografia de ponta a ponta.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _secondaryText, fontSize: 10, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sair da conta'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFDCD9),
                foregroundColor: const Color(0xFFA61B1B),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final initials = obterIniciais(_name);
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(
          bottom: BorderSide(
            color: _isDark ? const Color(0xFF35383C) : const Color(0xFFEDEDED),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, color: _blue, size: 22),
          ),
          Expanded(
            child: Text(
              'Configurações',
              style: TextStyle(
                color: _primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Buscar configuração',
            onPressed: () => _searchFocus.requestFocus(),
            icon: Icon(Icons.search, color: _primaryText, size: 22),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditarInformacoesPage()),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _blue,
              child: _photoUrl?.trim().isNotEmpty == true
                  ? ClipOval(
                      child: Image.network(
                        _photoUrl!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _avatarInitials(initials),
                      ),
                    )
                  : _avatarInitials(initials),
            ),
          ),
          const SizedBox(width: 3),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (value) => setState(() => _search = value),
        style: TextStyle(color: _primaryText, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Buscar configuração, som, privacidade...',
          hintStyle: TextStyle(color: _secondaryText, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: _blue, size: 20),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar busca',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                  icon: Icon(Icons.close, color: _secondaryText, size: 18),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _settingsBody() {
    final sections = [
      _section(
        title: '1. Notificações',
        subtitle: 'Controle total de alertas e avisos',
        icon: Icons.notifications_active_outlined,
        badge: '8 ATIVOS',
        entries: _notificationEntries(),
      ),
      _section(
        title: '2. Acessibilidade',
        subtitle: 'Conforto visual e ergonomia de uso',
        icon: Icons.accessibility_new,
        entries: _accessibilityEntries(),
      ),
      _section(
        title: '3. Aparência',
        subtitle: 'Tema visual do ConsertaJá',
        icon: Icons.palette_outlined,
        entries: [_themeEntry()],
      ),
      _section(
        title: '4. Privacidade',
        subtitle: 'Permissões de hardware e diretrizes LGPD',
        icon: Icons.privacy_tip_outlined,
        entries: _privacyEntries(),
      ),
      _section(
        title: '5. Segurança',
        subtitle: 'Biometria e travas de proteção do app',
        icon: Icons.fingerprint,
        entries: [
          _switchEntry(
            key: 'security.biometrics',
            title: 'Login por biometria',
            description: 'Face ID / Impressão digital configurada',
            initialValue: true,
          ),
          _switchEntry(
            key: 'security.requireAuthentication',
            title: 'Solicitar autenticação ao abrir o aplicativo',
            description: 'Pede biometria sempre que alternar de tela',
            initialValue: true,
          ),
          _choiceEntry(
            title: 'Bloqueio automático do aplicativo',
            description: '',
            settingKey: 'security.autoLock',
            options: ['Imediatamente', 'Após 1 min', 'Após 5 min'],
            columns: 3,
          ),
          _switchEntry(
            key: 'security.showNotificationContent',
            title: 'Mostrar conteúdo das notificações',
            description: 'Oculto na tela de bloqueio do celular',
          ),
        ],
      ),
      _section(
        title: '6. Preferências de uso',
        subtitle: 'Comportamento de busca e confirmações',
        icon: Icons.tune,
        entries: [
          _switchEntry(
            key: 'preferences.useCurrentLocation',
            title: 'Usar localização atual automaticamente',
            description: 'Encontra técnicos e oficinas mais próximas',
            initialValue: true,
          ),
          _switchEntry(
            key: 'preferences.confirmRequest',
            title: 'Confirmar antes de enviar solicitações',
            description: 'Exibe revisão antes de disparar orçamento',
            initialValue: true,
          ),
          _switchEntry(
            key: 'preferences.confirmCancel',
            title: 'Confirmar antes de cancelar pedidos',
            description: 'Evita cancelamento acidental com técnicos a caminho',
            initialValue: true,
          ),
          _switchEntry(
            key: 'preferences.showTips',
            title: 'Exibir dicas de utilização',
            description: 'Caixas tutoriais nas páginas de serviço',
          ),
        ],
      ),
      _section(
        title: '7. Rede e dados',
        subtitle: 'Consumo de franquia e armazenamento local',
        icon: Icons.wifi,
        entries: _networkEntries(),
      ),
      _section(
        title: '8. Ajuda e suporte',
        subtitle: 'Atendimento, central e denúncias',
        icon: Icons.help_outline,
        entries: _helpEntries(),
      ),
    ];
    final hasResults = sections.any((section) => section is! SizedBox);

    // Fonte/negrito/contraste já vêm do MaterialApp (AppSettingsController).
    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF151619) : _background,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _blue))
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        _profileCard(),
                        _searchBar(),
                        if (_search.isNotEmpty && !hasResults)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                            child: Text(
                              'Nenhuma configuração encontrada.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _secondaryText),
                            ),
                          ),
                        ...sections,
                        _footer(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _settingsBody();
}

class _SettingEntry {
  final String title;
  final String description;
  final Widget child;

  const _SettingEntry({
    required this.title,
    required this.description,
    required this.child,
  });
}
