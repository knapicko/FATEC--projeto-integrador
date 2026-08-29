import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Renderiza um documento em Markdown (Termos de Uso / Política de
/// Privacidade) com a identidade visual do Conserta Já.
class DocumentoMarkdown extends StatelessWidget {
  final String data;

  const DocumentoMarkdown({super.key, required this.data});

  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textBody = Color(0xFF3A3A3A);
  static const Color _blueDark = Color(0xFF0B6FA8);

  @override
  Widget build(BuildContext context) {
    final styleSheet = MarkdownStyleSheet.fromTheme(
      Theme.of(context),
    ).copyWith(
      h1: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: _textDark,
        height: 1.3,
      ),
      h2: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: _blueDark,
        height: 1.4,
      ),
      h3: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: _textDark,
        height: 1.4,
      ),
      h4: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _textDark,
        height: 1.4,
      ),
      p: const TextStyle(
        fontSize: 14,
        color: _textBody,
        height: 1.55,
      ),
      strong: const TextStyle(
        fontSize: 14,
        color: _textDark,
        height: 1.55,
        fontWeight: FontWeight.w700,
      ),
      em: const TextStyle(
        fontSize: 14,
        color: _textBody,
        height: 1.55,
        fontStyle: FontStyle.italic,
      ),
      listBullet: const TextStyle(
        fontSize: 14,
        color: _textBody,
        height: 1.55,
      ),
      listIndent: 24,
      blockSpacing: 12,
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E2E2), width: 1),
        ),
      ),
    );

    return MarkdownBody(
      data: data,
      styleSheet: styleSheet,
    );
  }
}
