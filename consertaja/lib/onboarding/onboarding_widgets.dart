import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'onboarding_theme.dart';
import '../widgets/seletor_ddi.dart';
import '../termos_de_uso.dart';
import '../politica_de_privacidade.dart';
import '../services/validacao_documento.dart';

/// Identifica com precisão o tipo de identificador digitado no login:
/// Retorna 'CPF:', 'CNPJ:', 'Email:' ou 'Telefone:' (ou placeholder quando vazio).
String identificarTipoLogin(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'CPF, CNPJ, email ou telefone';
  }

  // Se contém '@' ou letras, é email
  if (trimmed.contains('@') || RegExp(r'[A-Za-z]').hasMatch(trimmed)) {
    return 'Email:';
  }

  // Se o usuário digitou '(' ou ')', começou digitando telefone
  if (trimmed.contains('(') || trimmed.contains(')')) {
    return 'Telefone:';
  }

  // Se contém '/', é CNPJ
  if (trimmed.contains('/')) {
    return 'CNPJ:';
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return 'CPF, CNPJ, email ou telefone';
  }

  // CNPJ tem mais de 11 dígitos
  if (digits.length > 11) {
    return 'CNPJ:';
  }

  // Se começa com '0', no Brasil não há DDD iniciando com 0 -> CPF
  if (digits.startsWith('0')) {
    return 'CPF:';
  }

  // Se o usuário colocou '.' (máscara de CPF), é CPF
  if (trimmed.contains('.')) {
    return 'CPF:';
  }

  // Com 3 ou mais dígitos:
  // No Brasil, celular SEMPRE tem DDD (11-99) seguido de '9'.
  if (digits.length >= 3) {
    final ddd = int.tryParse(digits.substring(0, 2)) ?? 0;
    final terceiroDigito = digits[2];
    final dddValido = ddd >= 11 && ddd <= 99 && (ddd % 10 != 0);

    if (terceiroDigito == '9' && dddValido) {
      if (digits.length == 11 &&
          validarCpf(digits) &&
          !trimmed.startsWith('(')) {
        return 'CPF:';
      }
      return 'Telefone:';
    } else {
      return 'CPF:';
    }
  }

  return 'CPF:';
}

class CpfCnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 14 ? digits.substring(0, 14) : digits;
    final mask = limited.length <= 11 ? '###.###.###-##' : '##.###.###/####-##';
    var formatted = '';
    var digitIndex = 0;
    for (var i = 0; i < mask.length; i++) {
      if (digitIndex >= limited.length) break;
      if (mask[i] == '#') {
        formatted += limited[digitIndex];
        digitIndex++;
      } else {
        formatted += mask[i];
      }
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    const mask = '(##) #####-####';
    var formatted = '';
    var digitIndex = 0;
    for (var i = 0; i < mask.length; i++) {
      if (digitIndex >= digits.length) break;
      if (mask[i] == '#') {
        formatted += digits[digitIndex];
        digitIndex++;
      } else {
        formatted += mask[i];
      }
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class LoginIdentifierInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final value = newValue.text;
    if (value.isEmpty) return newValue;

    // Se for e-mail (tem letra ou @), não aplica máscara numérica
    if (value.contains('@') || RegExp(r'[A-Za-z]').hasMatch(value)) {
      return newValue;
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 14) return oldValue;

    if (digits.length > 11) {
      return _applyMask(digits, '##.###.###/####-##');
    }

    final tipo = identificarTipoLogin(value);
    if (tipo == 'Telefone:') {
      if (digits.length <= 10) {
        return _applyMask(digits, '(##) ####-####');
      } else {
        return _applyMask(digits, '(##) #####-####');
      }
    }

    return _applyMask(digits, '###.###.###-##');
  }

  TextEditingValue _applyMask(String digits, String mask) {
    var formatted = '';
    var index = 0;
    for (final character in mask.split('')) {
      if (index >= digits.length) break;
      if (character == '#') {
        formatted += digits[index++];
      } else {
        formatted += character;
      }
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class OnboardingWhiteField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool requiredMark;
  final bool readOnly;
  final bool obscure;
  final IconData? suffixIcon;
  final VoidCallback? onSuffix;
  final VoidCallback? onTap;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final String? errorText;
  final bool filledValue;

  const OnboardingWhiteField({
    super.key,
    required this.label,
    required this.controller,
    this.requiredMark = false,
    this.readOnly = false,
    this.obscure = false,
    this.suffixIcon,
    this.onSuffix,
    this.onTap,
    this.keyboardType,
    this.inputFormatters,
    this.prefix,
    this.errorText,
    this.filledValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                errorText!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (prefix != null) ...[prefix!, const SizedBox(width: 8)],
                    Expanded(
                      child: TextField(
                        controller: controller,
                        readOnly: readOnly,
                        obscureText: obscure,
                        onTap: onTap,
                        keyboardType: keyboardType,
                        inputFormatters: inputFormatters,
                        cursorColor: OnboardingColors.blue,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: label,
                          hintStyle: TextStyle(
                            color: OnboardingColors.blue.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          labelText: filledValue || controller.text.isNotEmpty
                              ? label
                              : null,
                          labelStyle: const TextStyle(
                            color: OnboardingColors.blue,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.auto,
                        ),
                      ),
                    ),
                    if (suffixIcon != null)
                      IconButton(
                        onPressed: onSuffix ?? onTap,
                        icon: Icon(suffixIcon, color: OnboardingColors.blue),
                      ),
                  ],
                ),
              ),
              if (requiredMark)
                const Positioned(
                  top: 8,
                  right: 12,
                  child: Text(
                    '*',
                    style: TextStyle(
                      color: OnboardingColors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Campo com máscara estilizada de documento para a Tela 4 (Imagem 4).
class DocumentInputField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final String? errorText;

  const DocumentInputField({
    super.key,
    required this.controller,
    required this.onSubmitted,
    this.errorText,
  });

  @override
  State<DocumentInputField> createState() => _DocumentInputFieldState();
}

class _DocumentInputFieldState extends State<DocumentInputField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    final showMask = !_focusNode.hasFocus && !hasText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onSubmitted: (_) => widget.onSubmitted(),
                inputFormatters: [CpfCnpjInputFormatter()],
                cursorColor: OnboardingColors.blue,
                style: const TextStyle(
                  color: OnboardingColors.blue,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: showMask ? _maskFor(widget.controller.text) : null,
                  hintStyle: TextStyle(
                    color: OnboardingColors.blue.withValues(alpha: 0.65),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.errorText!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  String _maskFor(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    return digits.length > 11 ? '__.___.___/____-__' : '___.___.___-__';
  }
}

class OnboardingPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String ddi;
  final ValueChanged<String> onDdiChanged;
  final String? errorText;

  const OnboardingPhoneField({
    super.key,
    required this.controller,
    required this.ddi,
    required this.onDdiChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingWhiteField(
      label: 'Telefone',
      controller: controller,
      keyboardType: TextInputType.phone,
      inputFormatters: [TelefoneInputFormatter()],
      errorText: errorText,
      prefix: SeletorDDI(
        ddiInicial: ddi,
        corPrimaria: OnboardingColors.blue,
        onChanged: onDdiChanged,
      ),
    );
  }
}

class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool outlined;
  final bool loading;
  final Color? background;
  final Color? foreground;
  final IconData? icon;

  /// Requisitos não cumpridos: botão cinza com cadeado e sem clique.
  final bool bloqueado;

  const PillButton({
    super.key,
    required this.label,
    this.onTap,
    this.outlined = false,
    this.loading = false,
    this.background,
    this.foreground,
    this.icon,
    this.bloqueado = false,
  });

  static const Color _cinzaBloqueado = Color(0xFFCBD5E1);
  static const Color _textoBloqueado = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final bg = bloqueado
        ? _cinzaBloqueado
        : outlined
        ? Colors.transparent
        : (background ?? Colors.white);
    final fg = bloqueado
        ? _textoBloqueado
        : outlined
        ? Colors.white
        : (foreground ?? OnboardingColors.blue);

    // Remove qualquer seta textual "->" para exibir o ícone real
    final cleanLabel = label.replaceAll(RegExp(r'\s*->'), '').trim();
    final hasArrow =
        label.contains('->') ||
        cleanLabel == 'Continuar' ||
        cleanLabel == 'Entrar';
    final effectiveIcon =
        icon ?? (hasArrow ? Icons.arrow_forward_rounded : null);

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: (loading || bloqueado) ? null : onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bg,
          disabledBackgroundColor: bloqueado
              ? _cinzaBloqueado
              : bg.withValues(alpha: 0.5),
          disabledForegroundColor: bloqueado ? _textoBloqueado : null,
          foregroundColor: fg,
          side: bloqueado
              ? BorderSide.none
              : outlined
              ? const BorderSide(color: Colors.white, width: 2)
              : (background != null
                    ? const BorderSide(color: Colors.white, width: 2)
                    : BorderSide.none),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: loading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (bloqueado) ...[
                    Icon(Icons.lock_outline_rounded, size: 19, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    cleanLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: fg,
                    ),
                  ),
                  if (effectiveIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(effectiveIcon, size: 20, color: fg),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Botão oficial estilizado "Continuar com Google" (Imagens 14, 15, 17, 20, 21, 22).
class GoogleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;

  const GoogleButton({super.key, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          elevation: 1,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: OnboardingColors.blue,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/icone/google-logo.png',
                    height: 22,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Continuar com Google',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class SpeechBubble extends StatelessWidget {
  final String text;
  final bool historico;
  final bool comSeta;

  const SpeechBubble({
    super.key,
    required this.text,
    this.historico = false,
    this.comSeta = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = historico ? OnboardingColors.historyFill : Colors.white;
    final color = historico
        ? OnboardingColors.historyText
        : OnboardingColors.blue;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: historico ? 28 : 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: historico
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: _renderBubbleText(text, color, historico ? 14 : 18),
        ),
        if (comSeta && !historico)
          CustomPaint(
            size: const Size(24, 14),
            painter: _BubbleTailPainter(color: bg),
          ),
      ],
    );
  }

  Widget _renderBubbleText(String content, Color baseColor, double fontSize) =>
      _textoDoBalao(content, baseColor, fontSize);
}

class TypingBubble extends StatefulWidget {
  final String text;
  final bool comSeta;

  const TypingBubble({super.key, required this.text, this.comSeta = true});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble> {
  String _shown = '';

  @override
  void initState() {
    super.initState();
    _type();
  }

  @override
  void didUpdateWidget(covariant TypingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _shown = '';
      _type();
    }
  }

  Future<void> _type() async {
    final full = widget.text;
    for (var i = 1; i <= full.length; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
      if (!mounted || widget.text != full) return;
      setState(() => _shown = full.substring(0, i));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SpeechBubble(
      text: _shown.isEmpty ? ' ' : _shown,
      comSeta: widget.comSeta,
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  _BubbleTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

class CaixaCharacter extends StatelessWidget {
  final String asset;
  final double size;
  final double offsetY;

  const CaixaCharacter({
    super.key,
    required this.asset,
    this.size = 210,
    this.offsetY = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeInOutCubic,
      width: size,
      height: size,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 340),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          layoutBuilder: (currentChild, previousChildren) {
            return SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: <Widget>[...previousChildren, ?currentChild],
              ),
            );
          },
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Image.asset(
              asset,
              key: ValueKey(asset),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.home_repair_service_rounded,
                key: ValueKey('fallback-$asset'),
                size: size * 0.7,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BubbleTransitionSwitcher extends StatelessWidget {
  final Widget child;

  const BubbleTransitionSwitcher({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 340),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return _BubbleTransition(animation: animation, child: child);
      },
      child: child,
    );
  }
}

class _BubbleTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _BubbleTransition({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    final isLeaving = animation.status == AnimationStatus.reverse;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slide = Tween<Offset>(
      begin: isLeaving ? Offset.zero : const Offset(0, 0.08),
      end: isLeaving ? const Offset(0, -0.16) : Offset.zero,
    ).animate(curved);
    final content = SlideTransition(position: slide, child: child);

    if (!isLeaving) return content;

    final fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: ReverseAnimation(animation),
        curve: const Interval(0.78, 1, curve: Curves.easeIn),
      ),
    );
    return FadeTransition(opacity: fade, child: content);
  }
}

class ConversationContentTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const ConversationContentTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isLeaving = animation.status == AnimationStatus.reverse;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final slide = Tween<Offset>(
      begin: isLeaving ? Offset.zero : const Offset(0, 0.1),
      end: isLeaving ? const Offset(0, -0.2) : Offset.zero,
    ).animate(curved);
    final content = SlideTransition(position: slide, child: child);

    if (!isLeaving) {
      // Só aparece depois que o conteúdo anterior já sumiu: os dois nunca
      // ficam visíveis um sobre o outro.
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 1, curve: Curves.easeOut),
        ),
        child: content,
      );
    }

    final fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: ReverseAnimation(animation),
        curve: const Interval(0, 0.5, curve: Curves.easeIn),
      ),
    );
    return FadeTransition(opacity: fade, child: content);
  }
}

