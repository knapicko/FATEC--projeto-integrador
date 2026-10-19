import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/servico_profissional.dart';
import '../services/servicos_profissional_service.dart';
import '../utils/iniciais.dart';

/// Bottom Sheet moderno e detalhado para envio de Serviço Personalizado no Chat.
class BottomSheetServicoPersonalizado extends StatefulWidget {
  final String nomeCliente;
  final String? fotoCliente;
  final bool estaOnline;
  final DateTime? ultimaConexao;
  final int? idProfissional;
  final int? idGrupoEmpresa;
  final bool baseadoEmServicoInicial;
  final int? idServicoProfInicial;
  final int? idSolicitacaoOrigem;
  final Future<void> Function({
    required String titulo,
    String? descricao,
    required double valor,
    int? fkOficio,
    String? nomeOficio,
    required String tipoExecucao,
    XFile? imagemLocal,
    String? imagemUrlExistente,
    int? idSolicitacaoOrigem,
  }) onEnviar;

  const BottomSheetServicoPersonalizado({
    super.key,
    required this.nomeCliente,
    this.fotoCliente,
    required this.estaOnline,
    this.ultimaConexao,
    this.idProfissional,
    this.idGrupoEmpresa,
    this.baseadoEmServicoInicial = false,
    this.idServicoProfInicial,
    this.idSolicitacaoOrigem,
    required this.onEnviar,
  });

  /// Abre a bottom sheet com efeito de desfoque (blur) no fundo.
  static Future<void> abrir({
    required BuildContext context,
    required String nomeCliente,
    String? fotoCliente,
    required bool estaOnline,
    DateTime? ultimaConexao,
    int? idProfissional,
    int? idGrupoEmpresa,
    bool baseadoEmServicoInicial = false,
    int? idServicoProfInicial,
    int? idSolicitacaoOrigem,
    required Future<void> Function({
      required String titulo,
      String? descricao,
      required double valor,
      int? fkOficio,
      String? nomeOficio,
      required String tipoExecucao,
      XFile? imagemLocal,
      String? imagemUrlExistente,
      int? idSolicitacaoOrigem,
    }) onEnviar,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: BottomSheetServicoPersonalizado(
            nomeCliente: nomeCliente,
            fotoCliente: fotoCliente,
            estaOnline: estaOnline,
            ultimaConexao: ultimaConexao,
            idProfissional: idProfissional,
            idGrupoEmpresa: idGrupoEmpresa,
            baseadoEmServicoInicial: baseadoEmServicoInicial,
            idServicoProfInicial: idServicoProfInicial,
            idSolicitacaoOrigem: idSolicitacaoOrigem,
            onEnviar: onEnviar,
          ),
        );
      },
    );
  }

  @override
  State<BottomSheetServicoPersonalizado> createState() =>
      _BottomSheetServicoPersonalizadoState();
}

