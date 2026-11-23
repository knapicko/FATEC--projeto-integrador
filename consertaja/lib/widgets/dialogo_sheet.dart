import 'package:flutter/material.dart';
import '../services/app_settings_controller.dart';

/// Mostra um [AlertDialog] como bottom sheet do app (alça, cantos de 28,
/// título, conteúdo rolável e botões largos), com a mesma assinatura de
/// `showDialog`. `Navigator.pop(ctx, valor)` continua funcionando igual.
///
/// Se o builder não devolver um [AlertDialog], abre como diálogo normal.
Future<T?> mostrarDialogoComoSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: barrierDismissible,
    enableDrag: barrierDismissible,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor:
        barrierColor ??
        (AppSettingsController.semTransparencia
            ? const Color(0xFF3A3F45)
            : Colors.black.withValues(alpha: 0.45)),
    builder: (ctx) {
      final w = builder(ctx);
      return PopScope(
        canPop: barrierDismissible,
        child: w is AlertDialog ? _SheetDoAlerta(alerta: w) : _SheetGenerica(w),
      );
    },
  );
}

class _SheetDoAlerta extends StatelessWidget {
  const _SheetDoAlerta({required this.alerta});

  final AlertDialog alerta;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final acoes = alerta.actions ?? const <Widget>[];
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
        decoration: BoxDecoration(
          color: alerta.backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                if (alerta.icon != null) ...[
                  Center(
                    child: IconTheme.merge(
                      data: IconThemeData(
                        size: 34,
                        color: alerta.iconColor ?? const Color(0xFF0FB3FF),
                      ),
                      child: alerta.icon!,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (alerta.title != null) ...[
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                    child: alerta.title!,
                  ),
                  const SizedBox(height: 10),
                ],
                if (alerta.content != null)
                  Flexible(
                    child: SingleChildScrollView(
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                        child: alerta.content!,
                      ),
                    ),
                  ),
                if (acoes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _Botoes(acoes: acoes),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botões do alerta: até 2 lado a lado, mais que isso empilhados.
class _Botoes extends StatelessWidget {
  const _Botoes({required this.acoes});

  final List<Widget> acoes;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).copyWith(
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          backgroundColor: const Color(0xFFF1F5F9),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
        ),
      ),
    );
    return Theme(
      data: estilo,
      child: acoes.length <= 2
          ? Row(
              children: [
                for (var i = 0; i < acoes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: acoes[i]),
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // O último botão costuma ser a ação principal: vai primeiro.
                for (final a in acoes.reversed) ...[
                  a,
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }
}

/// Outro widget (ex.: um [Dialog] com conteúdo próprio): o conteúdo vai
/// dentro do mesmo cartão.
class _SheetGenerica extends StatelessWidget {
  const _SheetGenerica(this.filho);

  final Widget filho;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    var f = filho;
    // Animação de entrada do diálogo antigo: a sheet já anima sozinha.
    if (f is TweenAnimationBuilder && f.child != null) f = f.child!;
    final conteudo = f is Dialog ? (f.child ?? const SizedBox.shrink()) : f;
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Material(color: Colors.transparent, child: conteudo),
          ),
        ),
      ),
    );
  }
}