/// Conversa da caixa: o balão atual e, acima dele, o anterior (cinza).
///
/// Os balões são itens estáveis (não são recriados a cada fala):
///  * ao avançar, o balão atual SOBE e vira "anterior" (encolhe e fica
///    cinza), o novo cresce embaixo empurrando-o, e o que já era anterior
///    (o 2º anterior) esmaece antes de recolher;
///  * ao voltar, o anterior desce e volta a ser o atual;
///  * se a fala não tem relação com a anterior, os antigos somem primeiro e
///    só então os novos entram — nada fica visualmente por cima de nada.
class ConversationBubbles extends StatefulWidget {
  const ConversationBubbles({
    super.key,
    required this.atual,
    this.historico,
    this.digitar = false,
    this.comSeta = true,
  });

  final String atual;
  final String? historico;

  /// Efeito de digitação no balão atual.
  final bool digitar;

  /// Seta do balão atual apontando para a caixa.
  final bool comSeta;

  @override
  State<ConversationBubbles> createState() => _ConversationBubblesState();
}

class _FalaItem {
  _FalaItem(
    this.id,
    this.texto, {
    this.digitar = false,
    this.atrasoEntrada = Duration.zero,
    this.jaVisivel = false,
  });

  final int id;
  final String texto;
  final bool digitar;
  final Duration atrasoEntrada;
  final bool jaVisivel;
  bool saindo = false;
  bool historico = false;
}

