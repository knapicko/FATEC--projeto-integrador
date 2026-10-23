import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PagamentoPedidoPage extends StatefulWidget {
  final int idSolicitacao;
  final String tituloServico;
  final String profissional;
  final double valor;
  final String? dataAgendada;
  final String? horaAgendada;

  const PagamentoPedidoPage({
    super.key,
    required this.idSolicitacao,
    required this.tituloServico,
    required this.profissional,
    required this.valor,
    this.dataAgendada,
    this.horaAgendada,
  });

  @override
  State<PagamentoPedidoPage> createState() => _PagamentoPedidoPageState();
}

class _PagamentoPedidoPageState extends State<PagamentoPedidoPage> {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _texto = Color(0xFF17212B);
  static const Color _muted = Color(0xFF667085);
  static const Color _fundo = Color(0xFFF6F8FA);

  final SupabaseClient _db = Supabase.instance.client;
  String _metodo = 'Pix';
  int _parcelas = 1;
  bool _salvando = false;
  String? _erro;
  String? _comprovante;
  DateTime? _dataPagamento;

  bool get _confirmado => _comprovante != null;

  String _formatarValor(double valor) =>
      'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}';

  String get _horaFormatada {
    final hora = widget.horaAgendada?.trim() ?? '';
    if (hora.length >= 5) return hora.substring(0, 5);
    return hora;
  }

  Future<void> _confirmarPagamento() async {
    if (_salvando || _confirmado) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });

    try {
      final resposta = await _db.rpc(
        'registrar_pagamento_solicitacao',
        params: {
          'p_id_solicitacao': widget.idSolicitacao,
          'p_forma_pagamento': _metodo,
          'p_parcelas': _metodo == 'Cartão de Crédito' ? _parcelas : 1,
        },
      );
      final linha = resposta is List && resposta.isNotEmpty
          ? Map<String, dynamic>.from(resposta.first as Map)
          : resposta is Map
          ? Map<String, dynamic>.from(resposta)
          : <String, dynamic>{};
      final numero = linha['numero_comprovante']?.toString();
      if (numero == null || numero.isEmpty) {
        throw Exception('O pagamento foi registrado, mas não retornou o comprovante.');
      }

      if (!mounted) return;
      setState(() {
        _comprovante = numero;
        _dataPagamento = DateTime.tryParse(
          linha['data_pagamento']?.toString() ?? '',
        )?.toLocal();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _texto,
        elevation: 0,
        title: Text(_confirmado ? 'Pagamento confirmado' : 'Pagamento'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _confirmado ? _buildConfirmacao() : _buildFormulario(),
      ),
    );
  }

  Widget _buildFormulario() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              _buildResumo(),
              const SizedBox(height: 22),
              const Text(
                'Forma de pagamento',
                style: TextStyle(
                  color: _texto,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _metodoTile('Pix', Icons.qr_code_2_rounded, 'Confirmação imediata'),
              const SizedBox(height: 8),
              _metodoTile(
                'Boleto',
                Icons.receipt_long_outlined,
                'Registro manual nesta versão',
              ),
              const SizedBox(height: 8),
              _metodoTile(
                'Cartão de Crédito',
                Icons.credit_card_outlined,
                'Nenhum dado do cartão será solicitado ou salvo',
              ),
              if (_metodo == 'Cartão de Crédito') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _parcelas,
                  decoration: InputDecoration(
                    labelText: 'Parcelas',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD9E0E5)),
                    ),
                  ),
                  items: List.generate(12, (index) => index + 1)
                      .map(
                        (quantidade) => DropdownMenuItem(
                          value: quantidade,
                          child: Text(
                            '$quantidade x ${_formatarValor(widget.valor / quantidade)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (valor) {
                    if (valor != null) setState(() => _parcelas = valor);
                  },
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF4D7A1)),
                ),
                child: const Text(
                  'O app ainda não está conectado a um serviço de pagamento. Ao confirmar, este pedido será registrado como pago para fins de teste.',
                  style: TextStyle(color: Color(0xFF76521B), fontSize: 12.5),
                ),
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(
                  _erro!,
                  style: const TextStyle(color: Color(0xFFB42318)),
                ),
              ],
            ],
          ),
        ),
        _buildBarraConfirmacao(),
      ],
    );
  }

  Widget _buildResumo() {
    final agendamento = [
      widget.dataAgendada?.trim() ?? '',
      _horaFormatada,
    ].where((item) => item.isNotEmpty).join(' às ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E8EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo do pedido', style: TextStyle(color: _muted)),
          const SizedBox(height: 12),
          Text(
            widget.tituloServico,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text('Profissional: ${widget.profissional}', style: const TextStyle(color: _muted)),
          if (agendamento.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(agendamento, style: const TextStyle(color: _muted)),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                _formatarValor(widget.valor),
                style: const TextStyle(
                  color: Color(0xFF087CA8),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metodoTile(String metodo, IconData icone, String descricao) {
    final selecionado = _metodo == metodo;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _metodo = metodo),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selecionado ? _azul : const Color(0xFFD9E0E5),
              width: selecionado ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icone, color: selecionado ? _azul : _muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metodo, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(descricao, style: const TextStyle(color: _muted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(
                selecionado ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selecionado ? _azul : const Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBarraConfirmacao() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          onPressed: _salvando ? null : _confirmarPagamento,
          icon: _salvando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.lock_outline),
          label: Text(_salvando ? 'Registrando...' : 'Confirmar pagamento'),
          style: FilledButton.styleFrom(
            backgroundColor: _azul,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmacao() {
    final data = _dataPagamento;
    final dataFormatada = data == null
        ? 'Agora'
        : '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 38, 20, 18),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(color: Color(0xFFE0F6FF), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, color: _azul, size: 52),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pagamento registrado',
            textAlign: TextAlign.center,
            style: TextStyle(color: _azul, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'O status do pedido foi atualizado para Pago.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E8EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Comprovante do pedido', style: TextStyle(fontWeight: FontWeight.w800)),
                const Divider(height: 24),
                _linhaComprovante('Serviço', widget.tituloServico),
                _linhaComprovante('Profissional', widget.profissional),
                _linhaComprovante('Forma', _metodo),
                if (_metodo == 'Cartão de Crédito')
                  _linhaComprovante('Parcelas', '$_parcelas x ${_formatarValor(widget.valor / _parcelas)}'),
                _linhaComprovante('Data', dataFormatada),
                _linhaComprovante('Documento', _comprovante!),
                const Divider(height: 24),
                _linhaComprovante('Total', _formatarValor(widget.valor), destaque: true),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Voltar ao pedido'),
              style: FilledButton.styleFrom(
                backgroundColor: _azul,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaComprovante(String titulo, String valor, {bool destaque = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 94, child: Text(titulo, style: const TextStyle(color: _muted))),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: destaque ? const Color(0xFF087CA8) : _texto,
                fontWeight: destaque ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
