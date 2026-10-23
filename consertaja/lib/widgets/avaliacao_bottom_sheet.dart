import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AvaliacaoResposta {
  final int? notaServico;
  final String comentarioServico;
  final int? notaProfissional;
  final String comentarioProfissional;
  final int? notaCliente;
  final String comentarioCliente;

  const AvaliacaoResposta({
    this.notaServico,
    this.comentarioServico = '',
    this.notaProfissional,
    this.comentarioProfissional = '',
    this.notaCliente,
    this.comentarioCliente = '',
  });
}

Future<AvaliacaoResposta?> mostrarAvaliacaoBottomSheet(
  BuildContext context, {
  required bool avaliandoCliente,
}) {
  return showModalBottomSheet<AvaliacaoResposta>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AvaliacaoBottomSheet(avaliandoCliente: avaliandoCliente),
  );
}

class _AvaliacaoBottomSheet extends StatefulWidget {
  final bool avaliandoCliente;

  const _AvaliacaoBottomSheet({required this.avaliandoCliente});

  @override
  State<_AvaliacaoBottomSheet> createState() => _AvaliacaoBottomSheetState();
}

class _AvaliacaoBottomSheetState extends State<_AvaliacaoBottomSheet> {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _texto = Color(0xFF17212B);
  static const Color _muted = Color(0xFF667085);
  static const Color _verde = Color(0xFF168A52);

  final TextEditingController _comentarioServico = TextEditingController();
  final TextEditingController _comentarioProfissional = TextEditingController();
  final TextEditingController _comentarioCliente = TextEditingController();

  int? _notaServico;
  int? _notaProfissional;
  int? _notaCliente;

  @override
  void dispose() {
    _comentarioServico.dispose();
    _comentarioProfissional.dispose();
    _comentarioCliente.dispose();
    super.dispose();
  }

  bool get _podeEnviar => widget.avaliandoCliente
      ? _notaServico != null && _notaProfissional != null
      : _notaCliente != null;

  void _enviar() {
    if (!_podeEnviar) return;
    Navigator.of(context).pop(
      AvaliacaoResposta(
        notaServico: _notaServico,
        comentarioServico: _comentarioServico.text.trim(),
        notaProfissional: _notaProfissional,
        comentarioProfissional: _comentarioProfissional.text.trim(),
        notaCliente: _notaCliente,
        comentarioCliente: _comentarioCliente.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                child: Column(
                  children: [
                    Icon(
                      widget.avaliandoCliente
                          ? Icons.rate_review_outlined
                          : Icons.person_outline,
                      color: _azul,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.avaliandoCliente
                          ? 'Avalie o serviço'
                          : 'Avalie o cliente',
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sua avaliação é opcional e ajuda a comunidade.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                  child: Column(
                    children: widget.avaliandoCliente
                        ? [
                            _avaliarAlvo(
                              titulo: 'Serviço',
                              nota: _notaServico,
                              comentario: _comentarioServico,
                              onNotaChanged: (nota) =>
                                  setState(() => _notaServico = nota),
                            ),
                            const SizedBox(height: 18),
                            _avaliarAlvo(
                              titulo: 'Profissional',
                              nota: _notaProfissional,
                              comentario: _comentarioProfissional,
                              onNotaChanged: (nota) =>
                                  setState(() => _notaProfissional = nota),
                            ),
                          ]
                        : [
                            _avaliarAlvo(
                              titulo: 'Cliente',
                              nota: _notaCliente,
                              comentario: _comentarioCliente,
                              onNotaChanged: (nota) =>
                                  setState(() => _notaCliente = nota),
                            ),
                          ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _podeEnviar ? _enviar : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _verde,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          disabledForegroundColor: _muted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Enviar avaliação'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Agora não'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avaliarAlvo({
    required String titulo,
    required int? nota,
    required TextEditingController comentario,
    required ValueChanged<int> onNotaChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: _texto,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (index) {
            final valor = index + 1;
            return IconButton(
              tooltip: '$valor estrela${valor == 1 ? '' : 's'}',
              onPressed: () => onNotaChanged(valor),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                valor <= (nota ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                color: valor <= (nota ?? 0)
                    ? const Color(0xFFF5A623)
                    : const Color(0xFF98A2B3),
                size: 32,
              ),
            );
          }),
        ),
        TextField(
          controller: comentario,
          maxLength: 150,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          minLines: 1,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Comentário (opcional)',
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF6F8FA),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
