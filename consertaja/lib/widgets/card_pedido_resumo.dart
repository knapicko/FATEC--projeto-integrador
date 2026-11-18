import 'package:flutter/material.dart';

import '../services/pedidos_cliente_service.dart';
import '../utils/cor_oficio.dart';
import '../utils/iniciais.dart';
import 'avisos_bottom_sheet.dart';

const _texto = Color(0xFF111827);
const _sec = Color(0xFF6B7280);

String _dd(int n) => n.toString().padLeft(2, '0');
String dataPedido(DateTime d) => '${_dd(d.day)}/${_dd(d.month)}/${d.year}';

String realPedido(double v) {
  final p = v.toStringAsFixed(2).split('.');
  final i = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return 'R\$ $i,${p[1]}';
}

/// Cor do selo de status.
Color corStatusPedido(PedidoResumo p) {
  final s = p.status.toLowerCase();
  if (p.concluido) return const Color(0xFF16A34A);
  if (s.contains('cancel') || s.contains('recus'))
    return const Color(0xFFDC2626);
  if (p.fkStatus == 1 || s.contains('aguardando pagamento')) {
    return const Color(0xFFF59E0B);
  }
  return const Color(0xFF0FB3FF);
}

Widget imagemPedido(String? url, String titulo, {double tamanho = 64}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      width: tamanho,
      height: tamanho,
      child: url != null
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _semImagem(titulo),
            )
          : _semImagem(titulo),
    ),
  );
}

Widget _semImagem(String titulo) => Container(
  color: const Color(0xFFE0F2FE),
  alignment: Alignment.center,
  child: const Icon(Icons.handyman_rounded, color: Color(0xFF0FB3FF)),
);

/// Linha do prestador: mini foto + nome.
Widget prestadorPedido(PedidoResumo p) => Row(
  children: [
    CircleAvatar(
      radius: 10,
      backgroundColor: const Color(0xFF0FB3FF),
      backgroundImage: p.fotoPrestador != null
          ? NetworkImage(p.fotoPrestador!)
          : null,
      child: p.fotoPrestador == null
          ? Text(
              obterIniciais(p.prestador),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    ),
    const SizedBox(width: 6),
    Expanded(
      child: Text(
        p.prestador,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _sec, fontSize: 12.5),
      ),
    ),
  ],
);

/// Card de um pedido do cliente (histórico).
class CardPedidoResumo extends StatelessWidget {
  const CardPedidoResumo({
    super.key,
    required this.pedido,
    required this.aoTocar,
  });

  final PedidoResumo pedido;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    final cor = corStatusPedido(p);
    final corFuncao = CorOficio.parse(p.corOficio);
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: p.precisaAvaliar
                ? const Color(0xFFFDBA74)
                : const Color(0xFFEDEFF2),
            width: p.precisaAvaliar ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                imagemPedido(p.imagem, p.titulo),
                if (p.precisaAvaliar)
                  const Positioned(top: -6, right: -6, child: SeloPendente()),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _texto,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        realPedido(p.valor),
                        style: const TextStyle(
                          color: _texto,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  prestadorPedido(p),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _selo(p.status, cor),
                      if (p.funcao != null)
                        _selo(p.funcao!, CorOficio.corTexto(corFuncao)),
                      if (p.data != null)
                        Text(
                          dataPedido(p.data!),
                          style: const TextStyle(color: _sec, fontSize: 11.5),
                        ),
                    ],
                  ),
                  if (p.precisaAvaliar) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Toque para avaliar este serviço',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selo(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      t,
      style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700),
    ),
  );
}

/// Estado vazio padrão das listas do perfil.
Widget listaVaziaPerfil(IconData icone, String titulo, String texto) =>
    ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2FE),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, color: const Color(0xFF0FB3FF), size: 36),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _texto,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _sec, height: 1.4),
          ),
        ),
      ],
    );

AppBar appBarPerfil(String titulo) => AppBar(
  backgroundColor: Colors.white,
  surfaceTintColor: Colors.white,
  elevation: 0,
  foregroundColor: _texto,
  title: Text(
    titulo,
    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
  ),
);
