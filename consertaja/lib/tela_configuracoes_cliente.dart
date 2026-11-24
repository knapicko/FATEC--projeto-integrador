import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'atualizar_senha.dart';
import 'editar_informacoes.dart';
import 'meus_enderecos.dart';
import 'perguntas_frequentes.dart';
import 'politica_de_privacidade.dart';
import 'services/app_settings_controller.dart';
import 'services/biometria_service.dart';
import 'services/rede_service.dart';
import 'sobre_conserta_ja.dart';
import 'tela_inicial.dart';
import 'termos_de_uso.dart';
import 'tutorial/botao_ajuda.dart';
import 'tutorial/tutorial.dart';
import 'tutorial/tutorial_visto.dart';
import 'utils/iniciais.dart';
import 'utils/movimento.dart';
import 'widgets/dialogo_sheet.dart';
import 'widgets/imagem_app.dart';
import 'widgets/skeleton_loading.dart';

/// Versão mostrada no rodapé das configurações.
const String kVersaoApp = '0.6.2';

class TelaConfiguracoesClientePage extends StatefulWidget {
  const TelaConfiguracoesClientePage({super.key});

  @override
  State<TelaConfiguracoesClientePage> createState() =>
      _TelaConfiguracoesClientePageState();
}

/// As 8 seções. A tela principal mostra cada uma como uma opção; ao tocar,
/// abre a página da seção (neste mesmo arquivo).
enum _Secao {
  notificacoes(
    'Notificações',
    'Quais avisos receber e como',
    Icons.notifications_active_outlined,
  ),
  acessibilidade(
    'Acessibilidade',
    'Texto, contraste, cores e animações',
    Icons.accessibility_new,
  ),
  aparencia(
    'Aparência',
    'Tema claro ou escuro e densidade',
    Icons.palette_outlined,
  ),
  privacidade(
    'Privacidade',
    'Permissões do celular e seus dados',
    Icons.privacy_tip_outlined,
  ),
  seguranca('Segurança', 'Biometria, senha e aparelhos', Icons.fingerprint),
  preferencias('Preferências de uso', 'Localização e confirmações', Icons.tune),
  rede('Rede e dados', 'Imagens, vídeos e armazenamento', Icons.wifi),
  ajuda(
    'Ajuda e suporte',
    'Central, tutoriais e denúncias',
    Icons.help_outline,
  );

  const _Secao(this.titulo, this.subtitulo, this.icone);

  final String titulo;
  final String subtitulo;
  final IconData icone;
}

