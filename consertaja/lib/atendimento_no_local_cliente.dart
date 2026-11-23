import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'detalhes_pedido.dart';
import 'tela_chat_profissional.dart';
import 'tela_meu_perfil_cliente.dart';
import 'utils/iniciais.dart';
import 'utils/voltar_fluxo_solicitacao.dart';
import 'widgets/skeletons_telas.dart';
import 'widgets/codigo_flutuante.dart';
import 'services/stripe_pagamento_service.dart';

/// Cliente acompanhando o atendimento no próprio endereço: etapas reais,
/// código de início, profissional (nota, veículo e placa), cronômetro ao
/// vivo, fotos de antes/depois e a confirmação de conclusão.
class AtendimentoNoLocalClientePage extends StatefulWidget {
  final int idSolicitacao;

  const AtendimentoNoLocalClientePage({super.key, required this.idSolicitacao});

  @override
  State<AtendimentoNoLocalClientePage> createState() =>
      _AtendimentoNoLocalClientePageState();
}

class _AtendimentoNoLocalClientePageState
    extends State<AtendimentoNoLocalClientePage>
    with VoltarParaPedidosMixin {
  /// Voltar (botão ou sistema) leva para meus_pedidos.dart.
  @override
  bool get voltarComoProfissional => false;

  static const _azul = Color(0xFF0FB3FF);
  static const _azulEscuro = Color(0xFF0A6E9D);
  static const _laranja = Color(0xFFF59E0B);
  static const _verde = Color(0xFF16A34A);
  static const _texto = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _fundo = Color(0xFFF5F7FA);
  final _db = Supabase.instance.client;

  bool _carregando = true;
  bool _confirmando = false;
  String _codigoPedido = '';
  String? _fotoCliente;
  String _nomeProfissional = 'Profissional';
  String? _fotoProfissional;
  String _titulo = 'Atendimento';
  String _endereco = 'Endereço do cliente';
  bool _loja = false;
  double _valor = 0;
  int _duracao = 0;
  DateTime? _inicio;
  bool _pausado = false;
  bool _profissionalFinalizou = false;
  String _codigoRecDev = '';
  double? _nota;
  int _atendimentos = 0;
  String? _meioLocomocao;
  String? _placa;
  Timer? _polling;
  Timer? _relogio;
  List<String> _antes = [];
  List<String> _depois = [];

  @override
  void initState() {
    super.initState();
    CodigoFlutuante.entrarNaTelaDoCodigo();
    _carregar();
    // Sincroniza com o profissional: início (código validado), pausa e
    // finalização.
    _polling = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _atualizarEstado(),
    );
    // Cronômetro ao vivo.
    _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _inicio != null && !_pausado && !_profissionalFinalizou) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _polling?.cancel();
    _relogio?.cancel();
    CodigoFlutuante.sairDaTelaDoCodigo();
    super.dispose();
  }

  /// Datas do banco sem fuso são UTC.
  DateTime? _dataUtc(Object? v) {
    final t = v?.toString().trim() ?? '';
    if (t.isEmpty) return null;
    final temFuso = t.endsWith('Z') || RegExp(r'[+-]\d\d:?\d\d$').hasMatch(t);
    return DateTime.tryParse(temFuso ? t : '${t}Z');
  }

  void _aplicarEstado(Map<String, dynamic> row) {
    _profissionalFinalizou = row['profissional_finalizado_atendimento'] == true;
    _pausado = row['andamento_pausado'] == true;
    _inicio = _dataUtc(row['data_inicio_andamento']);
    _duracao = (row['duracao_atendimento'] as num?)?.toInt() ?? _duracao;
    _antes = _lista(row['imagens_atendimento_antes']);
    _depois = _lista(row['imagens_atendimento_depois']);
  }

  Future<void> _atualizarEstado() async {
    if (!mounted || _confirmando) return;
    try {
      final row = await _db
          .from('solicitacoes')
          .select(
            'fk_status, profissional_finalizado_atendimento, '
            'data_inicio_andamento, duracao_atendimento, andamento_pausado, '
            'imagens_atendimento_antes, imagens_atendimento_depois',
          )
          .eq('id_solicitacao', widget.idSolicitacao)
          .maybeSingle();
      if (row == null || !mounted) return;
      if ((row['fk_status'] as num?)?.toInt() == 6) {
        _polling?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                DetalhesPedidoPage(idSolicitacao: widget.idSolicitacao),
          ),
        );
        return;
      }
      setState(() => _aplicarEstado(row));
    } catch (_) {}
  }

  List<String> _lista(dynamic value) => value is List
      ? value
            .map((e) => e.toString())
            .where((e) => e.startsWith('http'))
            .toList()
      : [];

  Future<void> _carregar() async {
    try {
      final row = await _db
          .from('solicitacoes')
          .select('*')
          .eq('id_solicitacao', widget.idSolicitacao)
          .single();
      _codigoPedido =
          '#PED-2026-${widget.idSolicitacao.toString().padLeft(4, '0')}';
      _valor = (row['valor_final'] as num?)?.toDouble() ?? 0;
      _codigoRecDev = row['codigo_rec_dev']?.toString().trim() ?? '';
      _aplicarEstado(row);
      final fkGrupo = (row['fk_grupo_empresa'] as num?)?.toInt();
      final fkProf = (row['fk_profissional'] as num?)?.toInt();
      final fkUsuario = (row['fk_usuario'] as num?)?.toInt();
      final fkEndereco = (row['fk_endereco'] as num?)?.toInt();
      final fkServico = (row['fk_servico_prof'] as num?)?.toInt();
      _loja = fkGrupo != null;

      await Future.wait([
        if (fkUsuario != null)
          _db
              .from('usuarios')
              .select('foto_perfil_url')
              .eq('id_usuario', fkUsuario)
              .maybeSingle()
              .then((u) => _fotoCliente = _url(u?['foto_perfil_url'])),
        _carregarPrestador(fkGrupo, fkProf),
        if (fkServico != null)
          _db
              .from('servicos_profissional')
              .select('titulo')
              .eq('id_servico_prof', fkServico)
              .maybeSingle()
              .then((s) => _titulo = s?['titulo']?.toString() ?? _titulo),
        if (fkEndereco != null) _carregarEndereco(fkEndereco),
        _carregarNota(fkGrupo, fkProf),
        _carregarLocomocao(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar atendimento: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String? _url(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.startsWith('http') ? s : null;
  }

  Future<void> _carregarPrestador(int? fkGrupo, int? fkProf) async {
    try {
      if (fkGrupo != null) {
        final g = await _db
            .from('grupo_empresa')
            .select('nome_empresa, foto_url_empresa')
            .eq('id_grupo_empresa', fkGrupo)
            .maybeSingle();
        _nomeProfissional = g?['nome_empresa']?.toString() ?? _nomeProfissional;
        _fotoProfissional = _url(g?['foto_url_empresa']);
        return;
      }
      if (fkProf == null) return;
      int? idUsuarioProf;
      try {
        final v = await _db.rpc(
          'vitrine_profissionais',
          params: {
            'p_ids': [fkProf],
          },
        );
        if (v is List && v.isNotEmpty) {
          idUsuarioProf = ((v.first as Map)['fk_usuario'] as num?)?.toInt();
        }
      } catch (_) {
        final p = await _db
            .from('dados_profissionais')
            .select('fk_usuario')
            .eq('id_profissional', fkProf)
            .maybeSingle();
        idUsuarioProf = (p?['fk_usuario'] as num?)?.toInt();
      }
      if (idUsuarioProf == null) return;
      final u = await _db
          .from('usuarios')
          .select('nome, foto_perfil_url')
          .eq('id_usuario', idUsuarioProf)
          .maybeSingle();
      _nomeProfissional = u?['nome']?.toString() ?? _nomeProfissional;
      _fotoProfissional = _url(u?['foto_perfil_url']);
    } catch (_) {}
  }

  Future<void> _carregarEndereco(int fkEndereco) async {
    try {
      final a = await _db
          .from('enderecos')
          .select('logradouro, numero, complemento, bairro')
          .eq('id_endereco', fkEndereco)
          .maybeSingle();
      if (a == null) return;
      String t(Object? v) => v?.toString().trim() ?? '';
      _endereco = [
        [
          t(a['logradouro']),
          t(a['numero']),
        ].where((x) => x.isNotEmpty).join(', '),
        t(a['complemento']),
        t(a['bairro']),
      ].where((x) => x.isNotEmpty).join(' · ');
    } catch (_) {}
  }

  /// Nota média e atendimentos concluídos do profissional/loja.
  Future<void> _carregarNota(int? fkGrupo, int? fkProf) async {
    if (fkGrupo == null && fkProf == null) return;
    try {
      var q = _db.from('solicitacoes').select('id_solicitacao, fk_status');
      q = fkGrupo != null
          ? q.eq('fk_grupo_empresa', fkGrupo)
          : q.eq('fk_profissional', fkProf!);
      final sols = await q;
      _atendimentos = sols
          .where((s) => (s['fk_status'] as num?)?.toInt() == 6)
          .length;
      final ids = [for (final s in sols) (s['id_solicitacao'] as num).toInt()];
      if (ids.isEmpty) return;
      final avs = await _db
          .from('avaliacoes_solicitacao')
          .select('nota')
          .eq('tipo_avaliacao', 'profissional')
          .inFilter('fk_solicitacao', ids);
      final notas = [
        for (final a in avs)
          if (a['nota'] is num) (a['nota'] as num).toDouble(),
      ];
      if (notas.isNotEmpty) {
        _nota = notas.reduce((x, y) => x + y) / notas.length;
      }
    } catch (_) {}
  }

  Future<void> _carregarLocomocao() async {
    try {
      final r = await _db.rpc(
        'locomocao_da_solicitacao',
        params: {'p_id_solicitacao': widget.idSolicitacao},
      );
      final linha = r is List && r.isNotEmpty ? r.first as Map : null;
      final meio = linha?['meio_locomocao']?.toString().trim() ?? '';
      final placa = linha?['placa_veiculo']?.toString().trim() ?? '';
      _meioLocomocao = meio.isEmpty ? null : meio;
      _placa = placa.isEmpty ? null : placa;
    } catch (_) {
      // Banco sem a v0_10: não mostra o veículo.
    }
  }

  int get _segundos {
    if (_inicio == null) return 0;
    if (_pausado || _profissionalFinalizou) return _duracao;
    final corrido = DateTime.now().toUtc().difference(_inicio!).inSeconds;
    return _duracao + (corrido < 0 ? 0 : corrido);
  }

  String _tempo(int total) {
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String d(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${d(h)}:${d(m)}:${d(s)}' : '${d(m)}:${d(s)}';
  }

  String _real(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  Future<void> _confirmarConclusao() async {
    if (!_profissionalFinalizou || _confirmando) return;
    setState(() => _confirmando = true);
    try {
      await _db
          .from('solicitacoes')
          .update({'fk_status': 6, 'etapa_solicitacao': 4})
          .eq('id_solicitacao', widget.idSolicitacao);
      StripePagamentoService.liberarPagamento(widget.idSolicitacao);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DetalhesPedidoPage(idSolicitacao: widget.idSolicitacao),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _confirmando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível concluir: $e')),
        );
      }
    }
  }

  void _abrirChat() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TelaChatProfissional(
        nomeProfissional: _nomeProfissional,
        fotoProfissional: _fotoProfissional ?? '',
        oficioPrincipal: _titulo,
        idSolicitacao: widget.idSolicitacao,
        // Abre (ou cria pelo servidor) a conversa deste pedido.
        somenteAbrirConversaExistente: true,
      ),
    ),
  );

  void _abrirFoto(List<String> fotos, int inicial) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: PageView.builder(
            controller: PageController(initialPage: inicial),
            itemCount: fotos.length,
            itemBuilder: (_, i) => Center(
              child: InteractiveViewer(child: Image.network(fotos[i])),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _ajuda() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Precisa de ajuda?',
                style: TextStyle(
                  color: _texto,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: _azul),
                title: const Text('Ver detalhes do pedido'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DetalhesPedidoPage(
                        idSolicitacao: widget.idSolicitacao,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_outlined, color: _azul),
                title: Text('Falar com $_nomeProfissional'),
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirChat();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.emergency_outlined,
                  color: Colors.red,
                ),
                title: const Text('Emergência (190)'),
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse('tel:190'));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Layout ─────────────────────────────────────────────────────────────

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEDEFF2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  Widget _tituloCard(IconData icone, String texto, {Widget? fim}) => Row(
    children: [
      Icon(icone, color: _azul, size: 20),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          texto,
          style: const TextStyle(
            color: _texto,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
      ?fim,
    ],
  );

  Widget _avatar(String? url, String nome, {double size = 48}) => CircleAvatar(
    radius: size / 2,
    backgroundColor: _azul,
    backgroundImage: url != null ? NetworkImage(url) : null,
    child: url == null
        ? Text(
            obterIniciais(nome),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.32,
            ),
          )
        : null,
  );

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: SafeArea(child: SkeletonEtapaFluxo(comMapa: false)),
      );
    }
    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: voltarParaPedidos,
          icon: const Icon(Icons.arrow_back_ios_new, color: _texto),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Atendimento no Local',
              style: TextStyle(
                color: _texto,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              _codigoPedido,
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ajuda',
            onPressed: _ajuda,
            icon: const Icon(Icons.help_outline_rounded, color: _texto),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TelaMeuPerfilClientePage(),
              ),
            ),
            icon: _avatar(_fotoCliente, 'Eu', size: 30),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _azul,
        onRefresh: _atualizarEstado,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            _etapas(),
            if (_inicio == null && _codigoRecDev.isNotEmpty) _codigoCard(),
            _cronometroCard(),
            _profissionalCard(),
            _enderecoCard(),
            _fotosCard(),
            _servicoCard(),
          ],
        ),
      ),
      bottomNavigationBar: _barraConfirmacao(),
    );
  }

  /// Etapas reais: Aceito → A caminho → No local → Em atendimento →
  /// Concluído (esta tela abre com o profissional já no endereço).
  Widget _etapas() {
    const nomes = ['Aceito', 'A caminho', 'No local', 'Atendendo', 'Concluído'];
    const icones = [
      Icons.check_rounded,
      Icons.directions_run_rounded,
      Icons.place_rounded,
      Icons.handyman_rounded,
      Icons.verified_rounded,
    ];
    final atual = _profissionalFinalizou
        ? 4
        : _inicio != null
        ? 3
        : 2;
    final textoAtual = switch (atual) {
      2 => 'O profissional chegou. Informe o código para ele começar.',
      3 =>
        _pausado
            ? 'Atendimento pausado pelo profissional.'
            : 'O profissional está fazendo o serviço.',
      _ => 'O profissional finalizou. Confira e confirme a conclusão.',
    };
    return _card(
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < nomes.length; i++) ...[
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < atual
                              ? _azul
                              : i == atual
                              ? (atual == 4 ? _verde : _laranja)
                              : const Color(0xFFE5E7EB),
                          boxShadow: i == atual
                              ? [
                                  BoxShadow(
                                    color: (atual == 4 ? _verde : _laranja)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Icon(
                          i < atual ? Icons.check_rounded : icones[i],
                          size: 16,
                          color: i <= atual
                              ? Colors.white
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        nomes[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: i == atual
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: i <= atual ? _texto : _muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              textoAtual,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _azulEscuro,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Código que o cliente mostra ao profissional para iniciar o atendimento.
  Widget _codigoCard() => _card(
    child: Column(
      children: [
        _tituloCard(Icons.password_rounded, 'Código de início'),
        const SizedBox(height: 4),
        const Text(
          'Informe este código ao profissional para ele iniciar o atendimento.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final d in _codigoRecDev.padRight(4, '-').split('').take(4))
              Container(
                width: 52,
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _azul.withValues(alpha: 0.4)),
                ),
                child: Text(
                  d,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _azulEscuro,
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _cronometroCard() {
    final rodando = _inicio != null && !_pausado && !_profissionalFinalizou;
    final status = _inicio == null
        ? 'Começa quando o código for validado'
        : _profissionalFinalizou
        ? 'Tempo total do atendimento'
        : _pausado
        ? 'Pausado'
        : 'Em andamento';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0FB3FF), Color(0xFF0A8FD6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _pausado ? Icons.pause_rounded : Icons.timer_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tempo de atendimento',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (rodando) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF86EFAC),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        status,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _tempo(_segundos),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconeMeio(String meio) => switch (meio) {
    'Carro' => Icons.directions_car_rounded,
    'Moto' => Icons.two_wheeler_rounded,
    'Bicicleta' => Icons.pedal_bike_rounded,
    'Transporte público' => Icons.directions_bus_rounded,
    _ => Icons.local_shipping_rounded,
  };

  Widget _profissionalCard() => _card(
    child: Column(
      children: [
        Row(
          children: [
            _avatar(_fotoProfissional, _nomeProfissional),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nomeProfissional,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _texto,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _azul.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _loja ? 'Loja' : 'Independente',
                          style: const TextStyle(
                            color: _azulEscuro,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.star_rounded, size: 15, color: _laranja),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '${_nota == null ? 'Novo' : _nota!.toStringAsFixed(1).replaceAll('.', ',')}'
                          ' · $_atendimentos '
                          '${_atendimentos == 1 ? 'atendimento' : 'atendimentos'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_meioLocomocao != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDEFF2)),
            ),
            child: Row(
              children: [
                Icon(_iconeMeio(_meioLocomocao!), color: _azul),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _meioLocomocao!,
                    style: const TextStyle(
                      color: _texto,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_placa != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF1E3A8A)),
                    ),
                    child: Text(
                      _placa!,
                      style: const TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _abrirChat,
            style: OutlinedButton.styleFrom(
              foregroundColor: _azul,
              side: const BorderSide(color: _azul),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text(
              'Conversar com $_nomeProfissional',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _enderecoCard() => _card(
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _azul.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_on_rounded, color: _azul),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No seu endereço',
                style: TextStyle(color: _texto, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                _endereco,
                style: const TextStyle(fontSize: 12.5, color: _muted),
              ),
              if (_inicio != null)
                Text(
                  'Atendimento iniciado às '
                  '${_inicio!.toLocal().hour.toString().padLeft(2, '0')}:'
                  '${_inicio!.toLocal().minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12.5, color: _muted),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _fotosCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloCard(Icons.photo_library_outlined, 'Fotos do atendimento'),
        const SizedBox(height: 12),
        _galeria('Antes', _antes),
        const SizedBox(height: 12),
        _galeria('Depois', _depois),
      ],
    ),
  );

  Widget _galeria(String titulo, List<String> fotos) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$titulo (${fotos.length})',
        style: const TextStyle(
          color: _muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        height: 84,
        child: fotos.isEmpty
            ? Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  titulo == 'Antes'
                      ? 'O profissional ainda não enviou as fotos de antes.'
                      : 'As fotos de depois aparecem ao finalizar.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: fotos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _abrirFoto(fotos, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      fotos[i],
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 84,
                        color: const Color(0xFFE5E7EB),
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: _muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    ],
  );

  Widget _servicoCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloCard(Icons.receipt_long_outlined, 'Resumo do pedido'),
        const SizedBox(height: 10),
        Text(
          _titulo,
          style: const TextStyle(
            color: _texto,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Valor total',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ),
            Text(
              _real(_valor),
              style: const TextStyle(
                color: _texto,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'O pagamento fica retido e só é liberado ao profissional quando '
          'você confirmar a conclusão.',
          style: TextStyle(color: _muted, fontSize: 11.5),
        ),
      ],
    ),
  );

  Widget _barraConfirmacao() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _verde,
            disabledBackgroundColor: const Color(0xFFE5E7EB),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _profissionalFinalizou && !_confirmando
              ? _confirmarConclusao
              : null,
          icon: _confirmando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  _profissionalFinalizou
                      ? Icons.check_circle_outline
                      : Icons.hourglass_top_rounded,
                ),
          label: Text(
            _profissionalFinalizou
                ? 'Confirmar conclusão do serviço'
                : 'Aguardando o profissional finalizar',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ),
  );
}
