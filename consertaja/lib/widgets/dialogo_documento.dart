import 'package:flutter/material.dart';
import 'documento_markdown.dart';

/// Exibe um pop-up (dialog) com o conteúdo de um documento legal
/// (Termos de Uso ou Política de Privacidade).
///
/// O conteúdo é rolável e o usuário pode fechar pelo botão "Entendi" ou
/// pelo ícone X no canto superior direito.
Future<void> mostrarDialogoDocumento(
  BuildContext context, {
  required String titulo,
  required String conteudo,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final double alturaMaxima =
          MediaQuery.of(dialogContext).size.height * 0.72;

      return Dialog(
        // Força fundo branco puro, removendo o surface-tint "rosado" herdado
        // do tema (Material 3) que tinha sobre o dialog.
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: alturaMaxima),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, color: Color(0xFF7B7B7B)),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE5E5E5)),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: DocumentoMarkdown(data: conteudo),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A2FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Entendi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
