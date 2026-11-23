import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'detalhes_pedido.dart';
import 'models/servico_profissional.dart';
import 'services/servicos_profissional_service.dart';
import 'utils/fluxo_solicitacao.dart';
import 'utils/voltar_fluxo_solicitacao.dart';
import 'widgets/skeletons_telas.dart';
import 'widgets/codigo_flutuante.dart';
import 'dart:async';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';

/// Retirado no Local — etapa 4 → etapa 5.
///
/// O serviço foi concluído na bancada (status 35, exibido como "Aguardando
/// retirada pelo cliente"). O cliente vai ao estabelecimento, recebe o código
/// de retirada do profissional, registra uma foto do produto e confirma.
/// A confirmação grava `fk_status = 6` e `etapa_solicitacao = 5`.
class ConfirmarRetiradaClientePage extends StatefulWidget {
  const ConfirmarRetiradaClientePage({super.key, required this.idSolicitacao});

  final int idSolicitacao;

  @override
  State<ConfirmarRetiradaClientePage> createState() =>
      _ConfirmarRetiradaClientePageState();
}

class _ConfirmarRetiradaClientePageState
    extends State<ConfirmarRetiradaClientePage>
    with VoltarParaPedidosMixin {
  /// Voltar (botão ou sistema) leva para meus_pedidos.dart.
  @override
  bool get voltarComoProfissional => false;

  static const _azul = Color(0xFF0FB3FF);
  static const _texto = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);

  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();
  final _codigo = List.generate(4, (_) => TextEditingController());

  bool _carregando = true;
  bool _enviando = false;
  bool _codigoValido = false;
  bool _podeRetirar = false;

  /// O profissional já confirmou que entregou? (1ª das duas confirmações)
  bool _profissionalConcluiu = false;
  String _codigoCorreto = '';
  String _nomeProfissional = 'Profissional';
  String _enderecoProfissional = '';
  String _tituloServico = 'Serviço';
  XFile? _foto;

  Timer? _polling;

  @override
  void initState() {
    super.initState();
    CodigoFlutuante.entrarNaTelaDoCodigo();
    _carregar();
    // Libera o botão assim que o profissional marcar como concluído.
    _polling = Timer.periodic(const Duration(seconds: 4), (_) async {
      try {
        final r = await _supabase
            .from('solicitacoes')
            .select('profissional_finalizado_atendimento, fk_status')
            .eq('id_solicitacao', widget.idSolicitacao)
            .maybeSingle();
        final concluiu = r?['profissional_finalizado_atendimento'] == true;
        if (mounted && concluiu != _profissionalConcluiu) {
          setState(() => _profissionalConcluiu = concluiu);
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _polling?.cancel();
    for (final c in _codigo) {
      c.dispose();
    }
    CodigoFlutuante.sairDaTelaDoCodigo();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final sol = await _supabase
          .from('solicitacoes')
          .select(
            'fk_status, etapa_solicitacao, tipo_execucao, codigo_rec_dev, '
            'fk_servico_prof, profissional_finalizado_atendimento',
          )
          .eq('id_solicitacao', widget.idSolicitacao)
          .single();
      final fluxo = FluxoSolicitacao(
        tipoExecucao: sol['tipo_execucao']?.toString(),
        fkStatus: (sol['fk_status'] as num?)?.toInt(),
        etapa: (sol['etapa_solicitacao'] as num?)?.toInt() ?? 0,
      );
      _podeRetirar = fluxo.aguardandoRetirada;
      _profissionalConcluiu =
          sol['profissional_finalizado_atendimento'] == true;
      _codigoCorreto = sol['codigo_rec_dev']?.toString().trim() ?? '';

      final idServico = (sol['fk_servico_prof'] as num?)?.toInt();
      if (idServico != null) {
        final DetalheServicoPublico? detalhe =
            await ServicosProfissionalService.buscarDetalhePublico(idServico);
        if (detalhe != null) {
          _nomeProfissional = detalhe.nomePrestador;
          _enderecoProfissional = detalhe.enderecoFormatado;
          _tituloServico = detalhe.servico.titulo;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar a retirada: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _validarCodigo() {
    final informado = _codigo.map((c) => c.text).join();
    setState(() {
      _codigoValido =
          informado.length == 4 &&
          _codigoCorreto.isNotEmpty &&
          informado == _codigoCorreto;
    });
  }

  Future<void> _tirarFoto() async {
    final foto = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
    );
    if (foto != null && mounted) setState(() => _foto = foto);
  }

  Future<void> _confirmarRetirada() async {
    if (!_podeRetirar ||
        !_profissionalConcluiu ||
        !_codigoValido ||
        _foto == null ||
        _enviando) {
      return;
    }
    setState(() => _enviando = true);
    try {
      final bytes = await _foto!.readAsBytes();
      final caminho =
          'solicitacao/${widget.idSolicitacao}/retirada_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from('Imagens Devolucao')
          .uploadBinary(
            caminho,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      final url = _supabase.storage
          .from('Imagens Devolucao')
          .getPublicUrl(caminho);

      await _supabase
          .from('solicitacoes')
          .update({
            'imagens_devolucao': [url],
            'fk_status': StatusSolicitacao.concluido,
            'etapa_solicitacao': ModalidadeExecucao.retiradaNoLocal.etapaFinal,
          })
          .eq('id_solicitacao', widget.idSolicitacao)
          .select('id_solicitacao')
          .single();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retirada confirmada. Serviço concluído!'),
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DetalhesPedidoPage(idSolicitacao: widget.idSolicitacao),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível confirmar a retirada: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final habilitado =
        _podeRetirar &&
        _profissionalConcluiu &&
        _codigoValido &&
        _foto != null &&
        !_enviando;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _texto,
        elevation: 0,
        title: const Text(
          'Retirada no Local',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          BotaoAjuda(
            passos: () => explicacaoDaTela(
              context,
              tela: 'Aqui você confirma a retirada do seu item.',
              conteudo: [
                'Confira o que foi feito e confirme quando estiver com o item em mãos.',
              ],
            ),
          ),
        ],
      ),
      body: _carregando
          ? const SkeletonEtapaFluxo(comMapa: false)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card(
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFFE0F2FE),
                        child: Icon(Icons.storefront_outlined, color: _azul),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _tituloServico,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _texto,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _nomeProfissional,
                              style: const TextStyle(color: _muted),
                            ),
                            if (_enderecoProfissional.isNotEmpty)
                              Text(
                                _enderecoProfissional,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_podeRetirar)
                  _card(
                    const Text(
                      'Este pedido não está aguardando retirada no momento.',
                      style: TextStyle(color: _muted),
                    ),
                  )
                else ...[
                  _card(
                    const Text(
                      'Seu produto está pronto! Vá até o estabelecimento, '
                      'peça o código de retirada ao profissional e registre '
                      'uma foto do produto para concluir.',
                      style: TextStyle(color: _muted, height: 1.4),
                    ),
                  ),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Foto do produto retirado',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _texto,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _enviando ? null : _tirarFoto,
                          icon: Icon(
                            _foto == null
                                ? Icons.add_a_photo_outlined
                                : Icons.check_circle,
                            color: _foto == null ? _azul : Colors.green,
                          ),
                          label: Text(
                            _foto == null
                                ? 'Adicionar foto obrigatória'
                                : 'Foto adicionada',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _card(
                    Column(
                      children: [
                        const Text(
                          'Código de retirada no balcão',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _texto,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 4; i++)
                              Container(
                                width: 56,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: TextField(
                                  controller: _codigo[i],
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  maxLength: 1,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: Color(0xFFF1F5F9),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide.none,
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(12),
                                      ),
                                    ),
                                  ),
                                  onChanged: (v) {
                                    if (v.isNotEmpty && i < 3) {
                                      FocusScope.of(context).nextFocus();
                                    }
                                    _validarCodigo();
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_codigo.every((c) => c.text.isNotEmpty))
                          Text(
                            _codigoValido
                                ? 'Código confirmado'
                                : 'Código inválido',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _codigoValido ? Colors.green : Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
      bottomNavigationBar: _carregando || !_podeRetirar
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  height: 52,
                  child: CorOriginal(interface: true, child: FilledButton.icon(
                    onPressed: habilitado ? _confirmarRetirada : null,
                    icon: _enviando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.inventory_2_outlined),
                    label: Text(
                      _enviando
                          ? 'Confirmando...'
                          : _profissionalConcluiu
                          ? 'Confirmar retirada'
                          : 'Aguardando o profissional confirmar a entrega',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _azul,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                  )),
                ),
              ),
            ),
    );
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: child,
  );
}