class _ConversationBubblesState extends State<ConversationBubbles> {
  final List<_FalaItem> _itens = [];
  int _proximoId = 0;

  _FalaItem _novo(
    String texto, {
    bool digitar = false,
    Duration atraso = Duration.zero,
    bool jaVisivel = false,
  }) {
    return _FalaItem(
      _proximoId++,
      texto,
      digitar: digitar,
      atrasoEntrada: atraso,
      jaVisivel: jaVisivel,
    );
  }

  List<_FalaItem> get _ativos => _itens.where((i) => !i.saindo).toList();

  @override
  void initState() {
    super.initState();
    final historico = widget.historico;
    if (historico != null) _itens.add(_novo(historico, jaVisivel: true));
    if (widget.atual.isNotEmpty) {
      _itens.add(_novo(widget.atual, digitar: widget.digitar));
    }
  }

  @override
  void didUpdateWidget(covariant ConversationBubbles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atual == widget.atual &&
        oldWidget.historico == widget.historico) {
      return;
    }
    final ativos = _ativos;
    final atual = ativos.isEmpty ? null : ativos.last;
    final anterior = ativos.length >= 2 ? ativos[ativos.length - 2] : null;

    // Avançou: o atual vira o anterior e o novo entra embaixo.
    if (atual != null &&
        widget.historico == atual.texto &&
        widget.atual != atual.texto) {
      for (final item in ativos) {
        if (item != atual) item.saindo = true;
      }
      if (widget.atual.isNotEmpty) {
        _itens.add(
          _novo(
            widget.atual,
            digitar: widget.digitar,
            atraso: const Duration(milliseconds: 90),
          ),
        );
      }
      return;
    }

    // Voltou: o anterior desce e volta a ser o atual.
    if (anterior != null &&
        widget.historico == null &&
        widget.atual == anterior.texto) {
      for (final item in ativos) {
        if (item != anterior) item.saindo = true;
      }
      return;
    }

