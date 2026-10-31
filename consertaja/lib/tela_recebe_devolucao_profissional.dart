import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'gestao_equipe.dart';
import 'solicitacao_em_andamento.dart';
import 'tela_chat_profissional.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/iniciais.dart';

class TelaRecebeDevolucaoProfissionalPage extends StatefulWidget {
  final int idSolicitacao;
  final String codigoPedido;
  final String nomeCliente;
  final String? fotoCliente;
  final String nomeServico;
  final String modalidade;
  final String enderecoPrincipal;
  final String enderecoComplementar;
  final bool isEmpresa;
  final int? idGrupoEmpresa;
  final String? fotoPerfilProfissional;
  final String? nomeProfissional;

  const TelaRecebeDevolucaoProfissionalPage({
    super.key,
    required this.idSolicitacao,
    required this.codigoPedido,
    required this.nomeCliente,
    this.fotoCliente,
    required this.nomeServico,
    this.modalidade = 'Leva e Traz',
    required this.enderecoPrincipal,
    required this.enderecoComplementar,
    this.isEmpresa = false,
    this.idGrupoEmpresa,
    this.fotoPerfilProfissional,
    this.nomeProfissional,
  });

  @override
  State<TelaRecebeDevolucaoProfissionalPage> createState() =>
      _TelaRecebeDevolucaoProfissionalPageState();
}

