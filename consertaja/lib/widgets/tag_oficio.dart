import 'package:flutter/material.dart';
import '../utils/cor_oficio.dart';

class TagOficio extends StatelessWidget {
  final OficioInfo oficio;
  final double fontSize;
  final EdgeInsets padding;
  final double borderRadius;

  const TagOficio({
    super.key,
    required this.oficio,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final corBase = CorOficio.parse(oficio.cor);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: CorOficio.corFundo(corBase),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        oficio.funcao,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: CorOficio.corTexto(corBase),
        ),
      ),
    );
  }
}
