import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Na primeira vez que o usuário chega a uma home (depois de baixar o app),
/// mostra um bottom sheet explicando e pedindo de uma vez as permissões que o
/// app usa. Se negar alguma, ela é pedida de novo na hora de usar (isso já
/// acontece em cada tela).
class PermissoesIniciais {
  PermissoesIniciais._();

  static const _chave = 'permissoes_iniciais_pedidas_v1';
  static bool _mostrandoAgora = false;

  static Future<void> pedirSePrimeiraVez(BuildContext context) async {
    if (_mostrandoAgora) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_chave) == true) return;
      _mostrandoAgora = true;
      if (!context.mounted) return;
      final aceitou = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => const _SheetPermissoes(),
      );
      await prefs.setBool(_chave, true);
      if (aceitou == true) {
        await [
          Permission.notification,
          Permission.locationWhenInUse,
          Permission.camera,
          Permission.microphone,
        ].request();
      }
    } catch (_) {
      // Sem permissões aqui não é erro: cada tela pede na hora de usar.
    } finally {
      _mostrandoAgora = false;
    }
  }
}

class _SheetPermissoes extends StatelessWidget {
  const _SheetPermissoes();

  static const _azul = Color(0xFF0FB3FF);

  Widget _item(IconData icone, String titulo, String texto) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icone, color: _azul),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                texto,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Antes de começar',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Para o ConsertaJá funcionar direitinho, precisamos de algumas '
              'permissões. Você pode mudar isso quando quiser nas '
              'configurações do celular.',
              style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
            ),
            const SizedBox(height: 12),
            _item(
              Icons.notifications_active_outlined,
              'Notificações',
              'Avisos de mensagens, propostas e do andamento dos pedidos.',
            ),
            _item(
              Icons.location_on_outlined,
              'Localização',
              'Encontrar profissionais e pedidos perto de você e o trajeto.',
            ),
            _item(
              Icons.photo_camera_outlined,
              'Câmera',
              'Fotos do serviço, de documentos e do reconhecimento facial.',
            ),
            _item(
              Icons.mic_none_rounded,
              'Microfone',
              'Mensagens de voz no chat.',
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _azul,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'Permitir tudo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Agora não',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