    // Sem relação: os antigos saem antes de os novos entrarem.
    for (final item in ativos) {
      item.saindo = true;
    }
    final atraso = ativos.isEmpty
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final historico = widget.historico;
    if (historico != null) _itens.add(_novo(historico, atraso: atraso));
    if (widget.atual.isNotEmpty) {
      _itens.add(_novo(widget.atual, digitar: widget.digitar, atraso: atraso));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ativos = _ativos;
    for (var i = 0; i < ativos.length; i++) {
      ativos[i].historico = i < ativos.length - 1;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in _itens)
          _FalaBalao(
            key: ValueKey(item.id),
            item: item,
            historico: item.historico,
            saindo: item.saindo,
            comSeta: widget.comSeta,
            aoSair: () {
              if (mounted) setState(() => _itens.remove(item));
            },
          ),
      ],
    );
  }
}

class _FalaBalao extends StatefulWidget {
  const _FalaBalao({
    super.key,
    required this.item,
    required this.historico,
    required this.saindo,
    required this.comSeta,
    required this.aoSair,
  });

  final _FalaItem item;
  final bool historico;
  final bool saindo;
  final bool comSeta;
  final VoidCallback aoSair;

  @override
  State<_FalaBalao> createState() => _FalaBalaoState();
}

class _FalaBalaoState extends State<_FalaBalao> with TickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: widget.item.jaVisivel ? 1 : 0,
  );
  late final AnimationController _saida = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  Timer? _atraso;
  Timer? _digitacao;
  late String _mostrado = widget.item.digitar ? '' : widget.item.texto;

  @override
  void initState() {
    super.initState();
    if (_entrada.value < 1) {
      final atraso = widget.item.atrasoEntrada;
      if (atraso == Duration.zero) {
        _entrar();
      } else {
        _atraso = Timer(atraso, _entrar);
      }
    }
    if (widget.saindo) _sair();
  }

  void _entrar() {
    if (!mounted || widget.saindo) return;
    _entrada.forward();
    if (widget.item.digitar) _digitar();
  }

  void _digitar() {
    final texto = widget.item.texto;
    var i = 0;
    _digitacao = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) return timer.cancel();
      i++;
      setState(() => _mostrado = texto.substring(0, i));
      if (i >= texto.length) timer.cancel();
    });
  }

  void _sair() {
    _atraso?.cancel();
    _saida.forward().whenComplete(() {
      if (mounted) widget.aoSair();
    });
  }

  @override
  void didUpdateWidget(covariant _FalaBalao oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.saindo && !oldWidget.saindo) _sair();
    // Virou anterior antes de terminar de digitar: mostra o texto inteiro.
    if (widget.historico && _mostrado != widget.item.texto) {
      _digitacao?.cancel();
      _mostrado = widget.item.texto;
    }
  }

  @override
  void dispose() {
    _atraso?.cancel();
    _digitacao?.cancel();
    _entrada.dispose();
    _saida.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_entrada, _saida]),
      builder: (context, child) {
        final e = Curves.easeOutCubic.transform(_entrada.value);
        final s = _saida.value;
        // Entrada: abre espaço (empurrando os de cima) e depois aparece.
        final opacidadeEntrada = Curves.easeOut.transform(
          ((_entrada.value - 0.3) / 0.7).clamp(0.0, 1.0),
        );
        // Saída: primeiro esmaece, só depois recolhe o espaço.
        final opacidadeSaida =
            1 - Curves.easeIn.transform((s / 0.45).clamp(0.0, 1.0));
        final alturaSaida =
            1 -
            Curves.easeInOutCubic.transform(
              ((s - 0.35) / 0.65).clamp(0.0, 1.0),
            );
        final fator = e * alturaSaida;
        final conteudo = Opacity(
          opacity: (opacidadeEntrada * opacidadeSaida).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - e) - 10 * s),
            child: child,
          ),
        );
        if (fator >= 1) return conteudo;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: fator.clamp(0.0, 1.0),
            child: conteudo,
          ),
        );
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: widget.historico ? 1 : 0),
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOutCubic,
        builder: (context, h, _) => _BalaoMorph(
          texto: _mostrado.isEmpty ? ' ' : _mostrado,
          h: h,
          comSeta: widget.comSeta,
        ),
      ),
    );
  }
}

/// Balão que interpola entre "atual" (h = 0) e "anterior" (h = 1).
class _BalaoMorph extends StatelessWidget {
  const _BalaoMorph({
    required this.texto,
    required this.h,
    required this.comSeta,
  });