class _BottomSheetServicoPersonalizadoState
    extends State<BottomSheetServicoPersonalizado> {
  static const Color _primaryBlue = Color(0xFF0FB3FF);
  static const Color _titleDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _borderLight = Color(0xFFE2E8F0);
  static const Color _bgCard = Color(0xFFFFFFFF);

  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController(text: '150,00');

  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  XFile? _imagemSelecionada;
  String? _imagemUrlExistente;
  List<({int id, String funcao, String cor})> _oficios = [];
  int? _oficioSelecionadoId;

  Set<String> _metodosPermitidos = {};
  String _tipoAtendimentoSelecionado = 'Leva e Traz';

  bool _carregandoInicial = true;
  bool _enviando = false;
  int _caracteresDescricao = 0;

  bool _baseadoEmServicoExistente = false;
  ServicoProfissional? _servicoBaseSelecionado;
  List<ServicoProfissional> _servicosDisponiveis = [];
  int? _idSolicitacaoOrigem;

  static const List<String> _todosMetodos = [
    'Leva e Traz',
    'Retirada no Local',
    'Receba em Casa',
    'Atendimento em Domicílio',
  ];

  @override
  void initState() {
    super.initState();
    _baseadoEmServicoExistente = widget.baseadoEmServicoInicial;
    _idSolicitacaoOrigem = widget.idSolicitacaoOrigem;
    _descricaoController.addListener(() {
      if (mounted) {
        setState(() {
          _caracteresDescricao = _descricaoController.text.length;
        });
      }
    });
    _carregarDados();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  void _selecionarServicoBase(
    ServicoProfissional s, {
    bool atualizarEstado = true,
  }) {
    _servicoBaseSelecionado = s;
    _nomeController.text = s.titulo;
    _descricaoController.text = s.descricao;
    _valorController.text =
        NumberFormat('#,##0.00', 'pt_BR').format(s.valor);
    _oficioSelecionadoId = s.fkOficio;
    _imagemUrlExistente = s.imagemUrl;
    _imagemSelecionada = null;

    if (s.tipoExecucao.isNotEmpty && _metodosPermitidos.isNotEmpty) {
      if (_metodoEstaPermitido(s.tipoExecucao, _metodosPermitidos)) {
        _tipoAtendimentoSelecionado = s.tipoExecucao;
      }
    }

    if (atualizarEstado && mounted) {
      setState(() {});
    }
  }

  Future<void> _carregarDados() async {
    setState(() => _carregandoInicial = true);
    try {
      // 1. Carrega Ofícios do perfil profissional (ou empresa)
      List<({int id, String funcao, String cor})> listaOficios = [];
      if (widget.idGrupoEmpresa != null) {
        listaOficios = await ServicosProfissionalService.buscarFuncoesDaEmpresa(
          widget.idGrupoEmpresa!,
        );
      } else {
        listaOficios =
            await ServicosProfissionalService.buscarFuncoesDoProfissional();
      }

      // 2. Carrega preferências de entrega salvas em metodo_entrega_profissional.dart
      Set<String> metodos = {};
      try {
        if (widget.idGrupoEmpresa != null) {
          final g = await _supabase
              .from('grupo_empresa')
              .select('metodo_entrega_empresa')
              .eq('id_grupo_empresa', widget.idGrupoEmpresa!)
              .maybeSingle();
          final raw = g?['metodo_entrega_empresa']?.toString() ?? '';
          metodos = _parseMetodos(raw);
        } else {
          final idProf = widget.idProfissional ??
              await ServicosProfissionalService.buscarIdProfissional();
          if (idProf != null) {
            final p = await _supabase
                .from('dados_profissionais')
                .select('metodo_entrega')
                .eq('id_profissional', idProf)
                .maybeSingle();
            final raw = p?['metodo_entrega']?.toString() ?? '';
            metodos = _parseMetodos(raw);
          }
        }
      } catch (e) {
        debugPrint('Erro ao buscar métodos de entrega: $e');
      }

      if (metodos.isEmpty) {
        metodos = {'Leva e Traz'};
      }

      // Normaliza seleção inicial para um método permitido
      String selecionado = 'Leva e Traz';
      for (final m in _todosMetodos) {
        if (_metodoEstaPermitido(m, metodos)) {
          selecionado = m;
          break;
        }
      }

      // 3. Carrega Serviços cadastrados do profissional/empresa
      List<ServicoProfissional> listaServicos = [];
      try {
        dynamic query = _supabase
            .from('servicos_profissional')
            .select('*, oficios(funcao, cod_cor)')
            .eq('ativo', true);

        if (widget.idGrupoEmpresa != null) {
          query = query.eq('fk_grupo_empresa', widget.idGrupoEmpresa!);
        } else {
          final idProf = widget.idProfissional ??
              await ServicosProfissionalService.buscarIdProfissional();
          if (idProf != null) {
            query = query.eq('fk_profissional', idProf);
          }
        }
        final rows = await query.order('data_criacao', ascending: false);
        listaServicos = (rows as List)
            .map<ServicoProfissional>(
              (e) => ServicoProfissional.fromMap(e as Map<String, dynamic>),
            )
            .toList();
      } catch (e) {
        debugPrint('Erro ao buscar serviços cadastrados: $e');
      }

      // Se solicitado iniciar baseado em serviço existente
      ServicoProfissional? servicoInicial;
      if (widget.baseadoEmServicoInicial || widget.idServicoProfInicial != null) {
        _baseadoEmServicoExistente = true;
        if (widget.idServicoProfInicial != null) {
          final match = listaServicos
              .where((s) => s.id == widget.idServicoProfInicial)
              .toList();
          if (match.isNotEmpty) {
            servicoInicial = match.first;
          } else {
            try {
              final row = await _supabase
                  .from('servicos_profissional')
                  .select('*, oficios(funcao, cod_cor)')
                  .eq('id_servico_prof', widget.idServicoProfInicial!)
                  .maybeSingle();
              if (row != null) {
                servicoInicial = ServicoProfissional.fromMap(row);
                listaServicos.insert(0, servicoInicial);
              }
            } catch (_) {}
          }
        } else if (listaServicos.isNotEmpty) {
          servicoInicial = listaServicos.first;
        }
      }

      if (mounted) {
        setState(() {
          _oficios = listaOficios;
          if (listaOficios.isNotEmpty) {
            _oficioSelecionadoId = listaOficios.first.id;
          }
          _metodosPermitidos = metodos;
          _tipoAtendimentoSelecionado = selecionado;
          _servicosDisponiveis = listaServicos;
          _carregandoInicial = false;
        });

        if (servicoInicial != null) {
          _selecionarServicoBase(servicoInicial, atualizarEstado: true);
        }
      }
    } catch (e) {
      debugPrint('Erro ao inicializar dados da proposta: $e');
      if (mounted) setState(() => _carregandoInicial = false);
    }
  }

  Set<String> _parseMetodos(String raw) {
    if (raw.trim().isEmpty) return <String>{};
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  bool _metodoEstaPermitido(String opcao, Set<String> permitidos) {
    if (permitidos.contains(opcao)) return true;
    // Variação textual: 'Retirada no Local' vs 'Retirado no Local'
    if (opcao.toLowerCase().contains('retirad') &&
        permitidos.any((p) => p.toLowerCase().contains('retirad'))) {
      return true;
    }
    return false;
  }

  String _formatarStatusOnline() {
    if (widget.estaOnline) return 'Online';
    if (widget.ultimaConexao == null) return 'Última vez há pouco';
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final data = DateTime(
      widget.ultimaConexao!.year,
      widget.ultimaConexao!.month,
      widget.ultimaConexao!.day,
    );
    final hora = DateFormat('HH:mm').format(widget.ultimaConexao!);
    if (hoje == data) {
      return 'Última vez online hoje às $hora';
    } else if (hoje.subtract(const Duration(days: 1)) == data) {
      return 'Última vez online ontem às $hora';
    } else {
      final dia = DateFormat('dd/MM').format(widget.ultimaConexao!);
      return 'Última vez online em $dia às $hora';
    }
  }

  double _obterValorNumerico() {
    final texto = _valorController.text
        .replaceAll('R\$', '')
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(texto) ?? 0.0;
  }

  Future<void> _escolherImagem() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (img != null && mounted) {
        setState(() => _imagemSelecionada = img);
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
    }
  }

  /// Abre seletor com os serviços já cadastrados do profissional para pré-preenchimento
  Future<void> _abrirSeletorSubservicoPrevio() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<ServicoProfissional>>(
          future: ServicosProfissionalService.buscarServicos(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: _primaryBlue)),
              );
            }
            final servicos = snapshot.data ?? [];
            if (servicos.isEmpty) {
              return Container(
                height: 220,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, size: 40, color: _textMuted),
                    const SizedBox(height: 12),
                    const Text(
                      'Nenhum serviço prévio encontrado',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _titleDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Cadastre serviços no seu perfil para selecioná-los rapidamente aqui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: _textMuted),
                    ),
                  ],
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Selecionar Serviço Prévio',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _titleDark,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: _textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: servicos.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final s = servicos[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          title: Text(
                            s.titulo,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: _titleDark,
                            ),
                          ),
                          subtitle: Text(
                            s.descricao.isNotEmpty
                                ? s.descricao
                                : 'Sem descrição',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: _textMuted),
                          ),
                          trailing: Text(
                            'R\$ ${s.valor.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: _primaryBlue,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _nomeController.text = s.titulo;
                              if (s.descricao.isNotEmpty) {
                                _descricaoController.text = s.descricao;
                              }
                              _valorController.text =
                                  NumberFormat('#,##0.00', 'pt_BR').format(s.valor);
                              final encontrado =
                                  _oficios.where((o) => o.id == s.fkOficio);
                              if (encontrado.isNotEmpty) {
                                _oficioSelecionadoId = encontrado.first.id;
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submeterProposta() async {
    final titulo = _nomeController.text.trim();
    if (titulo.isEmpty) {
      _mostrarAlerta('Informe o nome do serviço.');
      return;
    }

    final valor = _obterValorNumerico();
    if (valor <= 0) {
      _mostrarAlerta('Informe um valor válido para o serviço.');
      return;
    }

    if (_oficioSelecionadoId == null && _oficios.isNotEmpty) {
      _mostrarAlerta('Selecione a área do serviço (ofício).');
      return;
    }

    setState(() => _enviando = true);
    try {
      String? nomeOficio;
      if (_oficioSelecionadoId != null) {
        final match = _oficios.where((o) => o.id == _oficioSelecionadoId);
        if (match.isNotEmpty) {
          nomeOficio = match.first.funcao;
        }
      }

      await widget.onEnviar(
        titulo: titulo,
        descricao: _descricaoController.text.trim().isNotEmpty
            ? _descricaoController.text.trim()
            : null,
        valor: valor,
        fkOficio: _oficioSelecionadoId,
        nomeOficio: nomeOficio,
        tipoExecucao: _tipoAtendimentoSelecionado,
        imagemLocal: _imagemSelecionada,
        imagemUrlExistente:
            _imagemSelecionada == null ? _imagemUrlExistente : null,
        idSolicitacaoOrigem: _idSolicitacaoOrigem,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _enviando = false);
        _mostrarAlerta('Erro ao enviar proposta: $e');
      }
    }
  }

  void _mostrarAlerta(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final alturaDisponivel = media.size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: alturaDisponivel),
      decoration: const BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Barra Superior com Título, Subtítulo e Botão Fechar (X) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Enviar Serviço Personalizado',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _titleDark,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Crie e envie uma proposta direta para este cliente',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // ── Conteúdo Rolável ──
            Expanded(
              child: _carregandoInicial
                  ? const Center(
                      child: CircularProgressIndicator(color: _primaryBlue),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Seção de Serviço Existente (Switch + Seletor)
                          _buildSecaoBaseadoEmServico(),
                          const SizedBox(height: 18),

                          // 2. Card de Destinatário
                          _buildCardDestinatario(),
                          const SizedBox(height: 18),

                          // 3. Seção de Imagem do Item ou Serviço (Opcional)
                          _buildSecaoImagem(),
                          const SizedBox(height: 18),

                          // 4. Seção de Área do Serviço (Ofício)
                          _buildSecaoAreaServico(),
                          const SizedBox(height: 18),

                          // 5. Seção de Nome do Serviço
                          _buildSecaoNomeServico(),
                          const SizedBox(height: 18),

                          // 6. Seção de Descrição Detalhada (Opcional)
                          _buildSecaoDescricao(),
                          const SizedBox(height: 18),

                          // 7. Seção de Valor do Serviço
                          _buildSecaoValor(),
                          const SizedBox(height: 18),

                          // 8. Seção de Tipo de Atendimento
                          _buildSecaoTipoAtendimento(),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
            ),

            // ── Rodapé Fixo com Total e Botão Enviar no Chat ──
            _buildRodape(),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Sub-widgets das seções
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildCardDestinatario() {
    final statusOnline = _formatarStatusOnline();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight, width: 1.2),
      ),
      child: Row(
        children: [
          // Avatar com indicador de status
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFFE2E8F0),
                  child: widget.fotoCliente != null &&
                          widget.fotoCliente!.trim().isNotEmpty
                      ? Image.network(
                          widget.fotoCliente!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              obterIniciais(widget.nomeCliente),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            obterIniciais(widget.nomeCliente),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: widget.estaOnline
                        ? const Color(0xFF10B981)
                        : const Color(0xFF94A3B8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _titleDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (widget.estaOnline) ...[
                      const Text(
                        '• ',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          statusOnline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Badge "DESTINATÁRIO"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0F2FE)),
            ),
            child: const Text(
              'DESTINATÁRIO',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0284C7),
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecaoBaseadoEmServico() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.content_copy_rounded,
                  color: Color(0xFF0284C7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Baseado em serviço existente?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _titleDark,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Puxar dados de um dos seus serviços',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _baseadoEmServicoExistente,
                activeColor: _primaryBlue,
                onChanged: (val) {
                  setState(() {
                    _baseadoEmServicoExistente = val;
                    if (!val) {
                      _servicoBaseSelecionado = null;
                      _imagemUrlExistente = null;
                      _imagemSelecionada = null;
                      _nomeController.clear();
                      _descricaoController.clear();
                      _valorController.text = '150,00';
                    } else if (_servicosDisponiveis.isNotEmpty &&
                        _servicoBaseSelecionado == null) {
                      _selecionarServicoBase(_servicosDisponiveis.first);
                    }
                  });
                },
              ),
            ],
          ),
          if (_baseadoEmServicoExistente) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            const Text(
              'SELECIONE O SERVIÇO CADASTRADO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: _abrirModalSelecionarServicoBase,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderLight, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.build_circle_outlined,
                      color: _primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _servicoBaseSelecionado?.titulo ??
                            (_servicosDisponiveis.isEmpty
                                ? 'Nenhum serviço cadastrado encontrado'
                                : 'Toque para escolher o serviço base...'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: _servicoBaseSelecionado != null
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _servicoBaseSelecionado != null
                              ? _titleDark
                              : _textMuted,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _abrirModalSelecionarServicoBase() {
    if (_servicosDisponiveis.isEmpty) {
      _mostrarAlerta('Você ainda não possui serviços cadastrados no perfil.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.70,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Escolher Serviço Cadastrado',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _titleDark,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Expanded(
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: _servicosDisponiveis.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final s = _servicosDisponiveis[index];
                    final isSelected = _servicoBaseSelecionado?.id == s.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: s.imagemUrl != null && s.imagemUrl!.isNotEmpty
                            ? Image.network(
                                s.imagemUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 44,
                                  height: 44,
                                  color: const Color(0xFFF1F5F9),
                                  child: const Icon(
                                    Icons.build_rounded,
                                    color: _primaryBlue,
                                    size: 20,
                                  ),
                                ),
                              )
                            : Container(
                                width: 44,
                                height: 44,
                                color: const Color(0xFFF1F5F9),
                                child: const Icon(
                                  Icons.build_rounded,
                                  color: _primaryBlue,
                                  size: 20,
                                ),
                              ),
                      ),
                      title: Text(
                        s.titulo,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? _primaryBlue : _titleDark,
                        ),
                      ),
                      subtitle: Text(
                        '${(s.funcao != null && s.funcao!.isNotEmpty) ? s.funcao! : 'Serviço'} • R\$ ${s.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: _textMuted,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: _primaryBlue,
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _selecionarServicoBase(s);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecaoImagem() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Imagem do Item ou Serviço ',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
              TextSpan(
                text: '(Opcional)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: _textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _escolherImagem,
          borderRadius: BorderRadius.circular(14),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: const Color(0xFFCBD5E1),
              strokeWidth: 1.2,
              gap: 4,
              dash: 5,
              radius: 14,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: _imagemSelecionada != null
                  ? Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: kIsWeb
                              ? Image.network(
                                  _imagemSelecionada!.path,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_imagemSelecionada!.path),
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _imagemSelecionada!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _titleDark,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Toque para alterar a foto',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: _primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _imagemSelecionada = null),
                        ),
                      ],
                    )
                  : (_imagemUrlExistente != null &&
                          _imagemUrlExistente!.isNotEmpty)
                      ? Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                _imagemUrlExistente!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 52,
                                  height: 52,
                                  color: const Color(0xFFF1F5F9),
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Foto do serviço selecionado',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _titleDark,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Toque para alterar a foto',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: _primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFEF4444),
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _imagemUrlExistente = null),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_a_photo_outlined,
                                color: _primaryBlue,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Adicionar foto do item ou serviço',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: _titleDark,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Formatos JPG, PNG até 10MB',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: _textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoAreaServico() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Área do Serviço (Ofício)',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderLight, width: 1.2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _oficioSelecionadoId,
              isExpanded: true,
              hint: const Text(
                'Selecione a área',
                style: TextStyle(fontSize: 14, color: _textMuted),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B),
              ),
              items: _oficios.map((oficio) {
                return DropdownMenuItem<int>(
                  value: oficio.id,
                  child: Text(
                    oficio.funcao,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: _titleDark,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (novoId) {
                if (novoId == null) return;
                setState(() {
                  _oficioSelecionadoId = novoId;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoNomeServico() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Nome do Serviço',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _titleDark,
                    ),
                  ),
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: _abrirSeletorSubservicoPrevio,
              child: const Text(
                '+ Subserviço prévio',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _primaryBlue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nomeController,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: _titleDark,
          ),
          decoration: InputDecoration(
            hintText: 'Confecção de chave codificada automotiva',
            hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderLight, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoDescricao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Descrição detalhada ',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _titleDark,
                    ),
                  ),
                  TextSpan(
                    text: '(Opcional)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: _textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$_caracteresDescricao/300',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descricaoController,
          maxLength: 300,
          maxLines: 3,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
              null,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _titleDark,
          ),
          decoration: InputDecoration(
            hintText:
                'Descreva especificações, materiais inclusos ou observações para o cliente...',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.all(12),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderLight, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoValor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Valor do Serviço',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
              TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _valorController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _titleDark,
          ),
          decoration: InputDecoration(
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Text(
                'R\$',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _titleDark,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderLight, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecaoTipoAtendimento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de Atendimento',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: _titleDark,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildItemMetodo('Leva e Traz')),
                const SizedBox(width: 10),
                Expanded(child: _buildItemMetodo('Retirada no Local')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildItemMetodo('Receba em Casa')),
                const SizedBox(width: 10),
                Expanded(child: _buildItemMetodo('Atendimento em Domicílio')),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemMetodo(String opcao) {
    final permitido = _metodoEstaPermitido(opcao, _metodosPermitidos);
    final selecionado = _tipoAtendimentoSelecionado == opcao;

    Color corBorda = _borderLight;
    Color corFundo = Colors.white;
    Color corTexto = const Color(0xFF334155);

    if (!permitido) {
      corBorda = const Color(0xFFE2E8F0);
      corFundo = const Color(0xFFF8FAFC);
      corTexto = const Color(0xFF94A3B8);
    } else if (selecionado) {
      corBorda = _primaryBlue;
      corFundo = const Color(0xFFF0F9FF);
      corTexto = const Color(0xFF0F172A);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: permitido
            ? () {
                setState(() => _tipoAtendimentoSelecionado = opcao);
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: corFundo,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: corBorda,
              width: selecionado && permitido ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Radio indicator circular
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: !permitido
                        ? const Color(0xFFCBD5E1)
                        : (selecionado ? _primaryBlue : const Color(0xFF94A3B8)),
                    width: 1.8,
                  ),
                ),
                child: selecionado && permitido
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: _primaryBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  opcao,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selecionado && permitido
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: corTexto,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRodape() {
    final valor = _obterValorNumerico();
    final totalFormatado =
        'R\$ ${NumberFormat('#,##0.00', 'pt_BR').format(valor)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total da Proposta',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textMuted,
                ),
              ),
              Text(
                totalFormatado,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _titleDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _enviando ? null : _submeterProposta,
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
              label: Text(
                _enviando ? 'Enviando Proposta...' : 'Enviar Serviço no chat',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                elevation: 0,
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

/// Custom painter para borda tracejada (dashed border)
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.dash = 5.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dash < metric.length)
            ? dash
            : metric.length - distance;
        final extractPath = metric.extractPath(distance, distance + length);
        canvas.drawPath(extractPath, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dash != dash ||
        oldDelegate.radius != radius;
  }
}
