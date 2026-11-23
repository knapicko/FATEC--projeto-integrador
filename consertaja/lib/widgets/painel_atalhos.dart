import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Um atalho do painel da home do profissional.
class AtalhoItem {
  const AtalhoItem({
    required this.id,
    required this.icone,
    required this.rotulo,
    this.aoTocar,
    this.pendente = false,
    this.bloqueado = false,
  });

  final String id;
  final IconData icone;
  final String rotulo;
  final VoidCallback? aoTocar;
  final bool pendente;
  final bool bloqueado;
}

/// Painel de atalhos em páginas de 9 (3 x 3):
/// - deslizar para o lado troca de página (o card fica parado, só os atalhos
///   entram com uma animação rápida);
/// - segurar um atalho e soltar sobre outro troca os dois de lugar (inclusive
///   entre páginas: arraste até a borda para mudar de página). A ordem fica
///   salva no aparelho ([chaveOrdem]).
class PainelAtalhos extends StatefulWidget {
  const PainelAtalhos({
    super.key,
    required this.itens,
    required this.chaveOrdem,
    required this.construir,
    this.porPagina = 9,
    this.mostrarAtalho,
  });

  final List<AtalhoItem> itens;
  final String chaveOrdem;
  final Widget Function(AtalhoItem item) construir;
  final int porPagina;

  /// Quando recebe o id de um atalho, vai para a página dele (tutorial).
  final ValueNotifier<String?>? mostrarAtalho;

  @override
  State<PainelAtalhos> createState() => _PainelAtalhosState();
}

class _PainelAtalhosState extends State<PainelAtalhos> {
  static const _azul = Color(0xFF0FB3FF);

  List<String> _ordemSalva = const [];
  int _pagina = 0;
  int _direcao = 1;
  bool _arrastando = false;
  Timer? _timerBorda;

  @override
  void initState() {
    super.initState();
    _carregarOrdem();
    widget.mostrarAtalho?.addListener(_irParaAtalho);
  }

  void _irParaAtalho() {
    final id = widget.mostrarAtalho?.value;
    if (id == null) return;
    final i = _ordenados.indexWhere((a) => a.id == id);
    if (i >= 0) _irPara(i ~/ widget.porPagina);
  }

  @override
  void didUpdateWidget(covariant PainelAtalhos old) {
    super.didUpdateWidget(old);
    if (old.chaveOrdem != widget.chaveOrdem) {
      _pagina = 0;
      _carregarOrdem();
    }
  }

  @override
  void dispose() {
    widget.mostrarAtalho?.removeListener(_irParaAtalho);
    _timerBorda?.cancel();
    super.dispose();
  }

