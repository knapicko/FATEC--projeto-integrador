import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/fluxo_solicitacao.dart';
import '../utils/iniciais.dart';
import 'imagem_app.dart';
import '../utils/movimento.dart';

const _azul = Color(0xFF0FB3FF);
const _azulEscuro = Color(0xFF006DCC);
const _texto = Color(0xFF0F172A);
const _sec = Color(0xFF64748B);
const _verde = Color(0xFF10B981);
const _borda = Color(0xFFE2E8F0);

final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

// =============================================================================
// Proposta do Radar (solicitação geográfica) dentro do chat
// =============================================================================

/// Proposta pendente do Radar entre o cliente e o profissional/empresa da
/// conversa (RPC `proposta_radar_da_conversa`, docs/sql/v0_5_ajustes.sql).
class PropostaRadarChat {
  const PropostaRadarChat({
    required this.idProposta,
    required this.valor,
    required this.idSolicitacaoGeo,
    required this.titulo,
    required this.descricao,
    required this.imagens,
    required this.metodoEntrega,
    required this.souCliente,
  });

  final int idProposta;
  final double valor;
  final int idSolicitacaoGeo;
  final String titulo;
  final String descricao;
  final List<String> imagens;
  final String metodoEntrega;
  final bool souCliente;

  static Future<PropostaRadarChat?> daConversa(int idConversa) async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'proposta_radar_da_conversa',
        params: {'p_id_conversa': idConversa},
      );
      final lista = rows as List;
      if (lista.isEmpty) return null;
      final m = Map<String, dynamic>.from(lista.first as Map);
      return PropostaRadarChat(
        idProposta: (m['id_proposta'] as num).toInt(),
        valor: (m['valor'] as num?)?.toDouble() ?? 0,
        idSolicitacaoGeo: (m['id_solicitacao_geografica'] as num).toInt(),
        titulo: m['titulo']?.toString().trim() ?? '',
        descricao: m['descricao']?.toString().trim() ?? '',
        imagens: [
          if (m['img_solicitacao'] is List)
            for (final i in m['img_solicitacao'] as List)
              if (i != null && i.toString().startsWith('http')) i.toString(),
        ],
        metodoEntrega: m['metodo_entrega']?.toString() ?? '',
        souCliente: m['sou_cliente'] == true,
      );
    } catch (e) {
      // Banco sem a RPC (SQL v0.5 não rodado) ou sem proposta: nada a mostrar.
      debugPrint('[chat] proposta do radar: $e');
      return null;
    }
  }

  static Future<void> atualizarValor(int idProposta, double valor) async {
    try {
      await Supabase.instance.client.rpc(
        'atualizar_valor_proposta_geografica',
        params: {'p_id_proposta': idProposta, 'p_valor': valor},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}

/// Container acima da barra de mensagem com a proposta do Radar.
/// - cliente: aceitar / recusar;
/// - profissional: aguardando o cliente, com "Alterar valor".
class BarraPropostaRadar extends StatelessWidget {
  const BarraPropostaRadar({
    super.key,
    required this.proposta,
    this.ocupado = false,
    this.onAceitar,
    this.onRecusar,
    this.onAlterar,
  });

  final PropostaRadarChat proposta;
  final bool ocupado;
  final VoidCallback? onAceitar;
  final VoidCallback? onRecusar;
  final VoidCallback? onAlterar;

  @override
  Widget build(BuildContext context) {
    final cliente = proposta.souCliente;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.radar_rounded, color: _azulEscuro),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente
                          ? 'Proposta do Radar'
                          : 'Proposta enviada · aguardando o cliente',
                      style: const TextStyle(
                        color: _sec,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      proposta.titulo.isEmpty
                          ? 'Pedido pelo Radar'
                          : proposta.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _texto,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _moeda.format(proposta.valor),
                style: const TextStyle(
                  color: _azulEscuro,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (ocupado)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(6),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
            )
          else if (cliente)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRecusar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Recusar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAceitar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _verde,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Aceitar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAlterar,
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text(
                  'Alterar valor',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _azulEscuro,
                  side: const BorderSide(color: Color(0xFFBAE6FD)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sheet do profissional para uma proposta do Radar aguardando o cliente:
/// só foto e nome do cliente, o valor e a imagem que o cliente anexou.
/// Devolve true quando o valor foi alterado.
Future<bool?> abrirSheetPropostaRadar(
  BuildContext context, {
  required String nomeCliente,
  String? fotoCliente,
  required PropostaRadarChat proposta,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _SheetPropostaRadar(
      nomeCliente: nomeCliente,
      fotoCliente: fotoCliente,
      proposta: proposta,
    ),
  );
}

class _SheetPropostaRadar extends StatefulWidget {
  const _SheetPropostaRadar({
    required this.nomeCliente,
    this.fotoCliente,
    required this.proposta,
  });

  final String nomeCliente;
  final String? fotoCliente;
  final PropostaRadarChat proposta;

  @override
  State<_SheetPropostaRadar> createState() => _SheetPropostaRadarState();
}

class _SheetPropostaRadarState extends State<_SheetPropostaRadar> {
  late final _valor = TextEditingController(
    text: NumberFormat('#,##0.00', 'pt_BR').format(widget.proposta.valor),
  );
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  double get _numero =>
      double.tryParse(
        _valor.text
            .replaceAll(r'R$', '')
            .replaceAll('.', '')
            .replaceAll(',', '.')
            .trim(),
      ) ??
      0;

  Future<void> _salvar() async {
    final v = _numero;
    if (v <= 0) {
      setState(() => _erro = 'Informe um valor válido.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      await PropostaRadarChat.atualizarValor(widget.proposta.idProposta, v);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _erro = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _verImagem(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(child: InteractiveViewer(child: ImagemApp(child: Image.network(url)))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foto = widget.fotoCliente ?? '';
    final imagens = widget.proposta.imagens;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _borda,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CorOriginal(child: CircleAvatar(
                    radius: 26,
                    backgroundColor: _azul,
                    backgroundImage: foto.startsWith('http')
                        ? NetworkImage(foto)
                        : null,
                    child: foto.startsWith('http')
                        ? null
                        : Text(
                            obterIniciais(widget.nomeCliente),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.nomeCliente,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _texto,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'Proposta do Radar aguardando o cliente',
                          style: TextStyle(color: _sec, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (imagens.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Imagem enviada pelo cliente',
                  style: TextStyle(
                    color: _texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: imagens.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _verImagem(imagens[i]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ImagemApp(child: Image.network(
                          imagens[i],
                          width: imagens.length == 1 ? 300 : 180,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 180,
                            color: const Color(0xFFF1F5F9),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: _sec,
                            ),
                          ),
                        )),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                'Valor da proposta',
                style: TextStyle(
                  color: _texto,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _valor,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _texto,
                ),
                decoration: InputDecoration(
                  prefixText: r'R$ ',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  errorText: _erro,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _borda),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _borda),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _azul, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              CorOriginal(interface: true, child: ElevatedButton(
                onPressed: _enviando ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _azul,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _enviando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Atualizar proposta',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Etapas do pedido (toque na faixa do pedido no topo do chat)
// =============================================================================

String _descricaoEtapa(
  ModalidadeExecucao m,
  String titulo,
  bool comoProfissional,
) {
  final voce = comoProfissional ? 'o cliente' : 'você';
  final seu = comoProfissional ? 'do cliente' : 'seu';
  switch (titulo) {
    case 'Aceito':
      return 'Proposta aceita e pagamento confirmado';
    case 'Busca':
      return 'O profissional busca o produto no endereço $seu';
    case 'A caminho':
      return 'O profissional está indo até o endereço $seu';
    case 'No Local':
      return 'Atendimento no endereço $seu';
    case 'Cliente':
      return comoProfissional
          ? 'O cliente leva o produto até você'
          : 'Você leva o produto até o profissional';
    case 'Processo':
      return 'O serviço está sendo realizado';
    case 'Retirada':
      return comoProfissional
          ? 'O cliente retira o produto no seu endereço'
          : 'Você retira o produto no local do profissional';
    case 'Entrega':
      return m == ModalidadeExecucao.levaETraz ||
              m == ModalidadeExecucao.recebaEmCasa
          ? 'O profissional devolve o produto para $voce'
          : 'Entrega do produto';
    case 'Concluído':
      return 'Serviço finalizado';
  }
  return '';
}

/// Lista radial (bolinhas ligadas por uma linha) com as etapas já feitas e as
/// que faltam, conforme o método de entrega, e um botão para o pedido.
Future<void> abrirSheetEtapasPedido(
  BuildContext context, {
  required String codigo,
  required String nomeServico,
  required String status,
  required String? tipoExecucao,
  required int? fkStatus,
  required int etapa,
  required bool comoProfissional,
  required VoidCallback onIrParaPedido,
}) {
  final fluxo = FluxoSolicitacao(
    tipoExecucao: tipoExecucao,
    fkStatus: fkStatus,
    etapa: etapa,
    statusTexto: status,
  );
  final titulos = fluxo.modalidade.titulosEtapas;
  final efetiva = fluxo.etapaEfetiva;
  // Etapa 1 = aceito; enquanto não pago, ela é a atual; depois de pago, a
  // próxima (deslocamento) passa a ser a atual.
  final atual = fluxo.estaConcluido
      ? titulos.length + 1
      : (efetiva <= 1 ? (fluxo.aguardandoPagamento ? 1 : 2) : efetiva);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(ctx).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: _borda,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.build_outlined, color: _azulEscuro),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        codigo,
                        style: const TextStyle(
                          color: _sec,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        nomeServico,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _texto,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _pill(fluxo.rotuloPorModalidade ?? status, _azulEscuro),
                _pill(fluxo.modalidade.valorBanco, _sec),
              ],
            ),
            const SizedBox(height: 18),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < titulos.length; i++)
                      _ItemEtapa(
                        numero: i + 1,
                        titulo: titulos[i],
                        descricao: _descricaoEtapa(
                          fluxo.modalidade,
                          titulos[i],
                          comoProfissional,
                        ),
                        feita: i + 1 < atual,
                        atual: i + 1 == atual,
                        ultima: i == titulos.length - 1,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            CorOriginal(interface: true, child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                onIrParaPedido();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 19),
              label: const Text(
                'Ir para o pedido',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _azul,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )),
          ],
        ),
      ),
    ),
  );
}

Widget _pill(String texto, Color cor) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: cor.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    texto,
    style: TextStyle(color: cor, fontSize: 12.5, fontWeight: FontWeight.w700),
  ),
);

class _ItemEtapa extends StatefulWidget {
  const _ItemEtapa({
    required this.numero,
    required this.titulo,
    required this.descricao,
    required this.feita,
    required this.atual,
    required this.ultima,
  });

  final int numero;
  final String titulo;
  final String descricao;
  final bool feita;
  final bool atual;
  final bool ultima;

  @override
  State<_ItemEtapa> createState() => _ItemEtapaState();
}

class _ItemEtapaState extends State<_ItemEtapa>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulso = AnimationController(
    vsync: this,
    duration: duracao(const Duration(milliseconds: 1400)),
  );

  @override
  void initState() {
    super.initState();
    if (widget.atual) _pulso.repetir();
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cor = widget.feita
        ? _verde
        : widget.atual
        ? _azul
        : const Color(0xFFCBD5E1);
    Widget bolinha = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: widget.feita
            ? _verde
            : widget.atual
            ? _azul
            : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: cor, width: 2),
      ),
      child: Center(
        child: widget.feita
            ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
            : Text(
                '${widget.numero}',
                style: TextStyle(
                  color: widget.atual ? Colors.white : _sec,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
      ),
    );
    if (widget.atual) {
      bolinha = AnimatedBuilder(
        animation: _pulso,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 30 + 16 * _pulso.value,
              height: 30 + 16 * _pulso.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _azul.withValues(alpha: 0.28 * (1 - _pulso.value)),
              ),
            ),
            child!,
          ],
        ),
        child: bolinha,
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 46,
            child: Column(
              children: [
                SizedBox(height: 46, child: Center(child: bolinha)),
                if (!widget.ultima)
                  Expanded(
                    child: Container(
                      width: 2.4,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.feita ? _verde : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 11, bottom: widget.ultima ? 4 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.titulo,
                          style: TextStyle(
                            color: widget.feita || widget.atual ? _texto : _sec,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.atual)
                        _pill('Agora', _azulEscuro)
                      else if (widget.feita)
                        _pill('Feito', _verde),
                    ],
                  ),
                  if (widget.descricao.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      widget.descricao,
                      style: const TextStyle(
                        color: _sec,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