class _TelaRecebeDevolucaoProfissionalPageState
    extends State<TelaRecebeDevolucaoProfissionalPage>
    with TickerProviderStateMixin {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _fundo = Color(0xFFF8FAFC);
  static const Color _textoEscuro = Color(0xFF0F172A);
  static const Color _textoMuted = Color(0xFF64748B);
  static const Color _cinzaBorda = Color(0xFFE2E8F0);
  static const Color _cinzaCard = Color(0xFFF1F5F9);

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _sonarController;
  late Animation<double> _sonarAnimation;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  bool _carregando = true;
  bool _enviando = false;

  // Dados carregados da solicitação
  String _descricaoCliente = '';
  String? _anexoClienteUrl;
  String _legendaAnexo = 'Foto anexada pela cliente';
  int _quantidadeAnexos = 0;
  String _valorFinalFormatado = 'R\$ 180,00';
  double? _valorFinalNumerico;
  final String _prazoDevolucao = '23 de setembro';
  String _codigoCorreto = '';

  // Controle de acoplamento do código (se está na seção original ou fixado na barra inferior)
  bool _codigoNoLugarOriginal = false;

  // Fotos de registro
  final List<XFile?> _fotos = [null, null];
  final List<String> _titulosSlots = [
    '1. Painel Frontal',
    '2. Traseira / Série',
  ];

  // Observações
  final TextEditingController _obsController = TextEditingController();

  // Código de 4 dígitos
  final List<TextEditingController> _codigoControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _codigoFocusNodes = List.generate(
    4,
    (_) => FocusNode(),
  );
  bool? _codigoValido; // null = neutro, true = correto, false = incorreto

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_aoRolar);

    _sonarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _sonarAnimation = CurvedAnimation(
      parent: _sonarController,
      curve: Curves.easeOutQuad,
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _carregarDados();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_aoRolar);
    _sonarController.dispose();
    _shakeController.dispose();
    _scrollController.dispose();
    _obsController.dispose();
    for (final c in _codigoControllers) {
      c.dispose();
    }
    for (final f in _codigoFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _aoRolar() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) {
      if (!_codigoNoLugarOriginal) {
        setState(() => _codigoNoLugarOriginal = true);
      }
      return;
    }
    final offset = _scrollController.offset;
    // Quando o usuário rolar até perto do fim da tela (onde está a seção do código)
    final noFim = (max - offset) <= 220;
    if (noFim != _codigoNoLugarOriginal) {
      setState(() {
        _codigoNoLugarOriginal = noFim;
      });
    }
  }

  Future<void> _carregarDados() async {
    try {
      final row = await _supabase
          .from('solicitacoes')
          .select(
            'id_solicitacao, valor_final, detalhes, data_agendada, tipo_execucao, '
            'codigo_rec_dev, fk_usuario, fk_servico_prof, fk_servico_temp',
          )
          .eq('id_solicitacao', widget.idSolicitacao)
          .maybeSingle();

      if (row != null) {
        _codigoCorreto = row['codigo_rec_dev']?.toString().trim() ?? '';
        final valor = row['valor_final'];
        if (valor != null) {
          final numVal = (valor as num).toDouble();
          _valorFinalNumerico = numVal;
          _valorFinalFormatado =
              'R\$ ${numVal.toStringAsFixed(2).replaceAll('.', ',')}';
        }
        final det = row['detalhes']?.toString().trim();
        if (det != null && det.isNotEmpty) {
          _descricaoCliente = det;
        }

        // Buscar anexo do cliente se houver na tabela solicitacoes_anexos ou anexos_solicitacao
        try {
          final anexos = await _supabase
              .from('solicitacoes_anexos')
              .select('anexo_url, nome_arquivo')
              .eq('fk_solicitacao', widget.idSolicitacao)
              .order('ordem', ascending: true);
          if (anexos.isNotEmpty) {
            _quantidadeAnexos = anexos.length;
            final primeiro = anexos.first;
            final url = primeiro['anexo_url']?.toString().trim();
            if (url != null && url.isNotEmpty) {
              _anexoClienteUrl = url;
            }
            final nomeArq = primeiro['nome_arquivo']?.toString().trim();
            if (nomeArq != null && nomeArq.isNotEmpty) {
              _legendaAnexo = nomeArq;
            } else {
              _legendaAnexo = 'Foto anexada pela cliente (${widget.nomeServico})';
            }
          } else {
            _quantidadeAnexos = 0;
            _anexoClienteUrl = null;
          }
        } catch (_) {
          try {
            final anexos = await _supabase
                .from('anexos_solicitacao')
                .select('arquivo_url, tipo_arquivo')
                .eq('fk_solicitacao', widget.idSolicitacao)
                .limit(5);
            if (anexos.isNotEmpty) {
              _quantidadeAnexos = anexos.length;
              final primeiro = anexos.first;
              _anexoClienteUrl = primeiro['arquivo_url']?.toString();
              _legendaAnexo = 'Foto anexada pela cliente (${widget.nomeServico})';
            } else {
              _quantidadeAnexos = 0;
              _anexoClienteUrl = null;
            }
          } catch (_) {
            _quantidadeAnexos = 0;
            _anexoClienteUrl = null;
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados de recebimento: $e');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
        WidgetsBinding.instance.addPostFrameCallback((_) => _aoRolar());
      }
    }
  }

  void _aoMudarDigito(int index, String value) {
    setState(() {
      _codigoValido = null;
    });

    if (value.isNotEmpty) {
      if (index < 3) {
        _codigoFocusNodes[index + 1].requestFocus();
      } else {
        _codigoFocusNodes[index].unfocus();
        _verificarCodigo();
      }
    } else {
      if (index > 0) {
        _codigoFocusNodes[index - 1].requestFocus();
      }
    }
  }

  void _verificarCodigo() {
    final digitado = _codigoControllers.map((c) => c.text.trim()).join();
    if (digitado.length == 4) {
      final correto = _codigoCorreto.isNotEmpty && digitado == _codigoCorreto;
      setState(() {
        _codigoValido = correto;
      });

      if (!correto) {
        _shakeController.forward(from: 0.0);
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  Future<void> _selecionarFoto(int index) async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tirar ou escolher foto',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textoEscuro,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: _azul),
                title: const Text('Câmera (Tirar foto agora)'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: _azul),
                title: const Text('Galeria de Fotos'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (origem == null) return;

    try {
      final picked = await _picker.pickImage(
        source: origem,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _fotos[index] = picked;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível capturar a imagem: $e')),
      );
    }
  }

  void _adicionarSlotOpcional() {
    setState(() {
      _fotos.add(null);
      _titulosSlots.add('${_fotos.length}. Foto Opcional');
    });
  }

  void _removerFoto(int index) {
    setState(() {
      if (index >= 2) {
        _fotos.removeAt(index);
        _titulosSlots.removeAt(index);
      } else {
        _fotos[index] = null;
      }
    });
  }

  bool get _podeConfirmar {
    final fotosObrigatoriasOk =
        _fotos.length >= 2 && _fotos[0] != null && _fotos[1] != null;
    return fotosObrigatoriasOk && (_codigoValido == true);
  }

  Future<void> _confirmarColeta() async {
    if (!_podeConfirmar || _enviando) return;

    setState(() => _enviando = true);

    try {
      final List<String> urlsImagens = [];

      // 1. Upload de cada foto no bucket 'Imagens Recebimento'
      for (int i = 0; i < _fotos.length; i++) {
        final xfile = _fotos[i];
        if (xfile == null) continue;

        final bytes = await xfile.readAsBytes();
        final ext = xfile.path.split('.').last;
        final nomeArquivo =
            'recebimento_${widget.idSolicitacao}_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

        try {
          await _supabase.storage.from('Imagens Recebimento').uploadBinary(
            nomeArquivo,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
          final url = _supabase.storage
              .from('Imagens Recebimento')
              .getPublicUrl(nomeArquivo);
          urlsImagens.add(url);
        } catch (eStorage) {
          debugPrint('Upload falhou no bucket principal: $eStorage');
          // Fallback para bucket 'imagens_recebimento'
          try {
            await _supabase.storage.from('imagens_recebimento').uploadBinary(
              nomeArquivo,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
            final url = _supabase.storage
                .from('imagens_recebimento')
                .getPublicUrl(nomeArquivo);
            urlsImagens.add(url);
          } catch (_) {
            urlsImagens.add(xfile.path);
          }
        }
      }

      // 2. Salvar na tabela solicitacoes
      final obs = _obsController.text.trim();
      final agoraIso = DateTime.now().toIso8601String();
      try {
        await _supabase.from('solicitacoes').update({
          'imagens_recebimento': urlsImagens,
          'obs_do_prof': obs,
          'fk_status': 4, // Em Andamento
          'etapa_solicitacao': 3,
          'data_inicio_andamento': agoraIso,
          'andamento_pausado': false,
        }).eq('id_solicitacao', widget.idSolicitacao);
      } catch (eUpdate) {
        debugPrint('Erro ao atualizar solicitacoes com novas colunas: $eUpdate');
        // Tenta sem colunas opcionais caso ainda não tenham sido migradas no Supabase
        try {
          await _supabase.from('solicitacoes').update({
            'imagens_recebimento': urlsImagens,
            'obs_do_prof': obs,
            'fk_status': 4,
            'etapa_solicitacao': 3,
          }).eq('id_solicitacao', widget.idSolicitacao);
        } catch (_) {
          await _supabase.from('solicitacoes').update({
            'obs_do_prof': obs,
            'fk_status': 4,
            'etapa_solicitacao': 3,
          }).eq('id_solicitacao', widget.idSolicitacao);
        }
      }

      if (!mounted) return;

      // 3. Exibir confirmação e levar para bancada técnica
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Coleta Confirmada!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textoEscuro,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'O aparelho foi recebido com sucesso e está sob sua custódia técnica.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _textoMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => SolicitacaoEmAndamentoPage(
                          idSolicitacao: widget.idSolicitacao,
                          codigoPedido: widget.codigoPedido,
                          nomeCliente: widget.nomeCliente,
                          fotoCliente: widget.fotoCliente,
                          nomeServico: widget.nomeServico,
                          modalidade: widget.modalidade,
                          detalhes: _descricaoCliente,
                          valorFinal: _valorFinalNumerico,
                          isEmpresa: widget.isEmpresa,
                          idGrupoEmpresa: widget.idGrupoEmpresa,
                          fotoPerfilProfissional: widget.fotoPerfilProfissional,
                          nomeProfissional: widget.nomeProfissional,
                        ),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _azul,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Continuar para a Bancada',
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Falha ao confirmar coleta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _aoClicarPerfil() {
    if (widget.isEmpresa) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const GestaoEquipePage(),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              const TelaMeuPerfilProfissionalPage(isVisitante: false),
        ),
      );
    }
  }

  void _abrirChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaChatProfissional(
          nomeProfissional: widget.nomeCliente,
          fotoProfissional: widget.fotoCliente ?? '',
          oficioPrincipal: widget.nomeServico,
          idSolicitacao: widget.idSolicitacao,
        ),
      ),
    );
  }

  void _abrirSos() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.crisis_alert_rounded, color: Color(0xFFE11D48)),
                  SizedBox(width: 8),
                  Text(
                    'Central de Emergência e SOS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Se estiver em situação de risco, acione as autoridades imediatamente:',
                style: TextStyle(fontSize: 13, color: _textoMuted),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.local_police_outlined,
                    color: Color(0xFFE11D48)),
                title: const Text('Polícia Militar (190)'),
                onTap: () {
                  launchUrl(Uri.parse('tel:190'));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.medical_services_outlined,
                    color: Color(0xFFE11D48)),
                title: const Text('SAMU (192)'),
                onTap: () {
                  launchUrl(Uri.parse('tel:192'));
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      body: SafeArea(
        child: _carregando
            ? const Center(
                child: CircularProgressIndicator(color: _azul),
              )
            : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCardModalidadeEEtapas(),
                          const SizedBox(height: 14),
                          _buildCardInfoCliente(),
                          const SizedBox(height: 14),
                          _buildCardDetalhesServico(),
                          const SizedBox(height: 14),
                          _buildCardRegistroEstado(),
                          const SizedBox(height: 14),
                          _buildCardCodigoLiberacao(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomSheet: _buildBottomConfirmButton(),
    );
  }

  // ==========================================
  // 1. CABEÇALHO
  // ==========================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _cinzaBorda, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, color: _textoEscuro),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Text('🔴', style: TextStyle(fontSize: 10)),
                    SizedBox(width: 4),
                    Text(
                      'Aguardando recebimento',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _textoEscuro,
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.codigoPedido,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textoMuted,
                  ),
                ),
              ],
            ),
          ),
          // Botão SOS
          GestureDetector(
            onTap: _abrirSos,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4E6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emergency_rounded,
                      color: Color(0xFFE11D48), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'sos',
                    style: TextStyle(
                      color: Color(0xFFE11D48),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar do profissional
          GestureDetector(
            onTap: _aoClicarPerfil,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _azul, width: 1.5),
              ),
              child: ClipOval(
                child: widget.fotoPerfilProfissional != null &&
                        widget.fotoPerfilProfissional!.isNotEmpty
                    ? Image.network(
                        widget.fotoPerfilProfissional!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _avatarFallbackProfissional(),
                      )
                    : _avatarFallbackProfissional(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallbackProfissional() {
    final nome = widget.nomeProfissional ?? 'Profissional';
    return Container(
      color: _azul,
      alignment: Alignment.center,
      child: Text(
        obterIniciais(nome),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==========================================
  // 2. MODALIDADE E STEPPER DE ETAPAS
  // ==========================================
  Widget _buildCardModalidadeEEtapas() {
    final etapas = ['Aceito', 'Busca', 'Processo', 'Entrega', 'Concluído'];
    final icones = [
      Icons.check,
      Icons.radio_button_checked,
      Icons.business_center_outlined,
      Icons.local_shipping_outlined,
      Icons.check_circle_outline,
    ];
    const etapaAtual = 1; // Busca (atual)

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // Linha de modalidade e chip
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: _azul,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('●', style: TextStyle(color: _azul, fontSize: 10)),
                        SizedBox(width: 4),
                        Text(
                          'MODALIDADE ATIVA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _azul,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.modalidade,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _textoEscuro,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _azul,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Etapa 2 de 5',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Stepper de etapas
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(etapas.length, (index) {
              final isFirst = index == 0;
              final isLast = index == etapas.length - 1;
              final isDone = index < etapaAtual;
              final isCurrent = index == etapaAtual;
              
              return Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 42,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: isFirst
                                    ? const SizedBox()
                                    : Container(
                                        height: 3,
                                        color: index <= etapaAtual + 1
                                            ? _azul
                                            : const Color(0xFFCBD5E1),
                                      ),
                              ),
                              const SizedBox(width: 30),
                              Expanded(
                                child: isLast
                                    ? const SizedBox()
                                    : Container(
                                        height: 3,
                                        color: index <= etapaAtual
                                            ? _azul
                                            : const Color(0xFFCBD5E1),
                                      ),
                              ),
                            ],
                          ),
                          if (isDone)
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: _azul,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 18,
                                color: Colors.white,
                              ),
                            )
                          else if (isCurrent)
                            _buildSonarStepCircle(icones[index])
                          else
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFCBD5E1),
                              ),
                              child: Icon(
                                icones[index],
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      etapas[index],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isDone || isCurrent
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isDone || isCurrent ? _azul : _textoMuted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSonarStepCircle(IconData icone) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _sonarAnimation,
            builder: (context, _) {
              final val = _sonarAnimation.value;
              final ringSize = 32.0 + (val * 14.0);
              final opacity = ((1.0 - val) * 0.7).clamp(0.0, 1.0);
              return Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _azul.withValues(alpha: opacity),
                    width: 2.0,
                  ),
                  color: _azul.withValues(alpha: opacity * 0.2),
                ),
              );
            },
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _azul, width: 2.2),
            ),
            child: Icon(icone, size: 16, color: _azul),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. CARD INFO DO CLIENTE
  // ==========================================
  Widget _buildCardInfoCliente() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              Stack(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _cinzaBorda, width: 1.5),
                    ),
                    child: ClipOval(
                      child: widget.fotoCliente != null &&
                              widget.fotoCliente!.isNotEmpty
                          ? Image.network(
                              widget.fotoCliente!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  _avatarFallbackCliente(),
                            )
                          : _avatarFallbackCliente(),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: _azul,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 11,
                      ),
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
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: _textoMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Ponto de retirada
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on_outlined, color: _azul, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PONTO DE RETIRADA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: _azul,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.enderecoPrincipal,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _textoEscuro,
                      ),
                    ),
                    if (widget.enderecoComplementar.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.enderecoComplementar,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _textoMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Botão Conversar no Chat
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _abrirChat,
              icon: const Icon(Icons.chat_bubble_outline,
                  color: _azul, size: 18),
              label: const Text(
                'Conversar no Chat',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _azul,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _cinzaBorda, width: 1.5),
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

  Widget _avatarFallbackCliente() {
    return Container(
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: Text(
        obterIniciais(widget.nomeCliente),
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ==========================================
  // 4. CARD DETALHES DO SERVIÇO
  // ==========================================
  Widget _buildCardDetalhesServico() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              const Icon(Icons.receipt_long_outlined, color: _azul, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Detalhes do serviço',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textoEscuro,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _azul,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Bancada Técnica',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Subcard cinza
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cinzaCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SERVIÇO SELECIONADO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _textoMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (_quantidadeAnexos > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_file,
                                size: 13, color: _textoMuted),
                            const SizedBox(width: 3),
                            Text(
                              '$_quantidadeAnexos anexo${_quantidadeAnexos > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _textoMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.nomeServico,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textoEscuro,
                  ),
                ),
                if (_descricaoCliente.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '"$_descricaoCliente"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
                if (_anexoClienteUrl != null && _anexoClienteUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Foto anexada pelo cliente
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Image.network(
                          _anexoClienteUrl!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _placeholderFotoCliente(),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          color: Colors.black.withValues(alpha: 0.65),
                          child: Row(
                            children: [
                              const Icon(Icons.camera_alt_outlined,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _legendaAnexo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                // Valores
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Valor final',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _textoMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _valorFinalFormatado,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _azul,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Prazo Devolução',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _textoMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 14, color: _textoEscuro),
                            const SizedBox(width: 4),
                            Text(
                              _prazoDevolucao,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _textoEscuro,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderFotoCliente() {
    return Container(
      height: 150,
      width: double.infinity,
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8), size: 36),
          SizedBox(height: 4),
          Text(
            'Foto do aparelho',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 5. REGISTRO DO ESTADO NA COLETA
  // ==========================================
  Widget _buildCardRegistroEstado() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          const Row(
            children: [
              Icon(Icons.camera_alt_outlined, color: _azul, size: 20),
              SizedBox(width: 8),
              Text(
                'Registro do Estado na Coleta',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textoEscuro,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Fotografe o produto na presença do cliente antes de retirá-lo (frente, riscos e placa de série). Este checklist protege você e o cliente durante a custódia técnica.',
            style: TextStyle(
              fontSize: 12.5,
              color: _textoMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          // Slots de imagens
          SizedBox(
            height: 145,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _fotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final foto = _fotos[index];
                final obrigatoria = index < 2;
                final titulo = _titulosSlots[index];

                return _buildSlotFoto(index, foto, obrigatoria, titulo);
              },
            ),
          ),
          const SizedBox(height: 12),
          // Botão Adicionar outra Foto
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: _adicionarSlotOpcional,
              icon: const Icon(Icons.add_circle_outline,
                  color: _textoEscuro, size: 18),
              label: const Text(
                'Adicionar outra Foto (Opcional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textoEscuro,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _cinzaCard,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Observações / Acessórios Recebidos
          const Text(
            'Observações / Acessórios Recebidos',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _textoEscuro,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _cinzaCard,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _obsController,
              maxLines: 3,
              style: const TextStyle(fontSize: 13, color: _textoEscuro),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText:
                    'Ex: Acompanha prato giratório de vidro e anel de suporte. Leve risco de 3cm na lateral esquerda.',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotFoto(
      int index, XFile? foto, bool obrigatoria, String titulo) {
    if (foto != null) {
      return SizedBox(
        width: 140,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(foto.path),
                width: 140,
                height: 145,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              bottom: 6,
              left: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.greenAccent, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => _removerFoto(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Slot vazio (tracejado)
    return GestureDetector(
      onTap: () => _selecionarFoto(index),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF93C5FD),
            width: 1.5,
            style: BorderStyle.solid,
          ),
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
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Foto do\nrecebimento',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _azul,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              obrigatoria
                  ? 'Obrigatória (${index + 1}/2)'
                  : 'Opcional (${index + 1})',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: obrigatoria ? const Color(0xFFE11D48) : _textoMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 6. CÓDIGO DE LIBERAÇÃO DO CLIENTE
  // ==========================================
  Widget _buildCardCodigoLiberacao() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: _azul,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.key_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          const Text(
            'Código de Liberação do Cliente',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textoEscuro,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Solicite à cliente ${widget.nomeCliente} os 4 dígitos exibidos no app dela para autorizar a custódia do aparelho.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: _textoMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          // Se o usuário rolou até o final, os 4 inputs se desgrudam da barra inferior e ficam aqui na seção
          if (_codigoNoLugarOriginal) ...[
            _buildInputsCodigo(compacto: false),
            const SizedBox(height: 14),
          ] else ...[
            _buildPlaceholderCodigoNaSecao(),
            const SizedBox(height: 14),
          ],
          // Coletar assinatura manual centralizado e responsivo
          _buildBotaoAssinaturaManual(),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCodigoNaSecao() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.push_pin_outlined, size: 16, color: _azul),
          const SizedBox(width: 8),
          Text(
            'Código fixado acima do botão de confirmação',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsCodigo({bool compacto = false}) {
    final double tamanho = compacto ? 50 : 58;
    final double fontSize = compacto ? 20 : 24;
    final double margin = compacto ? 4 : 5;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final offset = _codigoValido == false
            ? sin(_shakeController.value * pi * 4) * 8
            : 0.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          return Container(
            width: tamanho,
            height: tamanho,
            margin: EdgeInsets.symmetric(horizontal: margin),
            decoration: BoxDecoration(
              color: _obterCorFundoDigito(index),
              borderRadius: BorderRadius.circular(compacto ? 14 : 16),
              border: Border.all(
                color: _obterCorBordaDigito(index),
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: _codigoControllers[index],
              focusNode: _codigoFocusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: _obterCorTextoDigito(index),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) => _aoMudarDigito(index, val),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBotaoAssinaturaManual() {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Opção de assinatura em tela selecionada.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit_note_rounded, color: _azul, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Coletar assinatura manual em tela se cliente não tiver celular',
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _azul,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _obterCorFundoDigito(int index) {
    if (_codigoValido == true) {
      return const Color(0xFF16A34A); // Verde
    }
    if (_codigoValido == false) {
      return const Color(0xFFDC2626); // Vermelho
    }
    final text = _codigoControllers[index].text.trim();
    if (text.isNotEmpty) {
      return _azul;
    }
    return Colors.white;
  }

  Color _obterCorBordaDigito(int index) {
    if (_codigoValido == true) {
      return const Color(0xFF16A34A);
    }
    if (_codigoValido == false) {
      return const Color(0xFFDC2626);
    }
    return _azul;
  }

  Color _obterCorTextoDigito(int index) {
    if (_codigoValido != null) {
      return Colors.white;
    }
    final text = _codigoControllers[index].text.trim();
    if (text.isNotEmpty) {
      return Colors.white;
    }
    return _textoEscuro;
  }

  // ==========================================
  // 7. BOTÃO INFERIOR FIXO COM CÓDIGO DOCKADO
  // ==========================================
  Widget _buildBottomConfirmButton() {
    final habilitado = _podeConfirmar && !_enviando;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _cinzaBorda, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quando a tela não está no fim da seção, os elementos de código acompanham aqui acima do botão
            if (!_codigoNoLugarOriginal) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: _azul,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.key_rounded,
                              color: Colors.white, size: 12),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Código de Liberação do Cliente',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _textoEscuro,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInputsCodigo(compacto: true),
                  ],
                ),
              ),
              const Divider(height: 1, color: _cinzaBorda),
            ],
            // Botão Confirmar Coleta
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: habilitado ? _confirmarColeta : null,
                  icon: _enviando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.two_wheeler_rounded, size: 22),
                  label: Text(
                    _enviando ? 'Confirmando Coleta...' : 'Confirmar Coleta',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _azul,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

