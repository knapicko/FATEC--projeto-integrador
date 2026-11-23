import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'perfil_loja.dart';
import 'perfil_profissional.dart';
import 'services/avaliacoes_pendentes.dart';
import 'tela_servico.dart';
import 'utils/cor_oficio.dart';
import 'utils/fluxo_solicitacao.dart';
import 'utils/iniciais.dart';
import 'widgets/skeleton_loading.dart';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';
import 'utils/movimento.dart';

/// Pedido CONCLUÍDO visto pelo cliente (servico_concluido.dart reexporta):
/// avaliação no topo, loja/profissional, detalhes do pedido e pagamento,
/// e detalhes da entrega.
class ServicoConcluidoClientePage extends StatefulWidget {
  const ServicoConcluidoClientePage({super.key, required this.idSolicitacao});

  final int idSolicitacao;

  @override
  State<ServicoConcluidoClientePage> createState() =>
      _ServicoConcluidoClientePageState();
}

class _ServicoConcluidoClientePageState
    extends State<ServicoConcluidoClientePage> {
  static const _azul = Color(0xFF0FB3FF);
  static const _texto = Color(0xFF111827);
  static const _sec = Color(0xFF6B7280);
  static const _borda = Color(0xFFE5E7EB);
  static const _fundo = Color(0xFFF5F7FA);

  final _db = Supabase.instance.client;
  bool _carregando = true;
  String? _erro;

  Map<String, dynamic> _sol = const {};
  int? _idUsuario;
  String _titulo = 'Serviço';
  String? _imagemServico;
  int? _idServico;
  String? _funcao;
  Color _corFuncao = _azul;

  bool _ehLoja = false;
  int? _idProfissional;
  int? _idGrupo;
  String _prestador = 'Profissional';
  String? _fotoPrestador;
  String? _tag;
  String? _corTag;
  double? _notaPrestador;
  int _totalAvaliacoes = 0;

  String _nomeCliente = '';
  String _endereco = '';

  // Pagamento
  String? _metodoPagamento;
  DateTime? _dataPagamento;
  String? _idPagamento;
  bool _pagamentoAberto = true;

  // Avaliação do cliente
  int? _minhaNota;
  String _meuComentario = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String get _codigo => '#${widget.idSolicitacao.toString().padLeft(6, '0')}';

  double get _valor => (_sol['valor_final'] as num?)?.toDouble() ?? 0;

  DateTime? _data(String campo) =>
      DateTime.tryParse(_sol[campo]?.toString() ?? '')?.toLocal();

  Future<T?> _opcional<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      debugPrint('[serviço concluído] $e');
      return null;
    }
  }

  Future<void> _carregar() async {
    try {
      final sol = await _db
          .from('solicitacoes')
          .select()
          .eq('id_solicitacao', widget.idSolicitacao)
          .single();
      _sol = sol;
      _idProfissional = (sol['fk_profissional'] as num?)?.toInt();
      _idGrupo = (sol['fk_grupo_empresa'] as num?)?.toInt();
      _ehLoja = _idGrupo != null;
      _idServico = (sol['fk_servico_prof'] as num?)?.toInt();
      final idTemp = (sol['fk_servico_temp'] as num?)?.toInt();
      final idEndereco = (sol['fk_endereco'] as num?)?.toInt();
      final idCliente = (sol['fk_usuario'] as num?)?.toInt();

      final user = _db.auth.currentUser;
      if (user != null) {
        final u = await _opcional(
          () => _db
              .from('usuarios')
              .select('id_usuario')
              .eq('auth_id', user.id)
              .maybeSingle(),
        );
        _idUsuario = (u?['id_usuario'] as num?)?.toInt();
      }

      await Future.wait([
        _carregarServico(idTemp),
        _carregarPrestador(),
        if (idEndereco != null) _carregarEndereco(idEndereco),
        if (idCliente != null) _carregarCliente(idCliente),
        _carregarPagamento(),
        _carregarMinhaAvaliacao(),
      ]);
      _erro = null;
    } catch (e) {
      debugPrint('[serviço concluído] $e');
      _erro = 'Não foi possível carregar o pedido.';
    }
    if (mounted) setState(() => _carregando = false);
  }

  Future<void> _carregarServico(int? idTemp) async {
    Map<String, dynamic>? s;
    if (_idServico != null) {
      s = await _opcional<Map<String, dynamic>?>(
        () => _db
            .from('servicos_profissional')
            .select(
              'titulo, imagem_url, funcoes(funcao, oficios(cor, cod_cor))',
            )
            .eq('id_servico_prof', _idServico!)
            .maybeSingle(),
      );
    } else if (idTemp != null) {
      s = await _opcional<Map<String, dynamic>?>(
        () => _db
            .from('servicos_chat_temporarios')
            .select(
              'titulo, imagem_url, funcoes(funcao, oficios(cor, cod_cor))',
            )
            .eq('id_servico_temp', idTemp)
            .maybeSingle(),
      );
    }
    if (s == null) return;
    _titulo = s['titulo']?.toString().trim().isNotEmpty == true
        ? s['titulo'].toString().trim()
        : _titulo;
    final img = s['imagem_url']?.toString() ?? '';
    _imagemServico = img.startsWith('http') ? img : null;
    final f = s['funcoes'];
    if (f is Map) {
      _funcao = f['funcao']?.toString();
      final o = f['oficios'];
      if (o is Map)
        _corFuncao = CorOficio.parse((o['cod_cor'] ?? o['cor'])?.toString());
    }
    if (_imagemServico == null) {
      final anexos = _sol['imagens_anexadas_cliente'];
      if (anexos is List && anexos.isNotEmpty) {
        final a = anexos.first.toString();
        if (a.startsWith('http')) _imagemServico = a;
      }
    }
  }

  Future<void> _carregarPrestador() async {
    if (_ehLoja) {
      final g = await _opcional(
        () => _db
            .from('grupo_empresa')
            .select(
              'nome_empresa, foto_url_empresa, tag_empresa, cor_tag_empresa',
            )
            .eq('id_grupo_empresa', _idGrupo!)
            .maybeSingle(),
      );
      _prestador = g?['nome_empresa']?.toString() ?? 'Loja';
      _fotoPrestador = g?['foto_url_empresa']?.toString();
      final t = g?['tag_empresa']?.toString().trim() ?? '';
      _tag = t.isEmpty ? null : (t.startsWith('#') ? t : '#$t').toUpperCase();
      _corTag = g?['cor_tag_empresa']?.toString();
    } else if (_idProfissional != null) {
      final d = await _opcional(
        () => _db
            .from('dados_profissionais')
            .select('fk_usuario')
            .eq('id_profissional', _idProfissional!)
            .maybeSingle(),
      );
      final idU = (d?['fk_usuario'] as num?)?.toInt();
      if (idU != null) {
        final u = await _opcional(
          () => _db
              .from('usuarios')
              .select('nome, foto_perfil_url')
              .eq('id_usuario', idU)
              .maybeSingle(),
        );
        _prestador = u?['nome']?.toString() ?? _prestador;
        _fotoPrestador = u?['foto_perfil_url']?.toString();
      }
    }
    // Nota média do prestador.
    final sols = await _opcional(() {
      var q = _db.from('solicitacoes').select('id_solicitacao');
      q = _ehLoja
          ? q.eq('fk_grupo_empresa', _idGrupo!)
          : q.eq('fk_profissional', _idProfissional ?? -1);
      return q;
    });
    final ids = [
      for (final r in sols ?? const []) (r['id_solicitacao'] as num).toInt(),
    ];
    if (ids.isEmpty) return;
    final avs = await _opcional(
      () => _db
          .from('avaliacoes_solicitacao')
          .select('nota')
          .eq('tipo_avaliacao', 'profissional')
          .inFilter('fk_solicitacao', ids),
    );
    final notas = [
      for (final a in avs ?? const [])
        if (a['nota'] != null) (a['nota'] as num).toDouble(),
    ];
    if (notas.isNotEmpty) {
      _totalAvaliacoes = notas.length;
      _notaPrestador = notas.reduce((a, b) => a + b) / notas.length;
    }
  }

  Future<void> _carregarEndereco(int id) async {
    final e = await _opcional(
      () => _db
          .from('enderecos')
          .select('logradouro, numero, complemento, bairro, cep, fk_cidade')
          .eq('id_endereco', id)
          .maybeSingle(),
    );
    if (e == null) return;
    String t(Object? v) => (v ?? '').toString().trim();
    var cidade = '';
    var uf = '';
    final idCidade = (e['fk_cidade'] as num?)?.toInt();
    if (idCidade != null) {
      final c = await _opcional(
        () => _db
            .from('cidades')
            .select('nome_cidade, estados(sigla_estado)')
            .eq('id_cidade', idCidade)
            .maybeSingle(),
      );
      cidade = t(c?['nome_cidade']);
      final est = c?['estados'];
      if (est is Map) uf = t(est['sigla_estado']);
    }
    final linha1 = [
      t(e['logradouro']),
      t(e['numero']),
      t(e['complemento']),
    ].where((x) => x.isNotEmpty).join(', ');
    final linha2 = [
      [cidade, uf].where((x) => x.isNotEmpty).join(', '),
      t(e['cep']),
    ].where((x) => x.isNotEmpty).join(', ');
    _endereco = [linha1, linha2].where((x) => x.isNotEmpty).join('\n');
  }

  Future<void> _carregarCliente(int id) async {
    final u = await _opcional(
      () => _db
          .from('usuarios')
          .select('nome')
          .eq('id_usuario', id)
          .maybeSingle(),
    );
    _nomeCliente = u?['nome']?.toString() ?? '';
  }

  Future<void> _carregarPagamento() async {
    final p = await _opcional(
      () => _db
          .from('pagamentos_stripe')
          .select('metodo_pagamento, data_pagamento, stripe_payment_intent_id')
          .eq('fk_solicitacao', widget.idSolicitacao)
          .maybeSingle(),
    );
    _metodoPagamento = p?['metodo_pagamento']?.toString();
    _dataPagamento = DateTime.tryParse(
      p?['data_pagamento']?.toString() ?? '',
    )?.toLocal();
    _idPagamento = p?['stripe_payment_intent_id']?.toString();
  }

  Future<void> _carregarMinhaAvaliacao() async {
    final av = await _opcional(
      () => _db
          .from('avaliacoes_solicitacao')
          .select('nota, comentario, fk_avaliador')
          .eq('fk_solicitacao', widget.idSolicitacao)
          .eq('tipo_avaliacao', 'servico'),
    );
    for (final a in av ?? const []) {
      if (_idUsuario == null ||
          (a['fk_avaliador'] as num?)?.toInt() == _idUsuario) {
        _minhaNota = (a['nota'] as num?)?.toInt();
        _meuComentario = a['comentario']?.toString().trim() ?? '';
        break;
      }
    }
  }

  Future<void> _avaliar() async {
    final ok = await AvaliacoesPendentes.avaliar(context, widget.idSolicitacao);
    if (ok && mounted) {
      await _carregarMinhaAvaliacao();
      if (mounted) setState(() {});
    }
  }

  void _copiar() {
    Clipboard.setData(ClipboardData(text: _codigo));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Número do pedido copiado.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _abrirPrestador() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ehLoja
            ? PerfilLoja(
                idGrupoEmpresa: _idGrupo,
                nomeEmpresa: _prestador,
                fotoUrlEmpresa: _fotoPrestador,
                tagEmpresa: _tag,
                corTagEmpresa: _corTag,
              )
            : PerfilProfissionalPage(
                nomeInicial: _prestador,
                imagemInicial: _fotoPrestador ?? '',
                idProfissional: _idProfissional,
                avaliacao: _notaPrestador,
                totalAvaliacoes: _totalAvaliacoes,
              ),
      ),
    );
  }

  void _abrirServico() {
    if (_idServico == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TelaServico(idServico: _idServico)),
    );
  }

  // ------------------------------------------------------------- formatação

  static const _dias = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
  static const _meses = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  String _dd(int n) => n.toString().padLeft(2, '0');
  String _dataCurta(DateTime d) => '${_dd(d.day)}/${_dd(d.month)}/${d.year}';
  String _diaHora(DateTime d) =>
      '${_dias[d.weekday - 1]} - ${_dd(d.hour)}:${_dd(d.minute)}';
  String _dataExtenso(DateTime d) =>
      '${d.day} de ${_meses[d.month - 1]} de ${d.year}';

  String _real(double v) {
    final p = v.toStringAsFixed(2).split('.');
    final i = p[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'R\$ $i,${p[1]}';
  }

  String get _rotuloEntrega {
    final m = ModalidadeExecucao.fromString(_sol['tipo_execucao']?.toString());
    return switch (m) {
      ModalidadeExecucao.levaETraz => 'Detalhes Leva e Traz',
      ModalidadeExecucao.atendimentoDomicilio => 'Atendimento no Endereço',
      ModalidadeExecucao.retiradaNoLocal => 'Detalhes Retirada',
      ModalidadeExecucao.recebaEmCasa => 'Detalhes Entrega',
    };
  }

  String get _tipoEntrega {
    final m = ModalidadeExecucao.fromString(_sol['tipo_execucao']?.toString());
    return switch (m) {
      ModalidadeExecucao.atendimentoDomicilio ||
      ModalidadeExecucao.retiradaNoLocal => 'Presencial',
      _ => 'Entrega',
    };
  }

  // ----------------------------------------------------------------- layout

  BoxDecoration get _caixa => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: _borda),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  Widget _chip(String texto, Color fundo, Color letra) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: fundo,
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(
      texto,
      style: TextStyle(color: letra, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );

  Widget _chipFuncao() => _funcao == null
      ? const SizedBox.shrink()
      : _chip(
          _funcao!,
          _corFuncao.withValues(alpha: 0.2),
          CorOficio.corTexto(_corFuncao),
        );

  Widget _cartaoAvaliacao() {
    final avaliado = _minhaNota != null;
    return Container(
      decoration: _caixa,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Text(
            avaliado ? 'Sua avaliação' : 'Avalie Este Serviço',
            style: const TextStyle(
              color: _texto,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: avaliado ? null : _avaliar,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      avaliado && i < _minhaNota!
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 40,
                      color: avaliado ? const Color(0xFFF59E0B) : _azul,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (avaliado)
            Text(
              _meuComentario.isEmpty
                  ? 'Obrigado pela avaliação!'
                  : '"$_meuComentario"',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _sec, fontSize: 13.5),
            )
          else
            TextButton(
              onPressed: _avaliar,
              style: TextButton.styleFrom(foregroundColor: _sec),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Deixe um comentário', style: TextStyle(fontSize: 14)),
                  Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cabecalhoAzul(String titulo, {Widget? extra}) => CorOriginal(interface: true, child: Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      color: _azul,
      borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
    ),
    child: Row(
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (extra != null) ...[const SizedBox(width: 8), extra],
      ],
    ),
  ));

  Widget _codigoCopiavel({Color cor = Colors.white, double tamanho = 12}) =>
      InkWell(
        onTap: _copiar,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _codigo,
              style: TextStyle(
                color: cor,
                fontSize: tamanho,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.copy_rounded, size: tamanho + 2, color: cor),
          ],
        ),
      );

  Widget _avatar(String? url, String nome, {double tamanho = 52}) {
    final u = url ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: tamanho,
        height: tamanho,
        child: u.startsWith('http')
            ? ImagemApp(child: Image.network(u, fit: BoxFit.cover))
            : Container(
                color: const Color(0xFFE0F2FE),
                alignment: Alignment.center,
                child: Text(
                  obterIniciais(nome),
                  style: const TextStyle(
                    color: _azul,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _cartaoPrestador() {
    final corTag = CorOficio.parse(_corTag);
    return Container(
      decoration: _caixa,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cabecalhoAzul('Pedido Finalizado', extra: _codigoCopiavel()),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              _ehLoja ? 'Informações da Loja' : 'Informações do Profissional',
              style: const TextStyle(
                color: _texto,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              children: [
                if (_tag != null)
                  _chip(
                    _tag!,
                    corTag.withValues(alpha: 0.25),
                    CorOficio.corTexto(corTag),
                  ),
                _chipFuncao(),
              ],
            ),
          ),
          const Divider(height: 20, color: _borda),
          InkWell(
            onTap: _abrirPrestador,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 8, 12),
              child: Row(
                children: [
                  _avatar(_fotoPrestador, _prestador),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _prestador,
                          style: const TextStyle(
                            color: _texto,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _ehLoja ? 'Loja parceira' : 'Profissional',
                              style: const TextStyle(color: _sec, fontSize: 12),
                            ),
                            if (_notaPrestador != null) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: _azul,
                              ),
                              Text(
                                ' ${_notaPrestador!.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: _texto,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                ' ($_totalAvaliacoes)',
                                style: const TextStyle(
                                  color: _sec,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _sec,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaData(String rotulo, DateTime? d) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$rotulo: ${d == null ? '—' : _dataCurta(d)}',
          style: const TextStyle(color: _texto, fontSize: 13.5),
        ),
        if (d != null) ...[
          const SizedBox(width: 6),
          Text(
            _diaHora(d),
            style: const TextStyle(color: _sec, fontSize: 10.5),
          ),
        ],
      ],
    ),
  );

  Widget _linhaValor(String a, String b, {bool forte = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            a,
            style: TextStyle(
              color: _texto,
              fontSize: forte ? 17 : 14,
              fontWeight: forte ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          b,
          style: TextStyle(
            color: _texto,
            fontSize: forte ? 17 : 12.5,
            fontWeight: forte ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );

  Widget _cartaoDetalhes() {
    final pago = _dataPagamento ?? _data('data_aceite');
    final metodo = (_metodoPagamento ?? 'Pix').trim();
    final pix = metodo.toLowerCase().contains('pix');
    return Container(
      decoration: _caixa,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(
              'Detalhes do Pedido',
              style: TextStyle(
                color: _texto,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(height: 1, color: _borda),
          // Serviço
          InkWell(
            onTap: _idServico == null ? null : _abrirServico,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Row(
                children: [
                  _avatar(_imagemServico, _titulo, tamanho: 56),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _texto,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _chipFuncao(),
                        _linhaData('Solicitado', _data('data_solicitacao')),
                        _linhaData(
                          'Finalizado',
                          _data('data_finalizacao') ??
                              _data('data_pagamento_liberado'),
                        ),
                      ],
                    ),
                  ),
                  if (_idServico != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _sec,
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: _borda),
          // Pagamento
          InkWell(
            onTap: () => setState(() => _pagamentoAberto = !_pagamentoAberto),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      border: Border.all(color: _borda),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      pix ? Icons.pix_rounded : Icons.credit_card_rounded,
                      color: const Color(0xFF32BCAD),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _real(_valor),
                              style: const TextStyle(
                                color: _texto,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _chip(
                              'PAGO',
                              const Color(0xFF86EFAC),
                              const Color(0xFF166534),
                            ),
                          ],
                        ),
                        Text(
                          'Tipo: ${pix ? 'Pix' : metodo}',
                          style: const TextStyle(color: _texto, fontSize: 13.5),
                        ),
                        _linhaData('Efetuado', pago),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _pagamentoAberto ? 0.5 : 0,
                    duration: duracao(const Duration(milliseconds: 180)),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      color: _sec,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: duracao(const Duration(milliseconds: 200)),
            alignment: Alignment.topCenter,
            child: !_pagamentoAberto
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(color: _borda),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (pago != null)
                              Text(
                                _dataExtenso(pago),
                                style: const TextStyle(
                                  color: _sec,
                                  fontSize: 11,
                                ),
                              ),
                            if (_idPagamento != null)
                              Text(
                                '| ${_idPagamento!.length > 10 ? _idPagamento!.substring(_idPagamento!.length - 10) : _idPagamento}',
                                style: const TextStyle(
                                  color: _sec,
                                  fontSize: 11,
                                ),
                              ),
                            Text(
                              _sol['pagamento_liberado'] == true
                                  ? 'Pagamento liberado ao profissional'
                                  : 'Pagamento aprovado',
                              style: const TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _linhaValor('Serviço', _real(_valor)),
                        _linhaValor('Frete', 'Sem Frete'),
                        const Divider(color: _borda),
                        _linhaValor('Total', _real(_valor), forte: true),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoEntrega() {
    return Container(
      decoration: _caixa,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cabecalhoAzul('Detalhes da Entrega'),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: _texto,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _rotuloEntrega,
                              style: const TextStyle(
                                color: _texto,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _tipoEntrega,
                            style: const TextStyle(color: _sec, fontSize: 11),
                          ),
                        ],
                      ),
                      if (_nomeCliente.isNotEmpty)
                        Text(
                          _nomeCliente,
                          style: const TextStyle(color: _sec, fontSize: 12.5),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        _endereco.isEmpty
                            ? 'Endereço não informado'
                            : _endereco,
                        style: const TextStyle(
                          color: _texto,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _azul),
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(
              child: Text(
                _titulo,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _azul,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(_codigo, style: const TextStyle(color: _sec, fontSize: 12)),
          ],
        ),
        actions: [
          BotaoAjuda(
            passos: () => explicacaoDaTela(
              context,
              tela: 'Este é o resumo do seu serviço concluído.',
              conteudo: [
                'Aqui você vê as etapas e os valores, e pode avaliar o profissional.',
              ],
            ),
          ),
        ],
      ),
      body: _carregando
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                SkeletonBox(height: 130, borderRadius: 8),
                SizedBox(height: 14),
                SkeletonBox(height: 170, borderRadius: 8),
                SizedBox(height: 14),
                SkeletonBox(height: 260, borderRadius: 8),
              ],
            )
          : _erro != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_erro!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
                children: [
                  _cartaoAvaliacao(),
                  const SizedBox(height: 14),
                  _cartaoPrestador(),
                  const SizedBox(height: 14),
                  _cartaoDetalhes(),
                  const SizedBox(height: 14),
                  _cartaoEntrega(),
                  const SizedBox(height: 40),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Pedido ',
                          style: TextStyle(color: _azul, fontSize: 13),
                        ),
                        _codigoCopiavel(cor: _azul, tamanho: 13),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