class _TelaConfiguracoesClientePageState
    extends State<TelaConfiguracoesClientePage>
    with WidgetsBindingObserver {
  // Azul primário do app (o mesmo da home e do Meu Perfil).
  static const Color _blue = Color(0xFF0FB3FF);
  static const Color _blueDark = Color(0xFF087BAE);
  static const Color _background = Color(0xFFF8F9FA);
  static const Color _mutedBackground = Color(0xFFF1F3F5);
  static const Color _primaryText = Color(0xFF202124);
  static const Color _cardColor = Colors.white;

  static const List<String> _fontSizes = [
    'Pequeno',
    'Padrão',
    'Médio',
    'Grande',
    'Extra',
  ];

  static const _chaveBuscasRecentes = 'buscas_recentes_cliente';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// Avisa as páginas das seções quando algo local muda (permissões, cache…).
  final ValueNotifier<int> _mudou = ValueNotifier<int>(0);

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
  int? _cacheBytes;
  final Map<Permission, PermissionStatus> _permStatus = {};

  Color get _secondaryText => _settings['accessibility.highContrast'] == true
      ? const Color(0xFF333333)
      : const Color(0xFF6D7075);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onSettingsChanged);
    unawaited(RedeService.instance.iniciar());
    unawaited(_loadSettingsAndProfile());
    unawaited(_carregarPermissoes());
    unawaited(_calcularCache());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Voltou das configurações do celular: relê as permissões.
    if (state == AppLifecycleState.resumed) unawaited(_carregarPermissoes());
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _atualizarTela() {
    if (!mounted) return;
    setState(() {});
    _mudou.value++;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onSettingsChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _mudou.dispose();
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

  // ───────────────────────────────────────────────────────── Estilos

  TextStyle get _rowTitleStyle => TextStyle(
    color: _primaryText,
    fontSize: 16,
    fontWeight: _settings['accessibility.boldText'] == true
        ? FontWeight.w700
        : FontWeight.w600,
    height: 1.25,
  );

  TextStyle get _rowDescriptionStyle =>
      TextStyle(color: _secondaryText, fontSize: 13.5, height: 1.35);

  Widget _statusBadge(String text, {Color? cor, Color? fundo}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: fundo ?? const Color(0xFFDCEFFA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cor ?? _blueDark,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Ícone branco sobre o azul primário (opções e seções).
  Widget _iconeAzul(IconData icone, {double tamanho = 44, Color? cor}) {
    // Modo escuro: o azul e o ícone branco mantêm as cores.
    return CorOriginal(
      interface: true,
      child: Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: cor ?? _blue,
          borderRadius: BorderRadius.circular(tamanho * 0.3),
        ),
        child: Icon(icone, color: Colors.white, size: tamanho * 0.55),
      ),
    );
  }

  // ───────────────────────────────────────────────────────── Linhas

  _SettingEntry _switchEntry({
    required String key,
    required String title,
    required String description,
    bool enabled = true,
    String? footnote,
    ValueChanged<bool>? onChanged,
  }) {
    final value = (_settings[key] as bool?) ?? false;
    return _SettingEntry(
      title: title,
      description: description,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _rowTitleStyle),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(description, style: _rowDescriptionStyle),
                    ],
                    if (footnote != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        footnote,
                        style: const TextStyle(
                          color: _blueDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CorOriginal(interface: true, ativo: value, child: Switch.adaptive(
                value: value,
                onChanged: enabled
                    ? (onChanged ?? (v) => _updateSetting(key, v))
                    : null,
                activeThumbColor: Colors.white,
                activeTrackColor: _blue,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFDADDE1),
              )),
            ],
          ),
        ),
      ),
    );
  }

  _SettingEntry _choiceEntry({
    required String title,
    required String description,
    required String settingKey,
    required List<String> options,
    String? padrao,
    int columns = 2,
  }) {
    final selected =
        (_settings[settingKey] as String?) ?? padrao ?? options.first;
    return _SettingEntry(
      title: title,
      description: description,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _rowTitleStyle),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(description, style: _rowDescriptionStyle),
            ],
            const SizedBox(height: 10),
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
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _updateSetting(settingKey, option),
                        child: CorOriginal(interface: true, ativo: isSelected, child: AnimatedContainer(
                          duration: duracao(const Duration(milliseconds: 150)),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? _blue : _mutedBackground,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            option,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? Colors.white : _primaryText,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        )),
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
    Color? statusCor,
    Color? statusFundo,
    bool danger = false,
  }) {
    return _SettingEntry(
      title: title,
      description: description,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              _iconeAzul(
                icon,
                tamanho: 38,
                cor: danger ? Colors.red.shade500 : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _rowTitleStyle.copyWith(
                        color: danger ? Colors.red.shade700 : null,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(description, style: _rowDescriptionStyle),
                    ],
                  ],
                ),
              ),
              if (status != null) ...[
                const SizedBox(width: 8),
                _statusBadge(status, cor: statusCor, fundo: statusFundo),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: danger ? Colors.red.shade600 : const Color(0xFFB0B0B0),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SettingEntry _subtitulo(String texto) => _SettingEntry(
    title: '',
    description: '',
    child: Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 2),
        child: Text(
          texto.toUpperCase(),
          style: TextStyle(
            color: _secondaryText,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    ),
  );

  _SettingEntry _aviso(String texto, {IconData icone = Icons.info_outline}) =>
      _SettingEntry(
        title: '',
        description: '',
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6FD),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: _blueDark, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(
                    color: _blueDark,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // ───────────────────────────────────────────────────────── 1. Notificações

  List<_SettingEntry> _notificationEntries() {
    final ligado = _settings['notifications.enabled'] == true;
    _SettingEntry tipo(String key, String title, String desc) => _switchEntry(
      key: key,
      title: title,
      description: desc,
      enabled: ligado,
    );
    final perm = _permStatus[Permission.notification];
    return [
      _switchEntry(
        key: 'notifications.enabled',
        title: 'Receber notificações',
        description: 'Desligado, nenhum aviso aparece no celular',
      ),
      if (perm != null && !perm.isGranted)
        _actionEntry(
          title: 'Notificações bloqueadas no celular',
          description: 'Toque para permitir nas configurações do sistema',
          icon: Icons.notifications_off_outlined,
          danger: true,
          onTap: () => _tocarPermissao(Permission.notification),
        ),
      _subtitulo('O que avisar'),
      tipo(
        'notifications.orders',
        'Pedidos e etapas',
        'Novos pedidos, mudanças de etapa, chegada e conclusão',
      ),
      tipo(
        'notifications.messages',
        'Mensagens do chat',
        'Novas mensagens nas suas conversas',
      ),
      tipo(
        'notifications.payments',
        'Pagamentos',
        'Pagamento confirmado, aguardando pagamento e estornos',
      ),
      tipo(
        'notifications.radar',
        'Radar e propostas',
        'Pedidos perto de você e respostas às propostas',
      ),
      tipo(
        'notifications.reminders',
        'Lembretes da conta',
        'Cadastro incompleto e avisos sobre a sua conta',
      ),
      tipo(
        'notifications.feedback',
        'Confirmações das suas ações',
        'Ex.: "Solicitação enviada!" logo depois de enviar',
      ),
      tipo(
        'notifications.promotions',
        'Novidades do ConsertaJá',
        'Avisos gerais, novidades e promoções',
      ),
      _subtitulo('Como avisar'),
      tipo('notifications.sound', 'Som', 'Toca o som padrão do celular'),
      tipo('notifications.vibration', 'Vibração', 'Vibra ao receber um aviso'),
      tipo(
        'notifications.quietHours',
        'Não perturbe à noite',
        'Das 22h às 7h os avisos chegam sem som e sem vibração',
      ),
      _aviso(
        'Os avisos desligados aqui continuam na tela de Notificações do app; '
        'só não aparecem no celular.',
      ),
    ];
  }

  // ───────────────────────────────────────────────────────── 2. Acessibilidade

  _SettingEntry _previaTexto() => _SettingEntry(
    title: 'Prévia',
    description: '',
    child: Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _mutedBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _iconeAzul(Icons.handyman_rounded, tamanho: 42),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prévia do texto',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Assim ficam os textos do app com as opções abaixo.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF55595E)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

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
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: _mutedBackground,
          borderRadius: BorderRadius.circular(16),
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
                    fontSize: 14,
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
              inactiveColor: const Color(0xFFD9D9D9),
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
                      style: TextStyle(color: _secondaryText, fontSize: 11),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<_SettingEntry> _accessibilityEntries() => [
    _previaTexto(),
    _fontSizeEntry(),
    _switchEntry(
      key: 'accessibility.boldText',
      title: 'Texto em negrito',
      description: 'Deixa os textos mais grossos',
    ),
    _switchEntry(
      key: 'accessibility.readability',
      title: 'Melhorar legibilidade',
      description: 'Mais espaço entre as letras e entre as palavras',
    ),
    _switchEntry(
      key: 'accessibility.highContrast',
      title: 'Alto contraste',
      description: 'Cores mais fortes e textos mais escuros',
    ),
    _switchEntry(
      key: 'accessibility.largerTargets',
      title: 'Botões maiores',
      description: 'Aumenta a área de toque de botões e campos',
    ),
    _choiceEntry(
      title: 'Modo para daltônicos',
      description: 'Ajusta as cores para o tipo de daltonismo',
      settingKey: 'accessibility.colorFilter',
      options: ['Desativado', 'Protanopia', 'Deuteranopia', 'Tritanopia'],
    ),
    _switchEntry(
      key: 'accessibility.reduceMotion',
      title: 'Reduzir animações',
      description:
          'Desliga transições, efeitos e animações do app (incluindo o '
          'tutorial)',
    ),
    _switchEntry(
      key: 'accessibility.reduceTransparency',
      title: 'Reduzir transparências',
      description: 'Troca desfoques e fundos transparentes por fundos sólidos',
    ),
  ];

  // ───────────────────────────────────────────────────────── 3. Aparência

  _SettingEntry _themeEntry() {
    const themes = [
      ('Claro', Icons.wb_sunny_outlined),
      ('Escuro', Icons.nightlight_round),
      ('Sistema', Icons.devices_outlined),
    ];
    final selected = (_settings['appearance.theme'] as String?) ?? 'Claro';
    return _SettingEntry(
      title: 'Tema',
      description: 'Claro, escuro ou igual ao do celular',
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tema', style: _rowTitleStyle),
            const SizedBox(height: 10),
            Row(
              children: themes.map((theme) {
                final isSelected = selected == theme.$1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _updateSetting('appearance.theme', theme.$1),
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: _mutedBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? _blue : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Stack(
                          children: [
                            if (isSelected)
                              const Positioned(
                                top: 7,
                                right: 7,
                                child: Icon(
                                  Icons.check_circle,
                                  color: _blue,
                                  size: 18,
                                ),
                              ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    theme.$2,
                                    color: isSelected ? _blue : _secondaryText,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    theme.$1,
                                    style: TextStyle(
                                      color: isSelected
                                          ? _blueDark
                                          : _primaryText,
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
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
          ],
        ),
      ),
    );
  }

  List<_SettingEntry> _appearanceEntries(BuildContext ctx) {
    final escuro = _controller.escuroAtivo(
      MediaQuery.platformBrightnessOf(ctx),
    );
    return [
      _themeEntry(),
      _switchEntry(
        key: 'appearance.dimImages',
        title: 'Escurecer fotos no modo escuro',
        description: 'Deixa fotos e ilustrações um pouco mais escuras à noite',
        enabled: escuro,
        footnote: escuro ? null : 'Disponível com o tema escuro ativo',
      ),
      _choiceEntry(
        title: 'Densidade da interface',
        description: 'Espaço entre botões, campos e listas',
        settingKey: 'appearance.density',
        options: ['Compacta', 'Padrão', 'Confortável'],
        padrao: 'Padrão',
        columns: 3,
      ),
      _aviso(
        'No modo escuro só os textos e os elementos mudam de cor: fotos, '
        'avatares e ilustrações mantêm as cores reais.',
        icone: Icons.palette_outlined,
      ),
    ];
  }

  // ───────────────────────────────────────────────────────── 4. Privacidade

  static final List<(String, String, IconData, Permission)> _permissoes = [
    (
      'Localização',
      'Achar profissionais perto de você e usar o Radar',
      Icons.location_on_outlined,
      Permission.locationWhenInUse,
    ),
    (
      'Câmera',
      'Fotos do problema, de documentos e da entrega',
      Icons.photo_camera_outlined,
      Permission.camera,
    ),
    (
      'Fotos e arquivos',
      'Enviar fotos da galeria e comprovantes',
      Icons.photo_library_outlined,
      Permission.photos,
    ),
    (
      'Microfone',
      'Mandar áudios no chat',
      Icons.mic_none_rounded,
      Permission.microphone,
    ),
    (
      'Notificações',
      'Avisos de pedidos, mensagens e pagamentos',
      Icons.notifications_none_rounded,
      Permission.notification,
    ),
  ];

  Future<void> _carregarPermissoes() async {
    for (final p in _permissoes) {
      try {
        _permStatus[p.$4] = await p.$4.status;
      } catch (_) {}
    }
    _atualizarTela();
  }

  (String, Color, Color) _textoStatus(PermissionStatus? s) {
    switch (s) {
      case PermissionStatus.granted:
        return ('Permitido', const Color(0xFF15803D), const Color(0xFFDCF5E3));
      case PermissionStatus.limited:
        return ('Parcial', const Color(0xFFB45309), const Color(0xFFFDF0D5));
      case PermissionStatus.provisional:
        return ('Provisório', const Color(0xFFB45309), const Color(0xFFFDF0D5));
      case PermissionStatus.permanentlyDenied:
        return ('Bloqueado', const Color(0xFFB91C1C), const Color(0xFFFDE2E2));
      case PermissionStatus.restricted:
        return ('Restrito', const Color(0xFFB91C1C), const Color(0xFFFDE2E2));
      case PermissionStatus.denied:
        return ('Não permitido', const Color(0xFF55595E), _mutedBackground);
      case null:
        return ('…', const Color(0xFF55595E), _mutedBackground);
    }
  }

  /// Não permitida → pede; permitida ou bloqueada → abre as configurações do
  /// celular (é lá que se tira ou libera de vez).
  Future<void> _tocarPermissao(Permission p) async {
    try {
      final atual = await p.status;
      if (atual.isDenied) {
        final novo = await p.request();
        _permStatus[p] = novo;
        _atualizarTela();
        if (!novo.isPermanentlyDenied) return;
      }
      await openAppSettings();
    } catch (error) {
      _showMessage('Não foi possível abrir as permissões: $error');
    }
  }

  Future<void> _limparHistoricoBusca() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chaveBuscasRecentes);
      _showMessage('Histórico de buscas apagado.');
    } catch (error) {
      _showMessage('Não foi possível apagar o histórico: $error');
    }
  }

  List<_SettingEntry> _privacyEntries() => [
    _subtitulo('Permissões do celular'),
    for (final p in _permissoes) _entradaPermissao(p),
    _aviso(
      'Toque em uma permissão para pedir ou para mudar nas configurações do '
      'celular.',
    ),
    _subtitulo('Seus dados'),
    _switchEntry(
      key: 'privacy.saveSearchHistory',
      title: 'Salvar buscas recentes',
      description: 'Mostra as suas últimas buscas na tela de busca',
    ),
    _actionEntry(
      title: 'Apagar histórico de buscas',
      description: 'Remove as buscas recentes deste celular',
      icon: Icons.history_rounded,
      onTap: _limparHistoricoBusca,
    ),
    _switchEntry(
      key: 'privacy.personalizedOffers',
      title: 'Personalização de ofertas',
      description: 'Serviços recomendados com base no seu histórico',
    ),
    _actionEntry(
      title: 'Política de privacidade',
      description: 'Como o ConsertaJá usa os seus dados',
      icon: Icons.policy_outlined,
      onTap: () => _abrir(const PoliticaDePrivacidadePage()),
    ),
  ];

  _SettingEntry _entradaPermissao((String, String, IconData, Permission) p) {
    final (texto, cor, fundo) = _textoStatus(_permStatus[p.$4]);
    return _actionEntry(
      title: p.$1,
      description: p.$2,
      icon: p.$3,
      status: texto,
      statusCor: cor,
      statusFundo: fundo,
      onTap: () => _tocarPermissao(p.$4),
    );
  }

  // ───────────────────────────────────────────────────────── 5. Segurança

  Future<void> _alternarBiometria(bool ligar) async {
    if (!ligar) {
      await BiometriaService.apagar();
      _updateSetting('security.biometrics', false);
      _showMessage('Login por biometria desativado.');
      return;
    }
    if (!await BiometriaService.disponivel()) {
      _showMessage(
        'Este celular não tem digital ou reconhecimento facial cadastrado.',
      );
      return;
    }
    if (!mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetBiometria(email: _email, nome: _name),
    );
    if (ok == true) {
      _updateSetting('security.biometrics', true);
      _showMessage('Pronto! Na próxima vez, entre com a biometria.');
    }
  }

  Future<void> _sairOutrosAparelhos() async {
    final confirmed = await mostrarDialogoComoSheet<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair dos outros aparelhos?'),
        content: const Text(
          'A sua conta será desconectada de todos os outros celulares. Este '
          'aparelho continua conectado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair dos outros'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.others);
      _showMessage('Os outros aparelhos foram desconectados.');
    } catch (error) {
      _showMessage('Não foi possível desconectar os outros aparelhos: $error');
    }
  }

  List<_SettingEntry> _securityEntries() => [
    _switchEntry(
      key: 'security.biometrics',
      title: 'Login por biometria',
      description:
          'Entre com a digital ou o rosto, sem digitar a senha, na última '
          'conta que ativou a opção neste celular',
      onChanged: (v) => unawaited(_alternarBiometria(v)),
    ),
    _switchEntry(
      key: 'security.showNotificationContent',
      title: 'Mostrar conteúdo das notificações',
      description:
          'Desligado, a tela de bloqueio mostra só que chegou um aviso e '
          'esconde o texto',
    ),
    _subtitulo('Acesso à conta'),
    _actionEntry(
      title: 'Alterar senha',
      description: 'Crie uma nova senha para entrar',
      icon: Icons.lock_reset_rounded,
      onTap: () => _abrir(const AtualizarSenhaPage()),
    ),
    _actionEntry(
      title: 'Sair dos outros aparelhos',
      description: 'Desconecta a sua conta dos outros celulares',
      icon: Icons.devices_other_rounded,
      onTap: _sairOutrosAparelhos,
    ),
  ];

  // ───────────────────────────────────────────────────────── 6. Preferências

  List<_SettingEntry> _preferenceEntries() => [
    _switchEntry(
      key: 'preferences.useCurrentLocation',
      title: 'Usar localização atual automaticamente',
      description:
          'Usa o GPS para achar profissionais perto de você. Desligado, usa '
          'o seu endereço cadastrado',
    ),
    _switchEntry(
      key: 'preferences.confirmRequest',
      title: 'Confirmar antes de enviar solicitações',
      description: 'Pergunta antes de enviar os pedidos da lista de serviços',
    ),
    _switchEntry(
      key: 'preferences.confirmCancel',
      title: 'Confirmar antes de cancelar pedidos',
      description: 'Evita cancelar um pedido ou um Radar sem querer',
    ),
    _switchEntry(
      key: 'preferences.showTips',
      title: 'Exibir dicas de utilização',
      description: 'Dicas rápidas nas páginas de serviço',
    ),
    _actionEntry(
      title: 'Meus endereços',
      description: 'Escolha o endereço principal usado nos pedidos',
      icon: Icons.location_city_rounded,
      onTap: () => _abrir(const MeusEnderecosPage()),
    ),
  ];

  // ───────────────────────────────────────────────────────── 7. Rede e dados

  static Future<int> _tamanhoPasta(Directory pasta) async {
    var total = 0;
    try {
      if (!await pasta.exists()) return 0;
      await for (final e in pasta.list(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            total += await e.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> _calcularCache() async {
    final memoria = PaintingBinding.instance.imageCache.currentSizeBytes;
    try {
      final temp = await getTemporaryDirectory();
      _cacheBytes = await _tamanhoPasta(temp) + memoria;
    } catch (_) {
      _cacheBytes = memoria;
    }
    _atualizarTela();
  }

  static String _formatarTamanho(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
    return '${mb.replaceAll('.', ',')} MB';
  }

  Future<void> _clearTemporaryCache() async {
    final confirmed = await mostrarDialogoComoSheet<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar cache do aplicativo?'),
        content: const Text(
          'Fotos guardadas e arquivos temporários do ConsertaJá serão '
          'removidos (voltam a ser baixados quando precisar). Sua conta e '
          'suas configurações não são apagadas.',
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

    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    var falhas = 0;
    try {
      final temp = await getTemporaryDirectory();
      if (await temp.exists()) {
        await for (final entity in temp.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {
            falhas++; // arquivo em uso: fica para a próxima
          }
        }
      }
    } catch (error) {
      _showMessage('Não foi possível limpar os arquivos temporários: $error');
    }
    await _calcularCache();
    _showMessage(
      falhas == 0
          ? 'Cache limpo.'
          : 'Cache limpo. Alguns arquivos em uso ficaram para depois.',
    );
  }

  List<_SettingEntry> _networkEntries() => [
    _SettingEntry(
      title: 'Conexão atual',
      description: RedeService.instance.descricao,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text('Conexão atual', style: _rowTitleStyle)),
            _statusBadge(RedeService.instance.descricao),
          ],
        ),
      ),
    ),
    _switchEntry(
      key: 'network.dataSaver',
      title: 'Economia de dados',
      description:
          'Nos dados móveis, as fotos só carregam quando você toca e os '
          'vídeos sempre perguntam antes de abrir',
    ),
    _choiceEntry(
      title: 'Carregamento automático de imagens',
      description: 'Quando não carregar, toque na imagem para ver',
      settingKey: 'network.imageLoading',
      options: ['Sempre', 'Somente Wi-Fi', 'Nunca'],
      padrao: 'Sempre',
      columns: 3,
    ),
    _switchEntry(
      key: 'network.videoAutoplay',
      title: 'Abrir vídeos sem perguntar',
      description:
          'Toca o vídeo direto. Desligado, pergunta antes (o vídeo pode '
          'gastar dados)',
    ),
    _SettingEntry(
      title: 'Limpar cache do aplicativo',
      description: 'Fotos guardadas e arquivos temporários',
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _mutedBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Limpar cache do aplicativo', style: _rowTitleStyle),
                  const SizedBox(height: 4),
                  Text(
                    _cacheBytes == null
                        ? 'Calculando o espaço usado…'
                        : '${_formatarTamanho(_cacheBytes!)} em fotos '
                              'guardadas e arquivos temporários',
                    style: _rowDescriptionStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CorOriginal(interface: true, child: FilledButton(
              onPressed: _clearTemporaryCache,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Limpar'),
            )),
          ],
        ),
      ),
    ),
  ];

  // ───────────────────────────────────────────────────────── 8. Ajuda

  void _abrir(Widget pagina) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pagina));
  }

  Future<void> _reverTutoriais() async {
    try {
      await TutorialVisto.resetar();
      _showMessage(
        'Pronto! Os tutoriais vão aparecer de novo quando você abrir cada tela.',
      );
    } catch (error) {
      _showMessage(
        'Os tutoriais voltam neste celular, mas não foi possível avisar o '
        'servidor: $error',
      );
    }
  }

  Future<void> _showSupportDialog({
    required bool report,
    bool complaint = false,
  }) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final submitted = await mostrarDialogoComoSheet<String>(
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
    _showMessage('Mensagem salva neste celular.');
  }

  List<_SettingEntry> _helpEntries() => [
    _actionEntry(
      title: 'Central de ajuda',
      description: 'Perguntas frequentes sobre pedidos, pagamentos e contas',
      icon: Icons.support_agent_outlined,
      onTap: () => _abrir(const PerguntasFrequentesPage()),
    ),
    _actionEntry(
      title: 'Rever os tutoriais',
      description: 'As explicações do primeiro acesso aparecem de novo',
      icon: Icons.school_outlined,
      onTap: _reverTutoriais,
    ),
    _actionEntry(
      title: 'Falar com suporte',
      description: 'Registre a sua dúvida',
      icon: Icons.chat_bubble_outline,
      onTap: () => _showSupportDialog(report: false),
    ),
    _actionEntry(
      title: 'Reportar um problema',
      description: 'Conte o que deu errado no aplicativo',
      icon: Icons.bug_report_outlined,
      onTap: () => _showSupportDialog(report: true),
    ),
    _actionEntry(
      title: 'Termos de uso',
      description: 'As regras do ConsertaJá',
      icon: Icons.description_outlined,
      onTap: () => _abrir(const TermosDeUsoPage()),
    ),
    _actionEntry(
      title: 'Sobre o ConsertaJá',
      description: 'Versão $kVersaoApp e informações do app',
      icon: Icons.info_outline_rounded,
      onTap: () => _abrir(const SobreConsertaJaPage()),
    ),
    _actionEntry(
      title: 'Denunciar usuário ou prestador',
      description: 'Canal seguro para a moderação',
      icon: Icons.flag_outlined,
      danger: true,
      onTap: () => _showSupportDialog(report: true, complaint: true),
    ),
  ];

  // ───────────────────────────────────────────────────────── Seções

  List<_SettingEntry> _entradas(_Secao s, BuildContext ctx) => switch (s) {
    _Secao.notificacoes => _notificationEntries(),
    _Secao.acessibilidade => _accessibilityEntries(),
    _Secao.aparencia => _appearanceEntries(ctx),
    _Secao.privacidade => _privacyEntries(),
    _Secao.seguranca => _securityEntries(),
    _Secao.preferencias => _preferenceEntries(),
    _Secao.rede => _networkEntries(),
    _Secao.ajuda => _helpEntries(),
  };

  /// Resumo à direita de cada opção da tela principal.
  String? _resumo(_Secao s) {
    switch (s) {
      case _Secao.notificacoes:
        if (_settings['notifications.enabled'] != true) return 'Desligadas';
        const tipos = [
          'orders',
          'messages',
          'payments',
          'radar',
          'reminders',
          'feedback',
          'promotions',
        ];
        final n = tipos
            .where((t) => _settings['notifications.$t'] == true)
            .length;
        return '$n de ${tipos.length}';
      case _Secao.aparencia:
        return (_settings['appearance.theme'] as String?) ?? 'Claro';
      case _Secao.seguranca:
        return _settings['security.biometrics'] == true ? 'Biometria' : null;
      case _Secao.rede:
        return _settings['network.dataSaver'] == true ? 'Economia' : null;
      default:
        return null;
    }
  }

  String _explicacao(_Secao s) => switch (s) {
    _Secao.notificacoes =>
      'Escolha quais avisos chegam no celular e se tocam som ou vibram.',
    _Secao.acessibilidade =>
      'Ajuste o tamanho e o peso do texto, as cores e as animações. A prévia '
          'no topo mostra o resultado na hora.',
    _Secao.aparencia =>
      'Escolha o tema claro, escuro ou o do celular, e o espaçamento da '
          'interface.',
    _Secao.privacidade =>
      'Veja quais permissões o app tem no celular e cuide dos seus dados.',
    _Secao.seguranca =>
      'Ative o login por biometria, troque a senha ou desconecte outros '
          'aparelhos.',
    _Secao.preferencias =>
      'Defina como o app usa a sua localização e quando pedir confirmação.',
    _Secao.rede =>
      'Economize dados móveis: escolha quando as imagens carregam e limpe o '
          'cache.',
    _Secao.ajuda => 'Tire dúvidas, reveja os tutoriais ou fale com a gente.',
  };

  /// Cartão branco com as linhas de uma seção.
  Widget _cartao(List<_SettingEntry> entries) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(18, 6, 14, 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: entries.map((e) => e.child).toList()),
    );
  }

  /// Seção filtrada pela busca (só aparece com texto na busca).
  Widget _secaoBusca(_Secao s) {
    final secaoBate = _matches('${s.titulo} ${s.subtitulo}');
    final visiveis = _entradas(s, context)
        .where(
          (e) =>
              e.title.isNotEmpty &&
              (secaoBate || _matches('${e.title} ${e.description}')),
        )
        .toList();
    if (visiveis.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: [
              _iconeAzul(s.icone, tamanho: 30),
              const SizedBox(width: 10),
              Text(
                s.titulo,
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _cartao(visiveis),
      ],
    );
  }

  void _abrirSecao(_Secao s) {
    if (s == _Secao.privacidade || s == _Secao.notificacoes) {
      unawaited(_carregarPermissoes());
    }
    if (s == _Secao.rede) unawaited(_calcularCache());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: Listenable.merge([
            _controller,
            _mudou,
            RedeService.instance,
          ]),
          builder: (pageContext, _) => Scaffold(
            backgroundColor: _background,
            body: SafeArea(
              child: Column(
                children: [
                  _header(
                    pageContext,
                    titulo: s.titulo,
                    ajuda: () => explicacaoDaTela(
                      pageContext,
                      tela: 'Aqui ficam as opções de ${s.titulo}.',
                      conteudo: [_explicacao(s)],
                      cabecalho: 64,
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      children: [_cartao(_entradas(s, pageContext))],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────── Tela principal

  Widget _opcaoSecao(_Secao s) {
    final resumo = _resumo(s);
    return InkWell(
      onTap: () => _abrirSecao(s),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            _iconeAzul(s.icone),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.titulo,
                    style: const TextStyle(
                      color: _primaryText,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(s.subtitulo, style: _rowDescriptionStyle),
                ],
              ),
            ),
            if (resumo != null) ...[
              const SizedBox(width: 8),
              Text(
                resumo,
                style: const TextStyle(
                  color: _blueDark,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB0B0B0),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  Widget _listaSecoes() {
    final itens = <Widget>[];
    for (final s in _Secao.values) {
      if (itens.isNotEmpty) {
        itens.add(
          const Divider(height: 1, indent: 74, color: Color(0xFFEDEFF1)),
        );
      }
      itens.add(_opcaoSecao(s));
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(children: itens),
      ),
    );
  }

  Widget _fallbackAvatar(String initials, double lado) {
    return Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF30465B),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: lado * 0.32,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _profileCard() {
    const lado = 62.0;
    final initials = obterIniciais(_name);
    final image = _photoUrl?.trim().isNotEmpty == true
        ? ImagemApp(
            child: Image.network(
              _photoUrl!,
              width: lado,
              height: lado,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallbackAvatar(initials, lado),
            ),
          )
        : _fallbackAvatar(initials, lado);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ClipOval(child: image),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _rowDescriptionStyle.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CorOriginal(interface: true, child: Material(
            color: _blue,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Editar perfil',
              onPressed: () => _abrir(const EditarInformacoesPage()),
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
            ),
          )),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(26),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (value) => setState(() => _search = value),
        style: const TextStyle(color: _primaryText, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Buscar configuração',
          hintStyle: TextStyle(color: _secondaryText, fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: _blue, size: 24),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar busca',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                  icon: Icon(Icons.close, color: _secondaryText, size: 20),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await mostrarDialogoComoSheet<bool>(
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

  Widget _footer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            // Logo branca: o círculo azul garante que ela apareça.
            decoration: const BoxDecoration(
              color: _blue,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(10),
            child: ImagemApp(
              child: Image.asset(
                'assets/images/icone/icone_consertaja.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.handyman_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'ConsertaJá',
            style: TextStyle(
              color: _primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Versão $kVersaoApp',
            textAlign: TextAlign.center,
            style: _rowDescriptionStyle,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text(
                'Sair da conta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFDCD9),
                foregroundColor: const Color(0xFFA61B1B),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext ctx, {
    required String titulo,
    required List<PassoTutorial> Function() ajuda,
  }) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: _cardColor,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.maybePop(ctx),
            icon: const Icon(Icons.arrow_back, color: _blue, size: 26),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _primaryText,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          BotaoAjuda(cor: _blue, tamanhoIcone: 26, passos: ajuda),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buscando = _search.trim().isNotEmpty;
    final resultados = buscando
        ? _Secao.values.map(_secaoBusca).toList()
        : const <Widget>[];
    final semResultados = buscando && resultados.every((w) => w is SizedBox);

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _header(
              context,
              titulo: 'Configurações',
              ajuda: () => explicacaoDaTela(
                context,
                tela: 'Estas são as configurações do app.',
                conteudo: const [
                  'Toque em uma seção para ver e mudar as opções dela.',
                  'Use a busca para achar uma opção pelo nome. Lá embaixo '
                      'fica o botão para sair da conta.',
                ],
                cabecalho: 64,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const SkeletonProfile()
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        _profileCard(),
                        _searchBar(),
                        if (semResultados)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                            child: Text(
                              'Nenhuma configuração encontrada.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _secondaryText,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        if (buscando) ...resultados else _listaSecoes(),
                        if (!buscando) _footer(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
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

/// Bottom sheet que explica o login por biometria e confirma a senha.
class _SheetBiometria extends StatefulWidget {
  const _SheetBiometria({required this.email, required this.nome});

  final String email;
  final String nome;

  @override
  State<_SheetBiometria> createState() => _SheetBiometriaState();
}

class _SheetBiometriaState extends State<_SheetBiometria> {
  final _senha = TextEditingController();
  bool _enviando = false;
  bool _ver = false;
  String? _erro;

  @override
  void dispose() {
    _senha.dispose();
    super.dispose();
  }

  Future<void> _ativar() async {
    final senha = _senha.text;
    if (senha.isEmpty) {
      setState(() => _erro = 'Digite a sua senha.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      // Confere a senha (entra de novo na MESMA conta).
      final r = await Supabase.instance.client.auth.signInWithPassword(
        email: widget.email,
        password: senha,
      );
      final authId = r.user?.id;
      if (authId == null) throw Exception('sem usuário');
      final ok = await BiometriaService.autenticar(
        'Confirme a biometria para ativar o login rápido',
      );
      if (!ok) {
        if (!mounted) return;
        setState(() {
          _enviando = false;
          _erro = 'A biometria não foi confirmada.';
        });
        return;
      }
      await BiometriaService.salvar(
        identificador: widget.email,
        senha: senha,
        authId: authId,
        nome: widget.nome,
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _erro =
            'Senha incorreta. Se você entra com o Google, crie uma senha em '
            '"Alterar senha" antes.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _erro = 'Não foi possível ativar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(22, 12, 22, 20 + mq.padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9DDE1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                CorOriginal(interface: true, child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0FB3FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.fingerprint,
                    color: Colors.white,
                    size: 30,
                  ),
                )),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Login por biometria',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Com a biometria ativa, a tela de login mostra o botão "Entrar '
              'com biometria". Basta usar a digital ou o rosto cadastrado no '
              'celular para entrar.',
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ela sempre entra na ÚLTIMA conta que ativou a opção neste '
              'celular. A sua senha fica guardada só no cofre seguro do '
              'aparelho.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF55595E),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _senha,
              obscureText: !_ver,
              enabled: !_enviando,
              onSubmitted: (_) => _ativar(),
              decoration: InputDecoration(
                labelText: 'Confirme a sua senha',
                errorText: _erro,
                errorMaxLines: 3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _ver = !_ver),
                  icon: Icon(
                    _ver
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: CorOriginal(interface: true, child: FilledButton(
                onPressed: _enviando ? null : _ativar,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0FB3FF),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _enviando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Ativar biometria',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              )),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _enviando ? null : () => Navigator.pop(context),
                child: const Text('Agora não', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
