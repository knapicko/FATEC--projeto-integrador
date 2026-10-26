import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'qrcode_pix.dart';
import 'pedido_pago.dart';
import 'services/stripe_pagamento_service.dart';
import 'tela_meu_perfil_cliente.dart';
import 'utils/iniciais.dart';
import 'widgets/imagem_servico.dart';
import 'widgets/skeleton_loading.dart';

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

class _MetodoPagamento {
  final String id;
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final bool destaquePix;
  final bool disponivel;

  const _MetodoPagamento({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.icone,
    this.destaquePix = false,
    this.disponivel = true,
  });
}

class _DadosCartao {
  final String numero;
  final int mesExpiracao;
  final int anoExpiracao;
  final String cvc;
  final String ultimosDigitos;

  const _DadosCartao({
    required this.numero,
    required this.mesExpiracao,
    required this.anoExpiracao,
    required this.cvc,
    required this.ultimosDigitos,
  });
}

class _PagamentoPedidoPageState extends State<PagamentoPedidoPage> {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _texto = Color(0xFF17212B);
  static const Color _muted = Color(0xFF667085);
  static const Color _fundo = Color(0xFFF6F8FA);
  static const Color _borda = Color(0xFFE6EAF0);
  static const Color _verde = Color(0xFF16A34A);
  static const Color _verdeFundo = Color(0xFFECFDF3);
  static const Color _verdeBorda = Color(0xFF22C55E);
  static const double _taxaServico = 3.0;

  static const List<String> _meses = [
    'Jan',
    'Fev',
    'Mar',
    'Abr',
    'Mai',
    'Jun',
    'Jul',
    'Ago',
    'Set',
    'Out',
    'Nov',
    'Dez',
  ];

  final SupabaseClient _db = Supabase.instance.client;

  bool _carregando = true;
  String _metodo = '';
  int _parcelas = 1;
  int _maxParcelas = 1;
  bool _salvando = false;
  String? _erro;
  String? _comprovante;
  DateTime? _dataPagamento;

  String? _fotoConta;
  String _nomeConta = '';

  String _tituloServico = '';
  String _nomeProfissional = '';
  String? _fotoProfissional;
  String? _imagemServico;
  String? _funcaoOficio;
  String? _corOficio;
  String? _dataAgendada;
  String? _horaAgendada;
  double _subtotal = 0;

  String _apelidoEndereco = 'Endereço';
  String _linhaEndereco = '';

  List<_MetodoPagamento> _metodosAceitos = const [];
  String? _condicoesParcela;
  String? _finalCartao;
  _DadosCartao? _dadosCartao;

  bool get _confirmado => _comprovante != null;

  double get _total => _subtotal + _taxaServico;

  bool get _metodoRequerCartao =>
      _metodo == 'Cartão de Crédito' || _metodo == 'Cartão de Débito';

  bool get _cartaoCadastrado =>
      _finalCartao != null && _finalCartao!.trim().isNotEmpty;

