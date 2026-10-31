import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'gestao_equipe.dart';
import 'meus_servicos_solicitados.dart';
import 'tela_chat_profissional.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/iniciais.dart';

class SolicitacaoEmAndamentoPage extends StatefulWidget {
  final int idSolicitacao;
  final String codigoPedido;
  final String nomeCliente;
  final String? fotoCliente;
  final String nomeServico;
  final String modalidade;
  final String? detalhes;
  final double? valorFinal;
  final bool isEmpresa;
  final int? idGrupoEmpresa;
  final String? fotoPerfilProfissional;
  final String? nomeProfissional;

  const SolicitacaoEmAndamentoPage({
    super.key,
    required this.idSolicitacao,
    required this.codigoPedido,
    required this.nomeCliente,
    this.fotoCliente,
    required this.nomeServico,
    this.modalidade = 'Leva e Traz',
    this.detalhes,
    this.valorFinal,
    this.isEmpresa = false,
    this.idGrupoEmpresa,
    this.fotoPerfilProfissional,
    this.nomeProfissional,
  });

  @override
  State<SolicitacaoEmAndamentoPage> createState() =>
      _SolicitacaoEmAndamentoPageState();
}

class _SolicitacaoEmAndamentoPageState extends State<SolicitacaoEmAndamentoPage> {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _fundo = Color(0xFFF8FAFC);
  static const Color _textoEscuro = Color(0xFF0F172A);
  static const Color _textoMuted = Color(0xFF64748B);
  static const Color _cinzaBorda = Color(0xFFE2E8F0);
  static const Color _cinzaCard = Color(0xFFF1F5F9);

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();

  bool _carregando = true;
  bool _salvando = false;

  // Diagnóstico
  String? _diagnostico;
  final TextEditingController _diagnosticoController = TextEditingController();

  // Fotos de recebimento carregadas
  List<String> _imagensRecebimento = [];

  // Evidências do conserto
  List<String> _imagensEmAndamento = [];
  bool _enviandoFoto = false;

  // Tempo de serviço (cronômetro)
  Timer? _timer;
  int _segundosAndamento = 0;
  bool _pausado = false;
  DateTime? _dataInicio;

  @override
  void initState() {
    super.initState();
    _carregarDadosSolicitacao();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _diagnosticoController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosSolicitacao() async {
    try {
      final res = await _supabase
          .from('solicitacoes')
          .select('*')
          .eq('id_solicitacao', widget.idSolicitacao)
          .maybeSingle();

      if (res != null && mounted) {
        // Carrega diagnóstico existente
        _diagnostico = res['diagnostico'] as String?;
        if (_diagnostico != null) {
          _diagnosticoController.text = _diagnostico!;
        }

        // Carrega imagens de recebimento
        if (res['imagens_recebimento'] != null) {
          final dynList = res['imagens_recebimento'];
          if (dynList is List) {
            _imagensRecebimento =
                dynList.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
          }
        }

        // Carrega imagens em andamento
        if (res['imagens_em_andamento'] != null) {
          final dynList = res['imagens_em_andamento'];
          if (dynList is List) {
            _imagensEmAndamento =
                dynList.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
          }
        }

        // Duração e estado de pausa
        _pausado = res['andamento_pausado'] == true;
        final duracaoSalva = (res['duracao_servico'] as num?)?.toInt() ?? 0;

        if (res['data_inicio_andamento'] != null) {
          _dataInicio = DateTime.tryParse(res['data_inicio_andamento'].toString());
        }
        _dataInicio ??= DateTime.now();

        if (_pausado) {
          _segundosAndamento = duracaoSalva;
        } else {
          final diff = DateTime.now().difference(_dataInicio!).inSeconds;
          _segundosAndamento = (diff > 0 ? diff : 0) + duracaoSalva;
        }

        _iniciarCronometro();
      }
    } catch (e) {
      debugPrint('Erro ao carregar solicitacao: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _iniciarCronometro() {
    _timer?.cancel();
    if (_pausado) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_pausado) {
        setState(() {
          _segundosAndamento++;
        });
      }
    });
  }

