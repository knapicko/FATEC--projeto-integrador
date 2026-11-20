import 'package:flutter/material.dart';

import '../services/requisitos_conta.dart';
import 'aviso_obrigatorio.dart';

/// Ícone da aba Perfil/Empresa da barra inferior com o selo "!" amarelo
/// quando ainda falta algo obrigatório na conta (cliente: endereço;
/// profissional: o que a home marca nos atalhos).
class IconeAbaPendente extends StatefulWidget {
  const IconeAbaPendente({
    super.key,
    required this.icone,
    required this.profissional,
  });

  final IconData icone;
  final bool profissional;

  @override
  State<IconeAbaPendente> createState() => _IconeAbaPendenteState();
}

class _IconeAbaPendenteState extends State<IconeAbaPendente> {
  ValueNotifier<bool> get _aviso => widget.profissional
      ? RequisitosConta.abaPendenteProfissional
      : RequisitosConta.abaPendenteCliente;

  @override
  void initState() {
    super.initState();
    RequisitosConta.atualizarAbaPendente(profissional: widget.profissional);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _aviso,
    builder: (_, pendente, _) => Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(widget.icone),
        if (pendente)
          const Positioned(
            right: -7,
            top: -5,
            child: SeloObrigatorio(tamanho: 14),
          ),
      ],
    ),
  );
}
