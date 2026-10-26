import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'services/stripe_pagamento_service.dart';
import 'pedido_pago.dart';

class QrcodePixPage extends StatefulWidget {
  final int idSolicitacao;
  final String tituloServico;
  final String profissional;
  final double valor;
  final String? paymentIntentId;
  final String? pixCopiaECola;
  final String? pixQrCodeUrl;

  const QrcodePixPage({
    super.key,
    required this.idSolicitacao,
    required this.tituloServico,
    required this.profissional,
    required this.valor,
    this.paymentIntentId,
    this.pixCopiaECola,
    this.pixQrCodeUrl,
  });

  @override
  State<QrcodePixPage> createState() => _QrcodePixPageState();
}

class _QrcodePixPageState extends State<QrcodePixPage> {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _texto = Color(0xFF17212B);
  static const Color _muted = Color(0xFF667085);
  static const Color _fundo = Color(0xFFF6F8FA);
  static const Color _vermelho = Color(0xFFE11D48);

  static const String _codigoPixDemonstracao =
      '00020126580014br.gov.bcb.pix0136123e4567-e89b-12d3-a456-4266141740005204000053039865802BR5925ConsertaJa Pagamentos6009Sao Paulo62070503***6304ABCD';

  late Duration _restante;
  Timer? _timer;
  Timer? _statusTimer;
  String _statusPagamento = 'Aguardando pagamento';
  String? _codigoPix;
  String? _qrCodeUrl;
  bool _statusCarregando = false;
  bool _abrindoPagamentoConcluido = false;

  bool get _modoDemonstracao =>
      widget.paymentIntentId == null ||
      (_codigoPix == null && _qrCodeUrl == null);

  @override
  void initState() {
    super.initState();
    _restante = const Duration(minutes: 29, seconds: 59);
    _codigoPix = widget.pixCopiaECola;
    _qrCodeUrl = widget.pixQrCodeUrl;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_restante.inSeconds <= 0) {
        _timer?.cancel();
        setState(() => _restante = Duration.zero);
        return;
      }
      setState(() => _restante -= const Duration(seconds: 1));
    });
    if (widget.paymentIntentId != null) {
      _consultarStatus();
      _statusTimer = Timer.periodic(
        const Duration(seconds: 6),
        (_) => _consultarStatus(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  String get _tempoFormatado {
    final m = _restante.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _restante.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatarValor(double valor) {
    final parts = valor.toStringAsFixed(2).split('.');
    final inteiro = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < inteiro.length; i++) {
      final pos = inteiro.length - i;
      buffer.write(inteiro[i]);
      if (pos > 1 && pos % 3 == 1) buffer.write('.');
    }
    return 'R\$ ${buffer.toString()},${parts[1]}';
  }

  Future<void> _copiarCodigo() async {
    await Clipboard.setData(
      ClipboardData(text: _codigoPix ?? _codigoPixDemonstracao),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Código Pix copiado')));
  }

  Future<void> _consultarStatus() async {
    if (!mounted || widget.paymentIntentId == null || _statusCarregando) {
      return;
    }
    _statusCarregando = true;
    try {
      final response = await StripePagamentoService.consultarStatus(
        idSolicitacao: widget.idSolicitacao,
      );
      if (!mounted) return;
      setState(() {
        _codigoPix ??= response.pixCopiaECola;
        _qrCodeUrl ??= response.pixQrCodeUrl;
        _statusPagamento = _textoStatus(response.status);
      });
      if (response.status == 'succeeded') {
        _statusTimer?.cancel();
        await _abrirPagamentoConcluido();
      }
    } catch (_) {
      // A tela continua exibindo o QR Code enquanto o próximo ciclo tenta
      // consultar novamente o webhook/status no servidor.
    } finally {
      _statusCarregando = false;
    }
  }

  Future<void> _abrirPagamentoConcluido() async {
    if (!mounted || _abrindoPagamentoConcluido) return;
    _abrindoPagamentoConcluido = true;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PedidoPagoPage(idSolicitacao: widget.idSolicitacao),
      ),
    );
  }

  String _textoStatus(String status) {
    switch (status) {
      case 'succeeded':
        return 'Pagamento confirmado';
      case 'failed':
      case 'canceled':
        return 'Pagamento não concluído';
      case 'processing':
        return 'Pagamento em processamento';
      default:
        return 'Aguardando pagamento';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _fundo,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    _buildResumo(),
                    const SizedBox(height: 22),
                    const Text(
                      'Escaneie o QR Code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(child: _buildQrCard()),
                    const SizedBox(height: 16),
                    _buildCopiaECola(),
                    const SizedBox(height: 22),
                    const Text(
                      'Como pagar:',
                      style: TextStyle(
                        color: _texto,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _passo(
                      1,
                      'Abra o app do seu banco ou instituição financeira.',
                    ),
                    const SizedBox(height: 10),
                    _passo(
                      2,
                      'Escolha a opção de pagar via Pix (QR Code ou Copia e Cola).',
                    ),
                    const SizedBox(height: 10),
                    _passo(
                      3,
                      'Escaneie o código acima ou cole a chave copiada para concluir.',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      disabledForegroundColor: _azul,
                      side: const BorderSide(color: _azul, width: 1.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      _statusPagamento,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: _azul,
          ),
          const Expanded(
            child: Text(
              'Pagamento via PIX',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _azul,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildResumo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo do Pedido',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tituloServico,
                      style: const TextStyle(
                        color: Color(0xFF0284C7),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Profissional: ${widget.profissional}',
                      style: const TextStyle(color: _muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Valor Total',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatarValor(widget.valor),
                    style: const TextStyle(
                      color: _azul,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    final expirado = _restante.inSeconds <= 0;
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: _azul.withValues(alpha: 0.7),
        radius: 22,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
        child: Column(
          children: [
            Container(
              width: 188,
              height: 188,
              color: Colors.white,
              alignment: Alignment.center,
              child: _qrCodeUrl != null && _qrCodeUrl!.isNotEmpty
                  ? Image.network(
                      _qrCodeUrl!,
                      width: 176,
                      height: 176,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => QrImageView(
                        data: _codigoPix ?? _codigoPixDemonstracao,
                        version: QrVersions.auto,
                        size: 176,
                        backgroundColor: Colors.white,
                      ),
                    )
                  : QrImageView(
                      data: _codigoPix ?? _codigoPixDemonstracao,
                      version: QrVersions.auto,
                      size: 176,
                      backgroundColor: Colors.white,
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: _vermelho),
                const SizedBox(width: 4),
                Text(
                  expirado ? 'QR Code expirado' : 'Expira em $_tempoFormatado',
                  style: const TextStyle(
                    color: _vermelho,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopiaECola() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pix Copia e Cola',
            style: TextStyle(
              color: _texto,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _codigoPix ?? _codigoPixDemonstracao,
              style: TextStyle(color: _muted, fontSize: 12.5, height: 1.35),
            ),
          ),
          if (_modoDemonstracao)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Modo demonstração: este QR Code não realiza um pagamento real.',
                style: TextStyle(
                  color: _vermelho,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _copiarCodigo,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text(
                'Copiar Código',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _azul,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passo(int numero, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFD7F1FF),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$numero',
            style: const TextStyle(
              color: _azul,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: _texto,
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 7.0;
      const gap = 5.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
