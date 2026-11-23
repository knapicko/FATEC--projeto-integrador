import 'package:flutter/material.dart';
export 'servico_concluido_cliente.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tela_home_profissional.dart';
import 'tela_meu_perfil_profissional.dart';
import 'utils/fluxo_solicitacao.dart';
import 'utils/voltar_fluxo_solicitacao.dart';
import 'widgets/skeleton_loading.dart';
import 'tutorial/botao_ajuda.dart';
import 'widgets/imagem_app.dart';

/// Última tela do fluxo do PROFISSIONAL: serviço concluído (as duas
/// confirmações feitas) e o valor que ele recebe.
class ServicoConcluidoPage extends StatefulWidget {
  final int idSolicitacao;

  const ServicoConcluidoPage({super.key, required this.idSolicitacao});

  @override
  State<ServicoConcluidoPage> createState() => _ServicoConcluidoPageState();
}

class _ServicoConcluidoPageState extends State<ServicoConcluidoPage>
    with VoltarParaPedidosMixin {
  /// Voltar (botão ou sistema) leva para meus_servicos_solicitados.dart.
  @override
  bool get voltarComoProfissional => true;

  /// Taxa de intermediação do ConsertaJá descontada do profissional.
  static const double _taxaIntermediacao = 0.12;

  static const Color _azul = Color(0xFF0FB3FF);
  static const Color _fundo = Color(0xFFF1F3F6);
  static const Color _texto = Color(0xFF1D2430);
  static const Color _textoSec = Color(0xFF6B7280);
  static const Color _cinzaInterno = Color(0xFFF3F4F6);
  static const Color _vermelho = Color(0xFFDC2626);

  final _db = Supabase.instance.client;
  bool _carregando = true;
  String? _erro;

  Map<String, dynamic>? _solicitacao;
  ModalidadeExecucao _modalidade = ModalidadeExecucao.levaETraz;
  String _nomeCliente = 'Cliente';
  String? _fotoCliente;
  String _titulo = 'Serviço';
  String _endereco = '';
  final List<_FotoConclusao> _fotos = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  List<String> _lista(dynamic value) => value is List
      ? value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
      : const [];

  Future<void> _carregar() async {
    try {
      final row = await _db
          .from('solicitacoes')
          .select('*')
          .eq('id_solicitacao', widget.idSolicitacao)
          .single();
      _solicitacao = row;
      _modalidade = ModalidadeExecucao.fromString(
        row['tipo_execucao']?.toString(),
      );

      final idCliente = (row['fk_usuario'] as num?)?.toInt();
      final idServico = (row['fk_servico_prof'] as num?)?.toInt();
      final idServicoTemp = (row['fk_servico_temp'] as num?)?.toInt();
      final idEndereco = (row['fk_endereco'] as num?)?.toInt();

      await Future.wait([
        if (idCliente != null)
          _db
              .from('usuarios')
              .select('nome, foto_perfil_url')
              .eq('id_usuario', idCliente)
              .maybeSingle()
              .then((u) {
                final nome = u?['nome']?.toString().trim() ?? '';
                if (nome.isNotEmpty) _nomeCliente = nome;
                final foto = u?['foto_perfil_url']?.toString().trim() ?? '';
                _fotoCliente = foto.isEmpty || foto == 'null' ? null : foto;
              }),
        if (idServico != null)
          _db
              .from('servicos_profissional')
              .select('titulo')
              .eq('id_servico_prof', idServico)
              .maybeSingle()
              .then((s) => _titulo = s?['titulo']?.toString() ?? _titulo)
        else if (idServicoTemp != null)
          _db
              .from('servicos_chat_temporarios')
              .select('titulo')
              .eq('id_servico_temp', idServicoTemp)
              .maybeSingle()
              .then((s) => _titulo = s?['titulo']?.toString() ?? _titulo),
        if (idEndereco != null) _carregarEndereco(idEndereco),
      ]);

      final grupos = _modalidade.ehDomicilio
          ? const [
              ('Antes', 'imagens_atendimento_antes'),
              ('Depois', 'imagens_atendimento_depois'),
            ]
          : const [
              ('Recebimento', 'imagens_recebimento'),
              ('Andamento', 'imagens_em_andamento'),
              ('Devolução', 'imagens_devolucao'),
            ];
      _fotos.clear();
      for (final grupo in grupos) {
        for (final url in _lista(row[grupo.$2])) {
          _fotos.add(_FotoConclusao(grupo.$1, url));
        }
      }
      _erro = null;
    } catch (e) {
      _erro = 'Não foi possível carregar a conclusão do serviço.';
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _carregarEndereco(int idEndereco) async {
    final e = await _db
        .from('enderecos')
        .select('logradouro, numero, complemento, bairro, fk_cidade')
        .eq('id_endereco', idEndereco)
        .maybeSingle();
    if (e == null) return;
    String? cidade;
    final idCidade = (e['fk_cidade'] as num?)?.toInt();
    if (idCidade != null) {
      try {
        final c = await _db
            .from('cidades')
            .select('nome_cidade')
            .eq('id_cidade', idCidade)
            .maybeSingle();
        cidade = c?['nome_cidade']?.toString();
      } catch (_) {}
    }
    String t(Object? v) => (v ?? '').toString().trim();
    final rua = [
      t(e['logradouro']),
      t(e['numero']),
    ].where((p) => p.isNotEmpty).join(', ');
    final comp = t(e['complemento']);
    _endereco = [
      comp.isEmpty ? rua : '$rua - $comp',
      t(e['bairro']),
      t(cidade),
    ].where((p) => p.isNotEmpty).join(', ');
  }

  double get _valorTotal =>
      (_solicitacao?['valor_final'] as num?)?.toDouble() ?? 0;
  double get _taxa =>
      (_valorTotal * _taxaIntermediacao * 100).roundToDouble() / 100;
  double get _liquido => _valorTotal - _taxa;

  String _real(double v) {
    final partes = v.toStringAsFixed(2).split('.');
    final inteiro = partes[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return 'R\$ $inteiro,${partes[1]}';
  }

  /// "48 minutos (14:08 às 14:56)".
  String _duracao() {
    final s = _solicitacao;
    if (s == null) return '—';
    final segundos =
        (s[_modalidade.ehDomicilio ? 'duracao_atendimento' : 'duracao_servico']
                as num?)
            ?.toInt() ??
        0;
    final minutos = (segundos / 60).round();
    final texto = minutos == 1 ? '1 minuto' : '$minutos minutos';
    final inicio = DateTime.tryParse(
      s['data_inicio_andamento']?.toString() ?? '',
    )?.toLocal();
    if (inicio == null || segundos <= 0) return texto;
    final fim = inicio.add(Duration(seconds: segundos));
    String h(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$texto (${h(inicio)} às ${h(fim)})';
  }

  void _irParaInicio() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const TelaHomeProfissional(isVisitante: false),
      ),
      (route) => false,
    );
  }

  void _emBreve(String o) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$o estará disponível em breve.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final codigo =
        '#PED-2026-${widget.idSolicitacao.toString().padLeft(4, '0')}';
    return Scaffold(
      backgroundColor: _fundo,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: voltarParaPedidos,
          icon: const Icon(Icons.close_rounded, color: _texto),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Serviço Concluído E Recebimento',
              style: TextStyle(
                color: _texto,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              codigo,
              style: const TextStyle(color: _textoSec, fontSize: 12),
            ),
          ],
        ),
        actions: [
          BotaoAjuda(
            cor: _texto,
            passos: () => explicacaoDaTela(
              context,
              tela: 'Este é o resumo do serviço concluído.',
              conteudo: [
                'Aqui você vê as etapas, o valor a receber, os dados do atendimento e as fotos.',
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CorOriginal(interface: true, child: Material(
              color: _azul,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TelaMeuPerfilProfissionalPage(),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            )),
          ),
        ],
      ),
      body: _carregando
          ? const _SkeletonConclusao()
          : _erro != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_erro!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    CorOriginal(interface: true, child: FilledButton(
                      onPressed: () {
                        setState(() => _carregando = true);
                        _carregar();
                      },
                      style: FilledButton.styleFrom(backgroundColor: _azul),
                      child: const Text('Tentar novamente'),
                    )),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: [
                _card(_etapas()),
                _card(_pagamento()),
                _card(_dadosAtendimento()),
                _card(_vistoria()),
                const SizedBox(height: 6),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _irParaInicio,
                    icon: const Icon(Icons.home_outlined, color: _texto),
                    label: const Text(
                      'Voltar para Início',
                      style: TextStyle(
                        color: _texto,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE5E7EB),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _emBreve('O comprovante em PDF'),
                    icon: const Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: Color(0xFF1E3A8A),
                    ),
                    label: const Text(
                      'Baixar Comprovante de Conclusão (PDF)',
                      style: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );

  Widget _tituloSecao(String texto) => Text(
    texto,
    style: const TextStyle(
      color: _texto,
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
    ),
  );

  /// Linha do tempo toda concluída + selo "Serviço Finalizado com Sucesso!".
  Widget _etapas() {
    final etapas = _modalidade.titulosEtapas;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < etapas.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: i == 0
                              ? const SizedBox()
                              : CorOriginal(interface: true, child: Container(height: 2, color: _azul)),
                        ),
                        CorOriginal(interface: true, child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: _azul,
                            shape: BoxShape.circle,
                            border: i == etapas.length - 1
                                ? Border.all(
                                    color: const Color(0xFFBDE9FF),
                                    width: 3,
                                  )
                                : null,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        )),
                        Expanded(
                          child: i == etapas.length - 1
                              ? const SizedBox()
                              : CorOriginal(interface: true, child: Container(height: 2, color: _azul)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      etapas[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _azul,
                        fontSize: 11.5,
                        fontWeight: i == etapas.length - 1
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        CorOriginal(interface: true, child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: _azul,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 17),
              SizedBox(width: 6),
              Text(
                'Serviço Finalizado com Sucesso!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _pagamento() {
    Widget linha(
      String rotulo,
      String valor, {
      Color? cor,
      bool forte = false,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                rotulo,
                style: TextStyle(
                  color: cor ?? const Color(0xFF374151),
                  fontSize: forte ? 14 : 13,
                  fontWeight: forte ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              valor,
              style: TextStyle(
                color: cor ?? _texto,
                fontSize: forte ? 14 : 13,
                fontWeight: forte ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final pct = (_taxaIntermediacao * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: _azul,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            _tituloSecao('PAGAMENTO LIBERADO'),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Valor líquido a receber',
          style: TextStyle(color: _textoSec, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _real(_liquido),
              style: const TextStyle(
                color: _azul,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'em carteira',
              style: TextStyle(color: _textoSec, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: _cinzaInterno,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              linha(
                'Valor Total do Serviço (${_modalidade.valorBanco})',
                _real(_valorTotal),
              ),
              linha(
                'Taxa de Intermediação ConsertaJá ($pct%)',
                '- ${_real(_taxa)}',
                cor: _vermelho,
              ),
              const Divider(height: 18, color: Color(0xFFE5E7EB)),
              linha(
                'Total Líquido Depositado',
                _real(_liquido),
                cor: _azul,
                forte: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.check_circle_outline, color: _azul, size: 17),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Disponível para saque imediato via PIX',
                style: TextStyle(color: Color(0xFF374151), fontSize: 12.5),
              ),
            ),
            InkWell(
              onTap: () => _emBreve('O extrato'),
              child: const Row(
                children: [
                  Text(
                    'Ver extrato',
                    style: TextStyle(
                      color: _azul,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _azul, size: 18),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dadosAtendimento() {
    Widget info(IconData icone, Widget texto) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: const Color(0xFF4B5563)),
          const SizedBox(width: 10),
          Expanded(child: texto),
        ],
      ),
    );
    const estilo = TextStyle(
      color: Color(0xFF374151),
      fontSize: 13,
      height: 1.3,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSecao('DADOS DO ATENDIMENTO'),
        const SizedBox(height: 14),
        Row(
          children: [
            CorOriginal(child: CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE0F2FE),
              backgroundImage: _fotoCliente != null
                  ? NetworkImage(_fotoCliente!)
                  : null,
              child: _fotoCliente == null
                  ? Text(
                      _nomeCliente.characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: _azul,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            )),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nomeCliente,
                    style: const TextStyle(
                      color: _texto,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _titulo,
                    style: const TextStyle(color: _textoSec, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(
            color: _cinzaInterno,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              if (_endereco.isNotEmpty)
                info(
                  Icons.location_on_outlined,
                  Text(_endereco, style: estilo),
                ),
              info(
                Icons.schedule_rounded,
                Text.rich(
                  TextSpan(
                    style: estilo,
                    children: [
                      const TextSpan(text: 'Duração: '),
                      TextSpan(
                        text: _duracao(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              info(
                Icons.credit_card_rounded,
                const Text(
                  'Pagamento Garantido via App (PIX Seguro)',
                  style: estilo,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _vistoria() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _tituloSecao('VISTORIA E COMPROVANTES')),
            CorOriginal(interface: true, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _azul,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Imagens',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )),
          ],
        ),
        const SizedBox(height: 14),
        if (_fotos.isEmpty)
          const Text(
            'Nenhuma imagem registrada neste atendimento.',
            style: TextStyle(color: _textoSec, fontSize: 13),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _fotos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              childAspectRatio: 0.98,
            ),
            itemBuilder: (_, i) {
              final foto = _fotos[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ImagemApp(child: Image.network(
                            foto.url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: _cinzaInterno,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: _textoSec,
                              ),
                            ),
                          )),
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: CorOriginal(interface: true, ativo: !(foto.tipo == 'Antes'), child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: foto.tipo == 'Antes'
                                    ? const Color(0xCC374151)
                                    : _azul,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                foto.tipo,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Imagem ${i + 1}',
                    style: const TextStyle(color: _textoSec, fontSize: 12),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _FotoConclusao {
  final String tipo;
  final String url;
  const _FotoConclusao(this.tipo, this.url);
}

/// Skeleton no formato da tela (etapas, pagamento, atendimento, imagens).
class _SkeletonConclusao extends StatelessWidget {
  const _SkeletonConclusao();

  @override
  Widget build(BuildContext context) {
    Widget card(List<Widget> filhos) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: filhos,
      ),
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(14),
      children: [
        card([
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              5,
              (_) => const SkeletonBox(width: 26, height: 26, borderRadius: 13),
            ),
          ),
          const SizedBox(height: 14),
          const SkeletonBox(height: 34, borderRadius: 17),
        ]),
        card(const [
          SkeletonBox(width: 170, height: 18),
          SizedBox(height: 16),
          SkeletonBox(width: 120, height: 12),
          SizedBox(height: 8),
          SkeletonBox(width: 190, height: 30),
          SizedBox(height: 12),
          SkeletonBox(height: 96, borderRadius: 12),
        ]),
        card(const [
          SkeletonBox(width: 180, height: 14),
          SizedBox(height: 14),
          Row(
            children: [
              SkeletonBox(width: 48, height: 48, borderRadius: 24),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 32)),
            ],
          ),
          SizedBox(height: 12),
          SkeletonBox(height: 90, borderRadius: 12),
        ]),
        card(const [
          SkeletonBox(width: 200, height: 14),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 130, borderRadius: 12)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 130, borderRadius: 12)),
            ],
          ),
        ]),
      ],
    );
  }
}