  final String texto;
  final double h;
  final bool comSeta;

  double _lerp(double a, double b) => a + (b - a) * h;

  @override
  Widget build(BuildContext context) {
    final fundo = Color.lerp(Colors.white, OnboardingColors.historyFill, h)!;
    final cor = Color.lerp(
      OnboardingColors.blue,
      OnboardingColors.historyText,
      h,
    )!;
    final seta = comSeta ? (1 - h).clamp(0.0, 1.0) : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: _lerp(16, 28)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: fundo,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08 * (1 - h)),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _textoDoBalao(texto, cor, _lerp(18, 14)),
        ),
        if (seta > 0)
          CustomPaint(
            size: Size(24, 14 * seta),
            painter: _BubbleTailPainter(color: fundo),
          ),
        // A seta do atual vira o espaço entre o anterior e o novo.
        SizedBox(height: 8 * h),
      ],
    );
  }
}

Widget _textoDoBalao(String content, Color baseColor, double fontSize) {
  if (content.contains('ConsertaJá')) {
    final parts = content.split('ConsertaJá');
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(color: baseColor, fontSize: fontSize, height: 1.3),
        children: [
          TextSpan(
            text: parts[0],
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const TextSpan(
            text: 'Conserta',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const TextSpan(
            text: 'Já',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          if (parts.length > 1)
            TextSpan(
              text: parts[1],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }

  return Text(
    content,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: baseColor,
      fontWeight: FontWeight.w800,
      fontSize: fontSize,
      height: 1.3,
    ),
  );
}

class AccountTypeCard extends StatelessWidget {
  final bool selected;
  final bool profissional;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const AccountTypeCard({
    super.key,
    required this.selected,
    required this.profissional,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = profissional
        ? OnboardingColors.orange
        : OnboardingColors.blue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? accent.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: selected ? 12 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              profissional ? Icons.handyman_rounded : Icons.person_rounded,
              color: accent,
              size: 36,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AreaSlotCard extends StatelessWidget {
  final String label;
  final String? value;
  final bool requiredMark;
  final VoidCallback onTap;

  const AreaSlotCard({
    super.key,
    required this.label,
    this.value,
    this.requiredMark = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? value! : label,
                  style: TextStyle(
                    color: OnboardingColors.blue.withValues(
                      alpha: hasValue ? 1 : 0.7,
                    ),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (requiredMark && !hasValue)
                const Text(
                  '*',
                  style: TextStyle(
                    color: OnboardingColors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: OnboardingColors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PasswordRequirementItem extends StatelessWidget {
  final String text;
  final bool valid;

  const PasswordRequirementItem({
    super.key,
    required this.text,
    required this.valid,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Icon(
            valid ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 17,
            color: valid ? Colors.white : Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: valid
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.85),
                fontSize: 13.5,
                fontWeight: valid ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TermsAndPrivacyCheckboxes extends StatelessWidget {
  final bool aceitouTermos;
  final bool aceitouPrivacidade;
  final VoidCallback onToggleTermos;
  final VoidCallback onTogglePrivacidade;

  const TermsAndPrivacyCheckboxes({
    super.key,
    required this.aceitouTermos,
    required this.aceitouPrivacidade,
    required this.onToggleTermos,
    required this.onTogglePrivacidade,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onToggleTermos,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Checkbox(
                value: aceitouTermos,
                onChanged: (_) => onToggleTermos(),
                activeColor: Colors.white,
                checkColor: OnboardingColors.blue,
                side: const BorderSide(color: Colors.white, width: 2),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TermosDeUsoPage(),
                      ),
                    );
                  },
                  child: const Text.rich(
                    TextSpan(
                      text: 'Li e aceito os ',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Termos de Uso',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onTogglePrivacidade,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Checkbox(
                value: aceitouPrivacidade,
                onChanged: (_) => onTogglePrivacidade(),
                activeColor: Colors.white,
                checkColor: OnboardingColors.blue,
                side: const BorderSide(color: Colors.white, width: 2),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PoliticaDePrivacidadePage(),
                      ),
                    );
                  },
                  child: const Text.rich(
                    TextSpan(
                      text: 'Li e aceito a ',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Política de Privacidade',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