  bool get _podePagar {
    if (_salvando || _confirmado || _carregando) return false;
    if (_metodo.isEmpty) return false;
    if (_metodoRequerCartao && !_cartaoCadastrado) return false;
    return true;
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

  String get _horaFormatada {
    final hora = (_horaAgendada ?? widget.horaAgendada)?.trim() ?? '';
    if (hora.length >= 5) return hora.substring(0, 5);
    return hora;
  }

  String get _dataHoraExibida {
    final dataRaw = (_dataAgendada ?? widget.dataAgendada)?.trim() ?? '';
    final hora = _horaFormatada;
    final dataFmt = _formatarDataCurta(dataRaw);
    if (dataFmt.isEmpty && hora.isEmpty) return 'Data a combinar';
    if (dataFmt.isEmpty) return hora;
    if (hora.isEmpty) return dataFmt;
    return '$dataFmt, $hora';
  }

  String _formatarDataCurta(String dataRaw) {
    if (dataRaw.isEmpty) return '';
    DateTime? data = DateTime.tryParse(dataRaw);
    if (data == null) {
      final br = dataRaw.split('/');
      if (br.length == 3) {
        data = DateTime.tryParse('${br[2]}-${br[1]}-${br[0]}');
      }
    }
    if (data == null) return dataRaw;
    final mes = (data.month >= 1 && data.month <= 12)
        ? _meses[data.month - 1]
        : '';
    return '${data.day.toString().padLeft(2, '0')} $mes';
  }

  @override
  void initState() {
    super.initState();
    _tituloServico = widget.tituloServico;
    _nomeProfissional = widget.profissional;
    _subtotal = widget.valor;
    _dataAgendada = widget.dataAgendada;
    _horaAgendada = widget.horaAgendada;
    _carregarTudo();
  }

  Future<void> _carregarTudo() async {
    setState(() => _carregando = true);
    await Future.wait([_carregarConta(), _carregarPedido()]);
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _carregarConta() async {
    try {
      final usuarioAuth = _db.auth.currentUser;
      if (usuarioAuth == null) return;
      final usuario = await _db
          .from('usuarios')
          .select('nome, foto_perfil_url')
          .eq('auth_id', usuarioAuth.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _nomeConta = usuario?['nome']?.toString().trim() ?? '';
        _fotoConta = usuario?['foto_perfil_url']?.toString().trim();
      });
    } catch (_) {}
  }

  Map<String, dynamic>? _comoMapa(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first as Map);
    }
    return null;
  }

  Future<void> _carregarPedido() async {
    try {
      final sol = await _db
          .from('solicitacoes')
          .select('*')
          .eq('id_solicitacao', widget.idSolicitacao)
          .maybeSingle();
      if (sol == null) return;

      _dataAgendada = sol['data_agendada']?.toString() ?? _dataAgendada;
      _horaAgendada = sol['hora_agendada']?.toString() ?? _horaAgendada;
      final valorFinal = (sol['valor_final'] as num?)?.toDouble();
      if (valorFinal != null && valorFinal > 0) _subtotal = valorFinal;

      await _carregarServico(sol);
      await _carregarEndereco(sol);
      await _carregarPrestadorEPagamento(sol);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar os dados do pedido.');
      }
    }
  }

  Future<void> _carregarServico(Map<String, dynamic> sol) async {
    final fkServProf = (sol['fk_servico_prof'] as num?)?.toInt();
    final fkServTemp = (sol['fk_servico_temp'] as num?)?.toInt();

    Map<String, dynamic>? servico;
    try {
      if (fkServProf != null) {
        servico = await _db
            .from('servicos_profissional')
            .select('titulo, valor, imagem_url, oficios(funcao, cor)')
            .eq('id_servico_prof', fkServProf)
            .maybeSingle();
      } else if (fkServTemp != null) {
        servico = await _db
            .from('servicos_chat_temporario')
            .select('titulo, valor, imagem_url, oficios(funcao, cor)')
            .eq('id_servico_temp', fkServTemp)
            .maybeSingle();
      }
    } catch (_) {
      if (fkServProf != null) {
        servico = await _db
            .from('servicos_profissional')
            .select('titulo, valor, imagem_url')
            .eq('id_servico_prof', fkServProf)
            .maybeSingle();
      } else if (fkServTemp != null) {
        servico = await _db
            .from('servicos_chat_temporario')
            .select('titulo, valor, imagem_url')
            .eq('id_servico_temp', fkServTemp)
            .maybeSingle();
      }
    }
    if (servico == null) return;

    final titulo = servico['titulo']?.toString().trim() ?? '';
    if (titulo.isNotEmpty) _tituloServico = titulo;
    final img = servico['imagem_url']?.toString().trim();
    if (img != null && img.isNotEmpty) _imagemServico = img;
    final valor = (servico['valor'] as num?)?.toDouble();
    if ((_subtotal <= 0) && valor != null && valor > 0) _subtotal = valor;

    final oficios = _comoMapa(servico['oficios']);
    if (oficios != null) {
      _funcaoOficio = oficios['funcao']?.toString();
      final cor = oficios['cor']?.toString().trim();
      if (cor != null && cor.isNotEmpty) _corOficio = cor;
    }
  }

  Future<void> _carregarEndereco(Map<String, dynamic> sol) async {
    final fkEndereco = (sol['fk_endereco'] as num?)?.toInt();
    if (fkEndereco == null) {
      _linhaEndereco = 'Endereço não informado';
      return;
    }

    final end = await _db
        .from('enderecos')
        .select('logradouro, numero, complemento, bairro, cep, fk_cidade')
        .eq('id_endereco', fkEndereco)
        .maybeSingle();
    if (end == null) {
      _linhaEndereco = 'Endereço não informado';
      return;
    }

    String cidade = '';
    String uf = '';
    final idCidade = (end['fk_cidade'] as num?)?.toInt();
    if (idCidade != null) {
      final cid = await _db
          .from('cidades')
          .select('nome_cidade, fk_estado')
          .eq('id_cidade', idCidade)
          .maybeSingle();
      cidade = cid?['nome_cidade']?.toString().trim() ?? '';
      final idEstado = (cid?['fk_estado'] as num?)?.toInt();
      if (idEstado != null) {
        final est = await _db
            .from('estados')
            .select('sigla_estado')
            .eq('id_estado', idEstado)
            .maybeSingle();
        uf = est?['sigla_estado']?.toString().trim() ?? '';
      }
    }

    final log = end['logradouro']?.toString().trim() ?? '';
    final numero = end['numero']?.toString().trim() ?? '';
    final complemento = end['complemento']?.toString().trim() ?? '';
    final bairro = end['bairro']?.toString().trim() ?? '';
    final partes = <String>[
      if (log.isNotEmpty) (numero.isNotEmpty ? '$log, $numero' : log),
      if (complemento.isNotEmpty) complemento,
      if (bairro.isNotEmpty) bairro,
      if (cidade.isNotEmpty) (uf.isNotEmpty ? '$cidade - $uf' : cidade),
    ];
    _linhaEndereco = partes.isEmpty ? 'Endereço cadastrado' : partes.join(', ');

    final fkUsuario = (sol['fk_usuario'] as num?)?.toInt();
    if (fkUsuario != null) {
      try {
        final vinculo = await _db
            .from('ass_usuario_endereco')
            .select('apelido_endereco, tipo_endereco')
            .eq('fk_usuario', fkUsuario)
            .eq('fk_endereco', fkEndereco)
            .maybeSingle();
        final apelido = vinculo?['apelido_endereco']?.toString().trim() ?? '';
        final tipo = vinculo?['tipo_endereco']?.toString().trim() ?? '';
        if (apelido.isNotEmpty) {
          _apelidoEndereco = apelido;
        } else if (tipo.isNotEmpty) {
          _apelidoEndereco = tipo;
        } else {
          _apelidoEndereco = 'Casa';
        }
      } catch (_) {
        _apelidoEndereco = 'Casa';
      }
    }
  }

  Future<void> _carregarPrestadorEPagamento(Map<String, dynamic> sol) async {
    final fkGrupo = (sol['fk_grupo_empresa'] as num?)?.toInt();
    final fkProf = (sol['fk_profissional'] as num?)?.toInt();

    String? pagamentoAceito;
    String? condicoes;

    if (fkGrupo != null && fkGrupo > 0) {
      final grupo = await _db
          .from('grupo_empresa')
          .select(
            'nome_empresa, foto_url_empresa, pagamento_aceito, condicoes_parcela',
          )
          .eq('id_grupo_empresa', fkGrupo)
          .maybeSingle();
      final nome = grupo?['nome_empresa']?.toString().trim() ?? '';
      if (nome.isNotEmpty) _nomeProfissional = nome;
      final foto = grupo?['foto_url_empresa']?.toString().trim();
      if (foto != null && foto.isNotEmpty) _fotoProfissional = foto;
      pagamentoAceito = grupo?['pagamento_aceito']?.toString();
      condicoes = grupo?['condicoes_parcela']?.toString();
    } else if (fkProf != null && fkProf > 0) {
      final dados = await _db
          .from('dados_profissionais')
          .select('fk_usuario, pagamento_aceito, condicoes_parcela')
          .eq('id_profissional', fkProf)
          .maybeSingle();

      pagamentoAceito = dados?['pagamento_aceito']?.toString();
      condicoes = dados?['condicoes_parcela']?.toString();
      final fkUsuario = (dados?['fk_usuario'] as num?)?.toInt();
      if (fkUsuario != null) {
        final usuario = await _db
            .from('usuarios')
            .select('nome, foto_perfil_url')
            .eq('id_usuario', fkUsuario)
            .maybeSingle();
        final nome = usuario?['nome']?.toString().trim() ?? '';
        if (nome.isNotEmpty) _nomeProfissional = nome;
        final foto = usuario?['foto_perfil_url']?.toString().trim();
        if (foto != null && foto.isNotEmpty) _fotoProfissional = foto;
      }
    }

    _condicoesParcela = condicoes;
    _maxParcelas = _extrairMaxParcelas(condicoes);
    if (_parcelas > _maxParcelas) _parcelas = _maxParcelas;
    _metodosAceitos = _parseMetodos(
      pagamentoAceito,
      // O Pix agora é gerado pela Stripe; a chave Pix cadastrada pelo
      // profissional não é necessária para iniciar o pagamento do cliente.
      pixDisponivel: true,
    );
    if (_metodosAceitos.isEmpty) {
      _metodosAceitos = [
        _MetodoPagamento(
          id: 'Pix',
          titulo: 'PIX',
          subtitulo: 'Confirmação rápida pela Stripe',
          icone: Icons.pix,
          destaquePix: true,
          disponivel: true,
        ),
      ];
    }
    if (_metodo.isNotEmpty &&
        !_metodosAceitos.any((m) => m.id == _metodo && m.disponivel)) {
      _metodo = '';
    }
  }

  int _extrairMaxParcelas(String? condicao) {
    final texto = (condicao ?? '').toLowerCase();
    if (texto.trim().isEmpty) return 1;
    if (texto.contains('à vista') || texto.contains('a vista')) return 1;
    final match = RegExp(r'(\d+)\s*x').firstMatch(texto);
    final n = int.tryParse(match?.group(1) ?? '') ?? 1;
    return n.clamp(1, 12);
  }

  List<_MetodoPagamento> _parseMetodos(
    String? raw, {
    required bool pixDisponivel,
  }) {
    final lista = (raw ?? 'Pix')
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final metodos = <_MetodoPagamento>[];
    if (lista.contains('pix')) {
      metodos.add(
        _MetodoPagamento(
          id: 'Pix',
          titulo: 'PIX',
          subtitulo: pixDisponivel
              ? 'Confirmação rápida'
              : 'Chave PIX não cadastrada pelo profissional',
          icone: Icons.pix,
          destaquePix: true,
          disponivel: pixDisponivel,
        ),
      );
    }
    if (lista.contains('cartão de crédito') ||
        lista.contains('cartao de credito')) {
      metodos.add(
        const _MetodoPagamento(
          id: 'Cartão de Crédito',
          titulo: 'Cartão de Crédito',
          subtitulo: 'Informe os dados para finalizar',
          icone: Icons.credit_card_rounded,
        ),
      );
    }
    if (lista.contains('cartão de débito') ||
        lista.contains('cartao de debito')) {
      metodos.add(
        const _MetodoPagamento(
          id: 'Cartão de Débito',
          titulo: 'Cartão de Débito',
          subtitulo: 'Débito à vista',
          icone: Icons.credit_card_outlined,
        ),
      );
    }
    if (lista.contains('boleto bancário') ||
        lista.contains('boleto bancario') ||
        lista.contains('boleto')) {
      metodos.add(
        const _MetodoPagamento(
          id: 'Boleto',
          titulo: 'Boleto Bancário',
          subtitulo: 'Registro simulado nesta versão',
          icone: Icons.qr_code_2_rounded,
        ),
      );
    }
    return metodos;
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
        throw Exception(
          'O pagamento foi registrado, mas não retornou o comprovante.',
        );
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

  Future<void> _abrirConfirmacaoMetodo() async {
    if (!_podePagar) return;
    if (_metodo == 'Pix') {
      await _iniciarPagamentoPix();
      return;
    }
    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _buildBottomSheetConfirmacao(sheetContext),
    );
    if (confirmar == true && mounted) {
      if (_metodoRequerCartao) {
        await _iniciarPagamentoCartao();
      } else {
        await _confirmarPagamento();
      }
    }
  }

  Future<void> _iniciarPagamentoCartao() async {
    final cartao = _dadosCartao;
    if (_salvando || _confirmado || cartao == null) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });

    final processamento = showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildBottomSheetProcessandoPagamento(),
    );

    try {
      await Future<void>.delayed(Duration.zero);
      final pagamento = await StripePagamentoService.criarPagamentoCartao(
        idSolicitacao: widget.idSolicitacao,
        numero: cartao.numero,
        mesExpiracao: cartao.mesExpiracao,
        anoExpiracao: cartao.anoExpiracao,
        cvc: cartao.cvc,
        credito: _metodo.contains('Cr'),
      );
      if (mounted) Navigator.of(context).pop();
      await processamento;
      if (!mounted) return;
      if (pagamento.status != 'succeeded') {
        throw Exception(
          'O pagamento nÃ£o foi concluÃ­do. Status: ${pagamento.status}',
        );
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PedidoPagoPage(idSolicitacao: widget.idSolicitacao),
        ),
      );
    } catch (e) {
      if (mounted) {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      _dadosCartao = null;
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _iniciarPagamentoPix() async {
    if (_salvando || _confirmado) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      // O ID 2 é "Aguardando Pagamento" na tabela de status.
      // A alteração é feita pela RPC porque o cliente não pode atualizar
      // diretamente a tabela solicitacoes por causa do RLS.
      final pagamento = await StripePagamentoService.criarPagamentoPix(
        idSolicitacao: widget.idSolicitacao,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QrcodePixPage(
            idSolicitacao: widget.idSolicitacao,
            tituloServico: _tituloServico,
            profissional: _nomeProfissional,
            valor: _total,
            paymentIntentId: pagamento.paymentIntentId,
            pixCopiaECola: pagamento.pixCopiaECola,
            pixQrCodeUrl: pagamento.pixQrCodeUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _abrirPerfil() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TelaMeuPerfilClientePage()));
  }

  Future<void> _abrirNovoCartao() async {
    final resultado = await showModalBottomSheet<_DadosCartao>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _BottomSheetNovoCartao(),
    );
    if (resultado != null && mounted) {
      setState(() {
        _dadosCartao = resultado;
        _finalCartao = resultado.ultimosDigitos;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _fundo,
        body: SafeArea(
          child: _confirmado
              ? Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildConfirmacao()),
                  ],
                )
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _carregando
                          ? const SkeletonPage(layout: SkeletonLayout.cards)
                          : _buildFormulario(),
                    ),
                    if (!_carregando) _buildBarraConfirmacao(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: _azul,
          ),
          const Expanded(
            child: Text(
              'Pagamento',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _azul,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(onTap: _abrirPerfil, child: _buildAvatarConta(36)),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        _buildCardServico(),
        const SizedBox(height: 12),
        _buildCardValores(),
        const SizedBox(height: 18),
        const Text(
          'Endereço de Entrega',
          style: TextStyle(
            color: _texto,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _buildCardEndereco(),
        const SizedBox(height: 18),
        const Text(
          'Método de Pagamento',
          style: TextStyle(
            color: _texto,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ..._metodosAceitos.map(
          (metodo) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _metodoTile(metodo),
          ),
        ),
        if (_metodo == 'Cartão de Crédito') ...[
          _buildSeletorParcelas(),
          const SizedBox(height: 8),
        ],
        if (_metodoRequerCartao) _buildAdicionarCartao(),
        if (_erro != null) ...[
          const SizedBox(height: 12),
          Text(_erro!, style: const TextStyle(color: Color(0xFFB42318))),
        ],
      ],
    );
  }

  Widget _cardShell({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardServico() {
    return _cardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: ImagemServico(
                imagemUrl: _imagemServico,
                funcao: _funcaoOficio,
                cor: _corOficio,
                height: 72,
                width: 72,
                tamanhoIcone: 32,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tituloServico,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _texto,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: _muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _dataHoraExibida,
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _miniAvatarProfissional(),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _nomeProfissional,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _miniAvatarProfissional() {
    final foto = (_fotoProfissional ?? '').trim();
    return ClipOval(
      child: SizedBox(
        width: 18,
        height: 18,
        child: foto.startsWith('http')
            ? Image.network(
                foto,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackMiniProf(),
              )
            : _fallbackMiniProf(),
      ),
    );
  }

  Widget _fallbackMiniProf() {
    return ColoredBox(
      color: const Color(0xFFDCE5EE),
      child: Center(
        child: Text(
          obterIniciais(
            _nomeProfissional.isEmpty ? 'Profissional' : _nomeProfissional,
          ),
          style: const TextStyle(
            color: Color(0xFF5E6F7E),
            fontWeight: FontWeight.w700,
            fontSize: 7,
          ),
        ),
      ),
    );
  }

  Widget _buildCardValores() {
    return _cardShell(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumo dos Valores',
            style: TextStyle(
              color: _texto,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _linhaValor('Subtotal do serviço', _formatarValor(_subtotal)),
          const SizedBox(height: 8),
          _linhaValor('Taxa de serviço', _formatarValor(_taxaServico)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFEEF2F6)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: _texto,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _formatarValor(_total),
                style: const TextStyle(
                  color: _texto,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linhaValor(String label, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 13.5)),
        Text(valor, style: const TextStyle(color: _muted, fontSize: 13.5)),
      ],
    );
  }

  Widget _buildCardEndereco() {
    return _cardShell(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: _muted,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _apelidoEndereco,
                  style: const TextStyle(
                    color: _texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _linhaEndereco,
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metodoTile(_MetodoPagamento metodo) {
    final selecionado = metodo.disponivel && _metodo == metodo.id;
    final bloqueado = !metodo.disponivel;
    final subtitulo =
        (metodo.id == 'Cartão de Crédito' || metodo.id == 'Cartão de Débito') &&
            _finalCartao != null
        ? '**** **** **** $_finalCartao'
        : metodo.subtitulo;

    return Opacity(
      opacity: bloqueado ? 0.55 : 1,
      child: Material(
        color: selecionado ? _verdeFundo : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: bloqueado ? null : () => setState(() => _metodo = metodo.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selecionado ? _verdeBorda : _borda,
                width: selecionado ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                _iconeMetodo(metodo, selecionado),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metodo.titulo,
                        style: const TextStyle(
                          color: _texto,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (metodo.destaquePix && !bloqueado) ...[
                            Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: selecionado ? _verde : _muted,
                            ),
                            const SizedBox(width: 2),
                          ],
                          Expanded(
                            child: Text(
                              subtitulo,
                              style: TextStyle(
                                color: selecionado ? _verde : _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  selecionado
                      ? Icons.check_circle
                      : bloqueado
                      ? Icons.block
                      : Icons.circle_outlined,
                  color: selecionado ? _verde : const Color(0xFFCBD5E1),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconeMetodo(_MetodoPagamento metodo, bool selecionado) {
    if (metodo.destaquePix) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF32BCAD),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.pix, color: Colors.white, size: 22),
      );
    }
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: selecionado ? Colors.white : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(metodo.icone, color: selecionado ? _verde : _muted, size: 22),
    );
  }

  Widget _buildSeletorParcelas() {
    final opcoes = List<int>.generate(_maxParcelas, (i) => i + 1);
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _condicoesParcela?.trim().isNotEmpty == true
                ? 'Parcelamento (${_condicoesParcela!.trim()})'
                : 'Parcelamento',
            style: const TextStyle(
              color: _texto,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<int>(
            key: ValueKey('parcelas-$_maxParcelas'),
            initialValue: _parcelas.clamp(1, _maxParcelas),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _borda),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _borda),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _azul, width: 1.4),
              ),
            ),
            items: opcoes
                .map(
                  (qtd) => DropdownMenuItem(
                    value: qtd,
                    child: Text(
                      qtd == 1
                          ? 'À vista • ${_formatarValor(_total)}'
                          : '$qtd x ${_formatarValor(_total / qtd)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (valor) {
              if (valor != null) setState(() => _parcelas = valor);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdicionarCartao() {
    return TextButton.icon(
      onPressed: _abrirNovoCartao,
      icon: const Icon(Icons.add_circle_outline, color: _azul, size: 20),
      label: const Text(
        'Adicionar novo cartão',
        style: TextStyle(color: _azul, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildBarraConfirmacao() {
    return Container(
      color: _fundo,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: _muted),
              SizedBox(width: 6),
              Text(
                'Pagamento 100% seguro',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: _podePagar ? _abrirConfirmacaoMetodo : null,
              style: FilledButton.styleFrom(
                backgroundColor: _azul,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _salvando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Pagar serviço',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetConfirmacao(BuildContext sheetContext) {
    final tituloMetodo = _metodo == 'Cartão de Crédito' ? 'Cartão' : _metodo;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Icon(
              _metodo == 'Pix'
                  ? Icons.pix
                  : _metodo == 'Boleto'
                  ? Icons.receipt_long_outlined
                  : Icons.credit_card_outlined,
              color: _azul,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              'Confirmar pagamento por $tituloMetodo?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _texto,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatarValor(_total),
              style: const TextStyle(
                color: Color(0xFF087CA8),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (_metodo == 'Pix') ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _azul, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: 'SIMULACAO-PAGAMENTO-CJ-${widget.idSolicitacao}',
                  version: QrVersions.auto,
                  size: 176,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'QR code fictício para visualização. Não realiza pagamento.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ] else if (_metodo == 'Boleto') ...[
              const SizedBox(height: 12),
              const Text(
                'Este boleto é apenas uma simulação. Nenhuma cobrança real será emitida.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                '$_parcelas x ${_formatarValor(_total / _parcelas)}',
                style: const TextStyle(
                  color: _texto,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_finalCartao != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Cartão final $_finalCartao',
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
              const SizedBox(height: 6),
              const Text(
                'Nenhum dado do cartão será salvo. Esta é uma confirmação de teste.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _azul,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Confirmar pagamento'),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: const Text('Voltar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSheetProcessandoPagamento() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(strokeWidth: 4, color: _azul),
            ),
            const SizedBox(height: 18),
            const Text(
              'Processando pagamento',
              style: TextStyle(
                color: _texto,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Aguarde enquanto confirmamos seu pagamento com a Stripe.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarConta(double tamanho) {
    final foto = (_fotoConta ?? '').trim();
    final iniciais = obterIniciais(_nomeConta.isEmpty ? 'Conta' : _nomeConta);
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _azul, width: 2),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(
        child: foto.startsWith('http')
            ? Image.network(
                foto,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _avatarFallback(iniciais),
              )
            : _avatarFallback(iniciais),
      ),
    );
  }

  Widget _avatarFallback(String iniciais) {
    return ColoredBox(
      color: const Color(0xFFE0F2FE),
      child: Center(
        child: Text(
          iniciais,
          style: const TextStyle(
            color: _azul,
            fontWeight: FontWeight.w800,
            fontSize: 12,
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
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: const BoxDecoration(
              color: Color(0xFFE0F6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: _azul, size: 52),
          ),
          const SizedBox(height: 20),
          const Text(
            'Pagamento registrado',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _azul,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4E8EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comprovante do pedido',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const Divider(height: 24),
                _linhaComprovante('Serviço', _tituloServico),
                _linhaComprovante('Profissional', _nomeProfissional),
                _linhaComprovante('Forma', _metodo),
                if (_metodo == 'Cartão de Crédito')
                  _linhaComprovante(
                    'Parcelas',
                    '$_parcelas x ${_formatarValor(_total / _parcelas)}',
                  ),
                _linhaComprovante('Data', dataFormatada),
                _linhaComprovante('Documento', _comprovante!),
                const Divider(height: 24),
                _linhaComprovante(
                  'Total',
                  _formatarValor(_total),
                  destaque: true,
                ),
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

  Widget _linhaComprovante(
    String titulo,
    String valor, {
    bool destaque = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(titulo, style: const TextStyle(color: _muted)),
          ),
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

class _BottomSheetNovoCartao extends StatefulWidget {
  const _BottomSheetNovoCartao();

  @override
  State<_BottomSheetNovoCartao> createState() => _BottomSheetNovoCartaoState();
}

class _BottomSheetNovoCartaoState extends State<_BottomSheetNovoCartao> {
  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _texto = Color(0xFF17212B);
  static const Color _muted = Color(0xFF667085);

  final _formKey = GlobalKey<FormState>();
  final _numero = TextEditingController();
  final _nome = TextEditingController();
  final _validade = TextEditingController();
  final _cvv = TextEditingController();

  @override
  void dispose() {
    _numero.dispose();
    _nome.dispose();
    _validade.dispose();
    _cvv.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, {String? hint, Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      labelStyle: const TextStyle(color: _muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE6EAF0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE6EAF0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _azul, width: 1.5),
      ),
    );
  }

  void _usarCartao() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final digits = _numero.text.replaceAll(RegExp(r'\D'), '');
    final finalCartao = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : digits;
    final validade = _validade.text.split('/');
    final mes = int.tryParse(validade.first) ?? 0;
    final ano = int.tryParse(validade.last) ?? 0;
    Navigator.pop(
      context,
      _DadosCartao(
        numero: digits,
        mesExpiracao: mes,
        anoExpiracao: ano < 100 ? 2000 + ano : ano,
        cvc: _cvv.text.trim(),
        ultimosDigitos: finalCartao,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.credit_card_rounded,
                      color: _azul,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Adicionar cartão',
                    style: TextStyle(
                      color: _texto,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Os dados ficam só nesta tela e não são salvos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _numero,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                      _CartaoNumeroFormatter(),
                    ],
                    decoration: _decoration(
                      'Número do cartão',
                      hint: '•••• •••• •••• ••••',
                      prefix: const Icon(Icons.credit_card_outlined),
                    ),
                    validator: (v) {
                      final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
                      if (d.length < 13) return 'Informe um número válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nome,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _decoration(
                      'Nome impresso',
                      hint: 'Como no cartão',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _validade,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _ValidadeFormatter(),
                          ],
                          decoration: _decoration('Validade', hint: 'MM/AA'),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(t)) {
                              return 'MM/AA';
                            }
                            final mes = int.tryParse(t.substring(0, 2)) ?? 0;
                            if (mes < 1 || mes > 12) return 'Mês inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _cvv,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          decoration: _decoration('CVV', hint: '•••'),
                          validator: (v) {
                            final d = (v ?? '').trim();
                            if (d.length < 3) return 'CVV inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _usarCartao,
                      style: FilledButton.styleFrom(
                        backgroundColor: _azul,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Usar este cartão',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartaoNumeroFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final texto = buffer.toString();
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

class _ValidadeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    var texto = digits;
    if (digits.length >= 3) {
      texto = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}
