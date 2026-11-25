import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/movimento.dart';
import 'imagem_app.dart';

const _azul = Color(0xFF0FB3FF);
const _texto = Color(0xFF1E293B);
const _sec = Color(0xFF64748B);

/// Seletor de data do app inteiro: abre no CAMPO DE DIGITAR (com máscara
/// DD/MM/AAAA) e tem um botão para trocar para o CALENDÁRIO (e voltar).
///
/// Aceita os mesmos parâmetros do `showDatePicker` para trocar sem mexer no
/// resto da tela (`builder`, `locale` e `fieldLabelText` são ignorados: o
/// visual já é o do app).
Future<DateTime?> escolherData({
  required BuildContext context,
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  String? fieldLabelText,
  Locale? locale,
  TransitionBuilder? builder,
}) {
  final primeira = DateUtils.dateOnly(firstDate);
  final ultima = DateUtils.dateOnly(lastDate);
  var inicial = DateUtils.dateOnly(initialDate ?? DateTime.now());
  if (inicial.isBefore(primeira)) inicial = primeira;
  if (inicial.isAfter(ultima)) inicial = ultima;
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _DialogoData(
      titulo: helpText ?? fieldLabelText ?? 'Escolha a data',
      inicial: inicial,
      primeira: primeira,
      ultima: ultima,
    ),
  );
}

/// Máscara DD/MM/AAAA enquanto digita.
class MascaraData extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    final d = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(d[i]);
    }
    final texto = b.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// "DD/MM/AAAA" → data (null se incompleta ou inválida, ex.: 31/02).
DateTime? lerData(String texto) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto.trim());
  if (m == null) return null;
  final dia = int.parse(m.group(1)!);
  final mes = int.parse(m.group(2)!);
  final ano = int.parse(m.group(3)!);
  final data = DateTime(ano, mes, dia);
  if (data.day != dia || data.month != mes || data.year != ano) return null;
  return data;
}

String formatarData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

class _DialogoData extends StatefulWidget {
  const _DialogoData({
    required this.titulo,
    required this.inicial,
    required this.primeira,
    required this.ultima,
  });

  final String titulo;
  final DateTime inicial;
  final DateTime primeira;
  final DateTime ultima;

  @override
  State<_DialogoData> createState() => _DialogoDataState();
}

class _DialogoDataState extends State<_DialogoData> {
  late final TextEditingController _campo = TextEditingController(
    text: formatarData(widget.inicial),
  );
  late DateTime _data = widget.inicial;
  bool _calendario = false;
  String? _erro;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  /// Valida o que foi digitado. null = ok.
  String? _validar(String texto) {
    if (texto.length < 10) return 'Digite a data completa: DD/MM/AAAA';
    final d = lerData(texto);
    if (d == null) return 'Data inválida';
    if (d.isBefore(widget.primeira)) {
      return 'A data não pode ser antes de ${formatarData(widget.primeira)}';
    }
    if (d.isAfter(widget.ultima)) {
      return 'A data não pode ser depois de ${formatarData(widget.ultima)}';
    }
    return null;
  }

  void _digitou(String texto) {
    setState(() {
      _erro = texto.length == 10 ? _validar(texto) : null;
      final d = lerData(texto);
      if (_erro == null && d != null) _data = d;
    });
  }

  void _alternar() {
    if (!_calendario) {
      // Indo para o calendário: abre no que foi digitado (se válido).
      final d = lerData(_campo.text);
      if (d != null && _validar(_campo.text) == null) _data = d;
    } else {
      _campo.text = formatarData(_data);
      _erro = null;
    }
    setState(() => _calendario = !_calendario);
  }

  void _confirmar() {
    if (!_calendario) {
      final erro = _validar(_campo.text);
      if (erro != null) {
        setState(() => _erro = erro);
        return;
      }
      _data = lerData(_campo.text)!;
    }
    Navigator.pop(context, _data);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: _azul,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: _texto,
          surfaceTint: Colors.transparent,
        ),
      ),
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.titulo,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  CorOriginal(
                    interface: true,
                    child: IconButton.filledTonal(
                      onPressed: _alternar,
                      tooltip: _calendario ? 'Digitar a data' : 'Abrir calendário',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFE6F7FF),
                        foregroundColor: _azul,
                      ),
                      icon: Icon(
                        _calendario
                            ? Icons.keyboard_alt_outlined
                            : Icons.calendar_month_rounded,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: duracao(const Duration(milliseconds: 220)),
                child: _calendario
                    ? SizedBox(
                        key: const ValueKey('cal'),
                        width: 320,
                        child: CalendarDatePicker(
                          initialDate: _data,
                          firstDate: widget.primeira,
                          lastDate: widget.ultima,
                          onDateChanged: (d) => setState(() => _data = d),
                        ),
                      )
                    : Column(
                        key: const ValueKey('campo'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _campo,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            inputFormatters: [MascaraData()],
                            onChanged: _digitou,
                            onSubmitted: (_) => _confirmar(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: _texto,
                            ),
                            decoration: InputDecoration(
                              hintText: 'DD/MM/AAAA',
                              errorText: _erro,
                              prefixIcon: const Icon(
                                Icons.event_outlined,
                                color: _azul,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF5F9FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: _azul,
                                  width: 1.6,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _alternar,
                            child: const Text(
                              'Prefere escolher no calendário? Toque no ícone ao lado.',
                              style: TextStyle(color: _sec, fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: _sec)),
                  ),
                  const SizedBox(width: 4),
                  CorOriginal(
                    interface: true,
                    child: FilledButton(
                      onPressed: _confirmar,
                      style: FilledButton.styleFrom(
                        backgroundColor: _azul,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Confirmar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