  String _formatarTempo(int totalSegundos) {
    final dias = totalSegundos ~/ 86400;
    final restoDia = totalSegundos % 86400;
    final horas = restoDia ~/ 3600;
    final minutos = (restoDia % 3600) ~/ 60;
    final segundos = restoDia % 60;

    final hStr = horas.toString().padLeft(2, '0');
    final mStr = minutos.toString().padLeft(2, '0');
    final sStr = segundos.toString().padLeft(2, '0');

    if (dias > 0) {
      final dStr = dias.toString().padLeft(2, '0');
      return '${dStr}d $hStr:$mStr:$sStr';
    }
    return '$hStr:$mStr:$sStr';
  }

  Future<void> _alternarPausa() async {
    final novoEstado = !_pausado;
    setState(() {
      _pausado = novoEstado;
    });

    if (novoEstado) {
      _timer?.cancel();
    } else {
      _iniciarCronometro();
    }

    try {
      await _supabase.from('solicitacoes').update({
        'andamento_pausado': novoEstado,
        'duracao_servico': _segundosAndamento,
      }).eq('id_solicitacao', widget.idSolicitacao);
    } catch (e) {
      debugPrint('Erro ao salvar pausa: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            novoEstado
                ? 'Cronômetro pausado (Falta de peça / Interrupção).'
                : 'Cronômetro retomado com sucesso.',
          ),
          backgroundColor: novoEstado ? Colors.amber.shade800 : const Color(0xFF16A34A),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _abrirModalDiagnostico() async {
    _diagnosticoController.text = _diagnostico ?? '';
    final resultado = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _azul.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.manage_search_rounded,
                        color: _azul,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Diagnóstico Técnico',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textoEscuro,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Descreva em detalhes o defeito identificado no aparelho, componentes afetados e a solução técnica aplicada.',
                  style: TextStyle(
                    fontSize: 13,
                    color: _textoMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _diagnosticoController,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 14, color: _textoEscuro),
                  decoration: InputDecoration(
                    hintText:
                        'Ex: Falha no capacitor de alta tensão em curto e desgaste severo no emissor do magnetron. Substituído conjunto...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    filled: true,
                    fillColor: _cinzaCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _cinzaBorda),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _cinzaBorda),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: _azul, width: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: () {
                      final texto = _diagnosticoController.text.trim();
                      if (texto.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Por favor, informe o diagnóstico técnico.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      Navigator.of(ctx).pop(texto);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _azul,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Confirmar Diagnóstico',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (resultado != null && resultado.isNotEmpty) {
      setState(() {
        _diagnostico = resultado;
      });
      try {
        await _supabase.from('solicitacoes').update({
          'diagnostico': resultado,
        }).eq('id_solicitacao', widget.idSolicitacao);
      } catch (e) {
        debugPrint('Erro ao salvar diagnóstico: $e');
      }
    }
  }

  Future<void> _adicionarFotoEvidencia({ImageSource source = ImageSource.camera}) async {
    try {
      final XFile? foto = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (foto == null) return;

      setState(() => _enviandoFoto = true);

      final bytes = await foto.readAsBytes();
      final ext = foto.name.split('.').last;
      final nomeArquivo =
          'andamento_${widget.idSolicitacao}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      String? urlPublica;

      // 1. Tentar bucket 'Imagens Em Andamento'
      try {
        await _supabase.storage.from('Imagens Em Andamento').uploadBinary(
              nomeArquivo,
              bytes,
              fileOptions: FileOptions(
                contentType: 'image/$ext',
                upsert: true,
              ),
            );
        urlPublica = _supabase.storage
            .from('Imagens Em Andamento')
            .getPublicUrl(nomeArquivo);
      } catch (_) {
        // 2. Fallback bucket 'imagens_em_andamento'
        try {
          await _supabase.storage.from('imagens_em_andamento').uploadBinary(
                nomeArquivo,
                bytes,
                fileOptions: FileOptions(
                  contentType: 'image/$ext',
                  upsert: true,
                ),
              );
          urlPublica = _supabase.storage
              .from('imagens_em_andamento')
              .getPublicUrl(nomeArquivo);
        } catch (_) {
          // 3. Fallback bucket 'solicitacoes'
          try {
            await _supabase.storage.from('solicitacoes').uploadBinary(
                  nomeArquivo,
                  bytes,
                  fileOptions: FileOptions(
                    contentType: 'image/$ext',
                    upsert: true,
                  ),
                );
            urlPublica =
                _supabase.storage.from('solicitacoes').getPublicUrl(nomeArquivo);
          } catch (_) {
            urlPublica = foto.path;
          }
        }
      }

      final novaLista = List<String>.from(_imagensEmAndamento)..add(urlPublica);
      setState(() {
        _imagensEmAndamento = novaLista;
      });

      // Atualizar no Supabase
      try {
        await _supabase.from('solicitacoes').update({
          'imagens_em_andamento': novaLista,
        }).eq('id_solicitacao', widget.idSolicitacao);
      } catch (e) {
        debugPrint('Erro ao atualizar imagens_em_andamento: $e');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao anexar foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  Future<void> _removerFoto(int index) async {
    final novaLista = List<String>.from(_imagensEmAndamento)..removeAt(index);
    setState(() {
      _imagensEmAndamento = novaLista;
    });
    try {
      await _supabase.from('solicitacoes').update({
        'imagens_em_andamento': novaLista,
      }).eq('id_solicitacao', widget.idSolicitacao);
    } catch (e) {
      debugPrint('Erro ao remover imagem: $e');
    }
  }

  void _abrirChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaChatProfissional(
          nomeProfissional: widget.nomeCliente,
          fotoProfissional: widget.fotoCliente ?? '',
          oficioPrincipal: widget.nomeServico,
          idProfissional: widget.isEmpresa ? null : null,
          idGrupoEmpresa: widget.idGrupoEmpresa,
          idSolicitacao: widget.idSolicitacao,
        ),
      ),
    );
  }

  void _abrirPerfilProfissional() {
    if (widget.isEmpresa) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const GestaoEquipePage(),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TelaMeuPerfilProfissionalPage(isVisitante: false),
        ),
      );
    }
  }

  void _notificarCliente() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 26),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.notifications_active_outlined, color: _azul, size: 24),
                SizedBox(width: 10),
                Text(
                  'Notificar Cliente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textoEscuro,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Envie uma mensagem instantânea sobre o status do reparo para ${widget.nomeCliente}.',
              style: const TextStyle(fontSize: 13, color: _textoMuted),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.handyman_outlined, color: _azul),
              title: const Text('Aparelho em bancada técnica'),
              subtitle: const Text('Notifica que o conserto já foi iniciado'),
              onTap: () {
                Navigator.pop(ctx);
                _enviarMensagemRapida('Olá! Seu aparelho já está na bancada técnica em processo de reparo.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined, color: Colors.orange),
              title: const Text('Aguardando peça de reposição'),
              subtitle: const Text('Notifica que um componente foi solicitado'),
              onTap: () {
                Navigator.pop(ctx);
                _enviarMensagemRapida('Olá! Estamos aguardando a chegada de uma peça de reposição para continuar.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Color(0xFF16A34A)),
              title: const Text('Reparo em fase final de testes'),
              subtitle: const Text('Notifica que os testes finais estão em curso'),
              onTap: () {
                Navigator.pop(ctx);
                _enviarMensagemRapida('Olá! O reparo foi concluído e seu aparelho está passando pelos testes finais!');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarMensagemRapida(String mensagem) async {
    try {
      await _supabase.from('mensagens').insert({
        'fk_solicitacao': widget.idSolicitacao,
        'mensagem': mensagem,
        'criado_em': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notificação enviada ao cliente com sucesso!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (_) {
      // Se a tabela mensagens for diferente, abre o chat direto
      _abrirChat();
    }
  }

  bool get _requisitosAtendidos {
    final temDiagnostico = _diagnostico != null && _diagnostico!.trim().isNotEmpty;
    final temFotosSuficientes = _imagensEmAndamento.length >= 3;
    return temDiagnostico && temFotosSuficientes;
  }

  Future<void> _concluirServico() async {
    if (!_requisitosAtendidos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para concluir, defina o diagnóstico e anexe no mínimo 3 fotos.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      // Salva duração final e atualiza etapa
      await _supabase.from('solicitacoes').update({
        'duracao_servico': _segundosAndamento,
        'andamento_pausado': true,
        'etapa_solicitacao': 4, // Etapa entrega / pronto
      }).eq('id_solicitacao', widget.idSolicitacao);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Serviço Concluído na Bancada!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textoEscuro,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'O diagnóstico e as evidências foram registradas com sucesso. O aparelho está pronto para devolução/entrega.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _textoMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const MeusServicosSolicitadosPage(),
                      ),
                      (route) => route.isFirst,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _azul,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Voltar para Serviços',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha ao concluir serviço: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      appBar: _buildAppBar(),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: _azul),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSecaoModalidadeEEtapa(),
                  const SizedBox(height: 16),
                  _buildSecaoCliente(),
                  const SizedBox(height: 16),
                  _buildSecaoBancadaTecnica(),
                  const SizedBox(height: 16),
                  _buildSecaoEvidencias(),
                  const SizedBox(height: 20),
                  _buildBotoesAcao(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _textoEscuro),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const MeusServicosSolicitadosPage(),
              ),
            );
          }
        },
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444), // Ponto vermelho
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Serviço Em Andamento',
                style: TextStyle(
                  color: _textoEscuro,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Text(
            widget.codigoPedido,
            style: const TextStyle(
              color: _textoMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: GestureDetector(
            onTap: _abrirPerfilProfissional,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: _azul,
              backgroundImage: widget.fotoPerfilProfissional != null &&
                      widget.fotoPerfilProfissional!.isNotEmpty
                  ? NetworkImage(widget.fotoPerfilProfissional!)
                  : null,
              child: widget.fotoPerfilProfissional == null ||
                      widget.fotoPerfilProfissional!.isEmpty
                  ? (widget.nomeProfissional != null &&
                          widget.nomeProfissional!.isNotEmpty
                      ? Text(
                          obterIniciais(widget.nomeProfissional!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.white, size: 20))
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoModalidadeEEtapa() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cinzaBorda),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: _azul, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'MODALIDADE ${widget.modalidade.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F3B68),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _azul,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Etapa 3 de 5',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Stepper de 5 etapas
          _buildStepper(),
          const SizedBox(height: 18),
          // Caixa informativa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _cinzaCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF475569), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Aparelho alocado na bancada técnica do especialista.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      children: [
        _buildStepItem(
          label: 'Aceito',
          concluido: true,
          ativo: false,
          icone: Icons.check,
        ),
        _buildStepLine(ativo: true),
        _buildStepItem(
          label: 'Busca',
          concluido: true,
          ativo: false,
          icone: Icons.check,
        ),
        _buildStepLine(ativo: true),
        _buildStepItem(
          label: 'Processo',
          concluido: false,
          ativo: true,
          icone: null,
        ),
        _buildStepLine(ativo: false),
        _buildStepItem(
          label: 'Entrega',
          concluido: false,
          ativo: false,
          icone: Icons.local_shipping_outlined,
        ),
        _buildStepLine(ativo: false),
        _buildStepItem(
          label: 'Concluído',
          concluido: false,
          ativo: false,
          icone: Icons.check,
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String label,
    required bool concluido,
    required bool ativo,
    IconData? icone,
  }) {
    Widget circle;
    if (concluido) {
      circle = Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: _azul,
          shape: BoxShape.circle,
        ),
        child: Icon(icone ?? Icons.check, color: Colors.white, size: 16),
      );
    } else if (ativo) {
      circle = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _azul, width: 2),
          boxShadow: [
            BoxShadow(
              color: _azul.withValues(alpha: 0.35),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: _azul,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else {
      circle = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        ),
        child: icone != null
            ? Icon(icone, color: const Color(0xFF94A3B8), size: 15)
            : null,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        circle,
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: ativo || concluido ? FontWeight.w700 : FontWeight.w500,
            color: ativo
                ? _azul
                : (concluido ? _textoEscuro : const Color(0xFF94A3B8)),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool ativo}) {
    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.only(bottom: 20),
        color: ativo ? _azul : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildSecaoCliente() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cinzaBorda),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFE2E8F0),
                    backgroundImage: widget.fotoCliente != null &&
                            widget.fotoCliente!.isNotEmpty
                        ? NetworkImage(widget.fotoCliente!)
                        : null,
                    child: widget.fotoCliente == null || widget.fotoCliente!.isEmpty
                        ? Text(
                            obterIniciais(widget.nomeCliente),
                            style: const TextStyle(
                              color: _textoEscuro,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: _azul,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nomeCliente,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textoEscuro,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.nomeServico,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _textoMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text(
                    'PRAZO\nACORDADO',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Sexta (18h)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F3B68),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _abrirChat,
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: _azul, size: 18),
              label: const Text(
                'Conversar no Chat',
                style: TextStyle(
                  color: _azul,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFBAE6FD), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoBancadaTecnica() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cinzaBorda),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _azul,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '● Bancada Técnica',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'OS: #OS-${widget.idSolicitacao}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _textoMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.nomeServico,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _textoEscuro,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.detalhes?.isNotEmpty == true
                ? '"${widget.detalhes}"'
                : '"Sem observações adicionais informadas pelo cliente."',
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: _textoMuted,
            ),
          ),
          const SizedBox(height: 14),
          // Container do Diagnóstico
          _buildContainerDiagnostico(),
          // Fotos da Coleta (se houver)
          if (_imagensRecebimento.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Fotos de Entrada / Coleta:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textoMuted,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imagensRecebimento.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final url = _imagensRecebimento[idx];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: url.startsWith('http')
                        ? Image.network(
                            url,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 64,
                              height: 64,
                              color: _cinzaCard,
                              child: const Icon(Icons.broken_image,
                                  color: Color(0xFF94A3B8), size: 24),
                            ),
                          )
                        : Image.file(
                            File(url),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 64,
                              height: 64,
                              color: _cinzaCard,
                              child: const Icon(Icons.broken_image,
                                  color: Color(0xFF94A3B8), size: 24),
                            ),
                          ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Dois cards: Valor do Serviço e Tempo de Serviço
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cinzaCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Valor do Serviço',
                        style: TextStyle(
                          fontSize: 11,
                          color: _textoMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'R\$ ${(widget.valorFinal ?? 180.0).toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _textoEscuro,
                              ),
                            ),
                          ),
                          const Icon(Icons.payments_outlined,
                              color: Color(0xFF64748B), size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _cinzaCard,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tempo de Serviço',
                        style: TextStyle(
                          fontSize: 11,
                          color: _textoMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatarTempo(_segundosAndamento),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _azul,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const Icon(Icons.timer_outlined, color: _azul, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContainerDiagnostico() {
    final temDiagnostico = _diagnostico != null && _diagnostico!.trim().isNotEmpty;

    if (!temDiagnostico) {
      // Container Azul Primário chamando para definir diagnóstico
      return InkWell(
        onTap: _abrirModalDiagnostico,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _azul,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _azul.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Definir Diagnóstico Técnico',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Clique para registrar o defeito constatado.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      );
    }

    // Diagnóstico Confirmado (estilo igual screenshot)
    return InkWell(
      onTap: _abrirModalDiagnostico,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBAE6FD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.manage_search_rounded, color: _azul, size: 20),
                SizedBox(width: 6),
                Text(
                  'Diagnóstico Confirmado',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _azul,
                  ),
                ),
                Spacer(),
                Icon(Icons.edit_outlined, color: _azul, size: 16),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _diagnostico!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF334155),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecaoEvidencias() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cinzaBorda),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Evidências e Fotos do Conserto',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: _textoEscuro,
                  ),
                ),
              ),
              Text(
                '${_imagensEmAndamento.length} fotos anexadas',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _azul,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Anexe fotos e comprovantes do conserto para liberação da garantia e envio automático de atualização ao cliente ${widget.nomeCliente}. (Mínimo de 3 fotos)',
            style: const TextStyle(
              fontSize: 12.5,
              color: _textoMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          // Grade de fotos já enviadas
          if (_imagensEmAndamento.isNotEmpty) ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: _imagensEmAndamento.length,
              itemBuilder: (context, idx) {
                final url = _imagensEmAndamento[idx];
                final legenda = idx == 0
                    ? '1. Placa & Teste de Bancada'
                    : idx == 1
                        ? '2. Peça Nova (Substituída)'
                        : '${idx + 1}. Evidência Técnica';

                return Container(
                  decoration: BoxDecoration(
                    color: _cinzaCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cinzaBorda),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(13),
                              ),
                              child: url.startsWith('http')
                                  ? Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: _cinzaCard,
                                        child: const Icon(Icons.broken_image,
                                            color: Color(0xFF94A3B8)),
                                      ),
                                    )
                                  : Image.file(
                                      File(url),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: _cinzaCard,
                                        child: const Icon(Icons.broken_image,
                                            color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => _removerFoto(idx),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Text(
                          legenda,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _textoEscuro,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          // Botões de ação para adicionar fotos (estilo igual screenshot)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _enviandoFoto
                      ? null
                      : () => _adicionarFotoEvidencia(source: ImageSource.camera),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: _cinzaCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _cinzaBorda),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: _azul,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '+ Foto Teste Final',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _textoEscuro,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Aparelho ligado aquecendo',
                          style: TextStyle(
                            fontSize: 10,
                            color: _textoMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: _enviandoFoto
                      ? null
                      : () => _adicionarFotoEvidencia(source: ImageSource.gallery),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: _cinzaCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _cinzaBorda),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: _azul,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.attach_file_rounded,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Laudo / NF Peças',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _textoEscuro,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'PDF ou Imagem fiscal',
                          style: TextStyle(
                            fontSize: 10,
                            color: _textoMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_enviandoFoto) ...[
            const SizedBox(height: 12),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _azul),
                  ),
                  SizedBox(width: 10),
                  Text('Enviando foto...', style: TextStyle(fontSize: 12, color: _textoMuted)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBotoesAcao() {
    final podeConcluir = _requisitosAtendidos;

    return Column(
      children: [
        // Botão principal: Concluir Serviço
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: podeConcluir && !_salvando ? _concluirServico : null,
            style: FilledButton.styleFrom(
              backgroundColor: _azul,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: podeConcluir ? 3 : 0,
            ),
            child: _salvando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Concluir Serviço →',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (!podeConcluir) ...[
          const SizedBox(height: 6),
          Text(
            _diagnostico == null || _diagnostico!.isEmpty
                ? 'Defina o diagnóstico para habilitar a conclusão.'
                : 'Anexe pelo menos 3 fotos (${_imagensEmAndamento.length}/3) para concluir.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Botões secundários: Pausar e Notificar Cliente
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _alternarPausa,
                  icon: Icon(
                    _pausado ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: const Color(0xFF475569),
                    size: 20,
                  ),
                  label: Text(
                    _pausado ? 'Retomar Serviço' : 'Pausar / Falta Peça',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE2E8F0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _notificarCliente,
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Color(0xFF0284C7),
                    size: 20,
                  ),
                  label: const Text(
                    'Notificar Cliente',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE0F2FE),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

