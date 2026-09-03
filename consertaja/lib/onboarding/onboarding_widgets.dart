import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'onboarding_theme.dart';
import '../widgets/seletor_ddi.dart';
import '../termos_de_uso.dart';
import '../politica_de_privacidade.dart';

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
                    if (prefix != null) ...[
                      prefix!,
                      const SizedBox(width: 8),
                    ],
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
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text(
                errorText!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Campo com máscara estilizada de documento para a Tela 4 (Imagem 4).
class DocumentInputField extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          height: 64,
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
            alignment: Alignment.center,
            children: [
              if (controller.text.isEmpty)
                Text(
                  '___ . ___ . ___ - __',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: OnboardingColors.blue.withValues(alpha: 0.65),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                onSubmitted: (_) => onSubmitted(),
                inputFormatters: [CpfCnpjInputFormatter()],
                cursorColor: OnboardingColors.blue,
                style: const TextStyle(
                  color: OnboardingColors.blue,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              errorText!,
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
      requiredMark: true,
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

  const PillButton({
    super.key,
    required this.label,
    this.onTap,
    this.outlined = false,
    this.loading = false,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final bg = outlined
        ? Colors.transparent
        : (background ?? Colors.white);
    final fg = outlined
        ? Colors.white
        : (foreground ?? OnboardingColors.blue);
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bg,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          foregroundColor: fg,
          side: outlined
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
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: fg,
                ),
              ),
      ),
    );
  }
}

/// Botão oficial estilizado "Continuar com Google" (Imagens 14, 15, 17, 20, 21, 22).
class GoogleButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;

  const GoogleButton({
    super.key,
    this.onTap,
    this.loading = false,
  });

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
                  CustomPaint(
                    size: const Size(20, 20),
                    painter: GoogleLogoPainter(),
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

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill;
    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill;
    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -0.785, 1.57, true, paintBlue);
    canvas.drawArc(rect, 0.785, 1.57, true, paintGreen);
    canvas.drawArc(rect, 2.356, 1.57, true, paintYellow);
    canvas.drawArc(rect, 3.927, 1.57, true, paintRed);

    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.58, innerPaint);

    final barRect = Rect.fromLTRB(
      center.dx,
      center.dy - radius * 0.22,
      size.width,
      center.dy + radius * 0.22,
    );
    canvas.drawRect(barRect, paintBlue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  Widget _renderBubbleText(String content, Color baseColor, double fontSize) {
    if (content.contains('ConsertaJá')) {
      final parts = content.split('ConsertaJá');
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            color: baseColor,
            fontSize: fontSize,
            height: 1.3,
          ),
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
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      height: size,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                ...previousChildren,
                ?currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: Image.asset(
            asset,
            key: ValueKey(asset),
            height: size,
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
    );
  }
}

class BubbleTransitionSwitcher extends StatelessWidget {
  final Widget child;

  const BubbleTransitionSwitcher({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.75, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class AnimatedHistoricalBubble extends StatelessWidget {
  final String text;

  const AnimatedHistoricalBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
      builder: (context, val, child) {
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - val) * 18),
            child: child,
          ),
        );
      },
      child: SpeechBubble(
        text: text,
        historico: true,
        comSeta: false,
      ),
    );
  }
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
    final accent = profissional ? OnboardingColors.orange : OnboardingColors.blue;
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            valid ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 16,
            color: valid ? Colors.white : Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: valid ? Colors.white : Colors.white.withValues(alpha: 0.8),
                fontSize: 12.5,
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