  Future<void> _carregarOrdem() async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList(widget.chaveOrdem) ?? const [];
      if (mounted) setState(() => _ordemSalva = l);
    } catch (_) {}
  }

  Future<void> _salvarOrdem(List<String> ordem) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(widget.chaveOrdem, ordem);
    } catch (_) {}
  }

  /// Itens na ordem salva; atalhos novos vão para o fim.
  List<AtalhoItem> get _ordenados {
    final porId = {for (final i in widget.itens) i.id: i};
    return [
      for (final id in _ordemSalva)
        if (porId.containsKey(id)) porId[id]!,
      for (final i in widget.itens)
        if (!_ordemSalva.contains(i.id)) i,
    ];
  }

  int get _paginas =>
      (widget.itens.length / widget.porPagina).ceil().clamp(1, 99);

  void _irPara(int pagina) {
    final alvo = pagina.clamp(0, _paginas - 1);
    if (alvo == _pagina) return;
    setState(() {
      _direcao = alvo > _pagina ? 1 : -1;
      _pagina = alvo;
    });
  }

  void _trocar(String a, String b) {
    if (a == b) return;
    final ids = [for (final i in _ordenados) i.id];
    final ia = ids.indexOf(a);
    final ib = ids.indexOf(b);
    if (ia < 0 || ib < 0) return;
    ids[ia] = b;
    ids[ib] = a;
    HapticFeedback.mediumImpact();
    setState(() => _ordemSalva = ids);
    _salvarOrdem(ids);
  }

  Widget _celula(AtalhoItem item) {
    final visual = widget.construir(item);
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != item.id,
      onAcceptWithDetails: (d) => _trocar(d.data, item.id),
      builder: (context, candidatos, _) => AnimatedScale(
        scale: candidatos.isNotEmpty ? 1.08 : 1,
        duration: const Duration(milliseconds: 140),
        child: LongPressDraggable<String>(
          data: item.id,
          hapticFeedbackOnStart: true,
          onDragStarted: () => setState(() => _arrastando = true),
          onDragEnd: (_) => setState(() => _arrastando = false),
          feedback: Material(
            color: Colors.transparent,
            child: Transform.scale(
              scale: 1.1,
              child: SizedBox(width: 96, child: visual),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: visual),
          child: visual,
        ),
      ),
    );
  }

  /// Faixa na borda: arrastando um atalho até ela, muda de página.
  Widget _borda(int passo) => DragTarget<String>(
    onWillAcceptWithDetails: (_) {
      _timerBorda?.cancel();
      _timerBorda = Timer(
        const Duration(milliseconds: 380),
        () => _irPara(_pagina + passo),
      );
      return false;
    },
    onLeave: (_) => _timerBorda?.cancel(),
    builder: (_, _, _) => Container(
      width: 22,
      decoration: BoxDecoration(
        color: _azul.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        passo < 0 ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
        color: _azul,
        size: 18,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final itens = _ordenados;
    final inicio = _pagina * widget.porPagina;
    final daPagina = itens.skip(inicio).take(widget.porPagina).toList();
    final linhas = <List<AtalhoItem?>>[];
    for (var i = 0; i < widget.porPagina; i += 3) {
      linhas.add([
        for (var j = i; j < i + 3; j++)
          j < daPagina.length ? daPagina[j] : null,
      ]);
    }

    final grade = KeyedSubtree(
      key: ValueKey(_pagina),
      child: Column(
        children: [
          for (var l = 0; l < linhas.length; l++) ...[
            if (l > 0) const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final it in linhas[l])
                  Expanded(
                    // Vaga vazia com a MESMA altura de um atalho (invisível):
                    // a página 2 não encolhe o card.
                    child: it == null
                        ? Visibility(
                            visible: false,
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            child: widget.construir(
                              const AtalhoItem(
                                id: '_vazio',
                                icone: Icons.circle,
                                rotulo: 'Linha\nLinha',
                              ),
                            ),
                          )
                        : _celula(it),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -150) _irPara(_pagina + 1);
            if (v > 150) _irPara(_pagina - 1);
          },
          child: Stack(
            children: [
              // Recorta só nas laterais (para a troca de página): em cima e
              // embaixo nada é cortado (selo "!" e o atalho sendo arrastado).
              ClipRect(
                clipper: const _SoLaterais(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final entrando = child.key == ValueKey(_pagina);
                    final de = Offset((entrando ? 0.35 : -0.35) * _direcao, 0);
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: de,
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  child: grade,
                ),
              ),
              if (_arrastando && _pagina > 0)
                Positioned(left: 0, top: 0, bottom: 0, child: _borda(-1)),
              if (_arrastando && _pagina < _paginas - 1)
                Positioned(right: 0, top: 0, bottom: 0, child: _borda(1)),
            ],
          ),
        ),
        if (_paginas > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _paginas; i++)
                GestureDetector(
                  onTap: () => _irPara(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _pagina ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _pagina ? _azul : const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                '${_pagina + 1}/$_paginas',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Recorte apenas horizontal (o conteúdo pode passar para cima/baixo).
class _SoLaterais extends CustomClipper<Rect> {
  const _SoLaterais();

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, -200, size.width, size.height + 200);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}
