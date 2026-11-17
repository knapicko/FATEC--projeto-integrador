import 'package:flutter/material.dart';

import '../services/google_auth_service.dart';

const Color _azul = Color(0xFF0FB3FF);
const Color _texto = Color(0xFF111827);
const Color _textoSec = Color(0xFF6B7280);

/// Bottom sheet padrão de aviso: ícone num círculo, título, texto e botões.
Future<T?> mostrarAvisoBottomSheet<T>(
  BuildContext context, {
  required IconData icone,
  required String titulo,
  required String mensagem,
  Color corIcone = _azul,
  String textoBotao = 'Entendi',
  T? valorBotao,
  String? textoSecundario,
  T? valorSecundario,
  String? detalhe,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: corIcone.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, color: corIcone, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _texto,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textoSec,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
            if (detalhe != null && detalhe.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                detalhe,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, valorBotao),
                style: FilledButton.styleFrom(
                  backgroundColor: _azul,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  textoBotao,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (textoSecundario != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, valorSecundario),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _azul,
                    side: const BorderSide(color: _azul, width: 1.4),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    textoSecundario,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Erro do login com Google, em português e num bottom sheet (no lugar da
/// faixa vermelha em inglês).
Future<void> mostrarErroGoogle(BuildContext context, Object erro) {
  final cancelou =
      erro is GoogleAuthException &&
      (erro.codigo == 'canceled' ||
          erro.codigo == 'cancelado' ||
          erro.codigo.toLowerCase().contains('cancel'));
  if (cancelou) {
    return mostrarAvisoBottomSheet(
      context,
      icone: Icons.person_search_rounded,
      titulo: 'Nenhuma conta escolhida',
      mensagem:
          'A janela de contas do Google foi fechada antes de você escolher '
          'uma conta. Toque no botão do Google de novo quando quiser entrar.',
    );
  }
  final texto = erro.toString().toLowerCase();
  final semInternet =
      texto.contains('network') ||
      texto.contains('socket') ||
      texto.contains('connection');
  return mostrarAvisoBottomSheet(
    context,
    icone: semInternet ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
    corIcone: const Color(0xFFDC2626),
    titulo: 'Não foi possível entrar com Google',
    mensagem: semInternet
        ? 'Parece que você está sem internet. Confira a conexão e tente de novo.'
        : 'Algo deu errado ao conectar com o Google. Tente de novo em instantes.',
    detalhe: erro is GoogleAuthException ? erro.codigo : null,
  );
}

/// Visitante tentou algo que precisa de conta: convida a entrar/cadastrar.
Future<void> mostrarAvisoVisitante(BuildContext context) async {
  final escolha = await mostrarAvisoBottomSheet<String>(
    context,
    icone: Icons.lock_open_rounded,
    titulo: 'Entre para usar tudo',
    mensagem:
        'Como visitante você pode explorar serviços e perfis. Entre ou crie '
        'sua conta para pedir serviços, conversar com profissionais, usar o '
        'Radar e acompanhar seus pedidos.',
    textoBotao: 'Criar conta',
    valorBotao: 'cadastro',
    textoSecundario: 'Já tenho conta',
    valorSecundario: 'login',
  );
  if (escolha == null || !context.mounted) return;
  aoEscolherEntrarVisitante?.call(context, login: escolha == 'login');
}

/// Registrado pela tela inicial: leva ao onboarding (login ou cadastro).
void Function(BuildContext context, {required bool login})?
aoEscolherEntrarVisitante;

/// Modo visitante ligado (home aberta por "Quero visitar"). Telas que não
/// recebem `isVisitante` consultam isto antes de ações que exigem conta.
class SessaoVisitante {
  SessaoVisitante._();

  static bool ativo = false;

  /// true se pode continuar; false (e mostra o convite) se for visitante.
  static bool permitir(BuildContext context) {
    if (!ativo) return true;
    mostrarAvisoVisitante(context);
    return false;
  }
}
