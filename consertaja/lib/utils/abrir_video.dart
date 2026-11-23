import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_settings_controller.dart';
import '../services/rede_service.dart';
import '../widgets/dialogo_sheet.dart';

/// Abre um vídeo no player do celular respeitando "Rede e dados":
/// • "Abrir vídeos sem perguntar" ligado → abre direto;
/// • desligado, ou economia de dados nos dados móveis → pergunta antes.
Future<void> abrirVideo(BuildContext context, String url) async {
  final cfg = AppSettingsController.instance;
  final rede = RedeService.instance;
  final perguntar =
      !cfg.abrirVideosSemPerguntar || (cfg.economiaDados && !rede.emWifi);
  if (perguntar) {
    final ok = await mostrarDialogoComoSheet<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abrir o vídeo?'),
        content: Text(
          rede.emWifi
              ? 'O vídeo abre no player do celular.'
              : 'Você está nos dados móveis: o vídeo pode gastar a sua '
                    'franquia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
  }
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
