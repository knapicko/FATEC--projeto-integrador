import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show navigatorKey;
import '../services/notificacoes/notificacao_service.dart';
import '../utils/abrir_solicitacao.dart';
import '../utils/fluxo_solicitacao.dart';

/// Estado de um pedido em que alguém está se deslocando.
class _PedidoEmTransito {
  const _PedidoEmTransito({
    required this.idSolicitacao,
    required this.fkStatus,
    required this.tipoExecucao,
    required this.codigo,
    required this.souCliente,
    this.distanciaMetros,
  });

  final int idSolicitacao;
  final int fkStatus;
  final String? tipoExecucao;
  final String codigo;
  final bool souCliente;
  final double? distanciaMetros;

  bool get chegou => fkStatus == 34 || fkStatus == 37;

  /// Quem mostra o código para o outro digitar:
  /// - busca/atendimento (33/34): o cliente;
  /// - devolução (36/37) e cliente levando o produto (38): o profissional.
  bool get mostroCodigo =>
      souCliente ? (fkStatus == 33 || fkStatus == 34) : fkStatus >= 36;

  String get titulo {
    final m = ModalidadeExecucao.fromString(tipoExecucao);
    if (fkStatus == 38) {
      return souCliente ? 'Você está a caminho' : 'Cliente a caminho';
    }
    final devolucao = fkStatus == 36 || fkStatus == 37;
    if (chegou) {
      return souCliente ? 'O profissional chegou!' : 'Você chegou ao cliente';
    }
    if (souCliente) {
      return devolucao
          ? 'Seu produto está a caminho'
          : (m.ehDomicilio
                ? 'Profissional a caminho'
                : 'Profissional indo buscar');
    }
    return devolucao ? 'Entrega em andamento' : 'Indo até o cliente';
  }

  String get legendaCodigo => mostroCodigo
      ? (souCliente ? 'Informe ao profissional' : 'Informe ao cliente')
      : (souCliente
            ? 'Peça o código ao profissional'
            : 'Peça o código ao cliente');
}

/// Código de entrega/recebimento flutuante, por cima de qualquer tela, com a
/// distância entre profissional e cliente e o aviso de "chegou".
///
/// Fica escondido nas telas que já mostram o código (elas chamam
/// [CodigoFlutuante.entrarNaTelaDoCodigo] / [CodigoFlutuante.sairDaTelaDoCodigo]).
class CodigoFlutuante extends StatefulWidget {
  const CodigoFlutuante({super.key});

  static final ValueNotifier<int> _telasDoCodigo = ValueNotifier(0);

  static void entrarNaTelaDoCodigo() => _telasDoCodigo.value++;
  static void sairDaTelaDoCodigo() {
    if (_telasDoCodigo.value > 0) _telasDoCodigo.value--;
  }

  @override
  State<CodigoFlutuante> createState() => _CodigoFlutuanteState();
}

class _CodigoFlutuanteState extends State<CodigoFlutuante> {
  static const _azul = Color(0xFF0FB3FF);
  static const _verde = Color(0xFF10B981);

  final _db = Supabase.instance.client;
  _PedidoEmTransito? _pedido;
  bool _expandido = true;
  Timer? _timer;
  StreamSubscription? _subAuth;
  StreamSubscription? _subNotif;
  Timer? _debounce;
  int? _ultimoStatus;

  @override
  void initState() {
    super.initState();
    _subAuth = _db.auth.onAuthStateChange.listen((_) => _agendar());
    _subNotif = NotificacaoService.instance.alteracoes.listen(
      (_) => _agendar(),
    );
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _consultar());
    _agendar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    _subAuth?.cancel();
    _subNotif?.cancel();
    super.dispose();
  }

  void _agendar() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _consultar);
  }

  Future<void> _consultar() async {
    final user = _db.auth.currentUser;
    if (user == null) {
      if (_pedido != null && mounted) setState(() => _pedido = null);
      return;
    }
    try {
      final u = await _db
          .from('usuarios')
          .select('id_usuario')
          .eq('auth_id', user.id)
          .maybeSingle();
      final idUsuario = (u?['id_usuario'] as num?)?.toInt();
      if (idUsuario == null) return;

      final profs = await _db
          .from('dados_profissionais')
          .select('id_profissional, fk_grupo_empresa')
          .eq('fk_usuario', idUsuario);
      final idsProf = [
        for (final p in profs)
          if (p['id_profissional'] != null)
            (p['id_profissional'] as num).toInt(),
      ];
      final idsGrupo = [
        for (final p in profs)
          if (p['fk_grupo_empresa'] != null)
            (p['fk_grupo_empresa'] as num).toInt(),
      ];
      final filtros = [
        'fk_usuario.eq.$idUsuario',
        if (idsProf.isNotEmpty) 'fk_profissional.in.(${idsProf.join(',')})',
        if (idsGrupo.isNotEmpty) 'fk_grupo_empresa.in.(${idsGrupo.join(',')})',
      ];
      final rows = await _db
          .from('solicitacoes')
          .select(
            'id_solicitacao, fk_status, tipo_execucao, codigo_rec_dev, fk_usuario',
          )
          .inFilter('fk_status', [33, 34, 36, 37, 38])
          .or(filtros.join(','))
          .order('id_solicitacao', ascending: false)
          .limit(1);
      if (rows.isEmpty) {
        if (_pedido != null && mounted) setState(() => _pedido = null);
        return;
      }
      final r = rows.first;
      final id = (r['id_solicitacao'] as num).toInt();
      final status = (r['fk_status'] as num).toInt();
      double? distancia;
      if (status != 38) {
        try {
          final d = await _db
              .from('deslocamento_profissional')
              .select('distancia_metros')
              .eq('fk_solicitacao', id)
              .maybeSingle();
          distancia = (d?['distancia_metros'] as num?)?.toDouble();
        } catch (_) {}
      }
      final novo = _PedidoEmTransito(
        idSolicitacao: id,
        fkStatus: status,
        tipoExecucao: r['tipo_execucao']?.toString(),
        codigo: r['codigo_rec_dev']?.toString().trim() ?? '',
        souCliente: (r['fk_usuario'] as num?)?.toInt() == idUsuario,
        distanciaMetros: distancia,
      );
      if (!mounted) return;
      // Ao chegar, abre o card de novo e vibra.
      if (novo.chegou && _ultimoStatus != status) {
        HapticFeedback.heavyImpact();
        _expandido = true;
      }
      _ultimoStatus = status;
      setState(() => _pedido = novo);
    } catch (e) {
      debugPrint('[código flutuante] $e');
    }
  }

  String _distancia(double m) => m >= 1000
      ? '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
      : '${m.round()} m';

  void _abrirPedido(_PedidoEmTransito p) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    abrirSolicitacaoPorStatus(
      ctx,
      p.idSolicitacao,
      comoProfissional: !p.souCliente,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CodigoFlutuante._telasDoCodigo,
      builder: (context, telas, _) {
        final p = _pedido;
        final visivel = p != null && telas == 0;
        final inferior = MediaQuery.of(context).padding.bottom;
        return Positioned(
          right: 12,
          bottom: inferior + 92,
          child: IgnorePointer(
            ignoring: !visivel,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              offset: visivel ? Offset.zero : const Offset(1.3, 0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: visivel ? 1 : 0,
                child: p == null ? const SizedBox.shrink() : _card(p),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card(_PedidoEmTransito p) {
    final cor = p.chegou ? _verde : _azul;
    return Material(
      color: Colors.transparent,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomRight,
        child: GestureDetector(
          onTap: () => setState(() => _expandido = !_expandido),
          child: Container(
            width: _expandido ? 236 : null,
            padding: _expandido
                ? const EdgeInsets.fromLTRB(14, 12, 12, 12)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: cor.withValues(alpha: 0.45),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: _expandido ? _conteudo(p, cor) : _compacto(p, cor),
          ),
        ),
      ),
    );
  }

  Widget _compacto(_PedidoEmTransito p, Color cor) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        p.chegou ? Icons.where_to_vote_rounded : Icons.navigation_rounded,
        color: cor,
        size: 20,
      ),
      const SizedBox(width: 6),
      Text(
        p.mostroCodigo && p.codigo.isNotEmpty
            ? p.codigo
            : (p.chegou
                  ? 'Chegou'
                  : (p.distanciaMetros != null
                        ? _distancia(p.distanciaMetros!)
                        : 'A caminho')),
        style: TextStyle(
          color: cor,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: p.mostroCodigo ? 3 : 0,
        ),
      ),
    ],
  );

  Widget _conteudo(_PedidoEmTransito p, Color cor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                p.chegou
                    ? Icons.where_to_vote_rounded
                    : Icons.navigation_rounded,
                color: cor,
                size: 17,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.titulo,
                maxLines: 2,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
            const Icon(
              Icons.unfold_less_rounded,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
        if (!p.chegou && p.distanciaMetros != null) ...[
          const SizedBox(height: 6),
          Text(
            'Distância: ${_distancia(p.distanciaMetros!)}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (p.mostroCodigo && p.codigo.isNotEmpty) ...[
          Row(
            children: [
              for (final d in p.codigo.split(''))
                Container(
                  width: 34,
                  height: 40,
                  margin: const EdgeInsets.only(right: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    d,
                    style: TextStyle(
                      color: cor,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Text(
          p.legendaCodigo,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: FilledButton(
            onPressed: () => _abrirPedido(p),
            style: FilledButton.styleFrom(
              backgroundColor: cor,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Abrir pedido',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
